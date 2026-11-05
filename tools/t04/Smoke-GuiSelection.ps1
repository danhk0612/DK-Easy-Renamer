# Native Windows PowerShell 5.1 / UIAutomation smoke on an ephemeral GitHub runner.
# Launches the installed app with the exact Explorer binary selection transport.
# Tests GUI selection and explicit Apply/Undo only on disposable files under unique %TEMP%.
[CmdletBinding()]
param([Parameter(Mandatory)][string]$AppExecutable)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_OS -ne 'Windows' -or
    [string]::IsNullOrWhiteSpace($env:RUNNER_TEMP)) {
    throw 'This smoke probe runs only in the GitHub-hosted ephemeral Windows CI environment.'
}
Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$scope = [System.Windows.Automation.TreeScope]::Descendants
$trueCondition = [System.Windows.Automation.Condition]::TrueCondition

# InvokePattern on an Apply button can block until the confirmation modal closes.
# Execute it on a helper thread while this script clicks the modal's Yes button.
$invokerSource = @'
using System;
using System.Threading;
using System.Windows.Automation;
public static class DkCiAsyncUiInvoke
{
    public static string Error;
    public static Thread Start(AutomationElement element)
    {
        Error = null;
        Thread thread = new Thread(new ThreadStart(() =>
        {
            try { ((InvokePattern)element.GetCurrentPattern(InvokePattern.Pattern)).Invoke(); }
            catch (Exception ex) { Error = ex.ToString(); }
        }));
        thread.IsBackground = true;
        thread.SetApartmentState(ApartmentState.STA);
        thread.Start();
        return thread;
    }
}
'@
$uiAssembly = [System.Windows.Automation.AutomationElement].Assembly.Location
Add-Type -TypeDefinition $invokerSource -ReferencedAssemblies @($uiAssembly)

function Invoke-UiButton($element) {
    if ($null -eq $element -or -not $element.Current.IsEnabled) {
        throw 'Expected enabled UI button is missing.'
    }
    $pattern = [System.Windows.Automation.InvokePattern]$element.GetCurrentPattern(
        [System.Windows.Automation.InvokePattern]::Pattern)
    $pattern.Invoke()
}

function Wait-ForFile([string]$path, [bool]$shouldExist) {
    for ($attempt=0; $attempt -lt 40; $attempt++) {
        if ([bool](Test-Path -LiteralPath $path) -eq $shouldExist) { return }
        Start-Sleep -Milliseconds 150
    }
    throw "File state did not match expected existence [$shouldExist]: $path"
}

function Find-AutomationId($root, [string]$id) {
    $condition = [System.Windows.Automation.PropertyCondition]::new([System.Windows.Automation.AutomationElement]::AutomationIdProperty,$id)
    return $root.FindFirst($scope,$condition)
}

function Get-UiNames($root) {
    $nodes = $root.FindAll($scope,$trueCondition)
    $names = New-Object 'System.Collections.Generic.List[string]'
    for ($i=0; $i -lt $nodes.Count; $i++) {
        $name = $nodes.Item($i).Current.Name
        if (-not [string]::IsNullOrWhiteSpace($name)) { $names.Add($name) }
    }
    return $names.ToArray()
}

function New-SelectionPacket([string[]]$paths) {
    $packet = Join-Path ([IO.Path]::GetTempPath()) ('DKR' + [Guid]::NewGuid().ToString('N') + '.tmp')
    $file = [IO.File]::Open($packet,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    $writer = [IO.BinaryWriter]::new($file,[Text.Encoding]::Unicode)
    try {
        $writer.Write([byte[]]@(68,75,82,49))
        $writer.Write([uint32]$paths.Length)
        foreach ($path in $paths) {
            $writer.Write([uint32]$path.Length)
            $writer.Write([Text.Encoding]::Unicode.GetBytes($path))
        }
    }
    finally { $writer.Dispose() }
    return $packet
}

function Open-SelectionGui([string[]]$paths, [string]$quickMode = '') {
    $packet = New-SelectionPacket $paths
    $arguments = @('--selection-file',('"' + $packet + '"'))
    if ($quickMode) { $arguments += @('--quick-mode', $quickMode) }
    $process = Start-Process -FilePath $AppExecutable -ArgumentList $arguments -PassThru
    $handle = [IntPtr]::Zero
    for ($attempt=0; $attempt -lt 30; $attempt++) {
        Start-Sleep -Milliseconds 350
        $process.Refresh()
        if ($process.HasExited) { throw "App exited early (code $($process.ExitCode))." }
        if ($process.MainWindowHandle -ne [IntPtr]::Zero) {
            $handle = $process.MainWindowHandle
            break
        }
    }
    if ($handle -eq [IntPtr]::Zero) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw 'Installed app did not expose a WPF main window.'
    }
    if ($process.MainWindowTitle -ne 'DK Easy Renamer') {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw "Native window title mismatch: $($process.MainWindowTitle)"
    }
    $gui = [System.Windows.Automation.AutomationElement]::FromHandle($handle)
    $grid = $null
    for ($attempt=0; $attempt -lt 20; $attempt++) {
        $grid = Find-AutomationId $gui 'FilesGrid'
        if ($null -ne $grid) { break }
        Start-Sleep -Milliseconds 250
    }
    $caption = Find-AutomationId $gui 'VisibleWindowCaption'
    if ($null -eq $caption -or $caption.Current.Name -ne 'DK Easy Renamer' -or $caption.Current.IsOffscreen) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw 'The WPF-rendered top title is missing, incorrect or offscreen.'
    }
    if ($null -eq $grid) {
        $names = Get-UiNames $gui
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw ('UIAutomation did not find FilesGrid. Available UI names: ' + ($names -join ' | '))
    }
    if (Test-Path -LiteralPath $packet) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
        throw 'App did not delete the consumed Explorer handoff packet.'
    }
    return [pscustomobject]@{ Process=$process; Root=$gui; Grid=$grid }
}

function Close-SelectionGui($app) {
    if ($null -ne $app -and $null -ne $app.Process) {
        if (-not $app.Process.HasExited) {
            Stop-Process -Id $app.Process.Id -Force -ErrorAction SilentlyContinue
        }
        $app.Process.Dispose()
    }
}

$created = & (Join-Path $PSScriptRoot 'New-TestFixtures.ps1')
$fixtureRoot = [IO.Path]::GetFullPath($created.Root)
$tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
if (-not $fixtureRoot.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or
    -not ([IO.Path]::GetFileName($fixtureRoot).StartsWith('DK-EasyRenamer-T04-'))) {
    throw 'Fixture root does not match uniquely labeled %TEMP% test directory.'
}
$app = $null
try {
    $paths = @(
        (Join-Path $fixtureRoot 'file1.txt'),
        (Join-Path $fixtureRoot '한글 파일 03.txt'),
        (Join-Path $fixtureRoot '日本語 04.txt'),
        (Join-Path $fixtureRoot '빈 폴더')
    )
    $app = Open-SelectionGui $paths
    $names = @(Get-UiNames $app.Grid)
    foreach ($name in @('file1.txt','한글 파일 03.txt','日本語 04.txt','빈 폴더')) {
        if (-not ($names -contains $name)) {
            throw ("GUI did not render a selected Explorer path [" + $name + "]; grid names: " + ($names -join ' | '))
        }
    }
    if ([IO.File]::ReadAllText((Join-Path $fixtureRoot 'file1.txt')) -ne 'one') {
        throw 'Opening a selection unexpectedly modified a fixture.'
    }
    Write-Host 'GUI selection handoff PASS: native UTF-16 packet, mixed files/folder, Hangul and Japanese names, WPF grid, native caption, no rename.'
    Close-SelectionGui $app
    $app = $null

    # UI quick modes still select the standard editable rule and preview:
    # neither invocation is allowed to mutate the selected fixture.
    foreach ($mode in @('sequence','replace')) {
        $app = Open-SelectionGui $paths $mode
        $names = @(Get-UiNames $app.Root)
        $expectedRule = if ($mode -eq 'sequence') { '순번 붙이기 / 이름 대체' }
                        else { '문자열 찾기 · 바꾸기' }
        if (-not ($names -contains $expectedRule)) {
            throw "Quick mode [$mode] did not preselect [$expectedRule] in the real WPF UI: $($names -join ' | ')"
        }
        if ([IO.File]::ReadAllText((Join-Path $fixtureRoot 'file1.txt')) -ne 'one') {
            throw "Quick mode [$mode] modified a fixture without Apply."
        }
        Write-Host "Quick Explorer action GUI routing PASS: $mode; rule preselected, no rename."
        Close-SelectionGui $app
        $app = $null
    }

    # Real WPF Apply -> explicit modal Yes -> Undo, only on the generated
    # file1.txt fixture. This does not exercise Explorer's COM menu on Win11.
    $original = Join-Path $fixtureRoot 'file1.txt'
    $renamed = Join-Path $fixtureRoot '001_file1.txt'
    $app = Open-SelectionGui @($original) 'sequence'
    $applyButton = Find-AutomationId $app.Root 'ApplyButton'
    $undoButton = Find-AutomationId $app.Root 'UndoButton'
    if ($null -eq $undoButton -or $undoButton.Current.IsEnabled) {
        throw 'Undo must be disabled before a rename.'
    }
    if (Test-Path -LiteralPath $renamed) {
        throw 'Expected renamed fixture did not start absent.'
    }
    if ($null -eq $applyButton -or -not $applyButton.Current.IsEnabled) {
        throw 'The sequence preview did not enable the Apply button.'
    }
    $invokeThread = [DkCiAsyncUiInvoke]::Start($applyButton)
    $modal = $null
    $desktop = [System.Windows.Automation.AutomationElement]::RootElement
    $modalCondition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::NameProperty,
        'DK Easy Renamer · 이름 변경')
    for ($attempt=0; $attempt -lt 40; $attempt++) {
        $modal = $desktop.FindFirst([System.Windows.Automation.TreeScope]::Children, $modalCondition)
        if ($null -ne $modal -and $modal.Current.ProcessId -eq $app.Process.Id) { break }
        $modal = $null
        Start-Sleep -Milliseconds 150
    }
    if ($null -eq $modal) { throw 'Explicit Apply confirmation dialog did not appear.' }
    $yesCondition = [System.Windows.Automation.PropertyCondition]::new(
        [System.Windows.Automation.AutomationElement]::AutomationIdProperty, '6')
    $yes = $modal.FindFirst($scope,$yesCondition)
    if ($null -eq $yes) {
        $names = @(Get-UiNames $modal)
        throw ('Confirmation Yes button was not available: ' + ($names -join ' | '))
    }
    Invoke-UiButton $yes
    if (-not $invokeThread.Join(8000)) { throw 'Apply UI automation did not finish after confirmation.' }
    if (-not [string]::IsNullOrEmpty([DkCiAsyncUiInvoke]::Error)) {
        throw ('Apply UI automation failed: ' + [DkCiAsyncUiInvoke]::Error)
    }
    Wait-ForFile $renamed $true
    Wait-ForFile $original $false
    if ([IO.File]::ReadAllText($renamed) -ne 'one') {
        throw 'GUI Apply did not preserve the file contents.'
    }
    $undoButton = Find-AutomationId $app.Root 'UndoButton'
    Invoke-UiButton $undoButton
    Wait-ForFile $original $true
    Wait-ForFile $renamed $false
    if ([IO.File]::ReadAllText($original) -ne 'one') {
        throw 'GUI Undo did not restore the original file contents.'
    }
    if ((Find-AutomationId $app.Root 'UndoButton').Current.IsEnabled) {
        throw 'Undo remained enabled after successful one-time rollback.'
    }
    Write-Host 'GUI Apply/Undo PASS: explicit modal consent, file rename, restored name/content, one-use Undo.'
    Close-SelectionGui $app
    $app = $null

}
finally {
    Close-SelectionGui $app
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Force -Recurse
    }
}
