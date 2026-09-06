class_name GameSettings
extends RefCounted

const Storage = preload("res://run_storage.gd")

static func defaults() -> Dictionary:
	return {"fullscreen": false, "window_size": [1440, 900], "music_enabled": true, "sfx_enabled": true, "master_volume": 0.8, "music_volume": 0.45, "sfx_volume": 0.7}

static func load_settings() -> Dictionary:
	var result := Storage.read_document(Storage.storage_root.path_join("settings.json"), "settings")
	return result.data if result.ok else defaults()

static func save_settings(settings: Dictionary) -> Dictionary:
	return Storage.write_document(Storage.storage_root.path_join("settings.json"), "settings", settings)

static func ensure_audio_buses() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	# Ceiling protection is shared by both buses; individual players are also quiet.
	var has_limiter := false
	for index in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0, index) is AudioEffectLimiter:
			has_limiter = true
	if not has_limiter:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -0.8
		AudioServer.add_bus_effect(0, limiter)

static func apply_audio(settings: Dictionary) -> void:
	var values := defaults()
	values.merge(settings, true)
	ensure_audio_buses()
	for pair in [["Master", "master_volume"], ["Music", "music_volume"], ["SFX", "sfx_volume"]]:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(pair[0]), linear_to_db(clampf(float(values[pair[1]]), 0.0, 1.0)))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not values.music_enabled)
	AudioServer.set_bus_mute(AudioServer.get_bus_index("SFX"), not values.sfx_enabled)

static func apply(settings: Dictionary) -> void:
	var values := defaults()
	values.merge(settings, true)
	apply_audio(values)
	if DisplayServer.get_name() == "headless":
		return
	if values.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var requested := Vector2i(int(values.window_size[0]), int(values.window_size[1]))
		var usable := DisplayServer.screen_get_usable_rect()
		requested.x = mini(maxi(requested.x, 960), usable.size.x)
		requested.y = mini(maxi(requested.y, 600), usable.size.y)
		DisplayServer.window_set_size(requested)
		DisplayServer.window_set_position(usable.position + (usable.size - requested) / 2)
