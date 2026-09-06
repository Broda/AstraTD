extends RefCounted
func run(game: Node):
 game.set_process(false)
 game.audio.set_paused(true)
 var shots = [["main",Vector2i(1440,900)],["maps",Vector2i(960,600)],["settings",Vector2i(1280,800)],["game",Vector2i(1440,900)],["pause",Vector2i(960,600)],["result",Vector2i(1280,800)]]
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
   "pause": game.toggle_pause()
   "result":
    game.session_state = game.Session.VICTORY
    game.completed_waves = 10
    game.menu.show_result()
  await game.get_tree().process_frame
  await RenderingServer.frame_post_draw
  game.get_viewport().get_texture().get_image().save_png("res://work/ui_"+shot[0]+".png")
 game.settings.fullscreen = true
 load("res://game_settings.gd").apply(game.settings)
 game.menu.show_settings()
 await game.get_tree().process_frame
 await RenderingServer.frame_post_draw
 game.get_viewport().get_texture().get_image().save_png("res://work/ui_fullscreen.png")
 game.settings.fullscreen = false
 load("res://game_settings.gd").apply(game.settings)
 await game.get_tree().process_frame
 print("UI CAPTURES PASSED")
 game.get_tree().quit()
