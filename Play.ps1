param([string]$GodotPath = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
if (-not $GodotPath) {
    $installed = Get-Command godot, godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installed) { $GodotPath = $installed.Source }
}
if (-not $GodotPath) {
    $localEngine = 'D:\Downloads\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe'
    if (Test-Path -LiteralPath $localEngine) { $GodotPath = $localEngine }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) {
    throw 'Godot 4 is required. Import project.godot in Godot, or set GODOT_BIN to the Godot executable.'
}
& $GodotPath --path $PSScriptRoot
