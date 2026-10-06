# Stage 5 toolchain quality record · updated 2026-10-07

The active stack is **PixelLab → Aseprite → Godot**, plus **local Depth-Anything-V2** and **DepthFlow cloud previews**. The user resumed DepthFlow after funding watermark-free access; this supersedes the brief pause. This is a completed integration/inspection study, not completion of stage 5's final layered room.

| Tool / artifact | Actual evidence | Current use |
| --- | --- | --- |
| PixelLab carry candidate | Successful API job; 9 transparent 216×216 frames for a request for 8; 6 generations charged, 1,994/2,000 remaining | Motion draft, retained intact for artist correction |
| Aseprite baseline | Six existing, distinct painted leg poses; editable explorer/idol layers; 125ms timing; imported Godot SpriteFrames | Baseline for comparing style, movement and hand/prop placement |
| Depth-Anything-V2 | Actual local vits inference, CPU, 400×380 grayscale matching the Workshop crop exactly | Native depth resource; no paid API usage |
| Godot | Real imported textures/resources; 1280×800 and 960×600 captures; selected candidate rendered in the Workshop crop | Isolated art QA; camera/depth motion stay fixed/off |
| DepthFlow account previews | v2: 5s, amplitude `0.2`; v3: 10s, amplitude `0.5`; both 400×380 H.264 without watermarks; 20 credits each | Both failed visual acceptance; v3 estimated camera displacement stayed below 1px |
| DepthFlow free comparison | Earlier approved 5s clip with repeated watermarks from the explicit `free` preset | Historical comparison only; superseded by the account-entitlement trial |

The provider reported PixelLab usage as generations, with USD usage 0. A `cost_if_paid` value is informational, not a dollar charge to this subscription. The failed initial trial request reported USD usage 0. The DepthFlow account header moved 600→580→560 over the two account renders, 20 credits each per the Workspace. Neither MP4 response included usage data; no additional cash payment occurred in the render flow.

## Visual findings

The PixelLab candidate has clear boot/knee movement and a complete silhouette. The cloak, body orientation and hand/prop relationship change across frames; in some frames the idol separates visibly from the fingers. The result is more pixel-like than the existing painted baseline. It is **not accepted as final production carrying art**. All frames are available in Aseprite for correction, without further API spending. The baseline is also an authoring study; it does not claim all directional or mechanism poses.

The Workshop crop preserves the existing painting. Its depth map is relative visual inverse depth, not metric water or collision data. Interactive floor, doorway and object coordinates must remain aligned with the shared map. The study does not enable depth displacement.

`workshop-account-dolly-v2.mp4` used the API sample's `0.2` amplitude for 5s; it was watermark-free but barely moved. With the user's approval, v3 used the Workspace's default amplitude `0.5` for 10s, matching the Gallery sample length. It too was watermark-free, yet motion stayed below 1px across 0.5-second samples and remained visually close to a still. The documented API payload does not reproduce Gallery-level movement. The v3 MP4 is retained as evidence of this limitation, not accepted for gameplay. No subscription settings changed; no credits were spent after this two-render comparison. The old `workshop-dolly-v1.mp4` remains the watermarked free-profile comparison.

## Open the studies

Open `scenes/samples/workshop_study.tscn` in Godot and run the scene. Space pauses/resumes; Right steps a paused frame; Esc closes.

```zsh
"/Users/oyl-mac_m1/Downloads/Godot.app/Contents/MacOS/Godot" --path . res://scenes/samples/workshop_study.tscn
"/Users/oyl-mac_m1/Downloads/Godot.app/Contents/MacOS/Godot" --path . res://scenes/samples/workshop_study.tscn -- --pixel-candidate
```

Editable sources are in `assets/authored/`. Godot output bundles include `frames.tres`, `sprite.tscn`, atlas and manifest. Native captures and animated GIFs are in ignored `test-output/`. The production game uses its existing artwork while this study is reviewed.

The account previews are `.asset-work/previews/workshop-account-dolly-v2.mp4` and `workshop-account-dolly-v3.mp4`; each private receipt records its endpoint, source hash, submitted payload and output path. Both use the approved `assets/authored/workshop-reference-v1.png` crop. v3's 2.5s, 5s and 7.5s review frames are in ignored `test-output/`.

## Verification and next acceptance

21 asset-tool tests pass, including returned-frame review, no duplicate submission, native alpha/canvas/timing, disabled provider paths, key suppression and binary-video provenance. The existing Godot asset suite passes 1,565 checks; the new study launches and captures through native Apple M1 Compatibility rendering. This tooling change does not claim new network/WAN evidence.

Next production acceptance: one Workshop room with separate floor, foreground walls and mechanism art, reliable occlusion and visible dry/flood states; correct hands/held idol, fixed facing and feet baseline across a full loop; then directional poses for the four identities, wading/mechanism animation and audible door/water danger. Expand only after that room is visually approved. Preserve authoritative simulation, privacy, sealed-refuge rules and the player-follow camera.
