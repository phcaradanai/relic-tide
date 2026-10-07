# Relic Tide verification — 2026-10-06

The stage-2 and stage-3 sections below are historical checkpoints; current stage-4 evidence is recorded at the end. The earlier automated and two-browser observations apply to stage 2 as it stood before the new gameplay. Stage 3 was subsequently compiled into the web export in this turn; its gameplay acceptance has not been playtested. Stage-2 movement, camera, privacy and lantern details remain useful evidence for unchanged systems.

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

## Stage 4 — complete expedition implementation and current verification

Implemented on 2026-10-06 with Godot 4.7.2 on macOS. All local checks below passed. Human balance/social playtests, multi-computer WAN, HTTPS/WSS and other browser engines remain pending; this is an implemented prototype, not final presentation acceptance.

| Current suite | Result | New proof |
| --- | --- | --- |
| rules_test.gd | 643 checks, 0 failures | Distinct controls/full hold/reset, gate use from both sides after unlocking, contested/duplicate pickup, drop/reclaim, real carry slowdown, cancellation/range loss, atomic extraction, empty-handed escape, drowning drop/recovery, breath restoration and dry stranded refuge at deadline |
| privacy_test.gd | 77 checks, 0 failures | Serialized visible carried idol only, no remote relic coordinates, no rival breath/score or early outcomes, closed-gate concealment and public final result records without coordinates |
| authority_test.gd | 53 checks, 0 failures | Peer-derived distinct operators, exact event schemas, stale/duplicate/injected-score rejection, server-only scoring, terminal command rejection and result retention/cleanup |
| scene_test.gd | 57 checks, 0 failures | Native nearby prompts, guide hold cancellation, same-tick carry prediction, Q drop priority, held extraction, terminal movement suppression and reusable result/lobby controls |
| render_test.gd | 23 checks, 0 failures | Apple M1 Compatibility renderer: two visible operators, actual held/dropped transparent idol, boat/progress and banked results at 960×600; retains wall/door/water/refuge visual checks |
| Run-NetworkTests.ps1 | All 12 scenarios passed across full 11-case run plus focused expedition-latency run | Existing eight cases plus complete 2/3/4-person expeditions and a full two-person expedition through 200ms RTT + periodic 180ms ordered stalls |
| Web release + web_smoke_test.mjs | Export succeeded; 8 checks, 0 failures | Matching official no-threads Web templates, explicit raster resources, served HTTP payloads/MIME, excluded sources and same-site WebSocket upgrade |

The full online bots use actual client walking and server collision; no server-side teleports or accelerated tide are used. They join from the lobby, walk both operators to separate C1 controls, hold to open D4, contest the idol, drop it and let the other explorer claim it, return to the Landing boat and extract. Every recipient reports all humans escaped, exactly 100 total points and the new holder as the winner. The delayed full expedition passed 1,261 host and 1,296 guest checks. The existing delayed movement case measured 68px snapshot lead and 34px correction; these are local TCP delay/stall observations, not WAN or physical packet-loss measurements.

Stage-4 held intentions renew through ordered events every 200ms and expire after 500ms without renewal. Authority rechecks reach and active state. D4 controls A/B are shared map points in C1; distinct people must hold them continuously for 1.5s. Early release/range loss/inactivity resets progress. Unlocking opens the gate and permanently releases its latch; later operation remains possible from either side by one explorer.

The single idol starts on the Vault pedestal, can be dropped at the carrier's feet and claimed by another nearby explorer, and slows movement to 75% in both authority and prediction. Breath drains in deep water and restores only on dry floor. Drowning drops the idol and physical lantern locally. Landing extraction requires a continuous 2s hold inside the authored boat area and banks 100 points atomically; empty-handed escape scores zero. Escaped/drowned explorers cannot issue gameplay events or return. Completion publishes final scores/outcomes only, keeps surviving deadline occupants stranded, and never changes the refuge's water to force a result. Completed room results survive peer departure.

Current captures: [vault-cooperation.png](test-output/vault-cooperation.png), [relic-ground.png](test-output/relic-ground.png), [relic-carried.png](test-output/relic-carried.png), [relic-dropped.png](test-output/relic-dropped.png), [extraction-hold.png](test-output/extraction-hold.png), [expedition-results.png](test-output/expedition-results.png) and [expedition-results-960.png](test-output/expedition-results-960.png). Renderer shadow sampling uses floor clear of native prompt text; relocating a prompt does not constitute light leakage.

The new [relic.png](assets/relic.png) was created with built-in imagegen, with actual alpha verified and no raster edits. Its exact prompt is [relic.prompt.txt](assets/relic.prompt.txt); generation provenance is [relic.origin.txt](assets/relic.origin.txt). Control wheels and the Landing boat reuse transparent cells in the existing generated action-icons atlas. Full directional carrying/mechanism poses, final layered scenery and audio remain stage 5. Build and network PowerShell scripts now restrict WindowStyle to Windows, preserving Windows behavior and permitting macOS runs. Official export templates were downloaded from the [Godot 4.7.2 archive](https://godotengine.org/download/archive/4.7.2-stable/) into ignored runtime storage, then the two no-threads Web templates were installed in this host's standard Godot template directory. Temporary custom-template paths were restored after export.

Actual browser QA used two ego-browser tabs joining the same live room via the native list, including the 960×600 lobby. P1 walked to the Landing boat and held E to escape empty-handed. P2 stayed in the live expedition as water rose, moved to the boat, then drowned when deep water exhausted breath before another extraction. P2 displayed the public P1 escaped / P2 drowned / zero-points / no successful relic extraction result. Full recipient agreement is covered by the separate-process tests. This also confirms that an inactive tab does not pause authority. The full successful 100-point relic route is verified by the separate-process network suites, not claimed as a manual two-browser relic playtest. Browser captures: [web-stage4-lobby-960.png](test-output/web-stage4-lobby-960.png), [web-stage4-boat.png](test-output/web-stage4-boat.png), [web-stage4-escaped.png](test-output/web-stage4-escaped.png) and [web-stage4-results-p2.png](test-output/web-stage4-results-p2.png).

## Walking acknowledgement correction — 2026-10-07

The reported symptom was the explorer stepping backwards while the scenery remained smooth. A 120-frame held-up trace reproduced 10 backwards frames under jitter and 8 under a 200ms round-trip stall; the largest backwards step was 3.5765 world units. Corrections also drove the sprite to face south while up remained held.

`scripts/movement_view.gd` now blends local presentation offsets within a 34-world-unit bound and previews the fraction of the next 50ms tick without mutating prediction. Shared geometry checks the whole offset path; newly closed doors remove an invalid offset. Gait uses the held direction and forward rendered distance. Fixed-step prediction, server movement, recipient filtering and command payloads are unchanged.

`tests/movement_view_test.gd` exercises the actual Main scene with deterministic ordered input/snapshot queues: steady, jitter, 200ms stall, 200ms burst and turn/release at 30/60/120 FPS. All **66 checks passed**: no backwards render frames or correction-induced facing, valid feet, bounded offsets, release convergence, gate closure and the pending-input limit. Numeric traces are in `test-output/movement-view-traces.json`.

Rules **643**, privacy **77**, authority **53**, scene **573**, holding **165**, explorer motion **19**, prop geometry **10**, native gameplay render **23** and environment render **12** checks passed. All twelve network scenarios passed across the initial run and an isolated rerun of the delayed expedition; that rerun passed **1,239 host / 1,194 guest checks**. Native render checks run with the window focused, since taking focus away intentionally cancels held interactions. These are local deterministic/TCP-relay checks, not WAN verification.

The final release was rebuilt and passed **8 HTTP/WebSocket smoke checks**. Two actual browser clients joined the same room; P1 used the test relay (100ms each way, periodic additional 180ms stalls), picked up the shared lantern, walked north through D0 and D1, stopped, then dropped it. Foreground captures retain the north-facing carried pose and the settled idle; the drop capture shows the shared ground lamp and the pickup prompt. Both clients left the room. The relay was stopped and the final kept browser was reloaded with `window.relicTideServerURL` absent, showing the normal local lobby at `http://127.0.0.1:8080`. Evidence: `test-output/web-walking-{held-lantern,north-0,north-1,north-2,north-stop,lantern-drop,ready}.png`.
