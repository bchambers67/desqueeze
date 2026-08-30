using System.IO;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;

namespace DesqueezeWindows.Services;

/// <summary>
/// The image operation itself: widen by the squeeze factor, height untouched.
/// Stateless, so the single-image and batch paths share one code path.
/// </summary>
public static class DesqueezeProcessor
{
    public static BitmapSource Load(string path)
    {
        var bmp = new BitmapImage();
        bmp.BeginInit();
        bmp.UriSource     = new Uri(path);
        bmp.CacheOption   = BitmapCacheOption.OnLoad;
        bmp.CreateOptions = BitmapCreateOptions.PreservePixelFormat;
        bmp.EndInit();
        bmp.Freeze();
        return bmp;
    }

    /// <summary>Scales <paramref name="source"/> horizontally by <paramref name="factor"/>.</summary>
    public static BitmapSource Desqueeze(BitmapSource source, double factor)
    {
        int newWidth  = (int)Math.Round(source.PixelWidth * factor);
        int newHeight = source.PixelHeight;

        var visual = new DrawingVisual();
        RenderOptions.SetBitmapScalingMode(visual, BitmapScalingMode.HighQuality);
        using (var dc = visual.RenderOpen())
        {
            dc.DrawImage(source, new Rect(0, 0, newWidth, newHeight));
        }

        var rtb = new RenderTargetBitmap(
            newWidth, newHeight, source.DpiX, source.DpiY, PixelFormats.Pbgra32);
        rtb.Render(visual);
        rtb.Freeze();
        return rtb;
    }

    /// <summary>Encoder chosen from the target extension; JPEG is the fallback.</summary>
    public static void Save(BitmapSource image, string path)
    {
        BitmapEncoder encoder = Path.GetExtension(path).ToLowerInvariant() switch
        {
            ".png"            => new PngBitmapEncoder(),
            ".tif" or ".tiff" => new TiffBitmapEncoder(),
            _                 => new JpegBitmapEncoder { QualityLevel = 92 },
        };

        encoder.Frames.Add(BitmapFrame.Create(image));

        var dir = Path.GetDirectoryName(path);
        if (!string.IsNullOrEmpty(dir)) Directory.CreateDirectory(dir);

        using var fs = new FileStream(path, FileMode.Create, FileAccess.Write);
        encoder.Save(fs);
    }

    /// <summary>Reads, de-squeezes, and writes one file. Safe to call off the UI thread.</summary>
    public static void ProcessFile(string sourcePath, string destPath, double factor)
        => Save(Desqueeze(Load(sourcePath), factor), destPath);
}
