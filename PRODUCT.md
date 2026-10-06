# Relic Tide

## Product identity

Relic Tide is a real-time co-op/competitive online game for 2–4 people exploring a flooding ancient ruin, taking relics and escaping. Helping, blocking, abandoning and competing happen through visible world interactions.

**Take the relic. Trust no one. Beat the tide.**

The four pillars are Explore, Cooperate, Betray and Escape. This is social tension through immediate choices; there is no assigned impostor role. Only extracted treasure scores.

## Authoritative documents and implementation status

This document defines the approved target. REALTIME_SPEC.md defines the first level and precise prototype rules; DESIGN.md defines presentation; REALTIME_PLAN.md records delivery stages and acceptance.

Stages 1–4 are implemented and automatically checked. The current web build includes physical doors, regional water flow, a route-changing valve, and exactly one refuge at R4. Independent online movement, shared authored collision, client prediction and recipient-filtered local vision continue through the existing room service. Two distinct explorers hold the vault controls, compete for one carryable relic and return to the Landing boat to extract it. Breath, drowning and final outcomes are authoritative. The painted shrine remains scenery; only the separate physical relic awards treasure after extraction. Human balance and WAN playtests remain pending.

## First playable slice

One authored ruin with five rooms and three corridor regions:
- Landing / extraction.
- Archive, an ordinary room on the alternate route.
- Workshop, an ordinary room with the flood-routing valve.
- Inner Vault, containing one valuable carryable relic.
- One watertight refuge.

Players move continuously, use nearby objects, open and close doors, cooperate to unlock one vault gate, carry/drop/pick up the relic, and extract. Carrying slows movement. A main corridor and a longer alternate path create choices when the valve redirects incoming water.

Do not scale the refuge count with player count. A level has only **1–2 refuge rooms**; this first level has **one**.

## Flooding and guaranteed refuge

Corridor water rises; room water is simulated locally and admitted through connecting openings. Water changes traversal and movement, not just the clock or artwork.

Closing an ordinary room door reduces water inflow and delays flooding. Closing a refuge door completely while the room is still dry guarantees **100% protection for as long as the door stays closed**, even at maximum exterior water. No pressure leak, automatic door breakage, protection expiry or round-end flooding may invalidate this guarantee.

Opening a refuge into a flooded corridor admits water again. Closing after water entered stops new inflow but does not erase existing water. A refuge has one doorway and no hidden water source. Shelter is not extraction.

The exact prototype timing, flood thresholds and event ordering are in REALTIME_SPEC.md. Numeric tuning values may change after playtesting; the refuge guarantee and 1–2-room limit may not.

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

Retain recipient-specific projections. Following the user's 2026-10-06 refinement, players see only their surroundings according to light and wall line of sight. The camera centers on the explorer; there is no whole-map view or global player minimap. Nearby torches widen vision and a physically held lantern widens it away from torches. Unseen positions, exact inventories, private scores and remote outcomes remain hidden. A visible carried relic/light is observable artwork, not permission to send complete inventory. Final scores/outcomes become public at the ending.

Open doorways may permit sight across logical region ids within light range. Walls and future closed doors block sight. This supersedes the earlier strict same-region visibility rule; seeing a door move still does not authorize disclosure of an unseen player's coordinates.

## Platform, rooms and lifecycle

Godot 4, GDScript, browser export with single-threaded Compatibility/WebGL 2. Support desktop/laptop mouse and keyboard with a canvas of at least 960 × 600; phone portrait remains outside this slice.

Reuse the central WebSocket service, six-character room codes and live room list. Full lobbies remain visible but reject joins; started rooms leave the list. The creator starts with 2–4 connected people. Players never enter an IP address or port.

An active disconnect aborts the expedition explicitly. Reconnect, host migration and continuation after disconnect remain separate work. The server must continue its real-time clock when a client opens the guide or its browser tab is inactive.

## Presentation

Use supplied/generated raster scenery and explorer artwork, animated in code. Build rooms from separate floor, wall, foreground, door, object, character and water assets; invisible collision and shadow geometry are allowed. Do not draw scenery or substitute explorers from polygons, meshes or procedural shapes.

Preserve painted limestone, blue/turquoise water, warm torch/relic light, recognizable explorers, compact native controls, system fonts and asset provenance. Keep the background independent of mouse motion. Reduced motion suppresses decorative loops while retaining actual gameplay updates.

The older four-layer city image is a useful legacy asset/reference; its anchor layout, fixed layer count and six-second travel are not the new playable-world contract.

## Delivery and current verification limits

Play.cmd or Play-Web.cmd starts the local HTTP proxy and headless room service through Play-Web.ps1; open http://127.0.0.1:8080. Browser clients use the site's WS/WSS /rooms route, with an operator override if needed. Rebuild code/assets with web/Build-Web.ps1 and deploy all web/build files together.

Public delivery requires HTTPS hosting, a persistent room service and a reverse proxy. Public HTTPS/WSS and WAN real-time performance remain unverified. Existing localhost/render checks do not establish real-time playability or visual parity with the references. See web/README.md and server/README.md for infrastructure instructions.

## Completion of the first slice

Groups of 2, 3 and 4 can complete one expedition from lobby to result. Movement is independent; doors and water change accessible routes; the refuge remains dry when sealed in time; cooperation and betrayal are observable; one relic cannot have two holders; only extraction produces score; every client agrees on authoritative outcomes.

Run rules, privacy, authority, scene, network, renderer and browser verification appropriate to the implementation, then conduct human playtesting and WAN checks. Stage 1 baseline results are recorded in REALTIME_SPEC.md.

## Non-goals

Additional maps, random generation, combat, progression, fixed traitor roles, elaborate menus, automatic matchmaking, reconnect, mobile redesign, full fluid simulation and speculative transport/provider abstractions.
