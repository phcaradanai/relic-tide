# Current production sources

- `explorer-holding-v2.aseprite`: current model, 1,376 native frames, 120 action/direction tags, four palette layers; 88×88 canvas, feet(44,74), scale44/60. Props and actual fingers are authored together, with separate relic/lantern/dual grips, planted held idles and four crouching pickup cases in all eight directions. Rear knee/lean poses are curated from actual PixelLab frames. See ASSET_PIPELINE.md for receipt-safe production and local-only assembly.

- `explorer-eight-way-v1.aseprite`: preserved previous model, 544 authored animation frames, 56 action/direction tags, four crew cloth palette layers. Show one palette layer at a time. Common canvas88×88, feet(44,74), display scale44/60. Walk/carry/wade use actual generated alternating boots. Carrying arms and idle stance are repaired from those same raster poses; backpack glass highlights are muted.
- `ruin-wall-faces-v1.png`: complete RGBA facade master extracted from the approved painting using shared map floors/obstacles; archived v1 material; current runtime uses assets/ruin-wall-faces-v2.png without furniture sight boxes.
- `workshop-reference-v1.png`: crop(630,0,400,380), source of the one-time DepthFlow Orbit study. The 2026-10-07 user refinement rejects its former lobby/map-overlay presentation; it is preserved as a study and excluded from the current Web export.

See `ASSET_QUALITY.md` for verified credits, renderer/browser evidence and remaining stage5 work. The files below remain historical comparisons; the production pass supersedes their old adoption/credit status.

# Stage 5 art study — Workshop / P1 carry

This is a first toolchain and motion study, not acceptance of the final layered room or all directional poses.

- `workshop-reference-v1.png`: Aseprite crop `(630,0,400,380)` of the approved `assets/ruin-movement.png`. No new scenery is drawn. Its actual local DA-V2 depth is in `assets/generated/depth/workshop-reference-v1/`.
- `explorer-p1-carry-e-v2.aseprite`: editable six-frame east-facing study, with separate original explorer and held-idol layers. Tag `carry_e`, 125ms per frame, complete 288×288 canvases. Foot anchor `(144,264)`. Linear filtering. It uses the existing six distinct leg poses from `assets/explorers-unlit-walk.png` and `assets/relic.png`; no body parts were generated, drawn or recolored.
- `explorer-p1-carry-reference-v1.aseprite` / `.png`: the 128×200 southeast reference uploaded once for PixelLab animation. This is a reference composition, not a generated result.
- The earlier east `v1` study remains as a smaller-prop comparison. `v2` is the sample's selected study. It is not substituted for all four production explorers.

Reproduction tools are in `tools/assets/examples/`: `export-painted-walk.gd` reuses the game's existing silhouette isolation, and `assemble-carry.lua` places each pose using its recorded original cell origin. `visible-bounds.lua` trims distant nearly transparent dust from the idol using alpha >127 and retains two antialiased edge pixels, before deliberate bilinear authoring at 40×60. Body pixels and leg poses are preserved. Imported manifests hash the editable source, retain frame timings and record the Aseprite provider.

Open `scenes/samples/workshop_study.tscn` in Godot and run the scene. Space pauses/resumes; Right steps a paused pose; Esc closes. The scene uses the real imported SpriteFrames and DepthArt resources. The camera remains still; depth displacement stays off. A short room-local walking path returns without teleporting. This isolated scene has no network, scores or gameplay interactions.

The initial PixelLab request `explorer-p1-carry-se-v1` failed with insufficient allowance and USD usage 0. After the user added allowance, `explorer-p1-carry-east-pixel-v2` completed and used 6 generations, leaving 1,994 of 2,000. It returned 9 transparent 216×216 frames for an 8-frame request. All 9 are preserved in the generated bundle and editable `explorer-p1-carry-east-pixel-v2.aseprite`; the importer records both counts. Run the study with `--pixel-candidate` to inspect it in Godot. The candidate visibly moves legs but needs corrections to the hand/prop relationship and directional consistency before adoption. API collection and import never resubmitted the completed job.

Historical DepthFlow Dolly trials were watermark-free and failed the motion target. The 5s v2 clip used amplitude `0.2`; the approved 10s v3 clip used the Workspace's default `0.5`. Both stayed almost static. v3 is 400×380 H.264 at 24fps/240 frames, and 0.5-second samples estimated under 1px camera displacement. Each render cost 20 prepaid credits; the account now shows 560 after two requests from 600. The incomplete Dolly fields did not reproduce the Gallery output. The later approved Orbit, documented above, succeeded with the full Workspace fields. The earlier watermarked free-profile clip remains a comparison; billing/renewal settings were unchanged.

Native Godot captures at 1280×800 and 960×600 show different intact leg poses, a visible held idol and the room crop. They are motion/art evidence, not proof that stage 5's final scene layering, foreground occlusion, wading, all directions, audio or WAN playtests are complete.

Current scenery: `assets/generated/depth/atlantis-background-v1/` reuses city.png with local DA-V2. New matching door/wheel parts and their source prompt are in `assets/generated/environment/sluice-set-v2.*`; generated with built-in imagegen. Scene masks are reproducible from `tools/assets/examples/export-scene-masks.gd`. No new provider credits were spent.
