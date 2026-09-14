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
    'User-Agent' = '986-Windows-Utility-Bootstrap/1.0'
}

if ([string]::IsNullOrWhiteSpace($InstallDir)) {
    $InstallDir = Join-Path $env:LOCALAPPDATA 'AbeyyTechXy\986-Windows-Utility'
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

    $zipPath = Join-Path $downloadDir $zipAsset.name
    $sumPath = Join-Path $downloadDir $sumAsset.name

    Write-Host "Downloading $($release.tag_name)..." -ForegroundColor Cyan
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
        $destination = Join-Path $InstallDir $item.Name
        if (Test-Path -LiteralPath $destination) {
            Remove-Item -LiteralPath $destination -Recurse -Force
        }
        Copy-Item -LiteralPath $item.FullName -Destination $destination -Recurse -Force
    }

    $app = Join-Path $InstallDir '986-Windows-Utility.ps1'
    Write-Host "Installed $($release.tag_name) to $InstallDir" -ForegroundColor DarkGray

    if (-not $NoLaunch) {
        & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $app
    }
} finally {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
}
