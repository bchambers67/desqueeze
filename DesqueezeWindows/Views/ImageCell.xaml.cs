using System.Windows;
using System.Windows.Controls;
using System.Windows.Media.Imaging;

namespace DesqueezeWindows;

public partial class ImageCell : UserControl
{
    public static readonly DependencyProperty ImageSourceProperty =
        DependencyProperty.Register(nameof(ImageSource), typeof(BitmapSource), typeof(ImageCell),
            new PropertyMetadata(null, OnImageSourceChanged));

    public static readonly DependencyProperty LabelProperty =
        DependencyProperty.Register(nameof(Label), typeof(string), typeof(ImageCell),
            new PropertyMetadata(string.Empty, OnLabelChanged));

    public static readonly DependencyProperty IsProcessingProperty =
        DependencyProperty.Register(nameof(IsProcessing), typeof(bool), typeof(ImageCell),
            new PropertyMetadata(false, OnIsProcessingChanged));

    public BitmapSource? ImageSource
    {
        get => (BitmapSource?)GetValue(ImageSourceProperty);
        set => SetValue(ImageSourceProperty, value);
    }

    public string Label
    {
        get => (string)GetValue(LabelProperty);
        set => SetValue(LabelProperty, value);
    }

    public bool IsProcessing
    {
        get => (bool)GetValue(IsProcessingProperty);
        set => SetValue(IsProcessingProperty, value);
    }

    public ImageCell() => InitializeComponent();

    private static void OnImageSourceChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        var cell = (ImageCell)d;
        cell.PreviewImage.Source = e.NewValue as BitmapSource;
        cell.UpdatePlaceholder();
    }

    private static void OnLabelChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        => ((ImageCell)d).LabelText.Text = e.NewValue as string ?? string.Empty;

    private static void OnIsProcessingChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
        => ((ImageCell)d).UpdatePlaceholder();

    private void UpdatePlaceholder()
    {
        bool showPlaceholder = ImageSource == null;
        Placeholder.Visibility  = showPlaceholder ? Visibility.Visible   : Visibility.Collapsed;
        PreviewImage.Visibility = showPlaceholder ? Visibility.Collapsed : Visibility.Visible;

        // Inside the placeholder, the safelight progress bar shows only while
        // work is in flight; otherwise the cell rests on a single hairline.
        Spinner.Visibility   = IsProcessing ? Visibility.Visible   : Visibility.Collapsed;
        EmptyDash.Visibility = IsProcessing ? Visibility.Collapsed : Visibility.Visible;
    }
}
