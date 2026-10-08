# Relic Tide

## Product identity

Relic Tide is a real-time co-op/competitive online game for 2–4 people exploring a flooding ancient ruin, taking relics and escaping. Helping, blocking, abandoning and competing happen through visible world interactions.

**Take the relic. Trust no one. Beat the tide.**

The four pillars are Explore, Cooperate, Betray and Escape. This is social tension through immediate choices; there is no assigned impostor role. Only extracted treasure scores.

## Authoritative documents and implementation status

This document defines the approved target. GAMEPLAY_EXPANSION.md records the user's 7 October 2026 expansion; REALTIME_SPEC.md defines production rules and the preserved prototype fixture; DESIGN.md defines presentation; REALTIME_PLAN.md records delivery and acceptance.

The production game now has three large authored levels, a Start screen, a physical waiting room, host map selection and readiness. Seeded local breaches, blackouts, toxic rooms, intermittent hunters, private chest puzzles and survival equipment run in the same fixed-step authority as movement, gates, the two-person vault and extraction. Human balance and WAN playtests remain pending. Current proof is recorded in EXPANSION_VERIFICATION.md; historical first-slice evidence remains in REALTIME_VERIFICATION.md.

## Production expeditions

Choose the Drowned Lagoon, Brass Foundry or Sunken Catacombs. Each authored 3840×2560 layout has twelve rooms, branching segmented corridors, physical gates, eight puzzle chests, one cooperative vault, a Landing boat and exactly one single-entry refuge. Stable roles include:
- Landing / extraction.
- Archive, an ordinary room on the alternate route.
- Workshop, an ordinary room with the flood-routing valve.
- Inner Vault, containing one valuable carryable relic.
- One watertight refuge.

Players move continuously, solve rune, circuit and pressure puzzles, collect exploration tools and bankable treasure, close routes against warned flooding, cooperate to unlock the vault, and physically return to extract. A collected map reveals static structure; a chart points toward treasure. Oxygen enables submerged traversal, a gas mask protects against toxic exposure, medkits restore a heart and limited tranquilizer ammunition can delay monsters or other explorers. Hunter waves spawn one creature for each active explorer; each pursues its assigned explorer until it loses sight and the short search fails, or the explorer escapes its pursuit range. The wave ends only after its hunters leave, followed by a rest interval. Explorers have three hearts and a separate air reserve. Carrying the great relic still slows movement.

Do not scale refuge count with player count. Each shipped level has **one**. The old five-room Sluice Vault is an internal regression fixture, never a fourth public map.

## Flooding and guaranteed refuge

Seeded breaches announce their room or passage 24 seconds before admitting water. Water spreads through connected openings using simultaneous area-weighted transfers. Its actual depth changes traversal, speed and air consumption.

Fully shutting a production gate blocks flow through that connector. Existing water stays after closure, and another warned breach may independently enter a different room. Closing a refuge door completely while the room is still dry guarantees **100% protection for as long as the door stays closed**, even at maximum exterior water. No pressure leak, automatic door breakage, protection expiry or round-end flooding may invalidate this guarantee.

Opening a refuge into a flooded corridor admits water again. Closing after water entered stops new inflow but does not erase existing water. A refuge has one doorway and no hidden water source. Shelter is not extraction.

Each seeded expedition lasts 10–30 minutes. A global evacuation announcement begins 60–120 seconds before its deadline, with a red gauge, countdown and direction toward the Landing. A refuge preserves life and dryness, but only reaching the boat banks treasure. Numeric tuning may change after playtesting; the refuge guarantee may not.

## Physical cooperation and betrayal

- Two people operate separate world controls together to unlock the vault.
- Door position determines whether a player can pass.
- A valve redirects incoming water and changes route risk.
- Dropped relics can be claimed by whoever reaches them.
- A slow carrier can be helped through a door or abandoned.
- Carried relic artwork is visible when its holder is visible.

No abstract Steal, Push or Sabotage menu command belongs in the first slice. Any future contested interaction must have a spatial cause, readable feedback and server validation.

## Authority and visibility

The central room service owns movement validation, world objects, flood state, relic ownership, extraction and outcomes. Clients send intentions, not trusted positions, water levels, inventories or scores. Keep domain rules independent of scenes, timers, input and rendering; the service supplies time and validated world events.

Retain recipient-specific projections. The user's latest 7 October FOV refinement uses supplied Among Us / Goose Goose Duck screenshots: actors should occupy about 12–14% of viewport height. A steady 2.6 gameplay camera provides that scale while preserving the large level and normal sight range. Darkness, power loss, walls and shut gates narrow sight; a physically held lantern helps in darkness. A collected map reveals static geography and the owner's marker, never hidden explorers. Unseen positions, exact inventories, private scores, puzzle challenges and remote outcomes remain hidden. A visible carried relic/light is observable artwork, not permission to send complete inventory. Final scores/outcomes become public at the ending.

Open doorways may permit sight across logical region ids within light range. Walls and future closed doors block sight. This supersedes the earlier strict same-region visibility rule; seeing a door move still does not authorize disclosure of an unseen player's coordinates.

## Platform, rooms and lifecycle

Godot 4, GDScript, browser export with single-threaded Compatibility/WebGL 2. Support desktop/laptop mouse and keyboard with a canvas of at least 960 × 600; phone portrait remains outside this slice.

Reuse the central WebSocket service, six-character room codes and live room list. Full lobbies remain visible but reject joins; started rooms leave the list. Players can walk while waiting. Only the creator chooses the map and starts; changing maps clears readiness. Starting requires 2–4 connected, ready people. Players never enter an IP address or port.

An active disconnect aborts the expedition explicitly. Reconnect, host migration and continuation after disconnect remain separate work. The server must continue its real-time clock when a client opens the guide or its browser tab is inactive.

## Presentation

Use supplied/generated raster scenery and explorer artwork, animated in code. Build rooms from separate floor, wall, foreground, door, object, character and water assets; invisible collision and shadow geometry are allowed. Do not draw scenery or substitute explorers from polygons, meshes or procedural shapes.

Preserve painted limestone, blue/turquoise water, warm brass, recognizable explorers, compact native controls, system fonts and asset provenance. The entire environment belongs to the playable floor/wall/prop map; no city or video backdrop is used. The HUD uses authored emblems, three hearts and air/tide gauges. Reduced motion suppresses decorative loops while retaining actual gameplay updates.

The older four-layer city image is a useful legacy asset/reference; its anchor layout, fixed layer count and six-second travel are not the new playable-world contract.

## Delivery and current verification limits

Play.cmd or Play-Web.cmd starts the local HTTP proxy and headless room service through Play-Web.ps1; open http://127.0.0.1:8080. Browser clients use the site's WS/WSS /rooms route, with an operator override if needed. Rebuild code/assets with web/Build-Web.ps1 and deploy all web/build files together.

Public delivery requires HTTPS hosting, a persistent room service and a reverse proxy. Public HTTPS/WSS and WAN real-time performance remain unverified. Existing localhost/render checks do not establish real-time playability or visual parity with the references. See web/README.md and server/README.md for infrastructure instructions.

## Completion of the first slice

Groups of 2, 3 and 4 can complete one expedition from lobby to result. Movement is independent; doors and water change accessible routes; the refuge remains dry when sealed in time; cooperation and betrayal are observable; one relic cannot have two holders; only extraction produces score; every client agrees on authoritative outcomes.

Run rules, privacy, authority, scene, network, renderer and browser verification appropriate to the implementation, then conduct human playtesting and WAN checks. Stage 1 baseline results are recorded in REALTIME_SPEC.md.

## Non-goals

Progression, fixed traitor roles, automatic matchmaking, reconnect, mobile redesign, full fluid simulation and speculative transport/provider abstractions. Additional authored maps, seeded events and limited tranquilizer combat are explicitly in scope under the user's 7 October expansion.
