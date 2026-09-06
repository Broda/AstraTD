# Persistence format

Runs can be saved only during preparation between waves. A run snapshot describes the completed wave, the fleet available for the next wave, and `spent: false`; no enemies, live targets, cooldowns, or effects are serialized. The gameplay layer must reject saves during combat and validate content IDs, map limits, and placements before replacing a current run.

`RunStorage` stores three numbered slots (1–3) in `user://wardens/slot_N.json`. Each JSON envelope contains `version: 1`, `kind: "run"`, a UTC ISO timestamp, and `data`. The data contains:

| Field | Meaning |
| --- | --- |
| `map_id` | Stable map content ID |
| `map_name`, `difficulty` | Optional human-readable slot preview metadata |
| `wave` | Number of the last completed wave; zero before the first wave |
| `credits`, `integrity`, `kills` | Exact economy and surviving core state |
| `spent` | Always false: next wave starts eligible for the no-purchase bonus |
| `speed` | Selected simulation multiplier: 1, 2, or 3 |
| `towers` | `{type_id, position: [x,y,z], branch_id, branch, tier, targeting, aim_mode}` records |

The stable `branch_id` selects the current content branch during reconstruction, so stale numeric ordering does not change the restored upgrade. `branch` is retained as validated legacy metadata: `-1` requires tier `0`; an index valid for the tower’s path count requires tiers `1` through `3` (including index `2` for Nova and Relay). Unupgraded towers use an empty `branch_id`. Optional `targeting` accepts `first`, `last`, `strongest`, `nearest`, or `unslowed`; `aim_mode` accepts `focus` or `distribute`. Older version-1 records omit these fields and use role defaults. The targeting controls expose Needs slowing only for Cryostat and focus/distribute only for Nova. These additive fields retain version-1 compatibility.

The Nova pulse and 1/2/3 drones are reconstructed from its stable branch ID and purchased tier, avoiding a separate boolean that could contradict upgrade ownership. Derived damage, range, investment, gun assemblies, and targets are reconstructed by gameplay without purchase charges or rewards. IDs are lowercase letters, digits, underscores, or hyphens, up to 80 characters. The storage layer rejects invalid numeric ranges, fractional counters, non-finite coordinates, inconsistent branches, oversized files/fleets, and incompatible versions.

Writes go to a sibling `.tmp`, are flushed, closed, and parsed again. A valid current file is copied to `.bak.tmp` and renamed to `.bak`; the verified new file is then renamed over the primary. Load checks the primary and falls back to a valid `.bak`, reporting recovery. A corrupt primary cannot overwrite a healthy backup. Failure leaves the in-memory run untouched. The first successful write has no preceding snapshot to retain. Rename atomicity and durability ultimately depend on the host filesystem; this is an interrupted-write recovery scheme, not a transactional database.

`progress.json` (`kind: "progress"`) stores a dictionary keyed by stable map ID with the latest victory summary, UTC timestamp, and win count. Gameplay calls `record_completion` once on entering victory. This file is independent of saves and settings. Only a victory records completion.

`settings.json` (`kind: "settings"`) stores fullscreen preference, the remembered window size, independent music/SFX toggles, `effects_intensity` (`normal` or `reduced`), and master/music/SFX volumes in `[0,1]`. Older settings without effect intensity use normal effects. Missing or invalid settings use defaults, with a valid backup preferred when available. Settings are applied before audio starts. Window resizing is clamped to the usable display; headless execution skips display calls.

Run standalone regression checks with Godot: `--headless --path . --script tests/storage_test.gd`. The test writes only to a unique `user://wardens_test_PROCESS_ID` directory and removes its fixtures.
