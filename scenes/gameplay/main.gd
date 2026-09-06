extends Node3D

const Data = preload("res://scripts/data/game_data.gd")
const TYPES = Data.TOWERS
enum Session { MAIN_MENU, PREPARATION, ACTIVE_WAVE, PAUSED, VICTORY, DEFEAT }
var session_state = Session.MAIN_MENU
var resume_state = Session.PREPARATION
var run_available = false
var dirty = false
var game_speed = 1.0
var map_data: Dictionary = {}
var wave_data: Dictionary = {}
var map_paths: Array = []
var map_root: Node3D
var enemy_models: Dictionary = {}
var completed_waves = 0
var testing = false
var check_runner: RefCounted
var completion_error = ""
var menu: CanvasLayer
var audio: Node
var settings: Dictionary = {}
var pause_button: Button
var speed_buttons: Array = []
var upgrade_buttons: Array = []
var branch_labels: Array = []
var hud_panels: Array = []
var credits = 440
var integrity = 20
var wave = 0
var kills = 0
var active = false
var spent = false
var remaining = 0
var spawn_clock = 0.0
var elapsed = 0.0
var towers: Array = []
var enemies: Array = []
var effects: Array = []
var path = Curve3D.new()
var camera: Camera3D
var selected = -1
var build_type = -1
var ghost: Node3D
var range_ring: MeshInstance3D
var pointer = Vector3.ZERO
var valid_build = false
var models: Array = []
var station_gun_models: Dictionary = {}
var enemy_model: PackedScene
var stats_label: Label
var wave_label: Label
var status_label: Label
var detail_label: Label
var toast_label: Label
var next_button: Button
var upgrade_a: Button
var upgrade_b: Button
var sell_button: Button
var buy_buttons: Array = []
var toast_time = 0.0
var ui: CanvasLayer
var portals: Array = []
var rng = RandomNumberGenerator.new()
var motes: Array = []
var fx: Node3D
var ui_clock = 0.0

func mat(color: Color) -> StandardMaterial3D:
 var m = StandardMaterial3D.new()
 m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 m.albedo_color = color
 if color.a < 1.0:
  m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 return m

func _ready():
 rng.seed = 7139
 fx = load("res://scripts/effects/space_fx.gd").new()
 add_child(fx)
 for t in TYPES:
  models.append(load("res://assets/models/%s/%s.glb" % [t.model, t.model]))
 enemy_model = load("res://assets/models/raider/raider.glb")
 station_gun_models[2] = load("res://assets/models/nova_gun/nova_gun.glb")
 station_gun_models[3] = load("res://assets/models/cryo_gun/cryo_gun.glb")
 station_gun_models[5] = load("res://assets/models/relay_gun/relay_gun.glb")
 for enemy_id in ["shielded", "regenerator"]:
  enemy_models[enemy_id] = load("res://assets/models/%s/%s.glb" % [enemy_id, enemy_id])
 camera = Camera3D.new()
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 29.0
 camera.position = Vector3(0,40,21)
 add_child(camera)
 camera.look_at(Vector3.ZERO,Vector3.UP)
 var light = DirectionalLight3D.new()
 light.rotation_degrees = Vector3(-55,-25,0)
 light.light_energy = 0.95
 light.shadow_enabled = true
 add_child(light)
 var rim = DirectionalLight3D.new()
 rim.rotation_degrees = Vector3(-25,145,0)
 rim.light_color = Color("6baffe")
 rim.light_energy = .45
 add_child(rim)
 var env = WorldEnvironment.new()
 var e = Environment.new()
 e.background_mode = Environment.BG_COLOR
 e.background_color = Color("060b21")
 e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 e.ambient_light_color = Color("9cb6e8")
 e.ambient_light_energy = 0.55
 var sky = Sky.new()
 var sky_material = ProceduralSkyMaterial.new()
 sky_material.sky_top_color = Color("607899")
 sky_material.sky_horizon_color = Color("a3b4c9")
 sky_material.ground_bottom_color = Color("17243c")
 sky_material.ground_horizon_color = Color("758ca9")
 sky.sky_material = sky_material
 e.sky = sky
 e.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
 env.environment = e
 add_child(env)
 range_ring = ring_mesh(1.0,Color(0.3,0.9,1,0.6))
 add_child(range_ring)
 range_ring.hide()
 testing = Array(OS.get_cmdline_user_args()).any(func(arg): return arg.ends_with("-test") or arg in ["--capture","--ui-capture"])
 make_ui()
 settings = load("res://scripts/services/game_settings.gd").defaults() if testing else load("res://scripts/services/game_settings.gd").load_settings()
 if not testing: load("res://scripts/services/game_settings.gd").apply(settings)
 audio = load("res://scripts/services/game_audio.gd").new()
 add_child(audio)
 audio.setup(settings)
 menu = load("res://scenes/ui/game_menu.gd").new()
 add_child(menu)
 menu.setup(self)
 start_run("endless")
 if not testing:
  run_available = false
  to_main_menu()
 get_tree().auto_accept_quit = false
 refresh_ui()
 if "--smoke-test" in OS.get_cmdline_user_args():
  run_smoke_test.call_deferred()
 elif "--combat-test" in OS.get_cmdline_user_args():
  run_combat_test.call_deferred()
 elif "--vfx-test" in OS.get_cmdline_user_args():
  run_vfx_test.call_deferred()
 elif "--station-test" in OS.get_cmdline_user_args():
  run_station_test.call_deferred()
 elif "--nova-target-test" in OS.get_cmdline_user_args():
  run_nova_target_test.call_deferred()
 elif "--nova-pulse-test" in OS.get_cmdline_user_args():
  run_nova_pulse_test.call_deferred()
 elif "--performance-test" in OS.get_cmdline_user_args():
  run_check("res://tests/performance_test.gd")
 elif "--menu-test" in OS.get_cmdline_user_args():
  run_check("res://tests/menu_test.gd")
 elif "--balance-test" in OS.get_cmdline_user_args():
  run_check("res://tests/balance_test.gd")
 elif "--integration-test" in OS.get_cmdline_user_args():
  run_check("res://tests/integration_test.gd")
 elif "--ui-capture" in OS.get_cmdline_user_args():
  run_check("res://tests/ui_capture.gd")
 elif "--capture" in OS.get_cmdline_user_args():
  capture_preview.call_deferred()

func make_space():
 var backdrop = MeshInstance3D.new()
 var plane = PlaneMesh.new()
 plane.size = Vector2(65,45)
 backdrop.mesh = plane
 backdrop.position.y = -7
 var nebula = ShaderMaterial.new()
 nebula.shader = load("res://assets/shaders/nebula.gdshader")
 nebula.set_shader_parameter("tint",map_data.theme.background)
 backdrop.material_override = nebula
 map_root.add_child(backdrop)
 for i in range(350):
  var s = MeshInstance3D.new()
  var mesh = SphereMesh.new()
  mesh.radius = rng.randf_range(0.015,0.048)
  mesh.height = mesh.radius*2
  mesh.radial_segments = 4
  mesh.rings = 2
  s.mesh = mesh
  s.material_override = mat(Color(0.35+rng.randf()*0.6,0.5+rng.randf()*0.5,1))
  s.position = Vector3(rng.randf_range(-26,26),-2,rng.randf_range(-16,16))
  map_root.add_child(s)
 for i in range(7):
  var haze = MeshInstance3D.new()
  var mesh = CylinderMesh.new()
  mesh.top_radius = 2.8+i*0.75
  mesh.bottom_radius = mesh.top_radius
  mesh.height = .01
  haze.mesh = mesh
  haze.position = Vector3(-11,-1.8-i*.01,-1)
  haze.material_override = mat(Color(.13,.12,.4,.035))
  map_root.add_child(haze)

func make_ribbon(width: float, color: Color, height: float):
 var st = SurfaceTool.new()
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 var pts = path.get_baked_points()
 for i in range(pts.size()-1):
  var side_a = (pts[i+1]-pts[maxi(0,i-1)]).normalized().cross(Vector3.UP)*width
  var side_b = (pts[mini(pts.size()-1,i+2)]-pts[i]).normalized().cross(Vector3.UP)*width
  var a = pts[i]+side_a+Vector3.UP*height
  var b = pts[i]-side_a+Vector3.UP*height
  var c = pts[i+1]+side_b+Vector3.UP*height
  var d = pts[i+1]-side_b+Vector3.UP*height
  var vertices = [a,c,b,b,c,d]
  var uvs = [Vector2(i*.12,0),Vector2((i+1)*.12,0),Vector2(i*.12,1),Vector2(i*.12,1),Vector2((i+1)*.12,0),Vector2((i+1)*.12,1)]
  for j in range(6):
   st.set_uv(uvs[j])
   st.add_vertex(vertices[j])
 var instance = MeshInstance3D.new()
 instance.mesh = st.commit()
 var m = mat(color)
 m.cull_mode = BaseMaterial3D.CULL_DISABLED
 instance.material_override = m
 if width == 0.82:
  var shader_mat = ShaderMaterial.new()
  shader_mat.shader = load("res://assets/shaders/wormhole.gdshader")
  instance.material_override = shader_mat
 map_root.add_child(instance)

func ring_mesh(radius: float, color: Color) -> MeshInstance3D:
 var instance = MeshInstance3D.new()
 var mesh = TorusMesh.new()
 mesh.inner_radius = radius-0.025
 mesh.outer_radius = radius+0.025
 mesh.rings = 64
 mesh.ring_segments = 6
 instance.mesh = mesh
 instance.material_override = mat(color)
 return instance

func panel(pos: Vector2, size: Vector2) -> Panel:
 var p = Panel.new()
 p.position = pos
 p.size = size
 var style = StyleBoxFlat.new()
 style.bg_color = Color(.035,.065,.13,.96)
 style.border_color = Color("253952")
 style.set_border_width_all(1)
 style.set_corner_radius_all(12)
 style.shadow_color = Color(0,0,0,.4)
 style.shadow_size = 6
 p.add_theme_stylebox_override("panel",style)
 ui.add_child(p)
 return p

func label_at(parent: Node, text: String, pos: Vector2, size: int, color = Color("e0ebfa")) -> Label:
 var l = Label.new()
 l.text = text
 l.position = pos
 l.add_theme_font_size_override("font_size",size)
 l.add_theme_color_override("font_color",color)
 parent.add_child(l)
 return l

func button_at(parent: Node, text: String, pos: Vector2, size: Vector2, callback: Callable) -> Button:
 var b = Button.new()
 b.text = text
 b.position = pos
 b.size = size
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 b.add_theme_font_size_override("font_size",16)
 for state in ["normal","hover","pressed","disabled"]:
  var s = StyleBoxFlat.new()
  s.bg_color = Color("172943") if state == "normal" else Color("264663")
  if state == "disabled": s.bg_color = Color("101b2d")
  s.border_color = Color("385571")
  s.set_border_width_all(1)
  s.set_corner_radius_all(7)
  b.add_theme_stylebox_override(state,s)
 var focus_style = StyleBoxFlat.new()
 focus_style.bg_color = Color(0,0,0,0)
 focus_style.border_color = Color("8befff")
 focus_style.set_border_width_all(3)
 focus_style.set_corner_radius_all(7)
 b.add_theme_stylebox_override("focus",focus_style)
 b.pressed.connect(callback)
 parent.add_child(b)
 return b

func make_ui():
 ui = CanvasLayer.new()
 add_child(ui)
 var top = panel(Vector2(22,20),Vector2(1396,82))
 hud_panels.append(top)
 label_at(top,"WORMHOLE / WARDENS",Vector2(22,12),25)
 label_at(top,"OUTER RIM DEFENSE COMMAND",Vector2(23,47),12,Color("6e91b6"))
 stats_label = label_at(top,"",Vector2(475,24),20)
 pause_button = button_at(top,"PAUSE  Esc",Vector2(1235,23),Vector2(145,38),toggle_pause)
 for i in range(3):
  speed_buttons.append(button_at(top,"%d×" % (i+1),Vector2(1020+i*66,23),Vector2(58,38),set_speed.bind(float(i+1))))
 var side = panel(Vector2(1100,118),Vector2(318,760))
 hud_panels.append(side)
 label_at(side,"FLEET FABRICATOR",Vector2(20,14),19)
 label_at(side,"Six roles • two exclusive branches",Vector2(20,41),13,Color("8fa9c9"))
 for i in range(TYPES.size()):
  var t = TYPES[i]
  var b = button_at(side,"%d  %s  %d cr\n%s" % [i+1,t.name,t.cost,t.role],Vector2(16,65+i*54),Vector2(286,49),choose_build.bind(i))
  b.add_theme_font_size_override("font_size",13)
  b.icon = load("res://assets/icons/"+t.model+".png")
  b.expand_icon = true
  b.add_theme_constant_override("icon_max_width",43)
  b.add_theme_constant_override("h_separation",9)
  b.alignment = HORIZONTAL_ALIGNMENT_LEFT
  b.add_theme_color_override("font_color",t.color)
  buy_buttons.append(b)
 label_at(side,"SHIP SYSTEMS / UPGRADE TREE",Vector2(20,402),15)
 detail_label = label_at(side,"",Vector2(20,433),14)
 detail_label.size = Vector2(282,120)
 for branch in range(2):
  var branch_label = label_at(side,"",Vector2(16+branch*147,538),11,TYPES[2].color)
  branch_label.size = Vector2(139,30)
  branch_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
  branch_labels.append(branch_label)
  var column: Array = []
  for tier in range(1,4):
   var b = button_at(side,"",Vector2(16+branch*147,577+(tier-1)*42),Vector2(139,38),upgrade.bind(branch))
   b.add_theme_font_size_override("font_size",12)
   b.focus_entered.connect(func(): notify(b.tooltip_text))
   column.append(b)
  upgrade_buttons.append(column)
 upgrade_a = upgrade_buttons[0][0]
 upgrade_b = upgrade_buttons[1][0]
 sell_button = button_at(side,"",Vector2(16,708),Vector2(286,36),sell_selected)
 var bottom = panel(Vector2(22,748),Vector2(1062,130))
 hud_panels.append(bottom)
 wave_label = label_at(bottom,"",Vector2(20,13),20)
 status_label = label_at(bottom,"",Vector2(20,44),13,Color("91afcf"))
 status_label.size = Vector2(780,54)
 status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 label_at(bottom,"1–6  Build   •   Click  Deploy / inspect   •   Right-click  Cancel   •   Esc / P  Pause",Vector2(20,105),12,Color("6d8bae"))
 next_button = button_at(bottom,"NEXT WAVE →",Vector2(820,28),Vector2(222,60),start_wave)
 toast_label = label_at(ui,"",Vector2(40,124),16,Color("73e6e2"))
 toast_label.size = Vector2(1020,55)
 toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func choose_build(kind: int):
 if not can_manage() or kind < 0 or kind >= TYPES.size(): return
 build_type = kind
 selected = -1
 if is_instance_valid(ghost): ghost.queue_free()
 ghost = make_tower_model(kind)
 add_child(ghost)
 refresh_ui()

func make_tower_model(kind: int) -> Node3D:
 var model: Node3D = models[kind].instantiate()
 if station_gun_models.has(kind):
  for socket in model.find_children("GunSocket_*","Node3D",true,false):
   var gun: Node3D = station_gun_models[kind].instantiate()
   gun.name = "WeaponAssembly"
   socket.add_child(gun)
 return model

func collect_guns(model: Node3D) -> Array:
 var guns: Array = []
 for socket in model.find_children("GunSocket_*","Node3D",true,false):
  var yaw: Node3D = socket.get_node("WeaponAssembly")
  var pitch: Node3D = yaw.find_child("BarrelPivot",true,false)
  guns.append({"yaw":yaw,"pitch":pitch,"home":pitch.position,"recoil":0.0,"muzzles":pitch.find_children("Muzzle_*","Node3D",true,false),"target":null})
 return guns

func cancel_build():
 build_type = -1
 if is_instance_valid(ghost): ghost.queue_free()
 ghost = null
 refresh_ui()

func can_place(p: Vector3) -> bool:
 if not p.is_finite() or absf(p.y) > .01 or map_data.is_empty(): return false
 if not map_data.bounds.has_point(Vector2(p.x,p.z)): return false
 for route in map_paths:
  if p.distance_to(route.get_closest_point(p)) < 1.45: return false
 for t in towers:
  if p.distance_to(t.node.position) < 1.65: return false
 return true

func deploy(kind: int, p: Vector3) -> bool:
 if not can_manage() or kind < 0 or kind >= TYPES.size(): return false
 if credits < TYPES[kind].cost or not can_place(p): return false
 create_tower(kind,p)
 credits -= TYPES[kind].cost
 dirty = true
 play_cue("deploy")
 if active: spent = true
 refresh_ui()
 return true

func create_tower(kind: int, p: Vector3) -> Dictionary:
 var n = make_tower_model(kind)
 n.position = p
 add_child(n)
 var platform = ring_mesh(.93,Color(TYPES[kind].color, .28))
 platform.position.y = .035
 n.add_child(platform)
 var t = {"node":n,"kind":kind,"damage":TYPES[kind].damage,"range":TYPES[kind].range,"rate":TYPES[kind].rate,"cooldown":0.0,"branch":-1,"level":0,"invested":TYPES[kind].cost,"jet_clock":0.0,"guns":collect_guns(n),"shot":0,"pulse_enabled":false,"support":TYPES[kind].get("support",0.0),"slow_power":.5}
 towers.append(t)
 return t

func _unhandled_input(event):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode == KEY_ESCAPE:
   if build_type >= 0:
    cancel_build()
   elif menu != null and menu.is_open(): menu.back()
   else: toggle_pause()
   get_viewport().set_input_as_handled()
   return
  if event.keycode == KEY_P and (menu == null or not menu.is_open()): toggle_pause()
  if can_manage() and event.keycode >= KEY_1 and event.keycode <= KEY_6: choose_build(event.keycode-KEY_1)
 if not can_manage(): return
 if event is InputEventMouseButton and event.pressed:
  if event.button_index == MOUSE_BUTTON_RIGHT: cancel_build()
  if event.button_index == MOUSE_BUTTON_LEFT:
   if build_type >= 0:
    if not deploy(build_type,pointer): notify("Cannot deploy: check credits, lane clearance, and nearby ships.")
   else:
    selected = -1
    for i in range(towers.size()):
     if pointer.distance_to(towers[i].node.position)<1.1: selected=i
    refresh_ui()

func upgrade(branch: int):
 if not can_manage() or selected < 0 or selected >= towers.size() or branch not in [0,1]: return
 var t = towers[selected]
 var cost = upgrade_cost(t)
 if t.level >= 3 or credits < cost or (t.branch >= 0 and t.branch != branch): return
 credits -= cost
 t.invested += cost
 t.branch = branch
 t.level += 1
 if active: spent = true
 apply_upgrade(t,Data.upgrade_for(TYPES[t.kind].id,branch,t.level))
 dirty = true
 play_cue("upgrade")
 notify("%s upgraded to tier %d" % [TYPES[t.kind].name,t.level])
 refresh_ui()

func apply_upgrade(t: Dictionary, spec: Dictionary):
 t.damage *= spec.get("damage_multiplier",1.0)
 t.range += spec.get("range_add",0.0)
 t.rate *= spec.get("rate_multiplier",1.0)
 t.support += spec.get("support_add",0.0)
 t.slow_power += spec.get("slow_add",0.0)
 t.pulse_enabled = t.pulse_enabled or spec.get("pulse_unlock",false)

func upgrade_cost(t: Dictionary) -> int:
 var spec = Data.upgrade_for(TYPES[t.kind].id,maxi(t.branch,0),t.level+1)
 return int(spec.get("cost",0))

func sell_selected():
 if not can_manage() or selected < 0 or selected >= towers.size(): return
 var t = towers[selected]
 dirty = true
 play_cue("salvage")
 credits += int(t.invested*.65)
 t.node.queue_free()
 towers.remove_at(selected)
 selected = -1
 refresh_ui()

func start_wave():
 if active or session_state != Session.PREPARATION or integrity <= 0: return
 if map_data.final_wave > 0 and wave >= map_data.final_wave: return
 wave_data = Data.wave_for(map_data.id,wave+1)
 if wave_data.is_empty(): return
 cancel_build()
 active = true
 session_state = Session.ACTIVE_WAVE
 spent = false
 wave += 1
 remaining = wave_data.spawns.size()
 spawn_clock = 0
 dirty = true
 play_cue("wave_start")
 notify("Incoming wave %d · %s" % [wave,"DREADNOUGHT DETECTED" if wave_data.spawns.has("dreadnought") else "Hostile signatures approaching"])
 refresh_ui()

func spawn_enemy(enemy_id = ""):
 var spec_wave = wave_data if not wave_data.is_empty() else Data.wave_for(map_data.id,maxi(1,wave))
 var spawn_index = clampi(spec_wave.spawns.size()-remaining,0,spec_wave.spawns.size()-1)
 if enemy_id.is_empty():
  enemy_id = spec_wave.spawns[spawn_index]
 var spec = Data.enemy_for_wave(enemy_id,map_data.id,maxi(1,wave))
 spec.speed *= spec_wave.spawn_speed_multipliers[spawn_index]
 var n: Node3D = enemy_models.get(spec.model,enemy_model).instantiate()
 add_child(n)
 var elite: bool = enemy_id == "dreadnought"
 n.scale = Vector3.ONE*(1.7 if elite else (1.05 if enemy_id == "armored" else .7)) if map_data.legacy else Vector3.ONE*spec.scale
 var bar = MeshInstance3D.new()
 var bm = BoxMesh.new()
 bm.size = Vector3(1,.02,.10)
 bar.mesh = bm
 bar.material_override = mat(Color("ff6581"))
 add_child(bar)
 var route: Curve3D = map_paths[(spec_wave.spawns.size()-remaining)%map_paths.size()]
 var status: MeshInstance3D = ring_mesh(.9,spec.color)
 status.visible = spec.shield > 0 or spec.regen > 0 or enemy_id == "swift"
 n.add_child(status)
 n.position = route.sample_baked(0)+Vector3.UP*.3
 enemies.append({"id":enemy_id,"node":n,"hp":spec.hp,"maxhp":spec.hp,"distance":0.0,"speed":spec.speed,"slow":0.0,"factor":1.0,"reward":spec.reward,"elite":elite,"bar":bar,"jet_clock":0.0,"route":route,"armor":spec.armor,"shield":spec.shield,"maxshield":spec.shield,"regen":spec.regen,"slow_resist":spec.slow_resist,"core_damage":spec.core_damage,"status":status})

func _process(delta):
 if toast_time > 0:
  toast_time -= delta
  if toast_time<=0: toast_label.text=""
 if session_state not in [Session.PREPARATION,Session.ACTIVE_WAVE]: return
 delta *= game_speed
 elapsed += delta
 fx.update(delta)
 for t in towers:
  for gun in t.guns:
   gun.recoil = move_toward(gun.recoil,0,delta*.4)
   gun.pitch.position = gun.home-Vector3(0,0,gun.recoil)
 for i in range(motes.size()):
  var d = fmod(i*path.get_baked_length()/motes.size()+elapsed*2.4,path.get_baked_length())
  motes[i].position = path.sample_baked(d)+Vector3(0,.08,sin(elapsed*1.2+i)*.45)
 var mouse = get_viewport().get_mouse_position()
 var hit = Plane(Vector3.UP,0).intersects_ray(camera.project_ray_origin(mouse),camera.project_ray_normal(mouse))
 if hit != null: pointer = hit
 if is_instance_valid(ghost):
  ghost.position = pointer
  valid_build = can_place(pointer) and credits >= TYPES[build_type].cost
  ghost.visible = mouse.x < 1090 and mouse.y > 105 and mouse.y < 743
  range_ring.visible = ghost.visible
  range_ring.position = pointer+Vector3.UP*.06
  range_ring.scale = Vector3.ONE*TYPES[build_type].range
  range_ring.material_override = mat(Color("54e5b1") if valid_build else Color("ff526c"))
 elif selected >= 0 and selected < towers.size():
  range_ring.show()
  range_ring.position = towers[selected].node.position+Vector3.UP*.06
  range_ring.scale = Vector3.ONE*towers[selected].range
  range_ring.material_override = mat(TYPES[towers[selected].kind].color)
 else: range_ring.hide()
 for i in range(portals.size()):
  portals[i].scale = Vector3.ONE*(1+sin(elapsed*2+i)*.12)
 for effect in effects.duplicate():
  effect.life -= delta
  if effect.has("expand"):
   effect.node.scale = (effect.node.scale + Vector3.ONE*delta*effect.expand).max(Vector3.ONE*.01)
  if effect.life <= 0:
   effect.node.queue_free()
   effects.erase(effect)
 if not active or integrity <= 0: return
 spawn_clock -= delta
 if remaining > 0 and spawn_clock <= 0:
  spawn_enemy()
  remaining -= 1
  spawn_clock += wave_data.interval
 for e in enemies.duplicate():
  e.slow = max(0,e.slow-delta)
  e.distance += e.speed*delta*(e.factor if e.slow>0 else 1.0)
  e.hp = minf(e.maxhp,e.hp+e.regen*delta)
  e.status.visible = e.shield > 0 or e.regen > 0 or e.id == "swift"
  if e.distance >= e.route.get_baked_length():
   integrity = maxi(0,integrity-e.core_damage)
   dirty = true
   play_cue("core_damage")
   remove_enemy(e,false)
   if integrity<=0:
    end_run(false)
    return
   continue
  var pos = e.route.sample_baked(e.distance)
  var forward = e.route.sample_baked(min(e.distance+.15,e.route.get_baked_length()))
  e.node.position = pos+Vector3.UP*.3
  # Blender's -Y bow becomes +Z after glTF export; aim the model's front.
  if pos.distance_to(forward)>.001: e.node.look_at(forward+Vector3.UP*.3,Vector3.UP,true)
  e.bar.position = pos + Vector3(0,1,-.75)
  e.bar.scale.x = max(.01,e.hp/e.maxhp)
  e.bar.material_override.albedo_color = Color("62cfff") if e.shield>0 else (Color("8aff99") if e.regen>0 else Color("ff6581"))
  e.jet_clock -= delta
  if e.jet_clock <= 0:
   e.jet_clock = .06
   for side in [-1,1]:
    fx.jet(e.node.to_global(Vector3(side*.4,.24,-.65)),-e.node.global_basis.z.normalized(),Color("ff647e"),2)
 for t in towers:
  t.cooldown -= delta
  if t.kind == 2: assign_nova_targets(t)
  var target = null
  for e in enemies:
   if e.node.position.distance_to(t.node.position)<=t.range:
    if target == null or e.distance>target.distance: target=e
  if target != null:
   var aligned = steer_ship(t,target.node.position,delta)
   if t.cooldown <= 0 and aligned:
    fire(t,target)
    t.cooldown = t.rate
 if remaining == 0 and enemies.is_empty(): finish_wave()
 ui_clock -= delta
 if ui_clock <= 0:
  refresh_ui()
  ui_clock = .1

func steer_ship(t: Dictionary, target_pos: Vector3, delta: float) -> bool:
 if t.kind == 2:
  var ready = false
  for gun in t.guns:
   if gun.target != null and enemies.has(gun.target):
    var aligned = aim_station_gun(gun,gun.target.node.position+Vector3.UP*.25,delta)
    ready = ready or aligned
  return ready
 if t.kind in [3,5]: return aim_station_guns(t,target_pos+Vector3.UP*.25,delta)
 var direction = target_pos-t.node.position
 var desired = atan2(direction.x,direction.z)
 var error = wrapf(desired-t.node.rotation.y,-PI,PI)
 var step = clampf(error,-delta*2.8,delta*2.8)
 t.node.rotate_y(step)
 t.jet_clock -= delta
 var turn = signf(step)
 var reversed = turn != t.get("rcs_turn",0.0)
 # Track actual rotation, including small per-frame corrections to moving targets.
 # An aiming-error dead zone can hide jets throughout a long, gradual turn.
 if t.kind == 0 and absf(step) > .000001 and (t.jet_clock <= 0 or reversed):
  play_cue("thruster")
  t.jet_clock = .035
  t.rcs_turn = turn
  # Exhaust opposite the required force: bow and stern jets produce a turning couple.
  # Keep both mirrored emitter pairs outside the detailed hull and nozzle rims.
  var side = -turn
  var basis = t.node.global_basis.orthonormalized()
  fx.jet(t.node.to_global(Vector3(side*.70,.29,.55)),basis.x*side,Color("83ecff"),4)
  fx.jet(t.node.to_global(Vector3(-side*.70,.29,-.5)),-basis.x*side,Color("83ecff"),3)
 return absf(error-step)<.20

func assign_nova_targets(t: Dictionary):
 var candidates: Array = []
 for e in enemies:
  if e.node.position.distance_to(t.node.position)<=t.range: candidates.append(e)
 candidates.sort_custom(func(a,b): return a.distance>b.distance)
 var claimed: Array = []
 # Keep valid, distinct locks so guns do not jitter between enemies every frame.
 for gun in t.guns:
  if gun.target != null and candidates.has(gun.target) and not claimed.has(gun.target):
   claimed.append(gun.target)
  else: gun.target = null
 for gun in t.guns:
  if gun.target != null: continue
  for e in candidates:
   if not claimed.has(e):
    gun.target = e
    claimed.append(e)
    break
  # Spare guns can share a lock when fewer than four enemies are in range.
  if gun.target == null and not candidates.is_empty(): gun.target = candidates[0]

func aim_station_gun(gun: Dictionary, target_pos: Vector3, delta: float) -> bool:
 # Traverse is local to each mounting socket; the station body never rotates.
 var local_target: Vector3 = gun.yaw.get_parent().to_local(target_pos)
 var desired = atan2(local_target.x,local_target.z)
 var error = wrapf(desired-gun.yaw.rotation.y,-PI,PI)
 gun.yaw.rotation.y += clampf(error,-delta*4.4,delta*4.4)
 var elevation: Vector3 = gun.yaw.to_local(target_pos)-gun.pitch.position
 var pitch = -atan2(elevation.y,Vector2(elevation.x,elevation.z).length())
 gun.pitch.rotation.x = move_toward(gun.pitch.rotation.x,clampf(pitch,-.6,.6),delta*3.5)
 return absf(wrapf(desired-gun.yaw.rotation.y,-PI,PI))<.15

func aim_station_guns(t: Dictionary, target_pos: Vector3, delta: float) -> bool:
 var ready = false
 for gun in t.guns:
  var aligned = aim_station_gun(gun,target_pos,delta)
  ready = ready or aligned
 return ready

func fire_station_guns(t: Dictionary, target_pos: Vector3, independent = false):
 for gun in t.guns:
  var aim_pos = target_pos
  if independent:
   if gun.target == null or not enemies.has(gun.target): continue
   if gun.target.node.position.distance_to(t.node.position)>t.range: continue
   aim_pos = gun.target.node.position+Vector3.UP*.25
  var forward: Vector3 = gun.pitch.global_basis.z.normalized()
  var toward: Vector3 = (aim_pos-gun.pitch.global_position).normalized()
  if forward.dot(toward)<.96: continue
  var muzzle: Node3D = gun.muzzles[t.shot%gun.muzzles.size()]
  beam(muzzle.global_position,aim_pos,TYPES[t.kind].color,.028,.16)
  fx.jet(muzzle.global_position,forward,TYPES[t.kind].color,3)
  gun.recoil = .045
  # Nova's independently aimed beams are its default damage source.
  if independent: hurt(gun.target,t.damage*support_multiplier(t))

func fire(t: Dictionary, target: Dictionary):
 var origin = t.node.position+Vector3.UP*.5
 var end = target.node.position
 var damage: float = t.damage*support_multiplier(t)
 play_cue(["laser","missile","laser","cryo","railgun","support"][t.kind])
 t.shot += 1
 if t.kind in [0,1,4]:
  origin = t.node.to_global(Vector3(0,.35,1.05))
 if t.kind == 4:
  var muzzle = t.node.find_child("Muzzle_0",true,false)
  if muzzle != null: origin = muzzle.global_position
 if t.kind == 2:
  fire_station_guns(t,end+Vector3.UP*.25,true)
  if t.pulse_enabled:
   play_cue("pulse")
   pulse(t.node.position,t.range,TYPES[t.kind].color)
   for e in enemies.duplicate():
    if e.node.position.distance_to(t.node.position)<=t.range: hurt(e,damage)
 elif t.kind == 1:
  beam(origin,end,TYPES[1].color,.07,.22)
  pulse(end,1.5,Color("ffac55"))
  for e in enemies.duplicate():
   if e.node.position.distance_to(end)<1.5: hurt(e,damage)
 else:
  if t.kind in [3,5]: fire_station_guns(t,end+Vector3.UP*.25)
  else: beam(origin,end,TYPES[t.kind].color,.065 if t.kind == 4 else .035,.20 if t.kind == 4 else .13)
  if t.kind == 3:
   var factor = 1.0-minf(.85,t.slow_power)*(1.0-target.slow_resist)
   target.factor = minf(target.factor,factor) if target.slow > 0 else factor
   target.slow = 2.0
  hurt(target,damage,t.kind == 4)

func beam(a: Vector3, b: Vector3, color: Color, thickness: float, life: float):
 var n = MeshInstance3D.new()
 var mesh = CylinderMesh.new()
 mesh.top_radius = thickness
 mesh.bottom_radius = thickness
 mesh.height = a.distance_to(b)
 n.mesh = mesh
 n.material_override = mat(color)
 add_child(n)
 n.position = (a+b)*.5
 var direction = (b-a).normalized()
 n.quaternion = Quaternion(Vector3.UP,direction)
 effects.append({"node":n,"life":life})
 var halo = n.duplicate()
 halo.mesh = mesh.duplicate()
 halo.mesh.top_radius = thickness*3.5
 halo.mesh.bottom_radius = thickness*3.5
 halo.material_override = mat(Color(color,.16))
 add_child(halo)
 effects.append({"node":halo,"life":life})

func pulse(pos: Vector3, radius: float, color: Color):
 var n = ring_mesh(.3,color)
 n.position = pos+Vector3.UP*.2
 add_child(n)
 effects.append({"node":n,"life":.3,"expand":radius*8})

func hurt(e: Dictionary, damage: float, armor_piercing = false):
 if not enemies.has(e): return
 var absorbed = minf(e.shield,damage)
 e.shield -= absorbed
 damage -= absorbed
 if damage > 0: e.hp -= damage if armor_piercing else maxf(1.0,damage-e.armor)
 fx.sparks(e.node.position+Vector3.UP*.25)
 play_cue("impact")
 if e.hp <= 0: remove_enemy(e,true)

func remove_enemy(e: Dictionary, killed: bool):
 if not enemies.has(e): return
 if killed:
  dirty = true
  play_cue("implosion")
  credits += e.reward
  kills += 1
  fx.implode(e.node.position,e.elite)
  var collapse = ring_mesh(1.5 if e.elite else .95,Color("a2a4ff"))
  collapse.position = e.node.position
  add_child(collapse)
  effects.append({"node":collapse,"life":.48,"expand":-2.0})
 e.node.queue_free()
 e.bar.queue_free()
 enemies.erase(e)

func finish_wave():
 if not active or integrity <= 0 or remaining > 0 or not enemies.is_empty(): return
 active = false
 session_state = Session.PREPARATION
 completed_waves = wave
 var base: int = wave_data.reward
 var bonus: int = wave_data.bonus if not spent else 0
 credits += base+bonus
 dirty = true
 play_cue("wave_complete")
 if bonus > 0: play_cue("bonus")
 notify("Wave %d cleared  +%d cr   |   %s" % [wave,base,"No-purchase bonus +%d cr" % bonus if bonus>0 else "No-purchase bonus forfeited"])
 if map_data.final_wave > 0 and wave >= map_data.final_wave: end_run(true)
 refresh_ui()

func notify(message: String):
 toast_label.text = message
 toast_time = 7

func refresh_ui():
 if stats_label == null or map_data.is_empty(): return
 stats_label.text = "%04d  CREDITS   %02d / %d  CORE   %d  KILLS" % [credits,integrity,map_data.starting_core,kills]
 var state_name = Session.keys()[session_state].replace("_"," ")
 wave_label.text = "%s  •  WAVE %d / %s  •  %s" % [map_data.name,wave,str(map_data.final_wave) if map_data.final_wave>0 else "∞",state_name]
 status_label.text = "%d incoming · %d in lane   |   Savings bonus: %s" % [remaining,enemies.size(),"forfeited" if spent else "+%d cr" % wave_data.get("bonus",0)] if active else next_wave_preview()
 next_button.disabled = session_state != Session.PREPARATION or active or integrity <= 0
 next_button.text = "WAVE IN PROGRESS" if active else "NEXT WAVE %02d  →" % (wave+1)
 if session_state in [Session.VICTORY,Session.DEFEAT]: next_button.text = "RUN COMPLETE"
 pause_button.text = "RESUME" if session_state == Session.PAUSED else "PAUSE  Esc"
 pause_button.disabled = session_state not in [Session.PREPARATION,Session.ACTIVE_WAVE,Session.PAUSED]
 for i in range(3):
  speed_buttons[i].text = ("● " if game_speed == i+1 else "")+"%d×" % (i+1)
  speed_buttons[i].disabled = not can_manage()
 for i in range(TYPES.size()): buy_buttons[i].disabled = credits<TYPES[i].cost or not can_manage()
 for label in branch_labels: label.hide()
 for column in upgrade_buttons:
  for b in column: b.hide()
 sell_button.hide()
 if build_type >= 0:
  var t = TYPES[build_type]
  detail_label.text = "%s / DEPLOYMENT\nDamage %.0f  ·  Range %.1f\nCooldown %.2fs\n%s\nGreen ring = valid placement" % [t.name,t.damage,t.range,t.rate,t.role]
 elif selected >= 0 and selected<towers.size():
  var t = towers[selected]
  detail_label.text = "%s  /  TIER %d\nDamage %.1f  ·  Range %.1f\nCooldown %.2fs\n%s" % [TYPES[t.kind].name,t.level,t.damage,t.range,t.rate,"Choose a branch (hover for effects)" if t.branch<0 else TYPES[t.kind].branches[t.branch]]
  if t.kind == 2: detail_label.text += "\nPulse: " + ("ONLINE" if t.pulse_enabled else "LOCKED")
  if t.kind == 5: detail_label.text += "\nNearby damage +%d%% (strongest only)" % roundi(t.support*100)
  for branch in range(2):
   branch_labels[branch].text = ("A · " if branch == 0 else "B · ")+TYPES[t.kind].branches[branch]
   branch_labels[branch].show()
   for tier in range(1,4):
    var b: Button = upgrade_buttons[branch][tier-1]
    var spec = Data.upgrade_for(TYPES[t.kind].id,branch,tier)
    var bought: bool = t.branch == branch and t.level >= tier
    var locked: bool = (t.branch >= 0 and t.branch != branch) or tier > t.level+1
    var state = "PURCHASED" if bought else ("LOCKED" if locked else ("NEED CREDITS" if credits < spec.cost else "%d cr" % spec.cost))
    b.text = "%s %d\n%s" % ["A" if branch == 0 else "B",tier,state]
    b.tooltip_text = "%s • Tier %d • %d credits\n%s\nDamage %.1f → %.1f | Range %.2f → %.2f | Cooldown %.2fs → %.2fs\nRequires previous tier; choosing a branch locks the other." % [TYPES[t.kind].branches[branch],tier,spec.cost,spec.description,t.damage,t.damage*spec.get("damage_multiplier",1.0),t.range,t.range+spec.get("range_add",0.0),t.rate,t.rate*spec.get("rate_multiplier",1.0)]
    b.disabled = bought or locked or credits<spec.cost or not can_manage()
    b.show()
  sell_button.show()
  sell_button.disabled = not can_manage()
  sell_button.text = "Salvage ship  +%d cr" % int(t.invested*.65)
 else:
  detail_label.text = "Select a ship to inspect its systems.\n\nSix nodes show both upgrade branches.\nHover or focus a node for its exact effect.\nEach branch has three tiers."

func run_smoke_test():
 assert(not can_place(path.sample_baked(10)))
 assert(deploy(0,Vector3(-16,0,-5)))
 selected = 0
 upgrade(1)
 assert(towers[0].branch == 1 and towers[0].level == 1)
 var previous = credits
 upgrade(0)
 assert(credits == previous)
 start_wave()
 assert(active and wave == 1)
 spawn_enemy()
 var reward = enemies[0].reward
 previous = credits
 hurt(enemies[0],100000)
 assert(credits == previous+reward and kills == 1)
 remaining = 0
 previous = credits
 finish_wave()
 assert(credits == previous+43+55)
 start_wave()
 credits = 1000
 assert(deploy(1,Vector3(-8,0,-8)))
 assert(spent)
 remaining = 0
 previous = credits
 finish_wave()
 assert(credits == previous+51)
 print("SMOKE TEST PASSED: placement, branches, wave start, kills, savings bonus, spending forfeiture")
 get_tree().quit()

func seed_test_fleet():
 credits = 100000
 for entry in [[0,Vector3(-17,0,-2)],[1,Vector3(-12,0,1)],[2,Vector3(-4,0,-1)],[3,Vector3(3,0,0)],[0,Vector3(8,0,3)]]:
  var p: Vector3 = entry[1]
  for offset in range(20):
   if can_place(p): break
   p = entry[1] + Vector3(0,0,offset*.3)
  assert(deploy(entry[0],p),"Invalid test fleet placement")
 assert(towers.size()==5)
 credits = 250

func run_combat_test():
 set_process(false)
 seed_test_fleet()
 credits = 10000
 for i in range(towers.size()):
  selected = i
  upgrade(0)
  upgrade(0)
  upgrade(0)
 for w in range(5):
  start_wave()
  var frames = 0
  while active and frames < 24000:
   _process(1.0/60.0)
   frames += 1
   if frames%300 == 0: await get_tree().process_frame
  assert(not active,"Wave timed out")
  assert(integrity>0,"Fleet failed early waves")
  print("COMBAT wave %d completed; core=%d kills=%d credits=%d" % [wave,integrity,kills,credits])
 assert(wave==5 and kills>50)
 for t in towers: t.node.queue_free()
 towers.clear()
 integrity = 1
 start_wave()
 spawn_enemy()
 enemies[0].distance = path.get_baked_length()
 _process(.1)
 assert(integrity==0 and not active)
 var old_wave = wave
 start_wave()
 assert(wave==old_wave)
 print("COMBAT TEST PASSED: five waves, all weapon types, boss wave, game-over lock")
 get_tree().quit()

func capture_preview():
 start_run("twin_rift")
 seed_test_fleet()
 credits = 1500
 for kind in [4,5]:
  var placed = false
  for x in range(2,9):
   for z in range(-5,6):
    if not placed and deploy(kind,Vector3(x,0,z)): placed = true
 wave = 6
 start_wave()
 set_process(false)
 for i in range(1300):
  _process(1.0/60.0)
  if i%60 == 0: await get_tree().process_frame
 selected = 2
 refresh_ui()
 toast_label.text = "Hold the corridor. Protect the core."
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://docs/screenshots/gameplay.png")
 print("PREVIEW SAVED")
 get_tree().quit()

func run_vfx_test():
 set_process(false)
 assert(deploy(0,Vector3(-16,0,-5)))
 var t = towers[0]
 for direction in [-1.0,1.0]:
  t.node.rotation.y = 0
  t.jet_clock = 0
  fx.particles.clear()
  steer_ship(t,t.node.position+Vector3(direction*4,0,0),.1)
  assert(signf(t.node.rotation.y)==direction)
  assert(absf(t.node.rotation.y)<=.281,"Rotation must be gradual")
  assert(fx.particles.size()==7)
  for particle in fx.particles:
   var lever: Vector3 = particle.pos-t.node.position
   var reaction: Vector3 = -particle.vel
   assert(signf(lever.cross(reaction).y)==direction,"Thruster torque must match the turn")
 # A reversal must immediately light the opposite nozzles, even during cooldown.
 fx.particles.clear()
 t.jet_clock = .035
 steer_ship(t,t.node.position+Vector3(-4,0,0),.001)
 assert(fx.particles.size()==7,"Clockwise reversal must emit immediately")
 for particle in fx.particles:
  var local_pos: Vector3 = t.node.to_local(particle.pos)
  assert(absf(local_pos.x)>.67,"Thrusters must clear the model's nozzle rims")
  assert(signf(local_pos.x)==(1.0 if local_pos.z>0 else -1.0),"Clockwise turn needs the opposite bow/stern pair")
 fx.particles.clear()
 steer_ship(t,t.node.position+Vector3(4,0,0),.001)
 assert(fx.particles.size()==7,"Counterclockwise reversal must also emit immediately")
 for particle in fx.particles:
  var local_pos: Vector3 = t.node.to_local(particle.pos)
  assert(signf(local_pos.x)==(-1.0 if local_pos.z>0 else 1.0),"Counterclockwise turn needs the mirrored bow/stern pair")
 # Real tracking often turns only a fraction of a degree per frame. Test both
 # directions at normal frame rates, including turns across the +/-PI boundary.
 for starting_heading in [0.0,PI-.02,-PI+.02]:
  for direction in [-1.0,1.0]:
   t.node.rotation.y = starting_heading
   t.jet_clock = 0
   fx.particles.clear()
   for i in range(1,61):
    var angle = starting_heading+direction*i*.003
    var tracking_target: Vector3 = t.node.position+Vector3(sin(angle)*4,0,cos(angle)*4)
    steer_ship(t,tracking_target,1.0/60.0)
   assert(fx.particles.size()>=100,"Gradual tracking must keep pulsing the turning jets")
   var count = fx.particles.size()
   var stationary_target: Vector3 = t.node.position+t.node.basis.z.normalized()*4
   for i in range(10): steer_ship(t,stationary_target,1.0/60.0)
   assert(fx.particles.size()==count,"Stationary ships must not fire maneuvering jets")
 fx.particles.clear()
 spawn_enemy()
 enemies[0].node.position = Vector3(-9,.3,3)
 hurt(enemies[0],1)
 assert(fx.particles.size()==14,"Nonlethal hits must emit sparks")
 fx.particles.clear()
 hurt(enemies[0],1e9)
 var inward = []
 for particle in fx.particles:
  if particle.center != Vector3.INF:
   inward.append({"particle":particle,"radius":particle.pos.distance_to(particle.center)})
 assert(inward.size()==36,"Destroyed ships must implode")
 fx.update(.12)
 for entry in inward:
  assert(entry.particle.pos.distance_to(entry.particle.center)<entry.radius,"Implosion must move inward")
 fx.update(2)
 assert(fx.particles.is_empty(),"Particles must expire")
 print("VFX TEST PASSED: left/right torque, reversals, gradual tracking across angle wrap, stationary cutoff, hit sparks, inward collapse, cleanup")
 get_tree().quit()

func run_station_test():
 set_process(false)
 credits = 1000
 assert(deploy(2,Vector3(-16,0,-5)))
 assert(deploy(3,Vector3(-8,0,-8)))
 for t in towers:
  assert(t.guns.size()==(4 if t.kind==2 else 2),"Each station needs its separate gun assemblies")
  var body_basis: Basis = t.node.basis
  for target_offset in [Vector3(3,.7,2),Vector3(-3,.2,-2)]:
   var target: Vector3 = t.node.position+target_offset
   for i in range(100): aim_station_guns(t,target,.016)
   assert(t.node.basis.is_equal_approx(body_basis),"Station body must remain fixed")
   for gun in t.guns:
    assert(gun.muzzles.size()>0)
    var aim: Vector3 = gun.pitch.global_basis.z.normalized()
    var direction: Vector3 = (target-gun.pitch.global_position).normalized()
    assert(aim.dot(direction)>.995,"Gun barrel must point at the enemy in 3D")
    assert(gun.muzzles[0].global_position.distance_to(gun.pitch.global_position)>.3)
  var count = effects.size()
  fire_station_guns(t,t.node.position+Vector3(-3,.2,-2))
  assert(effects.size()>count,"Shots must originate from the attached gun muzzles")
 print("STATION TEST PASSED: separate guns, yaw/elevation, stationary bodies, muzzle effects")
 get_tree().quit()

func run_nova_target_test():
 set_process(false)
 credits = 1000
 assert(deploy(2,Vector3(-16,0,-5)))
 var t = towers[0]
 var offsets = [Vector3(-2,.3,0),Vector3(2,.3,0),Vector3(0,.3,-2),Vector3(0,.3,2)]
 for i in range(4):
  spawn_enemy()
  enemies[i].node.position = t.node.position+offsets[i]
  enemies[i].distance = i
 assign_nova_targets(t)
 var locks: Array = []
 for gun in t.guns:
  assert(gun.target != null and not locks.has(gun.target),"Four guns must lock four different enemies")
  locks.append(gun.target)
 assign_nova_targets(t)
 for i in range(4): assert(t.guns[i].target==locks[i],"Valid locks must remain stable")
 for i in range(100): steer_ship(t,enemies[0].node.position,.016)
 for gun in t.guns:
  var toward: Vector3 = (gun.target.node.position+Vector3.UP*.25-gun.pitch.global_position).normalized()
  assert(gun.pitch.global_basis.z.normalized().dot(toward)>.995,"Each barrel must aim at its own lock")
 var hp: float = enemies[0].hp
 var effect_count = effects.size()
 fire(t,enemies[0])
 assert(effects.size()==effect_count+8,"All four aimed guns must fire without a default area pulse")
 for e in enemies: assert(is_equal_approx(e.hp,hp-t.damage),"Each gun must damage its own target")
 var survivor = enemies[0]
 for e in enemies.duplicate():
  if e!=survivor: remove_enemy(e,false)
 assign_nova_targets(t)
 for gun in t.guns: assert(gun.target==survivor,"Guns must reacquire after targets disappear")
 survivor.node.position=t.node.position+Vector3(t.range+.6,0,0)
 assign_nova_targets(t)
 for gun in t.guns: assert(gun.target==null,"Out-of-range enemies must lose their locks")
 selected=0
 upgrade(1)
 assign_nova_targets(t)
 for gun in t.guns: assert(gun.target==survivor,"Every gun must use the upgraded range")
 remove_enemy(survivor,false)
 assign_nova_targets(t)
 for gun in t.guns: assert(gun.target==null)
 print("NOVA TARGET TEST PASSED: distinct stable locks, independent gun damage, no default pulse, reacquisition, upgraded range")
 get_tree().quit()

func run_nova_pulse_test():
 set_process(false)
 credits = 10000
 assert(deploy(2,Vector3(-16,0,-5)))
 var t = towers[0]
 for i in range(6):
  spawn_enemy()
  var angle = i*TAU/6
  enemies[i].node.position = t.node.position+Vector3(sin(angle)*2,.3,cos(angle)*2)
  enemies[i].hp = 1000
  enemies[i].distance = i
 var outside = enemies[5]
 outside.node.position = t.node.position+Vector3(t.range+2,.3,0)
 assign_nova_targets(t)
 for i in range(100): steer_ship(t,enemies[0].node.position,.016)
 assert(not t.pulse_enabled)
 fire(t,enemies[0])
 var hits = 0
 for e in enemies:
  if e.hp<1000: hits+=1
 assert(hits==4,"Default Nova may only damage its four gun targets")
 assert(enemies[0].hp==1000 and outside.hp==1000,"Unselected and out-of-range enemies must receive no area damage")
 selected=0
 active=true
 spent=false
 var previous = credits
 var price = upgrade_cost(t)
 upgrade(0)
 assert(t.pulse_enabled and t.level==1 and t.branch==0)
 assert(credits==previous-price and spent,"Pulse purchase must charge credits and forfeit the wave savings bonus")
 assert(t.damage==TYPES[2].damage,"First pulse upgrade unlocks the weapon without a hidden gun damage increase")
 for e in enemies: e.hp=1000
 fire(t,enemies[0])
 for e in enemies:
  if e==outside:
   assert(e.hp==1000)
  else:
   var locked=false
   for gun in t.guns:
    if gun.target==e: locked=true
   assert(is_equal_approx(e.hp,1000-t.damage*(2 if locked else 1)),"Pulse adds one area hit alongside gun damage")
 upgrade(0)
 assert(t.pulse_enabled and is_equal_approx(t.damage,TYPES[2].damage*1.65))
 assert(deploy(2,Vector3(-8,0,-8)))
 selected=1
 upgrade(1)
 assert(not towers[1].pulse_enabled,"Range upgrades must not unlock the pulse")
 previous=credits
 upgrade(0)
 assert(not towers[1].pulse_enabled and credits==previous,"The alternate branch must remain exclusive")
 print("NOVA PULSE TEST PASSED: guns-only default, paid pulse unlock, additional area damage, upgrades, range boundaries, savings forfeiture")
 get_tree().quit()

func can_manage() -> bool:
 return run_available and integrity > 0 and session_state in [Session.PREPARATION,Session.ACTIVE_WAVE]

func start_run(map_id: String):
 var definition = Data.map_by_id(map_id)
 if definition.is_empty(): return
 clear_run()
 map_data = definition
 credits = definition.starting_credits
 integrity = definition.starting_core
 wave = 0
 completed_waves = 0
 completion_error = ""
 kills = 0
 spent = false
 active = false
 remaining = 0
 spawn_clock = 0
 elapsed = 0
 wave_data = {}
 run_available = true
 dirty = false
 session_state = Session.PREPARATION
 resume_state = session_state
 game_speed = 1.0
 configure_map()
 if menu != null: menu.close()
 if audio != null:
  audio.set_paused(false)
  if not testing: audio.set_music("game")
 refresh_ui()

func clear_run():
 if is_instance_valid(ghost): ghost.queue_free()
 ghost = null
 build_type = -1
 selected = -1
 for t in towers: t.node.queue_free()
 towers.clear()
 for enemy in enemies:
  enemy.node.queue_free()
  enemy.bar.queue_free()
 enemies.clear()
 for effect in effects: effect.node.queue_free()
 effects.clear()
 fx.particles.clear()
 fx.update(0)
 motes.clear()
 portals.clear()
 map_paths.clear()
 if is_instance_valid(map_root): map_root.free()
 if range_ring != null: range_ring.hide()

func configure_map():
 map_root = Node3D.new()
 map_root.name = "MapScenery"
 add_child(map_root)
 make_space()
 for points in map_data.paths:
  var route = Curve3D.new()
  for point in points: route.add_point(point)
  map_paths.append(route)
  path = route
  make_ribbon(1.30,Color(.12,.3,.6,.11),-.19)
  make_ribbon(1.04,map_data.theme.lane,-.15)
  make_ribbon(.82,Color("244066"),-.12)
  make_ribbon(.64,Color("153147"),-.10)
  make_ribbon(.035,map_data.theme.accent,-.07)
  for d in [0.0,route.get_baked_length()]:
   var r = ring_mesh(1.2,map_data.theme.accent)
   r.position = route.sample_baked(d)+Vector3.UP*.1
   map_root.add_child(r)
   portals.append(r)
   var marker = Label3D.new()
   marker.text = "RIFT ENTRY" if d == 0.0 else "CORE GATE"
   marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
   marker.font_size = 36
   marker.pixel_size = .01
   marker.position = r.position+Vector3(0,.3,-1.75)
   marker.modulate = map_data.theme.accent
   map_root.add_child(marker)
 path = map_paths[0]
 for i in range(36):
  var mote = MeshInstance3D.new()
  var sphere = SphereMesh.new()
  sphere.radius = .045
  sphere.height = .09
  sphere.radial_segments = 6
  sphere.rings = 3
  mote.mesh = sphere
  mote.material_override = mat(map_data.theme.accent)
  map_root.add_child(mote)
  motes.append(mote)

func next_wave_preview() -> String:
 if session_state == Session.VICTORY: return "Sector secured. Replay this map or choose another from the results menu."
 if session_state == Session.DEFEAT: return "Core lost. Rebuild your strategy and try again from the results menu."
 var upcoming = Data.wave_for(map_data.id,wave+1)
 if upcoming.is_empty(): return "All waves complete."
 var counts: Dictionary = {}
 for id in upcoming.spawns: counts[id] = counts.get(id,0)+1
 var descriptions = PackedStringArray()
 for id in counts: descriptions.append("%d %s" % [counts[id],Data.enemy_by_id(id).name])
 return ("BOSS WARNING • " if counts.has("dreadnought") else "Next: ")+", ".join(descriptions)+". Clear: %d cr + %d if no combat purchases." % [upcoming.reward,upcoming.bonus]

func support_multiplier(tower: Dictionary) -> float:
 var boost = 0.0
 for source in towers:
  if source == tower or source.support <= boost: continue
  if source.node.position.distance_to(tower.node.position) <= source.range: boost = source.support
 return 1.0+boost

func set_speed(value: float):
 if not can_manage() or value not in [1.0,2.0,3.0]: return
 game_speed = value
 dirty = true
 refresh_ui()

func toggle_pause():
 if session_state == Session.PAUSED:
  resume_run()
 elif session_state in [Session.PREPARATION,Session.ACTIVE_WAVE]:
  cancel_build()
  resume_state = session_state
  session_state = Session.PAUSED
  if audio != null: audio.set_paused(true)
  if menu != null: menu.show_pause()
  refresh_ui()

func resume_run():
 if not run_available: return
 session_state = resume_state
 if menu != null: menu.close()
 if audio != null:
  audio.set_paused(false)
  if not testing: audio.set_music("game")
 if session_state in [Session.VICTORY,Session.DEFEAT] and menu != null: menu.show_result()
 refresh_ui()

func to_main_menu():
 if session_state not in [Session.PAUSED,Session.MAIN_MENU]: resume_state = session_state
 session_state = Session.MAIN_MENU
 cancel_build()
 if audio != null:
  audio.set_paused(true)
  if not testing: audio.set_music("menu")
 if menu != null: menu.show_main()
 refresh_ui()

func end_run(won: bool):
 if session_state in [Session.VICTORY,Session.DEFEAT]: return
 active = false
 remaining = 0
 cancel_build()
 session_state = Session.VICTORY if won else Session.DEFEAT
 resume_state = session_state
 if won and not testing:
  var result = load("res://scripts/services/run_storage.gd").record_completion(map_data.id,run_summary())
  if not result.ok: completion_error = "Victory! Completion could not be saved: "+result.error
 play_cue("victory" if won else "defeat")
 if menu != null: menu.show_result()
 refresh_ui()

func run_summary() -> Dictionary:
 return {"map_id":map_data.id,"map_name":map_data.name,"difficulty":map_data.difficulty,"waves_completed":completed_waves,"kills":kills,"integrity":integrity}

func can_save() -> bool:
 var phase = resume_state if session_state in [Session.PAUSED,Session.MAIN_MENU] else session_state
 return run_available and phase == Session.PREPARATION and not active and enemies.is_empty() and remaining == 0 and integrity > 0

func saved_run() -> Dictionary:
 var records: Array = []
 for t in towers:
  records.append({"type_id":TYPES[t.kind].id,"position":[t.node.position.x,0,t.node.position.z],"branch":t.branch,"branch_id":TYPES[t.kind].branch_ids[t.branch] if t.branch >= 0 else "","tier":t.level})
 return {"map_id":map_data.id,"map_name":map_data.name,"difficulty":map_data.difficulty,"wave":wave,"credits":credits,"integrity":integrity,"kills":kills,"spent":false,"speed":game_speed,"towers":records}

func validate_run(data: Dictionary) -> String:
 var schema_error = load("res://scripts/services/run_storage.gd").validate_run(data)
 if not schema_error.is_empty(): return schema_error
 var definition = Data.map_by_id(data.get("map_id",""))
 if definition.is_empty(): return "This save refers to an unknown map."
 if data.wave < 0 or (definition.final_wave>0 and data.wave>=definition.final_wave): return "This run is beyond its final playable wave."
 if data.integrity < 1 or data.integrity > definition.starting_core: return "The saved core integrity is invalid."
 var occupied: Array = []
 for record in data.towers:
  var kind = Data.tower_index(record.type_id)
  if kind < 0: return "This save refers to an unknown tower."
  var branch_id = record.get("branch_id","")
  if (record.tier == 0 and branch_id != "") or (record.tier > 0 and not TYPES[kind].branch_ids.has(branch_id)): return "The saved upgrade branch is incompatible."
  var pos = Vector3(record.position[0],record.position[1],record.position[2])
  if absf(pos.y) > .01 or not definition.bounds.has_point(Vector2(pos.x,pos.z)): return "A saved tower is outside the map."
  for points in definition.paths:
   var route = Curve3D.new()
   for point in points: route.add_point(point)
   if pos.distance_to(route.get_closest_point(pos)) < 1.45: return "A saved tower overlaps a wormhole lane."
  for other in occupied:
   if pos.distance_to(other) < 1.65: return "Saved towers overlap."
  occupied.append(pos)
 return ""

func restore_run(data: Dictionary) -> String:
 var error = validate_run(data)
 if not error.is_empty(): return error
 start_run(data.map_id)
 for record in data.towers:
  var kind = Data.tower_index(record.type_id)
  var t = create_tower(kind,Vector3(record.position[0],record.position[1],record.position[2]))
  t.branch = TYPES[kind].branch_ids.find(record.get("branch_id",""))
  for tier in range(1,int(record.tier)+1):
   t.level = tier
   var spec = Data.upgrade_for(TYPES[kind].id,t.branch,tier)
   t.invested += spec.cost
   apply_upgrade(t,spec)
 credits = int(data.credits)
 integrity = int(data.integrity)
 kills = int(data.kills)
 wave = int(data.wave)
 completed_waves = wave
 spent = false
 game_speed = float(data.speed)
 dirty = false
 refresh_ui()
 return ""

func play_cue(id: String):
 if audio != null and not testing: audio.cue(id)

func _notification(what):
 if what == NOTIFICATION_WM_CLOSE_REQUEST and menu != null:
  if can_manage(): toggle_pause()
  menu.request_quit()

func run_check(script_path: String):
 check_runner = load(script_path).new()
 check_runner.run.call_deferred(self)
