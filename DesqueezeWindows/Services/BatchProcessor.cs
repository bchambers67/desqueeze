namespace DesqueezeWindows.Services;

/// <summary>
/// Folder enumeration for batch de-squeezing.
/// </summary>
public static class BatchProcessor
{
    private static readonly string[] ImageExtensions =
        [".jpg", ".jpeg", ".png", ".tif", ".tiff", ".heic", ".bmp", ".webp"];

    public static IEnumerable<string> GetImageFiles(string folderPath) =>
        Directory
            .EnumerateFiles(folderPath, "*", SearchOption.TopDirectoryOnly)
            .Where(f => ImageExtensions.Contains(
                Path.GetExtension(f).ToLowerInvariant()))
            .OrderBy(f => f, StringComparer.OrdinalIgnoreCase);

    public static bool IsSupported(string path) =>
        ImageExtensions.Contains(Path.GetExtension(path).ToLowerInvariant());
}
