# Run in a fresh process: powershell -NoProfile -File .\tests\pingfang-uninstall.Tests.ps1
# Dummy files, an in-memory registry, and a fake native API only. No system fonts are changed.
$ErrorActionPreference = 'Stop'
$sandbox = Join-Path ([System.IO.Path]::GetTempPath()) ('pingfang-tests-' + [guid]::NewGuid())
$oldLocalAppData = $env:LOCALAPPDATA
$oldWinDir = $env:windir

if ('LzScoop.PingFangNative' -as [type]) { throw 'Run these tests in a fresh PowerShell process.' }
Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
namespace LzScoop {
    public static class PingFangNative {
        public static string Sandbox;
        public static int RegisteredCount;
        public static bool Notified;
        public static bool NotifySucceeds = true;
        public static FileStream SessionLock;
        public static string SessionPath;
        public static readonly Dictionary<string, int> References = new Dictionary<string, int>();
        public static readonly List<string> UnloadCalls = new List<string>();
        public static bool RemoveFontResourceExW(string name, uint flags, IntPtr reserved) {
            if (!name.StartsWith(Sandbox + "\\", StringComparison.OrdinalIgnoreCase))
                throw new Exception("Native API path outside sandbox");
            if (RegisteredCount != 0 || flags != 0 || reserved != IntPtr.Zero)
                throw new Exception("Fonts must be unregistered before unloading with public-font flags");
            UnloadCalls.Add(name);
            int count;
            if (!References.TryGetValue(name, out count) || count == 0) return false;
            References[name] = --count;
            if (count == 0 && name == SessionPath && SessionLock != null) {
                SessionLock.Dispose();
                SessionLock = null;
            }
            return true;
        }
        public static bool SendNotifyMessageW(IntPtr hWnd, uint msg, UIntPtr wParam, IntPtr lParam) {
            if (hWnd != new IntPtr(0xffff) || msg != 0x001d || wParam != UIntPtr.Zero || lParam != IntPtr.Zero)
                throw new Exception("Expected HWND_BROADCAST / WM_FONTCHANGE");
            Notified = true;
            return NotifySucceeds;
        }
    }
}
'@
[LzScoop.PingFangNative]::Sandbox = $sandbox

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
    Assert-True ($Name -ne 'Older PingFang (TrueType)') 'Unrelated registry entry must not be removed'
    if ($state.FailRegistry -eq $Name) { throw 'Simulated registry deletion failure' }
    Assert-True ($state.Values.Contains($Name)) 'Attempted to delete a missing registry entry'
    $state.Values.Remove($Name)
    [LzScoop.PingFangNative]::RegisteredCount--
}

function Remove-Item {
    [CmdletBinding()]
    param([string]$LiteralPath, [switch]$Force)
    Assert-SandboxPath $LiteralPath
    Assert-True ([LzScoop.PingFangNative]::RegisteredCount -eq 0) 'Registry removal must precede file deletion'
    Assert-True ([LzScoop.PingFangNative]::UnloadCalls.Contains($LiteralPath)) 'Native unload must precede file deletion'
    Assert-True ([LzScoop.PingFangNative]::Notified) 'Font change notification must precede file deletion'
    if ($state.FailFile -eq $LiteralPath) { throw 'Simulated file deletion failure' }
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $LiteralPath -Force:$Force -ErrorAction Stop
}

function Reset-Fixture {
    if ([LzScoop.PingFangNative]::SessionLock) { [LzScoop.PingFangNative]::SessionLock.Dispose() }
    [LzScoop.PingFangNative]::SessionLock = $null
    [LzScoop.PingFangNative]::SessionPath = ''
    [LzScoop.PingFangNative]::References.Clear()
    [LzScoop.PingFangNative]::UnloadCalls.Clear()
    [LzScoop.PingFangNative]::RegisteredCount = 6
    [LzScoop.PingFangNative]::Notified = $false
    [LzScoop.PingFangNative]::NotifySucceeds = $true
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
    # Deliberately empty: uninstall must not depend on source OTF files in $dir.
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
        $uninstallSource = $manifest.uninstaller.script -join "`n"
        $uninstallHook = [scriptblock]::Create($uninstallSource)
        $names = @($manifest.url | ForEach-Object { [System.IO.Path]::GetFileName(([uri]$_).AbsolutePath) })
        # Compile the production P/Invoke declarations under a different namespace, but never call them.
        $declaration = [regex]::Match($uninstallSource, "(?s)Add-Type -TypeDefinition @'\n(.*?)\n'@")
        Assert-True $declaration.Success 'Native declarations not found'
        $testNamespace = 'LzScoopDeclarationTest' + $app.Replace('-', '')
        Add-Type -TypeDefinition $declaration.Groups[1].Value.Replace('namespace LzScoop', "namespace $testNamespace")

        foreach ($global in @($false, $true)) {
            $fontDir = if ($global) { "$env:windir\Fonts" } else { "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" }
            New-Item -Path $fontDir -ItemType Directory -Force | Out-Null
            $firstPath = Join-Path $fontDir $names[0]

            Reset-Fixture
            & $preHook 6>$null
            & $uninstallHook 6>$null
            Assert-Cleaned
            & $preHook 6>$null
            & $uninstallHook 6>$null
            Assert-Cleaned

            # Regression: a reader can deny exclusive-open while still allowing file deletion.
            Reset-Fixture
            $reader = [System.IO.File]::Open($firstPath, 'Open', 'Read', ([System.IO.FileShare]::ReadWrite -bor [System.IO.FileShare]::Delete))
            try {
                Assert-Throws { $stream = [System.IO.File]::Open($firstPath, 'Open', 'ReadWrite', 'None'); $stream.Dispose() } '.*'
                & $preHook 6>$null
                & $uninstallHook 6>$null
            } finally { $reader.Dispose() }
            Assert-Cleaned

            # A session-loaded font is released via the native API before actual deletion.
            Reset-Fixture
            [LzScoop.PingFangNative]::SessionPath = $firstPath
            [LzScoop.PingFangNative]::SessionLock = [System.IO.File]::Open($firstPath, 'Open', 'ReadWrite', 'None')
            [LzScoop.PingFangNative]::References[$firstPath] = 2
            & $preHook 6>$null
            & $uninstallHook 6>$null
            Assert-True ([LzScoop.PingFangNative]::References[$firstPath] -eq 0) 'Not all font references were released'
            Assert-Cleaned

            # An external lock that the API cannot release leaves the app retryable but unregistered.
            Reset-Fixture
            $lock = [System.IO.File]::Open($firstPath, 'Open', 'ReadWrite', 'None')
            try {
                & $preHook 6>$null
                Assert-Throws { & $uninstallHook 6>$null } 'Font registrations have been removed, but file cleanup is incomplete'
                Assert-True ($state.Values.Count -eq 1) 'Locked fonts must not remain registered and reload at login'
                Assert-True (Test-Path -LiteralPath $firstPath) 'Locked font disappeared'
            } finally { $lock.Dispose() }
            & $uninstallHook 6>$null
            Assert-Cleaned

            Reset-Fixture
            $state.FailFile = $firstPath
            Assert-Throws { & $uninstallHook 6>$null } 'Simulated file deletion failure'
            Assert-True ($state.Values.Count -eq 1) 'Registrations remain after file deletion failure'
            $state.FailFile = ''
            & $uninstallHook 6>$null
            Assert-Cleaned

            # Partial registry failure must not delete files or unload resources; retry is safe.
            Reset-Fixture
            $state.FailRegistry = [System.IO.Path]::GetFileNameWithoutExtension($names[1]) + ' (TrueType)'
            Assert-Throws { & $uninstallHook 6>$null } 'Simulated registry deletion failure'
            Assert-True ([LzScoop.PingFangNative]::UnloadCalls.Count -eq 0) 'Unloaded resources after incomplete unregistration'
            foreach ($name in $names) { Assert-True (Test-Path -LiteralPath (Join-Path $fontDir $name)) 'Registry failure removed a file' }
            $state.FailRegistry = ''
            & $uninstallHook 6>$null
            Assert-Cleaned

            # A conflict in the last entry must be caught before touching any of the other five fonts.
            Reset-Fixture
            $lastRegistryName = [System.IO.Path]::GetFileNameWithoutExtension($names[-1]) + ' (TrueType)'
            $state.Values[$lastRegistryName] = 'another font installation'
            Assert-Throws { & $uninstallHook 6>$null } 'points elsewhere'
            Assert-True ($state.Values.Count -eq 7) 'Ownership conflict changed registry entries'
            Assert-True ([LzScoop.PingFangNative]::UnloadCalls.Count -eq 0) 'Ownership conflict unloaded fonts'
            foreach ($name in $names) { Assert-True (Test-Path -LiteralPath (Join-Path $fontDir $name)) 'Conflicting installation was removed' }

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
            [LzScoop.PingFangNative]::NotifySucceeds = $false
            & $uninstallHook 3>$null 6>$null
            Assert-Cleaned

            Reset-Fixture
            $state.RegistryExists = $false
            $state.Values.Clear()
            [LzScoop.PingFangNative]::RegisteredCount = 0
            & $uninstallHook 6>$null
            foreach ($name in $names) {
                Assert-True (-not (Test-Path -LiteralPath (Join-Path $fontDir $name))) 'Missing registry key prevented file cleanup'
            }
            Write-Output "PASS $app (global=$global): native unload order, shared readers, session resources, external locks, cleanup retry, registry failures, ownership, validation, notification failure, missing registry"
        }
    }
} finally {
    if ([LzScoop.PingFangNative]::SessionLock) { [LzScoop.PingFangNative]::SessionLock.Dispose() }
    $env:LOCALAPPDATA = $oldLocalAppData
    $env:windir = $oldWinDir
    if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $sandbox) {
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
