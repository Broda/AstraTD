extends SceneTree
## Three independent rendered processes verify persisted display/audio settings.
## Run --script tests/display_test.gd -- --display-phase=write, then read, then windowed.

const Storage = preload("res://scripts/services/run_storage.gd")
const Settings = preload("res://scripts/services/game_settings.gd")
const TEST_ROOT = "user://display_acceptance"
const REQUESTED_SIZE = Vector2i(1280, 800)

var checks = 0
var failures: Array[String] = []
var runtime: Node


func _initialize() -> void:
	run.call_deferred()


func expect(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("DISPLAY: " + message)
	return condition


func receipt_path() -> String:
	return TEST_ROOT.path_join("phase_receipt.json")


func read_receipt() -> Dictionary:
	if not expect(FileAccess.file_exists(receipt_path()), "The preceding process must leave its phase receipt"):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(receipt_path()))
	if not expect(parsed is Dictionary, "The preceding phase receipt must be valid JSON"):
		return {}
	return parsed


func save_receipt(receipt: Dictionary):
	var file = FileAccess.open(receipt_path(), FileAccess.WRITE)
	if expect(file != null, "The isolated phase receipt must be writable"):
		file.store_string(JSON.stringify(receipt))
		file.close()


func check_audio(values: Dictionary):
	for pair in [["Master", "master_volume"], ["Music", "music_volume"], ["SFX", "sfx_volume"]]:
		var index = AudioServer.get_bus_index(pair[0])
		if expect(index >= 0, "The settings application must create the " + pair[0] + " audio bus"):
			expect(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(index)), values[pair[1]]), "The " + pair[0] + " volume must match the persisted value")
	expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) == not values.music_enabled, "The actual Music bus mute must match the persisted toggle")
	expect(AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")) == not values.sfx_enabled, "The actual SFX bus mute must match the persisted toggle")


func settings_match(actual: Dictionary, expected: Dictionary) -> bool:
	for key in ["fullscreen", "music_enabled", "sfx_enabled"]:
		if actual.get(key) != expected[key]:
			return false
	for key in ["master_volume", "music_volume", "sfx_volume"]:
		if not is_equal_approx(float(actual.get(key, -1)), float(expected[key])):
			return false
	var size = actual.get("window_size", [])
	return size.size() == 2 and int(size[0]) == int(expected.window_size[0]) and int(size[1]) == int(expected.window_size[1])


func custom_settings() -> Dictionary:
	var values = Settings.defaults()
	values.window_size = [REQUESTED_SIZE.x, REQUESTED_SIZE.y]
	values.music_enabled = false
	values.sfx_enabled = false
	values.master_volume = .37
	values.music_volume = .23
	values.sfx_volume = .64
	values.fullscreen = true
	return values


func check_usable_window(size: Vector2i):
	var usable = DisplayServer.screen_get_usable_rect()
	var expected = Vector2i(mini(size.x, usable.size.x), mini(size.y, usable.size.y))
	expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED, "The actual window must be in Windowed mode")
	expect(DisplayServer.window_get_size() == expected, "Windowed mode must restore the saved usable size")
	var position = DisplayServer.window_get_position()
	expect(position.x >= usable.position.x and position.y >= usable.position.y, "Restored window must begin inside the usable desktop")
	expect(position.x + expected.x <= usable.end.x and position.y + expected.y <= usable.end.y, "Restored window content must fit inside the usable desktop")


func write_phase():
	var values = custom_settings()
	if not expect(Settings.save_settings(values).ok, "The first process must persist its custom settings"):
		return
	Settings.apply(values)
	await create_timer(.15).timeout
	expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Fullscreen must apply to the actual rendered window immediately")
	expect(settings_match(Settings.load_settings(), values), "All custom settings must persist without changing the saved window size")
	check_audio(values)
	save_receipt({"write_process": OS.get_process_id(), "phase": "write"})


func start_production_runtime(expected: Dictionary):
	runtime = load("res://scenes/gameplay/main.tscn").instantiate()
	root.add_child(runtime)
	await create_timer(.2).timeout
	expect(not runtime.testing, "Display phase arguments must exercise the production startup path")
	expect(settings_match(runtime.settings, expected), "Production main._ready must load the preceding process's saved settings")
	check_audio(expected)
	expect(runtime.audio.music_context == "menu" and runtime.audio.music_players[0].playing, "Production startup must start menu music with the persisted bus mute already applied")


func read_phase():
	var receipt = read_receipt()
	if receipt.is_empty():
		return
	expect(receipt.get("phase") == "write", "Read phase must follow the completed write phase")
	expect(int(receipt.get("write_process", 0)) != OS.get_process_id(), "Read verification must occur in a new operating-system process")
	var document = Storage.read_document(TEST_ROOT.path_join("settings.json"), "settings")
	if not expect(document.ok, "The new process must read the preceding process's saved settings"):
		return
	var values = Settings.load_settings()
	expect(settings_match(values, custom_settings()), "A new process must retain display mode, window size, audio toggles, and all three volumes")
	await start_production_runtime(values)
	expect(DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN, "Production startup in a fresh process must apply persisted Fullscreen mode")
	values.fullscreen = false
	runtime.settings = values.duplicate(true)
	Settings.apply(runtime.settings)
	await create_timer(.15).timeout
	check_usable_window(REQUESTED_SIZE)
	expect(int(values.window_size[0]) == 1280 and int(values.window_size[1]) == 800, "Leaving fullscreen must preserve the user's requested window dimensions")
	expect(Settings.save_settings(values).ok, "The second process must persist the return to Windowed mode")
	receipt.phase = "read"
	receipt.read_process = OS.get_process_id()
	save_receipt(receipt)


func windowed_phase():
	var receipt = read_receipt()
	if receipt.is_empty():
		return
	expect(receipt.get("phase") == "read", "Windowed verification must follow the completed read phase")
	expect(OS.get_process_id() != int(receipt.get("read_process", 0)) and OS.get_process_id() != int(receipt.get("write_process", 0)), "Windowed verification must run in a third independent process")
	var expected = custom_settings()
	expected.fullscreen = false
	var values = Settings.load_settings()
	expect(settings_match(values, expected), "The third process must retain Windowed mode, requested size, disabled audio, and custom volumes")
	await start_production_runtime(values)
	check_usable_window(REQUESTED_SIZE)
	var defaults = Settings.defaults()
	runtime.settings = defaults.duplicate(true)
	Settings.apply(runtime.settings)
	await create_timer(.15).timeout
	check_usable_window(Vector2i(defaults.window_size[0], defaults.window_size[1]))
	check_audio(defaults)
	expect(Settings.save_settings(defaults).ok and settings_match(Settings.load_settings(), defaults), "Restore Defaults must apply and persist every display/audio default")
	# Remove only the files in the explicitly isolated acceptance directory.
	var directory = DirAccess.open(TEST_ROOT)
	if directory != null:
		for filename in directory.get_files():
			expect(directory.remove(filename) == OK, "The isolated test fixture must clean up its file: " + filename)
		expect(DirAccess.remove_absolute(TEST_ROOT) == OK, "The isolated acceptance directory must be removed")


func run():
	Storage.storage_root = TEST_ROOT
	var phase = ""
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--display-phase="):
			phase = argument.get_slice("=", 1)
	if not expect(DisplayServer.get_name() != "headless", "Display acceptance requires a rendered process; headless mode cannot verify real display changes"):
		quit(1)
		return
	if not expect(phase in ["write", "read", "windowed"], "Choose --display-phase=write, read, or windowed"):
		quit(1)
		return
	match phase:
		"write":
			await write_phase()
		"read":
			await read_phase()
		"windowed":
			await windowed_phase()
	if is_instance_valid(runtime):
		runtime.queue_free()
		await process_frame
	# Let production music playback and bus/effect changes drain before teardown.
	await create_timer(.25).timeout
	if failures.is_empty():
		print("DISPLAY TEST PASSED: %s; %d checks; process %d; actual mode %d; window %s; isolated cross-process settings verified" % [phase, checks, OS.get_process_id(), DisplayServer.window_get_mode(), DisplayServer.window_get_size()])
	else:
		print("DISPLAY TEST FAILED: %s; %d of %d checks failed" % [phase, failures.size(), checks])
	quit(0 if failures.is_empty() else 1)
