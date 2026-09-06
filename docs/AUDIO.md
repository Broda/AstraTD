# Original game audio

All audio in `assets/audio/` is synthesized specifically for Wormhole Wardens by `tools/asset_pipeline/generate_audio.py`. It uses mathematical oscillators, envelopes, and deterministically seeded noise, with original note sequences. There are no external recordings, samples, soundfonts, tracks, or compositions. No third-party license or attribution is required; these generated assets belong to the project alongside their generator source.

Regenerate with Python 3: `python tools/asset_pipeline/generate_audio.py`. The script uses only the standard library and produces 22.05 kHz, 16-bit mono WAV files.

| Assets | Purpose |
| --- | --- |
| `music_menu.wav` | 24-second, 80 BPM ambient suspended/minor instrumental |
| `music_game.wav` | 20-second, 96 BPM instrumental with a restrained bass pulse |
| `laser`, `missile`, `pulse`, `cryo`, `rail`, `support` | Distinct weapon/ability cues |
| `impact`, `implode`, `thruster` | Hit, destruction, and brief engine feedback |
| `deploy`, `upgrade`, `salvage`, `ui` | Fleet and menu interaction feedback |
| `wave`, `complete`, `bonus`, `core`, `victory`, `defeat` | State and reward cues |

Music note tails wrap around the buffers; a four-millisecond circular seam treatment makes the endpoint samples continuous. `GameAudio` enables WAV looping at runtime and crossfades menu/game streams over 1.2 seconds. Real elapsed time drives fades and cue throttles, so simulation speed changes do not alter music pitch or UI timing.

`GameSettings` creates Music and SFX buses routed to Master and adds a master limiter with a -0.8 dB ceiling. Settings are applied before any stream starts. Source peaks are bounded; playback further attenuates combat voices to -17 dB, thrusters to -22 dB, important cues to -10 dB, and music to -10 dB before bus levels. The shared pool permits 12 one-shots, with combat limited to 8 to reserve room for wave/core/UI cues. Per-cue throttles suppress repeated events (85 ms combat, 120 ms impact, 420 ms thruster, 250 ms core).

Pausing stops all outstanding SFX and blocks subsequent combat cues. Music continues at normal pitch; pause-menu feedback remains available. Thrusters are short one-shots, so destroyed units cannot leave a persistent engine loop. Disabling SFX immediately stops voices and mutes the bus. Disabling music mutes its bus while preserving playback position. Freeing the audio node stops its child players.

Standalone checks in `tests/storage_test.gd` verify settings-before-playback, bus separation, bounded voices, and pause behavior. Headless checks verify routing and playback state; final perceptual mix assessment requires listening on the intended output device.
