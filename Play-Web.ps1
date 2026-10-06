param([string]$GodotPath = $env:GODOT_BIN, [int]$Port = 8080)
$ErrorActionPreference = 'Stop'
if (-not $GodotPath) {
    $installed = Get-Command godot,godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installed) { $GodotPath = $installed.Source }
}
if (-not $GodotPath) {
    $localEngine = 'D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
    if (Test-Path -LiteralPath $localEngine) { $GodotPath = $localEngine }
}
$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { throw 'Node.js is required to run the local web game and room service.' }
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'web/build/index.wasm'))) { & (Join-Path $PSScriptRoot 'web/Build-Web.ps1') -GodotPath $GodotPath }
Write-Output "Open http://127.0.0.1:$Port in your browser. Keep this terminal running; Ctrl+C stops both services."
& $node.Source (Join-Path $PSScriptRoot 'web/serve.mjs') "--godot=$GodotPath" "--port=$Port"
