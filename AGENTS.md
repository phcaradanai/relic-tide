# Repository Guidelines

## Project Structure & Architecture

Relic Tide is a Godot 4 web game written in GDScript. `project.godot` configures the project; `scenes/main.tscn` is the entry scene.

The approved target is real-time co-op/competitive multiplayer with physical interactions, regional flooding and extraction. Read `PRODUCT.md`, `DESIGN.md`, `REALTIME_SPEC.md`, `REALTIME_PLAN.md` and `GAMEPLAY_EXPANSION.md` before implementation. The latest approved expansion provides three large playable levels, a walkable ready lobby, seeded survival events, treasure puzzles, gear and intermittent hunters. The old five-room prototype is an internal regression fixture. Never restore simultaneous-turn waiting.

- `scripts/game.gd`: pure 2–4-human fixed-step movement, physical doors, water, co-op vault, relic ownership and extraction. Keep it independent of scenes, timers, input and rendering; authority supplies fixed ticks and validated intentions.
- `scripts/expedition_map.gd`: per-match shared large-level geometry, regions, gates, chest/prop anchors, power, refuge and route/LOS rules. No duplicate client/server coordinates. `level_map.gd` remains the internal prototype fixture.
- `scripts/expedition_systems.gd`: seeded round duration and warnings, local breaches, blackout/gas, chest puzzles and rewards, hearts, breath/tanks, healing, tranquilizers, player-scaled hunter waves and banked treasure. Each hunter keeps its assigned explorer until sight/search or pursuit range is lost; fixed-duration wave cleanup is not used. All rules use supplied fixed ticks.
- `scripts/movement_client.gd`: bounded local prediction and acknowledgement reconciliation; sends direction/sequence/match token, never position.
- `scripts/movement_view.gd`: local feet presentation with collision-checked fractional preview and bounded correction blending. Camera/light follow these feet; authority and fixed-step prediction remain separate.
- `scripts/expedition_world.gd`: raster floors, walls and props covering the actual playable map. Production levels have no separate decorative background or DepthFlow video.
- `scripts/world_mechanisms.gd`: painted door frames/slabs and wheel pedestals, local LOS and feet-based depth order.
- `scripts/vision_layer.gd`: local radial lighting and invisible wall/door shadow geometry; uses the shared map's sight rules and never reveals hidden actors.
- `scripts/water_layer.gd`: raster flood surface clipped to projected region floors, using the same canvas lighting and shadows as the playable floor.
- `scripts/survival_hud.gd`, `expedition_puzzle.gd`, `expedition_blueprint.gd`: compact icon HUD, owner-only live challenges and collected static structure map. The blueprint shows the local player's marker, never hidden actors or live remote hazards.
- `scripts/main.gd`: native online controls, player input, walkable scene presentation and raster animation. Legacy artwork anchors are not the target movement model.
- `scripts/session.gd`: WebSocket central-service transport, private packets and disconnect lifecycle.
- `scripts/room_directory.gd`: room-code generation, live room list, membership, per-room authoritative rules and validation.
- `server/`: headless room-service entry, deployment guide and optional proxy/service examples.
- `web/`: Web export script, local HTTP/WebSocket proxy and deployment guide; `web/build/` is generated.
- `scripts/player_view.gd`: recipient-specific visibility projection. Never send full rules state to clients.
- `assets/`: authored/generated raster floors, walls, props, HUD emblems, transparent eight-direction explorer/hunter atlases, and generation/source provenance.
- `tests/`: standalone rules and scene lifecycle checks.
- `PRODUCT.md` and `DESIGN.md`: approved identity, scope and visual direction.
- `REALTIME_SPEC.md`: current production contract followed by clearly marked historical prototype acceptance cases.
- `EXPANSION_VERIFICATION.md`: large-level delivery evidence, test counts, browser captures and remaining playtest limits.
- `REALTIME_PLAN.md`: staged delivery and completion conditions.
- `test-output/`: generated screenshots. `.godot/`, `.runtime/`, and `graft/` are generated local data.

Visuals use supplied/generated raster artwork and system fonts. Code animates images; do not add polygon/procedural scenery or drawn explorer substitutes. Invisible geometry for collision, flood masks and shadow occlusion is allowed. The latest large-level request supersedes the earlier Atlantis background: the entire scene is the playable level, with no decorative depth/video layer. Low props use authored ground contours and painted contact shadows, with no sight occlusion; structural walls and closed doors block authority LOS. Multiplayer is online through a central WebSocket room service for 2–4 people on separate computers. Players create rooms, enter six-character codes or browse; never require player IP/port input. The host chooses a map and at least two connected players must all be ready. Other explorers are visible only within light-dependent range and unblocked LOS. Open connectors can expose nearby people across region ids. Normal camera/range is broad; blackout, darkness, walls and closed gates restrict sight. A collected map reveals static structure only. Unseen positions, exact rival gear, breath, scores, puzzle data and hunter paths stay filtered; held relic/light art is visible with an observable holder. Never send full state and rely on client hiding.

Every current production level has exactly one refuge. A refuge sealed while dry admits zero water for as long as its door stays closed, even under maximum exterior water. No leak, pressure failure, protection timeout or round-end flooding may invalidate this. Production closed gates stop transfer across that connection; existing water and breaches on either side remain. Closing after water entered does not erase it; shelter is not extraction. Each round lasts a seeded 10–30 minutes, with 24-second local breach warnings and a 60–120-second final escape grace within the round. Do not substitute abstract sabotage/steal menus for physical interactions.

## Development & Verification Commands

Use Godot 4.4 or newer. Run commands from the repository root in PowerShell.

```powershell
.\Play.cmd
& $env:GODOT_BIN --headless --path . --script res://tests/rules_test.gd
& $env:GODOT_BIN --headless --path . --script res://tests/scene_test.gd
& $env:GODOT_BIN --headless --path . --script res://tests/privacy_test.gd
& $env:GODOT_BIN --headless --path . --script res://tests/authority_test.gd
& $env:GODOT_BIN --headless --path . --script res://tests/movement_view_test.gd
& $env:GODOT_BIN --headless --path . --script res://tests/expedition_map_test.gd
& $env:GODOT_BIN --headless --path . --script res://tests/expedition_rules_test.gd
& $env:GODOT_BIN --headless --path . --script res://tests/expedition_privacy_test.gd
& $env:GODOT_BIN --headless --path . --script res://tests/waiting_lifecycle_test.gd
./tests/Run-NetworkTests.ps1
& $env:GODOT_BIN --path . --script res://tests/render_test.gd
& $env:GODOT_BIN --path . --script res://tests/environment_render_test.gd
& $env:GODOT_BIN --path . --script res://tests/puzzle_input_test.gd
& $env:GODOT_BIN --path . -- --demo --capture=D:/Projects/relic-tide/test-output/realtime-demo.png
```

The launcher starts web and room services; open http://127.0.0.1:8080. Rebuild with web/Build-Web.ps1 after changing code/assets, and add new runtime files to the explicit export list in export_presets.cfg. Set `GODOT_BIN` for direct commands. Headless suites verify simulation/privacy/lifecycle; the renderer verifies raster motion and saves screenshots. The demo flag is an offline QA fixture only; the public lobby always uses the central service. The network runner includes a 200ms round-trip TCP delay/stall case. Import project.godot for editor development.

## Coding Style & Naming

Follow existing GDScript style: tab indentation, `snake_case` functions and variables, `UPPER_SNAKE_CASE` constants, and PascalCase class names. Use type annotations and `:=` inference where appropriate. Keep rules in `game.gd`/`expedition_systems.gd`, shared geometry in `expedition_map.gd`, and rendering in presentation modules. No formatter or linter configuration is present.

## Testing Guidelines

Tests extend `SceneTree`, use a local `check()` helper, and exit nonzero on failure; no external test framework is required. Name files `*_test.gd` and focused rule cases `test_*`. Add regression checks for changed mechanics or lifecycle behavior. Preserve seeded reproducibility and deterministic domain-rule results with supplied simulation time. Port legacy turn assertions as their behavior is intentionally replaced; do not preserve simultaneous-plan waiting in the real-time target. Cover closure/water boundary ordering, indefinite sealed-refuge protection, reopening/late closure, contested relic ownership, extraction and serialized privacy. Do not assume cross-platform physics is bit-identical. Run rules, privacy, authority, scene and network integration suites for gameplay/network changes; visually inspect presentation changes. No numeric coverage target is configured.

## Commits & Pull Requests

This checkout has no Git metadata, so historical commit conventions cannot be verified. Use concise, imperative commit subjects. Describe the problem, resulting behavior, and validation in pull requests; link relevant issues and include before/after screenshots for visual changes. Exclude generated caches, runtime data, and test output from commits.





<!-- graft:start -->
## Graft — repo context graph

This repo is indexed in `graft/`: small linked markdown nodes that explain each
system and carry exact file:line spans, kept in sync with the code through git.

For ANY task here — understanding how something works, finding where code lives,
or scoping a change — get context from the graph before grepping or opening
source files. Re-ask freely (it's cheap) and reuse literal identifiers you
already have (symbol, error string, file name) as the query. New to this repo?
Run `graft map` first — a token-budgeted orientation (dir clusters, hubs,
hotspots), no LLM, no key.

- Run `graft ask "<your question>" --source` → ranked nodes with the relevant
  code spans inlined (each hit's ≤8-line crux by default; `--full` for whole
  definitions when the crux isn't enough). Match the tool to the task shape:
  for understanding or editing, the top node IS the answer — cite its
  `covers:` file:line spans and edit straight from `--source`. For
  exhaustive tasks ("every occurrence / every caller of this pattern"), ranked
  results are top-N, not complete — run `graft grep "<literal>"` instead
  (exhaustive over indexed files, grouped by enclosing symbol), falling back
  to raw `grep -rn` only for unindexed files.
- `graft skeleton <file>` → every definition's signature + span, ~10× cheaper
  than reading the file; use it to skim an API surface.
- `graft callers <symbol>` gives precomputed, exact edges — who calls this.
  Add `--direction out` for what it calls, or `--depth N` to walk
  transitively for the full blast radius. For structural questions, skip
  ranking and use this directly.
- Or browse: `graft/INDEX.md` lists every node; follow the links.
- Monorepos and folders of multiple repos rank fairly across sub-projects —
  hits carry `[scope/]` labels naming which one they're from. Narrow with
  `graft ask "<task>" --in <scope>/` once you know where you're working.

If a returned span is truncated ("+N more lines"), open the file at that exact
range before finalizing. Only open source files when a node genuinely lacks a
needed detail, and then at the exact file:line the node points to — never
re-read whole files.

After big code changes, refresh the graph with `graft build` (deterministic,
no API key, $0).
<!-- graft:end -->
