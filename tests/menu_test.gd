extends RefCounted
## UI signal regression: run through main.gd with --headless -- --menu-test.
const Storage = preload("res://scripts/services/run_storage.gd")
const Settings = preload("res://scripts/services/game_settings.gd")
const Data = preload("res://scripts/data/game_data.gd")
var game: Node
var failures := 0

func check(condition: bool, message: String) -> void:
 if not condition:
  failures += 1
  push_error(message)

func button(prefix: String, occurrence := 0) -> Button:
 if not game.menu.is_open(): return null
 for control in game.menu.content.find_children("*", "Button", true, false):
  if control.text.begins_with(prefix):
   if occurrence == 0: return control
   occurrence -= 1
 return null

func press(prefix: String, occurrence := 0) -> void:
 var control := button(prefix, occurrence)
 check(control != null, "Missing menu action: " + prefix)
 if control == null: return
 check(not control.disabled, "Menu action unexpectedly disabled: " + prefix)
 if control.disabled: return
 control.pressed.emit()
 await game.get_tree().process_frame

func escape() -> void:
 var event := InputEventKey.new()
 event.keycode = KEY_ESCAPE
 event.pressed = true
 game._unhandled_input(event)
 await game.get_tree().process_frame

func focused_page(expected: String) -> void:
 check(game.menu.page == expected, "Expected menu page " + expected + ", got " + game.menu.page)
 if not game.menu.is_open(): return
 var focused: Control = game.get_viewport().gui_get_focus_owner()
 check(focused != null and game.menu.content.is_ancestor_of(focused), "Current page must own visible keyboard focus.")
 for control in game.menu.content.find_children("*", "Button", true, false):
  check(control.position.x >= 0 and control.position.y >= 0 and control.position.x + control.size.x <= 1440 and control.position.y + control.size.y <= 900, "Menu button must fit the design viewport: " + control.text)

func run(host: Node) -> void:
 game = host
 game.set_process(false)
 var original_root: String = Storage.storage_root
 var original_settings: Dictionary = game.settings.duplicate(true)
 Storage.storage_root = "user://wardens_menu_test_%d" % OS.get_process_id()
 game.run_available = false
 game.to_main_menu()
 await game.get_tree().process_frame
 focused_page("main")
 check(button("CONTINUE") == null and button("SAVE GAME").disabled and button("LOAD GAME").disabled, "Initial main menu must disable unavailable save/load actions.")
 await press("NEW GAME")
 focused_page("maps")
 var first_map: Dictionary = Data.maps()[0]
 var second_map: Dictionary = Data.maps()[1]
 await press(first_map.name)
 check(game.map_data.id == first_map.id and game.session_state == game.Session.PREPARATION and not game.menu.is_open(), "Selecting a map must enter fresh preparation.")
 game.set_speed(3.0)
 game.choose_build(0)
 await escape()
 check(game.build_type == -1 and game.session_state == game.Session.PREPARATION, "First Escape must cancel construction before pausing.")
 await escape()
 focused_page("pause")
 check(game.session_state == game.Session.PAUSED and not button("SAVE GAME").disabled, "Preparation pause must permit saving.")
 await press("SAVE GAME")
 focused_page("save")
 await press("SAVE HERE")
 check(Storage.load_slot(1).ok and not game.dirty, "Save action must persist the selected slot and clear dirty state.")
 var first_balance: int = int(Storage.load_slot(1).data.credits)
 game.credits += 25
 game.dirty = true
 await press("SAVE HERE")
 focused_page("confirm")
 await press("CANCEL")
 check(Storage.load_slot(1).data.credits == first_balance and game.dirty, "Cancel overwrite must preserve the existing save and dirty run.")
 await press("SAVE HERE")
 await press("CONFIRM")
 check(Storage.load_slot(1).data.credits == first_balance + 25 and not game.dirty, "Confirm overwrite must store the new preparation snapshot.")
 await escape()
 focused_page("pause")
 await press("SETTINGS")
 focused_page("settings")
 var toggles: Array = game.menu.content.find_children("*", "CheckButton", true, false)
 check(toggles.size() == 2, "Settings must expose independent music/SFX toggles.")
 toggles[0].button_pressed = false
 toggles[1].button_pressed = false
 check(not game.settings.music_enabled and not game.settings.sfx_enabled, "Each toggle must update its own setting.")
 check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")) and AudioServer.is_bus_mute(AudioServer.get_bus_index("SFX")), "Toggles must immediately mute both requested buses.")
 var sliders: Array = game.menu.content.find_children("*", "HSlider", true, false)
 check(sliders.size() == 3, "Settings must expose three separate volume controls.")
 for index in range(3): sliders[index].value = [37, 23, 64][index]
 var persisted := Settings.load_settings()
 check(is_equal_approx(persisted.master_volume, .37) and is_equal_approx(persisted.music_volume, .23) and is_equal_approx(persisted.sfx_volume, .64), "Slider callbacks must persist distinct volume values.")
 check(not persisted.music_enabled and not persisted.sfx_enabled, "Volume changes must retain independent enable toggles.")
 var modes: Array = game.menu.content.find_children("*", "OptionButton", true, false)
 check(modes.size() == 1 and modes[0].item_count == 2, "Fullscreen and Windowed must be one mutually exclusive selection.")
 await press("RESTORE DEFAULTS")
 focused_page("settings")
 persisted = Settings.load_settings()
 check(persisted.music_enabled and persisted.sfx_enabled and is_equal_approx(persisted.master_volume, .8), "Restore Defaults must apply and persist defaults.")
 await escape()
 focused_page("pause")
 await press("RETURN TO MAIN MENU")
 focused_page("main")
 check(game.game_speed == 3.0, "Menu navigation must preserve selected speed.")
 game.dirty = true
 await press("NEW GAME")
 focused_page("maps")
 await press(second_map.name)
 focused_page("confirm")
 await escape()
 focused_page("maps")
 check(game.map_data.id == first_map.id and game.credits == first_balance + 25, "Cancel replacement must preserve the live run.")
 await press(second_map.name)
 await press("CONFIRM")
 check(game.map_data.id == second_map.id and game.wave == 0 and not game.menu.is_open(), "Confirmed replacement must start the selected map exactly once.")
 game.set_speed(2.0)
 game.toggle_pause()
 await press("LOAD GAME")
 await press("LOAD")
 focused_page("confirm")
 await press("CANCEL")
 check(game.map_data.id == second_map.id and game.dirty, "Cancel load must preserve the current map and unsaved progress.")
 await press("LOAD")
 await press("CONFIRM")
 check(game.map_data.id == first_map.id and game.credits == first_balance + 25 and game.game_speed == 3.0 and not game.dirty, "Confirmed load must restore map, balance, speed, and clean state.")
 var bad: Dictionary = game.saved_run().duplicate(true)
 bad.map_id = "missing_content_map"
 check(Storage.save_slot(2, bad).ok, "Schema-valid unknown content fixture should be writable for UI validation.")
 game.toggle_pause()
 await press("LOAD GAME")
 await press("LOAD", 1)
 focused_page("error")
 check(game.map_data.id == first_map.id and game.credits == first_balance + 25, "Unknown save content must display an error without changing the run.")
 await escape()
 focused_page("load")
 await press("DELETE", 1)
 focused_page("confirm")
 await press("CANCEL")
 check(Storage.load_slot(2).ok, "Cancel delete must preserve the slot.")
 await press("DELETE", 1)
 await press("CONFIRM")
 check(not Storage.load_slot(2).ok and Storage.load_slot(1).ok, "Confirmed deletion must remove only its selected slot.")
 var corrupt_path: String = Storage.storage_root.path_join("slot_3.json")
 var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
 corrupt_file.store_string("{interrupted")
 corrupt_file.close()
 game.menu.show_slots(false)
 await game.get_tree().process_frame
 check(button("LOAD", 2).disabled and not button("DELETE", 2).disabled, "Corrupt slots must show disabled Load and permit confirmed deletion.")
 game.menu.return_origin()
 await press("RETURN TO MAIN MENU")
 game.dirty = true
 await press("QUIT")
 focused_page("confirm")
 await escape()
 focused_page("main")
 check(game.run_available, "Cancel quit must preserve the current run.")
 Storage.record_completion(first_map.id, {"waves_completed": first_map.final_wave, "kills": 10, "integrity": 5})
 await press("NEW GAME")
 check("COMPLETE" in button(first_map.name).text, "Map selection must read separate completion progress by map ID.")
 await escape()
 await press("CONTINUE")
 check(game.session_state == game.Session.PREPARATION and not game.menu.is_open(), "Continue must restore the prior preparation phase.")
 game.start_wave()
 game.toggle_pause()
 await game.get_tree().process_frame
 check(button("SAVE GAME").disabled, "Combat pause must clearly disable preparation-only saves.")
 var simulation_time: float = game.elapsed
 game._process(1.0)
 check(game.elapsed == simulation_time and game.session_state == game.Session.PAUSED, "Pause-menu interaction must leave the simulation frozen.")
 await press("RESUME")
 check(game.session_state == game.Session.ACTIVE_WAVE and game.game_speed == 3.0, "Resume must restore combat and its previous speed.")
 check(not game.get_tree().auto_accept_quit, "Operating-system close must pass through game confirmation.")
 game.dirty = true
 game._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
 await game.get_tree().process_frame
 focused_page("confirm")
 check(game.session_state == game.Session.PAUSED, "Window close must pause combat while confirming unsaved progress.")
 await press("CANCEL")
 focused_page("pause")
 await press("RESUME")
 game.end_run(false)
 await game.get_tree().process_frame
 focused_page("result")
 await press("REPLAY THIS MAP")
 check(game.session_state == game.Session.PREPARATION and game.wave == 0 and game.kills == 0 and not game.menu.is_open(), "Results replay must clear the previous run.")
 game.menu.close()
 game.clear_run()
 game.audio.set_paused(true)
 game.audio.set_music("")
 game.audio.queue_free()
 await game.get_tree().process_frame
 await game.get_tree().create_timer(.25).timeout
 var directory := DirAccess.open(Storage.storage_root)
 if directory != null:
  for filename in directory.get_files(): directory.remove(filename)
  DirAccess.remove_absolute(Storage.storage_root)
 Storage.storage_root = original_root
 game.settings = original_settings
 if failures == 0:
  print("MENU TEST PASSED: button signals, keyboard Back/focus, map replacement, pause/resume, save/load/overwrite/delete confirmations, corrupt slots, settings, completion badges, replay")
 game.get_tree().quit(0 if failures == 0 else 1)
