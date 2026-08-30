using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace DesqueezeWindows;

/// <summary>
/// Collapses when the bound boolean is <c>true</c>.
/// </summary>
/// <remarks>
/// WPF's built-in <see cref="BooleanToVisibilityConverter"/> takes no parameter,
/// so a <c>ConverterParameter=Inverse</c> is silently ignored and the drop zone
/// stays visible underneath the preview. This is the real inverse.
/// </remarks>
public class InverseBoolToVisibilityConverter : IValueConverter
{
    public object Convert(object value, Type targetType, object parameter, CultureInfo culture)
        => value is true ? Visibility.Collapsed : Visibility.Visible;

    public object ConvertBack(object value, Type targetType, object parameter, CultureInfo culture)
        => value is Visibility.Collapsed;
}
