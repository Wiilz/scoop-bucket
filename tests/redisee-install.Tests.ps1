# Verify downloaded archives with real Scoop extractors; never launch Redisee or change real user data.
# Both archive paths must refer to the version declared in bucket/redisee.json.
param(
    [Parameter(Mandatory = $true)][string]$Archive64bit,
    [Parameter(Mandatory = $true)][string]$ArchiveArm64
)

$ErrorActionPreference = 'Stop'
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { "$HOME\scoop" }
$scoopSource = "$scoopRoot\apps\scoop\current"
foreach ($lib in 'core', 'manifest', 'decompress', 'install') {
    . "$scoopSource\lib\$lib.ps1"
}
Add-Type -AssemblyName System.IO.Compression.FileSystem

function Assert-True($condition, $message) {
    if (!$condition) { throw "Assertion failed: $message" }
}
function Get-StreamHash($stream) {
    $sha = [Security.Cryptography.SHA256]::Create()
    try { [BitConverter]::ToString($sha.ComputeHash($stream)).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}
function Get-FileDigest($path) {
    $stream = [IO.File]::OpenRead($path)
    try { Get-StreamHash $stream } finally { $stream.Dispose() }
}

$manifestPath = Join-Path $PSScriptRoot '..\bucket\redisee.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
Add-Type -Path "$scoopSource\supporting\validator\bin\Scoop.Validator.dll"
$validator = New-Object Scoop.Validator("$scoopSource/schema.json", $true)
Assert-True ($validator.Validate((Resolve-Path $manifestPath).Path)) ($validator.Errors -join "`n")
Assert-True ($manifest.extract_dir -eq 'current') 'Extract the real application, not the outer launcher'
Assert-True ($manifest.bin -eq 'Redisee.exe') 'Keep the existing command entry point'
Assert-True ($manifest.shortcuts[0][0] -eq 'Redisee.exe') 'Shortcut must target the real application'
foreach ($field in 'persist', 'post_install', 'installer', 'uninstaller', 'pre_uninstall', 'post_uninstall') {
    Assert-True ($null -eq $manifest.$field) "Unexpected data migration or lifecycle hook: $field"
}

$archives = @{ '64bit' = (Resolve-Path $Archive64bit).Path; 'arm64' = (Resolve-Path $ArchiveArm64).Path }
$extractors = @('Expand-ZipArchive')
if (Test-HelperInstalled -Helper 7zip) { $extractors += 'Expand-7zipArchive' }
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('redisee-tests-' + [guid]::NewGuid())
$oldLocalAppData = $env:LOCALAPPDATA
try {
    $env:LOCALAPPDATA = Join-Path $sandbox 'LocalAppData'
    $persist_dir = Join-Path $sandbox 'persist'
    $dataDir = Join-Path $env:LOCALAPPDATA 'Redisee\Data'
    New-Item -ItemType Directory -Path "$persist_dir\Data", $dataDir -Force | Out-Null
    # Reproduce the old migration trigger without using a real database.
    [IO.File]::WriteAllText("$persist_dir\Data\connections.db", 'old-connections')
    [IO.File]::WriteAllText("$persist_dir\Data\favorites.db", 'old-favorites')
    [IO.File]::WriteAllText("$dataDir\favorites.db", 'existing-favorites')

    foreach ($arch in '64bit', 'arm64') {
        $archive = $archives[$arch]
        Assert-True ((Get-FileDigest $archive) -eq $manifest.architecture.$arch.hash) "$arch archive SHA256"
        $expected = @{}
        $zip = [IO.Compression.ZipFile]::OpenRead($archive)
        try {
            $marker = $zip.GetEntry('.portable')
            Assert-True ($null -ne $marker -and $marker.Length -eq 0) 'Upstream portable marker must still be empty'
            foreach ($entry in $zip.Entries) {
                if ($entry.FullName -eq '.portable' -or ($entry.FullName.StartsWith('current/') -and !$entry.FullName.EndsWith('/'))) {
                    $name = $entry.FullName -replace '^current/', ''
                    $stream = $entry.Open()
                    try { $expected[$name] = Get-StreamHash $stream } finally { $stream.Dispose() }
                }
            }
        } finally { $zip.Dispose() }
        Assert-True ($expected.ContainsKey('Redisee.exe')) "$arch real executable exists"

        foreach ($extractor in $extractors) {
            $dir = Join-Path $sandbox "$arch-$extractor"
            New-Item -ItemType Directory -Path $dir | Out-Null
            $copy = Join-Path $dir 'archive.zip'
            Copy-Item -LiteralPath $archive -Destination $copy
            & $extractor -Path $copy -DestinationPath $dir -ExtractDir $manifest.extract_dir -Removal
            # Scoop runs pre_install after extraction. Repeating it must be harmless.
            1..2 | ForEach-Object {
                Invoke-HookScript -HookType 'pre_install' -Manifest $manifest -ProcessorArchitecture $arch
            }
            $files = @(Get-ChildItem -LiteralPath $dir -File -Recurse -Force)
            Assert-True ($files.Count -eq $expected.Count) "$arch/$extractor has no extra launcher, updater or archive"
            foreach ($file in $files) {
                $relative = $file.FullName.Substring($dir.Length + 1).Replace('\', '/')
                Assert-True ($expected.ContainsKey($relative)) "Unexpected installed file: $relative"
                Assert-True ((Get-FileDigest $file.FullName) -eq $expected[$relative]) "Installed bytes differ: $relative"
            }
            Assert-True (!(Test-Path "$dir\current")) 'No nested current directory'
            Assert-True (!(Test-Path "$dataDir\connections.db")) 'No automatic connection migration'
            Assert-True ([IO.File]::ReadAllText("$dataDir\favorites.db") -eq 'existing-favorites') 'Existing data not overwritten'
            Assert-True ([IO.File]::ReadAllText("$persist_dir\Data\connections.db") -eq 'old-connections') 'Old backup preserved'
            Write-Host "PASS: $arch / $extractor; exact payload, portable marker, no data migration"
        }
    }
} finally {
    $env:LOCALAPPDATA = $oldLocalAppData
    if (Test-Path -LiteralPath $sandbox) { Remove-Item -LiteralPath $sandbox -Recurse -Force }
}
