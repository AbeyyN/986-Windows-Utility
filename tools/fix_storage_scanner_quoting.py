from pathlib import Path

root = Path(__file__).resolve().parents[1]
cpp = root / 'storage' / 'shell' / 'StorageShell.cpp'
test = root / 'tests' / 'StorageShell.Tests.ps1'
changelog = root / 'CHANGELOG.md'

text = cpp.read_text(encoding='utf-8')
anchor = '''static std::wstring CachePath(const std::wstring& root) {
    wchar_t drive = root.empty() ? L'X' : root[0];
    std::wstring path = CacheDirectory();
    path += L"\\\\drive-";
    path.push_back(drive);
    path += L".json";
    return path;
}

static bool ReadUtf8File'''
replacement = '''static std::wstring CachePath(const std::wstring& root) {
    wchar_t drive = root.empty() ? L'X' : root[0];
    std::wstring path = CacheDirectory();
    path += L"\\\\drive-";
    path.push_back(drive);
    path += L".json";
    return path;
}

static std::wstring QuoteCommandLineArg(const std::wstring& arg) {
    if (arg.empty()) return L"\\\"\\\"";
    if (arg.find_first_of(L" \\t\\n\\v\\\"") == std::wstring::npos) return arg;
    std::wstring out = L"\\\"";
    size_t backslashes = 0;
    for (wchar_t ch : arg) {
        if (ch == L'\\\\') {
            ++backslashes;
            continue;
        }
        if (ch == L'\\\"') {
            out.append(backslashes * 2 + 1, L'\\\\');
            out.push_back(L'\\\"');
            backslashes = 0;
            continue;
        }
        out.append(backslashes, L'\\\\');
        backslashes = 0;
        out.push_back(ch);
    }
    out.append(backslashes * 2, L'\\\\');
    out.push_back(L'\\\"');
    return out;
}

static bool ReadUtf8File'''
if text.count(anchor) != 1:
    raise SystemExit('QuoteCommandLineArg insertion anchor missing or duplicated')
text = text.replace(anchor, replacement, 1)
old_cmd = '        std::wstring cmd = L"\\\"" + scanner + L"\\\" \\\"" + d.root + L"\\\" \\\"" + cache + L"\\\"";'
new_cmd = '        std::wstring cmd = QuoteCommandLineArg(scanner) + L" " + QuoteCommandLineArg(d.root) + L" " + QuoteCommandLineArg(cache);'
if text.count(old_cmd) != 1:
    raise SystemExit('scanner command-line anchor missing or duplicated')
text = text.replace(old_cmd, new_cmd, 1)
cpp.write_text(text, encoding='utf-8', newline='\n')

ps = test.read_text(encoding='utf-8')
anchor_test = "if ($cppText -match 'PtInRect\\(&d\\.scanButton') { throw 'Click dispatch must not depend on a paint-populated DriveCard hitbox.' }\n"
extra = anchor_test + "foreach ($marker in 'QuoteCommandLineArg','QuoteCommandLineArg(scanner)','QuoteCommandLineArg(d.root)','QuoteCommandLineArg(cache)') {\n    if ($cppText -notmatch [regex]::Escape($marker)) { throw \"Missing safe scanner command-line marker: $marker\" }\n}\nif ($cppText -match [regex]::Escape('L\"\\\\\" \" + d.root')) { throw 'Drive roots must not use naive quoted trailing-backslash command-line construction.' }\n"
if ps.count(anchor_test) != 1:
    raise SystemExit('StorageShell test insertion anchor missing or duplicated')
ps = ps.replace(anchor_test, extra, 1)
test.write_text(ps, encoding='utf-8', newline='\n')

cl = changelog.read_text(encoding='utf-8')
anchor_changelog = '- Scanner process launch now supplies the executable path and working directory explicitly and records Windows launch errors for the user-visible storage card.\n'
addition = anchor_changelog + '- Fixed Win32 command-line quoting for fixed-drive roots such as `C:\\`; trailing backslashes are no longer placed inside naive quotes that can corrupt scanner arguments.\n'
if cl.count(anchor_changelog) != 1:
    raise SystemExit('RC3 changelog anchor missing or duplicated')
cl = cl.replace(anchor_changelog, addition, 1)
changelog.write_text(cl, encoding='utf-8', newline='\n')

print('STORAGE_SCANNER_QUOTING_PATCHED')
