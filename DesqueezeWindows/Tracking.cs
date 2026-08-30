using System.Text;
using System.Windows;
using System.Windows.Controls;

namespace DesqueezeWindows;

/// <summary>
/// Letter-spacing (tracking) for <see cref="TextBlock"/>.
/// </summary>
/// <remarks>
/// WPF has no letter-spacing primitive — <c>CharacterSpacing</c> exists only in
/// WinUI/UWP, and <c>Typography</c> exposes no equivalent. The brand sets
/// uppercase labels between .12em and .22em, so tracking is approximated by
/// interleaving Unicode fixed-width spaces, which is also literally how the
/// house lockup is set: <c>C H A M B E R S &amp; L I G H T</c>.
///
/// Approximate widths: HAIR SPACE (U+200A) ≈ .1em, THIN SPACE (U+2009) ≈ .2em.
///
/// The value resolves once, so apply it to static labels only — never to bound
/// text, which would lose its spacing on the next update.
/// </remarks>
public static class Track
{
    private const char Hair = ' ';   // ≈ .1em
    private const char Thin = ' ';   // ≈ .2em

    /// <summary>Tracking in em. Applied once, when the value is set.</summary>
    public static readonly DependencyProperty EmProperty =
        DependencyProperty.RegisterAttached(
            "Em", typeof(double), typeof(Track),
            new PropertyMetadata(0.0, OnEmChanged));

    public static void SetEm(DependencyObject d, double v) => d.SetValue(EmProperty, v);
    public static double GetEm(DependencyObject d) => (double)d.GetValue(EmProperty);

    private static readonly DependencyProperty AppliedProperty =
        DependencyProperty.RegisterAttached(
            "Applied", typeof(bool), typeof(Track), new PropertyMetadata(false));

    private static void OnEmChanged(DependencyObject d, DependencyPropertyChangedEventArgs e)
    {
        if (d is not TextBlock tb) return;

        // Text may not be assigned yet when the attached property is parsed,
        // so apply now and again once the element is loaded.
        Apply(tb);
        tb.Loaded += (_, _) => Apply(tb);
    }

    private static void Apply(TextBlock tb)
    {
        if ((bool)tb.GetValue(AppliedProperty)) return;

        string text = tb.Text;
        if (string.IsNullOrEmpty(text)) return;

        double em = GetEm(tb);
        if (em <= 0) return;

        tb.SetValue(AppliedProperty, true);
        tb.Text = Space(text, em);
    }

    /// <summary>
    /// Interleaves fixed-width spaces to approximate <paramref name="em"/> of
    /// tracking.
    /// </summary>
    public static string Space(string text, double em)
    {
        // Choose the filler whose width is closest to the requested tracking,
        // using two hair spaces where a single thin space would overshoot.
        string filler = em switch
        {
            >= 0.20 => Thin.ToString(),
            >= 0.14 => new string(Hair, 2),
            _       => Hair.ToString(),
        };

        var sb = new StringBuilder(text.Length * 2);
        for (int i = 0; i < text.Length; i++)
        {
            sb.Append(text[i]);
            if (i < text.Length - 1) sb.Append(filler);
        }
        return sb.ToString();
    }
}
