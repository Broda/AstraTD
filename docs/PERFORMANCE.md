# Performance acceptance workload

Measured on September 6, 2026 using `tests/performance_test.gd`. Both the headless
and rendered runs completed all **76 assertions**, exited with code 0, and logged
no engine errors or resource-leak warnings.

## Reproduce

From the repository root:

```text
godot --headless --path . --log-file work/performance-headless.log -- --performance-test
godot --path . --log-file work/performance-rendered.log -- --performance-test
```

The test writes machine-readable results to `work/performance_headless.json` or
`work/performance_rendered.json` and prints the same data as `PERFORMANCE_RESULT`.
The `work/` directory is ignored by Git. The test does not write saved runs,
completion progress, or settings. It restores its temporary audio settings and
clears its workload before exiting.

## Workload

- Twin Rift (Hard), with all **42 enemies** from its final authored formation
  simultaneously alive and spread across both routes.
- **30 legally placed towers**, five of each of the six roles. All have three
  purchased upgrade tiers; both exclusive branches are represented. This includes
  Nova pulse generators and **40 independently aiming station gun assemblies**.
- Enemy hull health is raised to keep the population alive. Enemies nearing the
  core wrap to their route's beginning. Health refresh and wrap preparation are
  outside the measured simulation call.
- Normal gameplay movement, target selection, independent gun aiming, damage,
  shields, regeneration, slowing, support auras, muzzle effects, particles, and
  firing/impact SFX run through `scenes/gameplay/main.gd`'s `_process` and its usual helpers.
- **60 warmup frames**, then **180 measured frames**, each with a fixed `1/60`
  second simulation step. The test yields each frame to service audio and dispose
  queued effect nodes. Every role fires during the workload.

The setup grants artificial credits and health to produce sustained rendering and
simulation pressure. It is a density stress test, not evidence that this fleet is
affordable or that a campaign difficulty is balanced. It also does not establish
the maximum possible density of the endless map.

## Recorded environment

| Item | Value |
| --- | --- |
| Operating system | Windows |
| Engine | Godot 4.7.2 stable, official build |
| Processor | Intel Core Ultra 7 165H, 22 logical processors |
| Renderer | OpenGL Compatibility (`gl_compatibility`) |
| GPU in rendered run | NVIDIA RTX 2000 Ada Generation Laptop GPU |
| Reported OpenGL/driver | OpenGL 3.3.0, NVIDIA 596.41 |
| Rendered window | 1280 × 800 |
| Logical viewport | 1440 × 900 |
| VSync | Enabled in rendered run |
| 3D antialiasing | Project setting `msaa_3d=2` |

## Results

CPU measurements cover only the direct `game._process(1.0 / 60.0)` call. They
exclude workload preparation, frame waits, and deferred engine cleanup. Percentiles
use the nearest-rank value from the 180 measured samples.

| Metric | Headless | Rendered |
| --- | ---: | ---: |
| Simulation CPU median | 3.268 ms | 3.687 ms |
| Simulation CPU p95 | 5.351 ms | 5.862 ms |
| Rendered frame interval median | Not measured | 16.665 ms |
| Rendered frame interval p95 | Not measured | 16.773 ms |
| Peak live particles | 1,588 / 2,400 | 1,588 / 2,400 |
| Peak transient effect nodes | 61 | 61 |
| Peak active SFX voices | 8 / 12 | 8 / 12 |
| Peak active combat voices | 8 / 8 | 8 / 8 |

The rendered frame intervals are measured between successive
`RenderingServer.frame_post_draw` completions. They include engine scheduling and
VSync waits; they are not isolated GPU execution times. This run maintained frame
intervals close to 60 Hz under the specified workload. Headless timings measure
simulation CPU cost and provide no evidence about GPU frame time.

Across warmup and measurement, firing-cycle totals were Lancer 38, Bastion 19,
Nova 20, Cryostat 44, Railgun 10, and Relay 20. A Nova firing cycle can discharge
multiple independently targeted guns. Counts were identical in both modes.

## Acceptance limits and practical scope

The automated test fails with a nonzero exit code if it cannot build the legal
fleet, preserve 30 towers/42 enemies for the entire workload, collect all 180
samples, exercise every weapon role and actual SFX, or respect the particle and
audio budgets. Combat audio may occupy at most eight voices out of the twelve-voice
pool, reserving capacity for important noncombat cues.

It also guards against transient effects accumulating beyond 1,023 live nodes in
this fixed workload. This is a benchmark sanity limit, not a claimed hard pool cap
in gameplay; the observed peak was 61 nodes. Expiring effects are released between
frames.

These are single short runs on one machine with VSync enabled. Background load,
power mode, resolution, graphics drivers, and slower GPUs can change results.
The check deliberately has no hardware-specific CPU or FPS pass threshold. Use
the recorded frame and CPU timings to compare future changes under the same
environment, and test longer sessions separately when looking for gradual memory
growth or sustained thermal throttling.
