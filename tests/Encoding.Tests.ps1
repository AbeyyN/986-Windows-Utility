$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$utf8 = [System.Text.UTF8Encoding]::new($false, $true)
$extensions = '.md','.ps1','.yml','.yaml','.json','.txt','.cmd'
$badPrefixes = @(
    ([string][char]0x00C2),
    ([string][char]0x00E2 + [char]0x2020),
    ([string][char]0x00E2 + [char]0x20AC),
    ([string][char]0xFFFD)
)
$files = Get-ChildItem $root -Recurse -File | Where-Object {
    $_.FullName -notmatch '\\.git\\|\\release\\' -and
    ($extensions -contains $_.Extension.ToLowerInvariant() -or $_.Name -in '.editorconfig','.gitignore','.gitattributes')
}
foreach ($file in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($file.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        throw "UTF-8 BOM is not allowed: $($file.FullName)"
    }
    try { $text = $utf8.GetString($bytes) }
    catch { throw "Invalid UTF-8: $($file.FullName)" }
    foreach ($bad in $badPrefixes) {
        if ($text.Contains($bad)) { throw "Possible mojibake detected: $($file.FullName)" }
    }
}
Write-Host "PASS: $($files.Count) tracked text files are strict UTF-8 without mojibake." -ForegroundColor Green
