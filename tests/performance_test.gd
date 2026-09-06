extends RefCounted
## Bounded stress workload, not an economy or campaign-balance simulation.

const Data = preload("res://game_data.gd")
const WARMUP_FRAMES = 60
const MEASURED_FRAMES = 180
const TOWER_COUNT = 30
const ENEMY_COUNT = 42
const STEP = 1.0 / 60.0

var game: Node
var failures: Array[String] = []
var cpu_samples: Array[float] = []
var rendered_samples: Array[float] = []
var peak_particles = 0
var peak_effects = 0
var peak_voices = 0
var peak_combat_voices = 0
var shots_by_role: Dictionary = {}
var headless = true
var checks = 0


func expect(condition: bool, description: String) -> bool:
	checks += 1
	if not condition:
		failures.append(description)
		push_error("PERFORMANCE: " + description)
	return condition


func position_near(target: Vector3) -> Vector3:
	var best = Vector3.INF
	var best_score = INF
	for x in range(-20, 11):
		for z in range(-10, 11):
			var position = Vector3(x, 0, z)
			if not game.can_place(position):
				continue
			var score = position.distance_squared_to(target)
			if score < best_score:
				best = position
				best_score = score
	return best


func setup_workload() -> bool:
	game.start_run("twin_rift")
	game.credits = 1000000
	for i in range(TOWER_COUNT):
		var route: Curve3D = game.map_paths[i % game.map_paths.size()]
		var fraction = (float(i / 2) + .5) / 15.0
		var position = position_near(route.sample_baked(route.get_baked_length() * fraction))
		if not expect(position.is_finite() and game.deploy(i % Data.TOWERS.size(), position), "Stress fleet must use legal nonoverlapping placements"):
			return false
		game.selected = i
		for tier in range(3):
			game.upgrade((i / Data.TOWERS.size()) % 2)
		if not expect(game.towers[i].level == 3, "Every stress tower must receive all three valid upgrade tiers"):
			return false
	game.selected = -1
	game.wave = game.map_data.final_wave - 1
	game.start_wave()
	if not expect(game.wave_data.spawns.size() == ENEMY_COUNT, "Workload must use all 42 enemies from the largest authored finite wave"):
		return false
	for i in range(ENEMY_COUNT):
		game.spawn_enemy()
		game.remaining -= 1
		var foe = game.enemies.back()
		foe.hp = 100000000.0
		foe.maxhp = foe.hp
		foe.distance = foe.route.get_baked_length() * ((float(i / 2) + .5) / 21.0)
		foe.node.position = foe.route.sample_baked(foe.distance) + Vector3.UP * .3
	game.game_speed = 1
	game.spawn_clock = 100000
	game.audio.set_paused(false)
	var audio_settings: Dictionary = game.audio.settings.duplicate(true)
	audio_settings.sfx_enabled = true
	game.audio.apply_settings(audio_settings)
	game.testing = false
	var mounts = 0
	for tower in game.towers:
		mounts += tower.guns.size()
	expect(mounts == 40, "Workload must contain 40 independently aiming station mounts")
	return failures.is_empty()


func prepare_step():
	# Keep the intended density alive. Workload preparation is excluded from CPU
	# timing; weapon targeting, damage, status, particles, beams, and cues are real.
	for foe in game.enemies:
		foe.hp = foe.maxhp
		if foe.distance > foe.route.get_baked_length() - .5:
			foe.distance = .25
			foe.node.position = foe.route.sample_baked(foe.distance) + Vector3.UP * .3


func sample_limits():
	peak_particles = maxi(peak_particles, game.fx.particles.size())
	peak_effects = maxi(peak_effects, game.effects.size())
	var playing = 0
	var combat_playing = 0
	for voice in game.audio.voices:
		if voice.playing:
			playing += 1
			if voice.get_meta("combat", false):
				combat_playing += 1
	peak_voices = maxi(peak_voices, playing)
	peak_combat_voices = maxi(peak_combat_voices, combat_playing)


func percentile(samples: Array[float], fraction: float) -> float:
	if samples.is_empty():
		return 0
	var ordered = samples.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(ordered.size() * fraction) - 1, 0, ordered.size() - 1)]


func report() -> Dictionary:
	var window_size = DisplayServer.window_get_size()
	var result = {
		"mode": "headless" if headless else "rendered",
		"godot": Engine.get_version_info().string,
		"os": OS.get_name(),
		"cpu": OS.get_processor_name(),
		"logical_processors": OS.get_processor_count(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name() if not headless else "not measured (headless)",
		"display_server": DisplayServer.get_name(),
		"window": [window_size.x, window_size.y],
		"viewport": [game.get_viewport().get_visible_rect().size.x, game.get_viewport().get_visible_rect().size.y],
		"vsync_mode": DisplayServer.window_get_vsync_mode() if not headless else -1,
		"warmup_frames": WARMUP_FRAMES,
		"measured_frames": cpu_samples.size(),
		"simulation_step_seconds": STEP,
		"towers": game.towers.size(),
		"enemies": game.enemies.size(),
		"independent_mounts": 40,
		"cpu_process_median_ms": percentile(cpu_samples, .5),
		"cpu_process_p95_ms": percentile(cpu_samples, .95),
		"rendered_frame_median_ms": percentile(rendered_samples, .5) if not headless else null,
		"rendered_frame_p95_ms": percentile(rendered_samples, .95) if not headless else null,
		"peak_particles": peak_particles,
		"particle_capacity": game.fx.CAPACITY,
		"peak_effect_nodes": peak_effects,
		"peak_sfx_voices": peak_voices,
		"peak_combat_voices": peak_combat_voices,
		"sfx_voice_capacity": game.audio.VOICE_LIMIT,
		"combat_voice_capacity": game.audio.COMBAT_VOICE_LIMIT,
		"shots_by_role": shots_by_role,
		"failures": failures.duplicate()
	}
	print("PERFORMANCE_RESULT " + JSON.stringify(result))
	DirAccess.make_dir_recursive_absolute("res://work")
	var file = FileAccess.open("res://work/performance_%s.json" % result.mode, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result, "\t"))
		file.close()
	return result


func run(node: Node):
	game = node
	game.set_process(false)
	headless = DisplayServer.get_name() == "headless"
	var original_testing = game.testing
	var original_audio: Dictionary = game.audio.settings.duplicate(true)
	var ready = setup_workload()
	var last_render_tick = Time.get_ticks_usec()
	if ready:
		for frame in range(WARMUP_FRAMES + MEASURED_FRAMES):
			# Yield each frame to flush queued effect nodes and service actual audio.
			await game.get_tree().process_frame
			prepare_step()
			var start = Time.get_ticks_usec()
			game._process(STEP)
			var cpu_ms = float(Time.get_ticks_usec() - start) / 1000.0
			if not headless:
				await RenderingServer.frame_post_draw
			var rendered_tick = Time.get_ticks_usec()
			if frame >= WARMUP_FRAMES:
				cpu_samples.append(cpu_ms)
				if not headless:
					rendered_samples.append(float(rendered_tick - last_render_tick) / 1000.0)
			last_render_tick = rendered_tick
			sample_limits()
		for tower in game.towers:
			var id: String = Data.TOWERS[tower.kind].id
			shots_by_role[id] = shots_by_role.get(id, 0) + tower.shot
		expect(game.towers.size() == TOWER_COUNT and game.enemies.size() == ENEMY_COUNT, "Stress density must remain constant for the full bounded workload")
		expect(game.active and game.integrity == game.map_data.starting_core, "Stress workload must not terminate or damage the core")
		expect(cpu_samples.size() == MEASURED_FRAMES, "CPU sample must contain exactly 180 measured simulation steps")
		expect(headless or rendered_samples.size() == MEASURED_FRAMES, "Rendered sample must contain exactly 180 measured frame intervals")
		expect(peak_particles > 0 and peak_particles <= game.fx.CAPACITY, "Gameplay particles must remain inside the 2400-particle pool")
		expect(peak_effects > 0 and peak_effects < 1024, "Transient beam/pulse effects must remain bounded under the fixed workload")
		expect(peak_voices > 0 and peak_voices <= game.audio.VOICE_LIMIT, "Actual firing and impact cues must use at most 12 SFX voices")
		expect(peak_combat_voices <= game.audio.COMBAT_VOICE_LIMIT, "Combat cues must respect their eight-voice sub-budget")
		for id in shots_by_role:
			expect(shots_by_role[id] > 0, "Every tower role must fire during the workload: " + id)
	var result = report()
	game.testing = true
	game.audio.set_paused(true)
	game.audio.apply_settings(original_audio)
	game.clear_run()
	# Release playback before quitting so the audio mixer can drain callbacks.
	game.audio.queue_free()
	await game.get_tree().process_frame
	await game.get_tree().create_timer(.25).timeout
	game.testing = original_testing
	if failures.is_empty():
		print("PERFORMANCE TEST PASSED: %d checks; %s CPU median %.3f ms / p95 %.3f ms, particles %d, effects %d, SFX voices %d" % [checks, result.mode, result.cpu_process_median_ms, result.cpu_process_p95_ms, peak_particles, peak_effects, peak_voices])
	else:
		print("PERFORMANCE TEST FAILED: %d checks failed" % failures.size())
	game.get_tree().quit(0 if failures.is_empty() else 1)
