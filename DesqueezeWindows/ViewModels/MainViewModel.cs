using Avalonia.Media.Imaging;
using DesqueezeWindows.Models;
using DesqueezeWindows.Services;
using SixLabors.ImageSharp;
using SixLabors.ImageSharp.Formats.Png;
using System.Collections.ObjectModel;
using System.Globalization;

namespace DesqueezeWindows.ViewModels;

public class MainViewModel : ViewModelBase
{
    // ── Mode ─────────────────────────────────────────────────────────────────
    private bool _isBatchMode;
    public bool IsBatchMode
    {
        get => _isBatchMode;
        set { SetField(ref _isBatchMode, value); OnPropertyChanged(nameof(IsSingleMode)); }
    }
    public bool IsSingleMode => !_isBatchMode;

    // ── Preset lists ─────────────────────────────────────────────────────────
    public IReadOnlyList<string> PresetLabels { get; } =
        SqueezePresets.All.Select(x => x.Label).ToArray();

    // ── Single-image state ───────────────────────────────────────────────────
    private string? _sourcePath;
    public string? SourcePath { get => _sourcePath; set => SetField(ref _sourcePath, value); }

    private Bitmap? _sourcePreview;
    public Bitmap? SourcePreview
    {
        get => _sourcePreview;
        set { SetField(ref _sourcePreview, value); OnPropertyChanged(nameof(HasImage)); OnPropertyChanged(nameof(NoImage)); }
    }

    private Bitmap? _processedPreview;
    public Bitmap? ProcessedPreview
    {
        get => _processedPreview;
        set => SetField(ref _processedPreview, value);
    }

    public bool HasImage => _sourcePreview != null;
    public bool NoImage  => _sourcePreview == null;

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

    private string _customFactor = "1.50";
    public string CustomFactor
    {
        get => _customFactor;
        set { SetField(ref _customFactor, value); OnPropertyChanged(nameof(ActiveFactor)); }
    }

    public bool IsCustom => _selectedPreset == SqueezePreset.Custom;

    public double ActiveFactor =>
        _selectedPreset == SqueezePreset.Custom
            ? (double.TryParse(_customFactor, NumberStyles.Any,
                               CultureInfo.InvariantCulture, out var v) ? v : 1.50)
            : SqueezePresets.FactorFor(_selectedPreset) ?? 1.50;

    private bool _isProcessing;
    public bool IsProcessing { get => _isProcessing; set { SetField(ref _isProcessing, value); OnPropertyChanged(nameof(IsIdle)); } }
    public bool IsIdle => !_isProcessing;

    private string? _errorMessage;
    public string? ErrorMessage { get => _errorMessage; set => SetField(ref _errorMessage, value); }

    private int _outputWidth;
    public int OutputWidth  { get => _outputWidth;  set { SetField(ref _outputWidth, value);  OnPropertyChanged(nameof(OutputInfo)); } }

    private int _outputHeight;
    public int OutputHeight { get => _outputHeight; set { SetField(ref _outputHeight, value); OnPropertyChanged(nameof(OutputInfo)); } }

    public string OutputInfo =>
        _outputWidth > 0 ? $"{_outputWidth} × {_outputHeight} px" : "";

    // ── Batch state ───────────────────────────────────────────────────────────
    public ObservableCollection<BatchItemViewModel> BatchItems { get; } = new();

    private int _bulkPresetIndex = 2; // 1.50×
    public int BulkPresetIndex
    {
        get => _bulkPresetIndex;
        set
        {
            if (!SetField(ref _bulkPresetIndex, value)) return;
            _bulkPreset = SqueezePresets.All[value].Preset;
            OnPropertyChanged(nameof(IsBulkCustom));
        }
    }
    private SqueezePreset _bulkPreset = SqueezePreset.X150;

    private string _bulkCustomFactor = "1.50";
    public string BulkCustomFactor { get => _bulkCustomFactor; set => SetField(ref _bulkCustomFactor, value); }
    public bool IsBulkCustom => _bulkPreset == SqueezePreset.Custom;

    private bool _isBatchProcessing;
    public bool IsBatchProcessing { get => _isBatchProcessing; set { SetField(ref _isBatchProcessing, value); OnPropertyChanged(nameof(IsBatchIdle)); } }
    public bool IsBatchIdle => !_isBatchProcessing;

    private int _batchProgress;
    public int BatchProgress { get => _batchProgress; set => SetField(ref _batchProgress, value); }

    private string? _batchStatus;
    public string? BatchStatus { get => _batchStatus; set => SetField(ref _batchStatus, value); }

    // ── Single-mode operations ────────────────────────────────────────────────
    public async Task LoadImageAsync(string path)
    {
        SourcePath = path;
        ErrorMessage = null;
        IsProcessing = true;
        ProcessedPreview = null;
        OutputWidth = 0;
        OutputHeight = 0;

        try
        {
            // Load a preview-size Bitmap directly (Avalonia handles common formats)
            SourcePreview = new Bitmap(path);
        }
        catch
        {
            // Fallback: decode via ImageSharp and render to PNG in memory
            try
            {
                using var img = await SixLabors.ImageSharp.Image.LoadAsync(path);
                using var ms  = new MemoryStream();
                await img.SaveAsPngAsync(ms);
                ms.Position   = 0;
                SourcePreview = new Bitmap(ms);
            }
            catch (Exception ex)
            {
                ErrorMessage  = $"Could not load image: {ex.Message}";
                IsProcessing  = false;
                return;
            }
        }

        await ProcessPreviewAsync();
    }

    public async Task ProcessPreviewAsync()
    {
        if (_sourcePath == null) return;
        IsProcessing = true;
        ErrorMessage = null;

        try
        {
            var (preview, w, h) = await DesqueezeProcessor.ProcessForPreviewAsync(
                _sourcePath, ActiveFactor);
            ProcessedPreview = preview;
            OutputWidth      = w;
            OutputHeight     = h;
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

    public void ClearImage()
    {
        SourcePath       = null;
        SourcePreview?.Dispose();
        ProcessedPreview?.Dispose();
        SourcePreview    = null;
        ProcessedPreview = null;
        ErrorMessage     = null;
        OutputWidth      = 0;
        OutputHeight     = 0;
    }

    // ── Batch operations ──────────────────────────────────────────────────────
    public void AddBatchFiles(IEnumerable<string> paths)
    {
        foreach (var path in paths)
        {
            if (!DesqueezeProcessor.IsSupported(path)) continue;
            if (BatchItems.Any(x => x.FilePath == path)) continue;
            BatchItems.Add(new BatchItemViewModel(path, _bulkPresetIndex)
            {
                CustomFactor = _bulkCustomFactor
            });
        }
    }

    public void AddBatchFolder(string folder) =>
        AddBatchFiles(BatchProcessor.GetImageFiles(folder));

    public void ApplyBulkFactor()
    {
        foreach (var item in BatchItems)
        {
            item.PresetIndex  = _bulkPresetIndex;
            item.CustomFactor = _bulkCustomFactor;
        }
    }

    public void ClearBatch()
    {
        BatchItems.Clear();
        BatchStatus   = null;
        BatchProgress = 0;
    }

    public async Task ExportBatchAsync(string outputFolder)
    {
        if (BatchItems.Count == 0) return;

        Directory.CreateDirectory(outputFolder);
        IsBatchProcessing = true;
        BatchProgress     = 0;
        BatchStatus       = "Exporting…";

        int total     = BatchItems.Count;
        int completed = 0;

        foreach (var item in BatchItems)
        {
            item.Status = BatchItemStatus.Processing;
            try
            {
                var ext      = Path.GetExtension(item.FilePath);
                var baseName = Path.GetFileNameWithoutExtension(item.FilePath);
                var dest     = Path.Combine(outputFolder, $"{baseName}_desqueezed{ext}");
                await DesqueezeProcessor.ExportAsync(item.FilePath, dest, item.ActiveFactor);
                item.Status = BatchItemStatus.Done;
            }
            catch (Exception ex)
            {
                item.Status       = BatchItemStatus.Error;
                item.ErrorMessage = ex.Message;
            }
            completed++;
            BatchProgress = (int)(100.0 * completed / total);
            BatchStatus   = $"{completed} / {total} exported";
        }

        BatchStatus       = $"Done — {completed} file{(completed == 1 ? "" : "s")} exported.";
        IsBatchProcessing = false;
    }
}
