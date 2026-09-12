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
    $json = Join-Path $build 'scan.json'
    & $exe $fixture $json | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $json)) { throw 'Storage scanner execution failed.' }
    $report = Get-Content $json -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($report.Files -ne 6) { throw "Expected 6 files; got $($report.Files)." }
    if ($report.Categories.Videos -ne 11) { throw 'Video classification failed.' }
    if ($report.Categories.Pictures -ne 13) { throw 'Picture classification failed.' }
    if ($report.Categories.Documents -ne 17) { throw 'Document classification failed.' }
    if ($report.Categories.Audio -ne 19) { throw 'Audio classification failed.' }
    if ($report.Categories.Apps -ne 23) { throw 'App classification failed.' }
    if ($report.Categories.Other -ne 29) { throw 'Other classification failed.' }
    Write-Host 'PASS: Storage scanner compiles and classifies deterministic fixture bytes.' -ForegroundColor Green
} finally {
    Remove-Item $build -Recurse -Force -ErrorAction SilentlyContinue
}
