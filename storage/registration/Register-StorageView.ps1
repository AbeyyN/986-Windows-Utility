param(
    [ValidateSet('Install','Remove','Status')][string]$Action = 'Status',
    [string]$DllPath,
    [string]$ClassRoot = 'HKCU:\Software\Classes\CLSID\{5FCCE720-D806-4B6A-A5F1-F060344FC88D}',
    [string]$NamespaceRoot = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{5FCCE720-D806-4B6A-A5F1-F060344FC88D}',
    [switch]$NoNotify
)
Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$script:StorageClsid = '{5FCCE720-D806-4B6A-A5F1-F060344FC88D}'
$script:StorageTitle = '986 Storage'
$script:Owner = 'AbeyyTechXy/986-Windows-Utility'

function Get-986OwnedRegistration {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    try {
        $value = (Get-ItemProperty -Path $Path -Name '986Owner' -ErrorAction Stop).'986Owner'
        return ([string]$value -eq $script:Owner)
    } catch { return $false }
}

function Assert-986StorageCollisionSafe {
    if ((Test-Path $ClassRoot) -and -not (Get-986OwnedRegistration -Path $ClassRoot)) {
        throw "Refusing to overwrite foreign CLSID registration: $ClassRoot"
    }
    if (Test-Path $NamespaceRoot) {
        $existing = $null
        try { $existing = (Get-Item -Path $NamespaceRoot).GetValue('') } catch { }
        if ($existing -and [string]$existing -ne $script:StorageTitle) {
            throw "Refusing to overwrite foreign This PC namespace entry: $NamespaceRoot"
        }
    }
}

function Notify-986ThisPcChanged {
    if ($NoNotify) { return }
    try {
        Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class StorageShellNotify {
  [DllImport("shell32.dll")] public static extern void SHChangeNotify(uint wEventId, uint uFlags, IntPtr dwItem1, IntPtr dwItem2);
}
'@ -ErrorAction SilentlyContinue
        [StorageShellNotify]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)
    } catch { }
}

function Install-986StorageView {
    if (-not $DllPath) { throw 'DllPath is required for Install.' }
    $resolved = [IO.Path]::GetFullPath($DllPath)
    if (-not (Test-Path $resolved -PathType Leaf)) { throw "Storage shell DLL not found: $resolved" }
    Assert-986StorageCollisionSafe

    New-Item -ItemType Directory -Path $ClassRoot -Force | Out-Null
    Set-Item -Path $ClassRoot -Value $script:StorageTitle
    New-ItemProperty -Path $ClassRoot -Name '986Owner' -Value $script:Owner -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $ClassRoot -Name 'System.IsPinnedToNameSpaceTree' -Value 1 -PropertyType DWord -Force | Out-Null

    $inproc = Join-Path $ClassRoot 'InprocServer32'
    New-Item -ItemType Directory -Path $inproc -Force | Out-Null
    Set-Item -Path $inproc -Value $resolved
    New-ItemProperty -Path $inproc -Name 'ThreadingModel' -Value 'Apartment' -PropertyType String -Force | Out-Null

    $icon = Join-Path $ClassRoot 'DefaultIcon'
    New-Item -ItemType Directory -Path $icon -Force | Out-Null
    Set-Item -Path $icon -Value 'shell32.dll,-31'

    $shellFolder = Join-Path $ClassRoot 'ShellFolder'
    New-Item -ItemType Directory -Path $shellFolder -Force | Out-Null
    New-ItemProperty -Path $shellFolder -Name 'Attributes' -Value ([int]-1610612736) -PropertyType DWord -Force | Out-Null

    New-Item -ItemType Directory -Path $NamespaceRoot -Force | Out-Null
    Set-Item -Path $NamespaceRoot -Value $script:StorageTitle
    New-ItemProperty -Path $NamespaceRoot -Name '986Owner' -Value $script:Owner -PropertyType String -Force | Out-Null
    Notify-986ThisPcChanged
}

function Remove-986StorageView {
    if ((Test-Path $NamespaceRoot) -and (Get-986OwnedRegistration -Path $NamespaceRoot)) {
        Remove-Item $NamespaceRoot -Recurse -Force
    }
    if ((Test-Path $ClassRoot) -and (Get-986OwnedRegistration -Path $ClassRoot)) {
        Remove-Item $ClassRoot -Recurse -Force
    }
    Notify-986ThisPcChanged
}

function Get-986StorageViewStatus {
    $classExists = Test-Path $ClassRoot
    $namespaceExists = Test-Path $NamespaceRoot
    [pscustomobject]@{
        CLSID = $script:StorageClsid
        ClassRegistered = $classExists
        NamespaceRegistered = $namespaceExists
        Owned = ($classExists -and (Get-986OwnedRegistration -Path $ClassRoot))
        Title = $script:StorageTitle
    }
}

switch ($Action) {
    'Install' { Install-986StorageView; Get-986StorageViewStatus }
    'Remove'  { Remove-986StorageView; Get-986StorageViewStatus }
    default   { Get-986StorageViewStatus }
}
