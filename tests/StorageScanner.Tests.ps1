$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$source = Join-Path $root 'storage\scanner\StorageScanner.cs'
if (-not (Test-Path $source)) { throw 'StorageScanner.cs missing.' }
$build = Join-Path $env:TEMP ('986-storage-test-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $build -Force | Out-Null
try {
    $exe = Join-Path $build '986StorageScanner.exe'
    $csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
    if (-not (Test-Path $csc)) { throw 'Framework64 csc.exe missing.' }
    & $csc /nologo /target:exe /out:$exe /r:System.Runtime.Serialization.dll $source
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $exe)) { throw 'Storage scanner compilation failed.' }

    $fixture = Join-Path $build 'fixture'
    New-Item -ItemType Directory -Path $fixture -Force | Out-Null
    $cases = @{
        'clip.mp4' = 11; 'photo.jpg' = 13; 'paper.pdf' = 17; 'song.mp3' = 19; 'tool.exe' = 23; 'blob.bin' = 29
    }
    foreach ($name in $cases.Keys) {
        $bytes = New-Object byte[] $cases[$name]
        [IO.File]::WriteAllBytes((Join-Path $fixture $name), $bytes)
    }
    $folderA = Join-Path $fixture 'FolderA'
    $folderB = Join-Path $fixture 'FolderB'
    New-Item -ItemType Directory -Path $folderA,$folderB -Force | Out-Null
    [IO.File]::WriteAllBytes((Join-Path $folderA 'large.bin'), (New-Object byte[] 101))
    [IO.File]::WriteAllBytes((Join-Path $folderB 'medium.bin'), (New-Object byte[] 67))
    $json = Join-Path $build 'scan.json'
    & $exe $fixture $json | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $json)) { throw 'Storage scanner execution failed.' }
    $report = Get-Content $json -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($report.Files -ne 8) { throw "Expected 8 files; got $($report.Files)." }
    if ($report.Categories.Videos -ne 11) { throw 'Video classification failed.' }
    if ($report.Categories.Pictures -ne 13) { throw 'Picture classification failed.' }
    if ($report.Categories.Documents -ne 17) { throw 'Document classification failed.' }
    if ($report.Categories.Audio -ne 19) { throw 'Audio classification failed.' }
    if ($report.Categories.Apps -ne 23) { throw 'App classification failed.' }
    if ($report.Categories.Other -ne 197) { throw 'Other classification failed.' }
    if (-not $report.TopFiles -or $report.TopFiles.Count -lt 3) { throw 'TopFiles intelligence output missing.' }
    if ($report.TopFiles[0].Bytes -ne 101 -or $report.TopFiles[0].Path -notmatch 'large\.bin$') { throw 'TopFiles ranking failed.' }
    if (-not $report.TopFolders -or $report.TopFolders.Count -lt 2) { throw 'TopFolders intelligence output missing.' }
    if ($report.TopFolders[0].Bytes -ne 101 -or $report.TopFolders[0].Path -notmatch 'FolderA$') { throw 'TopFolders ranking failed.' }
    if ($null -eq $report.Recommendations) { throw 'Recommendations collection missing.' }
    if ([string]::IsNullOrWhiteSpace([string]$report.TopFile1Path) -or $report.TopFile1Path -notmatch 'large\.bin$') { throw 'TopFile1Path output missing or incorrect.' }
    if ([string]::IsNullOrWhiteSpace([string]$report.TopFolder1Path) -or $report.TopFolder1Path -notmatch 'FolderA$') { throw 'TopFolder1Path output missing or incorrect.' }
    $progress = Join-Path $build 'progress.json'
    & $exe $fixture $json $progress | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $progress)) { throw 'Storage scanner progress output missing.' }
    $progressData = Get-Content $progress -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($progressData.Files -ne 8 -or $progressData.ScannedBytes -le 0) { throw 'Storage scanner progress counters invalid.' }
    if ([string]::IsNullOrWhiteSpace([string]$progressData.CurrentDirectory)) { throw 'Storage scanner progress current-directory output missing.' }
    if (-not $report.TopFilesPreview -or $report.TopFilesPreview -notmatch 'large\.bin') { throw 'TopFiles preview missing.' }
    if (-not $report.TopFoldersPreview -or $report.TopFoldersPreview -notmatch 'FolderA') { throw 'TopFolders preview missing.' }
    if (-not $report.RecommendationPreview) { throw 'Recommendation preview missing.' }
    $scannerSourceText = Get-Content $source -Raw -Encoding UTF8
foreach ($nativeMarker in 'FindFirstFileExW','FindNextFileW','WIN32_FIND_DATA','FindFirstExLargeFetch','nFileSizeHigh','nFileSizeLow') {
    if ($scannerSourceText -notmatch [regex]::Escape($nativeMarker)) { throw "Missing native scanner marker: $nativeMarker" }
}
if ($scannerSourceText -notmatch [regex]::Escape('Path.Combine(ctx.RootPrefix, first)')) { throw 'Drive-root TopFolders path must stay absolute.' }
foreach ($slowMarker in 'Directory.EnumerateFiles','new FileInfo(') {
    if ($scannerSourceText -match [regex]::Escape($slowMarker)) { throw "Legacy per-file managed enumeration remains: $slowMarker" }
}
Write-Host 'PASS: Storage scanner compiles, classifies bytes and emits deterministic Storage Intelligence rankings.' -ForegroundColor Green
} finally {
    Remove-Item $build -Recurse -Force -ErrorAction SilentlyContinue
}
