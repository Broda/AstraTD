# AstraTD Task List

## Outstanding

- [ ] Substantially improve the upgrade UI, taking inspiration from Bloons TD's upgrade presentation and interaction patterns.
- [ ] Add a Nova drone-launch upgrade. Drones swarm around the enemies they are attacking within Nova's range; each additional upgrade tier adds another drone.
- [ ] Limit Cryostat gun rotation to ±90° relative to its mounts. When aiming requires more rotation, turn the whole satellite using thrusters like the Lancer.
- [ ] Make Relay a support-only station: remove its offensive attacks and have it improve only fleet units within its range.
- [ ] Redesign Relay upgrade trees to improve nearby fleet units with increased damage speed, increased range, and increased rate of fire. Clarify what “damage speed” means and how it differs from rate of fire before implementation.
- [ ] Research Bloons TD for gameplay ideas and improvements applicable to this game, and turn the findings into prioritized proposals.

## Completed

- **2026-09-06 — Game expansion:** finite maps, expanded fleets and enemies, upgrades, menus, pause and speed controls, preparation saves, persistent progress, settings, and audio. See the [acceptance report](docs/ACCEPTANCE.md) for scope and verification, and the [README](README.md) for current features and controls.
- **2026-09-06 — Upgrade model size:** fleet models retain their original size when upgraded or restored from saves. Integration, station, and Nova pulse checks passed.
