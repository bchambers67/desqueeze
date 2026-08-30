using System.Collections.ObjectModel;
using System.IO;
using System.Windows;
using System.Windows.Media.Imaging;
using DesqueezeWindows.Models;
using DesqueezeWindows.Services;

namespace DesqueezeWindows.ViewModels;

public class MainViewModel : ViewModelBase
{
    // ── Single image ────────────────────────────────────────────

    private BitmapSource? _sourceImage;
    private BitmapSource? _processedImage;
    private SqueezePreset _selectedPreset = SqueezePreset.X150;
    private string        _customFactor   = "1.33";
    private bool          _isProcessing;
    private string?       _errorMessage;
    private string?       _successMessage;

    // ── Batch ─────────────────────────────────────────────────

    private bool    _isBatchMode;
    private bool    _isBatchRunning;
    private int     _batchCompleted;
    private string? _batchFolder;

    public ObservableCollection<BatchItemViewModel> BatchItems { get; } = [];

    // ── Presets ─────────────────────────────────────────────

    public IReadOnlyList<SqueezePresetOption> Presets { get; } =
        SqueezePresets.All
            .Where(p => p.Preset != SqueezePreset.Custom)
            .Select(p => new SqueezePresetOption(p.Preset, p.Label, p.Hint))
            .ToList();

    public MainViewModel() => SyncPresetSelection();

    public SqueezePreset SelectedPreset
    {
        get => _selectedPreset;
        set
        {
            if (!Set(ref _selectedPreset, value)) return;
            SyncPresetSelection();
            Raise(nameof(ActiveFactor));
            Raise(nameof(FactorText));
            Raise(nameof(IsCustom));
            Raise(nameof(AspectRatioText));
            _ = ProcessAsync();
        }
    }

    /// <summary>Mirrors <see cref="SelectedPreset"/> onto the bound option rows.</summary>
    private void SyncPresetSelection()
    {
        foreach (var opt in Presets) opt.IsSelected = opt.Preset == _selectedPreset;
    }

    public string CustomFactor
    {
        get => _customFactor;
        set
        {
            if (!Set(ref _customFactor, value)) return;
            Raise(nameof(ActiveFactor));
            Raise(nameof(FactorText));
            Raise(nameof(AspectRatioText));
        }
    }

    public bool IsCustom => SelectedPreset == SqueezePreset.Custom;

    public double ActiveFactor =>
        SqueezePresets.FactorFor(SelectedPreset)
        ?? (double.TryParse(CustomFactor, out var v) && v > 0 ? v : 1.33);

    // ── Single-image state ──────────────────────────────────────

    public BitmapSource? SourceImage
    {
        get => _sourceImage;
        private set
        {
            if (!Set(ref _sourceImage, value)) return;
            Raise(nameof(HasImage));
            Raise(nameof(SourceSizeText));
            Raise(nameof(AspectRatioText));
        }
    }

    public BitmapSource? ProcessedImage
    {
        get => _processedImage;
        private set
        {
            if (!Set(ref _processedImage, value)) return;
            Raise(nameof(OutputSizeText));
            Raise(nameof(CanExport));
        }
    }

    public bool HasImage => _sourceImage is not null;

    public bool IsProcessing
    {
        get => _isProcessing;
        private set { if (Set(ref _isProcessing, value)) Raise(nameof(CanExport)); }
    }

    public string? ErrorMessage
    {
        get => _errorMessage;
        private set { if (Set(ref _errorMessage, value)) Raise(nameof(HasError)); }
    }

    public bool HasError => !string.IsNullOrEmpty(_errorMessage);

    public string? SuccessMessage
    {
        get => _successMessage;
        private set { if (Set(ref _successMessage, value)) Raise(nameof(HasSuccess)); }
    }

    public bool HasSuccess => !string.IsNullOrEmpty(_successMessage);

    public bool CanExport => ProcessedImage is not null && !IsProcessing;

    // ── Readouts ────────────────────────────────────────────

    public string SourceSizeText => SourceImage is null
        ? "—" : $"{SourceImage.PixelWidth} × {SourceImage.PixelHeight}";

    public string OutputSizeText => ProcessedImage is null
        ? "—" : $"{ProcessedImage.PixelWidth} × {ProcessedImage.PixelHeight}";

    public string FactorText => $"{ActiveFactor:F2}×";

    public string AspectRatioText => SourceImage is null
        ? "—"
        : $"{(SourceImage.PixelWidth * ActiveFactor) / SourceImage.PixelHeight:F2} : 1";

    // ── Batch state ───────────────────────────────────────────

    public bool IsBatchMode
    {
        get => _isBatchMode;
        set => Set(ref _isBatchMode, value);
    }

    public bool IsBatchRunning
    {
        get => _isBatchRunning;
        private set { if (Set(ref _isBatchRunning, value)) Raise(nameof(CanRunBatch)); }
    }

    public int BatchCompleted
    {
        get => _batchCompleted;
        private set { if (Set(ref _batchCompleted, value)) Raise(nameof(BatchProgressText)); }
    }

    public string? BatchFolder
    {
        get => _batchFolder;
        private set { if (Set(ref _batchFolder, value)) Raise(nameof(BatchFolderText)); }
    }

    public string BatchFolderText => BatchFolder is null ? "—" : Path.GetFileName(BatchFolder);

    public string BatchProgressText => BatchItems.Count == 0
        ? "—" : $"{BatchCompleted} / {BatchItems.Count}";

    public bool CanRunBatch => BatchItems.Count > 0 && !IsBatchRunning;

    // ── Load ────────────────────────────────────────────────

    public void LoadFromPath(string path)
    {
        try
        {
            SourceImage  = DesqueezeProcessor.Load(path);
            ErrorMessage = null;
            _ = ProcessAsync();
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Could not load image: {ex.Message}";
        }
    }

    public void LoadBatchFolder(string folder)
    {
        try
        {
            BatchItems.Clear();
            foreach (var f in BatchProcessor.GetImageFiles(folder))
                BatchItems.Add(new BatchItemViewModel(f));

            BatchFolder    = folder;
            BatchCompleted = 0;
            ErrorMessage   = BatchItems.Count == 0 ? "No supported images in that folder." : null;

            Raise(nameof(BatchProgressText));
            Raise(nameof(CanRunBatch));

            // Preview the first frame so the factor can be judged before running.
            if (BatchItems.Count > 0) LoadFromPath(BatchItems[0].SourcePath);
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Could not read folder: {ex.Message}";
        }
    }

    // ── Process ─────────────────────────────────────────────

    public async Task ProcessAsync()
    {
        if (SourceImage is null) return;

        IsProcessing = true;
        ErrorMessage = null;

        var src    = SourceImage;
        var factor = ActiveFactor;

        try
        {
            ProcessedImage = await Task.Run(() => DesqueezeProcessor.Desqueeze(src, factor));
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Processing failed: {ex.Message}";
        }
        finally
        {
            IsProcessing = false;
        }
    }

    // ── Export ─────────────────────────────────────────────

    public bool Export(string path)
    {
        if (ProcessedImage is null) return false;
        try
        {
            DesqueezeProcessor.Save(ProcessedImage, path);
            Flash("Saved");
            return true;
        }
        catch (Exception ex)
        {
            ErrorMessage = $"Export failed: {ex.Message}";
            return false;
        }
    }

    /// <summary>
    /// De-squeezes every queued file into <paramref name="destFolder"/>, one at a
    /// time so a large queue cannot exhaust memory. Per-item failures are recorded
    /// on the item and do not stop the run.
    /// </summary>
    public async Task RunBatchAsync(string destFolder, string extension = ".jpg")
    {
        if (BatchItems.Count == 0 || IsBatchRunning) return;

        IsBatchRunning = true;
        BatchCompleted = 0;
        ErrorMessage   = null;

        var factor = ActiveFactor;

        foreach (var item in BatchItems)
        {
            item.State = BatchItemState.Working;
            item.Error = null;

            try
            {
                var name = Path.GetFileNameWithoutExtension(item.SourcePath);
                var dest = Path.Combine(destFolder, $"{name}_desqueezed{extension}");
                var src  = item.SourcePath;

                await Task.Run(() => DesqueezeProcessor.ProcessFile(src, dest, factor));
                item.State = BatchItemState.Done;
            }
            catch (Exception ex)
            {
                item.State = BatchItemState.Failed;
                item.Error = ex.Message;
            }

            BatchCompleted++;
        }

        IsBatchRunning = false;

        int failed = BatchItems.Count(i => i.IsFailed);
        if (failed == 0) Flash($"Batch complete — {BatchItems.Count} images");
        else ErrorMessage = $"{failed} of {BatchItems.Count} images failed.";
    }

    // ── Helpers ────────────────────────────────────────────

    private void Flash(string message)
    {
        SuccessMessage = message;
        Task.Delay(3000).ContinueWith(_ =>
            Application.Current?.Dispatcher.Invoke(() =>
            {
                if (SuccessMessage == message) SuccessMessage = null;
            }));
    }

    public void Reset()
    {
        SourceImage    = null;
        ProcessedImage = null;
        ErrorMessage   = null;
        SuccessMessage = null;
        BatchItems.Clear();
        BatchFolder    = null;
        BatchCompleted = 0;
        Raise(nameof(BatchProgressText));
        Raise(nameof(CanRunBatch));
    }
}

/// <summary>One selectable preset row, bound by the preset list in the view.</summary>
public class SqueezePresetOption(SqueezePreset preset, string label, string hint) : ViewModelBase
{
    private bool _isSelected;

    public SqueezePreset Preset { get; } = preset;
    public string Label { get; } = label;
    public string Hint  { get; } = hint;

    public bool IsSelected
    {
        get => _isSelected;
        set => Set(ref _isSelected, value);
    }
}
