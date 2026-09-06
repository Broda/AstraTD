# Phases 1–3 acceptance evidence

Date: 2026-09-06. Environment: Windows, Godot 4.7.2, Compatibility renderer.

This record covers the upgrade decisions, support fleet, and fleet behavior phases in [TASKLIST.md](../TASKLIST.md). All nine recommendations in these phases are implemented and verified below. The complete runner passed, followed by focused checks for the final keyboard-scroll correction and combat-capture framing.

## Scope and evidence

| Requirement | Implemented behavior and verified scope | Final evidence |
| --- | --- | --- |
| R01 — Upgrade UI | Named paths, icons, connected tier cards, an inspection panel, explicit purchase states, and separate salvage are present in the panel implementation. Cards expose both hover and focus inspection. | Headless/rendered inspector checks pass, including real Tab/Shift+Tab/Enter input and fully visible focused cards at 960 × 600. |
| R02 — Accurate previews | Shared calculations distinguish owned and supported damage, range, fire rate, slowing, coverage, pulse, and drones. All 42 real purchases match their effective previews. Future tiers include missing prerequisites and total investment; installed tiers do not apply twice. | Reviewed effective, owned, excluded, and future-tier details; prerequisite investment remains visible beside the separate purchase action. |
| R03 — Specializations | Four fleet types retain two paths; Nova and Relay each have three. All 14 paths have three named tiers, purposes, icons, stable IDs, costs, prerequisites, and explicit exclusivity. Existing offensive numerical paths remain stable; drones and Relay introduce the new mechanical choices. | All six fleet layouts pass; Nova and Relay expose three paths, connected cards, icons, and explicit exclusivity. |
| R04 — Support-only Relay | Relay has no attached offensive assemblies and cannot deal damage through either firing entry point. Damage, recipient weapon range, and fire-rate paths use the strongest bonus separately for each stat. Relays receive no Relay bonuses. Actual acquisition, hit damage, firing cooldown, and sale behavior are verified. | All six budget-constrained campaign strategies win; Relay stays unarmed and has a regenerated support-only purchase icon. |
| R05 — Support visibility | Real placement/selection highlights exclude Relays, affected counts match coverage, and increased coverage previews newly reached ships. Recipient details receive named sources. Live drones inherit carrier damage once and ignore a stronger aura near their target. | Reviewed current and projected coverage rings, recipient highlights/counts, strongest-per-stat source wording, and keyboard-accessible overflow. |
| R06 — Nova drones | Paid tiers add exactly one functional drone each, with save/load coverage for counts 1/2/3 and repeated restoration. Drones orbit while idle, distribute or focus attacks, stop damage outside carrier range, return, and freeze during pause. Original gun/pulse exclusivity is preserved. | 130 standalone checks and 521 checks in each headless/rendered workload pass. A close-up capture verifies all three paid drones attack. |
| R07 — Cryostat aiming | Both guns stay within ±90° throughout a 240-step turn. The body turns at a bounded rate, emits thruster particles, gains clearance inside the arcs, and settles without oscillating under small target motion. Illegal firing frames cannot damage a rear target. Selected arc visibility and range scaling are checked. | Reviewed selected arcs in normal/reduced dense combat; the 120-second fleet soak preserves hull scale within 8.43e-8 vector error. |
| R08 — Targeting | Closest to Core and Last compare remaining distance across unequal routes. Nova distributes stable locks and responds to priority/focus changes. Cryostat favors enemies needing slowing; Railgun defaults to strongest. Selections survive saves; older v1 records receive safe role defaults. | Real UI controls, role defaults, retained selections, keyboard focus, and focus/distribute behavior pass. |
| R24 — Bounded effects | Drone pools cap at three per carrier; transient beam/pulse effects cap at 256. Reduced mode retains essential beam geometry and supports persisted settings, including defaults for older files. | 15 live drones and overlapping support pass both intensities, plus a 120-second whole-fleet soak at 1×/2×/3× and a six-minute standalone drone test. |

## Completed automated checks

| Check | Result | Evidence |
| --- | --- | --- |
| Shared upgrade statistics | **253 checks passed** | [upgrade_data_test.gd](../tests/upgrade_data_test.gd): prerequisite projections, installed/exclusive nodes, separate Nova weapons, strongest per-stat support, no Relay amplification, and carrier-only inheritance. |
| Content definitions | **12,368 checks passed** | [content_data_test.gd](../tests/content_data_test.gd): maps, waves, stable IDs, all 42 upgrades, defensive copies, and original endless content parity. |
| Storage/settings/audio | **Passed** | [storage_test.gd](../tests/storage_test.gd): atomic recovery, third paths, optional targeting/aim settings, rejected malformed records, old settings, separate progress, buses, voice limits, and pause routing. |
| Real fleet integration | **1,699 checks passed** | [fleet_systems_test.gd](../tests/fleet_systems_test.gd): real paid upgrades, all-path save reconstruction, source/coverage behavior, combat support, effective cooldown preservation, targeting, legal aiming, live drones, reduced effects, and economic measurements below. |
| Final full suite | **Passed** | `tests/run_checks.ps1 -CaptureUI`: import, every standalone/runtime check, six campaign wins, rendered screens/drone combat, and three display-setting restarts. Zero engine warnings/errors. |
| Existing session integration | **214 checks passed** | Placement, economy, pause/speed, save rejection/recovery, terminal rewards, and support-only Relay. |
| Nova drone controller | **130 checks passed** | Counts 1/2/3, targeting, damage, recall, pause/speed, reconstruction, reduced effects, cleanup, and 36 drones over six simulated minutes. |
| Dense fleet performance | **521 checks passed per mode** | Separate headless and rendered normal/reduced runs, actual support overlap, identical firing, bounded effects, and a 120-second whole-fleet soak. |
| Final inspector correction | **Passed after the full suite** | Headless/rendered real-input tests verify complete focused-card visibility. Fleet integration (1,699), menus, and UI/drone captures passed again after the final UI correction. |

The fleet integration checks also verify original model scale through every upgrade and reconstruction, exact economy/investment, stale valid numeric branch indices resolved by stable IDs, no duplicate drones after repeated loads, and cooldown progress when upgrading an already supported receiver or upgrading/removing its Relay.

## Relay investment tradeoff

The integration benchmark supplies equal available budgets and measures four simulated seconds against one stationary, armor-free, durable target. Existing receivers are either all unupgraded Lancers or all tier-three damage-path Lancers. The alternative buys an extra Lancer and its first damage upgrade, leaving 20 credits; the Relay spends its full 190-credit allowance. All receivers have firing access and the Relay covers them all.

| Existing receivers | Fleet + base Relay: damage / spent | Same fleet + tier-one Lancer: damage / spent | Available budget |
| --- | ---: | ---: | ---: |
| 2 base Lancers | 297.36 / 390 cr | 459.90 / 370 cr | 390 cr |
| 4 base Lancers | 594.72 / 590 cr | 711.90 / 570 cr | 590 cr |
| 6 base Lancers | 892.08 / 790 cr | 963.90 / 770 cr | 790 cr |
| 2 tier-three Lancers | 1,335.78 / 1,168 cr | 1,339.92 / 1,148 cr | 1,168 cr |
| 4 tier-three Lancers | 2,671.56 / 2,146 cr | 2,471.93 / 2,126 cr | 2,146 cr |
| 6 tier-three Lancers | 4,007.33 / 3,124 cr | 3,603.95 / 3,104 cr | 3,124 cr |

This supports the intended tradeoff: baseline Relay damage support becomes attractive around an invested fleet, while a small basic fleet gains more immediate damage from another weapon. These measurements do not establish campaign balance, range-path value, slowing utility, armor performance, or the optimal use of every fleet composition. Geometry, target defenses, firing uptime, and additional Relay tiers need their own combat evidence.

## Rendered UI and combat review

The inspector retains a 490 × 760 logical area and uses scroll containers for its path tree and long details. Reviewed the 1280 × 800 and minimum 960 × 600 windows, plus 1440 × 900 gameplay and drone close-ups. The full screen suite also covers menus, settings, pause/results, fullscreen, and persisted windowed settings across three launches.

Actual Tab/Shift+Tab events reach and reverse tier focus. Enter on a future card only inspects it; BUY NEXT purchases one tier, preserves remaining credits, and cannot cross an excluded path. Focus and control identities survive repeated refresh. The final scroll correction reveals the complete focused card after layout, with assertions at the smallest supported size. Keyboard scrolling reaches long support-source and stat details. Selecting another ship clears stale coverage previews.

Reviewed states include owned, excluded, prerequisite, available, unaffordable, and completed paths. The always-visible reason shows prerequisite investment or the lock condition; salvage remains separate. Source text distinguishes every in-range Relay from the highest per-stat values that apply. Coverage previews show current → projected recipients and explain green/current versus amber/new highlights.

Published evidence:

- [Nova upgrade inspector](screenshots/upgrades.png): future tier with prerequisite-inclusive cost and supported values.
- [Relay coverage preview](screenshots/relay_support.png): coverage and recipient changes.
- [Three attacking Nova drones](screenshots/nova_drones.png): controlled, stationary durable target; all three drones must have attacked before capture. Camera zoom is for inspection; model scale is unchanged.

Other local captures are `work/fleet_panel_relay_960.png`, `work/ui_*.png`, and `work/performance_normal.png` / `work/performance_reduced.png`. Screenshots are excluded from timing samples.

## Performance and lifetime results

Both headless and rendered workloads pass 521 checks with 30 ships, 42 enemies, 15 live drones, all three Relay paths, and six recipients covered by overlapping sources. Every drone attacks; Relay fires zero times. Normal/reduced cases have identical firing totals and 90 drone hits each. Reduced mode lowers peak particles from 1,542 to 715 and transient effects from 65 to 34; all remain within the 2,400-particle and 256-effect caps.

On the reference RTX 2000 Ada laptop, rendered CPU median/p95 is 7.462/10.215 ms with normal effects and 5.704/6.992 ms with reduced effects. Rendered frame interval p95 is 17.501 ms and 16.783 ms respectively. The subsequent 120-second simulated soak spans 40 seconds each at 1×/2×/3×, records 2,457 more drone hits, retains the original 15 drone nodes, and preserves model scale. The standalone drone check covers 36 drones for six simulation minutes. Selected Cryostat arcs, recipient markers, and enemy health/silhouette feedback remain visible in both effect modes.

See [PERFORMANCE.md](PERFORMANCE.md) for exact hardware, samples, voice limits, counts, reproduction, and limitations. Batched simulation soak results establish lifetime/resource behavior; they are not rendered frame-rate measurements. Results apply to the measured hardware and workloads, without a claim for untested hardware or larger fleets.

## Compatibility and limits

Preparation-only saves remain the persistence boundary. Derived stats and drone nodes rebuild from stable type/path IDs and purchased tiers. Old Relay ownership loads into the redesigned support-only balance; historical offensive/aura effects are intentionally replaced by the new path effects. Save validation does not promise compatibility with unknown future content or schema versions.

The work does not establish completion of phases 4–6. Boss redesigns, retry-wave checkpoints, a test range, contribution reports, challenge presets, and later progression remain separate tasks.

## Reproduce the completed checks

From the repository root, replace `godot` with the installed console executable if it is not on PATH:

```powershell
godot --headless --path . --script tests/upgrade_data_test.gd
godot --headless --path . --script tests/content_data_test.gd
godot --headless --path . --script tests/storage_test.gd
godot --headless --path . -- --fleet-systems-test
```

Save tests use per-process isolated directories and clean up their own files. Use `tests/run_checks.ps1 -CaptureUI` for the full regression and rendered suite. Local logs are in `work/checks/`; final focused reruns are `work/final-*.log`.
