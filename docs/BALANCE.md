# Finite campaign balance evidence

All three finite campaigns were completed by two distinct mixed fleets using normal combat and only their starting and earned credits. The final run used Godot 4.7.2 on 2026-09-06. No enemy, map, economy, or tower balance values were weakened to produce these results.

## Final results

Earned credits exclude the map's starting allocation. Spent credits include normal deployment and upgrade purchases. Remaining credits include the final wave's rewards, which cannot be spent before that wave.

| Map | Fleet strategy | Result | Core | Kills | Earned credits | Spent credits | Remaining credits | Final towers |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Aurora Reach / Easy | Precision | Victory | 25 / 25 | 132 | 3,697 | 3,095 | 1,122 | 5 |
| Aurora Reach / Easy | Combined arms | Victory | 25 / 25 | 132 | 3,697 | 3,146 | 1,071 | 4 |
| Cobalt Bend / Normal | Precision | Victory | 20 / 20 | 219 | 6,146 | 5,240 | 1,366 | 8 |
| Cobalt Bend / Normal | Combined arms | Victory | 20 / 20 | 219 | 6,146 | 5,005 | 1,601 | 6 |
| Twin Rift / Hard | Precision | Victory | 9 / 16 | 313 | 9,333 | 7,798 | 1,955 | 10 |
| Twin Rift / Hard | Combined arms | Victory | 16 / 16 | 319 | 9,453 | 7,732 | 2,141 | 8 |

The six runs simulated about 34 minutes of combat in total. Each campaign reached its actual final wave through manual wave starts; success required the core to survive and every remaining spawn/enemy to resolve normally.

## Reproduce

Run from the project directory with Godot 4.x available as `godot`, or substitute the full path to the Godot console executable:

```powershell
godot --headless --path . --log-file work/balance.log -- --balance-test
```

The default run executes all six campaigns and exits nonzero if any strategy loses. Each wave prints core integrity, kills, credits, and tower count. Final lines print earned/spent credits, purchase count, simulated duration, and the exact fleet order with positions and upgrades. A successful complete run ends with `BALANCE TEST PASSED: 6 campaigns won with earned credits and normal combat`.

Focused reruns support either or both filters:

```powershell
godot --headless --path . -- --balance-test --balance-map=twin_rift
godot --headless --path . -- --balance-test --balance-map=twin_rift --balance-strategy=precision
```

Map IDs are `aurora_reach`, `cobalt_bend`, and `twin_rift`; strategies are `precision` and `combined_arms`. An unmatched filter fails instead of reporting success without running anything. The repository's `tests/run_checks.ps1` includes the complete balance suite alongside the other regressions.

## Method and limits

`tests/balance_test.gd` invokes the actual game's `start_run`, `deploy`, `upgrade`, `start_wave`, and `_process` paths. It never assigns credits, enemy health, damage, or core integrity. Placements come from a deterministic grid, validated through `can_place`; a route-coverage score favors useful firing windows and adds support/slow synergies. Purchased upgrades use the actual branch, tier, and affordability rules.

Purchases occur only during preparation. The harness checks that every purchase charges credits, balances never become negative, the combat purchase flag stays false, and each wave starts through the regular state guard. Simulation runs in 1/30-second steps and yields every 300 steps so queued scene cleanup can occur. A 400-second simulated timeout prevents a stuck wave from being mistaken for completion. Test mode suppresses persistent completion writes and sound cues; audio and performance are covered by their own checks.

These results establish that two deliberate mixed strategies can win each authored campaign with legal budgets. They do not establish that every fleet, upgrade order, placement, or input device performs equally well. The placement heuristic searches many legal positions, so it is more consistent than a first-time player's choices. Performance measurements and perceptual audio review are separate from this balance evidence.

## Fleet approaches

**Precision** opens with a Lancer and Railgun, strengthens the Lancer, adds a Cryostat, and builds a second Lancer. A Bastion then supplies splash damage for increasingly dense formations. Further investment completes damage/slow branches, adds Lancers, and eventually adds Railguns. The final Hard fleet contains five Lancers, three Railguns, one Cryostat, and one Bastion; one Railgun is tier 2 and the other purchased branches are tier 3.

**Combined arms** opens with Nova and Bastion, buys Nova's Pulse Generator, and adds Relay. It develops the first three units before expanding with another Nova and a rapid-launcher Bastion. Additional Novas cover remaining gaps. The final Hard fleet contains five Novas, two Bastions, and one Relay, all at tier 3. Novas use Pulse Generator, Relay uses Power amplification, and the Bastions use one branch each.

Twin Rift's alternating approaches punish an expensive fleet that covers too little of the converging route. Splash coverage helps when ships bunch up, while slow and armor-piercing damage give heavy hulls more time under fire. Invest the income from late waves before launching the final siege; a large unspent reserve cannot defend the core during combat.

Example legal Twin Rift opening positions use world `(x, z)` coordinates with `y = 0`:

| Strategy | Purchase order | Position | Early specialization |
| --- | --- | --- | --- |
| Precision | Lancer | `(5.50, 0.60)` | Overcharged beams |
| Precision | Railgun | `(1.75, 0.60)` | Kinetic accelerator |
| Precision | Cryostat | `(8.00, 3.10)` | Deep freeze |
| Precision | Second Lancer | `(4.25, -0.65)` | Overcharged beams |
| Precision | Bastion | `(4.25, 1.85)` | Heavy warheads |
| Combined arms | Nova | `(5.50, -0.65)` | Pulse Generator |
| Combined arms | Bastion | `(1.75, -0.65)` | Heavy warheads |
| Combined arms | Relay | `(4.25, 1.85)` | Power amplification |

The executable purchase plans in `tests/balance_test.gd` are authoritative for reproducing the complete result; these openings explain the tactical shape rather than prescribing every subsequent purchase.
