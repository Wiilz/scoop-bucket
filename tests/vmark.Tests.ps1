# Run in a separate PowerShell process. Never execute the installer, GUI or MCP server.
param([string]$Archive)

$ErrorActionPreference = 'Stop'
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { "$HOME\scoop" }
$scoopSource = "$scoopRoot\apps\scoop\current"
foreach ($lib in 'core', 'manifest', 'depends', 'download', 'decompress', 'install') { . "$scoopSource\lib\$lib.ps1" }

function Assert-True($condition, $message) {
    if (!$condition) { throw "Assertion failed: $message" }
}
function Get-FileDigest($path) {
    $stream = [IO.File]::OpenRead($path)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $stream.Dispose(); $sha.Dispose() }
}

$manifestPath = Join-Path $PSScriptRoot '..\bucket\vmark.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
Add-Type -Path "$scoopSource\supporting\validator\bin\Scoop.Validator.dll"
$validator = New-Object Scoop.Validator("$scoopSource/schema.json", $true)
Assert-True ($validator.Validate((Resolve-Path $manifestPath).Path)) ($validator.Errors -join "`n")
Assert-True (@($manifest.architecture.PSObject.Properties.Name).Count -eq 1 -and $null -ne $manifest.architecture.'64bit') 'Only official x64 builds are configured'
Assert-True ($manifest.bin -eq 'vmark.exe' -and $manifest.shortcuts[0][0] -eq $manifest.bin) 'GUI entry points'
Assert-True ($manifest.checkver -eq 'github') 'GitHub release tracking'
$url = $manifest.architecture.'64bit'.url
Assert-True ($manifest.autoupdate.architecture.'64bit'.url.Replace('$version', $manifest.version) -ceq $url) 'Autoupdate reproduces the current URL'
$cleanup = 'Remove-Item -LiteralPath "$dir\`$PLUGINSDIR", "$dir\uninstall.exe" -Recurse -Force'
Assert-True ($manifest.pre_install -ceq $cleanup) 'Cleanup is limited to installer artifacts'
foreach ($config in @($manifest) + @($manifest.architecture.PSObject.Properties.Value)) {
    foreach ($field in 'installer', 'post_install', 'pre_uninstall', 'uninstaller', 'post_uninstall', 'persist', 'env_add_path', 'env_set') {
        Assert-True ($null -eq $config.$field) "Unexpected lifecycle/data/system mutation: $field"
    }
}
Assert-True ($null -eq $manifest.architecture.'64bit'.pre_install) 'No architecture-specific cleanup override'
Write-Host 'PASS: manifest schema, entry points, update URL and restricted lifecycle hooks'

$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('vmark-tests-' + [guid]::NewGuid())
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
try {
    $env:APPDATA = Join-Path $sandbox 'Roaming'
    $env:LOCALAPPDATA = Join-Path $sandbox 'Local'
    $fixtures = @{
        "$env:APPDATA\app.vmark\settings.json" = 'fake-settings'
        "$env:LOCALAPPDATA\app.vmark\EBWebView\dummy" = 'fake-webview-data'
    }
    foreach ($path in $fixtures.Keys) {
        New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        [IO.File]::WriteAllText($path, $fixtures[$path])
    }
    $dir = Join-Path $sandbox 'app'
    New-Item -ItemType Directory -Path $dir | Out-Null
    $payload = @('vmark.exe', 'vmark-mcp-server.exe', 'resources\workflows\examples\triage-and-translate.yml')
    if ($Archive) {
        $archivePath = (Resolve-Path -LiteralPath $Archive).Path
        Assert-True ((Get-FileDigest $archivePath) -eq $manifest.architecture.'64bit'.hash) 'Official installer SHA256'
        Copy-Item -LiteralPath $archivePath -Destination "$dir\dl.7z"
        Invoke-Extraction -Path $dir -Name 'dl.7z' -Manifest $manifest -ProcessorArchitecture '64bit'
        Write-Host 'PASS: official installer SHA256 and Scoop extraction'
    } else {
        foreach ($relative in $payload + @('$PLUGINSDIR\System.dll', 'uninstall.exe')) {
            $path = Join-Path $dir $relative
            New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
            [IO.File]::WriteAllText($path, "fixture: $relative")
        }
        Write-Host 'SKIP: official archive not supplied; testing cleanup with fixtures'
    }
    $digests = @{}
    foreach ($relative in $payload) {
        $path = Join-Path $dir $relative
        Assert-True (Test-Path -LiteralPath $path -PathType Leaf) "Payload exists: $relative"
        $digests[$relative] = Get-FileDigest $path
    }
    Invoke-HookScript -HookType 'pre_install' -Manifest $manifest -ProcessorArchitecture '64bit'
    foreach ($relative in '$PLUGINSDIR', 'uninstall.exe') {
        Assert-True (!(Test-Path -LiteralPath (Join-Path $dir $relative))) "Installer artifact removed: $relative"
    }
    foreach ($relative in $payload) {
        Assert-True ((Get-FileDigest (Join-Path $dir $relative)) -eq $digests[$relative]) "Payload bytes preserved: $relative"
    }
    foreach ($hook in 'post_install', 'pre_uninstall', 'uninstaller', 'post_uninstall') {
        Invoke-HookScript -HookType $hook -Manifest $manifest -ProcessorArchitecture '64bit'
    }
    foreach ($path in $fixtures.Keys) {
        Assert-True ([IO.File]::ReadAllText($path) -ceq $fixtures[$path]) "User data preserved: $path"
    }
    Write-Host 'PASS: installer cleanup preserves GUI, MCP server, resources and user data'
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
