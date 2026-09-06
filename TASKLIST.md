# AstraTD Task List

Completed implementation checklist, verified on 2026-09-06. Candidate choices are now resolved in the game and content documentation. See [acceptance evidence](docs/ACCEPTANCE.md) for the checks, selected scope, and measured limits.

Implemented: three finite maps plus the preserved endless map, six fleet roles, six enemy archetypes, manual authored waves, exclusive three-tier upgrades, kill/completion/savings rewards, menus, pause and speed controls, preparation saves, persistent completion, settings, and original audio.

## 1. Game Data and Session Flow

- [x] Define reusable map, wave, enemy, tower, and upgrade data with stable IDs, so new content and saved games do not depend on array positions.
- [x] Separate session state from menu/UI state: main menu, preparation, active wave, paused, victory, and defeat.
- [x] Move map/wave configuration out of the hard-coded setup in `main.gd` without changing existing gameplay behavior.
- [x] Define which information belongs to a saved run, map-completion progress, and global settings.

## 2. Maps and Difficulty

- [x] Choose the initial map lineup and difficulty categories; candidate categories are Easy, Normal, and Hard.
- [x] Define each map's name, description, difficulty, starting credits, core integrity, and final wave number.
- [x] Create multiple distinct winding wormhole layouts with different placement opportunities and chokepoints.
- [x] Store paths, entry/exit gates, and playable boundaries per map rather than using one fixed layout.
- [x] Apply placement validation to every path on the selected map; prevent placement outside the playable area or overlapping another tower.
- [x] Give maps distinct backgrounds and previews while keeping enemies, paths, and placement indicators readable.
- [x] Build a map-selection screen showing difficulty, wave count, starting resources, and completion status.
- [x] Make map loading and restarting clear all previous enemies, towers, effects, and wave state.

## 3. Wave Progression and Map Completion

- [x] Replace the single scaling formula with configurable wave compositions, spawn intervals, and enemy stat scaling.
- [x] Introduce enemy mechanics gradually before mixing them into harder waves.
- [x] Design escalating challenge within each map, including deliberate boss or milestone waves.
- [x] Balance enemy health, speed, count, kill rewards, and completion rewards against available tower upgrades.
- [x] Preview the next wave's enemy types and boss warnings before the player starts it.
- [x] Keep **Next Wave** player-controlled and disabled during combat, pause, victory, and defeat.
- [x] Show current wave versus final wave in the HUD, such as `Wave 7 / 20`.
- [x] Declare victory only after the final wave has finished spawning and all remaining enemies have been resolved while the core survives.
- [x] Prevent further wave starts and duplicate rewards after victory or defeat.
- [x] Add victory and defeat summaries with map, difficulty, waves completed, kills, and remaining core integrity.
- [x] Record completed maps and provide replay and return-to-map-selection actions.

## 4. Main Menu and Navigation

- [x] Add a main menu with **New Game**, **Load Game**, **Settings**, and **Quit**.
- [x] Route **New Game** through map selection and initialize a fresh run using the selected map's data.
- [x] Add **Continue/Resume** and **Save Game** when a run is available; clearly disable unavailable actions.
- [x] Make Save, Load, Settings, and Return to Main Menu accessible from the in-game pause menu.
- [x] Confirm starting a new run, loading another save, or quitting when doing so would discard unsaved progress.
- [x] Support keyboard navigation, visible focus, and consistent Back/Escape behavior across menus.
- [x] Verify HUD and menu layouts at supported window sizes and in fullscreen mode.

## 5. Pause, Resume, and Game Speed

- [x] Add a visible Pause/Resume control and a keyboard shortcut; resolve the current Escape-to-cancel-build behavior before opening the pause menu.
- [x] Freeze enemy movement, spawning, targeting, weapon cooldowns, damage, rewards, and gameplay effects while paused.
- [x] Keep pause-menu navigation and settings usable while the simulation is paused.
- [x] Block purchases, upgrades, salvage, and wave starts while paused unless a deliberate alternative is specified.
- [x] Add labeled speed controls; candidate speeds are 1×, 2×, and 3×.
- [x] Scale simulation timers consistently without speeding up UI interaction or changing music pitch.
- [x] Resume at the previously selected speed and make the active speed/pause state obvious in the HUD.

## 6. Save, Load, and Persistent Progress

- [x] Decide whether the first save implementation supports active-wave saves or only preparation between waves; expose any restriction clearly in the UI.
- [x] Define a versioned save format using stable content IDs and store saves under Godot's `user://` directory.
- [x] Save map ID, wave state, credits, core integrity, kills, tower positions/types, and purchased upgrade branches/tiers, including Nova's pulse unlock.
- [x] **Not applicable by the selected save scope:** active-wave saves are disabled; enemy/status/path/spawn/timer serialization is unnecessary for preparation-only snapshots, which restore next-wave bonus eligibility.
- [x] Rebuild loaded towers, independent gun assemblies, targets, and UI from saved state without charging purchase costs or granting rewards again.
- [x] Add save-slot controls with map, difficulty, wave, and timestamp previews, including overwrite and delete confirmation.
- [x] Handle missing, corrupt, or incompatible saves with a readable error while preserving the current run.
- [x] Write saves atomically and retain a recovery copy so an interrupted write does not destroy the last valid save.
- [x] Persist map completion separately from individual runs and settings.
- [x] Verify save/load round trips preserve balances, upgrade exclusivity, pulse availability, and bonus eligibility.

## 7. Enemy, Fleet, and Upgrade Expansion

- [x] Choose additional enemy archetypes and their counterplay; candidates include shielded ships, regenerating ships, and support/carrier units.
- [x] Give each new enemy explicit health, speed, reward, core damage, abilities, and difficulty/wave introduction rules.
- [x] Make enemy types recognizable through silhouettes, materials, effects, and status indicators.
- [x] Define consistent rules for armor, shields, slowing, and other effects, including stacking and boss interactions.
- [x] Choose additional ship and station roles that add tactical choices; candidates include long-range railguns, drone carriers, and support stations.
- [x] Create complete 3D Blender models, materials, purchase icons, weapon mounts, and matching effects for approved units.
- [x] Give new station weapons independent aiming mounts, while keeping station bodies fixed.
- [x] Expand upgrades with explicit prerequisites, costs, stat changes, weapon unlocks, tier limits, and mutually exclusive choices.
- [x] Replace or extend the two-button upgrade display with a readable tree that shows purchased, available, unaffordable, and locked nodes.
- [x] Show the exact effect and cost of an upgrade before purchase, including a stat comparison where useful.
- [x] Balance new content across map difficulties so multiple fleet compositions remain viable.
- [x] Preserve independent Nova gun targeting and keep its area pulse gated behind the Pulse Generator upgrade.

## 8. Settings

- [x] Add mutually exclusive Fullscreen and Windowed display options.
- [x] Apply display changes immediately and preserve a usable window size when returning to windowed mode.
- [x] Add separate Music and SFX enable/disable toggles.
- [x] Add Master, Music, and SFX volume controls with clearly displayed values.
- [x] Persist settings across restarts and apply them before menu music or gameplay audio starts.
- [x] Provide Restore Defaults and ensure settings are accessible from both the main and pause menus.

## 9. Sound Effects and Music

- [x] Set up separate Master, Music, and SFX audio buses and connect them to settings.
- [x] Add distinct firing sounds for lasers, missiles, pulse weapons, and cryogenic weapons.
- [x] Add sounds for impacts, enemy implosions, thrusters, deployment, upgrades, and salvage.
- [x] Add UI feedback and cues for wave start, wave completion, bonus awarded, core damage, victory, and defeat.
- [x] Create or source sci-fi instrumental tracks for menus and gameplay, with seamless looping and unobtrusive transitions.
- [x] Record asset sources, licenses, and required attribution for all external audio.
- [x] Define pause behavior for music, loops, and one-shot effects; prevent stopped or destroyed units from leaving sounds playing.
- [x] Mix volume levels and limit simultaneous/repeated sounds so large waves do not clip or overwhelm important cues.

## 10. Integration and Acceptance Checks

- [x] Verify the full flow: launch → new game → map selection → waves → victory/defeat → replay or menu.
- [x] Verify pause, speed changes, saving, and loading cannot duplicate kills, credits, bonuses, or wave-completion events.
- [x] Verify each finite map stops at its configured final wave and records completion only on victory.
- [x] Test display modes, window resizing, audio toggles, volume settings, and persistence after restarting.
- [x] Extend the existing Godot checks for map loading, finite-wave completion, pause/speed timing, save/load, and new enemy/upgrade behavior.
- [x] Re-run the existing combat, station-aiming, thruster, Nova-targeting, and Nova-pulse checks when related systems change.
- [x] Check performance at the highest intended wave density, including particles, independent guns, and simultaneous audio.
- [x] Update the README, controls, screenshots, and asset-generation instructions to match the implemented features.
