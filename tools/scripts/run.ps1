<#
.SYNOPSIS
  Launches the game (brick 007).
.DESCRIPTION
  Verifies the engine build first, then runs the main scene. Extra arguments are
  forwarded to the game after `--`, so logging flags work:
      tools\scripts\run.ps1 --log-level=debug --log=gen:trace
.PARAMETER Headless
  Run without a window (useful for smoke checks and future dedicated-server work).
#>
[CmdletBinding()]
param(
    [switch]$Headless,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$GameArgs = @()
)

. "$PSScriptRoot\_common.ps1"

$godot = Get-GodotPath
$version = Assert-GodotBuild -GodotPath $godot
Write-Host "engine $version" -ForegroundColor DarkGray

$argv = @()
if ($Headless) { $argv += '--headless' }
if ($GameArgs.Count -gt 0) { $argv += '--'; $argv += $GameArgs }

Push-Location (Get-ProjectRoot)
try {
    & $godot @argv
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
