# Run in a separate PowerShell process. Never start the GUI/kernel or change proxy settings.
# Optional archive paths enable checksum and real Scoop extraction tests.
param([string]$Archive64bit, [string]$ArchiveArm64)

$ErrorActionPreference = 'Stop'
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { "$HOME\scoop" }
$scoopSource = "$scoopRoot\apps\scoop\current"
foreach ($lib in 'core', 'manifest', 'download', 'decompress', 'install') { . "$scoopSource\lib\$lib.ps1" }

function Assert-True($condition, $message) {
    if (!$condition) { throw "Assertion failed: $message" }
}
function Get-StreamDigest($stream) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Get-FileDigest($path) {
    $stream = [IO.File]::OpenRead($path)
    try { Get-StreamDigest $stream } finally { $stream.Dispose() }
}

$manifestPath = Join-Path $PSScriptRoot '..\bucket\sing-box-windows.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
Add-Type -Path "$scoopSource\supporting\validator\bin\Scoop.Validator.dll"
$validator = New-Object Scoop.Validator("$scoopSource/schema.json", $true)
Assert-True ($validator.Validate((Resolve-Path $manifestPath).Path)) ($validator.Errors -join "`n")
$hooks = @('pre_install', 'installer', 'post_install', 'pre_uninstall', 'uninstaller', 'post_uninstall')
# Reject unsafe hooks before dispatching anything, including architecture-specific overrides.
foreach ($config in @($manifest) + @($manifest.architecture.PSObject.Properties.Value)) {
    foreach ($field in $hooks + @('persist', 'env_add_path', 'env_set')) {
        Assert-True ($null -eq $config.$field) "Unexpected lifecycle/data/system mutation: $field"
    }
}
Assert-True ($manifest.bin -eq 'sing-box-windows.exe') 'Keep the existing command entry point'
Assert-True ($manifest.shortcuts[0][0] -eq $manifest.bin) 'Shortcut target matches the GUI'

$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('sing-box-tests-' + [guid]::NewGuid())
$oldAppData = $env:APPDATA
$oldLocalAppData = $env:LOCALAPPDATA
$archives = @{ '64bit' = $Archive64bit; 'arm64' = $ArchiveArm64 }
try {
    $env:APPDATA = Join-Path $sandbox 'Roaming'
    $env:LOCALAPPDATA = Join-Path $sandbox 'Local'
    $persist_dir = Join-Path $sandbox 'persist'
    $fixtures = @{
        "$env:APPDATA\cn.moncn.singbox\app_data.db" = 'fake-database'
        "$env:APPDATA\cn.moncn.singbox\app_data.db-wal" = 'fake-wal'
        "$env:APPDATA\cn.moncn.singbox\app_data.db-shm" = 'fake-shm'
        "$env:LOCALAPPDATA\sing-box-windows\sing-box\config.json" = 'fake-active-config'
        "$env:LOCALAPPDATA\sing-box-windows\sing-box\configs\manual.json" = 'fake-subscription'
        "$env:LOCALAPPDATA\sing-box-windows\sing-box\configs\manual.bak" = 'fake-config-backup'
        "$env:LOCALAPPDATA\sing-box-windows\sing-box\sing-box.exe" = 'fake-kernel'
        "$env:LOCALAPPDATA\cn.moncn.singbox\EBWebView\dummy" = 'fake-webview-data'
        "$persist_dir\appdata\old-backup" = 'fake-old-backup'
    }
    foreach ($path in $fixtures.Keys) {
        New-Item -ItemType Directory -Path (Split-Path $path) -Force | Out-Null
        [IO.File]::WriteAllText($path, $fixtures[$path])
    }
    foreach ($arch in '64bit', 'arm64') {
        # Covers fresh install, an update's old-version uninstall/new-version install, and uninstall.
        foreach ($hook in @('pre_install', 'installer', 'post_install', 'pre_uninstall', 'uninstaller', 'post_uninstall', 'pre_install', 'installer', 'post_install', 'pre_uninstall', 'uninstaller', 'post_uninstall')) {
            Invoke-HookScript -HookType $hook -Manifest $manifest -ProcessorArchitecture $arch
        }
        foreach ($path in $fixtures.Keys) {
            Assert-True ((Test-Path -LiteralPath $path) -and [IO.File]::ReadAllText($path) -ceq $fixtures[$path]) "User data changed: $path"
        }
        Assert-True (@(Get-ChildItem -LiteralPath $sandbox -Recurse -File -Force).Count -eq $fixtures.Count) 'No automatic backup or restore'
        Write-Host "PASS: $arch lifecycle hooks leave database, configs, kernel, WebView2 and old backup untouched"
    }
    # An absent Roaming directory must not trigger a restore from old persist data.
    Remove-Item -LiteralPath $env:APPDATA -Recurse -Force
    Invoke-HookScript -HookType 'post_install' -Manifest $manifest -ProcessorArchitecture '64bit'
    Assert-True (!(Test-Path -LiteralPath $env:APPDATA)) 'No implicit restore on a fresh installation'

    Add-Type -AssemblyName System.IO.Compression.FileSystem
    foreach ($arch in '64bit', 'arm64') {
        if (!$archives[$arch]) { Write-Host "SKIP: $arch archive not supplied"; continue }
        $archive = (Resolve-Path -LiteralPath $archives[$arch]).Path
        Assert-True ((Get-FileDigest $archive) -eq $manifest.architecture.$arch.hash) "$arch archive SHA256"
        $zip = [IO.Compression.ZipFile]::OpenRead($archive)
        try {
            Assert-True ($zip.Entries.Count -eq 1) "$arch portable archive contains only the GUI executable"
            $entry = $zip.GetEntry($manifest.bin)
            Assert-True ($null -ne $entry) "$arch executable exists at the archive root"
            $stream = $entry.Open()
            try { $expected = Get-StreamDigest $stream } finally { $stream.Dispose() }
        } finally { $zip.Dispose() }
        $dir = Join-Path $sandbox "extract-$arch"
        New-Item -ItemType Directory -Path $dir | Out-Null
        Copy-Item -LiteralPath $archive -Destination "$dir\archive.zip"
        Invoke-Extraction -Path $dir -Name 'archive.zip' -Manifest $manifest -ProcessorArchitecture $arch
        Assert-True (@(Get-ChildItem -LiteralPath $dir -File -Recurse -Force).Count -eq 1) 'No extra installed files'
        Assert-True ((Get-FileDigest "$dir\$($manifest.bin)") -eq $expected) "$arch extracted executable matches official bytes"
        Write-Host "PASS: $arch official archive checksum and Scoop extraction"
    }
} finally {
    $env:APPDATA = $oldAppData
    $env:LOCALAPPDATA = $oldLocalAppData
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
