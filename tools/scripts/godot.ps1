<#
.SYNOPSIS
  Runs the project's contracted Godot build with arbitrary arguments (brick 007).
.EXAMPLE
  tools\scripts\godot.ps1 --headless --quit
  tools\scripts\godot.ps1 -e            # open the editor
#>
[CmdletBinding()]
param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GodotArgs = @())

. "$PSScriptRoot\_common.ps1"

$godot = Get-GodotPath
Push-Location (Get-ProjectRoot)
try {
    & $godot @GodotArgs
    exit $LASTEXITCODE
} finally {
    Pop-Location
}
