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
public sealed class StorageEntry {
    [DataMember] public string Path;
    [DataMember] public long Bytes;
}

[DataContract]
public sealed class CleanupRecommendation {
    [DataMember] public string Code;
    [DataMember] public string Title;
    [DataMember] public string Path;
    [DataMember] public long Bytes;
    [DataMember] public string Detail;
}

[DataContract]
public sealed class ScanReport {
    [DataMember] public string Root;
    [DataMember] public DateTime GeneratedUtc;
    [DataMember] public long Files;
    [DataMember] public long ScannedBytes;
    [DataMember] public int SkippedDirectories;
    [DataMember] public CategoryBytes Categories;
    [DataMember] public List<StorageEntry> TopFiles;
    [DataMember] public List<StorageEntry> TopFolders;
    [DataMember] public List<CleanupRecommendation> Recommendations;
    [DataMember] public string TopFilesPreview;
    [DataMember] public string TopFoldersPreview;
    [DataMember] public string RecommendationPreview;
}

sealed class ScanContext {
    public string Root;
    public string RootPrefix;
    public readonly Dictionary<string,long> RootFolders = new Dictionary<string,long>(StringComparer.OrdinalIgnoreCase);
    public string Downloads;
    public string Temp;
    public string RecycleBin;
    public long DownloadsBytes;
    public long TempBytes;
    public long RecycleBinBytes;
}

public static class StorageScanner {
    const int FindExInfoBasic = 1;
    const int FindExSearchNameMatch = 0;
    const int FindFirstExLargeFetch = 2;
    const long OneMb = 1024L * 1024L;
    const long OneGb = 1024L * 1024L * 1024L;
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

    [DllImport("kernel32.dll", SetLastError = true)]
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

    static string WithTrailingSeparator(string path) {
        if (string.IsNullOrEmpty(path)) return path;
        char last = path[path.Length - 1];
        return (last == '\\' || last == '/') ? path : path + Path.DirectorySeparatorChar;
    }

    static bool IsAtOrUnder(string path, string candidate) {
        if (string.IsNullOrEmpty(candidate)) return false;
        if (string.Equals(path, candidate, StringComparison.OrdinalIgnoreCase)) return true;
        return path.StartsWith(WithTrailingSeparator(candidate), StringComparison.OrdinalIgnoreCase);
    }

    static void TrackTopFile(ScanReport report, string path, long bytes) {
        report.TopFiles.Add(new StorageEntry { Path = path, Bytes = bytes });
        report.TopFiles.Sort(delegate(StorageEntry a, StorageEntry b) { return b.Bytes.CompareTo(a.Bytes); });
        if (report.TopFiles.Count > 10) report.TopFiles.RemoveRange(10, report.TopFiles.Count - 10);
    }

    static void TrackRootFolder(ScanContext ctx, string file, long bytes) {
        if (!file.StartsWith(ctx.RootPrefix, StringComparison.OrdinalIgnoreCase)) return;
        string relative = file.Substring(ctx.RootPrefix.Length);
        int slash = relative.IndexOf(Path.DirectorySeparatorChar);
        if (slash <= 0) return;
        string first = relative.Substring(0, slash);
        string folder = Path.Combine(ctx.RootPrefix, first);
        long current;
        ctx.RootFolders.TryGetValue(folder, out current);
        ctx.RootFolders[folder] = current + bytes;
    }

    static void TrackReviewCandidates(ScanContext ctx, string file, long bytes) {
        if (IsAtOrUnder(file, ctx.Downloads)) ctx.DownloadsBytes += bytes;
        if (IsAtOrUnder(file, ctx.Temp)) ctx.TempBytes += bytes;
        if (IsAtOrUnder(file, ctx.RecycleBin)) ctx.RecycleBinBytes += bytes;
    }

    static IntPtr OpenDirectory(string dir, out WIN32_FIND_DATA data) {
        string pattern = Path.Combine(dir, "*");
        IntPtr h = FindFirstFileExW(pattern, FindExInfoBasic, out data, FindExSearchNameMatch, IntPtr.Zero, FindFirstExLargeFetch);
        if (h == InvalidHandle) h = FindFirstFileExW(pattern, FindExInfoBasic, out data, FindExSearchNameMatch, IntPtr.Zero, 0);
        return h;
    }

    static void ScanDirectory(string dir, Stack<string> pending, ScanReport report, ScanContext ctx) {
        WIN32_FIND_DATA data;
        IntPtr h = OpenDirectory(dir, out data);
        if (h == InvalidHandle) { report.SkippedDirectories++; return; }
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
                        TrackTopFile(report, full, size);
                        TrackRootFolder(ctx, full, size);
                        TrackReviewCandidates(ctx, full, size);
                    }
                }
                more = FindNextFileW(h, out data);
            }
        } finally { FindClose(h); }
    }

    static string PreviewBytes(long bytes) {
        if (bytes >= OneGb) return (bytes / (double)OneGb).ToString("0.0") + " GB";
        if (bytes >= OneMb) return (bytes / (double)OneMb).ToString("0.0") + " MB";
        return bytes.ToString() + " B";
    }

    static string BuildPreview(List<StorageEntry> items, bool files) {
        if (items == null || items.Count == 0) return "No data";
        var lines = new List<string>();
        int count = Math.Min(3, items.Count);
        for (int i = 0; i < count; i++) {
            string label = files ? Path.GetFileName(items[i].Path) : new DirectoryInfo(items[i].Path).Name;
            if (string.IsNullOrEmpty(label)) label = items[i].Path;
            lines.Add((i + 1).ToString() + ". " + label + " — " + PreviewBytes(items[i].Bytes));
        }
        return string.Join("\n", lines.ToArray());
    }

    static void FinalizeIntelligence(ScanReport report, ScanContext ctx) {
        foreach (KeyValuePair<string,long> kv in ctx.RootFolders) report.TopFolders.Add(new StorageEntry { Path = kv.Key, Bytes = kv.Value });
        report.TopFolders.Sort(delegate(StorageEntry a, StorageEntry b) { return b.Bytes.CompareTo(a.Bytes); });
        if (report.TopFolders.Count > 10) report.TopFolders.RemoveRange(10, report.TopFolders.Count - 10);

        if (ctx.DownloadsBytes >= OneGb) report.Recommendations.Add(new CleanupRecommendation {
            Code="REVIEW_DOWNLOADS", Title="Review Downloads", Path=ctx.Downloads, Bytes=ctx.DownloadsBytes,
            Detail="Large Downloads folder detected. Review files before removing anything."
        });
        if (ctx.TempBytes >= 512L * OneMb) report.Recommendations.Add(new CleanupRecommendation {
            Code="REVIEW_TEMP", Title="Review temporary files", Path=ctx.Temp, Bytes=ctx.TempBytes,
            Detail="Temporary files are using significant space. Review first; 986 does not delete them automatically."
        });
        if (ctx.RecycleBinBytes >= 512L * OneMb) report.Recommendations.Add(new CleanupRecommendation {
            Code="REVIEW_RECYCLE_BIN", Title="Review Recycle Bin", Path=ctx.RecycleBin, Bytes=ctx.RecycleBinBytes,
            Detail="Recycle Bin content is using significant space. Review before emptying it."
        });
        if (report.TopFiles.Count > 0 && report.TopFiles[0].Bytes >= OneGb) report.Recommendations.Add(new CleanupRecommendation {
            Code="REVIEW_LARGE_FILES", Title="Review very large files", Path=report.TopFiles[0].Path, Bytes=report.TopFiles[0].Bytes,
            Detail="One or more very large files were found. Confirm they are no longer needed before deletion."
        });
        report.Recommendations.Sort(delegate(CleanupRecommendation a, CleanupRecommendation b) { return b.Bytes.CompareTo(a.Bytes); });
        report.TopFilesPreview = BuildPreview(report.TopFiles, true);
        report.TopFoldersPreview = BuildPreview(report.TopFolders, false);
        report.RecommendationPreview = report.Recommendations.Count > 0
            ? report.Recommendations[0].Title + " — " + PreviewBytes(report.Recommendations[0].Bytes) + " | Review only; 986 never auto-deletes."
            : "No high-impact review items detected. 986 never auto-deletes.";
    }

    public static ScanReport Scan(string root) {
        string full = Path.GetFullPath(root);
        if (!Directory.Exists(full)) throw new DirectoryNotFoundException(full);
        var report = new ScanReport {
            Root = full, GeneratedUtc = DateTime.UtcNow, Categories = new CategoryBytes(),
            TopFiles = new List<StorageEntry>(), TopFolders = new List<StorageEntry>(), Recommendations = new List<CleanupRecommendation>()
        };
        string user = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var ctx = new ScanContext {
            Root = full.TrimEnd(Path.DirectorySeparatorChar), RootPrefix = WithTrailingSeparator(full),
            Downloads = string.IsNullOrEmpty(user) ? null : Path.Combine(user, "Downloads"),
            Temp = Path.GetFullPath(Path.GetTempPath()).TrimEnd(Path.DirectorySeparatorChar),
            RecycleBin = Path.Combine(Path.GetPathRoot(full), "$Recycle.Bin")
        };
        var pending = new Stack<string>();
        pending.Push(full);
        while (pending.Count > 0) ScanDirectory(pending.Pop(), pending, report, ctx);
        FinalizeIntelligence(report, ctx);
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
        if (args.Length < 1 || args.Length > 2) { Console.Error.WriteLine("Usage: 986StorageScanner.exe <root> [output.json]"); return 2; }
        try {
            var report = Scan(args[0]);
            string output = args.Length == 2 ? args[1] : Path.Combine(Path.GetTempPath(), "986-storage.json");
            WriteJson(report, output);
            Console.WriteLine(output);
            return 0;
        } catch (Exception ex) { Console.Error.WriteLine(ex.Message); return 1; }
    }
}
