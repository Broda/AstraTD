class_name GameAudio
extends Node
## Real-time music crossfades, bounded sound effects, and explicit pause behavior.

const Settings = preload("res://scripts/services/game_settings.gd")
const GAMEPLAY_CUES := ["laser", "missile", "pulse", "cryo", "rail", "support", "impact", "implode", "thruster"]
const CUES := ["laser", "missile", "pulse", "cryo", "rail", "support", "impact", "implode", "thruster", "deploy", "upgrade", "salvage", "ui", "wave", "complete", "bonus", "core", "victory", "defeat"]
const ALIASES := {"railgun": "rail", "implosion": "implode", "fire_laser": "laser", "fire_missile": "missile", "fire_pulse": "pulse", "fire_cryo": "cryo", "fire_rail": "rail", "enemy_death": "implode", "wave_start": "wave", "wave_complete": "complete", "core_damage": "core"}
const VOICE_LIMIT := 12
const COMBAT_VOICE_LIMIT := 8
var streams: Dictionary = {}
var voices: Array[AudioStreamPlayer] = []
var music_players: Array[AudioStreamPlayer] = []
var music_context := ""
var music_target := -1
var gains := [0.0, 0.0]
var last_cue: Dictionary = {}
var settings: Dictionary = {}
var gameplay_paused := false
var previous_tick := 0

func setup(initial_settings: Dictionary) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Bus mute/volume settings are applied before any stream can start.
	apply_settings(initial_settings)
	if not voices.is_empty():
		return
	for id in CUES:
		streams[id] = load("res://assets/audio/%s.wav" % id)
	for index in range(VOICE_LIMIT):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = -17.0
		add_child(player)
		voices.append(player)
	for context in ["menu", "game"]:
		var player := AudioStreamPlayer.new()
		player.bus = "Music"
		var stream := load("res://assets/audio/music_%s.wav" % context) as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
		player.stream = stream
		player.volume_db = -80.0
		add_child(player)
		music_players.append(player)
	previous_tick = Time.get_ticks_usec()

func apply_settings(values: Dictionary) -> void:
	settings = Settings.defaults()
	settings.merge(values, true)
	Settings.apply_audio(settings)
	if not settings.sfx_enabled:
		for player in voices:
			player.stop()

func cue(requested_id: String) -> void:
	var id: String = ALIASES.get(requested_id, requested_id)
	if not settings.get("sfx_enabled", true) or not streams.has(id):
		return
	var combat := id in GAMEPLAY_CUES
	if gameplay_paused and combat:
		return
	var now := Time.get_ticks_msec()
	var interval := 85 if combat else 70
	if id == "thruster": interval = 420
	if id == "impact": interval = 120
	if id == "core": interval = 250
	if now - int(last_cue.get(id, -10000)) < interval:
		return
	var playing := 0
	for player in voices:
		if player.playing: playing += 1
	if combat and playing >= COMBAT_VOICE_LIMIT:
		return
	var selected: AudioStreamPlayer = null
	for player in voices:
		if not player.playing:
			selected = player
			break
	if selected == null:
		# Preserve important cues by replacing a combat voice if the pool is full.
		if combat:
			return
		for player in voices:
			if player.get_meta("combat", false):
				selected = player
				break
	if selected == null:
		return
	last_cue[id] = now
	selected.stop()
	selected.set_meta("combat", combat)
	selected.stream = streams[id]
	selected.volume_db = -22.0 if id == "thruster" else (-17.0 if combat else -10.0)
	selected.pitch_scale = 1.0
	selected.play()

func set_music(context: String) -> void:
	if music_players.is_empty() or context == music_context:
		return
	music_context = context
	music_target = 0 if context == "menu" else (1 if context == "game" else -1)
	if music_target >= 0 and not music_players[music_target].playing:
		music_players[music_target].play()

func set_paused(value: bool) -> void:
	gameplay_paused = value
	if value:
		for player in voices:
			player.stop()
	# Music continues at the same pitch and UI cues remain available.

func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var elapsed := clampf(float(now - previous_tick) / 1000000.0, 0.0, 0.1)
	previous_tick = now
	for index in range(music_players.size()):
		gains[index] = move_toward(gains[index], 1.0 if index == music_target else 0.0, elapsed / 1.2)
		music_players[index].volume_db = linear_to_db(maxf(0.0001, gains[index])) - 10.0
		if gains[index] <= 0.0 and index != music_target:
			music_players[index].stop()

func _exit_tree() -> void:
	# Detach active playback before the audio server drains its mixer callbacks.
	for player in voices:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	for player in music_players:
		if is_instance_valid(player):
			player.stop()
			player.stream = null
	streams.clear()
