using System.IO;

namespace DesqueezeWindows.ViewModels;

public enum BatchItemState { Pending, Working, Done, Failed }

public class BatchItemViewModel : ViewModelBase
{
    private BatchItemState _state = BatchItemState.Pending;
    private string? _error;

    public BatchItemViewModel(string sourcePath) => SourcePath = sourcePath;

    public string SourcePath { get; }
    public string FileName => Path.GetFileName(SourcePath);

    public BatchItemState State
    {
        get => _state;
        set { if (Set(ref _state, value)) { Raise(nameof(StatusLabel)); Raise(nameof(IsFailed)); } }
    }

    public string? Error
    {
        get => _error;
        set { if (Set(ref _error, value)) Raise(nameof(StatusLabel)); }
    }

    public bool IsFailed => _state == BatchItemState.Failed;

    public string StatusLabel => _state switch
    {
        BatchItemState.Pending => "QUEUED",
        BatchItemState.Working => "WORKING",
        BatchItemState.Done    => "DONE",
        BatchItemState.Failed  => Error is null ? "FAILED" : $"FAILED · {Error}",
        _                      => "",
    };
}
