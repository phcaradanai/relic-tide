# Relic Tide web game

The browser runs the existing Godot game and painted scene. A central headless Godot service owns rooms and private player snapshots.

## Play on this computer

- **macOS / Linux:**
  ```bash
  export GODOT_BIN="/path/to/Godot.app/Contents/MacOS/Godot" # or your Godot 4 binary
  node web/serve.mjs --godot="$GODOT_BIN" --port=8080
  ```
- **Windows:**
  Double-click `Play.cmd` or `Play-Web.cmd` (or run `pwsh ./Play-Web.ps1`).

Then open <http://127.0.0.1:8080>. The launcher starts **both** the web server and room service; keep its terminal open. Ctrl+C stops both. Create a room and join its code or list entry from another browser tab. Players never configure an endpoint.

Developer prerequisites: Node.js 22+, Godot 4.7.2 (or compatible Godot 4 with matching export templates), and the build below. Set `GODOT_BIN` if Godot is not on PATH. Players visiting the deployed site need only a WebGL 2 capable browser.

## Build

### PowerShell (Windows)
```powershell
$env:GODOT_BIN = 'C:/path/to/Godot.exe'
./web/Build-Web.ps1
./Play-Web.ps1
```

### Bash (macOS / Linux)
```bash
export GODOT_BIN="/path/to/Godot.app/Contents/MacOS/Godot"
mkdir -p web/build
"$GODOT_BIN" --headless --path . --export-release Web "$(pwd)/web/build/index.html"
node web/serve.mjs --godot="$GODOT_BIN" --port=8080
```

Install matching Godot export templates before building. The script uses project-local `APPDATA`, so its template directory is `.runtime/Godot/export_templates/<version>.stable/`. Copy `web_*.zip` files and `version.txt` from the official template archive into that directory. This checkout already has 4.7.2 templates. Obtain versions through [Godot's official download archive](https://godotengine.org/download/archive/).

Rebuild after modifying GDScript or artwork. `web/build/` is generated and ignored. Deploy **all** files in that directory together; opening `index.html` via `file://` does not work. The preset uses single-threaded Compatibility/WebGL 2. Normal HTTP hosting suffices locally without cross-origin isolation headers. See [Godot web export requirements](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_web.html).

## Publish when hosting is available

No public server/domain has been provisioned. A static-only host cannot run authoritative rooms. Use one persistent host running headless Godot and an HTTPS reverse proxy serving the web files:

1. Copy the complete build to `/srv/relic-tide/web/` and server project to `/opt/relic-tide/` as described in [the server guide](../server/README.md).
2. Run headless Godot on `127.0.0.1:24567` under a process supervisor.
3. Adapt `server/Caddyfile.example` to an owned domain. It serves the build at `/` and proxies WebSocket upgrades at `/rooms`.
4. Browser clients derive `wss://<current-site>/rooms` on HTTPS, or `ws://<current-site>/rooms` on local HTTP. They never connect to the visitor's localhost. `project.godot` configures only native clients' endpoint.
5. Test codes/list, full 2/4-player matches, privacy and disconnects from separate internet connections before inviting players.

If the operator hosts the room service elsewhere, set `window.relicTideServerURL` in the exported HTML **before** engine startup to the public WSS URL. Prefer the default same-site route. Do not embed credentials in this URL.

## Supported use and limits

This slice targets desktop/laptop browsers with mouse and keyboard, at least 960 × 600. The canvas preserves the scene with letterboxing. Phone portrait UI and physical mobile-device testing remain future work. Browser tabs can pause when inactive; keep the game tab visible during a match. Reload/closing a tab disconnects its explorer and aborts an active match; reconnection is not implemented.

The current build includes stage 3: physical timed doors, local water depth and texture, movement thresholds, a held valve that switches the feed between the main and alternate routes, and one guaranteed dry refuge when sealed in time. Relics, the cooperative vault latch and extraction remain stage 4. The 2026-10-06 stage-2 browser/network checks are documented in ../REALTIME_VERIFICATION.md; gameplay balance for stage 3 has not been playtested. Public HTTPS/WSS and other browser engines remain unverified.

Run `node tests/web_smoke_test.mjs` while the launcher is active: 8 HTTP/export/WebSocket checks. Current rules/privacy/authority/scene/renderer and seven network scenarios are recorded in ../REALTIME_VERIFICATION.md. Add new runtime scripts/assets to export_presets.cfg's explicit file list before rebuilding. Native Godot reports a Windows root-certificate-store warning; plain local WebSocket checks do not establish public TLS behavior.

Files for this port: `scripts/session.gd`, `scripts/main.gd`, `export_presets.cfg`, `Play.cmd`, `Play-Web.cmd`, `Play-Web.ps1`, `web/Build-Web.ps1`, `web/serve.mjs`, `web/.gdignore`, `tests/web_smoke_test.mjs`, `.gitignore`, and project/deployment documentation. The local room service now also advances doors, the valve and regional water.

The Node server binds loopback and is a development helper. Production uses the supplied reverse proxy and headless service. No package install or Node dependencies are needed.
