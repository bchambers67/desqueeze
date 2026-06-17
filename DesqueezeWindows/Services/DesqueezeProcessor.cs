using Avalonia.Media.Imaging;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Jpeg;
using SixLabors.ImageSharp.Formats.Png;
using SixLabors.ImageSharp.Formats.Tiff;
using SixLabors.ImageSharp.Metadata.Profiles.Exif;
using SixLabors.ImageSharp.Processing;

namespace DesqueezeWindows.Services;

public static class DesqueezeProcessor
{
    private static readonly string[] SupportedExtensions =
        [".jpg", ".jpeg", ".png", ".tif", ".tiff", ".heic", ".bmp", ".webp"];

    public static bool IsSupported(string path) =>
        SupportedExtensions.Contains(
            Path.GetExtension(path).ToLowerInvariant());

    /// <summary>
    /// Returns an Avalonia Bitmap for preview plus the output pixel dimensions.
    /// </summary>
    public static async Task<(Bitmap Preview, int Width, int Height)> ProcessForPreviewAsync(
        string sourcePath, double factor)
    {
        using var source = await Image.LoadAsync(sourcePath);
        int newW = Math.Max(1, (int)Math.Round(source.Width * factor));
        int newH = source.Height;

        using var processed = source.Clone(ctx =>
            ctx.Resize(new ResizeOptions
            {
                Size = new Size(newW, newH),
                Mode = ResizeMode.Stretch,
                Sampler = KnownResamplers.Lanczos3,
            }));

        using var ms = new MemoryStream();
        await processed.SaveAsPngAsync(ms);
        ms.Position = 0;
        return (new Bitmap(ms), newW, newH);
    }

    /// <summary>
    /// Desqueezes and exports, preserving EXIF/XMP/IPTC metadata from the source.
    /// </summary>
    public static async Task ExportAsync(string sourcePath, string destPath, double factor)
    {
        using var source = await Image.LoadAsync(sourcePath);

        var exifProfile = source.Metadata.ExifProfile?.DeepClone();
        var xmpProfile  = source.Metadata.XmpProfile;
        var iptcProfile = source.Metadata.IptcProfile;

        int newW = Math.Max(1, (int)Math.Round(source.Width * factor));
        int newH = source.Height;

        using var processed = source.Clone(ctx =>
            ctx.Resize(new ResizeOptions
            {
                Size = new Size(newW, newH),
                Mode = ResizeMode.Stretch,
                Sampler = KnownResamplers.Lanczos3,
            }));

        // Update pixel-dimension tags so stored metadata stays consistent.
        if (exifProfile != null)
        {
            exifProfile.SetValue(ExifTag.PixelXDimension, (uint)newW);
            exifProfile.SetValue(ExifTag.PixelYDimension, (uint)newH);
            processed.Metadata.ExifProfile = exifProfile;
        }
        if (xmpProfile  != null) processed.Metadata.XmpProfile  = xmpProfile;
        if (iptcProfile != null) processed.Metadata.IptcProfile = iptcProfile;

        var ext = Path.GetExtension(destPath).ToLowerInvariant();
        switch (ext)
        {
            case ".png":
                await processed.SaveAsPngAsync(destPath);
                break;
            case ".tif":
            case ".tiff":
                await processed.SaveAsTiffAsync(destPath);
                break;
            default:
                await processed.SaveAsJpegAsync(destPath, new JpegEncoder { Quality = 92 });
                break;
        }
    }
}
