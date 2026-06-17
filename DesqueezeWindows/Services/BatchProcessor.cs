namespace DesqueezeWindows.Services;

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
}
