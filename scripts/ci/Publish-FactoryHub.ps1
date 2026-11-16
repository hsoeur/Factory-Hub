# Runner: Windows + PowerShell 7; target: Windows PowerShell 5.1.
[CmdletBinding()]
param([Parameter(Mandatory)][ValidatePattern('^[0-9a-f]{40}$')][string]$Commit)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows -or $PSVersionTable.PSVersion.Major -lt 7) { throw 'Windows PowerShell 7 runner required.' }
foreach ($command in 'docker', 'ssh', 'scp') { $null = Get-Command $command -ErrorAction Stop }
foreach ($secret in 'DEPLOY_SSH_KEY', 'DEPLOY_KNOWN_HOSTS') {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($secret))) { throw "Missing secret: $secret" }
}
function Invoke-Native {
    param([string]$Command, [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments)
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { throw "$Command failed (exit $LASTEXITCODE)." }
}
function ConvertTo-EncodedCommand([string]$Command) {
    return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($Command))
}
$id = [Guid]::NewGuid().ToString('N')
$temp = Join-Path ([IO.Path]::GetTempPath()) "factoryhub-$id"
$remoteRoot = 'C:\Deploy\containers\factoryhub_container'
$remote = "$remoteRoot\incoming-$id"
$destination = 'adminprod@192.168.1.104'
$remoteCreated = $false
try {
    $null = New-Item -ItemType Directory -Path $temp
    # Remove inherited access BEFORE writing any secrets; only the runner identity has access.
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = [Security.AccessControl.FileSystemAccessRule]::new($identity, 'FullControl',
        'ContainerInherit, ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
    Set-Acl -LiteralPath $temp -AclObject $acl
    $key = Join-Path $temp 'id_deploy'
    $knownHosts = Join-Path $temp 'known_hosts'
    [IO.File]::WriteAllText($key, $env:DEPLOY_SSH_KEY.TrimEnd() + "`n", [Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($knownHosts, $env:DEPLOY_KNOWN_HOSTS.TrimEnd() + "`n", [Text.UTF8Encoding]::new($false))
    # Do not expose secrets to subsequent child processes.
    Remove-Item Env:DEPLOY_SSH_KEY, Env:DEPLOY_KNOWN_HOSTS
    $options = @('-i', $key, '-o', 'BatchMode=yes', '-o', 'IdentitiesOnly=yes',
        '-o', 'StrictHostKeyChecking=yes', '-o', ('UserKnownHostsFile="{0}"' -f $knownHosts),
        '-o', 'GlobalKnownHostsFile=NUL', '-o', 'ConnectTimeout=15',
        '-o', 'ServerAliveInterval=15', '-o', 'ServerAliveCountMax=3')
    $image = "factoryhub_image:$Commit"
    $archive = Join-Path $temp 'image.tar'
    $os = & docker info --format '{{.OSType}}'
    if ($LASTEXITCODE -ne 0 -or $os.Trim() -ne 'linux') { throw 'Docker Linux daemon required on runner.' }
    Invoke-Native docker @('build', '--pull', '--tag', $image, '.')
    $imageId = & docker image inspect --format '{{.Id}}' $image
    if ($LASTEXITCODE -ne 0 -or $imageId -cnotmatch '^sha256:[0-9a-f]{64}$') { throw 'Cannot identify built image.' }
    Invoke-Native docker @('save', '--output', $archive, $image)
    $hash = (Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash
    $prepare = "`$ErrorActionPreference='Stop'; New-Item -ItemType Directory -Force -Path '$remote' | Out-Null"
    Invoke-Native ssh ($options + @($destination, 'powershell.exe -NoLogo -NoProfile -NonInteractive -EncodedCommand ' + (ConvertTo-EncodedCommand $prepare)))
    $remoteCreated = $true
    # -O uses legacy SCP supported by Windows OpenSSH without requiring SFTP drive mapping.
    $scpPath = $remote.Replace('\', '/')
    Invoke-Native scp ($options + @('-O', $archive, "${destination}:$scpPath/image.tar"))
    Invoke-Native scp ($options + @('-O', (Join-Path $PSScriptRoot 'Deploy-Remote.ps1'), "${destination}:$scpPath/Deploy-Remote.ps1"))
    $deploy = "`$ErrorActionPreference='Stop'; try { & '$remote\Deploy-Remote.ps1' -Archive '$remote\image.tar' -ArchiveSha256 '$hash' -ImageId '$imageId' -Commit '$Commit' -DeploymentId '$id'; exit 0 } catch { Write-Error `$_; exit 1 }"
    Invoke-Native ssh ($options + @($destination, 'powershell.exe -NoLogo -NoProfile -NonInteractive -EncodedCommand ' + (ConvertTo-EncodedCommand $deploy)))
}
finally {
    if ($remoteCreated) {
        $cleanup = "`$ErrorActionPreference='Stop'; Remove-Item -LiteralPath '$remote' -Recurse -Force"
        try { Invoke-Native ssh ($options + @($destination, 'powershell.exe -NoLogo -NoProfile -NonInteractive -EncodedCommand ' + (ConvertTo-EncodedCommand $cleanup))) }
        catch { Write-Warning "Remote staging cleanup failed for incoming-$id; remove it manually after confirming no deployment is active." }
    }
    if (Test-Path -LiteralPath $temp) { Remove-Item -LiteralPath $temp -Recurse -Force }
}
