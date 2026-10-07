# Relic Tide — large expeditions

Approved user refinement, 7 October 2026. This supersedes the old one-map, no-combat scope and narrow-camera/Atlantis-backdrop presentation. The prototype remains an internal regression fixture, not a fourth public level.

The playable loop is: choose one of three ruins in a waiting room, enter with 2–4 explorers, solve nearby chests for useful equipment, find and extract treasure, and make route decisions as warned local breaches and occasional hunters interrupt exploration. Only extracted treasure scores. Leaving an active match explicitly aborts it for the remaining group.

## Acceptance contract

- Three authored 3840×2560 maps, each with twelve rooms, segmented corridors, loops, physical gates, a two-person vault, extraction, and exactly one single-entry refuge. Map choice is per room/match; two rooms may run different levels concurrently.
- A steady player camera with legible character/prop scale and normally lit sight. The supplied Among Us / Goose Goose Duck images set an actor-height target of 12–14% of the viewport. Gameplay zoom is 2.6; level size and normal sight range stay unchanged. Darkness, power failures, walls and closed gates reduce visibility. A collected map reveals structure without disclosing hidden actors or inventories.
- The environment is raster floors, walls and props belonging to the playable level. No city/video backdrop. Original explorers retain their eight-direction, physically held-item animations and smooth predicted walking.
- Seeded, announced local water sources. Fully shut gates block ingress; wet rooms stay wet after closing. Deep passages require oxygen gear. A dry, sealed refuge never leaks, times out, or floods at the ending.
- Server-validated rune, circuit and pressure puzzles unlock chests. Rewards include a map, treasure bearing, oxygen, gas protection, medkits, ammunition and bankable treasure.
- Three hearts, healing, drowning, toxic exposure, and intermittent monster pursuit with rest intervals. Tranquilizers briefly stun nearby monsters or other explorers through unobstructed sight; all effects, ammunition and cooldowns are authoritative.
- A seeded expedition lasts 10–30 minutes. Its final global warning starts 60–120 seconds before the deadline and directs survivors toward extraction. A refuge protects water, not extraction or the clock.
- A Start screen, physical waiting room, host map selection, ready states and live room-code joining. The play HUD uses authored icons, hearts, breath and tide gauges; short functional labels and numeric ammunition/countdowns remain where useful.
- A complete online round supports 2, 3 and 4 people. New rule, privacy, authority, map and presentation tests cover the new modes; original regression suites remain valid. Web export and actual local multi-client rendering are checked at supported desktop sizes.

## Implementation boundaries

Reuse the fixed-step rules, room service, recipient projection, bounded prediction and raster explorer pipeline. A per-match `ExpeditionMap` owns all floor, gate, interaction and flood coordinates. New survival state is pure deterministic domain code; scenes do not choose loot, apply damage, advance time or resolve shots. Invisible floor/door geometry remains the collision and occlusion source.

No full-state packets, remote player minimap, copied reference-game assets, simultaneous-turn waiting, IP-entry UI, automatic matchmaking, reconnect, mobile redesign or speculative provider framework. Local tests cannot establish WAN quality or human balance; report those limits separately from implemented mechanics.

## Visual direction contract

THESIS: A broad, legible ancient ruin where closing a gate, reaching a chest and fleeing a hunter are immediately readable physical choices.

OWN-WORLD: Blue limestone, sea-green oxidized metal, warm ochre brass, native explorer pixels and restrained red danger. A single raster kit unifies floors, wall reveals, gates, props, creatures and HUD emblems.

STORY: Start → choose/ready in the staging room → explore and equip → treasure pursuit → warned route loss → relief between hunts → final extraction alarm → earned outcome.

FIRST VIEWPORT: The title and Start dominate a quiet raster staging floor. During play the world dominates, with three hearts at upper left, a slim tide clock at top, equipment below, and one contextual interact badge at the relevant object.

FORM: Native Godot controls on a 1440×900 logical canvas, verified down to 960×600. A steady 2.6 gameplay camera follows the same rendered feet as the local light, framing the 44-unit explorer at about 12.7% of viewport height to match the supplied references. No pointer drift, decorative city or diagnostic wall of text.

FINISH: Inspect real native/web renders of Start, waiting, all three levels, a warning/closed gate, a puzzle, a hunter and the final alarm. Review against this direction and the craft floor before updating durable design documentation.
