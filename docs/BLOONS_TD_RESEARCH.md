# Bloons TD research and AstraTD improvement proposals

Research date: 2026-09-06. Status: proposals for review; gameplay has not been changed by this research.

The highest-value direction is to improve upgrade decisions, support placement, and dependable combat behavior, then build replayability around the existing fleet and maps. The current game already has manual wave starts, exact enemy-count previews, boss warnings, preparation saves, pause, speed controls, authored formations, and distinct enemy defenses. These recommendations build on those systems.

## Scope and evidence

The latest release verified in this research is **Bloons TD 6, PC/mobile version 56.3**. Ninja Kiwi's August 21, 2026 update confirms the release of 56.0 through 56.3 and separately describes console releases. Searches did not establish a newer release; this is the latest confirmed reference, not a claim about every platform. [Ninja Kiwi release status](https://www.reddit.com/r/NinjaKiwiOfficial/comments/1vu1l65/whats_up_at_ninja_kiwi_21st_august_2026/)

Research covered the current v56 updates, recent v53-v54 design changes, official descriptions of the base game and Rogue Legends, and older official notes where they directly explain relevant mechanics. Three parallel investigations covered upgrades/support, modes/progression, and the current AstraTD implementation. This was source research and code inspection, not a first-hand BTD6 play session or an audit of its current screen layout. All AstraTD designs, names, priorities, and example numbers below are recommendations, not BTD6 facts or approved balance values.

Useful source findings:

- **Distinct specialization:** the newest Skywarden has wind, lightning, and ice paths; its mechanics include interactions with frozen targets. [Official v56 notes](https://www.reddit.com/r/btd6/comments/1vfommu/update_bloons_td_6_v560_update_notes/)
- **Planning and control:** v56 adds a placement buff indicator for Sun Avatar, changes Robo Monkey's initial priorities to First and Strong, stabilizes ability order, and preserves ability cooldown percentage on upgrades. [Official v56 notes](https://www.reddit.com/r/btd6/comments/1vfommu/update_bloons_td_6_v560_update_notes/)
- **Reliable aircraft:** v54 adjusts Aircraft Carrier flight and turning to improve consistency alongside balance changes; it also corrects an inappropriate buff interaction involving Etienne's drones. [Official v54 notes](https://www.reddit.com/r/btd6/comments/1sg9k4f/update_bloons_td_6_v540_update_notes/)
- **Readable encounters:** v54 redesigns confusing Lych behavior; v56 adds a boss time-penalty warning. [Official v54 notes](https://www.reddit.com/r/btd6/comments/1sg9k4f/update_bloons_td_6_v540_update_notes/), [official v56 notes](https://www.reddit.com/r/btd6/comments/1vfommu/update_bloons_td_6_v560_update_notes/)
- **Learning and pacing:** v56 includes a Skywarden learning quest, maintains Sandbox, and smooths later Freeplay formations. [Official v56 notes](https://www.reddit.com/r/btd6/comments/1vfommu/update_bloons_td_6_v560_update_notes/)
- **Recovery:** v41 added Retry Last Round to CHIMPS, retaining separate recognition for uninterrupted completion. [Official v41 notes](https://www.reddit.com/r/btd6/comments/1akoc55/update_bloons_td_6_v410_update_notes/)
- **Content reuse:** v53 includes restricted and unusual quests plus a map with attacks from both directions. The base game offers themed multi-map Odysseys and shared challenges. [Official v53 notes](https://www.reddit.com/r/btd6/comments/1r2iecf/bloons_td_6_version_fifty_three_point_oh_update/), [publisher game description](https://store.steampowered.com/app/960090/Bloons_TD_6/)
- **Run variety:** Rogue Legends offers choices involving units, artifacts, and boosts. [Publisher Rogue Legends description](https://store.steampowered.com/app/3377850/Bloons_TD_6_Rogue_Legends/)

Priority meanings: **P0** = first delivery sequence or a requirement accompanying it; **P1** = deepen the core game next; **P2** = expand once the core changes are working. Scope labels S/M/L indicate relative breadth, not time estimates.

## Prioritized improvements

### R01 - Replace the compact upgrade grid with a proper fleet details panel

**P0 | M | Highest immediate usability value**

Current state: the sidebar presents six small A/B tier buttons. Names and effects rely heavily on tooltips. See `scenes/gameplay/main.gd:298`, `scenes/gameplay/main.gd:313`, and `scenes/gameplay/main.gd:824`.

Proposal:

- Give the selected ship a dedicated panel containing its role, targeting, effective stats, buffs, and upgrade choices.
- Give each path a name, icon, short purpose, and three connected tier cards. Show the next purchasable upgrade's effect and price without hovering.
- Distinguish purchased, available, unaffordable, prerequisite-locked, and excluded-by-specialization states using text and shape as well as color.
- Let players inspect a later tier without buying it. State the required investment and path commitment before purchase.
- Keep selling separate from upgrade actions. Provide the same information through keyboard focus and hover.

Success: a player can explain the next upgrade's effect, cost, and lock reason from the panel alone. Test at the smallest supported window size and with keyboard-only selection.

Basis: BTD6's named paths and deliberate mechanical identities support this design direction; the proposed panel arrangement is specific to AstraTD. [Publisher description](https://store.steampowered.com/app/960090/Bloons_TD_6/), [Ninja Kiwi's Desperado design discussion](https://www.reddit.com/r/btd6/comments/1la1b5n/bloons_td_6_v490_update_preview/)

### R02 - Correct upgrade previews and show effective combat statistics

**P0 | M | Fix alongside R01**

Current state: selected damage omits Relay's combat multiplier. Tooltips apply each node's effect to current stats, so purchased tiers can imply another increase and future tiers can omit prerequisites. See `scenes/gameplay/main.gd:816`, `scenes/gameplay/main.gd:829`, and `scenes/gameplay/main.gd:691`.

Proposal: show current -> after purchase values, applying prerequisites in order. Separate base values from support bonuses. Present damage per hit, attacks per second, effective range, target count, armor interaction, slow duration, and drone count when relevant. For Nova, identify gun, pulse, and drone damage separately rather than implying every displayed value is one combined hit.

Use rate-of-fire language consistently: reducing a cooldown by 28% raises firing frequency by about 38.9%, not 28%. A DPS estimate must state its assumptions about uptime, target count, armor, and area damage.

Success: every shown purchase result agrees with actual combat values; purchased cards show achieved effects; previewing tier III includes missing tiers and their combined cost. This is a code-grounded correction, not a claim that BTD6 exposes these exact numeric previews.

### R03 - Give upgrade paths recognizable tactical identities

**P0 | M/L | Shared foundation for Relay and Nova**

Current state: every unit has two exclusive branches with three tiers. Many tiers repeat damage/range multipliers. Nova's paid pulse unlock already demonstrates a more distinct upgrade. See `scripts/data/game_data.gd:161` and `scenes/gameplay/main.gd:445`.

Proposal: retain short three-tier paths initially. Use a progression such as unlock a behavior -> improve that behavior -> specialize it. Support a variable number of named paths so Relay can offer the requested three buff types and Nova can gain a third drone path alongside its existing gun and pulse choices.

State branch exclusivity clearly. Consider limited secondary-path upgrades only as a later balance experiment. Preserve fleet hull scale through all upgrades and save/load; communicate advancement with emitters, weapon details, light patterns, and drones.

Success: each path answers a different tactical problem and retains a weakness. Avoid making every final upgrade simultaneously best against swarms, armor, bosses, and distant targets. [Current Skywarden specialization example](https://www.reddit.com/r/btd6/comments/1vfommu/update_bloons_td_6_v560_update_notes/)

### R04 - Make Relay support-only with damage, range, and rate-of-fire paths

**P0 | L | Explicit existing request**

Current state: Relay fires weak attacks and supplies only a damage aura; one branch also extends its own coverage. It cannot currently improve recipients' range or firing frequency. See `scripts/data/game_data.gd:10`, `scripts/data/game_data.gd:166`, and `scenes/gameplay/main.gd:1230`.

Proposed path themes:

| Path | Benefit to covered fleet | Main tactical use |
| --- | --- | --- |
| Power Amplification | Increased damage | Improve damage from an expensive firing position |
| Targeting Network | Increased weapon range | Reach more of a route and extend engagement time |
| Fire-Control Network | Increased rate of fire | Increase sustained output and control applications |

Remove Relay's attacks. Keep **Relay coverage radius** distinct from **the weapon-range bonus granted to another ship**. Initial recommended stacking rule: strongest bonus of each stat applies; different stat types can combine; Relays cannot amplify themselves or other Relays into a loop.

Success: the UI names the same three effects the user requested, including **damage**. Compare the value of Relay with another offensive ship at two, four, and six supported units. Damage and fire-rate bonuses multiply their theoretical DPS effects: illustrative +20% to each gives +44%, before armor and uptime. Tune from combat evidence rather than adding those percentages together.

### R05 - Show support coverage and define drone buff inheritance

**P0 | M | Required with R04/R06**

Proposal: during Relay placement, outline eligible ships and show an affected count. Preview newly covered ships when changing aura radius. Selected recipients should list active bonus amounts and their sources. Use the same coverage geometry for the ring and simulation.

For drones, determine support eligibility from the Nova carrier's position. Let drones inherit applicable owner damage/fire-rate bonuses once; circling through another aura must not apply them again. A recipient range bonus should extend Nova's engagement boundary, which also controls drone acquisition and recall. Keep any drone-local weapon reach separately defined.

Success: selecting any supported ship explains its actual values; overlapping Relays follow the displayed rule; selling a Relay immediately removes its contribution; drones cannot receive duplicate buffs through owner and independent aura checks.

Basis: recent BTD6 changes specifically address placement support indicators and drone buff eligibility. [Official v56 notes](https://www.reddit.com/r/btd6/comments/1vfommu/update_bloons_td_6_v560_update_notes/), [official v54 notes](https://www.reddit.com/r/btd6/comments/1sg9k4f/update_bloons_td_6_v540_update_notes/)

### R06 - Give Nova a dependable drone swarm upgrade

**P0 | L | Explicit existing request**

Proposal: tier I launches one drone, tier II adds a second, and tier III adds a third. Drones orbit Nova while idle and visibly swarm the enemy they attack. Preserve the current four-gun behavior and make the drone path's relationship to the pulse and gun paths explicit.

Acquire only enemies within Nova's effective engagement range. Reassign or recall drones when a target dies, exits range, or becomes invalid. Stop their attack when the target leaves the permitted boundary. Use distinct orbit positions, stable target locks, and reliable interception so turning animations do not unpredictably erase damage output.

Expose Focus Fire and Distribute behavior if both prove useful. Start with a small fixed drone pool per Nova rather than repeated spawning. Display deployed/available drone count in the details panel.

Success: each tier adds exactly one functional drone; drones visibly swarm valid targets; no out-of-range pursuit or duplicate respawns after loading; performance and damage are predictable against fast enemies and sharp path bends.

Basis: BTD6's recent carrier adjustments emphasize reliable flight/attack behavior as well as power. [Official v54 notes](https://www.reddit.com/r/btd6/comments/1sg9k4f/update_bloons_td_6_v540_update_notes/)

### R07 - Enforce Cryostat's aiming limits with visible satellite rotation

**P0 | M | Explicit existing request**

Current state: Cryostat's body stays stationary while its guns can yaw without the requested limit. See `scenes/gameplay/main.gd:609`, `scenes/gameplay/main.gd:620`, and `scenes/gameplay/main.gd:653`.

Proposal: clamp each mount to +/-90 degrees in its local frame. When a useful target needs more rotation, turn the whole satellite with visible opposing thrusters using Lancer's existing convention. Coordinate body and gun movement smoothly, with a small tolerance around the limit to prevent repeated left-right corrections. Define how two guns choose a shared body heading when their targets differ.

Show the selected mount's firing arc and a tracking/repositioning state. Fire only when the gun is legally aligned.

Success: no rearward shot bypasses the limit; the body visibly rotates when needed; targets near the boundary do not cause oscillation. This is an AstraTD-specific requirement, not a mechanic attributed to BTD6.

### R08 - Add targeting priorities with useful defaults

**P1 | M | Deliver with the selected-unit panel where practical**

Current state: ordinary targeting uses greatest traveled route distance; Nova preserves independent locks. Current Twin Rift routes are mirrored, so this research does not establish a current unequal-route ordering bug. See `scenes/gameplay/main.gd:587` and `scenes/gameplay/main.gd:632`.

Proposal: offer Closest to Core, Strongest, Nearest, and Last where meaningful. Use remaining route distance for Closest to Core so future asymmetric routes behave consistently. Define Strongest visibly, for example highest remaining hull plus shields; keep armor priority a separate explicit option if introduced.

Suggested defaults: Railgun prefers heavy/armored targets; Cryostat favors useful slowing coverage; Nova distributes targets, with optional focus fire. Preserve stable locks unless a meaningful priority change warrants switching. Save player choices.

Success: the selected target and current priority are clear, and ordinary success does not require continual retargeting. [Current BTD6 targeting changes](https://www.reddit.com/r/btd6/comments/1vfommu/update_bloons_td_6_v560_update_notes/)

### R09 - Make enemy defenses and debuffs visible in combat

**P1 | M**

Current state: the enemy bar width tracks hull while its color changes for shields; it can remain full as shielding depletes. Armor, regeneration, and slowing have limited active-state communication. See `scenes/gameplay/main.gd:576`.

Proposal: use separate shield and hull indicators, plus compact icons for armor, slowing, regeneration, and resistance. Show slow duration on selection, a clear shield-break event, and a readable repair pulse. Pair color with shapes or labels. Put enemy counterplay text already present in the data into a small inspectable reference panel.

Success: players can tell whether shots are removing shield or hull and why a slow or small hit has reduced effect. This adapts the readable-counterplay lesson from recent boss changes to existing enemies. [Lych clarity rework](https://www.reddit.com/r/btd6/comments/1sg9k4f/update_bloons_td_6_v540_update_notes/)

### R10 - Enrich the existing wave forecast and explain purchase tradeoffs

**P1 | M**

Current state: exact enemy counts, boss warnings, completion rewards, and no-purchase bonuses already exist. See `scenes/gameplay/main.gd:1219`.

Proposal: add enemy portraits, defense symbols, entry-lane markers, and a compact ordered formation preview. Introduce an enemy's counter before its first appearance. Highlight which routes a selected ship can cover. Present the no-purchase bonus as a clear preparation-versus-emergency-spending choice; show the bonus that a combat purchase would forfeit.

Success: players can identify the next wave's unusual threat, entry lanes, expected rewards, and economic tradeoff before starting. Keep manual wave starts and pause as the default planning tools.

### R11 - Add a few explicit fleet combinations while preserving roles

**P1 | M/L | After baseline Relay/drone balance**

Proposal: develop a small number of understandable combinations, such as a Cryostat specialization that applies a capped brittle debuff for allied heavy hits, or a Nova drone specialization that marks its current target. Present the combo condition and duration in both upgrade and enemy details.

Preserve roles: Railgun handles armored/heavy targets but has a slow cycle; Bastion favors groups; Cryostat creates firing time; Relay rewards coverage; drones provide sustained engagement. Every new combo needs a cap or strongest-effect rule and a useful alternative fleet composition.

Success: at least two materially different affordable fleet plans can answer each standard mission, and no particular support pair becomes compulsory. [Skywarden's explicit interactions with frozen targets](https://www.reddit.com/r/btd6/comments/1vfommu/update_bloons_td_6_v560_update_notes/)

### R12 - Add fleet contribution and an after-action report

**P1 | L | Enables useful balance and player learning**

Proposal: track hull/shield damage, kills, firing uptime, escaped enemy types, spending, and unspent credits. Report Cryostat slow uptime and Relay recipients/bonus damage. Separate Nova gun, pulse, and drone contributions when inspecting it.

Credit only the measured incremental damage to support, and label estimates explicitly. Extra attacks caused by rate buffs and extra time in range are more difficult to attribute than per-hit damage; avoid claiming exact counterfactual contribution without a defensible method.

Success: the end-wave report can explain a loss using recorded facts and can compare a support investment with an extra weapon. Extend current run-wide tracking without creating a wall of mandatory statistics. See `scenes/gameplay/main.gd:747`, `scenes/ui/game_menu.gd:229`, and `docs/BALANCE.md`.

### R13 - Add Retry Wave using the preparation checkpoint

**P1 | M**

Proposal: capture the exact fleet, resources, core, and relevant run state immediately before a wave starts. On defeat, allow the player to restore that preparation state, adjust the fleet, and try again. Restore rewards and purchases consistently so retry cannot duplicate credits. Keep a separate optional uninterrupted-clear distinction.

Success: retry reproduces the same formation and budget while allowing a different tactical response. Build on existing preparation saves rather than requiring active-combat serialization.

Basis: BTD6 added a last-round retry specifically to make a difficult learning loop more approachable. [Official v41 notes](https://www.reddit.com/r/btd6/comments/1akoc55/update_bloons_td_6_v410_update_notes/)

### R14 - Build a fleet test range

**P1 | L | Strong partner for R12**

Proposal: offer map selection, enemy type/count/spacing, a fixed seed, free or constrained credits, pause/speed controls, and instant reset. Allow copying a preparation fleet into the test range. Show measured damage and support effects so players can compare paths against armor, shields, and swarms.

Keep campaign rewards and mastery records separate from experiments. A small preset-based first release is enough; a full wave editor can follow.

Success: a player can answer whether another drone, range upgrade, or Relay improves a specific situation without replaying a campaign. BTD6 Sandbox is the inspiration; copying the fleet and these exact controls are AstraTD proposals. [Current Sandbox maintenance](https://www.reddit.com/r/btd6/comments/1vfommu/update_bloons_td_6_v560_update_notes/)

### R15 - Teach fleet roles through optional short trials

**P1 | M | Reuse test-range infrastructure**

Proposal: create two-to-four-minute missions for armor penetration, slowing a rush, overlapping Relay coverage, Nova drone behavior, and Cryostat rotation. Temporarily provide the relevant upgrades and explain one mechanic at a time. End with a concise explanation of the successful interaction.

Success: players can learn a newly introduced role through a short playable situation with immediate feedback. Make trials replayable without locking existing basic fleet access behind them. [Current Skywarden learning quest](https://www.reddit.com/r/btd6/comments/1vfommu/update_bloons_td_6_v560_update_notes/)

### R16 - Introduce one boss with an understandable signature mechanic

**P1 | L**

Proposal: evolve one dreadnought encounter into a flagship with an escort-generated shield. Telegraph escort arrival, show which enemies supply shielding, and explicitly state that destroying escorts exposes the flagship. Use visible health thresholds to change the encounter's demand.

Teach the rule before combining it with heavy armor, regeneration, or severe slow resistance. Let the player practice after discovering it.

Success: after one attempt, the player can explain why the boss was protected and what action would expose it. [Recent Lych rework and boss warnings](https://www.reddit.com/r/btd6/comments/1sg9k4f/update_bloons_td_6_v540_update_notes/)

### R17 - Reuse existing maps through curated challenge presets

**P2 | M**

Proposal: initially build a few presets from limited credits, maximum fleet count, no selling, one offensive role plus Relay, accelerated enemies, and shield-heavy formations. State rules and victory conditions before launch. Make difficulty rules independent of map selection so a familiar sector can support several challenges.

Success: each preset rewards a different build or placement decision; it remains solvable under its stated budget. Avoid a support-only challenge after Relay becomes the only pure support ship unless the scenario provides another explicit damage source.

Basis: BTD6 quests and shared challenges demonstrate how constraints reuse existing systems. [Official v53 notes](https://www.reddit.com/r/btd6/comments/1r2iecf/bloons_td_6_version_fifty_three_point_oh_update/), [publisher description](https://store.steampowered.com/app/960090/Bloons_TD_6/)

### R18 - Add map mastery and cosmetic recognition

**P2 | S/M | After retry/challenge rules settle**

Proposal: retain a normal completion badge and add optional feats for no core damage, no retries, spending below a target, or a limited fleet. Show eligibility before a mission. Record best endless wave and challenge results locally. Reward call signs, insignia, hull accents, or UI badges while preserving model scale.

Success: players have clear reasons to replay a map, and normal difficulty remains interpretable without account-wide combat bonuses. This adapts BTD6 completion distinctions and cosmetic rewards to the current local game. [Official v41 notes](https://www.reddit.com/r/btd6/comments/1akoc55/update_bloons_td_6_v410_update_notes/), [publisher description](https://store.steampowered.com/app/960090/Bloons_TD_6/)

### R19 - Differentiate sectors through placement and engagement geometry

**P2 | L**

Proposal: build on Aurora's overlap, Cobalt's alternating turns, and Twin Rift's split approaches. Future sectors can introduce repeated passes through one firing zone, asymmetric routes, or separated windows that reward range and satellite turning. Animate route previews during preparation.

Consider a later interactive obstruction only if its cost, visibility, and effect on firing are clearly shown. Line of sight would be a substantial new rule, so introduce it through a dedicated map/trial.

Success: strong placements meaningfully differ between sectors; current mirrored Twin Rift routes are not misrepresented as already asymmetric. [BTD6's two-direction Party Parade and interactive Mushroom Grotto](https://www.reddit.com/r/btd6/comments/1r2iecf/bloons_td_6_version_fifty_three_point_oh_update/), [official v54 notes](https://www.reddit.com/r/btd6/comments/1sg9k4f/update_bloons_td_6_v540_update_notes/)

### R20 - Balance waves around threat patterns and smooth endless growth

**P1 | M/L | Repeat after major combat changes**

Proposal: retain authored introductions, then alternate swarms, spaced armor, fast leaks, and shield escorts. Combine learned counters at milestones. In endless, use a controlled threat budget and periodic elite encounters; measure transitions instead of raising health, speed, count, and resistance sharply at once.

The original endless mode intentionally differs from finite campaigns in armor and slow rules. Keep it clearly labeled as a legacy ruleset or introduce a separately versioned modern endless mode; do not silently invalidate existing saves or results.

Success: several affordable strategies remain viable, spikes are signaled, and expanded enemy counts stay within measured budgets. Current automated wins establish a useful baseline, not proof of broad strategic diversity. [BTD6's recent Freeplay smoothing](https://www.reddit.com/r/btd6/comments/1vfommu/update_bloons_td_6_v560_update_notes/)

### R21 - Add only a small number of meaningful active commands

**P2 | L | Optional after automatic systems feel good**

Proposal: if active abilities improve play, start with one or two distinct commands such as temporary Relay overcharge or a short drone surge. Keep ordinary auras and drone deployment automatic. Use stable action slots, keyboard shortcuts, clear duration/cooldown indicators, and cooldown-percentage preservation on upgrades and saves.

Success: commands reward timing at a dangerous moment without demanding repeated button presses for normal campaign viability. BTD6's recent fixes to ability ordering and controls are useful design constraints. [Official v56 notes](https://www.reddit.com/r/btd6/comments/1vfommu/update_bloons_td_6_v560_update_notes/), [official v56.2 notes](https://www.reddit.com/r/btd6/comments/1vs5ws0/update_bloons_td_6_v562_update_notes/)

### R22 - Prototype a short multi-sector expedition

**P2 | L | Expansion after standard missions and challenges**

Proposal: connect three missions with a shared fleet allowance and one between-sector choice. Example run-limited options: reduced construction cost, wider Relay coverage, or improved salvage. Begin with fixed choices and explicit tradeoffs; add branching routes only if the short operation is enjoyable.

Success: a complete operation offers a coherent series of decisions in a manageable session, without requiring a large permanent progression system. [BTD6 Odysseys](https://store.steampowered.com/app/960090/Bloons_TD_6/), [Rogue Legends choices](https://store.steampowered.com/app/3377850/Bloons_TD_6_Rogue_Legends/)

### R23 - Make custom challenges shareable through local definitions

**P2 | M/L | After curated challenges**

Proposal: export/import versioned challenge files containing map, budget, allowed ships, upgrade caps, formations, seed, and victory conditions. Record the balance version with scores. Use validated data fields with bounded counts.

Success: another player can reproduce a challenge without hosted infrastructure. A community browser, co-op, clans, and seasonal events can be considered later when the core game has enough depth and there is a reason to operate those services. [BTD6 Content Browser inspiration](https://store.steampowered.com/app/960090/Bloons_TD_6/)

### R24 - Preserve performance and visual readability as fleets become richer

**P0 | M | Accompanies drones, buffs, and effects**

Proposal: add drone-heavy, multiple-Relay, and long-session workloads to existing performance checks. Bound active drones and transient effects. Provide reduced effect intensity while retaining targeting, shields, status icons, and aiming arcs. Preserve hull scale at every tier.

Success: swarm motion remains legible at the maximum supported fleet size and simulation speed. Recheck rendered performance on the existing reference machine and a lower-spec target before claiming broader hardware support. Current measurements cover a bounded 30-tower/42-enemy scenario on one laptop, not all future endless cases. See `docs/PERFORMANCE.md`.

## Suggested delivery sequence

| Slice | Recommendations | Reviewable result |
| --- | --- | --- |
| 1. Upgrade decisions | R01-R03 | Accurate named paths, explicit lock states, expandable tree data, effective stats |
| 2. Support fleet | R04-R05 | Pure support Relay with the requested three buff themes and visible recipients |
| 3. Fleet behavior | R06-R08, R24 | Nova drones, constrained Cryostat aiming, targeting controls, bounded effects |
| 4. Combat understanding | R09-R10, R12-R15 | Readable defenses/forecasts, evidence after failure, retry, test range, short trials |
| 5. Tactical depth | R11, R16, R20 | Deliberate synergies, one readable boss, rebalance across several fleet plans |
| 6. Replay and expansion | R17-R19, R21-R23 | Challenge presets, mastery, distinct sectors, optional commands/expeditions/sharing |

Each slice may need several focused commits. UI previews and buff calculations should share the same underlying stat model. New paths and targeting need stable saved IDs and migration coverage. The first five outstanding implementation requests are already represented in the task list; this report supplies proposals and acceptance criteria without treating all later ideas as approved work.

Research validation: cross-checked official source pages and the current content/UI/combat/persistence documentation. No gameplay tests were run for this documentation-only change.
