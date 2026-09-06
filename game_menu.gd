extends CanvasLayer
const Data = preload("res://game_data.gd")
const Storage = preload("res://run_storage.gd")
const Settings = preload("res://game_settings.gd")
var game: Node
var content: Control
var page = ""
var origin = "main"
var confirm_back: Callable

func setup(host: Node):
 game = host
 layer = 10

func is_open() -> bool:
 return content != null and is_instance_valid(content)

func close():
 if is_open():
  content.hide()
  content.queue_free()
 content = null
 page = ""
 for panel in game.hud_panels: panel.show()
 game.toast_label.show()

func screen(title: String, subtitle: String, name: String):
 close()
 page = name
 for panel in game.hud_panels: panel.hide()
 game.toast_label.hide()
 content = Control.new()
 content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 add_child(content)
 var shade = ColorRect.new()
 shade.color = Color(.015,.025,.065,.96)
 shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 content.add_child(shade)
 game.label_at(content,"WORMHOLE / WARDENS",Vector2(64,35),18,Color("74d5e1"))
 game.label_at(content,title,Vector2(64,86),40)
 var sub = game.label_at(content,subtitle,Vector2(66,147),16,Color("9bb1ce"))
 sub.size = Vector2(1300,60)
 sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func action(text: String, pos: Vector2, size: Vector2, callback: Callable, disabled = false) -> Button:
 var button = game.button_at(content,text,pos,size,func():
  game.play_cue("ui")
  callback.call())
 button.disabled = disabled
 return button

func focus_first():
 for control in content.find_children("*","Button",true,false):
  if not control.disabled:
   control.grab_focus()
   return

func show_main():
 origin = "main"
 screen("Defend the outer rim", "Build a fleet. Shape the battle. Keep the core alive.","main")
 var y = 250
 if game.run_available:
  action("CONTINUE / RESUME",Vector2(66,y),Vector2(390,58),game.resume_run)
  y += 72
 action("NEW GAME",Vector2(66,y),Vector2(390,58),show_maps)
 action("LOAD GAME",Vector2(66,y+72),Vector2(390,58),func(): show_slots(false),not has_saves())
 action("SAVE GAME",Vector2(66,y+144),Vector2(390,58),func(): show_slots(true),not game.can_save())
 action("SETTINGS",Vector2(66,y+216),Vector2(390,58),show_settings)
 action("QUIT",Vector2(66,y+288),Vector2(390,58),request_quit)
 var info = game.label_at(content,"MISSION BRIEF\n\nThree finite sectors, plus the original endless corridor.\nSix fleet roles and two exclusive upgrade branches each.\n\nWave starts stay under your control.\nSave between waves, then resume exactly where you left off.\n\nTab / Shift+Tab to navigate • Enter to select • Esc to go back",Vector2(565,264),20,Color("adbed5"))
 info.size = Vector2(770,360)
 info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 focus_first()

func show_maps():
 screen("Choose a sector", "Each map offers different firing windows. Completion is stored separately from saves.","maps")
 var progress = Storage.load_progress()
 var maps = Data.maps()
 for i in range(maps.size()):
  var definition: Dictionary = maps[i]
  var pos = Vector2(66+(i%2)*664,227+(i/2)*269)
  var preview = load("res://map_preview.gd").new()
  preview.definition = definition
  preview.position = pos
  preview.size = Vector2(620,130)
  content.add_child(preview)
  var completed = progress.has(definition.id)
  var title = "%s  •  %s%s" % [definition.name,definition.difficulty,"  ✓ COMPLETE" if completed else ""]
  action(title, pos+Vector2(0,137),Vector2(620,46),func(): confirm_discard(func(): game.start_run(definition.id),"Replace the current run?"))
  game.label_at(content,"%s waves  •  %d credits  •  %d core" % [str(definition.final_wave) if definition.final_wave>0 else "Endless",definition.starting_credits,definition.starting_core],pos+Vector2(5,187),15)
  var description = game.label_at(content,definition.description,pos+Vector2(5,211),13,Color("9bb1ce"))
  description.size = Vector2(610,44)
  description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 action("← BACK",Vector2(66,800),Vector2(200,50),return_origin)
 focus_first()

func show_pause():
 origin = "pause"
 screen("Simulation paused", "%s • Wave %d • Resume at %d× speed. Music continues; combat and effects are frozen." % [game.map_data.name,game.wave,game.game_speed],"pause")
 action("RESUME",Vector2(66,240),Vector2(430,58),game.resume_run)
 action("SAVE GAME",Vector2(66,315),Vector2(430,58),func(): show_slots(true),not game.can_save())
 action("LOAD GAME",Vector2(66,390),Vector2(430,58),func(): show_slots(false),not has_saves())
 action("SETTINGS",Vector2(66,465),Vector2(430,58),show_settings)
 action("RETURN TO MAIN MENU",Vector2(66,540),Vector2(430,58),game.to_main_menu)
 action("QUIT",Vector2(66,615),Vector2(430,58),request_quit)
 game.label_at(content,"SAVING\n\nSaves are available during preparation between waves.\n"+("This run is ready to save." if game.can_save() else "Finish the current wave to save this run.")+"\n\nReturning to the main menu keeps this run in memory.\nStarting another run or quitting can discard unsaved changes.",Vector2(570,280),20,Color("adbed5"))
 focus_first()

func show_slots(saving: bool):
 screen("Save game" if saving else "Load game","Three local slots • Preparation between waves only • A recovery copy protects the previous save.","save" if saving else "load")
 var slots = Storage.list_slots()
 for i in range(slots.size()):
  var entry: Dictionary = slots[i]
  var slot = int(entry.slot)
  var y = 238+i*157
  var description = "Empty slot"
  if entry.exists:
   description = "%s • %s • Wave %d • %s%s" % [entry.get("map_name",entry.get("map_id","Unknown")),entry.get("difficulty",""),entry.get("wave",0),entry.get("timestamp","")," • RECOVERY COPY" if entry.get("recovered",false) else ""] if entry.ok else entry.error
  game.label_at(content,"SLOT %d" % slot,Vector2(66,y),21)
  var detail = game.label_at(content,description,Vector2(66,y+39),15,Color("adbed5"))
  detail.size = Vector2(920,53)
  detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  action("SAVE HERE" if saving else "LOAD",Vector2(1000,y+15),Vector2(168,53),func():
   if saving:
    if entry.exists: confirm_action("Overwrite slot %d?" % slot,"Its previous save will remain as a recovery copy.",func(): save_to(slot),func(): show_slots(true))
    else: save_to(slot)
   else: load_from(slot),not game.can_save() if saving else not entry.ok)
  action("DELETE",Vector2(1190,y+15),Vector2(160,53),func(): confirm_action("Delete slot %d?" % slot,"This removes the save and its recovery copy.",func():
   var result = Storage.delete_slot(slot)
   if not result.ok: show_error(result.error,func(): show_slots(saving))
   else: show_slots(saving),func(): show_slots(saving)),not entry.exists)
 action("← BACK",Vector2(66,800),Vector2(200,50),return_origin)
 focus_first()

func has_saves() -> bool:
 for slot in Storage.list_slots():
  if slot.exists: return true
 return false

func save_to(slot: int):
 if not game.can_save():
  show_error("Finish the current wave before saving.",show_pause)
  return
 var result = Storage.save_slot(slot,game.saved_run())
 if not result.ok:
  show_error(result.error,func(): show_slots(true))
  return
 game.dirty = false
 show_slots(true)

func load_from(slot: int):
 var result = Storage.load_slot(slot)
 if not result.ok:
  show_error(result.error,func(): show_slots(false))
  return
 var error: String = game.validate_run(result.data)
 if not error.is_empty():
  show_error(error,func(): show_slots(false))
  return
 confirm_discard(func():
  var restore_error: String = game.restore_run(result.data)
  if not restore_error.is_empty(): show_error(restore_error,func(): show_slots(false)),"Load slot %d?" % slot)

func show_settings():
 screen("Settings","Changes apply immediately and persist across restarts.","settings")
 var mode = OptionButton.new()
 mode.position = Vector2(66,257)
 mode.size = Vector2(390,50)
 mode.add_item("Windowed")
 mode.add_item("Fullscreen")
 mode.select(1 if game.settings.fullscreen else 0)
 mode.item_selected.connect(func(index):
  if index == 1 and not game.settings.fullscreen:
   var size = DisplayServer.window_get_size()
   game.settings.window_size = [size.x,size.y]
  game.settings.fullscreen = index == 1
  Settings.apply(game.settings)
  persist_settings())
 content.add_child(mode)
 game.label_at(content,"DISPLAY MODE",Vector2(66,215),18)
 for i in range(2):
  var key = "music_enabled" if i == 0 else "sfx_enabled"
  var toggle = CheckButton.new()
  toggle.text = "Music enabled" if i == 0 else "Sound effects enabled"
  toggle.position = Vector2(66,354+i*70)
  toggle.size = Vector2(390,52)
  toggle.button_pressed = game.settings[key]
  toggle.toggled.connect(func(value):
   game.settings[key] = value
   apply_audio_settings())
  content.add_child(toggle)
 for i in range(3):
  var key = ["master_volume","music_volume","sfx_volume"][i]
  var title = ["MASTER","MUSIC","SFX"][i]
  var y = 241+i*132
  var value_label = game.label_at(content,"%s  %d%%" % [title,roundi(game.settings[key]*100)],Vector2(620,y),22)
  var slider = HSlider.new()
  slider.position = Vector2(620,y+51)
  slider.size = Vector2(690,40)
  slider.min_value = 0
  slider.max_value = 100
  slider.step = 1
  slider.value = roundi(game.settings[key]*100)
  slider.value_changed.connect(func(value):
   game.settings[key] = value/100.0
   value_label.text = "%s  %d%%" % [title,value]
   apply_audio_settings())
  content.add_child(slider)
 action("RESTORE DEFAULTS",Vector2(66,658),Vector2(390,55),func():
  game.settings = Settings.defaults()
  Settings.apply(game.settings)
  apply_audio_settings()
  show_settings())
 action("← BACK",Vector2(66,800),Vector2(200,50),return_origin)
 mode.grab_focus()

func apply_audio_settings():
 game.audio.apply_settings(game.settings)
 persist_settings()

func persist_settings():
 var result = Settings.save_settings(game.settings)
 if not result.ok: show_error(result.error,show_settings)

func show_result():
 origin = "result"
 var won: bool = game.session_state == game.Session.VICTORY
 screen("Sector secured" if won else "Core lost",(game.completion_error if not game.completion_error.is_empty() else "Victory recorded. Choose your next mission.") if won else "Review your coverage, then try a different fleet.","result")
 var summary = "%s\n%s difficulty\n\n%d / %s waves completed\n%d enemy ships destroyed\n%d / %d core integrity remaining" % [game.map_data.name,game.map_data.difficulty,game.completed_waves,str(game.map_data.final_wave) if game.map_data.final_wave > 0 else "∞",game.kills,game.integrity,game.map_data.starting_core]
 game.label_at(content,summary,Vector2(66,240),27)
 action("REPLAY THIS MAP",Vector2(785,266),Vector2(550,64),func(): game.start_run(game.map_data.id))
 action("MAP SELECTION",Vector2(785,352),Vector2(550,64),show_maps)
 action("MAIN MENU",Vector2(785,438),Vector2(550,64),game.to_main_menu)
 focus_first()

func confirm_discard(callback: Callable, title: String):
 if game.run_available and game.dirty and game.resume_state not in [game.Session.VICTORY,game.Session.DEFEAT]:
  var previous = page
  confirm_action(title,"Unsaved progress in the current run will be discarded.",callback,func(): restore_page(previous))
 else: callback.call()

func confirm_action(title: String, message: String, callback: Callable, cancel: Callable):
 confirm_back = cancel
 screen(title,message,"confirm")
 action("CANCEL",Vector2(66,270),Vector2(300,60),cancel)
 action("CONFIRM",Vector2(390,270),Vector2(300,60),callback)
 focus_first()

func show_error(message: String, callback: Callable):
 confirm_back = callback
 screen("Unable to complete action",message+" Your current run has been preserved.","error")
 action("← BACK",Vector2(66,280),Vector2(300,60),callback)
 focus_first()

func request_quit():
 confirm_discard(func(): game.get_tree().quit(),"Quit Wormhole Wardens?")

func return_origin():
 match origin:
  "pause": show_pause()
  "result": show_result()
  _: show_main()

func restore_page(previous: String):
 match previous:
  "maps": show_maps()
  "load": show_slots(false)
  "save": show_slots(true)
  "pause": show_pause()
  "result": show_result()
  _: show_main()

func back():
 match page:
  "confirm", "error": confirm_back.call()
  "pause": game.resume_run()
  "main":
   if game.run_available: game.resume_run()
  "result": game.to_main_menu()
  _: return_origin()
