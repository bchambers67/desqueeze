namespace DesqueezeWindows.Models;

public enum SqueezePreset
{
    X125, X133, X150, X155, X160, X165, X175, X180, X200, Custom
}

public static class SqueezePresets
{
    public static readonly (SqueezePreset Preset, string Label, double? Factor)[] All =
    [
        (SqueezePreset.X125,  "1.25×", 1.25),
        (SqueezePreset.X133,  "1.33×", 1.33),
        (SqueezePreset.X150,  "1.50×", 1.50),
        (SqueezePreset.X155,  "1.55×", 1.55),
        (SqueezePreset.X160,  "1.60×", 1.60),
        (SqueezePreset.X165,  "1.65×", 1.65),
        (SqueezePreset.X175,  "1.75×", 1.75),
        (SqueezePreset.X180,  "1.80×", 1.80),
        (SqueezePreset.X200,  "2.00×", 2.00),
        (SqueezePreset.Custom, "Custom", null),
    ];

    public static string LabelFor(SqueezePreset preset) =>
        Array.Find(All, x => x.Preset == preset).Label;

    public static double? FactorFor(SqueezePreset preset) =>
        Array.Find(All, x => x.Preset == preset).Factor;
}
