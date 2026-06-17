using Avalonia.Controls;
using Avalonia.Input;
using Avalonia.Interactivity;
using Avalonia.Platform.Storage;
using Avalonia.Threading;
using DesqueezeWindows.Services;
using DesqueezeWindows.ViewModels;

namespace DesqueezeWindows;

public partial class MainWindow : Window
{
    private MainViewModel VM => (MainViewModel)DataContext!;

    public MainWindow()
    {
        InitializeComponent();
        this.Loaded += OnLoaded;
    }

    private void OnLoaded(object? s, RoutedEventArgs e)
    {
        SetupDragDrop();
        VM.PropertyChanged += OnVmPropertyChanged;
        UpdatePreviewVisibility(VM);
        UpdateBatchListVisibility(VM);
    }

    // ── ViewModel subscriptions ───────────────────────────────────────────
    private void OnVmPropertyChanged(object? sender,
        System.ComponentModel.PropertyChangedEventArgs e)
    {
        var vm = VM;
        switch (e.PropertyName)
        {
            case nameof(MainViewModel.HasImage):
            case nameof(MainViewModel.NoImage):
                UpdatePreviewVisibility(vm);
                break;

            case nameof(MainViewModel.SourcePreview):
                BeforeImage.Source = vm.SourcePreview;
                break;

            case nameof(MainViewModel.ProcessedPreview):
                AfterImage.Source = vm.ProcessedPreview;
                break;

            case nameof(MainViewModel.IsProcessing):
                ProcessingBar.IsVisible     = vm.IsProcessing;
                SinglePresetCombo.IsEnabled = !vm.IsProcessing;
                CustomFactorBox.IsEnabled   = !vm.IsProcessing;
                break;

            case nameof(MainViewModel.OutputInfo):
                OutputInfoText.Text        = vm.OutputInfo;
                OutputInfoPanel.IsVisible  = vm.OutputWidth > 0;
                break;

            case nameof(MainViewModel.ErrorMessage):
                ErrorText.Text       = vm.ErrorMessage ?? "";
                ErrorPanel.IsVisible = !string.IsNullOrEmpty(vm.ErrorMessage);
                break;

            case nameof(MainViewModel.IsCustom):
                CustomFactorRow.IsVisible = vm.IsCustom;
                break;

            case nameof(MainViewModel.IsBulkCustom):
                BulkCustomRow.IsVisible = vm.IsBulkCustom;
                break;

            case nameof(MainViewModel.IsBatchProcessing):
                BatchProgressPanel.IsVisible = vm.IsBatchProcessing;
                BatchExportButton.IsEnabled  = !vm.IsBatchProcessing;
                BatchClearButton.IsEnabled   = !vm.IsBatchProcessing;
                break;

            case nameof(MainViewModel.BatchProgress):
                BatchProgressBar.Value = vm.BatchProgress;
                break;

            case nameof(MainViewModel.BatchStatus):
                if (vm.IsBatchProcessing)
                {
                    BatchProgressLabel.Text  = vm.BatchStatus ?? "";
                    BatchDoneLabel.IsVisible = false;
                }
                else
                {
                    BatchDoneLabel.Text      = vm.BatchStatus ?? "";
                    BatchDoneLabel.IsVisible = !string.IsNullOrEmpty(vm.BatchStatus);
                }
                break;
        }
    }

    private void UpdatePreviewVisibility(MainViewModel vm)
    {
        DropZone.IsVisible     = vm.NoImage;
        PreviewPanel.IsVisible = vm.HasImage;
        ExportButton.IsEnabled = vm.HasImage;
        ClearButton.IsEnabled  = vm.HasImage;
    }

    private void UpdateBatchListVisibility(MainViewModel vm)
    {
        bool hasItems             = vm.BatchItems.Count > 0;
        BatchEmptyState.IsVisible = !hasItems;
        BatchListBox.IsVisible    = hasItems;
        BatchCountLabel.Text      = hasItems ? $"{vm.BatchItems.Count} file(s)" : "";
    }

    // ── Drag-drop setup ───────────────────────────────────────────────────
    private void SetupDragDrop()
    {
        DragDrop.SetAllowDrop(DropZone, true);
        DropZone.AddHandler(DragDrop.DropEvent,      OnSingleDrop);
        DropZone.AddHandler(DragDrop.DragEnterEvent, OnSingleDragEnter);
        DropZone.AddHandler(DragDrop.DragLeaveEvent, OnSingleDragLeave);
        DropZone.PointerPressed += OnDropZoneClick;

        DragDrop.SetAllowDrop(BatchDropZone, true);
        BatchDropZone.AddHandler(DragDrop.DropEvent,      OnBatchDrop);
        BatchDropZone.AddHandler(DragDrop.DragEnterEvent, OnBatchDragEnter);
        BatchDropZone.AddHandler(DragDrop.DragLeaveEvent, OnBatchDragLeave);

        VM.BatchItems.CollectionChanged += (_, _) =>
            Dispatcher.UIThread.Post(() => UpdateBatchListVisibility(VM));
    }

    private void OnSingleDragEnter(object? s, DragEventArgs e)
    {
        e.DragEffects = DragDropEffects.Copy;
        DropZone.BorderBrush = new Avalonia.Media.SolidColorBrush(
            Avalonia.Media.Color.Parse("#C9A84C"));
    }
    private void OnSingleDragLeave(object? s, DragEventArgs e) =>
        DropZone.BorderBrush = new Avalonia.Media.SolidColorBrush(
            Avalonia.Media.Color.Parse("#2A2A2A"));

    private async void OnSingleDrop(object? s, DragEventArgs e)
    {
        OnSingleDragLeave(s, e);
        var files = GetDroppedPaths(e);
        if (files.Count == 0) return;
        await VM.LoadImageAsync(files[0]);
    }

    private async void OnDropZoneClick(object? s, PointerPressedEventArgs e)
    {
        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            AllowMultiple = false,
            FileTypeFilter = ImagePickerTypes(),
        });
        if (files.Count > 0)
            await VM.LoadImageAsync(files[0].Path.LocalPath);
    }

    private void OnBatchDragEnter(object? s, DragEventArgs e)
    {
        e.DragEffects = DragDropEffects.Copy;
        BatchEmptyState.BorderBrush = new Avalonia.Media.SolidColorBrush(
            Avalonia.Media.Color.Parse("#C9A84C"));
    }
    private void OnBatchDragLeave(object? s, DragEventArgs e) =>
        BatchEmptyState.BorderBrush = new Avalonia.Media.SolidColorBrush(
            Avalonia.Media.Color.Parse("#2A2A2A"));

    private void OnBatchDrop(object? s, DragEventArgs e)
    {
        OnBatchDragLeave(s, e);
        foreach (var path in GetDroppedPaths(e))
        {
            if (Directory.Exists(path))
                VM.AddBatchFolder(path);
            else
                VM.AddBatchFiles([path]);
        }
        UpdateBatchListVisibility(VM);
    }

    private static List<string> GetDroppedPaths(DragEventArgs e)
    {
        var list = new List<string>();
        if (e.Data.Contains(DataFormats.Files))
        {
            var items = e.Data.GetFiles();
            if (items != null)
                list.AddRange(items.Select(f => f.Path.LocalPath));
        }
        return list;
    }

    // ── Mode tabs ─────────────────────────────────────────────────────────
    private void OnSingleModeClick(object? s, RoutedEventArgs e)
    {
        VM.IsBatchMode        = false;
        SinglePanel.IsVisible = true;
        BatchPanel.IsVisible  = false;
        SingleTabButton.Classes.Add("active");
        BatchTabButton.Classes.Remove("active");
    }

    private void OnBatchModeClick(object? s, RoutedEventArgs e)
    {
        VM.IsBatchMode        = true;
        SinglePanel.IsVisible = false;
        BatchPanel.IsVisible  = true;
        BatchTabButton.Classes.Add("active");
        SingleTabButton.Classes.Remove("active");
        UpdateBatchListVisibility(VM);
    }

    // ── Single-mode controls ──────────────────────────────────────────────
    private async void OnApplyFactorClick(object? s, RoutedEventArgs e) =>
        await VM.ProcessPreviewAsync();

    private async void OnExportClick(object? s, RoutedEventArgs e)
    {
        var file = await StorageProvider.SaveFilePickerAsync(new FilePickerSaveOptions
        {
            SuggestedFileName = SuggestedExportName(),
            DefaultExtension  = "jpg",
            FileTypeChoices   = ExportPickerTypes(),
        });
        if (file == null) return;

        var dest = file.Path.LocalPath;
        ExportButton.IsEnabled = false;
        try
        {
            await DesqueezeProcessor.ExportAsync(VM.SourcePath!, dest, VM.ActiveFactor);
        }
        catch (Exception ex)
        {
            ErrorText.Text       = $"Export failed: {ex.Message}";
            ErrorPanel.IsVisible = true;
        }
        finally
        {
            ExportButton.IsEnabled = VM.HasImage;
        }
    }

    private void OnClearClick(object? s, RoutedEventArgs e)
    {
        VM.ClearImage();
        UpdatePreviewVisibility(VM);
    }

    // ── Batch controls ────────────────────────────────────────────────────
    private async void OnBatchAddFilesClick(object? s, RoutedEventArgs e)
    {
        var files = await StorageProvider.OpenFilePickerAsync(new FilePickerOpenOptions
        {
            AllowMultiple  = true,
            FileTypeFilter = ImagePickerTypes(),
        });
        if (files.Count > 0)
        {
            VM.AddBatchFiles(files.Select(f => f.Path.LocalPath));
            UpdateBatchListVisibility(VM);
        }
    }

    private async void OnBatchAddFolderClick(object? s, RoutedEventArgs e)
    {
        var folders = await StorageProvider.OpenFolderPickerAsync(
            new FolderPickerOpenOptions { AllowMultiple = false });
        if (folders.Count > 0)
        {
            VM.AddBatchFolder(folders[0].Path.LocalPath);
            UpdateBatchListVisibility(VM);
        }
    }

    private void OnBatchClearClick(object? s, RoutedEventArgs e)
    {
        VM.ClearBatch();
        UpdateBatchListVisibility(VM);
        BatchDoneLabel.IsVisible = false;
    }

    private void OnApplyBulkClick(object? s, RoutedEventArgs e) =>
        VM.ApplyBulkFactor();

    private async void OnBatchExportClick(object? s, RoutedEventArgs e)
    {
        if (VM.BatchItems.Count == 0) return;

        var folders = await StorageProvider.OpenFolderPickerAsync(
            new FolderPickerOpenOptions { AllowMultiple = false, Title = "Choose export folder" });
        if (folders.Count == 0) return;

        var folder = folders[0].Path.LocalPath;
        BatchExportButton.IsEnabled  = false;
        BatchProgressPanel.IsVisible = true;

        await VM.ExportBatchAsync(folder);

        BatchProgressPanel.IsVisible = false;
        BatchDoneLabel.Text          = VM.BatchStatus ?? "";
        BatchDoneLabel.IsVisible     = true;
        BatchExportButton.IsEnabled  = true;
    }

    // ── Helpers ───────────────────────────────────────────────────────────
    private string SuggestedExportName()
    {
        var src = VM.SourcePath;
        if (string.IsNullOrEmpty(src)) return "desqueezed";
        return Path.GetFileNameWithoutExtension(src) + "_desqueezed";
    }

    private static FilePickerFileType[] ImagePickerTypes() =>
    [
        new FilePickerFileType("Images")
        {
            Patterns = ["*.jpg","*.jpeg","*.png","*.tif","*.tiff","*.heic","*.bmp","*.webp"],
        },
    ];

    private static FilePickerFileType[] ExportPickerTypes() =>
    [
        new FilePickerFileType("JPEG") { Patterns = ["*.jpg"] },
        new FilePickerFileType("PNG")  { Patterns = ["*.png"] },
        new FilePickerFileType("TIFF") { Patterns = ["*.tif","*.tiff"] },
    ];
}
