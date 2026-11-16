# Dependency-free transactional tests, compatible with Windows PowerShell 5.1 / 7.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/../../scripts/ci/Deploy-Remote.ps1"

function Assert-True([bool]$Value, [string]$Message) {
    if (-not $Value) { throw "Assertion failed: $Message" }
}
function Reset-Fake([bool]$Existing = $true) {
    $script:containers = @{}
    if ($Existing) { $script:containers['factoryhub_container'] = 'old' }
    $script:calls = [Collections.Generic.List[string]]::new()
    $script:failure = ''
    $script:newHealth = 'healthy'
    $script:oldHealth = 'healthy'
    $script:imageMismatch = $false
    $script:lockObserved = $false
}
function Invoke-Docker {
    param([string[]]$Arguments)
    $a = $Arguments
    $script:calls.Add(($a -join ' '))
    # The OS lock must remain held even during rollback commands.
    $probe = $null
    try { $probe = [IO.File]::Open((Join-Path $script:root 'deploy.lock'), 'Open', 'ReadWrite', 'None') }
    catch [IO.IOException] { $script:lockObserved = $true }
    finally { if ($probe) { $probe.Dispose(); throw 'Deployment did not hold the lock.' } }
    switch ($a[0]) {
        'info' { return 'linux' }
        'load' { return 'Loaded image' }
        'image' {
            $id = $script:expectedId
            if ($script:imageMismatch) { $id = 'sha256:' + ('b' * 64) }
            return ConvertTo-Json -Depth 6 -InputObject @(@{
                Id = $id; Os = 'linux'; RepoTags = @("factoryhub_image:$script:commit")
                Config = @{ Healthcheck = @{ Test = @('CMD-SHELL', 'wget') } }
            }) -Compress
        }
        'container' {
            if ($a[1] -eq 'ls') { return ($script:containers.Keys -join "`n") }
            $name = $a[2]
            if (-not $script:containers.ContainsKey($name)) { throw 'No such container' }
            $health = $script:newHealth
            if ($script:containers[$name] -eq 'old') { $health = $script:oldHealth }
            return ConvertTo-Json -Depth 6 -InputObject @(@{ State = @{
                Status = 'running'; Health = @{ Status = $health }
            } }) -Compress
        }
        'rename' {
            if ($script:failure -eq 'rename' -and $a[1] -eq 'factoryhub_container') { throw 'rename failed' }
            $script:containers[$a[2]] = $script:containers[$a[1]]
            $script:containers.Remove($a[1])
            return ''
        }
        'stop' { if ($script:failure -eq 'stop') { throw 'stop failed' }; return '' }
        'run' {
            # Model docker run failing after creation as well as successful creation.
            $script:containers['factoryhub_container'] = 'new'
            if ($script:failure -eq 'run') { throw 'run failed' }
            return 'new-container-id'
        }
        'rm' { $script:containers.Remove($a[2]); return '' }
        'start' { if ($script:failure -eq 'rollback') { throw 'start failed' }; return '' }
        default { throw "Unexpected Docker command: $($a -join ' ')" }
    }
}
function Invoke-TestDeployment {
    Invoke-Deployment -Archive $script:archive -ArchiveSha256 $script:hash -ImageId $script:expectedId `
        -Commit $script:commit -DeploymentId $script:id -Root $script:root -HealthTimeoutSeconds 0
}
function Expect-Failure([string]$Pattern) {
    $caught = $null
    try { Invoke-TestDeployment } catch { $caught = $_ }
    Assert-True ($null -ne $caught) 'Expected failure'
    Assert-True ($caught.ToString() -like "*$Pattern*") "Expected error matching $Pattern; received $caught"
}

$script:root = Join-Path ([IO.Path]::GetTempPath()) ('factoryhub-test-' + [Guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $script:root
$script:archive = Join-Path $script:root 'image.tar'
[IO.File]::WriteAllText($script:archive, 'test archive, not a real docker image')
$script:hash = (Get-FileHash -LiteralPath $script:archive -Algorithm SHA256).Hash
$script:commit = 'a' * 40
$script:id = '1' * 32
$script:expectedId = 'sha256:' + ('a' * 64)
$backup = "factoryhub_container-previous-$script:id"
$passed = 0
try {
    Reset-Fake
    Invoke-TestDeployment
    Assert-True ($script:containers['factoryhub_container'] -eq 'new') 'New container active'
    Assert-True ($script:containers[$backup] -eq 'old') 'Old container retained'
    Assert-True $script:lockObserved 'Target lock acquired'
    $passed++

    Reset-Fake $false
    Invoke-TestDeployment
    Assert-True ($script:containers.Count -eq 1) 'First deployment has no backup'
    $passed++

    foreach ($scenario in 'unhealthy', 'starting', 'run', 'stop', 'rollback', 'rename') {
        Reset-Fake
        if ($scenario -in @('unhealthy', 'starting')) { $script:newHealth = $scenario }
        else { $script:failure = $scenario }
        if ($scenario -eq 'rollback') {
            $script:newHealth = 'unhealthy'
            Expect-Failure 'ROLLBACK FAILED'
        }
        else {
            Expect-Failure 'failed'
            Assert-True ($script:containers['factoryhub_container'] -eq 'old') "Old restored after $scenario"
        }
        Assert-True $script:lockObserved "Lock held for $scenario"
        $passed++
    }

    Reset-Fake $false
    $script:newHealth = 'unhealthy'
    Expect-Failure 'failed'
    Assert-True ($script:containers.Count -eq 0) 'Failed first deployment cleans candidate'
    $passed++

    Reset-Fake
    $script:imageMismatch = $true
    Expect-Failure 'identity'
    Assert-True (-not ($script:calls -match '^stop |^rename |^run ')) 'Identity checked before outage'
    $passed++

    Reset-Fake
    $script:oldHealth = 'unhealthy'
    Expect-Failure 'unhealthy'
    Assert-True (-not ($script:calls -match '^stop |^rename |^run ')) 'Unhealthy previous container untouched'
    $passed++

    Reset-Fake
    $goodHash = $script:hash
    $script:hash = '0' * 64
    Expect-Failure 'SHA256'
    Assert-True ($script:calls.Count -eq 0) 'Hash checked before Docker load'
    $script:hash = $goodHash
    $passed++

    Reset-Fake
    $held = [IO.File]::Open((Join-Path $script:root 'deploy.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
    try { Expect-Failure 'used by another process' }
    finally { $held.Dispose() }
    Assert-True ($script:calls.Count -eq 0) 'Concurrent deployment blocked before Docker'
    $passed++

    # A failed transaction releases the lock so a later deployment can proceed.
    Reset-Fake
    Invoke-TestDeployment
    $passed++
    Write-Host "PASSED: $passed transactional scenarios (Docker mocked; no network)."
}
finally { Remove-Item -LiteralPath $script:root -Recurse -Force }
