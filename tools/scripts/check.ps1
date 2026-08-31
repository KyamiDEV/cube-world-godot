<#
.SYNOPSIS
  Validates the development environment and the whole GDScript tree (brick 007).
.DESCRIPTION
  Four checks, in dependency order:
    1. engine build matches the contract (CLAUDE.md section 1), then a project
       import so newly added `class_name` scripts are registered
    2. Voxel Tools 1.7 module and required classes are present
    3. every project .gd file compiles, warnings-as-errors included
    4. the project boots headless without errors
  Exits non-zero on the first failure category found; each check reports on its own.
.EXAMPLE
  tools\scripts\check.ps1
#>
[CmdletBinding()]
param()

. "$PSScriptRoot\_common.ps1"

$failures = @()

Write-Section 'Engine build'
$godot = Get-GodotPath
Write-Host "path    $godot"
try {
    $version = Assert-GodotBuild -GodotPath $godot
    Write-Host "version $version" -ForegroundColor Green
} catch {
    Write-Host $_.Exception.Message -ForegroundColor Red
    # Nothing below is meaningful on the wrong engine.
    exit 1
}

Write-Section 'Project import'
Update-ClassCache
Write-Host '  class cache refreshed'

Write-Section 'Voxel Tools'
$voxel = Invoke-Godot -GodotArgs @('--headless', '--script', 'res://tools/probe/probe_voxel.gd') -Quiet
$voxel.Output | Where-Object { $_ -match '^(voxel_|required_classes|registered_|RESULT|FAIL)' } | ForEach-Object { Write-Host "  $_" }
if ($voxel.ExitCode -ne 0) { $failures += 'voxel-tools' }

Write-Section 'GDScript compile'
$scripts = Invoke-Godot -GodotArgs @('--headless', '--script', 'res://tools/probe/check_scripts.gd') -Quiet
$scripts.Output | Where-Object { $_ -match '^(checked=|RESULT|FAIL:)' } | ForEach-Object { Write-Host "  $_" }
if ($scripts.ExitCode -ne 0) {
    $failures += 'gdscript'
    # Compiler diagnostics explain *why*; they are only useful on failure.
    $scripts.Output | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error' } | Select-Object -First 40 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}

Write-Section 'Headless boot'
$boot = Invoke-Godot -GodotArgs @('--headless', '--quit') -Quiet
$bootErrors = $boot.Output | Where-Object { $_ -match 'SCRIPT ERROR|ERROR:|Parse Error' }
$boot.Output | Where-Object { $_ -match '^\w/' } | ForEach-Object { Write-Host "  $_" }
if ($boot.ExitCode -ne 0 -or $bootErrors) {
    $failures += 'boot'
    $bootErrors | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
}

Write-Host ''
if ($failures.Count -eq 0) {
    Write-Host 'CHECK OK' -ForegroundColor Green
    exit 0
}
Write-Host "CHECK FAILED: $($failures -join ', ')" -ForegroundColor Red
exit 1
