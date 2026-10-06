# Stage 2 verification and stage 3 implementation — 2026-10-06

The fresh automated and two-browser observations below apply to stage 2 as it stood before the new gameplay. Stage 3 was subsequently compiled into the web export in this turn; its gameplay acceptance has not been playtested. Stage-2 movement, camera, privacy and lantern details remain useful evidence for unchanged systems.

## Current behavior

- Authority advances shared movement/collision rules at 20Hz and sends recipient-specific snapshots at 10Hz. Clients send direction, ordered sequence and match token; seat and position come from authority.
- Vision radius is 105 logical pixels without a lantern, 220 with one, and up to 250 near a torch. Torch influence tapers across 110 pixels. Walls block sight. Nearby people can be visible across open room/corridor boundaries.
- Hidden rivals have no serialized position, velocity, region or held-light state. Unseen ground-lantern coordinates are also omitted. Client presentation clears hidden-position caches.
- E picks up the nearby lantern within 38 pixels and unobstructed sight; Q drops it at the holder's feet. Authority resolves contested pickup to one holder. Empty-handed sprite edits prevent a baked lantern from implying false ownership.
- Camera zoom is 1.65× and follows the explorer. It has no mouse parallax, decorative drift or shake. Movement prediction is bounded, acknowledged and reconciled; remote actors interpolate.

## Fresh automated results

Verified using Godot 4.7.2 on Windows. The render suite used the real NVIDIA/OpenGL renderer; it was not a headless visual assertion.

| Suite | Result | Coverage |
| --- | --- | --- |
| rules_test.gd | 555 checks, 0 failures | Independent ticks, speed/direction validation, stale-input stop, collision, both traversable routes, repeatability, lantern ownership and light/LOS |
| privacy_test.gd | 64 checks, 0 failures | Serialized recipient filtering, darkness, walls, lantern range, open connectors and distant ground-object privacy |
| authority_test.gd | 35 checks, 0 failures | Lobby lifecycle, peer-derived identity, spoof/stale/duplicate rejection, rate budgets and physical-light events |
| scene_test.gd | 44 checks, 0 failures | Native lobby, movement/camera, input focus/help, sprite isolation, lantern pickup/drop and bounded delayed reconciliation |
| render_test.gd | 10 checks, 0 failures | Actual raster movement, camera, dark floor, held-light expansion, wall shadow, torch range and lobby return |
| Run-NetworkTests.ps1 | All 7 scenarios passed | Separate-process 2/3/4-player matches, participant disconnect, host leave, live lobby and delayed transport |
| web_smoke_test.mjs | 8 checks, 0 failures | HTTP export, payloads/MIME, excluded source files and WebSocket upgrade |

The final delayed-transport run added 100ms each way plus a periodic 180ms ordered pause. Its moving host reached a maximum prediction-to-delayed-snapshot lead of 85 pixels and an actual reconciliation correction of 34 pixels. These are different measures: snapshot lead includes travel since the older snapshot. The relay preserves TCP order and models reliable-transport stalls; it does not simulate physical packet loss. The normal final runs had at most 17 pixels of snapshot lead and 12 pixels of correction.

The web export was rebuilt with the active scripts/assets in the explicit export list. Node syntax checks passed for the web service and delay relay. The build rejects script/parse errors.

## Actual browser observations

Two browser clients joined the same four-seat lobby through the live room list and started with two players. At 960×600 and 1280×720, each displayed local surroundings and its own player-centered camera. P1 moved while P2 stayed still. P1 picked up the lantern, moved and dropped it; P2 then picked it up. Both HUDs and carried art agreed with the resulting single holder. The fresh second client reported no console errors. This verifies the exported game in browser tabs on one computer; it is not a multi-computer internet playtest.

Native game captures from the current assets are saved under `test-output/`:

| Capture | Shows |
| --- | --- |
| [realtime-landing.png](test-output/realtime-landing.png) | Starting local view |
| [realtime-walking.png](test-output/realtime-walking.png) | Actual movement and camera |
| [vision-no-lantern.png](test-output/vision-no-lantern.png) | Limited unlit surroundings |
| [vision-with-lantern.png](test-output/vision-with-lantern.png) | Wider vision while carrying the light |
| [vision-wall-shadow.png](test-output/vision-wall-shadow.png) | Nearby wall blocks the adjacent room |
| [vision-near-torch.png](test-output/vision-near-torch.png) | Torch expands visible surroundings |

## Raster assets and prompts

All four assets below were generated or edited with built-in imagegen. Original supplied/generated sources remain preserved. Adjacent `.origin.txt` files record source paths and generation details. Invisible geometry supplies collision and shadows; it does not replace painted scenery.

| Active raster | Saved prompt | Provenance |
| --- | --- | --- |
| [ruin-movement.png](assets/ruin-movement.png) | [ruin-movement.prompt.txt](assets/ruin-movement.prompt.txt) | [ruin-movement.origin.txt](assets/ruin-movement.origin.txt) |
| [explorers-unlit.png](assets/explorers-unlit.png) | [explorers-unlit.prompt.txt](assets/explorers-unlit.prompt.txt) | [explorers-unlit.origin.txt](assets/explorers-unlit.origin.txt) |
| [explorers-unlit-walk.png](assets/explorers-unlit-walk.png) | [explorers-unlit-walk.prompt.txt](assets/explorers-unlit-walk.prompt.txt) | [explorers-unlit.origin.txt](assets/explorers-unlit.origin.txt) |
| [lantern.png](assets/lantern.png) | [lantern.prompt.txt](assets/lantern.prompt.txt) | [lantern.origin.txt](assets/lantern.origin.txt) |

## Remaining stages and limits

Stage 3 now implements physical doors and regional rising water. The first map contains exactly one refuge, R4. A refuge fully sealed while dry admits zero water indefinitely while its door remains closed. Late closure retains water already inside. Refuge is not extraction; Landing is an ordinary room. Actual closed-door state now drives sight blocking. These are implemented rules awaiting interactive stage-3 gameplay verification.

Stage 4 adds relic carrying/contested pickup, cooperative vault unlocking and extraction scoring. The valve, doors and water already have authoritative interactions; the shrine is still scenery. The current background plus raster flood/gate overlays is a movement prototype, with art alignment and final layered scenery still to refine.

Public HTTPS/WSS, real WAN conditions, other browser engines and human social-tension playtests remain unverified. Godot's Windows root-certificate-store warning persists; passing local plain-WebSocket tests does not establish TLS support. Mobile controls, reconnect and host migration are outside this stage.

## Stage 3 code and build state

Godot 4.7.2 successfully rebuilt the final Web export after the stage-3 changes. The export preset includes the new raster assets and lit water layer. Direct rule/scene runs compile and exercise the runtime scripts; export success alone is packaging evidence. Automated checks below pass. Human stage-3 playtesting, measured balance and stage-3 gameplay in the browser remain pending.

| Final stage-3 check | Result | Evidence |
| --- | --- | --- |
| rules_test.gd | 587 checks, 0 failures | Reach, duplicate events, locked gate, occupied closure, sealed-door proximity, same-tick refuge closure, protection beyond round length, late closure, reopening, regional volume conservation, wet movement and actual valve routing/drain |
| privacy_test.gd | 69 checks, 0 failures | Serialized sight filtering, closed-door actor/water privacy and no refuge interior indicator sent outside |
| authority_test.gd | 39 checks, 0 failures | Connection-derived door operation, remote use rejection, exact event schema and injected progress rejection |
| scene_test.gd | 49 checks, 0 failures | Movement, hold release, live world projection and repeatable shadow cleanup |
| render_test.gd | 16 checks, 0 failures | Native Compatibility renderer: actual raster water, full-map darkness, door closure/opening shadows and sealed refuge view |
| Run-NetworkTests.ps1 | 8 scenarios passed across the full seven-case run and focused door run | Separate 2/3/4-player processes, disconnect, host leave, lobby, delayed transport and two-client authoritative door closure/reopening |
| web_smoke_test.mjs | 8 checks, 0 failures | Final release at http://127.0.0.1:8086/, HTTP payloads/MIME, excluded source and same-site room WebSocket upgrade |

The delayed-transport run reached 68 pixels of snapshot lead and 25.5 pixels of actual correction. These checks are local separate processes, not multiple computers over the internet. Native renders were visually inspected; the water stays inside local light and door shadows. The final captures include [flood-wading.png](test-output/flood-wading.png), [door-closed.png](test-output/door-closed.png), [door-open.png](test-output/door-open.png) and [refuge-sealed.png](test-output/refuge-sealed.png).

- Door D0–D5 positions and boundaries live in `scripts/level_map.gd`. The authority advances doors before water each 50ms tick. Doors open in 0.6 seconds and close in 0.75. A doorway with an explorer stays at least 20% open. At full closure, the same authored doorway blocks movement, local actor sight and light shadows.
- Normal fully closed doors retain 8% of open water conductance. Door progress controls collision, visible sprite and flow through the same door record.
- R4/D5 is the only refuge. It starts open and dry. At fully closed progress it has exactly zero water conductance, independent of outside depth or elapsed time. The tick order lets it seal dry when closure completes before that tick's transfer. Water that entered earlier remains if the door is later closed. There is no hidden pressure leak, expiry, extra refill or timer override.
- The external tide starts after a 45-second lead-in and increases to depth 2.2 at 360 seconds. One explorer holds the valve for 1.5 seconds; release or leaving reach cancels it. It directs incoming water to C1 or the C2 service route; the explicit C1 drain removes only already present water. Rates and region thresholds remain prototype tuning, not measured balance.
- Water conductance is area-weighted and all region transfers derive from the previous depth state then apply together. The same local depth drives shallow/wading/deep movement and blocks entry to a region at depth 1.8. Explorers already inside a submerged region can move slowly toward an exit. No breath, drowning, co-op gate unlocking, relic, score or extraction behavior is part of this stage.
- [assets/flood-water.png](assets/flood-water.png) is the visible raster water surface; region floor polygons are only its rendering mask. `scripts/water_layer.gd` uses the same lighting/shadows as the background. [assets/sluice-gate.png](assets/sluice-gate.png) has verified transparent corners. Both were made with built-in imagegen; exact prompts are [flood-water.prompt.txt](assets/flood-water.prompt.txt) and [sluice-gate.prompt.txt](assets/sluice-gate.prompt.txt), with source provenance beside each asset. Stage-3 state stays recipient-filtered: only nearby visible door records and sight-visible region depths are sent; the dry refuge indicator is only available to an observer inside R4.

For the next gameplay pass, review the feel of the 45–360 second tide, whether the 8% seep rate is readable and whether the mapped gate artwork aligns at each doorway. The route switches mechanically on valve completion, not from instant water removal.
