extends RefCounted
## Legal placements with deliberately unlimited funds and durable enemies.
## The 180-frame samples measure real frame intervals; the separate soak batches
## simulation updates and proves lifetime/resource limits, not rendered throughput.

const Data = preload("res://scripts/data/game_data.gd")
const WARMUP_FRAMES = 60
const MEASURED_FRAMES = 180
const TOWER_COUNT = 30
const ENEMY_COUNT = 42
const MOUNT_COUNT = 30
const DRONE_COUNT = 15
const STEP = 1.0 / 60.0
const SOAK_SECONDS_PER_SPEED = 40.0

var game: Node
var failures: Array[String] = []
var cpu_samples: Array[float] = []
var rendered_samples: Array[float] = []
var peak_particles = 0
var peak_effects = 0
var peak_voices = 0
var peak_combat_voices = 0
var peak_drones = 0
var shots_by_role: Dictionary = {}
var cases: Array[Dictionary] = []
var support_coverage: Dictionary = {}
var longevity: Dictionary = {}
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
	if not expect(is_instance_valid(game.get("fleet_panel")) and is_instance_valid(game.wave_label) and is_instance_valid(game.status_label), "Full fleet panel and HUD must initialize before performance measurement"):
		return false
	game.start_run("twin_rift")
	game.credits = 1000000
	for i in range(TOWER_COUNT):
		var route: Curve3D = game.map_paths[i % game.map_paths.size()]
		var fraction = (float(i / 2) + .5) / 15.0
		var position = position_near(route.sample_baked(route.get_baked_length() * fraction))
		var kind: int = i % Data.TOWERS.size()
		if not expect(position.is_finite() and game.deploy(kind, position), "Stress fleet must use legal nonoverlapping placements"):
			return false
		game.selected = i
		var branch: int = (i / Data.TOWERS.size()) % 2
		if kind == 2:
			branch = 2
		elif kind == 5:
			branch = (i / Data.TOWERS.size()) % 3
		for tier in range(3):
			game.upgrade(branch)
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
	var drones = 0
	for tower in game.towers:
		mounts += tower.guns.size()
		drones += tower.drones.size()
	expect(mounts == MOUNT_COUNT, "Workload contains 20 Nova and 10 Cryostat mounts; support-only Relay has none")
	expect(drones == DRONE_COUNT, "Five three-tier Nova carriers must deploy exactly 15 functional drones")
	verify_support()
	return failures.is_empty()


func verify_support():
	support_coverage = {"damage_recipients":0,"range_recipients":0,"fire_rate_recipients":0,"overlapping_recipients":0,"max_sources":0,"relay_paths":[]}
	for tower in game.towers:
		var effective: Dictionary = game.effective_stats(tower)
		if tower.support_only:
			support_coverage.relay_paths.append(tower.branch)
			expect(tower.guns.is_empty() and effective.damage == 0.0 and effective.attacks_per_second == 0.0, "Relay has neither an offensive weapon nor effective offensive damage")
			expect(effective.sources.is_empty(), "Overlapping Relays must not amplify one another")
			expect(effective.affected_count > 0, "Every stress Relay must support real nearby fleet recipients")
			continue
		var sources: Array = game.support_sources(tower)
		support_coverage.max_sources = maxi(support_coverage.max_sources,sources.size())
		if sources.size() > 1: support_coverage.overlapping_recipients += 1
		if effective.damage > tower.damage: support_coverage.damage_recipients += 1
		if effective.range > tower.range: support_coverage.range_recipients += 1
		if effective.rate < tower.rate: support_coverage.fire_rate_recipients += 1
		var damage_bonus = 0.0
		var range_bonus = 0.0
		var fire_bonus = 0.0
		for source in sources:
			damage_bonus = maxf(damage_bonus,source.support_damage)
			range_bonus = maxf(range_bonus,source.support_range)
			fire_bonus = maxf(fire_bonus,source.support_fire_rate)
		expect(is_equal_approx(effective.damage,tower.damage*(1.0+damage_bonus)) and is_equal_approx(effective.range,tower.range*(1.0+range_bonus)) and is_equal_approx(effective.rate,tower.rate/(1.0+fire_bonus)), "Live recipient damage/range/rate uses the strongest eligible source for each bonus")
		if tower.drone_count > 0:
			expect(is_equal_approx(effective.drone_damage,tower.drone_damage*(1.0+damage_bonus)) and is_equal_approx(effective.drone_rate,tower.drone_rate/(1.0+fire_bonus)), "Live drones inherit supported carrier damage and rate once")
	expect(support_coverage.relay_paths == [0,1,2,0,1], "Five Relays exercise damage, range and fire-rate paths with overlapping duplicate paths")
	for key in ["damage_recipients","range_recipients","fire_rate_recipients","overlapping_recipients"]:
		expect(support_coverage[key] > 0, "Stress fleet must actually exercise " + key)


func prepare_step():
	# Retain density without bypassing real movement, targeting, shields, slowing,
	# damage, drone travel, particles, beams, and audio. Excluded from CPU timing.
	for foe in game.enemies:
		foe.hp = foe.maxhp
		if foe.distance > foe.route.get_baked_length() - .5:
			foe.distance = .25
			foe.node.position = foe.route.sample_baked(foe.distance) + Vector3.UP * .3


func sample_limits():
	peak_particles = maxi(peak_particles, game.fx.particles.size())
	peak_effects = maxi(peak_effects, game.effects.size())
	var drones = 0
	for tower in game.towers: drones += tower.drones.size()
	peak_drones = maxi(peak_drones,drones)
	var playing = 0
	var combat_playing = 0
	for voice in game.audio.voices:
		if voice.playing:
			playing += 1
			if voice.get_meta("combat", false): combat_playing += 1
	peak_voices = maxi(peak_voices, playing)
	peak_combat_voices = maxi(peak_combat_voices, combat_playing)


func shot_totals() -> Dictionary:
	var result: Dictionary = {}
	for tower in game.towers:
		var id: String = Data.TOWERS[tower.kind].id
		result[id] = result.get(id,0) + tower.shot
	return result


func drone_shots() -> int:
	var total = 0
	for tower in game.towers: total += tower.drone_shots
	return total


func percentile(samples: Array[float], fraction: float) -> float:
	if samples.is_empty(): return 0
	var ordered = samples.duplicate()
	ordered.sort()
	return ordered[clampi(ceili(ordered.size() * fraction) - 1, 0, ordered.size() - 1)]


func reset_metrics():
	cpu_samples.clear()
	rendered_samples.clear()
	peak_particles = 0
	peak_effects = 0
	peak_voices = 0
	peak_combat_voices = 0
	peak_drones = 0
	shots_by_role.clear()


func verify_density():
	expect(game.towers.size() == TOWER_COUNT and game.enemies.size() == ENEMY_COUNT, "Stress density remains constant throughout the workload")
	expect(game.active and game.integrity == game.map_data.starting_core, "Stress workload does not terminate or damage the core")
	expect(peak_particles > 0 and peak_particles <= game.fx.CAPACITY, "Gameplay particles remain within the bounded particle pool")
	expect(peak_effects > 0 and peak_effects <= game.MAX_EFFECTS, "Transient beam/pulse effects remain within their hard capacity")
	expect(peak_drones == DRONE_COUNT, "Combat retains exactly 15 drones without extra spawned fighters")
	expect(peak_voices > 0 and peak_voices <= game.audio.VOICE_LIMIT, "Actual firing and impact cues respect the total SFX budget")
	expect(peak_combat_voices <= game.audio.COMBAT_VOICE_LIMIT, "Combat cues respect their eight-voice sub-budget")


func measure_case(intensity: String) -> Dictionary:
	reset_metrics()
	game.settings.effects_intensity = intensity
	if not setup_workload(): return {}
	var last_render_tick = Time.get_ticks_usec()
	for frame in range(WARMUP_FRAMES + MEASURED_FRAMES):
		await game.get_tree().process_frame
		prepare_step()
		var start = Time.get_ticks_usec()
		game._process(STEP)
		var cpu_ms = float(Time.get_ticks_usec()-start)/1000.0
		if not headless: await RenderingServer.frame_post_draw
		var rendered_tick = Time.get_ticks_usec()
		if frame >= WARMUP_FRAMES:
			cpu_samples.append(cpu_ms)
			if not headless: rendered_samples.append(float(rendered_tick-last_render_tick)/1000.0)
		last_render_tick = rendered_tick
		sample_limits()
	shots_by_role = shot_totals()
	verify_density()
	expect(cpu_samples.size() == MEASURED_FRAMES, "CPU sample contains exactly 180 measured simulation steps")
	expect(headless or rendered_samples.size() == MEASURED_FRAMES, "Rendered sample contains exactly 180 measured frame intervals")
	for id in shots_by_role:
		expect(shots_by_role[id] == 0 if id == "support" else shots_by_role[id] > 0, "Support remains nonoffensive; every offensive role fires: " + id)
	expect(drone_shots() > 0, "Orbiting drones deal real combat hits during the measured workload")
	var active_drones = 0
	var reusable_beams = 0
	for tower in game.towers:
		for drone in tower.drones:
			if drone.shots > 0: active_drones += 1
			if is_instance_valid(drone.beam): reusable_beams += 1
			if intensity == "reduced": expect(not drone.beam.visible and drone.node.visible, "Reduced effects suppress drone beams while preserving visible functional fighters")
	expect(active_drones == DRONE_COUNT, "Every one of the 15 drones must acquire and attack within the measured workload")
	expect(reusable_beams == DRONE_COUNT, "Each drone owns exactly one reusable beam")
	verify_readability()
	if not headless:
		await game.get_tree().process_frame
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://work")
		game.get_viewport().get_texture().get_image().save_png("res://work/performance_%s.png" % intensity)
	return {
		"effects_intensity":intensity,
		"warmup_frames":WARMUP_FRAMES,
		"measured_frames":cpu_samples.size(),
		"simulation_step_seconds":STEP,
		"simulation_speed":1,
		"towers":game.towers.size(),
		"enemies":game.enemies.size(),
		"independent_mounts":MOUNT_COUNT,
		"drones":DRONE_COUNT,
		"active_drones":active_drones,
		"drone_shots":drone_shots(),
		"reusable_drone_beams":reusable_beams,
		"cpu_process_median_ms":percentile(cpu_samples,.5),
		"cpu_process_p95_ms":percentile(cpu_samples,.95),
		"rendered_frame_median_ms":percentile(rendered_samples,.5) if not headless else null,
		"rendered_frame_p95_ms":percentile(rendered_samples,.95) if not headless else null,
		"peak_particles":peak_particles,
		"particle_capacity":game.fx.CAPACITY,
		"peak_effect_nodes":peak_effects,
		"effect_capacity":game.MAX_EFFECTS,
		"peak_drones":peak_drones,
		"peak_sfx_voices":peak_voices,
		"peak_combat_voices":peak_combat_voices,
		"sfx_voice_capacity":game.audio.VOICE_LIMIT,
		"combat_voice_capacity":game.audio.COMBAT_VOICE_LIMIT,
		"shots_by_role":shots_by_role.duplicate(),
		"support":support_coverage.duplicate(true)
	}


func verify_readability():
	# Essential overlays remain present at both effect intensities.
	game.selected = 17 # Relay with fire-control path near the middle of the fleet.
	game.update_support_visuals()
	var relay: Dictionary = game.towers[game.selected]
	var recipients: Array = game.support_recipients(relay.node.position,relay.aura_range)
	for tower in game.towers:
		expect(tower.support_marker.visible == recipients.has(tower), "Reduced/normal effects retain accurate selected-Relay recipient markers")
	game.selected = 15 # Cryostat, with its firing arcs visible in the capture.
	game.refresh_ui()
	game.update_support_visuals()
	for gun in game.towers[game.selected].guns:
		expect(gun.has("arc") and gun.arc.visible, "Selected Cryostat aiming arcs remain visible independently of effect intensity")
	for foe in game.enemies:
		expect(foe.node.visible and foe.bar.visible, "Enemy silhouettes and health feedback remain visible during the dense workload")

func soak_fleet():
	# Use the reduced-effects fleet left by measure_case; retain all real combat.
	# Batch eight steps per real frame. This is a longevity/resource check only.
	var original_ids: Array = []
	for tower in game.towers:
		for drone in tower.drones: original_ids.append(drone.node.get_instance_id())
	var speed_results: Array = []
	var initial_shots = drone_shots()
	for speed in [1.0,2.0,3.0]:
		game.set_speed(speed)
		var elapsed_before: float = game.elapsed
		var before_shots = shot_totals()
		var before_drone_shots = drone_shots()
		var steps = roundi(SOAK_SECONDS_PER_SPEED/(STEP*speed))
		for frame in range(steps):
			if frame%8 == 0: await game.get_tree().process_frame
			prepare_step()
			game._process(STEP)
			sample_limits()
		var after_shots = shot_totals()
		for id in after_shots:
			expect(after_shots[id] == 0 if id == "support" else after_shots[id] > before_shots[id], "At %dx Relay never fires and every offensive role keeps working: %s" % [speed,id])
		expect(drone_shots() > before_drone_shots, "Drone attacks continue across the full %dx simulation segment" % speed)
		expect(is_equal_approx(game.elapsed-elapsed_before,SOAK_SECONDS_PER_SPEED), "The %dx segment advances the intended 40 simulation seconds exactly once" % speed)
		verify_density()
		speed_results.append({"speed":speed,"steps":steps,"simulation_seconds":game.elapsed-elapsed_before,"drone_shots":drone_shots()-before_drone_shots})
	var final_ids: Array = []
	var max_scale_roundoff = 0.0
	for tower in game.towers:
		max_scale_roundoff = maxf(max_scale_roundoff,tower.node.scale.distance_to(Vector3.ONE))
		expect(tower.node.scale.is_equal_approx(Vector3.ONE), "Long combat and support preserve fleet scale within rotation floating-point precision: %s" % tower.node.scale)
		for drone in tower.drones:
			final_ids.append(drone.node.get_instance_id())
			expect(drone.node.visible and not drone.beam.visible, "Long reduced-effects combat retains essential drone visuals")
	expect(final_ids == original_ids, "Two minutes of real fleet simulation reuse the original 15 fighter instances")
	longevity = {
		"effects_intensity":"reduced",
		"simulation_seconds":SOAK_SECONDS_PER_SPEED*3.0,
		"frames_batched_per_yield":8,
		"segments":speed_results,
		"drone_shots":drone_shots()-initial_shots,
		"same_drone_instances":final_ids==original_ids,
		"max_scale_roundoff":max_scale_roundoff,
		"peak_drones":peak_drones,
		"peak_particles":peak_particles,
		"peak_effect_nodes":peak_effects,
		"peak_sfx_voices":peak_voices,
		"peak_combat_voices":peak_combat_voices,
		"shots_by_role":shot_totals()
	}


func report() -> Dictionary:
	var window_size = DisplayServer.window_get_size()
	var result: Dictionary = cases[0].duplicate(true) if not cases.is_empty() else {}
	result.merge({
		"mode":"headless" if headless else "rendered",
		"godot":Engine.get_version_info().string,
		"os":OS.get_name(),
		"cpu":OS.get_processor_name(),
		"logical_processors":OS.get_processor_count(),
		"renderer":RenderingServer.get_current_rendering_method(),
		"gpu":RenderingServer.get_video_adapter_name() if not headless else "not measured (headless)",
		"display_server":DisplayServer.get_name(),
		"window":[window_size.x,window_size.y],
		"viewport":[game.get_viewport().get_visible_rect().size.x,game.get_viewport().get_visible_rect().size.y],
		"vsync_mode":DisplayServer.window_get_vsync_mode() if not headless else -1,
		"cases":cases,
		"longevity":longevity,
		"checks":checks,
		"failures":failures.duplicate()
	})
	print("PERFORMANCE_RESULT " + JSON.stringify(result))
	DirAccess.make_dir_recursive_absolute("res://work")
	var file = FileAccess.open("res://work/performance_%s.json" % result.mode,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(result,"\t"))
		file.close()
	return result


func run(node: Node):
	game = node
	game.set_process(false)
	headless = DisplayServer.get_name() == "headless"
	var original_testing = game.testing
	var original_settings: Dictionary = game.settings.duplicate(true)
	var original_audio: Dictionary = game.audio.settings.duplicate(true)
	for intensity in ["normal","reduced"]:
		var measured: Dictionary = await measure_case(intensity)
		if measured.is_empty(): break
		cases.append(measured)
	if cases.size() == 2:
		expect(cases[1].peak_particles < cases[0].peak_particles, "Reduced intensity lowers particle pressure under the same scenario")
		expect(cases[1].peak_effect_nodes < cases[0].peak_effect_nodes, "Reduced intensity lowers transient beam/effect pressure")
		expect(cases[1].drone_shots == cases[0].drone_shots and cases[1].shots_by_role == cases[0].shots_by_role, "Effect intensity preserves identical drone and fleet firing behavior")
		await soak_fleet()
	var result = report()
	game.testing = true
	game.settings = original_settings
	game.audio.set_paused(true)
	game.audio.apply_settings(original_audio)
	game.clear_run()
	# Stop streams and allow the audio mixer to drain callbacks before quitting.
	game.audio.queue_free()
	await game.get_tree().process_frame
	await game.get_tree().create_timer(.25).timeout
	game.testing = original_testing
	if failures.is_empty():
		print("PERFORMANCE TEST PASSED: %d checks; %s normal CPU median %.3f ms / p95 %.3f ms; 15 drones, normal/reduced effects, overlapping support, 120-second 1x/2x/3x fleet soak" % [checks,result.mode,result.get("cpu_process_median_ms",0.0),result.get("cpu_process_p95_ms",0.0)])
	else:
		print("PERFORMANCE TEST FAILED: %d checks failed" % failures.size())
	game.get_tree().quit(0 if failures.is_empty() else 1)
