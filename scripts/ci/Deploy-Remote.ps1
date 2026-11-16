# Compatible with Windows PowerShell 5.1 and PowerShell 7. Dot-source for tests.
[CmdletBinding()]
param(
    [string]$Archive,
    [string]$ArchiveSha256,
    [string]$ImageId,
    [string]$Commit,
    [string]$DeploymentId,
    [string]$Root = 'C:\Deploy\containers\factoryhub_container',
    [int]$HealthTimeoutSeconds = 90
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-Docker {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    $output = & docker @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) { throw "Docker $($Arguments[0]) failed: $($output -join ' ')" }
    return ($output -join "`n")
}

function Get-ContainerNames {
    return @((Invoke-Docker @('container', 'ls', '-a', '--format', '{{.Names}}')) -split "`r?`n")
}

function Wait-Healthy {
    param([string]$Name, [int]$TimeoutSeconds)
    $deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
    do {
        $items = @(ConvertFrom-Json (Invoke-Docker @('container', 'inspect', $Name)))
        $state = $items[0].State
        if ($state.Status -ne 'running') { throw "Container $Name is not running." }
        if (-not $state.PSObject.Properties['Health']) { throw "Container $Name has no healthcheck." }
        if ($state.Health.Status -eq 'healthy') { return }
        if ($state.Health.Status -eq 'unhealthy') { throw "Container $Name is unhealthy." }
        if ([DateTime]::UtcNow -ge $deadline) { throw "Health timeout for $Name." }
        Start-Sleep -Seconds 2
    } while ($true)
}

function Invoke-Deployment {
    param(
        [string]$Archive, [string]$ArchiveSha256, [string]$ImageId,
        [string]$Commit, [string]$DeploymentId, [string]$Root,
        [int]$HealthTimeoutSeconds = 90
    )
    if ($Commit -cnotmatch '^[0-9a-f]{40}$' -or $DeploymentId -cnotmatch '^[0-9a-f]{32}$' -or
        $ArchiveSha256 -notmatch '^[0-9a-fA-F]{64}$' -or $ImageId -cnotmatch '^sha256:[0-9a-f]{64}$') {
        throw 'Invalid deployment identity.'
    }
    $name = 'factoryhub_container'
    $backup = "$name-previous-$DeploymentId"
    $image = "factoryhub_image:$Commit"
    $lock = $null
    try {
        # Atomic, exclusive OS lock, held through validation AND rollback. Never delete it.
        $lock = [IO.File]::Open((Join-Path $Root 'deploy.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
        if ((Get-FileHash -LiteralPath $Archive -Algorithm SHA256).Hash -ne $ArchiveSha256) {
            throw 'Archive SHA256 mismatch.'
        }
        $os = Invoke-Docker @('info', '--format', '{{.OSType}}')
        if ($os.Trim() -ne 'linux') { throw 'The target Docker daemon must run Linux containers.' }
        $null = Invoke-Docker @('load', '--input', $Archive)
        $images = @(ConvertFrom-Json (Invoke-Docker @('image', 'inspect', $image)))
        $loaded = $images[0]
        if ($loaded.Id -cne $ImageId -or $loaded.Os -ne 'linux' -or
            $loaded.RepoTags -notcontains $image -or
            -not $loaded.Config.PSObject.Properties['Healthcheck'] -or
            $loaded.Config.Healthcheck.Test[0] -eq 'NONE') {
            throw 'Loaded image identity, platform or healthcheck mismatch.'
        }
        $names = @(Get-ContainerNames)
        if ($names -contains $backup) { throw 'Backup name already exists.' }
        $hadPrevious = $names -contains $name
        if ($hadPrevious) { Wait-Healthy $name $HealthTimeoutSeconds }
        $renamed = $false
        $stopAttempted = $false
        $runAttempted = $false
        try {
            if ($hadPrevious) {
                # Rename while still running: if rename fails, the old service is untouched.
                $null = Invoke-Docker @('rename', $name, $backup)
                $renamed = $true
                $stopAttempted = $true
                $null = Invoke-Docker @('stop', '--time', '30', $backup)
            }
            $runAttempted = $true
            $null = Invoke-Docker @('run', '-d', '--name', $name, '--restart', 'unless-stopped',
                '--label', "factoryhub.commit=$Commit", '-p', '12000:80', $image)
            Wait-Healthy $name $HealthTimeoutSeconds
            Write-Host "Deployment healthy: $Commit. Previous container retained: $backup (if present)."
        }
        catch {
            $deploymentError = $_
            try {
                if ($runAttempted -and (@(Get-ContainerNames) -contains $name)) {
                    $null = Invoke-Docker @('rm', '-f', $name)
                }
                if ($renamed) {
                    $null = Invoke-Docker @('rename', $backup, $name)
                    if ($stopAttempted) { $null = Invoke-Docker @('start', $name) }
                    Wait-Healthy $name $HealthTimeoutSeconds
                    Write-Warning 'Previous container restored and healthy.'
                }
            }
            catch { throw "Deployment failed: $deploymentError ; ROLLBACK FAILED: $_. Manual recovery required." }
            throw "Deployment failed (rollback completed or no previous container): $deploymentError"
        }
    }
    finally { if ($null -ne $lock) { $lock.Dispose() } }
}

if ($MyInvocation.InvocationName -ne '.') {
    Invoke-Deployment -Archive $Archive -ArchiveSha256 $ArchiveSha256 -ImageId $ImageId `
        -Commit $Commit -DeploymentId $DeploymentId -Root $Root -HealthTimeoutSeconds $HealthTimeoutSeconds
}
