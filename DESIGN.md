---
name: Relic Tide
description: A painted flooding ruin for real-time physical cooperation, betrayal and extraction.
colors:
  ink: "#f1ead6"
  muted: "#b9d3d3"
  gold: "#edc47b"
  dark: "#0a202b"
  player-one: "#85e1d1"
  player-two: "#ffb29f"
  player-three: "#f3d17e"
  player-four: "#d6bfff"
typography:
  title:
    fontFamily: "Segoe UI, Verdana"
    fontSize: "26px"
  body:
    fontFamily: "Segoe UI, Verdana"
    fontSize: "18px"
  control:
    fontFamily: "Segoe UI, Verdana"
    fontSize: "17px"
rounded:
  control: "12px"
spacing:
  page-inset: "24px"
---

# Design System: Relic Tide

## Status and source of truth

This is the approved real-time target. The current build renders assets/ruin-movement.png as the 1440×900 walkable floor, with isolated raster explorers. Stage 3 overlays an authored water texture clipped to shared region geometry and a separate transparent gate sprite; collision, door sight and water flow use the same map data. The background remains a prototype rather than final layered-scene art. Stage 4 adds a separate transparent idol sprite, raster wheel controls and Landing boat from the existing atlas, local breath/carry/score feedback and native final results. Carried art is observable only with a visible holder. Full directional carrying/mechanism poses and final layered scenery remain stage 5. PRODUCT.md owns scope; REALTIME_SPEC.md owns rules; REALTIME_PLAN.md owns delivery stages.

## Visual direction

**The painted flooding ruin, with decisions happening in front of the player.**

An elevated top-down 2D view gives a 2.5D impression. Moonlit stone, dark ruined walls and turquoise water frame warm torches and golden relic light. Preserve recognizable explorer identities and the supplied/generated raster medium.

The first attached reference is the working direction for painterly surfaces and characters. The second informs clear multiplayer identities, readable doors, water and compact HUD. Pixel-art treatment is not a newly locked requirement.

Use one finished room sample to settle perspective, scale, animation and lighting before producing the entire map.

## World composition and asset contract

Separate floor, wall/foreground, doorway, valve/mechanism, pedestal/relic, explorer and water artwork. Interactive objects cannot be baked inseparably into a whole-level painting. Author the surfaces revealed by opening doors and walking behind foreground walls.

Visible scenery and explorers remain raster artwork. Geometry may define invisible collision, interaction bounds, flood masks or shadow occlusion, but may not become drawn scenery or a replacement character. There is no fixed requirement to preserve the legacy four-layer stack.

A shared level definition must align room regions, collision, door thresholds, interaction positions and flood masks between the client and the authoritative service. Stable ids in REALTIME_SPEC.md are the starting contract.

Occlusion follows the explorer's feet and authored foreground boundaries. A character behind a wall should be partially hidden; door collision and visible opening must agree. Do not let painterly perspective hide the traversable floor or interaction reach.

## Character and object readability

- Preserve P1–P4 labels and the established mint/coral/amber/lavender identities; color is supplemented by player number.
- Provide actual directional walking, standing, carrying and mechanism-use poses. Animation advances with movement, not a fixed six-second trip between anchors.
- A visible relic carrier has unmistakable held artwork and a readable slower pace.
- Gates show open, opening, closing, shut and obstructed states.
- A valve shows which corridor it currently feeds.
- An interact prompt sits near the relevant world object and shows action/progress, rather than a bottom-row planning menu.
- A two-person mechanism shows whether one or two people are actively holding its controls.

The one refuge looks distinct through authored sealed-door artwork and a persistent refuge symbol/name. Its safe status is shown only once the door is fully closed and the room is dry. A closing or obstructed door must not display guaranteed-safe feedback.

## Water and warnings

Render local room/corridor depth from the same authoritative state that determines speed, breath and traversal. Dry floor, ankle-deep water, wading water and dangerous/submerged passages must have different visible treatments.

Stage 3 uses an authored repeating flood texture with region masks and depth-scaled opacity; visible water overlays never extend into a protected room. Later polish may add authored foam/splash animation and light reflections. Budget lights and overlays for the browser renderer.

Water rises outside a correctly sealed refuge while its interior stays visibly dry. Do not use a full-screen/global flood crossfade that visually floods a protected room. Normal closed doors show their delayed seepage consistently. The current gate is a shared raster sprite scaled through opening/closing progress.

Give readable waterline, door-threshold and imminent-danger signals. Supplement color with motion/state symbols and sound. Changing the valve redirects water gradually; the scene must not imply that existing water vanished instantly.

## Controls and HUD

Prototype controls are WASD/arrow movement, E nearby interaction/hold, Q drop, H guide, V reduced motion and R leave. Lobby fields retain text-entry ownership; movement/interaction commands are disabled during lobby typing. Movement is normalized diagonally and validated by the server.

Keep the expedition world dominant. A compact transparent HUD shows local water danger, breath when relevant, carried relic and extracted score. Room code/identity remain accessible. There is no plan lock, waiting-for-all indicator, initiative order or turn counter in the target.

Map presentation may show static geography, the current region and known environmental information. Never display live player markers in remote regions. Exact rival inventory/score remains private even when a visible carried object is rendered.

Use native Godot controls and SystemFont requesting Segoe UI then Verdana. Keep current parchment/sea/gold palette and translucent glass controls as a starting point. No CSS-based interface, persistent side panel or mobile reflow is introduced.

## Layout, camera and reduced motion

Retain the logical 1440 × 900 canvas, canvas_items stretching with aspect keep, and minimum supported desktop canvas 960 × 600. The native development window remains 1280 × 800.

User refinement on 2026-10-06: do not show the full map. Center a 1.65× camera on the explorer and reveal only the local light radius with wall shadows. The camera follows actual movement without shake, bob, smoothing drift or mouse parallax. Torches expand nearby vision; a held lantern expands vision away from torches. Native PointLight2D/CanvasModulate use an invisible radial light mask and invisible shadow occluders. A narrow raster wall face is revealed around floor boundaries; authority still filters actors against exact floor LOS.

V and browser prefers-reduced-motion suppress decorative water displacement, light drift, idle bob and opening breathing. Player position, collisions, water danger, door state and other meaningful gameplay updates continue. Reduced motion cannot pause the server or hide an impending hazard.

Opening, lobby, guide and results use compact native overlays. Opening the guide does not pause the online expedition.

## Privacy and world feedback

Show explorers only within the recipient's light radius and unblocked line of sight. Hide departing rivals without trails. Open connectors allow nearby sight across logical region ids; this user refinement replaces the earlier same-region-only rule. Visible carried lantern/relic art is allowed, while unseen positions, private resources and exact rival inventories remain filtered at the server.

Both vault control users must be observable when nearby and lit. A future closed refuge door blocks sight as well as water; opening it permits LOS subject to range. Door movement and anonymous environmental cues remain readable without leaking unseen positions. No player minimap reveals the ruin or remote explorers.

Only final results expose all scores/outcomes. Client-side hiding is not a privacy boundary; player_view.gd must omit forbidden data from packets.

## Existing implementation and assets

The legacy expedition uses assets/city.png, aligned assets/city-flood.png, displaced painted-water detail and explorers drawn at anchors. Its current ART_RECT is Rect2(45, 0, 1350, 900), fitting the full painting with side margins. The opening uses the supplied moonlit image in public/images/background/.

assets/explorers.png is the standing atlas; assets/explorers-walk.png contains six columns by four explorer rows; assets/action-icons.png is a 4 × 4 icon atlas. scripts/sprite_atlas.gd isolates crossing-cell artwork into 24 transparent pose textures. Preserve complete silhouettes, offsets and antialiased edges; do not restore uniform cell cropping without visual verification.

The legacy corrected walk art contains genuinely different leg poses. Future animation must visibly move feet/knees, not merely cloak/hair. Inspect actual rendered movement; frame-index assertions alone do not establish animation quality.

The legacy header/footer are transparent and ignore pointer input. Controls have translucent blue-green fills and 12px corners; panels/popups use stronger tint for legibility. These are continuity references, not a mandate to keep the old planner layout.

Preserve generation prompts in assets/*.prompt.txt, supplied-art origins in assets/supplied-art.origin.txt and embedded raster provenance.

## Visual acceptance

Inspect a real rendered walk and at least these scenes: dry room, flooding corridor, ordinary closed-door delay, sealed dry refuge beside high water, carried relic, two-person gate use and extraction.

Verify the smallest supported desktop canvas, native keyboard focus, reduced motion, hidden remote rivals and clear door/water warnings. Historical legacy screenshots or tests do not establish acceptance of the new real-time build. Compare the first finished room against the reference before expanding artwork production.
