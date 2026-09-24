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
    foreach ($field in 'installer', 'post_install', 'pre_uninstall', 'uninstaller', 'persist', 'env_add_path', 'env_set') {
        Assert-True ($null -eq $config.$field) "Unexpected lifecycle/data/system mutation: $field"
    }
}
Assert-True ($null -eq $manifest.architecture.'64bit'.pre_install -and $null -eq $manifest.architecture.'64bit'.post_uninstall) 'No architecture-specific cleanup override'
Assert-True ($manifest.post_uninstall[0] -ceq "if (`$cmd -eq 'uninstall') {") 'Data deletion requires an explicit uninstall command'
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
    $unrelated = @{
        "$env:APPDATA\other-app\settings.json" = 'keep-other-app'
        "$env:LOCALAPPDATA\app.vmark-other\dummy" = 'keep-similar-name'
        "$sandbox\Documents\note.md" = 'keep-document'
        "$sandbox\mcp-client\config.json" = 'keep-mcp-config'
    }
    foreach ($path in @($fixtures.Keys) + @($unrelated.Keys)) {
        New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        $value = if ($fixtures.ContainsKey($path)) { $fixtures[$path] } else { $unrelated[$path] }
        [IO.File]::WriteAllText($path, $value)
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
    foreach ($cmd in @('install', 'update', 'cleanup', 'reset', '', $null)) {
        foreach ($hook in 'post_install', 'pre_uninstall', 'uninstaller', 'post_uninstall') {
            Invoke-HookScript -HookType $hook -Manifest $manifest -ProcessorArchitecture '64bit'
        }
        foreach ($path in $fixtures.Keys) {
            Assert-True ([IO.File]::ReadAllText($path) -ceq $fixtures[$path]) "User data preserved for command '$cmd': $path"
        }
    }
    Write-Host 'PASS: install, update and unknown commands preserve user data'

    $cmd = 'uninstall'
    $purge = $false
    foreach ($hook in 'pre_uninstall', 'uninstaller') {
        Invoke-HookScript -HookType $hook -Manifest $manifest -ProcessorArchitecture '64bit'
    }
    foreach ($path in $fixtures.Keys) {
        Assert-True ([IO.File]::ReadAllText($path) -ceq $fixtures[$path]) 'Data must survive until post_uninstall'
    }
    Invoke-HookScript -HookType 'post_uninstall' -Manifest $manifest -ProcessorArchitecture '64bit'
    foreach ($root in @($env:APPDATA, $env:LOCALAPPDATA)) {
        Assert-True (!(Test-Path -LiteralPath (Join-Path $root 'app.vmark'))) 'Plain uninstall removes the VMark data directory without -p'
        Assert-True (Test-Path -LiteralPath $root) 'AppData root is preserved'
    }
    # Repeated cleanup and purge with absent directories are harmless.
    $purge = $true
    Invoke-HookScript -HookType 'post_uninstall' -Manifest $manifest -ProcessorArchitecture '64bit'
    foreach ($path in $unrelated.Keys) {
        Assert-True ([IO.File]::ReadAllText($path) -ceq $unrelated[$path]) "Unrelated data preserved: $path"
    }
    Write-Host 'PASS: explicit uninstall removes only VMark AppData; missing data is harmless'

    # Never fall back to the working directory if AppData is unset or relative.
    $env:APPDATA = ''
    $env:LOCALAPPDATA = 'relative-path'
    Push-Location $sandbox
    try {
        foreach ($relative in @('app.vmark', 'relative-path\app.vmark')) {
            New-Item -ItemType Directory -Path $relative -Force | Out-Null
        }
        Invoke-HookScript -HookType 'post_uninstall' -Manifest $manifest -ProcessorArchitecture '64bit'
        foreach ($relative in @('app.vmark', 'relative-path\app.vmark')) {
            Assert-True (Test-Path -LiteralPath $relative) 'Invalid environment paths cannot trigger relative deletion'
        }
    } finally { Pop-Location }

    # A user-created junction must not cause deletion at its external target.
    $env:APPDATA = Join-Path $sandbox 'Roaming'
    $env:LOCALAPPDATA = Join-Path $sandbox 'Local'
    $link = Join-Path $env:APPDATA 'app.vmark'
    $target = Join-Path $sandbox 'linked-data'
    New-Item -ItemType Directory -Path $target | Out-Null
    [IO.File]::WriteAllText("$target\sentinel", 'keep-linked-data')
    New-Item -ItemType Junction -Path $link -Target $target | Out-Null
    try {
        Invoke-HookScript -HookType 'post_uninstall' -Manifest $manifest -ProcessorArchitecture '64bit'
        Assert-True ([IO.File]::ReadAllText("$target\sentinel") -ceq 'keep-linked-data') 'Linked data is not deleted'
        Assert-True (Test-Path -LiteralPath $link) 'Linked directory is left for manual cleanup'
    } finally { [IO.Directory]::Delete($link) }
    Write-Host 'PASS: invalid environment paths and linked data are skipped'
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
