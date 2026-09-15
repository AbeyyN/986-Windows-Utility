# 986 Windows Utility bootstrap
param(
    [switch]$NoLaunch,
    [string]$InstallDir
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = 'AbeyyN/986-Windows-Utility'
$api = "https://api.github.com/repos/$repo/releases/latest"
$headers = @{
    'Accept' = 'application/vnd.github+json'
    'User-Agent' = '986-Windows-Utility-Bootstrap/1.1'
}

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $InstallDir = Join-Path $env:LOCALAPPDATA 'AbeyyTechXy\986-Windows-Utility'
}

function Get-986InstalledVersion {
    param([Parameter(Mandatory)][string]$Root)
    $appPath = Join-Path $Root '986-Windows-Utility.ps1'
    if (-not (Test-Path -LiteralPath $appPath -PathType Leaf)) { return $null }
    try {
        $text = Get-Content -LiteralPath $appPath -Raw -Encoding UTF8
        $m = [regex]::Match($text, "(?m)^\s*\`$Version\s*=\s*'([^']+)'")
        if ($m.Success) { return [string]$m.Groups[1].Value }
    } catch { }
    return $null
}

function Copy-986MergeItem {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Destination
    )
    $sourceItem = Get-Item -LiteralPath $Source
    if ($sourceItem.PSIsContainer) {
        if ((Test-Path -LiteralPath $Destination) -and -not (Test-Path -LiteralPath $Destination -PathType Container)) {
            Remove-Item -LiteralPath $Destination -Force
        }
        New-Item -ItemType Directory -Force -Path $Destination | Out-Null
        foreach ($child in @(Get-ChildItem -LiteralPath $Source -Force)) {
            Copy-986MergeItem -Source $child.FullName -Destination (Join-Path $Destination $child.Name)
        }
        return
    }

    if ((Test-Path -LiteralPath $Destination) -and (Test-Path -LiteralPath $Destination -PathType Container)) {
        Remove-Item -LiteralPath $Destination -Recurse -Force
    }
    $parent = Split-Path -Parent $Destination
    if ($parent) { New-Item -ItemType Directory -Force -Path $parent | Out-Null }
    Copy-Item -LiteralPath $Source -Destination $Destination -Force
}

function Install-986StoragePayload {
    param(
        [Parameter(Mandatory)][string]$SourceStorage,
        [Parameter(Mandatory)][string]$Root,
        [Parameter(Mandatory)][string]$ReleaseTag,
        [Parameter(Mandatory)][bool]$RepairMode
    )

    $storageRoot = Join-Path $Root 'storage'
    $sourceBin = Join-Path $SourceStorage 'bin'
    $sourceShell = Join-Path $sourceBin '986StorageShell.dll'
    if (-not (Test-Path -LiteralPath $sourceShell -PathType Leaf)) {
        throw 'Release package is missing storage\bin\986StorageShell.dll.'
    }

    New-Item -ItemType Directory -Force -Path $storageRoot | Out-Null

    foreach ($child in @(Get-ChildItem -LiteralPath $SourceStorage -Force)) {
        if ($child.Name -eq 'bin') {
            $binRoot = Join-Path $storageRoot 'bin'
            New-Item -ItemType Directory -Force -Path $binRoot | Out-Null
            foreach ($binItem in @(Get-ChildItem -LiteralPath $child.FullName -Force)) {
                if ($binItem.Name -eq '986StorageShell.dll') { continue }
                $target = Join-Path $binRoot $binItem.Name
                if ($RepairMode) {
                    Copy-986MergeItem -Source $binItem.FullName -Destination $target
                } else {
                    if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
                    Copy-Item -LiteralPath $binItem.FullName -Destination $target -Recurse -Force
                }
            }
            continue
        }

        $target = Join-Path $storageRoot $child.Name
        if ($RepairMode) {
            Copy-986MergeItem -Source $child.FullName -Destination $target
        } else {
            if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
            Copy-Item -LiteralPath $child.FullName -Destination $target -Recurse -Force
        }
    }

    $safeTag = ($ReleaseTag -replace '[^A-Za-z0-9._-]', '_')
    $versionedShellDir = Join-Path $storageRoot ("versions\" + $safeTag)
    $versionedShell = Join-Path $versionedShellDir '986StorageShell.dll'
    New-Item -ItemType Directory -Force -Path $versionedShellDir | Out-Null

    if (Test-Path -LiteralPath $versionedShell -PathType Leaf) {
        $sourceHash = (Get-FileHash -LiteralPath $sourceShell -Algorithm SHA256).Hash
        $targetHash = (Get-FileHash -LiteralPath $versionedShell -Algorithm SHA256).Hash
        if ($sourceHash -ne $targetHash) {
            throw "Existing versioned Storage shell does not match $ReleaseTag. Refusing to overwrite a possibly loaded DLL."
        }
    } else {
        Copy-Item -LiteralPath $sourceShell -Destination $versionedShell -Force
    }

    # Legacy fallback is created only once. Never replace it in-place because Explorer
    # may have this DLL loaded from releases prior to side-by-side shell deployment.
    $legacyShell = Join-Path $storageRoot 'bin\986StorageShell.dll'
    if (-not (Test-Path -LiteralPath $legacyShell -PathType Leaf)) {
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $legacyShell) | Out-Null
        Copy-Item -LiteralPath $sourceShell -Destination $legacyShell -Force
    }

    # Migrate an existing 986-owned registration to the immutable versioned path.
    # Explorer may continue using the already-loaded old DLL until it naturally restarts;
    # the bootstrap deliberately does not force-restart Explorer.
    $classRoot = 'HKCU:\Software\Classes\CLSID\{5FCCE720-D806-4B6A-A5F1-F060344FC88D}'
    if (Test-Path $classRoot) {
        $owned = $false
        try {
            $owned = ((Get-ItemProperty -Path $classRoot -Name '986Owner' -ErrorAction Stop).'986Owner' -eq 'AbeyyTechXy/986-Windows-Utility')
        } catch { }
        if ($owned) {
            $inproc = Join-Path $classRoot 'InprocServer32'
            if (Test-Path $inproc) {
                Set-Item -Path $inproc -Value ([IO.Path]::GetFullPath($versionedShell))
                Write-Host '986 Storage shell registration migrated to the versioned payload. Explorer restart is not forced.' -ForegroundColor DarkGray
            }
        }
    }

    return $versionedShell
}

$stage = Join-Path $env:TEMP ('986-Windows-Utility-bootstrap-' + [guid]::NewGuid().ToString('N'))
$downloadDir = Join-Path $stage 'download'
$extractDir = Join-Path $stage 'extract'
New-Item -ItemType Directory -Force -Path $downloadDir,$extractDir | Out-Null

try {
    Write-Host 'Resolving latest stable 986 Windows Utility release...' -ForegroundColor Cyan
    $release = Invoke-RestMethod -UseBasicParsing -Uri $api -Headers $headers
    if (-not $release -or $release.draft -or $release.prerelease) {
        throw 'GitHub latest release is unavailable or is not stable.'
    }

    $zipAsset = @($release.assets | Where-Object { $_.name -match '^986-Windows-Utility-v.+\.zip$' }) | Select-Object -First 1
    $sumAsset = @($release.assets | Where-Object { $_.name -match '^SHA256SUMS-v.+\.txt$' }) | Select-Object -First 1
    if (-not $zipAsset -or -not $sumAsset) {
        throw 'Latest release is missing the ZIP or SHA256SUMS asset.'
    }

    $installedVersion = Get-986InstalledVersion -Root $InstallDir
    $releaseVersion = ([string]$release.tag_name) -replace '^[vV]', ''
    $repairMode = (-not [string]::IsNullOrWhiteSpace($installedVersion) -and $installedVersion -eq $releaseVersion)

    if ($repairMode) {
        Write-Host "Current stable $($release.tag_name) detected; verifying and repairing in place..." -ForegroundColor Cyan
    } else {
        Write-Host "Downloading $($release.tag_name)..." -ForegroundColor Cyan
    }

    $zipPath = Join-Path $downloadDir $zipAsset.name
    $sumPath = Join-Path $downloadDir $sumAsset.name
    Invoke-WebRequest -UseBasicParsing -Uri $zipAsset.browser_download_url -OutFile $zipPath -Headers $headers
    Invoke-WebRequest -UseBasicParsing -Uri $sumAsset.browser_download_url -OutFile $sumPath -Headers $headers

    $sumLine = @(Get-Content -Path $sumPath -Encoding ASCII | Where-Object { $_ -match [regex]::Escape($zipAsset.name) }) | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($sumLine)) {
        throw 'Release checksum file does not contain the downloaded ZIP.'
    }

    $expected = (($sumLine.Trim() -split '\s+')[0]).ToLowerInvariant()
    $actual = ((Get-FileHash -Path $zipPath -Algorithm SHA256).Hash).ToLowerInvariant()
    if ($actual -ne $expected) {
        throw "Release checksum mismatch. Expected $expected but got $actual."
    }
    Write-Host 'SHA256 verified.' -ForegroundColor Green

    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractDir -Force
    $packageRoot = @(Get-ChildItem -Path $extractDir -Directory | Where-Object {
        Test-Path (Join-Path $_.FullName '986-Windows-Utility.ps1')
    }) | Select-Object -First 1
    if (-not $packageRoot) {
        if (Test-Path (Join-Path $extractDir '986-Windows-Utility.ps1')) {
            $packageRoot = Get-Item $extractDir
        } else {
            throw 'Release package root could not be located.'
        }
    }

    $required = @(
        '986-Windows-Utility.ps1',
        'modules\TweakIntelligence.ps1',
        'modules\Doctor.ps1',
        'modules\Profiles.ps1',
        'modules\UpdateCenter.ps1',
        'display\ResolutionManager.ps1',
        'display\ResolutionUi.ps1',
        'display\986ResolutionHelper.exe',
        'storage\registration\Register-StorageView.ps1',
        'storage\bin\986StorageShell.dll',
        'storage\bin\986StorageScanner.exe'
    )
    foreach ($relative in $required) {
        if (-not (Test-Path (Join-Path $packageRoot.FullName $relative))) {
            throw "Release package is incomplete: missing $relative"
        }
    }

    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
    $stateDir = Join-Path $InstallDir 'state'
    New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

    foreach ($item in @(Get-ChildItem -Path $packageRoot.FullName -Force)) {
        if ($item.Name -eq 'state') { continue }

        if ($item.Name -eq 'storage' -and $item.PSIsContainer) {
            [void](Install-986StoragePayload -SourceStorage $item.FullName -Root $InstallDir -ReleaseTag ([string]$release.tag_name) -RepairMode $repairMode)
            continue
        }

        $destination = Join-Path $InstallDir $item.Name
        if ($repairMode) {
            Copy-986MergeItem -Source $item.FullName -Destination $destination
        } else {
            if (Test-Path -LiteralPath $destination) {
                Remove-Item -LiteralPath $destination -Recurse -Force
            }
            Copy-Item -LiteralPath $item.FullName -Destination $destination -Recurse -Force
        }
    }

    $app = Join-Path $InstallDir '986-Windows-Utility.ps1'
    $modeText = if ($repairMode) { 'Verified/repaired' } else { 'Installed' }
    Write-Host "$modeText $($release.tag_name) at $InstallDir" -ForegroundColor DarkGray

    if (-not $NoLaunch) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $app
    }
} finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}
