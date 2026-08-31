# Shared helpers for the tools/scripts/*.ps1 entry points (brick 007).
# Dot-source this: . "$PSScriptRoot\_common.ps1"

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

# Engine build required by CLAUDE.md section 1. The precision token is a wildcard
# because the preferred build reports "4.7.2.stable.double.custom_build.<hash>".
$script:RequiredEngineVersionPattern = '^4\.7\.2\.stable(\.\w+)?\.custom_build\.ed1daf0bf'
$script:RecordedEnginePath = 'C:\Users\Admin\Desktop\godot.windows.editor.double.x86_64.exe'

function Get-ProjectRoot { return $script:ProjectRoot }

# Resolution order (docs/environment.md section 3):
#   1. $env:GODOT_BIN
#   2. tools/local/godot_path.txt   (gitignored, machine-local)
#   3. the path recorded in docs/environment.md
function Get-GodotPath {
    $candidates = @()
    if ($env:GODOT_BIN) { $candidates += $env:GODOT_BIN }
    $localFile = Join-Path $script:ProjectRoot 'tools\local\godot_path.txt'
    if (Test-Path $localFile) {
        $line = (Get-Content $localFile -TotalCount 1).Trim()
        if ($line) { $candidates += $line }
    }
    $candidates += $script:RecordedEnginePath

    foreach ($c in $candidates) {
        if (Test-Path $c) { return (Resolve-Path $c).Path }
    }
    throw "Godot executable not found. Tried:`n  $($candidates -join "`n  ")`nSet `$env:GODOT_BIN or write the path into tools/local/godot_path.txt."
}

# Verifies the binary is the exact contracted build. Throws otherwise: silently
# switching engine builds is forbidden (CLAUDE.md section 1).
function Assert-GodotBuild {
    param([string]$GodotPath)
    $version = (& $GodotPath --version 2>&1 | Select-Object -Last 1).ToString().Trim()
    if ($version -notmatch $script:RequiredEngineVersionPattern) {
        throw "Engine mismatch.`n  expected: 4.7.2.stable[.<precision>].custom_build.ed1daf0bf`n  found:    $version`n  path:     $GodotPath"
    }
    return $version
}

# Runs Godot inside the project and returns the captured output plus exit code.
function Invoke-Godot {
    param(
        [Parameter(Mandatory = $true)][string[]]$GodotArgs,
        [switch]$Quiet
    )
    $godot = Get-GodotPath
    Push-Location $script:ProjectRoot
    # Windows PowerShell 5.1 wraps a native command's stderr lines in ErrorRecords,
    # which would throw under ErrorActionPreference=Stop even when the tool exits 0.
    # Godot writes diagnostics to stderr, so stderr is merged deliberately here and
    # the preference is relaxed only around the call.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $godot @GodotArgs 2>&1 | ForEach-Object { $_.ToString() }
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousPreference
        Pop-Location
    }
    if (-not $Quiet) { $output | ForEach-Object { Write-Host $_ } }
    return [pscustomobject]@{ ExitCode = $code; Output = $output }
}

# Rescans the project so scripts declaring `class_name` are registered in
# .godot/global_script_class_cache.cfg. Headless `--script` runs read that cache
# but never refresh it, so a newly added global class is invisible until this runs.
function Update-ClassCache {
    $result = Invoke-Godot -GodotArgs @('--headless', '--import') -Quiet
    if ($result.ExitCode -ne 0) {
        Write-Host ($result.Output | Select-Object -Last 10) -ForegroundColor Red
        throw "Project import failed (exit $($result.ExitCode))."
    }
}

function Write-Section {
    param([string]$Text)
    Write-Host ''
    Write-Host "== $Text" -ForegroundColor Cyan
}
