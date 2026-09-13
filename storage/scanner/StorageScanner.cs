using System;
using System.Collections.Generic;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;

[DataContract]
public sealed class CategoryBytes {
    [DataMember] public long Apps;
    [DataMember] public long Videos;
    [DataMember] public long Pictures;
    [DataMember] public long Documents;
    [DataMember] public long Audio;
    [DataMember] public long System;
    [DataMember] public long Other;
}

[DataContract]
public sealed class ScanReport {
    [DataMember] public string Root;
    [DataMember] public DateTime GeneratedUtc;
    [DataMember] public long Files;
    [DataMember] public long ScannedBytes;
    [DataMember] public int SkippedDirectories;
    [DataMember] public CategoryBytes Categories;
}

public static class StorageScanner {
    const int FindExInfoBasic = 1;
    const int FindExSearchNameMatch = 0;
    const int FindFirstExLargeFetch = 2;
    static readonly IntPtr InvalidHandle = new IntPtr(-1);

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct WIN32_FIND_DATA {
        public FileAttributes dwFileAttributes;
        public System.Runtime.InteropServices.ComTypes.FILETIME ftCreationTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME ftLastAccessTime;
        public System.Runtime.InteropServices.ComTypes.FILETIME ftLastWriteTime;
        public uint nFileSizeHigh;
        public uint nFileSizeLow;
        public uint dwReserved0;
        public uint dwReserved1;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 260)] public string cFileName;
        [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 14)] public string cAlternateFileName;
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr FindFirstFileExW(string lpFileName, int fInfoLevelId, out WIN32_FIND_DATA lpFindFileData,
        int fSearchOp, IntPtr lpSearchFilter, int dwAdditionalFlags);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool FindNextFileW(IntPtr hFindFile, out WIN32_FIND_DATA lpFindFileData);

    [DllImport("kernel32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    static extern bool FindClose(IntPtr hFindFile);

    static readonly HashSet<string> Video = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".mp4", ".mkv", ".mov", ".avi", ".webm", ".m4v", ".wmv" };
    static readonly HashSet<string> Picture = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".heic", ".tif", ".tiff", ".dng", ".raw" };
    static readonly HashSet<string> Document = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".pdf", ".txt", ".rtf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".csv", ".md", ".odt", ".ods", ".odp" };
    static readonly HashSet<string> Audio = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".mp3", ".flac", ".wav", ".m4a", ".aac", ".ogg", ".wma" };
    static readonly HashSet<string> App = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".exe", ".msi", ".msix", ".appx", ".appxbundle", ".dll" };

    static string Classify(string path) {
        string p = path.Replace('/', '\\').ToLowerInvariant();
        if (p.Contains("\\windows\\") || p.Contains("\\programdata\\microsoft\\windows\\")) return "System";
        if (p.Contains("\\program files\\") || p.Contains("\\program files (x86)\\") || p.Contains("\\windowsapps\\")) return "Apps";
        string ext = Path.GetExtension(path);
        if (Video.Contains(ext)) return "Videos";
        if (Picture.Contains(ext)) return "Pictures";
        if (Document.Contains(ext)) return "Documents";
        if (Audio.Contains(ext)) return "Audio";
        if (App.Contains(ext)) return "Apps";
        return "Other";
    }

    static void Add(CategoryBytes c, string category, long bytes) {
        switch (category) {
            case "Apps": c.Apps += bytes; break;
            case "Videos": c.Videos += bytes; break;
            case "Pictures": c.Pictures += bytes; break;
            case "Documents": c.Documents += bytes; break;
            case "Audio": c.Audio += bytes; break;
            case "System": c.System += bytes; break;
            default: c.Other += bytes; break;
        }
    }

    static IntPtr OpenDirectory(string dir, out WIN32_FIND_DATA data) {
        string pattern = Path.Combine(dir, "*");
        IntPtr h = FindFirstFileExW(pattern, FindExInfoBasic, out data, FindExSearchNameMatch, IntPtr.Zero, FindFirstExLargeFetch);
        if (h == InvalidHandle) {
            h = FindFirstFileExW(pattern, FindExInfoBasic, out data, FindExSearchNameMatch, IntPtr.Zero, 0);
        }
        return h;
    }

    static void ScanDirectory(string dir, Stack<string> pending, ScanReport report) {
        WIN32_FIND_DATA data;
        IntPtr h = OpenDirectory(dir, out data);
        if (h == InvalidHandle) {
            report.SkippedDirectories++;
            return;
        }
        try {
            bool more = true;
            while (more) {
                string name = data.cFileName;
                if (name != "." && name != "..") {
                    string full = Path.Combine(dir, name);
                    FileAttributes attrs = data.dwFileAttributes;
                    if ((attrs & FileAttributes.Directory) != 0) {
                        if ((attrs & FileAttributes.ReparsePoint) == 0) pending.Push(full);
                    } else {
                        long size = ((long)data.nFileSizeHigh << 32) | data.nFileSizeLow;
                        report.Files++;
                        report.ScannedBytes += size;
                        Add(report.Categories, Classify(full), size);
                    }
                }
                more = FindNextFileW(h, out data);
            }
        } finally {
            FindClose(h);
        }
    }

    public static ScanReport Scan(string root) {
        string full = Path.GetFullPath(root);
        if (!Directory.Exists(full)) throw new DirectoryNotFoundException(full);
        var report = new ScanReport { Root = full, GeneratedUtc = DateTime.UtcNow, Categories = new CategoryBytes() };
        var pending = new Stack<string>();
        pending.Push(full);
        while (pending.Count > 0) ScanDirectory(pending.Pop(), pending, report);
        return report;
    }

    static void WriteJson(ScanReport report, string output) {
        string parent = Path.GetDirectoryName(Path.GetFullPath(output));
        if (!string.IsNullOrEmpty(parent)) Directory.CreateDirectory(parent);
        string temp = output + ".tmp-" + Guid.NewGuid().ToString("N");
        var serializer = new DataContractJsonSerializer(typeof(ScanReport));
        using (var stream = File.Create(temp)) serializer.WriteObject(stream, report);
        if (File.Exists(output)) File.Delete(output);
        File.Move(temp, output);
    }

    public static int Main(string[] args) {
        if (args.Length < 1 || args.Length > 2) {
            Console.Error.WriteLine("Usage: 986StorageScanner.exe <root> [output.json]");
            return 2;
        }
        try {
            var report = Scan(args[0]);
            string output = args.Length == 2 ? args[1] : Path.Combine(Path.GetTempPath(), "986-storage.json");
            WriteJson(report, output);
            Console.WriteLine(output);
            return 0;
        } catch (Exception ex) {
            Console.Error.WriteLine(ex.Message);
            return 1;
        }
    }
}
