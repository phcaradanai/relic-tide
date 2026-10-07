# Large expedition verification — 2026-10-07

The approved expansion is implemented for online 2–4-player rooms. Lagoon, Foundry and Catacombs each use a 3840×2560 playable raster world, twelve rooms, segmented gated corridors, eight treasure chests, a co-op vault, the Landing extraction boat and exactly one refuge. Production has no decorative city, depth layer or DepthFlow video. The old five-room prototype is an internal regression fixture.

## Latest FOV result

The user's two supplied Among Us / Goose Goose Duck screenshots supersede the initial widest-camera framing. A standing actor occupies roughly 12–14% of reference viewport height. Production camera zoom is **2.6**, framing the original 44-world-unit explorer at approximately 110–114 pixels on a 900-pixel logical viewport, or 12–13%. Waiting remains 1.18 and Start 1.05. The provisional 1.55 and original 0.85 production zooms are superseded. Physical level dimensions, collision, speed, normal sight range, darkness and authority privacy are unchanged.

The fresh independent visual reviewer inspected both references and the current three-map captures. Its final **ship** disposition covers actor/prop framing and three bounded UI corrections: pressure ticks inside the actual gauge, the **Hit [Space]** action with target/hit count, and an opaque dark countdown backing. It does not establish motion quality, WAN behavior, human balance or exact visual parity with commercial games.

Before: `test-output/expansion-fov-before.png`. Current captures: `test-output/expansion-lagoon-desktop.png`, `expansion-foundry-desktop.png` and `expansion-catacombs-desktop.png`. The pressure and finale have desktop and 960×600 captures. Original raster assets and integrated held-item frames remain intact.

## Gameplay delivered

- Native Start, room creation/code/live-list entry, physical waiting, host map selection, all-connected-player readiness and central service authority.
- Seeded 10–30-minute rounds with local RNG breaches, a 24-second warning before ingress, gas/blackouts, intermittent hunter waves and a final 60–120-second evacuation grace within the round.
- Physical gates stop cross-gate flow when closed. Late closure retains existing water; a breach can continue on its own side. A refuge sealed dry remains dry indefinitely even under exterior maximum water and at the deadline; shelter banks no treasure.
- Rune memory, three-switch circuit and three-hit pressure challenges, server-validated nonce/proximity/owner/timing, treasure granted once and one provision claim per other explorer.
- Three hearts, wounds, medkit healing, 20-second breath, oxygen tanks, gas masks, limited-ammo tranquilizers against visible hunters/players, static collected maps and private treasure bearings.
- Real two-person vault release, one physical relic, held lantern/relic artwork, carrying slowdown, death drops and physical Landing extraction. Only extracted treasure is banked.
- Per-match geometry and power, 20Hz rules/10Hz recipient views, bounded movement prediction and fractional presentation. Hidden actor locations, rival gear/health/breath/treasure, puzzle data, hunter paths/targets and unseen hazards are filtered by authority.

## Automated evidence

All listed suites completed with zero failures. Counts describe assertions in those suites, not coverage percentages or human playtest quality.

| Suite | Passed checks |
|---|---:|
| `rules_test.gd` — legacy physical rules | 643 |
| `privacy_test.gd` — legacy projection | 77 |
| `authority_test.gd` — input/service validation | 53 |
| `scene_test.gd` — lifecycle and scene integration | 573 |
| `movement_view_test.gd` — motion/reconciliation | 66 |
| `expedition_map_test.gd` — three-map topology/routes | 1091 |
| `expedition_rules_test.gd` — seeded survival/puzzles/hunts | 355 |
| `expedition_privacy_test.gd` — production serialized views | 93 |
| `waiting_lifecycle_test.gd` — membership/map/actor cache | 31 |
| `environment_render_test.gd` — actual production rendering, final FOV | 93 |
| `render_test.gd` — legacy renderer and current Start restoration | 23 |
| `puzzle_input_test.gd` — actual native key/mouse GUI and lease/reward boundaries | 101 |
| `web_smoke_test.mjs` — final HTTP/WebSocket export | 8 |

The strict `Run-NetworkTests.ps1` passed **15 real-socket scenarios**, rejecting script/parse errors as well as failed assertions. They include 2/3/4-player movement, lobbies, disconnect/host-leave, physical doors, full unique-relic expeditions and the delayed relay. Three production scenarios use Lagoon with two clients, Foundry with three and Catacombs with four, walking the waiting room, choosing/readying a level, solving rune/circuit chests, sharing provisions exactly once and banking/extracting without teleporting. Separate concurrent rooms retain their own geometry and power.

The relay adds 100ms in each direction plus periodic 180ms ordered stalls. This verifies local reliable-transport delay behavior; it does not simulate physical packet loss or certify WAN performance. Movement suites preserve authority/collision during acknowledgements and correction blending. No measured frame-rate or zero-stutter claim is made.

Native rendering uses Godot 4.7.2, Compatibility/OpenGL on Apple M1. Captures cover Start, waiting, three themes, powered/dark/lantern floor visibility, closed/open gate shadows, wet/dry surfaces, refuge, pressure puzzle, static blueprint, original hunter and final alarm. Scene lighting covers the full feet-order range across the 2560-unit level. Floor crops exclude transparent gutters. The final Web release rebuilt successfully with no script/parse errors; runtime assets are in the explicit export list.

## Browser delivery

The local service remains available at [localhost:8080](http://127.0.0.1:8080), serving the final export with same-site `/rooms` WebSocket transport. Actual Ego Lite screenshots confirm Start, room creation, host selection of Brass Foundry and a second browser's live room list containing the test room. Evidence is `test-output/expansion-web-start.png`, `expansion-web-waiting.png` and `expansion-web-guest-rooms.png`.

After the user explicitly authorized resuming control, **two actual browser clients joined by code, readied, entered a production expedition and walked independently**. E opened the circuit chest. Real GUI mouse actions completed it and awarded **a treasure chart plus 45 treasure**, visible in `test-output/expansion-web-chest-reward-final.png`; no game state was injected. `expansion-web-ready-two.png`, `expansion-web-playing.png`, `expansion-web-playing-guest.png` and `expansion-web-walking-guest.png` record readiness, framing and movement. The test room was left normally; only the final Start page is retained for the user, with the service running.

The browser fallback required mouse motion before press/release and a short press dwell so Godot GUI hover/input processed correctly. Earlier manual automation rounds also exceeded the challenge's 25-second owner lease. A native input probe passed 101 checks: actual E and mouse input solve circuit targets at both sizes, rewards cannot duplicate, and idle challenges expire at the step ending tick502 (25.1 seconds) without loot; stale clicks leave the expedition running. No runtime input fix was needed. Some earlier long-running QA attempts returned to Start; the native probe did not reproduce that transition, so those attempts are not used as gameplay acceptance evidence.

Public HTTPS/WSS, other browser engines, real internet sessions and human balance remain unverified. Leaving/reloading/disconnecting during a round aborts it; reconnect/host migration remain out of scope.

## Asset provenance and usage

Original environment, prop and survival-icon sheets preserve generated native pixels, real transparency and prompt/origin sidecars. Prompts are also embedded in generated PNG metadata. The eight-direction explorer retains four cloth palettes and fifteen original/locally-authored integrated actions, including planted grips and crouching pickups.

The original PixelLab brine stalker is complete: walk 12 frames, idle 8, attack 8 and stun 4, in all eight directions (**256 frames, 32 tags**). Accepted animation groups were extended for missing directions rather than duplicated. All frames use a shared 120×120 transparent padded canvas; runtime feet anchor is (60,99), displayed height 52. Aseprite/source outputs and receipts are preserved. The recorded service allowance changed **1788 → 1703** (85 units); no dollar cost is inferred. No DepthFlow render was submitted for this expansion.

`monster_production.py` gained idempotent missing-direction completion; offline asset-helper validation reported 60 passing checks, and the missing-direction fixture confirmed no resubmission when complete. The graph cache was refreshed with deterministic `graft build`; this installed parser indexes Python/JavaScript/Lua, so GDScript proof comes from the actual Godot suites.

## Remaining playtests

Human multi-person balance still needs to tune round pacing, flood frequency, hunter pressure, gear value, room density and extraction fairness. Sustained user-device performance, real WAN latency, public TLS deployment and other browsers require their own evidence. The delivered mechanics and current reference framing are runnable locally; these limits are not hidden by the test counts.
