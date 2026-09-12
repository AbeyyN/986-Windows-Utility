using System;
using System.Collections.Generic;
using System.IO;
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
    static readonly HashSet<string> Video = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".mp4", ".mkv", ".mov", ".avi", ".webm", ".m4v", ".wmv" };
    static readonly HashSet<string> Picture = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".heic", ".tif", ".tiff", ".dng", ".raw" };
    static readonly HashSet<string> Document = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".pdf", ".txt", ".rtf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".csv", ".md", ".odt", ".ods", ".odp" };
    static readonly HashSet<string> Audio = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".mp3", ".flac", ".wav", ".m4a", ".aac", ".ogg", ".wma" };
    static readonly HashSet<string> App = new HashSet<string>(StringComparer.OrdinalIgnoreCase) { ".exe", ".msi", ".msix", ".appx", ".appxbundle", ".dll" };

    static string Classify(string path) {
        string p = path.Replace('/', '\').ToLowerInvariant();
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

    public static ScanReport Scan(string root) {
        string full = Path.GetFullPath(root);
        if (!Directory.Exists(full)) throw new DirectoryNotFoundException(full);
        var report = new ScanReport { Root = full, GeneratedUtc = DateTime.UtcNow, Categories = new CategoryBytes() };
        var pending = new Stack<string>();
        pending.Push(full);
        while (pending.Count > 0) {
            string dir = pending.Pop();
            try {
                foreach (string file in Directory.EnumerateFiles(dir)) {
                    try {
                        var info = new FileInfo(file);
                        long size = info.Length;
                        report.Files++;
                        report.ScannedBytes += size;
                        Add(report.Categories, Classify(file), size);
                    } catch { }
                }
                foreach (string child in Directory.EnumerateDirectories(dir)) {
                    try {
                        var attrs = File.GetAttributes(child);
                        if ((attrs & FileAttributes.ReparsePoint) == 0) pending.Push(child);
                    } catch { report.SkippedDirectories++; }
                }
            } catch { report.SkippedDirectories++; }
        }
        return report;
    }

    static void WriteJson(ScanReport report, string output) {
        var serializer = new DataContractJsonSerializer(typeof(ScanReport));
        using (var stream = File.Create(output)) serializer.WriteObject(stream, report);
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
