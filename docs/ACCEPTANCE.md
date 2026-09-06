# Expansion acceptance evidence

Verified on 2026-09-06 with Godot 4.7.2, Windows, and the Compatibility renderer. All checklist items are implemented and verified within the scope below. The full automated run finished with `ALL CHECKS PASSED`; engine error and warning output fails the runner even when a script exits with code zero.

## Selected scope

- Aurora Reach (Easy, 8 waves), Cobalt Bend (Normal, 10), Twin Rift (Hard, 12), and the original endless Outer Rim.
- Railgun and Relay extend the original four roles. Aegis shields and Mender regeneration extend the four original enemies. Every tower has two exclusive three-tier branches with explicit effects and prerequisites.
- Saves are available only during preparation between waves. Active-wave serialization is therefore not applicable. Three slots retain stable map, tower, and upgrade branch IDs, exact economy, core, kills, tier ownership, positions, and speed. Derived stats and independent gun assemblies are rebuilt without purchases or rewards.
- Music continues during pause. Gameplay and existing SFX stop, menu audio remains available, and simulation speed never changes audio pitch or UI timing.

## Verification results

| Check | Evidence |
| --- | --- |
| Content | 12,145 assertions: map geometry, all routes/gates/bounds, authored finite waves, stable IDs, 36 upgrades, copied definitions, and original endless parity over 20 waves |
| Original regressions | Smoke/economy, five-wave combat and defeat, VFX/thruster direction, stationary station bodies and muzzle aiming, independent Nova targeting, and paid exclusive Nova pulse unlock all pass |
| Session integration | 226 assertions: map/replay cleanup, every-lane placement, pause freeze, equal simulated time at 1/2/3x, save reconstruction, stale numeric branch ordering resolved by stable ID, invalid-load preservation, defenses, support, railguns, relay mounts, terminal rewards and completion persistence |
| Menus | Real button signals verify navigation/focus, Escape cancel-before-pause, replacement/load/overwrite/delete/quit confirmation, OS-window close pausing before confirmation, corrupt slots, settings, resume, completion badges and replay |
| Storage/settings/audio | Version/schema rejection, atomic backup recovery, corrupt primary preserving a valid backup, exact balances/upgrades, separate progress, muted startup, voice budgets, pause routing and settings round trips pass |
| Campaign balance | Two earned-economy strategies win each finite map: six full campaigns, no free damage or income; see [balance evidence](BALANCE.md) |
| Display restart | 80 checks across three separate rendered processes; production main-scene startup restores fullscreen/windowed mode, remembered size, audio toggles and 37/23/64% test volumes before menu playback; defaults restore and persist |
| Layout | Screens captured and visually inspected at 960×600, 1280×800 and 1440×900, plus fullscreen; map cards, all fleet buttons, upgrade branches, main/pause/results/settings screens remain visible without clipping |
| Dense combat | 76 checks in each headless/rendered benchmark; 30 tier-three towers, 40 independent mounts and 42 simultaneous enemies; peak 1,588/2,400 particles and 8/12 SFX voices; rendered frame median 16.665 ms, p95 16.773 ms on this machine; see [performance evidence](PERFORMANCE.md) |
| Assets | Complete Blender sources/GLBs, packed PBR textures, UVs, independent weapon hierarchy, model icons and underside review renders; original generated audio with bounded peaks, continuous loop endpoints and a 1.2-second music crossfade |

## Reproduce

```powershell
.\tests\run_checks.ps1
.\tests\run_checks.ps1 -CaptureUI
# Or supply -Godot 'C:\path\to\Godot_console.exe'.
```

The first command imports assets and runs all automated headless checks. `-CaptureUI` also requires a display and captures the screens before running the ordered `write`, `read`, and `windowed` display phases in separate processes. Logs go under ignored `work/checks/`. Save tests use isolated test directories and do not alter player slots or completion progress.

The production gameplay screenshot is `preview.png`; map/settings screenshots are in `docs/screenshots/`. The remaining reproducible UI captures are written to `work/ui_*.png`. Detailed model and audio generation instructions are in the README and asset documents.

## Limits

The balance evidence proves two deliberate mixed strategies per map, not every placement or upgrade order. Performance is a bounded worst-finite-wave workload on the documented machine, not a guarantee for arbitrary endless-wave densities or other hardware. Audio levels, repeat limits, routing and peak protection are verified; speaker/headphone preferences still call for listening on the intended device. Saves intentionally resume at preparation boundaries, and the recovery scheme relies on the host filesystem's rename behavior.
