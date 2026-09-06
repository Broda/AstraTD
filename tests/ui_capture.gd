extends RefCounted
func run(game: Node):
 game.set_process(false)
 game.audio.set_paused(true)
 var camera_transform: Transform3D = game.camera.transform
 var camera_size: float = game.camera.size
 var shots = [["main",Vector2i(1440,900)],["maps",Vector2i(960,600)],["settings",Vector2i(1280,800)],["game",Vector2i(1440,900)],["drones",Vector2i(1440,900)],["pause",Vector2i(960,600)],["result",Vector2i(1280,800)]]
 for shot in shots:
  DisplayServer.window_set_size(shot[1])
  match shot[0]:
   "main": game.to_main_menu()
   "maps": game.menu.show_maps()
   "settings": game.menu.show_settings()
   "game":
    game.start_run("cobalt_bend")
    game.seed_test_fleet()
    game.selected = 2
    game.refresh_ui()
   "drones":
    game.credits = 2000
    game.selected = 2
    for tier in range(3): game.upgrade(2)
    var nova: Dictionary = game.towers[2]
    game.start_wave()
    game.spawn_enemy("armored")
    game.remaining = 0
    var target: Dictionary = game.enemies[0]
    target.maxhp = 100000.0
    target.hp = target.maxhp
    target.speed = 0.0
    target.distance = target.route.get_closest_offset(nova.node.position)
    for frame in range(240):
     game._process(1.0/60.0)
     await game.get_tree().process_frame
    assert(nova.drones.size() == 3 and nova.drone_shots > 0,"Capture must show functional paid drones")
    for drone in nova.drones: assert(drone.shots > 0,"Every drone must have attacked")
    var focus: Vector3 = (nova.node.position + target.node.position)*.5
    game.camera.position = focus + Vector3(0,18,13)
    game.camera.look_at(focus,Vector3.UP)
    game.camera.size = 13.0
    game.refresh_ui()
    game.fleet_panel.tier_buttons[2][2].grab_focus()
    for frame in range(5): await game.get_tree().process_frame
   "pause": game.toggle_pause()
   "result":
    game.session_state = game.Session.VICTORY
    game.completed_waves = 10
    game.menu.show_result()
  await game.get_tree().process_frame
  await RenderingServer.frame_post_draw
  game.get_viewport().get_texture().get_image().save_png("res://work/ui_"+shot[0]+".png")
  game.camera.transform = camera_transform
  game.camera.size = camera_size
 game.settings.fullscreen = true
 load("res://scripts/services/game_settings.gd").apply(game.settings)
 game.menu.show_settings()
 await game.get_tree().process_frame
 await RenderingServer.frame_post_draw
 game.get_viewport().get_texture().get_image().save_png("res://work/ui_fullscreen.png")
 game.settings.fullscreen = false
 load("res://scripts/services/game_settings.gd").apply(game.settings)
 await game.get_tree().process_frame
 game.clear_run()
 game.audio.queue_free()
 await game.get_tree().process_frame
 await game.get_tree().create_timer(.25).timeout
 print("UI CAPTURES PASSED")
 game.get_tree().quit()
