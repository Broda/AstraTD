# Performance acceptance workload

Measured on September 6, 2026 with `tests/performance_test.gd`. The final headless
and rendered runs each passed **521 assertions**, exited with code 0, and logged
no engine errors or resource-leak warnings. Each run checks normal and reduced
visual intensity, then exercises the complete fleet for another two simulation
minutes at 1x, 2x, and 3x.

## Reproduce

From the repository root, using a Godot 4.7 console executable:

```text
godot --headless --path . --log-file work/performance-headless.log -- --performance-test
godot --path . --log-file work/performance-rendered.log -- --performance-test
godot --headless --path . --script tests/nova_drone_test.gd
```

The integrated test prints `PERFORMANCE_RESULT` and writes
`work/performance_headless.json` or `work/performance_rendered.json`. The top-level
metrics describe normal intensity; `cases` contains both measured scenarios and
`longevity` records the subsequent simulation soak. Rendered runs also save
`work/performance_normal.png` and `work/performance_reduced.png` after timing is
complete. `work/` is ignored by Git.

The test initializes the full HUD and fleet panel, uses temporary game/audio
settings, and clears the fleet and drains audio playback before exiting. It does
not write player saves, completion progress, or settings. Inspect the engine logs
alongside the assertion result; `tests/run_checks.ps1` rejects errors and warnings.

## Workload

- Twin Rift, with all **42 enemies** from its final authored formation alive at
  once and spread across both routes.
- **30 legally placed ships**, five per role, each with three purchased upgrade
  tiers. All five Novas use the drone path: **15 functional drones** accompany
  their existing four guns. The fleet has **30 independent station gun mounts**:
  20 on Nova and 10 on Cryostat.
- The five support-only Relays use paths `[damage, range, fire rate, damage,
  range]`. Relay has no weapon mounts and never fires. The arrangement supplies
  damage to 15 recipients, range to 11, and fire rate to three. Six recipients
  receive overlapping auras, with up to three sources per ship. The test checks
  strongest-per-stat application and one-time drone inheritance through Nova.
- Artificial credits permit the legal fleet placements and upgrades. Enemy hull
  health is replenished and enemies approaching the core wrap to their route's
  beginning. This preparation is excluded from CPU timing.
- Normal movement, route-based targeting, gun aiming, Cryostat hull rotation,
  shields, slowing, regeneration, damage, support, drone pursuit/recall, effects,
  and audio use the actual gameplay simulation.

This is a repeatable density workload. It does not establish an affordable fleet,
prove campaign balance, or cover every possible endless-map density. The previous
report used 40 mounts and an offensive Relay; use this revised workload for future
like-for-like comparisons.

## Timing method and environment

Each effect-intensity case rebuilds the same initial fleet and formation, runs
**60 warmup frames**, then collects **180 measured frames** at a fixed `1/60`
second step and 1x simulation speed. Every frame yields to the engine for audio,
rendering, and disposal of queued nodes. CPU timing covers only the direct
`game._process()` call, including its scheduled HUD refreshes. Preparation,
frame waits, deferred cleanup, and screenshot readback are excluded.

Rendered intervals are measured between successive
`RenderingServer.frame_post_draw` completions. They include engine scheduling and
VSync waits and do not isolate GPU execution time. Percentiles use nearest-rank
values from the 180 measured samples. The timing sample uses the ordinary fleet
HUD; selected Cryostat details and aiming arcs are captured afterward.

| Item | Recorded value |
| --- | --- |
| OS | Windows |
| Engine | Godot 4.7.2 stable, official build |
| CPU | Intel Core Ultra 7 165H, 22 logical processors |
| Renderer | OpenGL Compatibility (`gl_compatibility`) |
| GPU | NVIDIA RTX 2000 Ada Generation Laptop GPU |
| OpenGL / driver | OpenGL 3.3.0, NVIDIA 596.41 |
| Rendered window | 1280 x 800 |
| Logical viewport | 1440 x 900 |
| VSync | Enabled |
| 3D antialiasing | Project setting `msaa_3d=2` |

## Measured results

| Metric | Headless normal | Headless reduced | Rendered normal | Rendered reduced |
| --- | ---: | ---: | ---: | ---: |
| Simulation CPU median | 6.139 ms | 5.005 ms | 7.462 ms | 5.704 ms |
| Simulation CPU p95 | 7.862 ms | 7.004 ms | 10.215 ms | 6.992 ms |
| Rendered interval median | — | — | 16.669 ms | 16.665 ms |
| Rendered interval p95 | — | — | 17.501 ms | 16.783 ms |
| Peak particles / 2,400 | 1,542 | 715 | 1,542 | 715 |
| Peak transient effects / 256 | 65 | 34 | 65 | 34 |
| Peak SFX voices / 12 | 8 | 11 | 8 | 12 |
| Peak combat voices / 8 | 8 | 8 | 8 | 8 |
| Active drones / 15 | 15 | 15 | 15 | 15 |
| Drone hits | 90 | 90 | 90 | 90 |

The rendered median was close to a 60 Hz frame interval in both scenarios. Reduced
intensity cut the observed particle peak from 1,542 to 715 and transient effect
peak from 65 to 34. It retained identical weapon firing and drone hit counts.
These are observations from the recorded machine and short samples, not universal
frame-rate guarantees. Headless measurements provide no GPU performance evidence.

Across warmup and measurement, firing-cycle totals were Lancer **37**, Bastion
**22**, Nova **20**, Cryostat **47**, Railgun **10**, and Relay **0** in all four
cases. A Nova cycle can fire multiple independent guns; its 90 drone hits are
counted separately. All 15 drones acquired targets and attacked.

## Whole-fleet longevity and supported speeds

After the reduced-effects sample, the same 30-ship/42-enemy fleet runs for another
**120 simulation seconds**. Eight simulation steps are batched per real-frame
yield so queued nodes and audio still receive regular service. This measures
lifecycle correctness and resource bounds; it is not a real-time frame benchmark
or a sustained thermal test.

| Speed | Steps at input delta 1/60 | Simulation duration | Additional drone hits |
| --- | ---: | ---: | ---: |
| 1x | 2,400 | 40 seconds | 802 |
| 2x | 1,200 | 40 seconds | 830 |
| 3x | 800 | 40 seconds | 825 |

Both runs recorded **2,457 additional drone hits** and retained the original 15
fighter instances. Every offensive role continued firing, Relay remained at zero,
and the fleet/enemy counts and core health stayed constant. The highest particle
and transient-effect counts remained 715 and 34. Combat voices stayed at or below
eight; total voices peaked at 11 headless and 12 rendered.

Hull transforms remained at their original scale within floating-point precision;
the largest measured scale-vector error was approximately `8.43e-8`. Normalizing
hull rotation prevents repeated turns from accumulating scale drift.

The separate `tests/nova_drone_test.gd` passed **130 checks**, including 36 drones
across six simulated minutes. It isolates pool reconstruction, owner cleanup,
stable focus/distribute targeting, target death/range exit, carrier-only support
inheritance, cooldown changes, pause, and equal-time 1x/2x/3x behavior. It exercises
the controller with a minimal game stub and complements the integrated workload;
it does not measure full-game rendering or actual save-file I/O.

## Bounds and essential feedback

The gameplay limits checked by this workload are:

- **Three drones per carrier**, retaining existing instances when tiers change.
  Each owns one reusable beam; the 15 persistent drone beams are separate from
  the transient-effect list.
- **2,400 live particles** and **256 transient beam/pulse effects**. New optional
  effects respect capacity rather than growing an unbounded list.
- **12 SFX voices**, with at most **eight combat voices**, leaving room for other
  game cues. The test uses actual playback and drains it before shutdown.

Reduced intensity lowers particle emission and removes optional beam halos and
drone beam flashes. Damage, targeting, and drone movement continue unchanged.
At both intensities the test checks correct selected-Relay recipient markers,
visible selected-Cryostat aiming arcs, and visible enemy silhouettes/health bars.
Drone models remain visible throughout the soak. Rendered captures provide a
visual review of these controls and arcs under the dense workload.

These runs cover one laptop, one resolution, a bounded fleet, and short real-time
samples. They do not establish performance on lower-spec hardware, the largest
possible fleet, hours of play, or thermal throttling. There is deliberately no
hardware-specific CPU/FPS pass threshold. Recheck a lower-spec target before
claiming broader hardware support, and retain the same scenario, resolution,
driver, power mode, and background-load conditions when comparing revisions.
