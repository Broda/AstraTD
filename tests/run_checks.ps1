param(
    [string]$Godot = "",
    [int]$TimeoutSeconds = 180,
    [switch]$CaptureUI
)
$ErrorActionPreference = 'Stop'
$taskRoot = Split-Path -Parent $PSScriptRoot
$taskLogs = Join-Path $taskRoot 'work/checks'
New-Item -ItemType Directory -Force -Path $taskLogs | Out-Null
if (-not $Godot) {
    $taskEngine = Get-Command godot -ErrorAction SilentlyContinue
    if ($taskEngine) { $Godot = $taskEngine.Source }
    else { $Godot = 'C:\Godot_v4.7.2-stable_mono_win64\Godot_v4.7.2-stable_mono_win64_console.exe' }
}
if (-not (Test-Path -LiteralPath $Godot)) { throw 'Godot was not found. Pass -Godot with the full console executable path.' }
function Invoke-WardensCheck([string]$Name, [string[]]$Arguments, [bool]$ExpectPass = $true) {
    $taskOut = Join-Path $taskLogs ($Name + '.stdout.log')
    $taskErr = Join-Path $taskLogs ($Name + '.stderr.log')
    $taskArguments = @('--path', ('"' + $taskRoot + '"')) + $Arguments
    $taskProcess = Start-Process -FilePath $Godot -ArgumentList $taskArguments -WorkingDirectory $taskRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $taskOut -RedirectStandardError $taskErr
    if (-not $taskProcess.WaitForExit($TimeoutSeconds * 1000)) {
        $taskProcess.Kill($true)
        throw "$Name timed out after $TimeoutSeconds seconds. See $taskLogs."
    }
    $taskProcess.WaitForExit()
    $taskText = (Get-Content -LiteralPath $taskOut -Raw) + (Get-Content -LiteralPath $taskErr -Raw)
    if ($taskProcess.ExitCode -ne 0 -or $taskText -match '(?m)^(SCRIPT ERROR:|ERROR:|WARNING:)' -or ($ExpectPass -and $taskText -notmatch 'PASSED')) {
        Write-Output $taskText
        throw "$Name failed (exit $($taskProcess.ExitCode)). See $taskLogs."
    }
    Write-Output ("PASS " + $Name)
}
Invoke-WardensCheck 'import' @('--headless','--editor','--import','--quit') $false
Invoke-WardensCheck 'content' @('--headless','--script','tests/content_data_test.gd')
Invoke-WardensCheck 'storage-settings-audio' @('--headless','--script','tests/storage_test.gd')
foreach ($taskCheck in @('smoke-test','combat-test','vfx-test','station-test','nova-target-test','nova-pulse-test','integration-test','menu-test','balance-test','performance-test')) {
    Invoke-WardensCheck $taskCheck @('--headless','--',('--' + $taskCheck))
}
if ($CaptureUI) {
    Invoke-WardensCheck 'ui-capture' @('--','--ui-capture')
    foreach ($taskPhase in @('write','read','windowed')) {
        Invoke-WardensCheck ('display-' + $taskPhase) @('--script','tests/display_test.gd','--',('--display-phase=' + $taskPhase))
    }
}
Write-Output 'ALL CHECKS PASSED. Logs: work/checks/'
