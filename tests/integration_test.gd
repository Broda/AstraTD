extends RefCounted
## Invoked by main.gd with --integration-test. All persistent writes are isolated.

const Data = preload("res://scripts/data/game_data.gd")
const Storage = preload("res://scripts/services/run_storage.gd")

var game: Node
var checks = 0
var failures: Array[String] = []


func expect(condition: bool, message: String) -> bool:
	checks += 1
	if not condition:
		failures.append(message)
		push_error("INTEGRATION: " + message)
	return condition


func reset(map_id = "aurora_reach"):
	game.start_run(map_id)
	game.credits = 100000


func valid_position(near = Vector3.ZERO) -> Vector3:
	var best = Vector3.INF
	var distance = INF
	for x in range(-20, 11):
		for z in range(-10, 11):
			var position = Vector3(x, 0, z)
			if game.can_place(position) and position.distance_squared_to(near) < distance:
				best = position
				distance = position.distance_squared_to(near)
	return best


func place(id: String, near = Vector3.ZERO) -> int:
	var position = valid_position(near)
	if not expect(position.is_finite(), "Test setup must find a legal placement for " + id):
		return -1
	if not expect(game.deploy(Data.tower_index(id), position), "Test setup must deploy " + id):
		return -1
	return game.towers.size() - 1


func enemy(id: String) -> Dictionary:
	game.spawn_enemy(id)
	return game.enemies.back()


func write_text(path: String, contents: String):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if expect(file != null, "Test fixture must be writable"):
		file.store_string(contents)
		file.close()


func run(node: Node):
	game = node
	game.set_process(false)
	var original_root = Storage.storage_root
	var original_testing = game.testing
	Storage.storage_root = "user://integration_checks_%d" % OS.get_process_id()
	game.testing = true
	check_maps_and_reset()
	await game.get_tree().process_frame
	check_pause_and_navigation()
	await game.get_tree().process_frame
	check_speed()
	check_save_restore()
	await game.get_tree().process_frame
	check_damage_rules()
	check_support_and_mounts()
	await game.get_tree().process_frame
	check_terminal_guards()
	game.testing = true
	game.clear_run()
	game.audio.queue_free()
	await game.get_tree().process_frame
	await game.get_tree().create_timer(.25).timeout
	# Delete only files in this process's explicitly isolated test directory.
	var directory = DirAccess.open(Storage.storage_root)
	if directory != null:
		for filename in directory.get_files():
			directory.remove(filename)
		DirAccess.remove_absolute(Storage.storage_root)
	Storage.storage_root = original_root
	game.testing = original_testing
	if failures.is_empty():
		print("INTEGRATION TEST PASSED: %d checks; finite map reset and lanes, pause/speed, saved fleet reconstruction, rejected-load preservation, defenses, support-only relay, terminal rewards and progress" % checks)
	else:
		print("INTEGRATION TEST FAILED: %d / %d checks" % [failures.size(), checks])
	game.get_tree().quit(0 if failures.is_empty() else 1)


func check_maps_and_reset():
	for definition in Data.maps():
		if definition.final_wave == 0:
			continue
		game.start_run(definition.id)
		expect(game.map_data.id == definition.id and game.map_paths.size() == definition.paths.size(), "Map must load every configured route: " + definition.id)
		expect(game.credits == definition.starting_credits and game.integrity == definition.starting_core, "Map must use its own starting economy and core")
		expect(game.wave == 0 and game.completed_waves == 0 and not game.active and game.session_state == game.Session.PREPARATION, "Map must start in preparation at wave zero")
		expect(game.portals.size() == definition.paths.size() * 2, "Map must create entry and exit gates for every route")
		for i in range(game.map_paths.size()):
			var route: Curve3D = game.map_paths[i]
			expect(route.sample_baked(0).is_equal_approx(definition.entry_gates[i]), "Route entry must match the selected map")
			expect(route.sample_baked(route.get_baked_length()).is_equal_approx(definition.exit_gates[i]), "Route exit must match the selected map")
			for fraction in [.1, .3, .5, .7, .9]:
				expect(not game.can_place(route.sample_baked(route.get_baked_length() * fraction)), "Placement must reject every lane, including secondary routes")
		expect(not game.can_place(Vector3(-22, 0, 0)) and not game.can_place(Vector3(12, 0, 0)), "Placement must respect left/right map bounds")
		expect(not game.can_place(Vector3(0, 0, 12)) and not game.can_place(Vector3(0, 1, 0)), "Placement must respect depth bounds and the placement plane")
		expect(not game.can_place(Vector3.INF), "Non-finite placements must be rejected")
		var index = place("lancer")
		if index < 0:
			return
		var old_tower: Node3D = game.towers[index].node
		expect(not game.can_place(old_tower.position + Vector3(.5, 0, 0)), "Ships must not overlap")
		game.start_wave()
		var first = enemy("raider")
		game.pulse(Vector3.ZERO, 1, Color.WHITE)
		game.fx.add_particle(Vector3.ZERO, Vector3.ONE, Color.WHITE, 10, 1)
		game.spent = true
		game.kills = 9
		game.set_speed(3)
		var old_map: Node3D = game.map_root
		game.start_run(definition.id)
		expect(not is_instance_valid(old_map), "Restart must release previous map scenery immediately")
		expect(old_tower.is_queued_for_deletion() and first.node.is_queued_for_deletion(), "Restart must dispose previous ships and enemies")
		expect(game.towers.is_empty() and game.enemies.is_empty() and game.effects.is_empty() and game.fx.particles.is_empty(), "Restart must clear combat objects and particles")
		expect(game.remaining == 0 and game.spawn_clock == 0 and game.elapsed == 0 and game.wave_data.is_empty(), "Restart must clear pending spawns and wave timers")
		expect(not game.spent and game.kills == 0 and game.game_speed == 1 and not game.dirty, "Restart must reset purchase eligibility, kills, speed, and dirty state")
	reset("twin_rift")
	game.start_wave()
	var first_route = enemy("raider").route
	game.remaining -= 1
	var second_route = enemy("raider").route
	expect(first_route != second_route, "Twin Rift spawns must alternate between distinct entry lanes")


func frozen_snapshot() -> Dictionary:
	var foes: Array = []
	for e in game.enemies:
		foes.append([e.distance, e.hp, e.shield, e.slow, e.node.position, e.jet_clock])
	var fleet: Array = []
	for tower in game.towers:
		var guns: Array = []
		for gun in tower.guns:
			guns.append([gun.recoil, gun.pitch.transform, gun.yaw.transform, gun.target])
		fleet.append([tower.cooldown, tower.jet_clock, tower.node.transform, guns])
	var visual: Array = []
	for effect in game.effects:
		visual.append([effect.life, effect.node.transform])
	return {"enemies": foes, "towers": fleet, "effects": visual, "particles": game.fx.particles.duplicate(true), "elapsed": game.elapsed, "remaining": game.remaining, "clock": game.spawn_clock, "credits": game.credits, "kills": game.kills, "core": game.integrity, "wave": game.wave, "spent": game.spent}


func check_pause_and_navigation():
	reset()
	var index = place("cryostat", Vector3(7, 0, 8))
	if index < 0:
		return
	game.towers[index].cooldown = 1.5
	game.towers[index].guns[0].recoil = .04
	game.start_wave()
	var e = enemy("regenerating")
	e.hp -= 10
	e.slow = 2
	e.factor = .5
	game.spawn_clock = .1
	game.pulse(Vector3.ZERO, 2, Color.WHITE)
	game.fx.add_particle(Vector3.ZERO, Vector3.ONE, Color.WHITE, 5, 1)
	game.set_speed(3)
	expect(not game.can_save(), "Active waves must expose the between-wave save restriction")
	game.toggle_pause()
	expect(game.session_state == game.Session.PAUSED and game.resume_state == game.Session.ACTIVE_WAVE, "Pause must preserve the combat phase")
	var before = frozen_snapshot()
	for i in range(20):
		game._process(.1)
	expect(frozen_snapshot() == before, "Pause must freeze movement, regeneration, status timers, cooldowns, targeting, recoil, effects, spawning, and rewards")
	game.selected = index
	game.upgrade(0)
	game.sell_selected()
	game.start_wave()
	game.set_speed(1)
	expect(not game.deploy(0, valid_position()), "Pause must block purchases")
	expect(frozen_snapshot() == before and game.towers.size() == 1 and game.game_speed == 3, "Pause must block upgrades, salvage, wave starts, and speed changes")
	expect(not game.can_save(), "Pausing combat must not enable preparation-only saves")
	game.resume_run()
	expect(game.session_state == game.Session.ACTIVE_WAVE and game.game_speed == 3, "Resume must restore the active phase and selected speed")
	game._process(.01)
	expect(e.distance > before.enemies[0][0] and e.hp > before.enemies[0][1], "Resumed simulation must move and regenerate enemies")
	game.to_main_menu()
	before = frozen_snapshot()
	game._process(.5)
	expect(game.session_state == game.Session.MAIN_MENU and frozen_snapshot() == before, "Main menu must suspend an available run")
	game.resume_run()
	expect(game.session_state == game.Session.ACTIVE_WAVE, "Continue must return from the main menu to the prior phase")
	reset()
	game.toggle_pause()
	expect(game.can_save(), "Preparation saves must remain available in the pause menu")
	game.resume_run()


func speed_sample(speed: float) -> Array:
	reset()
	var index = place("lancer", Vector3(8, 0, 9))
	if index < 0:
		return []
	game.towers[index].cooldown = 5
	game.start_wave()
	game.remaining = 1
	game.spawn_clock = 100
	var e = enemy("regenerating")
	e.hp -= 15
	e.jet_clock = 100
	game.set_speed(speed)
	for i in range(int(60 / speed)):
		game._process(1.0 / 60.0)
	return [e.distance, e.hp, game.towers[index].cooldown, game.spawn_clock, game.elapsed, game.credits]


func check_speed():
	var normal = speed_sample(1)
	for speed in [2.0, 3.0]:
		var faster = speed_sample(speed)
		if not expect(normal.size() == 6 and faster.size() == 6, "Speed test setup must produce comparable samples"):
			return
		for i in range(normal.size()):
			expect(is_equal_approx(normal[i], faster[i]), "Equal simulated time at 1x/%dx must preserve movement, regeneration, cooldowns, spawn timers, elapsed time, and credits (field %d)" % [speed, i])


func check_save_restore():
	reset("twin_rift")
	for entry in [["nova", 0, 2], ["nova", 1, 3], ["support", 0, 2], ["railgun", 1, 3]]:
		var index = place(entry[0])
		if index < 0:
			return
		game.selected = index
		for tier in range(entry[2]):
			game.upgrade(entry[1])
	game.wave = 3
	game.completed_waves = 3
	game.credits = 1234
	game.integrity = 13
	game.kills = 42
	game.set_speed(3)
	var original_stats: Array = []
	for tower in game.towers:
		original_stats.append([tower.damage, tower.range, tower.rate, tower.invested, tower.support, tower.pulse_enabled, tower.guns.size()])
	var snapshot: Dictionary = game.saved_run()
	expect(game.can_save() and not snapshot.spent, "Preparation snapshot must preserve next-wave bonus eligibility")
	if not expect(Storage.save_slot(1, snapshot).ok, "A real game snapshot must save successfully"):
		return
	var loaded: Dictionary = Storage.load_slot(1)
	if not expect(loaded.ok, "A real game snapshot must load successfully"):
		return
	reset("cobalt_bend")
	expect(game.restore_run(loaded.data).is_empty(), "Restoring a saved fleet must succeed")
	expect(game.saved_run() == snapshot, "Map, balances, core, kills, speed, positions, stable type IDs, branches, and tiers must round trip")
	expect(game.completed_waves == 3 and not game.dirty and not game.spent, "Loaded preparation state must be clean with completed waves and bonus eligibility restored")
	var stale_indices: Dictionary = snapshot.duplicate(true)
	for record in stale_indices.towers:
		record.branch = 1-int(record.branch)
	expect(game.restore_run(stale_indices).is_empty(), "Stable branch IDs must survive stale numeric branch ordering")
	expect(game.saved_run() == snapshot, "Upgrade reconstruction must use stable IDs rather than serialized array indices")
	if not expect(game.towers.size() == original_stats.size(), "Restore must rebuild exactly one tower per saved record"):
		return
	for i in range(game.towers.size()):
		var tower = game.towers[i]
		var actual: Array = [tower.damage, tower.range, tower.rate, tower.invested, tower.support, tower.pulse_enabled, tower.guns.size()]
		expect(actual == original_stats[i], "Restore must replay exact upgrade stats, investment, aura, pulse state, and independent mounts")
		for gun in tower.guns:
			expect(gun.target == null and gun.muzzles.size() > 0, "Loaded guns must rebuild valid muzzle anchors and acquire fresh targets")
	expect(game.towers[0].pulse_enabled and not game.towers[1].pulse_enabled, "Nova pulse unlock must survive load without leaking into the exclusive guns branch")
	game.selected = 0
	var before = game.saved_run()
	game.upgrade(1)
	expect(game.saved_run() == before, "Loaded Nova specialization must continue to reject the exclusive branch without charging")
	expect(game.restore_run(loaded.data).is_empty() and game.saved_run() == snapshot, "Repeated restore must not charge, reward, duplicate towers, or duplicate upgrades")
	before = game.saved_run()
	var old_tower: Node3D = game.towers[0].node
	var bad = snapshot.duplicate(true)
	bad.map_id = "missing_map"
	expect(not game.restore_run(bad).is_empty(), "Unknown map saves must be rejected")
	expect(game.saved_run() == before and game.towers[0].node == old_tower, "Unknown map rejection must preserve the live run and its nodes")
	bad = snapshot.duplicate(true)
	bad.towers[1].position = bad.towers[0].position.duplicate()
	expect(not game.restore_run(bad).is_empty() and game.saved_run() == before, "Overlapping saved ships must be rejected before changing the current run")
	bad = snapshot.duplicate(true)
	var lane: Vector3 = game.map_paths[1].sample_baked(10)
	bad.towers[0].position = [lane.x, 0, lane.z]
	expect(not game.restore_run(bad).is_empty() and game.saved_run() == before, "Saved towers overlapping a secondary lane must be rejected before mutation")
	bad = snapshot.duplicate(true)
	bad.towers[0].branch_id = "removed_branch"
	expect(not game.restore_run(bad).is_empty() and game.saved_run() == before, "Incompatible stable branch IDs must be rejected before mutation")
	write_text(Storage.storage_root.path_join("slot_2.json"), "{interrupted")
	var corrupt = Storage.load_slot(2)
	expect(not corrupt.ok and not corrupt.error.is_empty() and game.saved_run() == before, "Corrupt saves must produce a readable error and preserve the run")
	game.start_wave()
	expect(not game.spent and game.wave == snapshot.wave + 1 and not game.can_save(), "Continuing a loaded run must start exactly the next wave with its bonus eligible")


func check_damage_rules():
	reset()
	var armored = enemy("armored")
	var hp: float = armored.hp
	game.hurt(armored, 10)
	expect(is_equal_approx(armored.hp, hp - 6), "Armor must reduce each normal hit by its explicit armor amount")
	game.hurt(armored, 2)
	expect(is_equal_approx(armored.hp, hp - 7), "Armor must retain a minimum one point of hull damage")
	game.hurt(armored, 10, true)
	expect(is_equal_approx(armored.hp, hp - 17), "Armor piercing must bypass hull armor")
	var shielded = enemy("shielded")
	hp = shielded.hp
	var shield: float = shielded.shield
	game.hurt(shielded, shield - 3)
	expect(is_equal_approx(shielded.shield, 3) and shielded.hp == hp, "Shields must absorb damage before hull health")
	game.hurt(shielded, 8, true)
	expect(shielded.shield == 0 and is_equal_approx(shielded.hp, hp - 5), "Piercing must respect shields and carry overflow into hull damage")
	var rail_index = place("railgun")
	if rail_index < 0:
		return
	armored.hp = 1000
	armored.maxhp = 1000
	var rail = game.towers[rail_index]
	game.fire(rail, armored)
	expect(is_equal_approx(armored.hp, 1000 - rail.damage), "Railgun firing must use armor-piercing damage")
	reset()
	game.start_wave()
	game.remaining = 1
	game.spawn_clock = 100
	var mender = enemy("regenerating")
	mender.hp = mender.maxhp - 1
	shielded = enemy("shielded")
	shielded.shield = 0
	game._process(1)
	expect(mender.hp == mender.maxhp, "Regeneration must restore health without exceeding maximum hull")
	expect(shielded.shield == 0, "Depleted shields must not regenerate")
	var cryo_index = place("cryostat")
	if cryo_index < 0:
		return
	var cryo = game.towers[cryo_index]
	var boss = enemy("dreadnought")
	for _frame in range(180): game.steer_ship(cryo,boss.node.position,1.0/60.0)
	game.fire(cryo, boss)
	expect(is_equal_approx(boss.factor, .675) and boss.slow == 2, "Boss slowing must apply the explicit 35% resistance")
	cryo.slow_power = .8
	game.fire(cryo, boss)
	var strongest: float = boss.factor
	cryo.slow_power = .5
	game.fire(cryo, boss)
	expect(is_equal_approx(boss.factor, strongest) and boss.slow == 2, "Repeated slow must refresh duration and retain the strongest active factor without multiplicative stacking")
	cryo.cooldown = 100
	boss.distance = 0
	boss.slow = .001
	game._process(.01)
	expect(boss.slow == 0 and is_equal_approx(boss.distance, boss.speed * .01), "Expired slow must restore normal movement")
	var reward = mender.reward
	var credits: int = game.credits
	var kills: int = game.kills
	game.hurt(mender, 100000, true)
	game.hurt(mender, 100000, true)
	game.remove_enemy(mender, true)
	expect(game.credits == credits + reward and game.kills == kills + 1, "Repeated resolution of one enemy must never duplicate kill rewards")


func check_support_and_mounts():
	reset()
	var receiver_index = place("lancer")
	var relay_index = place("support")
	var second_index = place("support")
	if receiver_index < 0 or relay_index < 0 or second_index < 0:
		return
	var receiver = game.towers[receiver_index]
	var relay = game.towers[relay_index]
	var stronger = game.towers[second_index]
	# Controlled relative positions isolate aura range and stacking from placement.
	receiver.node.position = Vector3.ZERO
	relay.node.position = Vector3(2, 0, 0)
	stronger.node.position = Vector3(-2, 0, 0)
	stronger.support_damage = .38
	expect(is_equal_approx(game.support_multiplier(receiver), 1.38), "Overlapping support auras must use the strongest bonus only")
	stronger.node.position = Vector3(20, 0, 0)
	expect(is_equal_approx(game.support_multiplier(receiver), 1.18), "An out-of-range aura must stop affecting a ship")
	expect(is_equal_approx(game.support_multiplier(relay), 1), "A relay must not apply its own aura to itself")
	var target = enemy("raider")
	target.hp = 1000
	target.maxhp = 1000
	target.node.position = Vector3(0, .3, 3)
	game.fire(receiver, target)
	expect(is_equal_approx(target.hp, 1000 - receiver.damage * 1.18), "Support must increase actual weapon damage, not only displayed stats")
	expect(relay.guns.is_empty(), "Support-only Relay must have no offensive weapon assemblies")
	var body: Transform3D = relay.node.transform
	var health: float = target.hp
	var effect_count: int = game.effects.size()
	var shot_count: int = relay.shot
	for i in range(120): game.steer_ship(relay,target.node.position,1.0/60.0)
	game.fire(relay,target)
	game.fire_station_guns(relay,target.node.position)
	expect(relay.node.transform.is_equal_approx(body), "Relay must remain a stationary support platform")
	expect(target.hp == health and game.effects.size() == effect_count and relay.shot == shot_count, "Relay must never fire or damage enemies, including direct attack calls")
	game.start_wave()
	game.remaining = 1
	game.spawn_clock = 100
	game._process(.02)
	expect(relay.shot == 0, "Active combat must keep Relay non-offensive")


func check_terminal_guards():
	for definition in Data.maps():
		if definition.final_wave == 0:
			continue
		reset(definition.id)
		game.wave = definition.final_wave - 1
		game.completed_waves = game.wave
		expect("BOSS" in game.next_wave_preview(), "Final wave preview must announce its boss")
		game.start_wave()
		expect(game.wave == definition.final_wave, "Finite map must start its configured final wave")
		var before: int = game.credits
		game.finish_wave()
		expect(game.active and game.credits == before, "An empty lane must not clear while enemies remain to spawn")
		var last = enemy("raider")
		game.remaining = 0
		game.finish_wave()
		expect(game.active and game.session_state == game.Session.ACTIVE_WAVE, "Final victory must wait for every live enemy to resolve")
		game.hurt(last, 100000, true)
		before = game.credits
		var earned: int = game.wave_data.reward + game.wave_data.bonus
		game.testing = false
		game.finish_wave()
		game.testing = true
		expect(game.session_state == game.Session.VICTORY and not game.active and game.integrity > 0, "Final clear with a surviving core must declare victory")
		expect(game.credits == before + earned and game.completed_waves == definition.final_wave, "Final completion and savings rewards must be applied exactly once")
		var progress: Dictionary = Storage.load_progress()
		expect(progress.has(definition.id) and progress[definition.id].wins == 1, "Each victorious finite map must persist completion separately from saved runs")
		var summary: Dictionary = game.run_summary()
		expect(summary.map_id == definition.id and summary.waves_completed == definition.final_wave and summary.kills == 1 and summary.integrity == game.integrity, "Result summary must report map, completed waves, kills, and surviving core")
		before = game.credits
		game.finish_wave()
		game.start_wave()
		game.testing = false
		game.end_run(true)
		game.testing = true
		expect(game.credits == before and game.wave == definition.final_wave and not game.active, "Victory must block further waves and duplicate rewards")
		expect(Storage.load_progress()[definition.id].wins == 1, "Repeated terminal events must not duplicate persistent victories")
		expect(not game.can_save() and game.next_button.disabled, "Completed runs must disable preparation saves and Next Wave")
	reset()
	game.start_wave()
	game.spawn_clock = 100
	var doomed = enemy("dreadnought")
	var survivor = enemy("raider")
	doomed.distance = doomed.route.get_baked_length() - .001
	game.integrity = 1
	var before: int = game.credits
	game._process(.1)
	expect(game.integrity == 0 and game.session_state == game.Session.DEFEAT and not game.active and game.remaining == 0, "A breached core must end the run immediately and cancel remaining spawns")
	expect(game.credits == before and game.completed_waves == 0, "Defeat must not grant kill or wave-completion rewards")
	var frozen = frozen_snapshot()
	game._process(1)
	game.start_wave()
	game.finish_wave()
	game.end_run(true)
	expect(frozen_snapshot() == frozen and game.session_state == game.Session.DEFEAT, "Defeat must freeze surviving enemies and block subsequent waves, rewards, or victory")
	expect(game.enemies.has(survivor) and not game.can_save(), "A defeated run must keep its result state without allowing preparation saves")
