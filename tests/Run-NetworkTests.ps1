param([string]$GodotBin = $env:GODOT_BIN, [string]$OnlyCase = '', [switch]$RenderLobby)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $GodotBin)) { throw 'Set GODOT_BIN to a Godot 4 executable.' }
$projectRoot = Split-Path $PSScriptRoot -Parent
$outputRoot = Join-Path $projectRoot 'test-output'
New-Item -ItemType Directory -Path $outputRoot -Force | Out-Null
$env:APPDATA = Join-Path $projectRoot '.runtime'
$env:LOCALAPPDATA = $env:APPDATA
$launchOptions = @{}
if ($IsWindows -or $PSVersionTable.PSEdition -eq 'Desktop') { $launchOptions.WindowStyle = 'Hidden' }
$cases = @(@{ Count=2; Case='match' }, @{ Count=3; Case='match' }, @{ Count=4; Case='match' }, @{ Count=2; Case='disconnect' }, @{ Count=2; Case='host-leave' }, @{ Count=3; Case='lobby' }, @{ Count=2; Case='latency' }, @{ Count=2; Case='doors' }, @{ Count=2; Case='expedition' }, @{ Count=3; Case='expedition' }, @{ Count=4; Case='expedition' }, @{ Count=2; Case='expedition-latency' })
$cases += @(@{ Count=2; Case='large-expedition'; Map='lagoon' }, @{ Count=3; Case='large-expedition'; Map='foundry' }, @{ Count=4; Case='large-expedition'; Map='catacombs' })
if ($OnlyCase) { $cases = @($cases | Where-Object { $_.Case -eq $OnlyCase }) }
$port = 24602
foreach ($case in $cases) {
    $processes = @()
    $logs = @()
	$delayProxy = $null
	$clientPort = $port
    $serverLog = Join-Path $outputRoot "room-server-$port.log"
    $serverArgs = @('--headless', '--log-file', "`"$serverLog.engine`"", '--path', "`"$projectRoot`"", '--script', 'res://server/room_server.gd', '--', "--port=$port", '--qa-prototype')
    $server = Start-Process -FilePath $GodotBin -ArgumentList $serverArgs @launchOptions -PassThru -RedirectStandardOutput $serverLog -RedirectStandardError "$serverLog.err"
    Start-Sleep -Milliseconds 300
    try {
		if ($case.Case -in @('latency', 'expedition-latency')) {
			$clientPort = $port + 100
			$proxyScript = Join-Path $PSScriptRoot 'network_delay_proxy.mjs'
			$delayProxy = Start-Process -FilePath (Get-Command node).Source -ArgumentList "`"$proxyScript`"", "$clientPort", "$port" @launchOptions -PassThru -RedirectStandardOutput (Join-Path $outputRoot 'delay-proxy.log') -RedirectStandardError (Join-Path $outputRoot 'delay-proxy.err')
			Start-Sleep -Milliseconds 250
		}
        for ($i = 0; $i -lt $case.Count; $i++) {
            $role = if ($i -eq 0) { 'host' } elseif ($case.Case -eq 'lobby' -and $i -eq 2) { 'browser' } else { 'client' }
            $log = Join-Path $outputRoot "network-$($case.Case)-$($case.Count)-$i.log"
            $logs += $log
            $testScript = if ($case.Case -eq 'large-expedition') { 'res://tests/large_expedition_peer_test.gd' } elseif ($case.Case -eq 'lobby') { 'res://tests/lobby_peer_test.gd' } elseif ($case.Case -like 'expedition*') { 'res://tests/expedition_peer_test.gd' } else { 'res://tests/network_peer_test.gd' }
            $arguments = @('--headless', '--log-file', "`"$log.engine`"", '--path', "`"$projectRoot`"", '--script', $testScript, '--', "--role=$role", "--count=$($case.Count)", "--port=$clientPort", "--case=$($case.Case)")
            if ($case.Map) { $arguments += "--map=$($case.Map)" }
            if ($RenderLobby -and $case.Case -eq 'lobby') { $arguments = @($arguments | Where-Object { $_ -ne '--headless' }) }
            $processes += Start-Process -FilePath $GodotBin -ArgumentList $arguments @launchOptions -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err"
            if ($i -eq 0) { Start-Sleep -Milliseconds 250 }
        }
        $deadline = [DateTime]::UtcNow.AddSeconds($(if ($case.Case -like '*expedition*') { 110 } else { 22 }))
        while (@($processes | Where-Object { -not $_.HasExited }).Count -gt 0 -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 100 }
        foreach ($process in $processes) {
            if (-not $process.HasExited) { throw 'Network test process timeout.' }
            $process.WaitForExit()
            if ($process.ExitCode -ne 0) { foreach ($log in $logs) { Get-Content -LiteralPath $log; Get-Content -LiteralPath "$log.err" }; throw "Network test failed: $($case.Case) $($case.Count)" }
        }
        foreach ($log in $logs) {
            if (Get-Content -LiteralPath "$log.err" | Select-String 'SCRIPT ERROR|Parse Error') {
                Get-Content -LiteralPath "$log.err"
                throw "Runtime script error: $($case.Case) $($case.Count)"
            }
        }
        foreach ($log in $logs) { Get-Content -LiteralPath $log | Select-String 'Online ' }
    } finally {
        if (-not $server.HasExited) { $server.Kill() }
        foreach ($process in $processes) { if (-not $process.HasExited) { $process.Kill() } }
		if ($delayProxy -and -not $delayProxy.HasExited) { $delayProxy.Kill() }
    }
    $port++
}
Write-Output "Network integration: all $($cases.Count) selected scenarios passed."
