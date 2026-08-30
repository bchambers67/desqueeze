namespace DesqueezeWindows.Models;

/// <summary>
/// Anamorphic squeeze factors. Kept in lockstep with the macOS app's
/// <c>SqueezePreset</c> so both clients offer the same glass.
/// </summary>
public enum SqueezePreset
{
    X125, X133, X150, X155, X160, X165, X175, X180, X200, Custom
}

public static class SqueezePresets
{
    /// <summary>Preset, display label, factor, and the glass it corresponds to.</summary>
    public static readonly (SqueezePreset Preset, string Label, double? Factor, string Hint)[] All =
    [
        (SqueezePreset.X125,   "1.25×",  1.25, "ULTRA STARLESS"),
        (SqueezePreset.X133,   "1.33×",  1.33, "HAWK · LOMO"),
        (SqueezePreset.X150,   "1.50×",  1.50, "SLR MAGIC"),
        (SqueezePreset.X155,   "1.55×",  1.55, "IRON GLASS"),
        (SqueezePreset.X160,   "1.60×",  1.60, "VAZEN"),
        (SqueezePreset.X165,   "1.65×",  1.65, "COOKE SF"),
        (SqueezePreset.X175,   "1.75×",  1.75, "ATLAS MERCURY"),
        (SqueezePreset.X180,   "1.80×",  1.80, "KOWA · ISCO"),
        (SqueezePreset.X200,   "2.00×",  2.00, "FULL 2× GLASS"),
        (SqueezePreset.Custom, "Custom", null, ""),
    ];

    public static string LabelFor(SqueezePreset preset)
        => Array.Find(All, x => x.Preset == preset).Label;

    public static double? FactorFor(SqueezePreset preset)
        => Array.Find(All, x => x.Preset == preset).Factor;

    public static string HintFor(SqueezePreset preset)
        => Array.Find(All, x => x.Preset == preset).Hint ?? string.Empty;
}
