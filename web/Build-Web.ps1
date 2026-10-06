param([string]$GodotPath = $env:GODOT_BIN)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $GodotPath) {
    $installed = Get-Command godot,godot4 -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($installed) { $GodotPath = $installed.Source }
}
if (-not $GodotPath) {
    $localEngine = 'D:/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64.exe'
    if (Test-Path -LiteralPath $localEngine) { $GodotPath = $localEngine }
}
if (-not $GodotPath -or -not (Test-Path -LiteralPath $GodotPath)) { throw 'Set GODOT_BIN to Godot 4 with matching web export templates.' }
$env:APPDATA = Join-Path $projectRoot '.runtime'
$env:LOCALAPPDATA = $env:APPDATA
New-Item -ItemType Directory (Join-Path $PSScriptRoot 'build') -Force | Out-Null
$exportLog = Join-Path $env:APPDATA 'web-export.log'
$exportError = "$exportLog.err"
$launchOptions = @{}
if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') { $launchOptions.WindowStyle = 'Hidden' }
$arguments = @('--headless', '--path', "`"$projectRoot`"", '--export-release', 'Web', "`"$(Join-Path $PSScriptRoot 'build/index.html')`"")
$process = Start-Process -FilePath $GodotPath -ArgumentList $arguments @launchOptions -Wait -PassThru -RedirectStandardOutput $exportLog -RedirectStandardError $exportError
if ($process.ExitCode -ne 0) { Get-Content -LiteralPath $exportError; throw 'Web export failed. Install matching Godot export templates.' }
if (Select-String -LiteralPath $exportError -Pattern 'SCRIPT ERROR|Parse Error' -Quiet) { Get-Content -LiteralPath $exportError; throw 'Web export contains script errors.' }
if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'build/index.wasm'))) { throw 'Web export is incomplete. Inspect .runtime/web-export.log.' }
Write-Output 'Relic Tide web build ready in web/build.'
