extends SceneTree

const Storage = preload("res://run_storage.gd")
const Settings = preload("res://game_settings.gd")
const Audio = preload("res://game_audio.gd")
var failures := 0

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func write_text(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func run() -> void:
	var original_root: String = Storage.storage_root
	Storage.storage_root = "user://wardens_test_%d" % OS.get_process_id()
	var snapshot := {"map_id": "serpent_reach", "map_name": "Serpent Reach", "difficulty": "Easy", "wave": 3, "credits": 765, "integrity": 17, "kills": 42, "spent": false, "speed": 3, "towers": [{"type_id": "nova", "position": [3.25, 0.0, -2.75], "branch": 0, "tier": 1}, {"type_id": "lancer", "position": [-4.0, 0.0, 3.0], "branch": 1, "tier": 3}]}
	check(not Storage.load_slot(1).ok, "Missing save should return a readable error.")
	check(not Storage.save_slot(0, snapshot).ok, "Slot IDs must be bounded.")
	check(Storage.save_slot(1, snapshot).ok, "Initial save should succeed.")
	var loaded := Storage.load_slot(1)
	check(loaded.ok and loaded.data.credits == 765 and loaded.data.kills == 42, "Economy and kills must round trip exactly.")
	check(loaded.data.towers[0].branch == 0 and loaded.data.towers[0].tier == 1, "Nova pulse unlock must retain its purchased branch and tier.")
	check(loaded.data.towers[1].branch == 1 and loaded.data.towers[1].tier == 3 and not loaded.data.spent, "Exclusive branch and next-wave bonus eligibility must survive a round trip.")
	check(loaded.data.towers[0].position == [3.25, 0.0, -2.75] and loaded.data.speed == 3, "Positions and selected speed must round trip.")
	var bad := snapshot.duplicate(true)
	bad.towers[0].tier = 0
	check(not Storage.save_slot(1, bad).ok, "An upgrade branch without its prerequisite tier must be rejected.")
	bad = snapshot.duplicate(true)
	bad.spent = true
	check(not Storage.save_slot(1, bad).ok, "Combat purchase flags must not enter preparation-only saves.")
	bad = snapshot.duplicate(true)
	bad.credits = -1
	check(not Storage.save_slot(1, bad).ok and Storage.load_slot(1).data.credits == 765, "Invalid saves must preserve the last valid balance.")
	bad = snapshot.duplicate(true)
	bad.towers[0].position[0] = INF
	check(not Storage.save_slot(1, bad).ok, "Non-finite positions must be rejected.")
	snapshot.credits = 1000
	check(Storage.save_slot(1, snapshot).ok, "Atomic overwrite should succeed.")
	var slot_path: String = Storage.storage_root.path_join("slot_1.json")
	write_text(slot_path, "{interrupted")
	loaded = Storage.load_slot(1)
	check(loaded.ok and loaded.recovered and loaded.data.credits == 765, "A corrupt primary must recover the previous valid snapshot.")
	check(Storage.save_slot(1, snapshot).ok, "Saving after recovery should repair the primary.")
	write_text(slot_path, "corrupt again")
	check(Storage.load_slot(1).data.credits == 765, "Repair must never replace a healthy backup with corrupt data.")
	var list := Storage.list_slots()
	check(list.size() == 3 and list[0].exists and list[0].recovered and list[0].wave == 3 and not list[1].exists, "Slot previews must distinguish missing and recovered data.")
	write_text(Storage.storage_root.path_join("slot_2.json"), JSON.stringify({"version": 999, "kind": "run", "timestamp": "test", "data": snapshot}))
	check(not Storage.load_slot(2).ok and "incompatible" in Storage.load_slot(2).error, "Future versions must show an incompatible-save error.")
	check(Storage.record_completion("serpent_reach", {"waves_completed": 12, "kills": 90, "integrity": 7}).ok, "Completion progress must save independently.")
	check(Storage.load_progress().serpent_reach.wins == 1, "Completion should be recorded once per supplied victory.")
	var settings := Settings.defaults()
	settings.music_enabled = false
	settings.sfx_volume = 0.25
	settings.window_size = [1280, 800]
	check(Settings.save_settings(settings).ok, "Settings should persist.")
	var restored := Settings.load_settings()
	check(not restored.music_enabled and restored.sfx_volume == 0.25 and int(restored.window_size[0]) == 1280 and int(restored.window_size[1]) == 800, "Display, toggles, and independent volumes must survive restart loading.")
	Settings.apply(restored)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music must be muted before playback.")
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))), 0.25), "SFX volume must apply to its own bus.")
	bad = settings.duplicate(true)
	bad.master_volume = 4.0
	check(not Settings.save_settings(bad).ok, "Out-of-range settings must be rejected.")
	check(Settings.save_settings(Settings.defaults()).ok and Settings.load_settings().music_enabled, "Restore defaults must persist.")
	var audio := Audio.new()
	root.add_child(audio)
	audio.setup(restored)
	audio.set_music("menu")
	check(audio.music_players[0].playing and AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Fresh settings must apply before menu music.")
	for id in Audio.GAMEPLAY_CUES:
		audio.cue(id)
	var active := 0
	for voice in audio.voices:
		if voice.playing: active += 1
	check(active <= Audio.COMBAT_VOICE_LIMIT, "Large waves must not exceed the combat voice budget.")
	audio.set_paused(true)
	for voice in audio.voices:
		check(not voice.playing, "Pause must stop existing one-shot effects.")
	audio.cue("laser")
	check(not audio.voices[0].playing and audio.music_players[0].playing, "Pause must block new combat cues while music continues.")
	audio.cue("ui")
	check(audio.voices[0].playing, "Pause-menu feedback must remain available.")
	audio.free()
	await create_timer(0.25).timeout
	check(Storage.delete_slot(1).ok and not Storage.load_slot(1).ok, "Deleting a slot must also remove its recovery copy.")
	check(Storage.load_progress().has("serpent_reach") and Settings.load_settings().music_enabled, "Deleting a run must preserve global progress and settings.")
	# Clean up only the isolated test directory created in this process.
	var directory := DirAccess.open(Storage.storage_root)
	for filename in directory.get_files():
		directory.remove(filename)
	DirAccess.remove_absolute(Storage.storage_root)
	Storage.storage_root = original_root
	if failures == 0:
		print("STORAGE/SETTINGS/AUDIO TEST PASSED: atomic recovery, schema rejection, economy and upgrades, isolated progress, settings persistence, buses, voice budget, pause audio")
	quit(0 if failures == 0 else 1)
