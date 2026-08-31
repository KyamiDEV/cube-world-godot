<#
.SYNOPSIS
  Runs the headless test suite (brick 008).
.DESCRIPTION
  Verifies the engine build, refreshes the global class cache so newly added
  `class_name` scripts resolve, then runs res://tests/run_tests.gd.
  Exit code 0 = every test passed and at least one test ran.
.PARAMETER Filter
  Run only test methods whose name contains this substring.
.PARAMETER File
  Run only test files whose path contains this substring.
.PARAMETER Verbose_
  List passing tests, not just failures.
.PARAMETER NoImport
  Skip the class-cache refresh (faster when no script was added or renamed).
.EXAMPLE
  tools\scripts\test.ps1
  tools\scripts\test.ps1 -File log -Verbose_
#>
[CmdletBinding()]
param(
    [string]$Filter = '',
    [string]$File = '',
    [switch]$Verbose_,
    [switch]$NoImport,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$ExtraArgs = @()
)

. "$PSScriptRoot\_common.ps1"

$godot = Get-GodotPath
$version = Assert-GodotBuild -GodotPath $godot
Write-Host "engine $version" -ForegroundColor DarkGray

if (-not $NoImport) { Update-ClassCache }

$argv = @('--headless', '--script', 'res://tests/run_tests.gd', '--')
if ($Filter) { $argv += "--test-filter=$Filter" }
if ($File) { $argv += "--test-file=$File" }
if ($Verbose_) { $argv += '--verbose' }
$argv += $ExtraArgs

$result = Invoke-Godot -GodotArgs $argv -Quiet
$result.Output |
    Where-Object { $_ -notmatch 'godot_ai|^Godot Engine' -and $_.Trim() -ne '' } |
    ForEach-Object {
        if ($_ -match '^\s*FAIL|^FAIL:|RESULT=FAIL') { Write-Host $_ -ForegroundColor Red }
        elseif ($_ -match 'RESULT=OK') { Write-Host $_ -ForegroundColor Green }
        else { Write-Host $_ }
    }

exit $result.ExitCode
