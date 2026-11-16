# Runner transport tests: all native commands mocked, no SSH or Docker access.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows -or $PSVersionTable.PSVersion.Major -lt 7) { throw 'Run transport tests with pwsh on Windows.' }
function Assert-True([bool]$Value, [string]$Message) {
    if (-not $Value) { throw "Assertion failed: $Message" }
}
$script:commit = 'a' * 40
$script:imageId = 'sha256:' + ('a' * 64)
function git {
    $global:LASTEXITCODE = 0
    return $script:commit
}
function docker {
    $a = @($args)
    Assert-True ([string]::IsNullOrEmpty($env:DEPLOY_SSH_KEY)) 'Secret not passed to Docker child'
    $script:calls.Add('docker ' + ($a -join ' '))
    $global:LASTEXITCODE = 0
    switch ($a[0]) {
        'info' { return 'linux' }
        'build' { return }
        'image' { return $script:imageId }
        'save' {
            [IO.File]::WriteAllText($a[2], 'fake archive')
            return
        }
        default { throw 'Unexpected docker command' }
    }
}
function Test-SshOptions([object[]]$Arguments) {
    $text = $Arguments -join ' '
    foreach ($option in 'BatchMode=yes', 'IdentitiesOnly=yes', 'StrictHostKeyChecking=yes',
        'ConnectTimeout=15', 'UserKnownHostsFile=') {
        Assert-True ($text.Contains($option)) "Missing SSH option $option"
    }
    Assert-True (-not $text.Contains('FAKE-PRIVATE-KEY')) 'No secret in arguments'
    $keyIndex = [Array]::IndexOf($Arguments, '-i') + 1
    $key = $Arguments[$keyIndex]
    $script:tempPath = Split-Path $key
    Assert-True (Test-Path -LiteralPath $key) 'Temporary key exists'
    $acl = Get-Acl -LiteralPath $script:tempPath
    Assert-True $acl.AreAccessRulesProtected 'Temporary ACL inheritance removed'
    Assert-True (@($acl.Access).Count -eq 1) 'Only runner identity has access'
}
function ssh {
    $a = @($args)
    Test-SshOptions $a
    $encoded = ($a[-1] -split ' ')[-1]
    $command = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String($encoded))
    $script:calls.Add('ssh ' + $command)
    $global:LASTEXITCODE = 0
    if (($script:failure -eq 'prepare' -and $command.Contains('New-Item')) -or
        ($script:failure -eq 'deploy' -and $command.Contains('-ArchiveSha256'))) {
        $global:LASTEXITCODE = 1
    }
}
function scp {
    $a = @($args)
    Test-SshOptions $a
    Assert-True ($a -contains '-O') 'Windows legacy SCP protocol requested'
    Assert-True ($a[-1] -match '^adminprod@192\.168\.1\.104:C:/Deploy/containers/factoryhub_container/incoming-[a-f0-9]{32}/') 'Fixed unique target path'
    $script:calls.Add('scp')
    $global:LASTEXITCODE = 0
    if ($script:failure -eq 'transfer') { $global:LASTEXITCODE = 1 }
}
$oldKey = $env:DEPLOY_SSH_KEY
$oldHosts = $env:DEPLOY_KNOWN_HOSTS
$exitVariable = Get-Variable LASTEXITCODE -Scope Global -ErrorAction SilentlyContinue
$oldExit = 0
if ($null -ne $exitVariable) { $oldExit = $exitVariable.Value }
$passed = 0
try {
    foreach ($scenario in 'success', 'prepare', 'transfer', 'deploy') {
        $script:calls = [Collections.Generic.List[string]]::new()
        $script:tempPath = $null
        $script:failure = $scenario
        $env:DEPLOY_SSH_KEY = 'FAKE-PRIVATE-KEY'
        $env:DEPLOY_KNOWN_HOSTS = '192.168.1.104 ssh-ed25519 FAKE-HOST-KEY'
        $errorCaught = $null
        try { . "$PSScriptRoot/../../scripts/ci/Publish-FactoryHub.ps1" -Commit $script:commit -Sequence 42 }
        catch { $errorCaught = $_ }
        if ($scenario -eq 'success') { Assert-True ($null -eq $errorCaught) "Success: $errorCaught" }
        else { Assert-True ($null -ne $errorCaught) "Expected failure: $scenario" }
        Assert-True (-not (Test-Path -LiteralPath $script:tempPath)) "Local secrets cleaned after $scenario"
        if ($scenario -ne 'prepare') {
            Assert-True (@($script:calls -match '^ssh .*Remove-Item').Count -eq 1) "Remote staging cleaned after $scenario"
        }
        else { Assert-True (@($script:calls -match '-ArchiveSha256').Count -eq 0) 'No deploy after prepare failure' }
        if ($scenario -eq 'success') {
            Assert-True (@($script:calls -match '-ArchiveSha256').Count -eq 1) 'Deployment includes hash and identity'
            Assert-True (@($script:calls -match '-Sequence 42;').Count -eq 1) 'Validated sequence transmitted in encoded command'
        }
        $passed++
    }
    # Missing credentials must block before any build/network command.
    $script:calls.Clear()
    Remove-Item Env:DEPLOY_SSH_KEY -ErrorAction SilentlyContinue
    $caught = $null
    try { . "$PSScriptRoot/../../scripts/ci/Publish-FactoryHub.ps1" -Commit $script:commit -Sequence 42 }
    catch { $caught = $_ }
    Assert-True ($null -ne $caught) 'Missing key blocks deployment'
    Assert-True ($script:calls.Count -eq 0) 'No build or transport without key'
    $passed++
    $env:DEPLOY_SSH_KEY = 'FAKE-PRIVATE-KEY'
    $env:DEPLOY_KNOWN_HOSTS = '192.168.1.104 ssh-ed25519 FAKE-HOST-KEY'
    foreach ($invalidSequence in @('0', '-1', 'not-a-number', '9223372036854775808')) {
        $caught = $null
        try { . "$PSScriptRoot/../../scripts/ci/Publish-FactoryHub.ps1" -Commit $script:commit -Sequence $invalidSequence }
        catch { $caught = $_ }
        Assert-True ($null -ne $caught) "Invalid sequence rejected: $invalidSequence"
        Assert-True ($script:calls.Count -eq 0) 'Invalid sequence blocks before build or transport'
        $passed++
    }
    Write-Host "PASSED: $passed runner transport/credential scenarios (all native commands mocked)."
}
finally {
    $env:DEPLOY_SSH_KEY = $oldKey
    $env:DEPLOY_KNOWN_HOSTS = $oldHosts
    $global:LASTEXITCODE = $oldExit
}
