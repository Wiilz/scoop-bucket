# Run with: powershell -NoProfile -File .\tests\sfmono-install.Tests.ps1
# Real Scoop installer dispatch, dummy OTF files, mocked registry and ACL writes. No system fonts changed.
$ErrorActionPreference = 'Stop'
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('sfmono-tests-' + [guid]::NewGuid())
$oldLocalAppData = $env:LOCALAPPDATA
$oldWinDir = $env:windir
$scoopRoot = if ($env:SCOOP) { $env:SCOOP } else { "$HOME\scoop" }
foreach ($source in @("$scoopRoot\apps\scoop\current\lib\install.ps1", "$scoopRoot\apps\scoop\current\lib\manifest.ps1")) {
    $tokens = $null; $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($source, [ref]$tokens, [ref]$errors)
    if ($errors.Count) { throw "Cannot parse Scoop source: $source" }
    foreach ($definition in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -in @('Invoke-Installer', 'Invoke-HookScript', 'arch_specific') }, $true)) {
        . ([scriptblock]::Create($definition.Extent.Text))
    }
}
function Assert-True($condition, $message) { if (!$condition) { throw "Assertion failed: $message" } }
function Assert-Sandbox($path) { Assert-True ($path.StartsWith($sandbox + '\', [StringComparison]::OrdinalIgnoreCase)) "Path outside sandbox: $path" }
function Assert-Throws([scriptblock]$action, $pattern) {
    $caught = $null
    try { & $action } catch { $caught = $_ }
    Assert-True ($null -ne $caught -and $caught.Exception.Message -match $pattern) "Expected '$pattern', got '$caught'"
}
function Get-ItemProperty {
    [CmdletBinding()] param([string]$Path)
    Assert-True ($Path -eq 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion') 'Unexpected OS build query'
    [pscustomobject]@{ CurrentBuildNumber = $state.Build }
}
function Test-Path {
    [CmdletBinding()] param([string]$LiteralPath, [string]$PathType = 'Any')
    if ($LiteralPath -match '^HK(CU|LM):') {
        Assert-True ($LiteralPath -eq $state.RegistryPath) 'Wrong registry scope'
        return $state.RegistryExists
    }
    Assert-Sandbox $LiteralPath
    Microsoft.PowerShell.Management\Test-Path -LiteralPath $LiteralPath -PathType $PathType -ErrorAction Stop
}
function New-Item {
    [CmdletBinding()] param([string]$Path, [string]$ItemType, [switch]$Force)
    if ($Path -match '^HK(CU|LM):') {
        Assert-True ($Path -eq $state.RegistryPath) 'Wrong registry creation scope'
        $state.RegistryExists = $true
        return
    }
    Assert-Sandbox $Path
    Microsoft.PowerShell.Management\New-Item -Path $Path -ItemType $ItemType -Force:$Force -ErrorAction Stop
}
function Get-Acl {
    [CmdletBinding()] param([string]$LiteralPath)
    Assert-True (!$global -and $LiteralPath -eq $state.FontDir) 'ACL requested outside the user font directory'
    return [Security.AccessControl.DirectorySecurity]::new()
}
function Set-Acl {
    [CmdletBinding()] param([string]$LiteralPath, $AclObject)
    Assert-True (!$global -and $LiteralPath -eq $state.FontDir) 'ACL changed outside the user font directory'
    if ($state.FailAcl) { throw 'Simulated ACL failure' }
    $rules = $AclObject.GetAccessRules($true, $false, [Security.Principal.SecurityIdentifier])
    foreach ($sid in @('S-1-15-2-1', 'S-1-15-2-2')) {
        $rule = @($rules | Where-Object { $_.IdentityReference.Value -eq $sid })
        # Allow rules may automatically include Synchronize in addition to ReadAndExecute.
        $allowedRights = [Security.AccessControl.FileSystemRights]::ReadAndExecute -bor [Security.AccessControl.FileSystemRights]::Synchronize
        Assert-True ($rule.Count -eq 1 -and ($rule[0].FileSystemRights -band [Security.AccessControl.FileSystemRights]::ReadAndExecute) -eq [Security.AccessControl.FileSystemRights]::ReadAndExecute -and ($rule[0].FileSystemRights -band (-bnot $allowedRights)) -eq 0) "Unexpected read/execute ACL for $sid"
        Assert-True ($rule[0].InheritanceFlags -eq ([Security.AccessControl.InheritanceFlags]::ContainerInherit -bor [Security.AccessControl.InheritanceFlags]::ObjectInherit)) 'Wrong ACL inheritance'
    }
    $state.AclWrites++
}
function Copy-Item {
    [CmdletBinding()] param([string]$LiteralPath, [string]$Destination, [switch]$Force)
    Assert-Sandbox $LiteralPath
    Assert-Sandbox $Destination
    Assert-True ([IO.Path]::GetDirectoryName($Destination) -eq $state.FontDir) 'Wrong font copy scope'
    if ($state.FailCopy) { throw 'Simulated copy failure' }
    Microsoft.PowerShell.Management\Copy-Item -LiteralPath $LiteralPath -Destination $Destination -Force:$Force -ErrorAction Stop
}
function New-ItemProperty {
    [CmdletBinding()] param([string]$LiteralPath, [string]$Name, [string]$Value, [switch]$Force)
    Assert-True ($LiteralPath -eq $state.RegistryPath) 'Wrong font registration scope'
    $fileName = $Name.Replace(' (TrueType)', '.otf')
    $expected = if ($global) { $fileName } else { Join-Path $state.FontDir $fileName }
    Assert-True ($Value -eq $expected) 'Wrong font registration value'
    Assert-True ([IO.File]::Exists((Join-Path $state.FontDir $fileName))) 'Registered a font before copying it'
    $state.Values[$Name] = $Value
}
function Reset-Fixture([int]$build) {
    $fontDir = if ($global) { "$env:windir\Fonts" } else { "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" }
    Microsoft.PowerShell.Management\New-Item -Path $fontDir -ItemType Directory -Force | Out-Null
    Get-ChildItem -LiteralPath $fontDir -File | Microsoft.PowerShell.Management\Remove-Item -Force
    $script:state = @{
        Build = $build; FontDir = $fontDir; Values = @{}; RegistryExists = $false
        RegistryPath = if ($global) { 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' } else { 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' }
        AclWrites = 0; FailAcl = $false; FailCopy = $false
    }
    foreach ($name in $names) { [IO.File]::WriteAllText((Join-Path $dir $name), 'dummy font') }
}
function Install-Fixture {
    Invoke-Installer -Path $dir -Name 'fonts.zip' -Manifest $manifest -ProcessorArchitecture '64bit' -AppName 'SFMono-NF' -Global:$global
}
try {
    $env:LOCALAPPDATA = Join-Path $sandbox 'LocalAppData'
    $env:windir = Join-Path $sandbox 'Windows'
    $dir = Join-Path $sandbox 'archive'
    Microsoft.PowerShell.Management\New-Item -Path $dir -ItemType Directory -Force | Out-Null
    $app = 'SFMono-NF'
    $manifest = Get-Content (Join-Path $PSScriptRoot '..\bucket\SFMono-NF.json') -Raw | ConvertFrom-Json
    $names = @('Bold', 'Heavy', 'Light', 'Medium', 'Regular', 'Semibold') | ForEach-Object { "SFMono $_ Nerd Font Complete.otf"; "SFMono $_ Italic Nerd Font Complete.otf" }
    foreach ($global in @($false, $true)) {
        foreach ($build in @(17762, 17763, 22621, 26100)) {
            Reset-Fixture $build
            if ($build -lt 17763 -and !$global) {
                Assert-Throws { Install-Fixture 6>$null } 'Per-user fonts require Windows 10 1809'
                Assert-True ($state.Values.Count -eq 0 -and $state.AclWrites -eq 0) 'Unsupported OS changed font state'
            } else {
                Install-Fixture 6>$null
                Assert-True ($state.Values.Count -eq 12) 'Expected 12 registered font faces'
                Assert-True (@(Get-ChildItem -LiteralPath $state.FontDir -File).Count -eq 12) 'Expected 12 copied font files'
                Assert-True ($state.AclWrites -eq $(if ($global) { 0 } else { 1 })) 'Unexpected ACL changes'
            }
            Write-Output "PASS SFMono-NF installer: build=$build global=$global"
        }
    }
    $global = $false
    Reset-Fixture 26100
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath (Join-Path $dir $names[-1]) -Force
    Assert-Throws { Install-Fixture 6>$null } 'Missing font in archive'
    Assert-True ($state.Values.Count -eq 0 -and $state.AclWrites -eq 0) 'Missing archive font caused partial installation'
    Reset-Fixture 26100
    $state.FailAcl = $true
    Assert-Throws { Install-Fixture 6>$null } 'Simulated ACL failure'
    Assert-True ($state.Values.Count -eq 0) 'ACL failure registered fonts'
    Reset-Fixture 26100
    $state.FailCopy = $true
    Assert-Throws { Install-Fixture 6>$null } 'Simulated copy failure'
    Assert-True ($state.Values.Count -eq 0) 'Copy failure registered fonts'
    Write-Output 'PASS SFMono-NF installer failure handling: missing source, ACL failure, copy failure'
} finally {
    $env:LOCALAPPDATA = $oldLocalAppData
    $env:windir = $oldWinDir
    if (Microsoft.PowerShell.Management\Test-Path -LiteralPath $sandbox) {
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath $sandbox -Recurse -Force
    }
}
