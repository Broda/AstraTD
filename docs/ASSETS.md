# Fleet assets

The game models, material textures, and purchase renders are original procedural
work created for this repository. No external model, texture, icon pack, or stock
image is required, and these assets add no third-party attribution obligations.
Blender is a production tool, not a bundled runtime dependency.

## Rebuilding

Run from the repository root with Blender 5.2 or a compatible version:

```text
blender --background --python tools/asset_pipeline/build_models.py
blender --background --python tools/asset_pipeline/render_fleet_icons.py
blender --background --python tools/asset_pipeline/build_expansion_models.py
blender --background --python tools/asset_pipeline/render_expansion_icons.py
```

To refresh only Relay's current purchase icon without regenerating unrelated
icons or historical review images:

```text
blender --background --python tools/asset_pipeline/render_expansion_icons.py -- --icons relay
```

The original fleet generator creates the shared PBR maps in `assets/textures/`.
The expansion generator uses those existing maps and writes only its own `.blend`
and `.glb` files. Both sets of editable Blender sources pack their texture images;
GLBs embed base color, roughness, and normal maps. The source models retain named
individual armor plates, hull sections, engines, and weapon parts. Exports batch
static meshes by material and parent to limit draw calls while preserving weapon
articulation and effect anchors.

`WARDENS_ASSETS` redirects the asset root for GLB output: models are written under `models/<model_id>/<model_id>.glb` inside that root. Editable sources are in `art/models/`; the default runtime model root is `assets/models/`. `WARDENS_RENDER_SAMPLES`
can change the expansion renderer's sample count (40 by default). Render scripts
assemble and light source copies without modifying the game models or materials.

## Expansion content and mounting contract

Blender **−Y** is the bow and **+Z** is up. glTF export converts this to Godot
**+Z** forward and **+Y** up, matching the original fleet.

| Stable asset ID | Role and visual identity | Exported anchors |
| --- | --- | --- |
| `railgun` | Long, narrow ship with an open twin-rail accelerator, amber field clamps, aft bridge, capacitor nacelles, and armored ventral recoil keel. | `Muzzle_0` at Godot `(0, 0.17, 1.51)` |
| `relay` | Support-only triangular station with three amplifier pods, a parabolic uplink dish, lower service drum, and braced undersides. No offensive guns are mounted in the game or current icon. | `AuraEmitter`; unused legacy `GunSocket_0` and `GunSocket_1` retained in source |
| `relay_gun` | Retired defense turret retained as an unused authoring/export resource. Its elevation bearings, pulse collars, muzzle guard, and rear heat sink document the earlier design. | `BarrelPivot` with child `Muzzle_0`; unused at runtime |
| `shielded` | Broad defensive escort with swept ceramic shield vanes, forward blue emitters, reinforced keel, and dorsal shield generator. | `ShieldEmitter` |
| `regenerator` | Repair frigate with green ringed cylindrical reservoirs, an exposed repair reactor, forked emitter booms, and ventral conduit armor. | `RepairEmitter` |

Relay's historical gun root attached at `GunSocket_*`: the root provided yaw,
while `BarrelPivot` provided elevation and recoil. That assembly is no longer
instantiated by gameplay or by the Relay icon renderer. The unused `relay_gun`
source, GLB, and standalone icon are retained for authoring history; they are not
current Relay equipment. Nova and Cryostat still use their own articulated
weapon assemblies and transformed muzzle anchors.

Relay uses warm orange emitters; railgun uses yellow amber; shielded ships use blue;
regenerators use green. Their silhouettes differ as well as their materials, so
combat readability does not depend only on color. The hulls are closed and detailed
from below. The relay's open dish has a solidified rear surface and radial braces.

The expansion exports have 6–7 material surfaces per asset. Source polygon counts
before glTF triangulation are 6,604 (railgun), 6,610 (relay), 1,624 (relay gun),
3,684 (shielded), and 5,956 (regenerator). The relay gun preserves separate static
and pivoted surfaces even when their materials match.

## Visual review artifacts

- `assets/icons/railgun.png` and `assets/icons/relay.png`: 256 × 256 transparent
  purchase renders of the current models. Relay was refreshed for the support-only
  design on 2026-09-06 and has no offensive gun assemblies.
- `assets/icons/shielded.png` and `assets/icons/regenerator.png`: matching enemy
  preview icons; `assets/icons/relay_gun.png` is a historical render of the retired gun.
- `docs/model_previews/expansion_gallery.png`: historical labeled fleet and enemy
  gallery from the expansion. Its armed Relay depicts the earlier design.
- `docs/model_previews/expansion_relay_side.png`: historical low view showing the
  earlier gun assemblies, fixed dish, lower service drum, and underside braces.
  The guns in this review image are no longer part of the live Relay.
- `docs/model_previews/expansion_railgun_underside.png`: bottom view of the complete
  armored keel, pressure hull, accelerator, and engine nacelles.

The original fleet review images remain in `docs/model_previews/fleet_gallery.png`
and `docs/model_previews/nova_side.png`.
