Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path "$PSScriptRoot/../..").Path
foreach ($script in @('scripts/ci/Deploy-Remote.ps1', 'scripts/ci/Publish-FactoryHub.ps1',
    'tests/ci/Test-Deploy.ps1', 'tests/ci/Test-Repository.ps1', 'tests/ci/Test-Publish.ps1')) {
    $errors = $null
    $tokens = $null
    $null = [Management.Automation.Language.Parser]::ParseFile((Join-Path $root $script), [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "PowerShell syntax errors in ${script}: $errors" }
}
$html = [IO.File]::ReadAllText((Join-Path $root 'dist/index.html'))
if ($html -match '(?i)fonts\.googleapis\.com|fonts\.gstatic\.com') { throw 'Google Fonts regression.' }
# Link targets are intentionally remote; initial resource attributes must not be.
foreach ($tag in [regex]::Matches($html, '(?is)<(?:script|img|link|iframe|source|video|audio)\b[^>]*>')) {
    if ($tag.Value -match '(?i)(?:src|href|poster)\s*=\s*["''](?:https?:)?//') {
        throw "External initial resource: $($tag.Value)"
    }
}
if ($html -match '(?i)(?:@import\s+["'']|url\(\s*["'']?)(?:https?:)?//') {
    throw 'External CSS initial resource.'
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ('factoryhub-js-' + [Guid]::NewGuid().ToString('N') + '.js')
try {
    $inline = @([regex]::Matches($html, '(?is)<script\b[^>]*>(.*?)</script>') | ForEach-Object { $_.Groups[1].Value })
    if ($inline.Count -eq 0) { throw 'No inline application JavaScript found.' }
    [IO.File]::WriteAllText($temp, ($inline -join "`n"))
    & node --check $temp
    if ($LASTEXITCODE -ne 0) { throw 'JavaScript syntax check failed.' }
}
finally { if (Test-Path $temp) { Remove-Item $temp } }
$dockerfile = [IO.File]::ReadAllText((Join-Path $root 'Dockerfile'))
foreach ($expected in @('COPY nginx.conf /etc/nginx/conf.d/default.conf', 'COPY dist/ /usr/share/nginx/html/', 'HEALTHCHECK')) {
    if (-not $dockerfile.Contains($expected)) { throw "Dockerfile contract missing: $expected" }
}
if (-not (Test-Path (Join-Path $root 'dist/index.html'))) { throw 'Missing distribution.' }
if (-not (Test-Path (Join-Path $root 'dist/assets/amphitech-logo.png'))) { throw 'Missing initial logo asset.' }
$nginx = [IO.File]::ReadAllText((Join-Path $root 'nginx.conf'))
if ($nginx -notmatch 'root\s+/usr/share/nginx/html;' -or $nginx -notmatch 'listen\s+80;') {
    throw 'nginx/Docker runtime contract mismatch.'
}
$ignore = [IO.File]::ReadAllText((Join-Path $root '.dockerignore'))
foreach ($included in '!Dockerfile', '!nginx.conf', '!dist/', '!dist/**') {
    if (-not $ignore.Contains($included)) { throw "Docker build input excluded: $included" }
}
$workflow = [IO.File]::ReadAllText((Join-Path $root '.gitea/workflows/deploy.yml'))
if (-not $workflow.Contains('DEPLOY_SEQUENCE: ${{ github.run_number }}') -or
    -not $workflow.Contains('-Sequence $env:DEPLOY_SEQUENCE')) {
    throw 'Workflow must transmit the Gitea run number via environment to Publish.'
}
Write-Host 'PASSED: PowerShell parsing, initial resources, node --check, Docker/dist contract.'
