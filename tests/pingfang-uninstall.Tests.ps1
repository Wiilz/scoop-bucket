# Run with: powershell -NoProfile -File .\tests\pingfang-uninstall.Tests.ps1
# Uses dummy files and an in-memory registry; never installs or removes system fonts.
$ErrorActionPreference = 'Stop'
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ('pingfang-tests-' + [guid]::NewGuid())
$oldLocalAppData = $env:LOCALAPPDATA
$oldWinDir = $env:windir

function Assert-True($condition, [string]$message) {
    if (-not $condition) { throw "Assertion failed: $message" }
}

function Assert-Throws([scriptblock]$action, [string]$pattern) {
    $caught = $null
    try { & $action } catch { $caught = $_ }
    Assert-True ($null -ne $caught) 'Expected a terminating error'
    Assert-True ($caught.Exception.Message -match $pattern) "Unexpected error: $caught"
}

function Assert-RegistryPath([string]$path) {
    Assert-True ($path -eq $state.RegistryPath) "Unexpected registry path: $path"
}

function Assert-SandboxPath([string]$path) {
    Assert-True ($path.StartsWith($sandbox + '\', [StringComparison]::OrdinalIgnoreCase)) "Path outside sandbox: $path"
}

# Intercept registry operations. Filesystem operations are restricted to the sandbox.
function Test-Path {
    [CmdletBinding()]
    param([string]$LiteralPath)
    if ($LiteralPath -match '^HK(CU|LM):') {
        Assert-RegistryPath $LiteralPath
        return $state.RegistryExists
    }
    Assert-SandboxPath $LiteralPath
    Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath -ErrorAction Stop
}

function Get-ItemProperty {
    [CmdletBinding()]
    param([string]$LiteralPath)
    Assert-RegistryPath $LiteralPath
    return [pscustomobject]$state.Values
}

function Remove-ItemProperty {
    [CmdletBinding()]
    param([string]$LiteralPath, [string]$Name, [switch]$Force)
    Assert-RegistryPath $LiteralPath
    if ($state.FailRegistry -eq $Name) { throw 'Simulated registry deletion failure' }
    $state.Values.Remove($Name)
}

function Remove-Item {
    [CmdletBinding()]
    param([string]$LiteralPath, [switch]$Force)
    Assert-SandboxPath $LiteralPath
    if ($state.FailFile -eq $LiteralPath) { throw 'Simulated file deletion failure' }
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $LiteralPath -Force:$Force -ErrorAction Stop
}

function Reset-Fixture {
    Get-ChildItem -LiteralPath $fontDir -File | Microsoft.PowerShell.Management\Remove-Item -Force
    $script:state = @{
        RegistryPath = if ($global) { 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' } else { 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' }
        RegistryExists = $true
        Values = [ordered]@{}
        FailFile = ''
        FailRegistry = ''
    }
    foreach ($name in $names) {
        $path = Join-Path $fontDir $name
        [System.IO.File]::WriteAllText($path, 'dummy font')
        $state.Values[([System.IO.Path]::GetFileNameWithoutExtension($name) + ' (TrueType)')] = if ($global) { $name } else { $path }
    }
    [System.IO.File]::WriteAllText((Join-Path $fontDir 'PingFang Medium_1.ttf'), 'unrelated font')
    $state.Values['Older PingFang (TrueType)'] = 'unrelated registration'
}

function Assert-Cleaned {
    foreach ($name in $names) {
        Assert-True (-not (Test-Path -LiteralPath (Join-Path $fontDir $name))) "Font remains: $name"
    }
    Assert-True ($state.Values.Count -eq 1) 'Managed registry entries remain'
    Assert-True ($state.Values['Older PingFang (TrueType)'] -eq 'unrelated registration') 'Unrelated registry entry changed'
    Assert-True (Test-Path -LiteralPath (Join-Path $fontDir 'PingFang Medium_1.ttf')) 'Unrelated font removed'
}

try {
    $env:LOCALAPPDATA = Join-Path $sandbox 'LocalAppData'
    $env:windir = Join-Path $sandbox 'Windows'
    # Deliberately empty: uninstall must not depend on the source OTF files in $dir.
    $dir = Join-Path $sandbox 'empty-app-dir'
    New-Item -Path $dir -ItemType Directory -Force | Out-Null
    $cmd = 'uninstall'

    foreach ($file in Get-ChildItem (Join-Path $PSScriptRoot '..\bucket\pingfang-*.json')) {
        $manifest = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        $app = $file.BaseName
        foreach ($lines in @($manifest.installer.script, $manifest.pre_uninstall, $manifest.uninstaller.script, $manifest.checkver.script)) {
            $tokens = $null; $parseErrors = $null
            $null = [System.Management.Automation.Language.Parser]::ParseInput(($lines -join "`n"), [ref]$tokens, [ref]$parseErrors)
            Assert-True ($parseErrors.Count -eq 0) "PowerShell syntax errors in $app"
        }
        $preHook = [scriptblock]::Create($manifest.pre_uninstall -join "`n")
        $uninstallHook = [scriptblock]::Create($manifest.uninstaller.script -join "`n")
        $names = @($manifest.url | ForEach-Object { [System.IO.Path]::GetFileName(([uri]$_).AbsolutePath) })

        foreach ($global in @($false, $true)) {
            $fontDir = if ($global) { "$env:windir\Fonts" } else { "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" }
            New-Item -Path $fontDir -ItemType Directory -Force | Out-Null
            $firstPath = Join-Path $fontDir $names[0]
            $firstRegistryName = [System.IO.Path]::GetFileNameWithoutExtension($names[0]) + ' (TrueType)'

            Reset-Fixture
            & $preHook 6>$null
            & $uninstallHook 6>$null
            Assert-Cleaned
            & $preHook 6>$null
            & $uninstallHook 6>$null
            Assert-Cleaned

            Reset-Fixture
            $lock = [System.IO.File]::Open($firstPath, 'Open', 'ReadWrite', 'None')
            try {
                Assert-Throws { & $preHook 6>$null } '.*'
                Assert-Throws { & $uninstallHook 6>$null } '.*'
                Assert-True ($state.Values.Count -eq 7) 'Locked font lost its registry entry'
                Assert-True (Test-Path -LiteralPath $firstPath) 'Locked font disappeared'
            } finally { $lock.Dispose() }

            Reset-Fixture
            & $preHook 6>$null
            $state.FailFile = $firstPath
            Assert-Throws { & $uninstallHook 6>$null } 'Simulated file deletion failure'
            Assert-True ($state.Values.Count -eq 7) 'Deletion failure lost registry entries'
            $state.FailFile = ''
            & $uninstallHook 6>$null
            Assert-Cleaned

            Reset-Fixture
            $state.FailRegistry = $firstRegistryName
            Assert-Throws { & $uninstallHook 6>$null } 'Simulated registry deletion failure'
            Assert-True (-not (Test-Path -LiteralPath $firstPath)) 'File must be removed before its registry entry'
            Assert-True ($state.Values.Count -eq 7) 'Unexpected registry changes on failure'
            $state.FailRegistry = ''
            & $uninstallHook 6>$null
            Assert-Cleaned

            Reset-Fixture
            $state.Values[$firstRegistryName] = 'another font installation'
            Assert-Throws { & $uninstallHook 6>$null } 'points elsewhere'
            Assert-True (Test-Path -LiteralPath $firstPath) 'Conflicting installation was removed'

            Reset-Fixture
            $savedUrls = $manifest.url
            try {
                $manifest.url = @()
                Assert-Throws { & $preHook 6>$null } 'Invalid PingFang font list'
                Assert-Throws { & $uninstallHook 6>$null } 'Invalid PingFang font list'
                $manifest.url = @($savedUrls)
                $manifest.url[0] = 'https://example.invalid/unrelated.otf'
                Assert-Throws { & $preHook 6>$null } 'Invalid PingFang font list'
                Assert-Throws { & $uninstallHook 6>$null } 'Invalid PingFang font list'
                Assert-True ($state.Values.Count -eq 7) 'Invalid manifest changed registry entries'
            } finally { $manifest.url = $savedUrls }

            Reset-Fixture
            $state.RegistryExists = $false
            $state.Values.Clear()
            & $uninstallHook 6>$null
            foreach ($name in $names) {
                Assert-True (-not (Test-Path -LiteralPath (Join-Path $fontDir $name))) 'Missing registry key prevented file cleanup'
            }
            Write-Output "PASS $app (global=$global): empty source directory, cleanup, retry, locks, deletion failures, ownership, manifest validation, missing registry key"
        }
    }
} finally {
    $env:LOCALAPPDATA = $oldLocalAppData
    $env:windir = $oldWinDir
    if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $sandbox) {
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
