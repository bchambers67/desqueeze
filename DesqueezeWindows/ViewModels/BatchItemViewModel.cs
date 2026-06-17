using DesqueezeWindows.Models;

namespace DesqueezeWindows.ViewModels;

public enum BatchItemStatus { Pending, Processing, Done, Error }

public class BatchItemViewModel : ViewModelBase
{
    public string FilePath { get; }
    public string FileName => Path.GetFileName(FilePath);

    public IReadOnlyList<string> PresetLabels { get; } =
        SqueezePresets.All.Select(x => x.Label).ToArray();

    private int _presetIndex = 2; // 1.50× default
    public int PresetIndex
    {
        get => _presetIndex;
        set
        {
            if (!SetField(ref _presetIndex, value)) return;
            _selectedPreset = SqueezePresets.All[value].Preset;
            OnPropertyChanged(nameof(IsCustom));
            OnPropertyChanged(nameof(ActiveFactor));
        }
    }

    private SqueezePreset _selectedPreset = SqueezePreset.X150;
    public SqueezePreset SelectedPreset => _selectedPreset;

    private string _customFactor = "1.50";
    public string CustomFactor
    {
        get => _customFactor;
        set { SetField(ref _customFactor, value); OnPropertyChanged(nameof(ActiveFactor)); }
    }

    public bool IsCustom => _selectedPreset == SqueezePreset.Custom;

    public double ActiveFactor =>
        _selectedPreset == SqueezePreset.Custom
            ? (double.TryParse(_customFactor, System.Globalization.NumberStyles.Any,
                               System.Globalization.CultureInfo.InvariantCulture, out var v)
                ? v : 1.50)
            : SqueezePresets.FactorFor(_selectedPreset) ?? 1.50;

    private BatchItemStatus _status = BatchItemStatus.Pending;
    public BatchItemStatus Status { get => _status; set => SetField(ref _status, value); }

    private string? _errorMessage;
    public string? ErrorMessage { get => _errorMessage; set => SetField(ref _errorMessage, value); }

    public string StatusText => _status switch
    {
        BatchItemStatus.Processing => "⟳",
        BatchItemStatus.Done       => "✓",
        BatchItemStatus.Error      => "✗",
        _                          => "–",
    };

    public BatchItemViewModel(string filePath, int presetIndex = 2)
    {
        FilePath = filePath;
        PresetIndex = presetIndex;
    }

    public void SetPresetIndex(int index)
    {
        PresetIndex = index;
        OnPropertyChanged(nameof(StatusText));
    }
}
