# Main expedition · Real-time target

## Implementation status

Stages 1–3 are implemented: online fixed-step movement, collision, prediction, light-dependent local vision, physical doors, regional water, a held valve and one watertight refuge. Camera is centered on the explorer; walls and closed doors occlude sight, torches/held light widen it, and server snapshots omit unseen people/objects. Rule, privacy, authority, scene, renderer and separate-process network checks pass; human playtesting and tuning are pending. Relics, the two-person vault latch and extraction remain stage 4. REALTIME_VERIFICATION.md records current evidence; historical screenshots/finish verdicts are legacy.

## Direction contract

THESIS: A painted flooding ruin in which 2–4 online explorers see nearby cooperation, door blocking, relic carrying and escape happen in real time.
OWN-WORLD: Raster moonlit stone, turquoise moving water, warm torches/relics and recognizable explorers. Invisible collision/shadow shapes are permitted; drawn scenery/explorer substitutes are not.
STORY: Explore corridors and rooms, cooperate to unlock a vault, decide whether to share space/help or take the relic, then extract before routes are cut.
LEVEL: Five rooms and three corridor regions, a main and alternate route, one valve, one two-person unlocking gate and exactly one watertight refuge. Future levels have only 1–2 refuges.
SAFETY: A fully closed dry refuge admits zero water at any exterior tide. No leaks, timed expiry, pressure failure or end-of-round drowning. Reopening allows inflow; later closure retains already admitted water.
FORM: Elevated top-down 2D with a 2.5D impression. Separate raster floor, walls/foreground, doors, objects, characters and water. Stage 3 clips a repeating raster water texture to visible region floors and animates transparent raster gates. No fixed legacy four-layer/anchor layout.
FIRST VIEWPORT: The playable world dominates, with compact transparent local resources/danger and nearby object prompts. No turn, plan lock, initiative or waiting-for-all chrome.
PRIVACY: User refinement supersedes same-region-only visibility: include explorers only within observer light radius and floor/obstacle LOS. Walls and closed doors block sight; open connectors may reveal nearby people across ids. Unseen coordinates/region/velocity/light state, distant ground lights and hidden door/water state are omitted; no whole-map view or global player minimap.
MOTION: Actual walking plus player-centered 1.65× camera, no pointer parallax or decorative drift. Empty-handed raster poses; separate lantern only for actual holder. Doors, regional water, water movement penalties and the valve are authoritative. Reduced motion retains gameplay movement and danger feedback.
CONTROLS: WASD/arrows, E nearby door/light, hold E at the valve for 1.5 seconds, Q drop light, H guide, V reduced motion, R leave. Releasing E or moving away cancels valve use. Guide does not pause the server; lobby typing owns input.
FINISH: Playtest stage-3 door obstruction, local water transitions, valve routing and early/late refuge closure, then refine visual alignment and tuning. Stage 4 adds a visible relic, co-op gate and extraction. Independent online players and WAN evidence remain required before claiming a finished game. First finish one reference-quality room before expanding assets.

## Platform and reusable infrastructure

Godot 4 GDScript, single-threaded Compatibility/WebGL 2, logical 1440 × 900 and supported desktop canvas at least 960 × 600. Phone portrait remains unsupported. Reuse central WebSocket service, six-character room codes/list and operator-configured WS/WSS /rooms; no player IP/port fields.

Started rooms disappear, full lobbies reject joins, creator starts with 2–4 connected people. An active disconnect aborts; reconnect/host migration remain outside this slice. Public HTTPS/WSS and real-time WAN performance remain unverified.

## Legacy asset and verification reference

Preserve assets/city.png, city-flood.png, explorers.png, explorers-walk.png, action-icons.png and source/generation provenance. The current city ART_RECT is (45,0,1350,900); the previous six-second anchor travel and flood crossfade are legacy behavior.

Sprite isolation through scripts/sprite_atlas.gd preserves crossing-cell silhouettes and antialiased edges; do not reintroduce naive grid clipping without visual review. Existing transparent glass controls and system fonts are continuity references.

Fresh stage-1 baseline on 2026-10-06: rules 41390, privacy 39, authority 30, scene 106, renderer 4 and web smoke 8 checks all passed; all six network scenarios passed. These do not verify the real-time target or manual browser playtesting. Details and planned RT01–RT15 cases are in REALTIME_SPEC.md.
