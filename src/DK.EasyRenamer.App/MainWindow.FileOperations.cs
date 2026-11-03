using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using DK.EasyRenamer.Core;

namespace DK.EasyRenamer.App;

public partial class MainWindow
{
    private const string InternalDragFormat = "DKEasyRenamer.SelectedRows";
    private bool _descending;

    private void OnAddFiles(object sender, RoutedEventArgs e)
    {
        var dialog = new Microsoft.Win32.OpenFileDialog
        {
            Title = "이름을 변경할 파일 선택",
            Filter = "모든 파일 (*.*)|*.*",
            Multiselect = true,
            CheckFileExists = true
        };
        if (dialog.ShowDialog(this) == true) AddPaths(dialog.FileNames);
    }

    private void OnAddFolder(object sender, RoutedEventArgs e)
    {
        using var dialog = new System.Windows.Forms.FolderBrowserDialog
        {
            Description = "이름을 변경할 폴더를 선택하세요 (폴더 자체만 대상)",
            UseDescriptionForTitle = true,
            ShowNewFolderButton = false
        };
        if (dialog.ShowDialog() == System.Windows.Forms.DialogResult.OK)
            AddPaths([dialog.SelectedPath]);
    }

    private void OnExternalDragOver(object sender, DragEventArgs e)
    {
        if (e.Data.GetDataPresent(DataFormats.FileDrop))
        {
            e.Effects = DragDropEffects.Copy;
            e.Handled = true;
        }
    }

    private void OnExternalDrop(object sender, DragEventArgs e)
    {
        if (e.Handled) return;
        if (e.Data.GetData(DataFormats.FileDrop) is string[] files)
        {
            AddPaths(files);
            e.Handled = true;
        }
    }

    private void OnRemoveFiles(object sender, RoutedEventArgs e)
    {
        var selected = FilesGrid.SelectedItems.Cast<FileRow>().ToArray();
        foreach (FileRow row in selected)
        {
            row.PropertyChanged -= OnRowPropertyChanged;
            _rows.Remove(row);
        }
        _justApplied = false;
        RefreshPreview();
    }

    private void OnSort(object sender, RoutedEventArgs e)
    {
        if (SortChoiceBox.SelectedItem is not SortChoice choice) return;
        try
        {
            var sorted = RenameSelectionSorter.Sort(
                _rows.Select(x => new RenameSelection(x.FullPath, x.Included)),
                choice.Field, _descending);
            var byPath = _rows.ToDictionary(x => x.FullPath, StringComparer.OrdinalIgnoreCase);
            var result = sorted.Select(x => byPath[x.Path]).ToArray();
            _rows.Clear();
            foreach (FileRow row in result) _rows.Add(row);
            _descending = !_descending;
            _justApplied = false;
            RefreshPreview();
        }
        catch (IOException ex)
        {
            DetailText.Text = "정렬 실패: " + ex.Message;
        }
    }

    private void OnFileUp(object sender, RoutedEventArgs e) => MoveSelected(-1);
    private void OnFileDown(object sender, RoutedEventArgs e) => MoveSelected(1);

    private void MoveSelected(int delta)
    {
        var selected = FilesGrid.SelectedItems.Cast<FileRow>().ToHashSet();
        if (selected.Count == 0) return;
        if (delta < 0)
        {
            for (int i = 1; i < _rows.Count; i++)
                if (selected.Contains(_rows[i]) && !selected.Contains(_rows[i - 1]))
                    _rows.Move(i, i - 1);
        }
        else
        {
            for (int i = _rows.Count - 2; i >= 0; i--)
                if (selected.Contains(_rows[i]) && !selected.Contains(_rows[i + 1]))
                    _rows.Move(i, i + 1);
        }
        Reselect(selected);
        _justApplied = false;
        RefreshPreview();
    }

    private void Reselect(IEnumerable<FileRow> selected)
    {
        FilesGrid.SelectedItems.Clear();
        foreach (FileRow item in selected) FilesGrid.SelectedItems.Add(item);
    }

    private void OnFilesPointerDown(object sender, MouseButtonEventArgs e)
    {
        _dragStart = e.GetPosition(FilesGrid);
        _dragSource = FindRow(e.OriginalSource as DependencyObject)?.Item as FileRow;
    }

    private void OnFilesPointerMove(object sender, MouseEventArgs e)
    {
        if (_dragSource is null || e.LeftButton != MouseButtonState.Pressed) return;
        Point current = e.GetPosition(FilesGrid);
        if (Math.Abs(current.X - _dragStart.X) < SystemParameters.MinimumHorizontalDragDistance &&
            Math.Abs(current.Y - _dragStart.Y) < SystemParameters.MinimumVerticalDragDistance)
            return;
        var rows = FilesGrid.SelectedItems.Cast<FileRow>().ToArray();
        if (!rows.Contains(_dragSource)) rows = [_dragSource];
        var data = new DataObject(InternalDragFormat, rows);
        _dragSource = null;
        DragDrop.DoDragDrop(FilesGrid, data, DragDropEffects.Move);
    }

    private void OnFilesDragOver(object sender, DragEventArgs e)
    {
        e.Effects = e.Data.GetDataPresent(InternalDragFormat)
            ? DragDropEffects.Move
            : e.Data.GetDataPresent(DataFormats.FileDrop) ? DragDropEffects.Copy : DragDropEffects.None;
        e.Handled = true;
    }

    private void OnFilesDrop(object sender, DragEventArgs e)
    {
        if (e.Data.GetData(InternalDragFormat) is FileRow[] moving)
        {
            var target = FindRow(e.OriginalSource as DependencyObject)?.Item as FileRow;
            if (target is not null && !moving.Contains(target))
            {
                var ordered = _rows.Where(moving.Contains).ToArray();
                foreach (FileRow item in ordered) _rows.Remove(item);
                int index = _rows.IndexOf(target);
                foreach (FileRow item in ordered) _rows.Insert(index++, item);
                Reselect(ordered);
                _justApplied = false;
                RefreshPreview();
            }
            e.Handled = true;
        }
        else if (e.Data.GetData(DataFormats.FileDrop) is string[] files)
        {
            AddPaths(files);
            e.Handled = true;
        }
    }

    private static DataGridRow? FindRow(DependencyObject? source)
    {
        while (source is not null && source is not DataGridRow)
            source = VisualTreeHelper.GetParent(source);
        return source as DataGridRow;
    }

    private void OnApply(object sender, RoutedEventArgs e)
    {
        if (_plan is null || !_plan.IsValid || !_plan.Items.Any(x => x.Changed)) return;
        int count = _plan.Items.Count(x => x.Changed);
        var confirmation = MessageBox.Show(this,
            $"{count}개 파일·폴더의 이름을 미리보기대로 변경합니다. 진행하시겠습니까?",
            "DK Easy Renamer · 이름 변경", MessageBoxButton.YesNo, MessageBoxImage.Question);
        if (confirmation != MessageBoxResult.Yes) return;
        var plan = _plan;
        RenameExecutionResult result = RenameExecutor.Apply(plan);
        if (!result.Succeeded)
        {
            StatusText.Text = "이름 변경에 실패했습니다.";
            DetailText.Text = string.Join(" / ", result.Errors);
            ApplyButton.IsEnabled = false;
            return;
        }

        _lastPathChanges.Clear();
        for (int i = 0; i < plan.Items.Count; i++)
        {
            if (!plan.Items[i].Changed) continue;
            FileRow row = _rows[i];
            _lastPathChanges.Add((row, row.FullPath));
            row.FullPath = plan.Items[i].TargetPath;
            row.PreviewName = row.FileName;
            row.Status = "적용됨";
        }
        _undo = result.Undo;
        _justApplied = true;
        RefreshPreview();
        DetailText.Text = $"{count}개 항목을 변경했습니다. 필요하면 상단 '되돌리기'를 누르세요.";
    }

    private void OnUndo(object sender, RoutedEventArgs e)
    {
        if (_undo is null) return;
        RenameExecutionResult result = RenameExecutor.Undo(_undo);
        if (!result.Succeeded)
        {
            StatusText.Text = "되돌리기에 실패했습니다.";
            DetailText.Text = string.Join(" / ", result.Errors);
            return;
        }
        foreach (var (row, original) in _lastPathChanges)
            row.FullPath = original;
        _undo = null;
        _lastPathChanges.Clear();
        _justApplied = false;
        RefreshPreview();
        DetailText.Text = "마지막 이름 변경 작업을 되돌렸습니다.";
    }
}
