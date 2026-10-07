---
name: Relic Tide
description: A painted flooding ruin for real-time physical cooperation, betrayal and extraction.
colors:
  ink: "#f1ead6"
  muted: "#b9d3d3"
  gold: "#edc47b"
  dark: "#0a202b"
  glass: "rgba(6.375, 17.85, 25.5, 0.78)"
  edge: "rgba(183.6, 224.4, 234.6, 0.38)"
  start-surface: "rgba(6.375, 17.85, 25.5, 0.95)"
  gear-surface: "rgba(6.375, 17.85, 25.5, 0.86)"
  air: "#b9e8f0"
  danger: "#ef786f"
  alarm-surface: "#491e29"
  alarm-countdown: "#ef9990"
  blueprint-surface: "rgba(6.375, 22.95, 30.6, 0.97)"
  blueprint-floor: "#487277"
  player-one: "#85e1d1"
  player-two: "#ffb29f"
  player-three: "#f3d17e"
  player-four: "#d6bfff"
typography:
  display:
    fontFamily: "Segoe UI, Verdana"
    fontSize: "54px"
  title:
    fontFamily: "Segoe UI, Verdana"
    fontSize: "26px"
  panel-title:
    fontFamily: "Segoe UI, Verdana"
    fontSize: "24px"
  body:
    fontFamily: "Segoe UI, Verdana"
    fontSize: "18px"
  control:
    fontFamily: "Segoe UI, Verdana"
    fontSize: "17px"
  final-alert:
    fontFamily: "Segoe UI, Verdana"
    fontSize: "30px"
  actor-label:
    fontFamily: "Segoe UI, Verdana"
    fontSize: "13px"
  map-label:
    fontFamily: "Segoe UI, Verdana"
    fontSize: "12px"
rounded:
  control: "12px"
  gear: "6px"
  gauge-track: "5px"
  gauge-fill: "4px"
spacing:
  page-inset: "24px"
  control-inline: "18px"
  control-block: "12px"
  panel-inline: "26px"
  panel-block: "24px"
  gear-inset: "4px"
components:
  button:
    backgroundColor: "{colors.glass}"
    textColor: "{colors.ink}"
    typography: "{typography.control}"
    rounded: "{rounded.control}"
    padding: "12px 18px"
    height: "42px"
  button-disabled:
    backgroundColor: "{colors.glass}"
    textColor: "{colors.muted}"
    typography: "{typography.control}"
    rounded: "{rounded.control}"
    padding: "12px 18px"
    height: "42px"
  field:
    backgroundColor: "{colors.glass}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "12px 18px"
    height: "42px"
  panel-glass:
    backgroundColor: "{colors.glass}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "12px 18px"
  panel-start:
    backgroundColor: "{colors.start-surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.control}"
    padding: "12px 18px"
  panel-puzzle:
    backgroundColor: "{colors.dark}"
    textColor: "{colors.muted}"
    rounded: "{rounded.control}"
    padding: "24px 26px"
    width: "430px"
    height: "325px"
  gear-slot:
    backgroundColor: "{colors.gear-surface}"
    rounded: "{rounded.gear}"
    padding: "4px"
    size: "50px"
  tide-gauge:
    backgroundColor: "{colors.dark}"
    rounded: "{rounded.gauge-track}"
    width: "420px"
    height: "15px"
  air-gauge:
    backgroundColor: "{colors.dark}"
    rounded: "{rounded.gauge-track}"
    width: "142px"
    height: "12px"
  final-alert:
    backgroundColor: "{colors.alarm-surface}"
    textColor: "{colors.ink}"
    typography: "{typography.final-alert}"
    rounded: "{rounded.control}"
    width: "660px"
    height: "190px"
---

# Design System: Relic Tide

## Overview

**Creative North Star: "The painted flooding ruin, with physical decisions happening in front of the player"**

Relic Tide uses an elevated top-down 2D view with a 2.5D impression: blue limestone, sea-green oxidized metal, turquoise water and warm ochre brass. Original explorer pixels and restrained red danger belong to the same material world. Preserve the recognizable mint, coral, amber and lavender crew identities, supplementing color with P1–P4 labels. The supplied/generated raster medium, palette and native system fonts remain the incumbent identity.

The production expansion keeps the world dominant and the interface compact. Separate authored floors, wall reveals, gates, props, characters and water form the entire environment. No Atlantis city, DepthFlow video or decorative backdrop appears behind or over the level. Unknown space stays dark. Physical movement, a closing gate, a chest and a pursuing hunter carry the action; nearby authored emblems explain what the player can do.

Eastward and Children of Morta remain quality references for grounded steps and material detail; Among Us and Goose Goose Duck remain readability references. Use original assets, never copied characters or scenery. Preserve the real eight-direction held-item poses and the steady camera following reconciled rendered feet. The 7 October expansion changes map scale, sight and survival feedback without replacing this visual identity.

**Key Characteristics:**

- Elevated top-down raster rooms and segmented corridors, with authored stone, brass and water materials.
- Three large playable expeditions, a quiet Start screen and a physical waiting room.
- Broad normal sight, meaningful darkness and gate shadows, with a steady feet-centered camera.
- Four recognizable explorers with real directional steps, pickups and physically held relic/lantern artwork.
- Authored hearts, tide, air and equipment emblems, short functional labels and a clear evacuation alarm.
- Native Godot controls, system fonts, keyboard focus and recipient-specific world feedback.

### Current evidence and historical scope

This merge records the approved 7 October production expansion implemented in scripts/main.gd, survival_hud.gd, expedition_world.gd, expedition_puzzle.gd, expedition_blueprint.gd and vision_layer.gd, with shared coordinates from expedition_map.gd. PRODUCT.md owns product truth and GAMEPLAY_EXPANSION.md owns the expansion's surface direction. Frontmatter values come from native code; pixel values express logical Godot canvas units, not a CSS implementation. Control dimensions are requested/minimum sizes; Godot theme minima may expand them.

The finish handoff reports survival rules (355 checks), production privacy (93), waiting lifecycle (31), production rendering at the final (2.6) zoom (93) and all fifteen strict real-socket scenarios passing. The final Web build and smoke checks (8) also pass. The actual .impeccable/review/expansion-*.png native captures cover Start, waiting, all three map themes, dry/wet rooms, gate states, refuge, blackouts, lantern, puzzle, blueprint, hunter and finale, including supported small-canvas overlays. The independent visual reviewer returned a ship disposition for the reference-like framing and corrected pressure markers, Hit [Space] label and final-clock contrast. Measured actor bodies occupy (110–114 logical pixels of the 900-unit canvas height), approximately (12–13%), across all three maps.

The resumed TaskSpace5 browser run passed actual two-client code joining, Ready, host entry and WASD movement in the fresh WebGL export at (2.6) zoom. E opened chest T1's circuit, native puzzle-button input completed it, and the authority awarded a chart plus (45 treasure), captured in test-output/expansion-web-chest-reward-final.png. Recorded outgoing binary Godot Variant WebSocket chest/puzzle commands confirm the real service path. The native GUI input regression in tests/puzzle_input_test.gd passes (101 checks), covering real mouse/E input, one-time reward, rapid-burst protection and the exact (25.1-second) puzzle lease expiry. Public HTTPS/WSS, WAN performance, human balance and exact reference-game visual parity remain unverified. EXPANSION_VERIFICATION.md records the suite evidence and limits.

The five-room Sluice Vault, its narrow camera, older light ranges, ordinary-door seepage and all city/video composition passes are historical prototype evidence. They are not active production guidance. The sidecar preserves older metadata inside an explicitly inactive historical block.

## Colors

The material palette is cool stone and sea-green against warm ochre brass. The normative frontmatter captures repeated native UI colors rather than inventing hex values for painted scenery.

### Primary

- **Treasure Gold** (gold): title lettering, treasure, selected-map emphasis, mechanism progress and keyboard focus. Tide changes to this warning color after seventy percent of the expedition clock.

### Secondary

- **Mint Signal** (player-one): P1 identity and normal tide fill. Other identities use **Coral** (player-two), **Amber** (player-three) and **Lavender** (player-four), always paired with a player number.
- **Pale Air** (air): breath/oxygen fill and the remaining oxygen count.
- **Blueprint Stone** (blueprint-floor): unlocked static map geometry; it does not color the live world.

### Tertiary

- **Danger Coral** (danger): active breach marks, final tide fill and the extraction direction arrow during the alarm.
- **Alarm Rose** (alarm-countdown): remaining evacuation time.
- **Alarm Wine** (alarm-surface): the brief evacuation announcement panel.

### Neutral

- **Parchment Ink** (ink): native labels and useful numeric counts.
- **Muted Sea Mist** (muted): secondary instructions, disabled control text and gauge/map outlines.
- **Deep Water Ink** (dark): puzzle panels and gauge tracks.
- **Deep Glass** (glass) and **Sea Glass Edge** (edge): compact room, guide, results and text controls; translucency keeps the playable setting present.
- **Quiet Start Surface** (start-surface), **Equipment Surface** (gear-surface) and **Blueprint Surface** (blueprint-surface): the denser backing required by these overlays.

**The Material Continuity Rule.** New raster assets use the established limestone, sea-green and ochre-brass material vocabulary; a new gameplay role does not authorize a new visual identity.

**The Readable Identity Rule.** Player numbers and observable held objects supplement crew colors; color never permits disclosure of a hidden explorer.

## Typography

**Display Font:** Native SystemFont, requesting Segoe UI then Verdana.

**Body Font:** The same native font request for explicitly styled labels and buttons. Some OptionButton, LineEdit and puzzle controls retain Godot's native theme font where code does not override it.

**Character:** Plain, functional lettering keeps the raster world in charge. System fonts are an explicit user/project requirement, including the Start title; do not replace them to satisfy a generic craft font preference. No custom weight, tracking or line-height scale is established.

### Hierarchy

- **Display** (display): Start title; the tagline uses a smaller native label (20 logical units).
- **Title** (title): waiting/prototype header. Waiting room code/identity and local treasure use compact title-sized labels (22).
- **Panel title** (panel-title): guide and outcome headings. Private puzzles use their observed nearby size (25); the blueprint title uses (27).
- **Body** (body): wrapped guide text and default labels. Outcome rows use (19).
- **Control** (control): actions, compact hints and secondary room information.
- **Final alert** (final-alert): two-line evacuation instruction. Its countdown remains a smaller native number (23).
- **Actor label** (actor-label): P1–P4 above visible explorers. **Map label** (map-label): short room names inside the unlocked static blueprint.

**The Functional Text Rule.** Keep short action names, room codes, ammunition, oxygen and countdown numbers where they clarify use; authored emblems replace verbose live diagnostics.

## Layout

The logical canvas is (1440×900), stretched with Godot canvas_items; the native development window is (1280×800) and the supported desktop minimum is (960×600). Preserve the canvas composition at that minimum. There is no phone portrait layout or CSS breakpoint system.

Each production level—Drowned Lagoon, Brass Foundry and Sunken Catacombs—occupies (3840×2560) world units, with twelve rooms, branching segmented corridors and one single-entry refuge. World coordinates are separate from HUD coordinates. Production camera zoom is (2.6), calibrated to the readable character scale in the user's supplied Among Us / Goose Goose Duck screenshots; the physical waiting room uses (1.18), and Start uses (1.05). A standing explorer's authored (44-world-unit) body is approximately (114 logical pixels), or (12.7% of the 900-unit viewport height), at this zoom. This is a framing estimate, not an exact visual-parity claim. The legacy (1.65) zoom applies only to the internal prototype fixture; the earlier production (0.85) and provisional (1.55) framings are superseded.

Powered sight reaches (1250 world units). A dark room or blackout reduces it to (180); a physically held lantern restores (360) in darkness. Both observer and target-room power affect visibility. Walls and shut gates block line of sight, including across room ids. The playable view does not reveal the complete live map or remote actors. Lighting and authority filtering use shared map geometry and light rules.

The Start panel sits left of the quiet Landing floor at (85,220), minimum (515×275). The room browser opens at (70,175), and waiting controls sit at (25,230), beside the walkable staging floor. During play, three hearts occupy upper left; a slim tide gauge sits near top center; six gear slots sit lower left; local treasure stays lower right. Guide and Leave remain upper right. A nearby interact badge stays near its object, clamped clear of the fixed HUD. No persistent planning sidebar appears.

Controls use repeated inline/block padding from the frontmatter. Native stacks use observed separations suited to their content: (12) in the room browser, (18) in waiting/puzzles, (23) on Start. This is not a mandate to apply one spacing value to every game object.

**The Rendered Feet Rule.** Camera and local light follow the same reconciled rendered feet. Small corrections blend, fractional previews use shared collision/water/carry rules, and corrections never create a backward gait. No shake, bob, pointer drift or decorative camera motion is added.

Reduced motion (V) freezes decorative idle poses while preserving directional walking, pickups, doors, flood changes and hazards. Guide, puzzles and blueprint stop or redirect the local player's actions; online authority continues its clock. The alarm stays readable longer in reduced motion.

## Elevation & Depth

Depth comes from authored raster wall reveals, foreground boundaries, contact shadows and feet-based ordering. Floor, raster water, walls/props and visible actors have separate native rendering roles. Low furniture blocks feet along its authored contour but does not block eye-level sight or cast a solid rectangular sight wedge. Walls and closed doors remain opaque. A dedicated wall-material light does not illuminate hidden floor or actors. Visible explorers render above floor shadows after recipient visibility filtering.

Native overlays use tonal backing and borders rather than card drop shadows or CSS blur. Shared labels have a dark native text shadow offset downward (2 logical units). The light mask is an invisible radial texture with native wall/door occluders, not visible scenery; painted contact shadows remain part of the asset.

**The Raster World Rule.** Visible floors, walls, props, explorers, monsters and emblems use supplied or original generated raster pixels. Geometry may supply invisible collision, flood masks and shadow occlusion; the static blueprint and directional HUD arrow may use native diagram geometry.

## Shapes

Shared buttons, fields and panels use rounded.control. Equipment slots use the smaller rounded.gear; gauge tracks/fills use their own narrow corner values. Glass controls carry a thin edge (1 logical unit), with gold on keyboard focus. Equipment slots use a gold focus edge (2).

Raster silhouettes follow authored pixels. Keep complete feet, hands, held props, slabs and frames; do not approximate their contours with geometric masks. Refuge, wave, treasure, air and equipment emblems retain the atlas's distinct silhouettes.

## Components

### Buttons

Quiet native actions sit beside the world. Shared buttons use the frontmatter skin and minimum height, with width chosen for the real label. The shared helper intentionally uses the same glass fill/thin edge for normal, hover and pressed states; it establishes no animated lift or transition. Focus has a gold edge; disabled text is muted. The selected map receives the observed gold modulation.

Equipment icons occupy (50×50), with native tooltips and gold focus. Unavailable gear is dimmed. Passive chart/oxygen/mask slots are disabled; ammunition, health and counts determine active gun/medkit use. States not overridden by the HUD retain Godot's native theme.

### Cards / Containers

Start uses the denser quiet surface and large title. Waiting uses a narrow glass panel beside the physical floor. Guide, room browser and results use shared glass panels; guide text wraps and results expose outcomes only after the expedition ends. These are task overlays, not a repeated card grid.

### Inputs / Fields

A six-character room code field, capacity picker and available-room list use glass skins, thin edges and gold focus. Text entry owns keyboard input. Full rooms stay listed with Full status but reject joining; running rooms leave the list. No player-facing IP/port fields appear.

### Navigation

Start leads to creation/code joining/browsing, then a physical staging room. The creator selects one of three map buttons; everyone can walk and mark Ready, including with Space. A map change clears readiness. Only the creator sees Enter the ruin, enabled when 2–4 connected people are ready. Guide and Leave remain native actions; an active disconnect produces an explicit aborted result.

### Survival HUD and contextual interaction

The sixteen-emblem atlas supplies hearts, air, wave, map/chart, oxygen, mask, medkit, tranquilizer/dart, treasure, gate, hunter and refuge symbols. Health is three individual full/empty hearts (40×40). Tide uses the frontmatter gauge, changing mint → gold → danger as the clock advances. Air appears at local depth (1.2) and shows breath or active oxygen. Gear keeps numeric ammunition, medkit and tank counts. The lower-right treasure number is the local carried amount, including the great relic; it is not a rival score or a guarantee of banking.

The interact badge uses an authored object emblem, E and a short hold-progress strip. It replaces live text diagnostics in production. Warned breaches use a wave/local lead-in strip; gas has the mask cue and a hunt has the monster cue. All reflect recipient-projected state.

### Private chest puzzle

A dark panel at (505,245), minimum (430×325), uses authored seal emblems and short instructions. Runes display briefly before input; circuit controls match lit targets; pressure uses two markers drawn in the gauge's own coordinates, progress and a Hit [Space] action. Close [Esc] cancels the private challenge. Authority validates every attempt; no remote player's challenge is shown.

### Unlocked blueprint

Collected equipment opens a static map panel at (345,110), size (750×665), with geometry scaled by (0.18). It shows short room names and only the owner's marker. No hidden explorer/monster markers, private inventory, live remote outcome or automatic map reveal appear.

**The Private Geography Rule.** Static structure may be revealed by collected equipment; unseen actors and private state remain absent from recipient packets, not merely hidden by the renderer.

### Explorers, mechanisms and water

The original PixelLab/Aseprite crew uses four explorer-holding-p*-v2 bundles: fifteen actions in eight directions, a common (88×88) canvas, authored feet at (44,74) and a standing height of (44 world units). Walk and held-item walk use real leg poses. A confirmed pickup plays a planted bend/reach/lift, including with the other item held. Fingers overlap the prop and the torso hides the rear grip. Retain nearest filtering, complete silhouettes, grounded stride, slower relic carriage and provenance. The original Brine Stalker has its own eight-direction walk/idle/attack/stun bundle.

Gates retain matching stone/brass frames and a retracting slab, including open/opening/closing/shut/obstructed states. Visible opening, collision, sight and water agree with authoritative progress. Wheel controls and the Landing boat use authored prop pixels; the two-person vault shows nearby held controls. Raster water clips to floor regions and shares local lighting; no global flood crossfade covers a dry refuge.

**The Sealed Dry Refuge Rule.** Each production map has one single-entry refuge. Show guaranteed-safe feedback only when it is dry and its gate fully shut. It stays dry for as long as that gate remains closed, including at maximum exterior water and the ending; shelter never implies extracted treasure.

Fully shut production gates block flow through their connector. Existing water remains after closure; another warned breach can enter another room. Prototype ordinary-door seepage is not a production visual or rule.

### Final evacuation alert

The wave emblem and EVACUATE / Return to the Landing instruction use the wine-backed alert at (390,275), minimum (660×190). The announcement appears briefly (3.2 seconds, or 5 with reduced motion). Red tide fill, remaining time and the extraction direction cue persist afterward. The timer has opaque Deep Water Ink backing at (654,57), size (136×34), to stay readable over the level. The alarm changes information, not camera motion or refuge protection.

## Do's and Don'ts

### Do:

- **Do** preserve original raster materials, complete silhouettes, four numbered crew identities and source provenance.
- **Do** use current map scale, readable camera framing and powered/dark/lantern sight while keeping walls and shut gates opaque.
- **Do** anchor camera, light and grounded directional poses to the same reconciled rendered feet.
- **Do** keep authored hearts, gear and object badges compact, with functional labels, numeric counts and keyboard focus.
- **Do** make gate opening and regional water agree with authority; a dry sealed refuge stays visibly dry indefinitely while closed.
- **Do** verify real Start, waiting, all map themes, darkness, gates, refuge, puzzle, hunter and finale at supported desktop sizes.

### Don't:

- **Don't** restore decorative Atlantis, city/video backdrops, pointer parallax or moving imagery over the playable map.
- **Don't** replace scenery, explorer poses or authored emblems with drawn/procedural substitutes or copied reference-game assets.
- **Don't** restore simultaneous-turn waiting, plan locks, fixed anchor travel or a planning sidebar.
- **Don't** reveal hidden actors, exact rival inventories, private puzzles or live remote scores through a map or client-only hiding.
- **Don't** portray late closure as draining water, or invalidate a dry sealed refuge through leaks, pressure, expiry or the ending.
- **Don't** treat prototype screenshots, old stage counts or a local native render as current browser, WAN or human-balance acceptance.
