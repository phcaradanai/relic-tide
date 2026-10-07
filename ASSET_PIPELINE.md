# Relic Tide asset pipeline

Latest production expansion, 2026-10-07: Lagoon, Foundry and Catacombs are complete playable raster maps with no decorative background, DA-V2 depth layer or DepthFlow video. The original eight-way explorer and its four cloth palettes/15 integrated actions remain. New environment, prop and survival-icon sheets are original transparent raster assets with prompt provenance. Gameplay zoom 2.6 targets the character scale in the user's supplied Among Us / Goose Goose Duck images. See [current verification](EXPANSION_VERIFICATION.md).

The original PixelLab brine stalker now has walk (12 frames), idle (8), attack (8) and stun (4) in all eight directions: 256 frames and 32 tags. `tools/assets/monster_production.py` preserves accepted receipts and completes missing directions in their existing animation groups. All native pixels are retained on a common 120×120 transparent canvas; runtime feet anchor is (60,99), displayed height 52. Runtime resources are in `assets/generated/sprites/brine-stalker-v1/`, with editable Aseprite/source provenance preserved. Recorded PixelLab allowance changed from 1,788 to 1,703 during this batch (85 units); no dollar price is inferred. No DepthFlow render was submitted for the expansion.

Historical model/grip/background pass: the first model used 82 PixelLab generations (1,994→1,912); the grip/pickup extension used another 124 (1,912→1,788). An explicitly approved DepthFlow render cost 20 credits (560→540). Its Workshop Orbit overlay was retired after the user rejected the pasted appearance; the later Atlantis/DA-V2 background is also superseded by the latest playable-map request. [Historical quality evidence](ASSET_QUALITY.md) retains those results and limits.

The generic tooling below preserves source files. Dedicated production authoring in `assemble_character.py` pads native pixels, corrects carrying torso/legs, mutes backpack glass and makes cloth hue variants. It does not generate extra frames or bill providers. Gameplay authority remains separate.

## Current directional production

`tools/assets/character_production.py` uses the official v2 managed endpoints `/create-character-v3`, `/animate-character`, `/background-jobs/{id}`, and `/characters/{id}/zip`. The approved eight-way character and all seven animation groups are already completed. Receipts and the original 552-PNG ZIP stay in ignored `.asset-work/characters/explorer-eight-way-v1/`. A receipt is reserved before a paid POST. Only an identical request explicitly rejected with HTTP 429 may retry; accepted or ambiguous submissions are never resent.

```zsh
.venv-assets/bin/python tools/assets/character_production.py status
.venv-assets/bin/python tools/assets/character_production.py collect
```

Both commands are read-only provider operations. `produce` resumes accepted jobs and submits missing action groups; it is a production/billing command, not a free preview. Do not delete receipts to repeat the completed batch.

`assemble_character.py` packs the explicit ZIP animation metadata into four `assets/generated/sprites/explorer-eight-way-pN-v1/` resources and creates `assets/authored/explorer-eight-way-v1.aseprite`. Existing bundles are protected from overwrite. The original rejected carry-idle frames remain in the ZIP; production uses supporting torso pixels from real carry-walk frames and planted idle legs. The four Aseprite layers are editable color variants of one original model. Preserve the 88×88 canvas, `(44,74)` foot anchor and action/direction names; collapse does not loop. The motion driver honors both ordinary SpriteFrames durations and Aseprite's millisecond durations.

The approved Orbit request is `tools/assets/examples/depthflow-orbit-production-v1.json`. It includes the Workspace's full motion/render defaults with Orbit amplitude1.2, speed1, 8s and loop/smooth enabled. It has already been submitted once. `assemble_workshop_orbit.py` is local-only; it packs one complete observed five-second loop and generates its fixed floor-exclusion mask. This packing is historical and no longer exported. Regenerate current v2 geometry-only wall/floor masks with `tools/assets/examples/export-scene-masks.gd`; v1 masters stay archived. Never animate an interactive floor or change the player camera to follow this clip.

## Integrated grips and crouching pickups (v2)

`holding_production.py` extends the existing character; it never creates a duplicate model. Three eight-direction holding walk studies and four 16-frame pickup groups are complete. For a custom start/end pair, v3 accepts one direction per request; subsequent directions extend the returned `animation_group_id`. Every accepted request has its own receipt. Unknown receipts block later paid submissions; only a definite 429 rejection can retry. `status` and `collect` never submit. The new 1,352-PNG export stays in `.asset-work/characters/explorer-holding-v2/`; the original 552-PNG export remains intact.

The generated holding studies missed or duplicated some props, and several rear pickups barely bent. Local native raster authoring corrects these defects using actual PixelLab forearms, fingers, alternating gait and knee/lean poses. Source relic/lantern art is reduced to native pixels, with near-transparent stray pixels excluded before cropping. Props sit beneath fingers and behind the torso in rear views. Both hands and the prop share each sprite frame and its bob; `explorer_sprite.gd` draws one complete pose and has no independent held-item icon overlay.

The shipped bundles are `assets/generated/sprites/explorer-holding-pN-v2/`: 1,376 frames per palette, 120 tags, 88×88 canvas, foot anchor `(44,74)`, standing height 44. Actions are `walk`, `idle`, `use`, `wade`, `down`, `relic_walk`, `lantern_walk`, `dual_walk`, the three corresponding held idles, and `pickup_relic`, `pickup_lantern`, `pickup_relic_light`, `pickup_lantern_relic`. Pickups play once at 18 fps (about0.89s). Their final frame exactly matches the corresponding planted held idle.

Only a visible, server-confirmed ownership transition starts a pickup. Repeated snapshots, joining, revealing a hidden holder and denied pickups never restart it. The local player holds movement neutral during the crouch; death, dropping, hidden-state reset and substantial remote movement cancel it. Ownership, contested pickup and recipient filtering still belong to the authority, with no new private state in packets.

`assets/authored/` is intentionally `.gdignore`d. Keep runtime prop PNGs at `assets/relic-grip-v2.png` and `assets/lantern-grip-v2.png`; the explicit Web export includes them and all four new atlas/resources. Editable source is `assets/authored/explorer-holding-v2.aseprite`, with four palette layers. Show one layer at a time.

```zsh
# Completed provider operations: read-only status/export
.venv-assets/bin/python tools/assets/holding_production.py status
.venv-assets/bin/python tools/assets/holding_production.py collect
# Local authoring only; packing protects existing bundles from overwrite
.venv-assets/bin/python tools/assets/author_holding_refs.py
.venv-assets/bin/python tools/assets/author_rear_pickups.py
.venv-assets/bin/python tools/assets/assemble_holding.py --pack-only
```

After packing, run Aseprite natively with `tools/assets/examples/assemble-eight-way.lua`, passing `root`, `manifest=.asset-work/characters/explorer-holding-v2/assembled/aseprite.json` and `output=assets/authored/explorer-holding-v2.aseprite` as absolute paths. On this Mac the native app needs desktop execution; sandboxed Aseprite can abort. Import in Godot before testing. Do not remove receipts or source ZIPs to rebuild local art.

## Setup on this Mac (zsh)

Run from the repository root. Use the installed Python 3.11 to avoid installing PyTorch into system Python 3.14:

```zsh
cd /Users/Projects/relic-tide
/Users/Projects/Depth-Anything-V2/venv/bin/python -m venv .venv-assets
.venv-assets/bin/python -m pip install -r tools/assets/requirements.txt
.venv-assets/bin/python tools/assets/pipeline.py init
.venv-assets/bin/python tools/assets/pipeline.py doctor
```

`init` creates `.env.assets` with owner-only permissions on macOS and never replaces an existing file. Open that file locally and replace `YOUR_PIXELLAB_API_KEY` and `YOUR_DEPTHFLOW_API_KEY` with your existing paid API keys. Do not paste keys into chat or put them in command arguments, prompts, manifests, Godot scripts or project settings. Leave `.env.assets.example` as placeholders.

Process environment variables take precedence over `.env.assets`. The file is parsed as data: `NAME=value`, blank lines, whole-line comments and single/double quoted values. Spaces inside paths are supported. Shell expansion, `export`, inline comments and variable interpolation are not supported. Do not source the file in zsh or PowerShell.

The tools auto-detect this Mac's Godot in Downloads, Steam Aseprite, and the Python environment in `/Users/Projects/Depth-Anything-V2/venv`. Override executable paths using the commented entries in `.env.assets.example` if installations move. `doctor` reports presence, not API authentication or GPU availability, and never makes a paid request.

Only Pillow and requests are installed in `.venv-assets`. Depth inference uses the existing DA-V2 Python environment and small checkpoint. It does not modify that checkout or download models.

## Folder contract

| Folder/file | Purpose | Git / Godot |
| --- | --- | --- |
| `.env.assets` | Private paid API keys and machine paths | Ignored, explicitly excluded from export |
| `tools/assets/` | Agent-callable CLI, adapters, examples, tests | Tracked; `tools/.gdignore` excludes tools from Godot import |
| `.asset-work/jobs/` | PixelLab submission receipts, real job ids | Ignored, private, resume before retrying |
| `.asset-work/depthflow/` | Cloud response receipts or neutral image/depth inputs | Ignored; may contain signed download URLs |
| `.asset-work/previews/` | DepthFlow MP4 previews | Ignored; external art previews, not Godot runtime textures |
| `assets/generated/sprites/<name>/` | `atlas.png`, `frames.tres`, `sprite.tscn`, manifest | Complete, versionable Godot assets |
| `assets/generated/depth/<name>/` | Matched `image.png`, `depth.png`, `art.tres`, manifest | Complete, versionable Godot assets |
| `scripts/assets/`, `shaders/` | Reusable resource, layer and depth shader | Runtime; included in the explicit Web export list |
| `scenes/samples/depth_preview.tscn` | Separate sample using existing ruin/idol art | Editor QA only; expedition entry scene is unchanged |

Use names like `explorer-p1-walk-south-v1`. Names are restricted to lowercase ASCII letters, digits, `_` and `-`, starting with a letter. Complete asset bundles are published together; existing names are never overwritten. All source hashes, prompts/seeds where applicable, frame timings and provider provenance live in manifests. Machine paths and keys are not put in runtime manifests. A new version gets a new name.

## PixelLab sprites and animation

Read account allowance without submitting work:

```zsh
.venv-assets/bin/python tools/assets/pipeline.py pixellab balance
```

Initial setup check on 2026-10-06: PixelLab authenticated and reported 0.85 generations remaining of a 40-generation trial. The initial carry request failed with insufficient allowance and USD usage 0. After the user added allowance, one new versioned request succeeded; the current balance and candidate are recorded above. The user's phrase "40 per" was not interpreted as a $40 monthly budget.

The DepthFlow key passed an empty-request check (HTTP 422 requiring `body.file`, compared with keyless HTTP 401). After initial image-upload approval, the first Workshop render returned a real 5s H.264 MP4, 400×380 at 24fps/120 frames, from the example's `free` profile with repeated watermarks. The user briefly paused DepthFlow, then explicitly resumed after adding allowance. The `workshop-account-dolly-v2` render used the same Workshop crop with the `free` override omitted. It returned 5s H.264, 400×380, 24fps/120 frames and no visible watermark; measured motion remained barely perceptible. After explicit user authorization, `workshop-account-dolly-v3` used dolly amplitude `0.5` for 10 seconds. It returned H.264, 400×380, 24fps/240 frames, without a visible watermark. Review samples every 0.5 seconds estimated camera displacement below 1px, so it also fails the Gallery-motion target. The account header now shows 560 credits; each generation costs 20. No further provider requests are queued. The adapter does not automatically retry paid POSTs.

Each `sprite` or `animation` invocation submits one paid request. These commands are intentionally not run during setup/validation. They use the official public v2 endpoints, bearer auth, and no automatic POST retries or prompt enhancement. An ambiguous connection failure leaves a `submitting` receipt: check the dashboard before attempting another generation.

Generate a transparent sprite candidate:

```zsh
.venv-assets/bin/python tools/assets/pipeline.py pixellab sprite \
  --name explorer-p1-idle-v1 --prompt-file tools/assets/examples/explorer.prompt.txt \
  --width 128 --height 128 --direction south
```

To preserve an approved sprite style, use `--style-image path/to/approved-native-sprite.png` instead. This selects `/generate-with-style-v2`; output size is deduced from the reference, and `--width/--height/--direction` apply only to the plain Pixen endpoint. `--variant 0` selects one candidate when the style endpoint returns several; unrelated candidates are never turned into animation frames. Keep approved references at native resolution, at most 512px. PixelLab advises unzooming upscaled pixel art; do that explicitly in Aseprite or its tool before upload. This pipeline never silently resizes art.

Animate one approved transparent frame at native resolution, at most 256px per side:

```zsh
.venv-assets/bin/python tools/assets/pipeline.py pixellab animation \
  --name explorer-p1-walk-south-v1 --source path/to/approved-south.png \
  --action "walking south, visibly alternating feet, stable body scale" \
  --frames 8 --animation walk_south --fps 10
.venv-assets/bin/python tools/assets/pipeline.py pixellab poll \
  --name explorer-p1-walk-south-v1 --wait 300
```

The current animation endpoint is asynchronous. The initial command saves a receipt and exits by default; `--wait 300` can poll after submission. Polling is read-only and resumable. Timeouts never resubmit the paid job. Frames must be an even count from 4–16 and fit the documented pixel budget. If a job id was lost during an interrupted submission, recover its actual id from the dashboard and use `pixellab poll --name NAME --job-id ACTUAL_ID`. Do not delete a receipt and resubmit without checking whether the original job was charged.

The observed live provider returned 9 frames for a request for 8. Default import stops on a count mismatch. After reviewing the actual frames, `pixellab poll --name NAME --wait 0 --accept-returned-frames` imports **every returned frame**, without resubmitting or dropping a guessed reference frame. It records both counts and the review override. This flag approves the format for an art study, not the candidate's suitability for production.

Output decodes documented inline `image` / `images` base64 results, rejects opaque frames and inconsistent canvas sizes, pads cells, and emits native Godot resources. Provider schema changes stop with an error instead of guessing or overwriting art. Inspect complete silhouettes, foot alignment, direction and actual leg motion before adopting a candidate. Do not feed the old multi-person atlas as a single character reference.

## Aseprite and local sprite imports

Keep editable `.aseprite` originals in an authored source folder of your choice. Export tags with millisecond frame durations:

```zsh
.venv-assets/bin/python tools/assets/pipeline.py aseprite \
  --name explorer-p1-poses-v1 --source path/to/explorer.aseprite --filter linear
.venv-assets/bin/python tools/assets/pipeline.py import-frames \
  --name explorer-p1-walk-v2 --source path/to/aligned-frames \
  --animation walk_south --fps 10 --filter linear
```

PNG frame folders need zero-padded filenames, e.g. `frame_000.png`. Every frame must share the full canvas size and transparency. The tool never crops bodies, guesses feet, rescales, recolors or makes missing poses. Aseprite exports full untrimmed, unrotated canvases; tags preserve forward/reverse/pingpong order and original timing. Tags use the same safe name rules. Imported tags loop by default; switch `loop` off in SpriteFrames for one-shot actions. Choose `nearest` for native pixel art and `linear` for the project's painted art.

Instantiate the resulting `sprite.tscn` or set an AnimatedSprite2D's `sprite_frames` to `frames.tres`. Set the node's `offset` deliberately to the authored feet anchor; connect `play("walk_south")` to actual movement. Existing irregular explorer-atlas isolation in `scripts/sprite_atlas.gd` remains intact.

## Local Depth-Anything-V2

The installed `vits` model is the default. It produces an opaque grayscale map at exactly the source image dimensions, normalized to 0–255 with near objects white. This is visual inverse depth, not metric distance or authoritative flood state. The wrapper detects CUDA/MPS/CPU inside the local worker, safely loads checkpoint weights and rejects flat/invalid predictions. Use `--device cpu` to diagnose an MPS issue.

```zsh
.venv-assets/bin/python tools/assets/pipeline.py depth generate \
  --name archive-background-v1 --source path/to/approved-room.png
.venv-assets/bin/python tools/assets/pipeline.py depth import \
  --name archive-background-v2 --source path/to/approved-room.png \
  --depth-map path/to/grayscale-depth.png
```

For externally produced near-black maps, add `--near-is-dark`. Color visualizations, comparison panels, mismatched sizes and flat maps are rejected. Start with opaque environment art; transparent characters do not normally need this effect. The upstream small model is Apache-2.0; larger upstream checkpoints have different licensing and are not selected by this wrapper.

## DepthFlow cloud image upload

The fixed-origin adapter is enabled following the user's renewed decision. Keep the first free-profile result for comparison; the current account preset is `depthflow-account-dolly.json`. MP4 responses may omit billing data, so do not invent a per-render dollar price.

The authenticated [API keys page](https://www.depthflow.io/apis/api-keys), read on 2026-10-06, supplies the applicable Integration Quick Start:

- `POST https://www.depthflow.io/api/ai/depthflow/generate-3d` (the example's relative route on its own website origin).
- `X-API-Key: DEPTHFLOW_API_KEY`, with `Accept: application/json`.
- Multipart form fields `file` (the source image) and `payload` (a JSON string). The client sets the multipart boundary; do not set `Content-Type` manually.

A keyless `HEAD` returned `405` with `Allow: POST`; an empty POST without key, image or payload returned `401` (`Could not validate credentials`) using the pipeline's TLS-verified client. This proves route reachability and a credential gate, not successful paid generation. No real keys were revealed/copied/changed, and no generation job was submitted. The separate `/apis/documentation` page's Bearer/`api.depthflow.ai/v1/process` example conflicts with this upload quick start and that `.ai` host returned NXDOMAIN; the adapter does not use it.

Put your existing Live Secret Key into the ignored `.env.assets` under `DEPTHFLOW_API_KEY` by editing locally. No key belongs in a command argument. When you choose to submit a job, this command uploads the existing ruin painting once:

```zsh
.venv-assets/bin/python tools/assets/pipeline.py depthflow cloud --name ruin-dolly-v1 \
  --source assets/ruin-movement.png \
  --payload-file tools/assets/examples/depthflow-account-dolly.json
```

PowerShell:

```powershell
& .\.venv-assets\Scripts\python.exe tools/assets/pipeline.py depthflow cloud --name ruin-dolly-v1 `
  --source assets/ruin-movement.png `
  --payload-file tools/assets/examples/depthflow-account-dolly.json
```

The current account example requests `dolly`, amplitude `0.5`, and duration `10`, and omits the old `free` plan override. This is a standalone external preview with no gameplay camera change. Its paid v3 result shows the exposed API fields do not reproduce the motion visible in Gallery. The Workspace currently shows 560 credits and says each render costs 20 credits. Do not assume the API matches the web Workspace's motion controls until the provider documents the supported fields or confirms the behavior. A name is reserved before submission.

Outputs are private: a direct MP4 goes to `.asset-work/previews/ruin-dolly-v1.mp4`; the receipt in `.asset-work/depthflow/ruin-dolly-v1.json` preserves the endpoint, source hash, exact payload and output path. Direct MP4 handling has been verified with real jobs. Successful JSON response fields and any asynchronous polling route remain unverified. The adapter does not invent a polling endpoint or automatically retry a POST. For a JSON response, inspect the receipt locally and download a completed HTTPS MP4 using its actual field path:

```zsh
.venv-assets/bin/python tools/assets/pipeline.py depthflow collect --name ruin-dolly-v1 \
  --url-field ACTUAL_JSON_FIELD_PATH
```

That download sends no API key and follows no redirects. Keep signed result URLs private. A receipt is reserved before submission, so a timeout/unknown response cannot trigger a duplicate charge when the same name is reused. Check the dashboard before deciding whether to submit again under a new name. Neutral image/depth preparation and the local Godot sample work independently of the cloud service.

## Optional open-source local DepthFlow

This is a separate implementation from the paid endpoint. Its documented Python API accepts the project's source image plus the generated normalized near-white map. Prepare a neutral pair for an external tool:

This optional renderer was not installed. The native Godot depth assets and samples already work; no additional installation is needed for the current pipeline.

```zsh
.venv-assets/bin/python tools/assets/pipeline.py depthflow prepare --name ruin-preview
```

Local rendering is optional and needs OpenGL plus FFmpeg on PATH. Keep its packages separate from the user's DA-V2 environment:

```zsh
/Users/Projects/Depth-Anything-V2/venv/bin/python -m venv .venv-depthflow
.venv-depthflow/bin/python -m pip install -r tools/assets/requirements-depthflow.txt
.venv-assets/bin/python tools/assets/pipeline.py depthflow local --name ruin-preview
.venv-assets/bin/python tools/assets/pipeline.py depthflow local --name ruin-preview --render --seconds 5
```

The wrapper targets `depthflow==1.0.1` and opens a GLFW window on macOS, including for export; macOS does not supply EGL headless rendering. MP4 goes to `.asset-work/previews/`. This optional renderer is not installed automatically and was not validated on this machine. The existing Godot preview below provides the immediately usable depth proof without it.

## Reusable Godot depth layer and sample

The first stage-5 toolchain study is now `scenes/samples/workshop_study.tscn`. It combines a real local DA-V2 Workshop depth resource and an Aseprite-authored six-frame P1 carry study, preserving the existing painted artwork. The editable `.aseprite` source, full canvas, feet anchor and provenance are described in `assets/authored/README.md`. Space pauses/resumes, Right steps a paused pose, and Esc closes. Depth motion remains off. This is the historical separate art study. Directional poses are now in production; broader room layering remains later work.

```zsh
"/Users/oyl-mac_m1/Downloads/Godot.app/Contents/MacOS/Godot" \
  --path . res://scenes/samples/workshop_study.tscn
```

```zsh
.venv-assets/bin/python tools/assets/pipeline.py godot-import
"/Users/oyl-mac_m1/Downloads/Godot.app/Contents/MacOS/Godot" \
  --path . res://scenes/samples/depth_preview.tscn
```

The included `ruin-preview` depth map is a real local DA-V2 inference of existing `assets/ruin-movement.png`. The sample's idol uses the existing transparent `assets/relic.png` imported through the sprite pipeline. These are separate copies with source hashes, not replacement production art. **Motion starts off.** Space explicitly toggles a gentle preview; nothing follows the mouse or changes the expedition camera.

For another background, attach `scripts/assets/depth_layer.gd` to a Sprite2D and assign its exported `art` to the generated `art.tres`. Each instance creates its own ShaderMaterial. `motion_enabled=false` and `reduced_motion=true` are safe defaults. An approved decorative layer can set motion enabled and reduced motion false, then call `set_view_offset(Vector2)` explicitly; input is bounded to three source pixels. Call `set_reduced_motion(true)` to reset displacement. Do not attach displacement to interactive floors, doors or objects that must stay aligned with collision, LOS and authoritative coordinates. Flat/default rendering preserves source colors and alpha. Depth textures are numeric data and have no shader `source_color` hint.

The existing Web export uses an explicit resource list. Production explorer, Atlantis depth pair, v2 masks and scene mechanisms are explicitly included; historical study artwork is excluded. When adopting a generated asset, add its `sprite.tscn`/`frames.tres` or `art.tres` to `export_files` in `export_presets.cfg` if it is loaded dynamically; static scene dependencies are collected by Godot. Keep tools, keys, receipts, environments and previews excluded. Do not change the production entry scene for an art experiment.

## Validation

```zsh
.venv-assets/bin/python -m unittest discover -s tools/assets/tests -v
.venv-assets/bin/python tools/assets/pipeline.py godot-import
"/Users/oyl-mac_m1/Downloads/Godot.app/Contents/MacOS/Godot" \
  --headless --path . --script res://tests/asset_pipeline_test.gd
```

Tests use fixtures and mocked HTTP responses; they never spend API credits. They check env handling, secret suppression, no duplicate paid submissions, inline decoding and polling states, pixel/alpha alignment, frame timing, depth contract and the dashboard-documented DepthFlow upload contract. Godot checks real imported textures/resources, independent materials, opt-in/reduced-motion behavior and the isolated scene. Existing gameplay/privacy/network code is untouched.

## PowerShell equivalents

Useful if this repo returns to Windows. Install Python 3.11 and configure `DEPTH_ANYTHING_DIR`, `DEPTH_ANYTHING_PYTHON`, `GODOT_BIN`, and `ASEPRITE_BIN` in the private file for that machine:

```powershell
py -3.11 -m venv .venv-assets
& .\.venv-assets\Scripts\python.exe -m pip install -r tools/assets/requirements.txt
& .\.venv-assets\Scripts\python.exe tools/assets/pipeline.py init
& .\.venv-assets\Scripts\python.exe tools/assets/pipeline.py doctor
& .\.venv-assets\Scripts\python.exe tools/assets/pipeline.py depth generate --name archive-background-v1 --source 'path\approved-room.png'
& .\.venv-assets\Scripts\python.exe tools/assets/pipeline.py godot-import
& .\.venv-assets\Scripts\python.exe -m unittest discover -s tools/assets/tests -v
$env:GODOT_BIN = 'C:\path\Godot.exe'
& $env:GODOT_BIN --headless --path . --script res://tests/asset_pipeline_test.gd
& $env:GODOT_BIN --path . res://scenes/samples/depth_preview.tscn
```

All CLI arguments are identical across shells; use one line in PowerShell or backticks for continuation, not zsh backslashes. Avoid passing keys in either shell's history.

## Contract references

- PixelLab official schema: https://api.pixellab.ai/v2/openapi.json (checked 2026-10-06; async v3 animation and style generation).
- Aseprite CLI: https://www.aseprite.org/docs/cli/
- Depth-Anything-V2 source/model license: https://github.com/DepthAnything/Depth-Anything-V2
- Open-source DepthFlow inputs/animation/export: https://depth.tremeschin.com/docs/inputs/, https://depth.tremeschin.com/docs/animation/, https://depth.tremeschin.com/docs/exporting/
- Paid DepthFlow image-upload quick start: https://www.depthflow.io/apis/api-keys (authenticated, read 2026-10-06) and account payload: https://www.depthflow.io/apis/dashboard (read 2026-10-07); fixed same-origin upload route, credential gate and direct MP4 verified. JSON/polling fields remain unverified. The Dashboard's legacy `api.depthflow.ai` route conflicts with the verified current upload origin; the adapter retains the working `depthflow.io` route.

## Current coherent scene composition · 2026-10-07

`assets/city.png` is reused through `assets/generated/depth/atlantis-background-v1/` (actual local CPU vits inference, 1536×1024, near-white). `scripts/atlantis_background.gd` puts it on a separate CanvasLayer with a slow time loop, reduced-motion switch and subdued play tint. The level painting never receives displacement. `shaders/local_scene.gdshader` and `local_water.gdshader` fade the local scene without revealing unlit floor content. Generic depth shader soft-focus/desaturation defaults are zero, preserving old depth studies.

`assets/generated/environment/sluice-set-v2.png` is a built-in imagegen asset made against the painted level reference, with actual transparent alpha and its exact `.prompt.txt`, `.origin.txt` and `.manifest.json`. It supplies masonry jambs, a horizontal moving slab, an authored side slab and grounded wheel pedestals. Native nine-slicing keeps jamb scale while matching shared threshold width. World pieces use feet-depth ordering and local sight; unlocked wheels remain in the scene. Workshop valve and extraction boat are the originals in the painting, with shared reachable approaches. No new PixelLab/DepthFlow credit was consumed for this pass.
