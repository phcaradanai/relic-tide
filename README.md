# Relic Tide

**Take the relic. Trust no one. Beat the tide.**

Relic Tide is a real-time co-op/competitive online extraction game for 2–4 people. Lagoon, Foundry and Catacombs each contain a 3840×2560 playable ruin, twelve rooms and segmented gated corridors. Floors, props and gates form the actual level; production has no separate decorative background or video. Normal vision is broad; darkness, blackouts, walls and closed gates restrict sight.

Find treasure, solve chest challenges, collect survival equipment and return to the Landing boat. Local flood warnings give time to shut gates and sacrifice routes. Hunters appear in short waves with quiet intervals. Seeded rounds last 10–30 minutes, including a final 60–120-second escape warning. Every level has one refuge that stays dry indefinitely when sealed before water enters; shelter banks no treasure.

Read [product identity](PRODUCT.md), [production rules](REALTIME_SPEC.md), [visual direction](DESIGN.md), [expansion contract](GAMEPLAY_EXPANSION.md) and [verification evidence](EXPANSION_VERIFICATION.md). The old five-room prototype remains an internal regression fixture.

## Play locally

```bash
# macOS / Linux: set the path to your Godot 4 executable.
export GODOT_BIN="/path/to/Godot.app/Contents/MacOS/Godot"
node web/serve.mjs --godot="$GODOT_BIN" --port=8080
```

On Windows, double-click `Play.cmd` or `Play-Web.cmd`, or run `pwsh ./Play-Web.ps1`.

Open [localhost:8080](http://127.0.0.1:8080) and keep the service terminal running. Choose **Start**, then create a room for 2, 3 or 4 people. Others join with its six-character code or double-click the live room list. Walk around the Landing while waiting. The host selects a level; changing it clears readiness. At least two connected players must all choose **Ready** before the host enters the ruin. Full or started rooms reject new joins.

| Control | Action |
|---|---|
| WASD / arrows | Walk in any direction |
| E | Use the nearest chest, gate, mechanism, lantern or relic; hold for valve, paired vault controls or extraction |
| Q | Drop the relic first, otherwise the lantern |
| 2 | Open the static layout after collecting a map |
| F | Fire a tranquilizer toward the mouse, when equipped |
| 1 | Use a medkit |
| Space | Ready in the waiting room; hit the pressure puzzle gauge |
| Esc | Close the map or puzzle |
| H | Open the guide while the round continues |
| V | Toggle the retained reduced-motion preference |
| R | Leave the room |

Rune chests ask you to remember four seals; circuit chests ask you to match three switches; pressure chests require three timed hits. Rewards include maps, treasure charts, oxygen tanks, gas masks, medkits or tranquilizers with limited ammunition. A solved chest grants treasure once and permits each other player one provision claim. The chart points toward a static unopened goal and never tracks a hidden holder.

Three hearts show health; a medkit heals one. Deep water drains tank oxygen first, then the 20-second air supply. Empty air causes drowning. A mask protects against toxic rooms. Tranquilizers briefly stun visible monsters or other players. Each monster wave sends one hunter after each active explorer. Hunters search the last seen position briefly and only leave after losing the trail or pursuit range; their visible departure is animated. Wounds and carried relics slow walking. Occupied gateways cannot close around an explorer. Local flood warnings precede water entry by 24 seconds. Closing a gate stops transfer across that connection; existing water and breaches on either side remain.

Hold the two separate vault controls with a partner for 1.5 seconds to unlock its single physical idol. Hold E at the Landing boat for two seconds to escape and bank treasure plus 100 points for the idol. Death drops held physical items. Unextracted treasure is not banked.

There are no player IP/port fields. Web clients use the site's `/rooms` route. Localhost is for this computer; separate computers require a shared endpoint. [Deployment instructions](server/README.md) are available. Public HTTPS/WSS and human internet playtests remain pending. Leaving, reloading or disconnecting during an active round aborts it; reconnect and host migration are not implemented.

## Authority and privacy

Rules run at 20Hz with recipient-filtered snapshots at 10Hz. Clients and authority share per-match geometry. Movement packets contain direction, sequence and match token, never client positions. Bounded prediction and fractional presentation smooth acknowledgements. Focus loss sends neutral input; stale input stops after 250ms.

Open connections may expose nearby people across region ids; range, darkness, walls and gates determine visibility. Hidden explorer packets omit position, velocity, region and held items; clients clear stale presentation caches. Rival gear, breath, health, exact treasure, puzzle data and hunter routes remain private. A collected blueprint contains static structure and your own marker only. Authority never sends full state for clients to hide.

Each match owns its geometry, power, seeded events and gates. Production closed gates have zero cross-gate flow; late closure retains existing water. The sole refuge cannot receive a local breach and stays protected when sealed dry, including at the deadline. Prototype permeability and six-minute timing apply only to internal QA.

## Development and verification

Use Godot 4.4+; this delivery was verified with 4.7.2. Import `project.godot` for editor development. Set `GODOT_BIN`, then run these headless suites with `"$GODOT_BIN" --headless --path . --script res://tests/<suite>.gd` on macOS/Linux, or `& $env:GODOT_BIN --headless --path . --script res://tests/<suite>.gd` in PowerShell:

- `rules_test.gd`, `privacy_test.gd`, `authority_test.gd`, `scene_test.gd`
- `movement_view_test.gd`, `expedition_map_test.gd`, `expedition_rules_test.gd`
- `expedition_privacy_test.gd`, `waiting_lifecycle_test.gd`

Run `pwsh ./tests/Run-NetworkTests.ps1` for actual socket clients. Native `render_test.gd`, `environment_render_test.gd` and `puzzle_input_test.gd` require a graphics session; omit `--headless`. The last suite exercises actual GUI mouse/key input, single rewards and the 25-second owner lease. Rebuild with `pwsh ./web/Build-Web.ps1` after runtime changes. New runtime files belong in `export_presets.cfg`'s explicit list. Verify the running web service with `node tests/web_smoke_test.mjs http://127.0.0.1:8080`.

The network runner rejects script errors and covers fifteen scenarios, including all three large levels with 2/3/4 actual client processes, puzzles, shared provisions, extraction, disconnects and a relay with 200ms round-trip delay plus periodic 180ms stalls. This proves local reliable-transport behavior, not WAN conditions. Captures are in `test-output/`. [EXPANSION_VERIFICATION.md](EXPANSION_VERIFICATION.md) records current evidence; [REALTIME_VERIFICATION.md](REALTIME_VERIFICATION.md) is historical. Human balance and sustained multi-person sessions still need playtesting.

## Asset production

[Asset pipeline commands](ASSET_PIPELINE.md) cover private PixelLab access, editable Aseprite imports, the installed local Depth-Anything-V2 model and historical DepthFlow studies. Production uses original raster environment/prop/icon sheets and preserves the explorer's grounded eight-direction movement, pickup and physically held relic/lantern poses.

The original PixelLab brine stalker has walk, idle, attack and stun in all eight directions: 256 frames and 32 tags. `tools/assets/monster_production.py` tracks accepted jobs, completes missing directions and packs Aseprite/Godot output with provenance. Current production uses no DepthFlow footage. Earlier media and studies remain source evidence; their integration is superseded by the playable-map expansion.
