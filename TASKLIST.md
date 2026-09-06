# AstraTD Task List

## Outstanding

Work through the phases in order, using focused commits within each phase. Recommendation IDs refer to the scope and success criteria in the [Bloons TD research report](docs/BLOONS_TD_RESEARCH.md). Existing requests are merged below rather than duplicated.

P0 covers the first delivery sequence and its supporting requirements; P1 deepens the core game; P2 is the later expansion backlog. Prototype tasks should establish whether an idea improves play before expanding it.

### Phase 4 — Combat understanding and learning

- [ ] **R09 · P1 — Enemy feedback:** separate shield and hull indicators; show armor, regeneration, slowing, and resistance with readable symbols and inspectable counterplay information.
- [ ] **R10 · P1 — Wave intelligence:** enrich existing enemy counts, boss warnings, and rewards with portraits, defense symbols, entry lanes, and formation order. Explain first appearances and show the no-purchase bonus forfeited by combat spending.
- [ ] **R12 · P1 — Contribution and after-action reports:** track damage, kills, firing uptime, escapes, and spending; expose Cryostat slow uptime, Relay support contribution, and Nova weapon contributions. Label estimated attribution clearly.
- [ ] **R13 · P1 — Retry Wave:** capture the exact pre-wave preparation state and restore it on defeat so players can adjust their fleet. Restore resources and rewards consistently; distinguish uninterrupted clears without blocking ordinary completion.
- [ ] **R14 · P1 — Fleet test range:** provide enemy/count/spacing and budget controls, pause/speed/reset, and preparation-layout copying. Display measured results and keep experiments separate from campaign progression.
- [ ] **R15 · P1 — Fleet trials:** add short optional missions teaching armor counters, slowing, Relay coverage, Nova drones, and Cryostat rotation. Reuse test-range infrastructure and temporarily supply the relevant upgrades.

### Phase 5 — Tactical depth and balance

- [ ] **R11 · P1 — Fleet combinations:** prototype a few explicit interactions, such as brittle targets or drone marking, with clear conditions and stacking limits. Preserve distinct roles and viable alternative builds.
- [ ] **R16 · P1 — Signature boss:** build one readable boss mechanic, such as escort-generated shielding, with visible sources, telegraphed phases, an explanation of counterplay, and a practice opportunity.
- [ ] **R20 · P1 — Wave and endless balance:** test several affordable strategies against recognizable threat patterns and smooth endless growth. Preserve or explicitly version legacy endless armor/slow rules; rebalance after major support and drone changes.

### Phase 6 — Replay and expansion backlog

- [ ] **R17 · P2 — Curated challenges:** reuse maps with limited budgets/fleet counts, no selling, restricted offensive roles, or distinct enemy mixes. Show rules before launch and validate each preset; separate map selection from difficulty rules.
- [ ] **R18 · P2 — Map mastery:** add optional no-core-damage, no-retry, budget, and small-fleet feats plus local endless/challenge records. Use cosmetic recognition and show eligibility before play.
- [ ] **R19 · P2 — Sector geometry:** create meaningful placement differences through repeated passes, split/asymmetric approaches, and separated engagement windows. Add animated preparation route previews; prototype interactive obstructions only with clear firing feedback.
- [ ] **R21 · P2 — Active-command prototype:** evaluate a small number of timed abilities, such as Relay overcharge or a drone surge. Keep normal support/drone operation automatic and controls stable; preserve cooldown progress through upgrades and saves.
- [ ] **R22 · P2 — Expedition prototype:** connect three sectors with a shared fleet allowance and readable, run-limited choices between missions. Validate the short operation before adding more progression or branching routes.
- [ ] **R23 · P2 — Shareable challenges:** after curated presets work well, add validated local challenge import/export with reproducible rules and balance-versioned results.

## Requirements across implementation phases

- Preserve the original size of fleet models through every upgrade and save/load; communicate upgrades through details, lights, and drones.
- Keep manual wave starts, pause, existing preparation saves, and current wave/reward information working as features evolve.
- Use consistent calculations for UI previews and combat effects. Preserve stable saved IDs and cover migration/restoration for new paths, targeting, support, and drones.
- Run checks appropriate to each slice, including balance and rendered performance when combat or entity counts change. Mark tasks complete against their linked research success criteria.

## Completed

- **2026-09-06 — Phases 1–3 (R01–R08, R24):** named upgrade paths and effective previews; support-only Relay with damage/range/fire-rate paths and visible coverage; Nova’s 1/2/3 drones; constrained Cryostat aiming; saved targeting controls; bounded effects and reduced intensity. Model scale, preparation saves, pause, and manual waves remain intact. Full suite, six campaigns, rendered UI, and drone/support lifetime checks passed. See [acceptance evidence](docs/PHASES_1_3_ACCEPTANCE.md) and [performance measurements](docs/PERFORMANCE.md).

- **2026-09-06 — Project organization:** grouped scenes and their scripts, shared logic, runtime assets, Blender sources, tools, and documentation. Preserved resource IDs and save compatibility; the complete suite passed from a cache-free copy, with rendered UI and checkout startup/performance checks. See the [structure and verification guide](docs/PROJECT_STRUCTURE.md).
- **2026-09-06 — Bloons TD research:** reviewed the latest confirmed BTD6 PC/mobile release (56.3), recent official design changes, and AstraTD gaps. See the [24 prioritized improvement proposals](docs/BLOONS_TD_RESEARCH.md), including upgrade UI, Nova drones, Cryostat aiming, and support-only Relay.
- **2026-09-06 — Game expansion:** finite maps, expanded fleets and enemies, upgrades, menus, pause and speed controls, preparation saves, persistent progress, settings, and audio. See the [acceptance report](docs/ACCEPTANCE.md) for scope and verification, and the [README](README.md) for current features and controls.
- **2026-09-06 — Upgrade model size:** fleet models retain their original size when upgraded or restored from saves. Integration, station, and Nova pulse checks passed.
