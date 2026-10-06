# Relic Tide room server

The game now uses a central Godot WebSocket room service for **room codes, the room list and authoritative matches**. Players make an outbound connection to the configured service. They never enter an IP/port or host an inbound game socket.

No public server or domain exists yet. The checked-in endpoint is `ws://127.0.0.1:24567` for development. The instructions below prepare deployment; no hosting account, domain, firewall rule or cloud resource has been created by this task.

## Local smoke test on Windows

Install/use Godot 4.4+ (verified 4.7.2). Set `GODOT_BIN` to its executable. In a PowerShell terminal at the project root:

```powershell
& $env:GODOT_BIN --headless --path . --script res://server/room_server.gd
```

The server reports `Relic Tide room server ready on 127.0.0.1:24567`. Keep that terminal running. For native development, open `Play.ps1` twice, choose **Create room** on one client, then either enter its six-character code or select it in the other client's room list. Double-click joins a listed available room. When both are connected, the creator clicks **Enter the ruin**. Ctrl+C stops the server and ends connected sessions.

For automated verification:

```powershell
./tests/Run-NetworkTests.ps1
# Capture the real browser and creator/client lobby at the minimum window size:
./tests/Run-NetworkTests.ps1 -OnlyCase lobby -RenderLobby
```

The runner starts and stops its own server. It checks complete 2/3/4-player matches, both participant-disconnect directions and actual list/code/full-room behavior.

## Internet deployment with a domain

Use one persistent Linux/Windows host capable of running Godot headlessly and holding long-lived WebSocket connections. Deploy the same project version as the clients. Server code has no graphics dependency; do not run the graphical main scene. Keep one authoritative server process for this prototype: room membership and matches live in its memory and cannot be randomly split across multiple replicas.

1. Copy the project to the host, excluding `.godot/`, `.runtime/`, `test-output/`, `graft/` and `.impeccable/`. Install a compatible Godot binary. Import/export caches are not required by the headless server script.
2. Start the service on loopback behind a TLS reverse proxy:

```sh
godot --headless --path /opt/relic-tide --script res://server/room_server.gd -- --bind=127.0.0.1 --port=24567
```

3. Point an owned domain, for example `game.example.com`, at that host. Terminate TLS at the reverse proxy and forward WebSocket traffic to `127.0.0.1:24567`. A Caddyfile example is supplied in `server/Caddyfile.example`; replace the example domain. Caddy's reverse proxy supports WebSocket upgrades. See its [official reverse proxy documentation](https://caddyserver.com/docs/caddyfile/directives/reverse_proxy). Expose the proxy's HTTPS TCP port, plus whatever certificate-issuance port the selected proxy configuration requires. Keep the Godot backend on loopback; no player-side port forwarding is needed.
4. For the web release, copy all files from `web/build/` into `/srv/relic-tide/web/`. The supplied Caddyfile serves this build and forwards `/rooms` to Godot. Browser clients automatically use `wss://game.example.com/rooms`. See [web instructions](../web/README.md). Native clients instead use `network/room_server_url`, `RELIC_TIDE_SERVER_URL`, or `--server-url=<url>`.
5. Restart the service through your process supervisor after deploying code. A Linux systemd example is supplied in `server/relic-tide.service.example`; create the named service user and adapt the binary/project paths before installing it.
6. From two separate internet connections, verify the release checklist below before inviting players.

Godot validates the hostname/certificate for `wss://` connections by default; this implementation does not disable verification. See [WebSocketMultiplayerPeer documentation](https://docs.godotengine.org/en/4.7/classes/class_websocketmultiplayerpeer.html). Local unencrypted WebSocket tests passed. Public DNS/TLS/proxy deployment and WAN play have not been tested because no server/domain has been supplied. This Windows environment also emits a root-certificate-store warning; check the target clients' TLS trust stores during the WSS test.

For a private development LAN without a reverse proxy, an operator can bind `0.0.0.0` and configure the client endpoint to that machine's `ws://` address. This is only a development setup; players still use room codes. Use WSS for public deployment.

## Release checks

- A room created on connection A appears on connection B, and joining by both code and list succeeds.
- The room shows connected/max players; a full room rejects another join. Started expeditions vanish from the available-room browser and reject code joins.
- Only the creator starts, with at least two players. Run complete 2- and 4-player treasure matches.
- Players only see co-located explorers. No remote positions, plans, inventories or private events arrive in client snapshots.
- A participant leaving during a match ends it explicitly. Leaving before start frees a slot; a creator leaving before start closes the room for everyone. Abandoned rooms disappear.
- Two independent rooms can play without receiving each other's views. After a player leaves and joins another room, the previous room cannot send snapshots to that player.
- A server restart clears rooms/matches and clients show a recoverable service-disconnected message. Refresh reconnects. Confirm the proxy keeps sockets open for a full match.

## Operations and prototype limits

Rooms are public and listed; the six-character code is an address for convenience, not a password. There are no accounts or private/password rooms. Codes are server-generated and unique among current rooms. Capacity is 2–4; the service bounds the room pool at 64 and connections at 256, and limits lobby/interaction commands to 30 and movement commands to 40 per peer per second. These are implementation bounds, not proven production capacity figures.

The central service owns rules and sends recipient-specific views. Creator status grants start permission, not simulation authority. This removes the previous trusted-player-host model. Clients cannot supply a player identity or room to act for someone else. It validates nearby door and valve interactions using the connected seat, match token and event sequence. Illegal, stale and already-locked actions are rejected.

Disconnects abort active matches; there is no reconnection or creator migration. Relic scores and extraction remain stage 4; aborted views remain available to connected members. Rooms/matches have no disk persistence and are lost on service restart. Simulation runs independently at 20Hz; an idle human does not delay others. Stale movement stops after 250ms, and 10Hz snapshots filter light range plus wall/door LOS and send only nearby door/water state. No full state is broadcast. The service is a small playable prototype, not a load-tested public matchmaking platform.


