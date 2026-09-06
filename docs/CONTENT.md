# Game content and balance

`scripts/data/game_data.gd` owns immutable map, formation, enemy, tower, and upgrade definitions. Runtime gameplay receives independent dictionaries from its lookup functions. Save files refer to map, tower, and upgrade branch string IDs; array indices only support the existing keyboard/UI ordering.

## Initial map lineup

| Stable ID | Map | Difficulty | Starting credits | Core | Final wave | Routes |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| `aurora_reach` | Aurora Reach | Easy | 520 | 25 | 8 | 1 |
| `cobalt_bend` | Cobalt Bend | Normal | 460 | 20 | 10 | 1 |
| `twin_rift` | Twin Rift | Hard | 420 | 16 | 12 | 2 |
| `endless` | Outer Rim | Endless | 440 | 20 | None | 1 |

Aurora's broad bends offer generous overlap. Cobalt's deeper alternating turns create more compact shared firing positions. Twin Rift divides the approaches before they meet at one core. Each map provides 181 sampled points per route, entry and exit coordinates, the playable x/z rectangle, and background/lane/accent colors. Placement must reject points near **any** route, outside the rectangle, or overlapping another tower. The original endless path remains mathematically identical.

## Formation design

Finite maps have explicitly authored rows containing ordered enemy groups, interval, health scaling, speed scaling, completion credits, and no-purchase bonus. Enemy populations rise from 9–12 ships to 25, 35, and 42 respectively. Boss milestones occur at waves 4/8 on Easy, 5/10 on Normal, and 4/8/12 on Hard. The final Normal and Hard waves contain two dreadnoughts.

All maps begin with raiders. Swift ships and armor follow; shields and regeneration each get an introductory formation before dense combinations. Easy introduces shields at wave 5 and regeneration at wave 6; Normal at 4 and 6; Hard at 3 and 4. Hard splits successive spawns between its two approaches. Difficulty increases through formation composition, fewer initial resources, density, and route coverage; final finite hull multipliers are 4.0, 6.65, and 8.12.

The economy retains kill credits, completion credits, and a no-purchase bonus. Buying between waves preserves the following wave's bonus. Finite milestone/completion rewards help pay for tier upgrades. Base tower costs and tier pricing are retained; Relay and Nova now have additional mechanics and paths. A complete specialization costs 3.9 times the tower's base cost in upgrades, making deployed totals 4.9 times base cost (subject to the original integer truncation).

Content validation confirms structural integrity and legacy parity; practical balance additionally requires combat simulations with legal budgets and placement. These definitions are tuned starting values, not a claim that every formation or strategy is equally effective.

## Enemy rules

Base values below precede per-wave scaling. Health, shield capacity, and regeneration scale together. Speed scales separately. Ordinary kill credits add `wave - 1`; dreadnought kill credits add `5 × (wave - 1)`.

| Enemy ID | HP | Speed | Base reward | Core damage | Ability |
| --- | ---: | ---: | ---: | ---: | --- |
| `raider` | 48 | 1.62 | 11 | 1 | None |
| `swift` | 33.6 | 2.673 | 11 | 1 | Fast, fragile |
| `armored` | 100.8 | 1.62 | 11 | 1 | 4 armor |
| `dreadnought` | 336 | 1.134 | 55 | 4 | 6 armor; 35% slow resistance |
| `shielded` | 57.6 | 1.49 | 17 | 2 | 52.8 shield; 10% slow resistance |
| `regenerating` | 79.2 | 1.38 | 19 | 2 | Repairs 3.6 HP/sec; 15% slow resistance |

Shields absorb damage before hull, carry excess damage into the hull, and do not regenerate. Hull armor subtracts its flat value from each hit with a minimum of 1; railguns ignore armor. Continuous hull regeneration stops at maximum HP and cannot resurrect a resolved enemy. Cryogenic slowing lasts two seconds, uses the strongest current slow rather than multiplying repeated applications, and is reduced by the enemy's resistance. Dreadnoughts follow these same rules. Aegis uses `shielded.glb`; Mender uses `regenerator.glb`.

Outer Rim intentionally keeps the original armor-as-extra-health behavior and full slow susceptibility. Its helper suppresses the new flat armor and resistance, preserves health/speed/reward formulas, countdown spawn order, and every-fifth-wave dreadnoughts. A subtle original overlap is retained: countdowns divisible by 20 produce armored hulls moving at swift speed. Apply `spawn_speed_multipliers[spawn_index]` after `enemy_for_wave()` for parity.

## Fleet and upgrades

The original tower ordering is Lancer, Bastion, Nova, Cryostat. Railgun and Relay append to that order. Nova retains independent gun targeting. Its first Pulse Generator tier only unlocks area damage; later tiers add 65% damage and 0.25 range. Neither Long-range guns nor Drone swarm unlocks the pulse. Drone swarm adds 1/2/3 drones across its tiers, retaining the four guns. Each drone has 18 base damage, a 0.7-second firing interval, and 1.4 attack reach; its target must remain within Nova’s effective range.

Railgun costs 300 credits, deals 118 damage every 2.35 seconds at range 8.2, and ignores armor. Its accelerator branch adds 65% damage per tier; its targeting branch adds 1.2 range and 16% damage per tier. Its slow cycle makes it less efficient against large groups of fragile ships.

Relay's stable ID is `support`, with model `relay`. It costs 190 credits and provides +18% damage within 5.6 coverage; it has no attacks or gun assemblies. Power amplification adds 10 percentage points of damage per tier. Targeting network (stable branch ID `relay`) adds 12 points of recipient weapon range and 0.4 coverage per tier. Fire-control network (`fire_control`) adds 12 points of rate of fire per tier. A recipient independently takes the largest in-range bonus for damage, range, and firing frequency. Relays never receive support, preventing loops. Drones use their carrier's already-supported stats and never scan a second aura at their flying position.

Each path has three tiers. Nova and Relay have three exclusive paths; other ships have two. `upgrade_for(tower_id, branch_index, tier)` returns stable IDs, a unique tier name, icon, tactical purpose, prerequisite ID, excluded branch IDs, cost, explanation, and explicit effects. Apply upgrades once in tier order when restoring a save, without charges or reward changes. `fleet_stats.gd` owns these calculations for both previews and combat; future-tier previews apply every missing prerequisite. Frequency bonuses divide cooldown by `1 + bonus`, preserving the fraction of an in-progress cooldown when support or upgrades change.

Target priorities rank by remaining route distance (Closest to Core / Last), remaining hull plus shield (Strongest), distance to the owner (Nearest), or unslowed enemies followed by Closest to Core (Needs slowing). Spawn order resolves ties. Railgun defaults to Strongest, Cryostat to Needs slowing, and other offensive ships to Closest to Core. Nova distributes stable valid locks by default and offers focus fire. Cryostat guns have ±90° local yaw limits and an alignment gate; the hull turns with paired thrusters only when tracking requires it, with a stopping margin to avoid boundary oscillation.

See [phases 1–3 acceptance](PHASES_1_3_ACCEPTANCE.md) for paid-upgrade equivalence, support investment comparisons, and runtime coverage.

## API

- `TOWERS`, `tower_by_id(id)`, `tower_index(id)`: fleet definitions and safe ID/index conversion.
- `maps()`, `map_by_id(id)`: name, description, difficulty, starting credits/core, final wave, paths, gates, bounds, and theme. `starting_core` and `starting_integrity` are equivalent.
- `waves_for(map_id)`: all finite formations; empty for the unbounded endless map.
- `wave_for(map_id, number)`: formation with stable ID, ordered enemy IDs, per-spawn speed multipliers, interval, health/speed scaling, completion `reward`, and no-purchase `bonus`. Invalid IDs or finite wave numbers return an empty dictionary.
- `enemy_by_id(id)`: unscaled enemy stats, model, tint, silhouette scale, and counterplay text.
- `enemy_for_wave(enemy_id, map_id, number)`: fully scaled HP, shield, regeneration, speed, and kill reward, including the Outer Rim compatibility rules. Wave 0 uses wave 1 for existing pre-wave checks.
- `upgrade_for(tower_id, branch_index, tier)`: a complete upgrade or an empty dictionary for invalid content.

Run `Godot --headless --path . --script tests/content_data_test.gd` for map bounds and gates, finite progression, complete upgrades, defensive copies, and exact original stat/order/reward parity over 20 endless waves. Combat, menus, saves, settings, and audio require the integration checks as well.
