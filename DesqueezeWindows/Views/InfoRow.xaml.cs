using System.Windows;
using System.Windows.Controls;

namespace DesqueezeWindows;

public partial class InfoRow : UserControl
{
    public static readonly DependencyProperty LabelProperty =
        DependencyProperty.Register(nameof(Label), typeof(string), typeof(InfoRow),
            new PropertyMetadata(string.Empty, (d, e) => ((InfoRow)d).LabelBlock.Text = e.NewValue as string ?? string.Empty));

    public static readonly DependencyProperty ValueProperty =
        DependencyProperty.Register(nameof(Value), typeof(string), typeof(InfoRow),
            new PropertyMetadata("—", (d, e) => ((InfoRow)d).ValueBlock.Text = e.NewValue as string ?? "—"));

    public string Label
    {
        get => (string)GetValue(LabelProperty);
        set => SetValue(LabelProperty, value);
    }

    public string Value
    {
        get => (string)GetValue(ValueProperty);
        set => SetValue(ValueProperty, value);
    }

    public InfoRow() => InitializeComponent();
}
