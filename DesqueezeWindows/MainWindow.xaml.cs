using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using DesqueezeWindows.Models;
using DesqueezeWindows.Services;
using DesqueezeWindows.ViewModels;
using Microsoft.Win32;

namespace DesqueezeWindows;

public partial class MainWindow : Window
{
    private readonly MainViewModel _vm = new();

    public MainWindow()
    {
        InitializeComponent();
        DataContext = _vm;
    }

    // ── Opening ────────────────────────────────────────────

    private void DropZone_Click(object sender, MouseButtonEventArgs e) => OpenFilePicker();
    private void OpenNew_Click(object sender, RoutedEventArgs e) => OpenFilePicker();

    private void OpenFilePicker()
    {
        var dlg = new OpenFileDialog
        {
            Title  = "Open Image",
            Filter = "Images|*.jpg;*.jpeg;*.png;*.tif;*.tiff;*.heic;*.bmp;*.webp|All files|*.*",
        };
        if (dlg.ShowDialog() == true)
        {
            _vm.IsBatchMode = false;
            _vm.LoadFromPath(dlg.FileName);
        }
    }

    private void ChooseFolder_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new OpenFolderDialog { Title = "Choose a folder of images" };
        if (dlg.ShowDialog() == true) LoadFolder(dlg.FolderName);
    }

    private void LoadFolder(string folder)
    {
        _vm.IsBatchMode = true;
        _vm.LoadBatchFolder(folder);
    }

    // ── Drag & drop — accepts a file or a folder ──────────────────────

    private void Window_DragOver(object sender, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(DataFormats.FileDrop)
            ? DragDropEffects.Copy
            : DragDropEffects.None;
        e.Handled = true;
    }

    private void Window_Drop(object sender, DragEventArgs e)
    {
        if (!e.Data.GetDataPresent(DataFormats.FileDrop)) return;
        if (e.Data.GetData(DataFormats.FileDrop) is not string[] { Length: > 0 } paths) return;

        var first = paths[0];

        if (Directory.Exists(first))
        {
            LoadFolder(first);
            return;
        }

        // Several files dropped at once are treated as an ad-hoc batch.
        var images = paths.Where(p => File.Exists(p) && BatchProcessor.IsSupported(p)).ToList();
        if (images.Count > 1)
        {
            LoadFolder(Path.GetDirectoryName(images[0])!);
            return;
        }

        _vm.IsBatchMode = false;
        _vm.LoadFromPath(first);
    }

    // ── Presets ────────────────────────────────────────────

    private void Preset_Click(object sender, RoutedEventArgs e)
    {
        if (sender is RadioButton { DataContext: SqueezePresetOption opt })
            _vm.SelectedPreset = opt.Preset;
    }

    private void Custom_Click(object sender, RoutedEventArgs e)
        => _vm.SelectedPreset = SqueezePreset.Custom;

    private void CustomFactor_KeyDown(object sender, KeyEventArgs e)
    {
        if (e.Key is not (Key.Return or Key.Enter)) return;
        _vm.SelectedPreset = SqueezePreset.Custom;
        _ = _vm.ProcessAsync();
    }

    // ── Preview mode ────────────────────────────────────────

    private void PreviewMode_Changed(object sender, RoutedEventArgs e)
    {
        // Fires during XAML parse, before the named panels exist.
        if (SideBySidePanel is null) return;

        SideBySidePanel.Visibility = sender == SideBySideBtn ? Visibility.Visible : Visibility.Collapsed;
        OriginalPanel.Visibility   = sender == OriginalBtn   ? Visibility.Visible : Visibility.Collapsed;
        ProcessedPanel.Visibility  = sender == ProcessedBtn  ? Visibility.Visible : Visibility.Collapsed;
    }

    // ── Export ─────────────────────────────────────────────

    private void Export_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new SaveFileDialog
        {
            Title           = "Export De-squeezed Image",
            FileName        = "desqueezed",
            Filter          = "JPEG|*.jpg|PNG|*.png|TIFF|*.tiff",
            DefaultExt      = ".jpg",
            AddExtension    = true,
            OverwritePrompt = true,
        };
        if (dlg.ShowDialog() == true) _vm.Export(dlg.FileName);
    }

    private async void RunBatch_Click(object sender, RoutedEventArgs e)
    {
        var dlg = new OpenFolderDialog { Title = "Choose a destination folder" };
        if (dlg.ShowDialog() != true) return;

        await _vm.RunBatchAsync(dlg.FolderName);
    }
}
