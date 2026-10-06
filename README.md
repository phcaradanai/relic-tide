# Relic Tide

**Take the relic. Trust no one. Beat the tide.**

Relic Tide is a real-time co-op/competitive online extraction game for 2–4 people. The current playable prototype adds physical doors, regional rising water, a route-changing valve and the first map's single refuge to stage-2 movement and local vision. Only a dry refuge sealed before water enters stays fully protected; ordinary closed doors slow the flow. Stage 4 adds two-person vault unlocking, one physical relic, carry slowdown, breath/drowning, Landing extraction and final scores. The painted shrine remains scenery; only the separate extracted idol scores.

Read [product identity](PRODUCT.md), [first-level rules](REALTIME_SPEC.md), [visual direction](DESIGN.md) and [delivery plan](REALTIME_PLAN.md).

## Connect and explore

Start the local web server and room service:

- **macOS / Linux:**
  ```bash
  export GODOT_BIN="/path/to/Godot.app/Contents/MacOS/Godot" # or your Godot 4 binary
  node web/serve.mjs --godot="$GODOT_BIN" --port=8080
  ```
- **Windows:**
  Double-click `Play.cmd` or `Play-Web.cmd` (or run `pwsh ./Play-Web.ps1`).

Then open http://127.0.0.1:8080 in your browser. Keep its terminal running. The launcher starts both the HTTP web server (`8080`) and central room service (`24567`). One player creates a room for 2, 3 or 4 people and shares its six-character code. Others enter the code and click **Join**, or double-click a room in the live list. The creator clicks **Enter the ruin** after at least two people connect. Full and started rooms reject new joins.

Move with **WASD or arrows**. **E** uses the nearest nearby object: pick up the lantern, or open/close a door; hold **E** for 1.5 seconds at the Workshop valve to redirect incoming water. **E** also takes the nearby idol; **Q** drops the relic first, otherwise the lantern. Hold separate vault controls A/B with a partner for 1.5 seconds to unlock D4, then take the idol and return to the Landing boat. Hold **E** there for 2 seconds to escape and bank its 100 points; empty-handed escape scores zero. Carrying slows walking by 25%. Deep water drains your 12 seconds of breath; drowning drops the relic at your feet. A dry sealed refuge preserves life at the deadline but awards no extraction score. A doorway with someone in it stays partly open, so it cannot crush or seal around them. The camera centers on the explorer with no mouse parallax or decorative drift. You see only local surroundings: walls and closed doors block sight, nearby torches widen it, and holding the lantern lets you see farther away from torches. There is no full-map view or player minimap. **H** opens the guide while the server continues; **R** leaves. **V** retains the reduced-motion preference; gameplay movement remains animated. Lobby typing owns input. Focus loss sends neutral input; authority stops stale input after 250ms. Reloading/closing aborts the match; reconnect/host migration are not implemented.

There are no player IP/port fields. Web clients connect to the website's `/rooms` route. Local localhost is for testing on this computer; other computers require a shared deployed endpoint. [Deployment files and instructions](server/README.md) are ready, but public HTTPS/WSS and real internet playtesting remain pending.

## Authority and privacy

The service advances movement, doors, held mechanisms, relic ownership, survival, extraction and region-based water at 20Hz, then sends recipient-filtered snapshots at 10Hz. Door timing, collision, sight, water flow and visible art share the authored room connections. The outside tide begins after 45 seconds and reaches its maximum at six minutes; the valve feeds either the main crossing or service passage, while its explicit outlet drains existing crossing water. The event service derives the seat from the connection and validates match token and increasing input/event sequences. Movement collision matches client prediction; clients cannot supply positions. Prediction is bounded during a stalled connection.

You see rivals only within your light radius and unobstructed sight. Open connectors may expose nearby people across room/corridor ids; a shut door also blocks sight. Hidden snapshots omit position, region, velocity and held-light/relic state; the client clears cached positions when they disappear. Distant ground-lantern/relic coordinates, controls, door states and water regions are omitted. Rival breath and exact scores remain private until public final results. Held interactions renew every 200ms and expire after 500ms without renewal. The full map is never displayed. Only R4 is a refuge; Landing is ordinary.

## Development and checks

Use Godot 4.4+; this checkout was verified with 4.7.2. Import `project.godot` for editor development. Set `GODOT_BIN` for standalone checks:

```powershell
& $env:GODOT_BIN --headless --path . --script res://tests/rules_test.gd
& $env:GODOT_BIN --headless --path . --script res://tests/privacy_test.gd
& $env:GODOT_BIN --headless --path . --script res://tests/authority_test.gd
& $env:GODOT_BIN --headless --path . --script res://tests/scene_test.gd
./tests/Run-NetworkTests.ps1
& $env:GODOT_BIN --path . --script res://tests/render_test.gd
./web/Build-Web.ps1
node tests/web_smoke_test.mjs http://127.0.0.1:8080
```

On macOS / Linux (bash):
```bash
# Run test suites
"$GODOT_BIN" --headless --path . --script res://tests/rules_test.gd
"$GODOT_BIN" --headless --path . --script res://tests/privacy_test.gd
"$GODOT_BIN" --headless --path . --script res://tests/authority_test.gd
"$GODOT_BIN" --headless --path . --script res://tests/scene_test.gd

# Export web release & verify smoke test
mkdir -p web/build
"$GODOT_BIN" --headless --path . --export-release Web "$(pwd)/web/build/index.html"
node tests/web_smoke_test.mjs http://127.0.0.1:8080
```
The network runner covers separate 2/3/4-player processes, stationary humans, visibility transitions, spoofed input, both disconnect cases, live lobbies, complete relic expeditions for 2/3/4 people, and a TCP relay adding 100ms each way plus periodic 180ms ordered pauses. This emulates reliable-transport stalls, not physical packet loss or real WAN conditions. Screenshots are generated under `test-output/`. The Windows root-certificate-store warning persists; local plain-WebSocket tests pass and do not establish TLS support.

The raster flood surface and transparent sluice gate use `assets/flood-water.png` and `assets/sluice-gate.png`; the region masks match the simulation. Empty-handed `explorers-unlit.png` / `explorers-unlit-walk.png` keep the lantern art consistent with ownership. Adjacent prompt/provenance files document every generation. The web package includes current scene assets. [Implementation and verification record](REALTIME_VERIFICATION.md) records stage-4 automated and browser evidence, plus remaining human playtest, WAN and stage-5 presentation work.

## Asset production

[Asset pipeline setup and commands](ASSET_PIPELINE.md) covers private PixelLab access, editable Aseprite imports, the installed local Depth-Anything-V2 model and native Godot art studies. The first Workshop carry study is in `scenes/samples/workshop_study.tscn`; [actual quality/cost evidence](ASSET_QUALITY.md) distinguishes the authored baseline and PixelLab candidate. The user resumed funded DepthFlow use on 2026-10-07; the account preset follows its Dashboard payload. Run `python tools/assets/pipeline.py --help` with the documented asset environment. The live expedition and its camera are unchanged.
