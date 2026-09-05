# Wormhole Wardens

A 3D space tower defense game built with Godot 4.7 and GDScript. All ships and stations were modeled and exported using Blender.

## Play

Double-click `Launch.cmd` on this machine. Alternatively, import `project.godot` in Godot and press F6 or F5.

- Choose a tower in the right panel, or press **1–4**. Click the map to deploy. Keep clicking to place more of the same type.
- The range ring turns green for valid locations and red where placement is blocked. Ships cannot overlap the wormhole or each other.
- **Right-click / Escape** cancels construction. Click an existing tower to inspect, upgrade, or salvage it.
- Each tower offers **two exclusive specializations**, with **three upgrade tiers** along the chosen branch.
- Click **Next Wave** when ready. Waves never start automatically.
- Each kill earns credits. Clearing a wave pays a completion reward, plus **45 + 10 × wave** credits if you bought no towers or upgrades during that wave. Purchases between waves do not affect the bonus. Salvaging does not forfeit it.
- Escaped raiders damage the core; dreadnoughts deal four damage. Restart when core integrity reaches zero.

## Fleet

| Tower | Cost | Weapon | Base range | Specializations |
| --- | ---: | --- | ---: | --- |
| Lancer | 100 | Rapid single-target laser | 5.1 | Damage / range |
| Bastion | 170 | Explosive missile strike, 1.5 splash radius | 6.4 | Damage / fire rate |
| Nova | 210 | Pulse damages all enemies in range | 3.8 | Damage / range |
| Cryostat | 140 | Low-damage beam slows enemies for 2 seconds | 4.6 | Stronger slow / fire rate |

Enemy count, health, and speed increase each wave. Fast ships arrive from wave 2, armored ships from wave 3, and a dreadnought every fifth wave. Survival is endless.

## Project and checks

`main.gd` contains gameplay and UI. `wormhole.gdshader` animates the lane, and `nebula.gdshader` draws the procedural background. `space_fx.gd` renders a bounded particle pool for maneuvering jets, engine trails, impact sparks, and spiraling implosions. `assets/` contains GLB models and purchase icons; `source/` contains editable Blender files, their generator, and the Blender icon renderer.

The Lancer turns smoothly using opposing bow/stern thrusters. Its jets emit from the side opposite the required force. Enemy hits release sparks; destroyed ships collapse inward. Purchase buttons use renders of the actual ships and individual upgrade symbols.

To regenerate assets, run Blender in background mode with `--python source/build_models.py`, then `--python source/render_fleet_icons.py` to render the purchase icons and apply the final material treatment.

Run Godot with `--headless --path . -- --smoke-test` for economy and placement assertions, `--headless --path . -- --combat-test` for five-wave combat and game-over checks, or `--headless --path . -- --vfx-test` to verify thrust direction, impact effects, inward collapse, and particle cleanup. `-- --capture` creates a staged gameplay screenshot and exits.

This first playable version has one map and session-only progress. The local launcher requires the Godot installation path shown above; the project itself can be opened on other machines with Godot 4.x.
