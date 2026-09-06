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

The economy retains kill credits, completion credits, and a no-purchase bonus. Buying between waves preserves the following wave's bonus. Finite milestone/completion rewards help pay for tier upgrades. Existing tower costs and upgrades are unchanged. A complete specialization costs 3.9 times the tower's base cost in upgrades, making deployed totals 4.9 times base cost (subject to the original integer truncation).

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

The original tower ordering is Lancer, Bastion, Nova, Cryostat. Railgun and Relay append to that order. Nova retains independent gun targeting. Its first Pulse Generator tier only unlocks area damage; later tiers add 65% damage and 0.25 range. The other Nova branch never unlocks the pulse.

Railgun costs 300 credits, deals 118 damage every 2.35 seconds at range 8.2, and ignores armor. Its accelerator branch adds 65% damage per tier; its targeting branch adds 1.2 range and 16% damage per tier. Its slow cycle makes it less efficient against large groups of fragile ships.

Relay's stable ID is `support`, with the model `relay`. It costs 190 credits, has two independently aiming mounts sharing one weak 7-damage hit at a 1.1-second cooldown, and provides an 18% damage aura within 5.6 range. The strongest nearby Relay aura applies to other units; multiple auras never add or multiply. Power amplification adds 10 percentage points per tier. Extended relay adds 1.2 range and 4 percentage points per tier. The aura trades another direct weapon for stronger nearby investment.

Every tower has two exclusive branches and three tiers. `upgrade_for(tower_id, branch_index, tier)` returns a stable ID, stable branch ID, prerequisite upgrade ID, excluded branch ID, cost, explanation, and explicit additive/multiplicative effects. All effect keys are present with neutral defaults. Apply upgrades once in tier order when reconstructing a saved tower, without charging credits or changing bonus eligibility.

## API

- `TOWERS`, `tower_by_id(id)`, `tower_index(id)`: fleet definitions and safe ID/index conversion.
- `maps()`, `map_by_id(id)`: name, description, difficulty, starting credits/core, final wave, paths, gates, bounds, and theme. `starting_core` and `starting_integrity` are equivalent.
- `waves_for(map_id)`: all finite formations; empty for the unbounded endless map.
- `wave_for(map_id, number)`: formation with stable ID, ordered enemy IDs, per-spawn speed multipliers, interval, health/speed scaling, completion `reward`, and no-purchase `bonus`. Invalid IDs or finite wave numbers return an empty dictionary.
- `enemy_by_id(id)`: unscaled enemy stats, model, tint, silhouette scale, and counterplay text.
- `enemy_for_wave(enemy_id, map_id, number)`: fully scaled HP, shield, regeneration, speed, and kill reward, including the Outer Rim compatibility rules. Wave 0 uses wave 1 for existing pre-wave checks.
- `upgrade_for(tower_id, branch_index, tier)`: a complete upgrade or an empty dictionary for invalid content.

Run `Godot --headless --path . --script tests/content_data_test.gd` for map bounds and gates, finite progression, complete upgrades, defensive copies, and exact original stat/order/reward parity over 20 endless waves. Combat, menus, saves, settings, and audio require the integration checks as well.
