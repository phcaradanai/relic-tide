# Stage 5 toolchain quality record · updated 2026-10-07

The active stack is **PixelLab → Aseprite → Godot**, plus **local Depth-Anything-V2** and **DepthFlow cloud previews**. The user resumed DepthFlow after funding watermark-free access; this supersedes the brief pause. This is a completed integration/inspection study, not completion of stage 5's final layered room.

| Tool / artifact | Actual evidence | Current use |
| --- | --- | --- |
| PixelLab carry candidate | Successful API job; 9 transparent 216×216 frames for a request for 8; 6 generations charged, 1,994/2,000 remaining | Motion draft, retained intact for artist correction |
| Aseprite baseline | Six existing, distinct painted leg poses; editable explorer/idol layers; 125ms timing; imported Godot SpriteFrames | Baseline for comparing style, movement and hand/prop placement |
| Depth-Anything-V2 | Actual local vits inference, CPU, 400×380 grayscale matching the Workshop crop exactly | Native depth resource; no paid API usage |
| Godot | Real imported textures/resources; 1280×800 and 960×600 captures; selected candidate rendered in the Workshop crop | Isolated art QA; camera/depth motion stay fixed/off |
| DepthFlow account preview | New 5s H.264 MP4, 400×380, 24fps/120 frames; first, middle and last frames have no visible watermark | Enabled for reviewed external previews; subtle motion, not adopted as the gameplay camera |
| DepthFlow free comparison | Earlier approved 5s clip with repeated watermarks from the explicit `free` preset | Historical comparison only; superseded by the account-entitlement trial |

The provider reported PixelLab usage as generations, with USD usage 0. A `cost_if_paid` value is informational, not a dollar charge to this subscription. The failed initial trial request reported USD usage 0. The DepthFlow Dashboard showed 600 remaining credits before the new render. The MP4 response contained no usage data, and a settled post-render balance was not established; credit consumption and per-render dollar cost remain unconfirmed.

## Visual findings

The PixelLab candidate has clear boot/knee movement and a complete silhouette. The cloak, body orientation and hand/prop relationship change across frames; in some frames the idol separates visibly from the fingers. The result is more pixel-like than the existing painted baseline. It is **not accepted as final production carrying art**. All frames are available in Aseprite for correction, without further API spending. The baseline is also an authoring study; it does not claim all directional or mechanism poses.

The Workshop crop preserves the existing painting. Its depth map is relative visual inverse depth, not metric water or collision data. Interactive floor, doorway and object coordinates must remain aligned with the shared map. The study does not enable depth displacement.

`workshop-account-dolly-v2.mp4` follows the authenticated Dashboard's payload without a `plan` override. Its first, middle and last frames have no visible watermark. Motion is subtle at amplitude 0.2; sampled frames show small differences rather than a strong camera move. This establishes a usable watermark-free output path, not final room quality or value at a known cost. The old `workshop-dolly-v1.mp4` remains a watermarked free-profile comparison. No subscription/billing settings were changed, no further render is scheduled, and neither job is automatically resubmitted.

## Open the studies

Open `scenes/samples/workshop_study.tscn` in Godot and run the scene. Space pauses/resumes; Right steps a paused frame; Esc closes.

```zsh
"/Users/oyl-mac_m1/Downloads/Godot.app/Contents/MacOS/Godot" --path . res://scenes/samples/workshop_study.tscn
"/Users/oyl-mac_m1/Downloads/Godot.app/Contents/MacOS/Godot" --path . res://scenes/samples/workshop_study.tscn -- --pixel-candidate
```

Editable sources are in `assets/authored/`. Godot output bundles include `frames.tres`, `sprite.tscn`, atlas and manifest. Native captures and animated GIFs are in ignored `test-output/`. The production game uses its existing artwork while this study is reviewed.

The new local video is `.asset-work/previews/workshop-account-dolly-v2.mp4`; its private receipt records the endpoint, source hash, exact account preset and output path. The source is the same approved `assets/authored/workshop-reference-v1.png` crop. Sampled frames are `test-output/depthflow-workshop-account-01.png`, `depthflow-workshop-account-middle.png` and `depthflow-workshop-account-02.png`.

## Verification and next acceptance

21 asset-tool tests pass, including returned-frame review, no duplicate submission, native alpha/canvas/timing, disabled provider paths, key suppression and binary-video provenance. The existing Godot asset suite passes 1,565 checks; the new study launches and captures through native Apple M1 Compatibility rendering. This tooling change does not claim new network/WAN evidence.

Next production acceptance: one Workshop room with separate floor, foreground walls and mechanism art, reliable occlusion and visible dry/flood states; correct hands/held idol, fixed facing and feet baseline across a full loop; then directional poses for the four identities, wading/mechanism animation and audible door/water danger. Expand only after that room is visually approved. Preserve authoritative simulation, privacy, sealed-refuge rules and the player-follow camera.
