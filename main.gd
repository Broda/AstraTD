extends Node3D

const TYPES = [
 {"name":"LANCER", "role":"Laser frigate", "model":"lancer", "cost":100, "damage":14.0, "range":5.1, "rate":0.48, "color":Color("55deff"), "branches":["Overcharged beams", "Long-range optics"]},
 {"name":"BASTION", "role":"Missile cruiser · splash", "model":"bastion", "cost":170, "damage":42.0, "range":6.4, "rate":1.65, "color":Color("ffb454"), "branches":["Heavy warheads", "Rapid launchers"]},
 {"name":"NOVA", "role":"Pulse station · area attack", "model":"nova", "cost":210, "damage":19.0, "range":3.8, "rate":1.05, "color":Color("b58aff"), "branches":["Singularity core", "Expanded field"]},
 {"name":"CRYOSTAT", "role":"Frost station · slows ships", "model":"cryostat", "cost":140, "damage":5.0, "range":4.6, "rate":0.7, "color":Color("62ffc1"), "branches":["Deep freeze", "Combat coolant"]}
]
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
 fx = load("res://space_fx.gd").new()
 add_child(fx)
 for t in TYPES:
  models.append(load("res://assets/" + t.model + ".glb"))
 enemy_model = load("res://assets/raider.glb")
 station_gun_models[2] = load("res://assets/nova_gun.glb")
 station_gun_models[3] = load("res://assets/cryo_gun.glb")
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
 make_space()
 for i in range(181):
  var x = -20.0 + i * 30.0 / 180.0
  path.add_point(Vector3(x,0,sin((x+18)*0.38)*5.1 + sin((x+20)*0.8)*0.7))
 make_ribbon(1.30,Color(.12,.3,.6,.11),-0.19)
 make_ribbon(1.12,Color(.16,.45,.7,.18),-0.17)
 make_ribbon(1.04,Color("102b52"),-0.15)
 make_ribbon(0.82,Color("244066"),-0.12)
 make_ribbon(0.64,Color("153147"),-0.10)
 make_ribbon(0.035,Color("6ddedb"),-0.07)
 for i in range(36):
  var mote = MeshInstance3D.new()
  var mesh = SphereMesh.new()
  mesh.radius = .045
  mesh.height = .09
  mesh.radial_segments = 6
  mesh.rings = 3
  mote.mesh = mesh
  mote.material_override = mat(Color("9bffe9"))
  add_child(mote)
  motes.append(mote)
 for d in [0.0,path.get_baked_length()]:
  var r = ring_mesh(1.2,Color("82f2ff"))
  r.position = path.sample_baked(d) + Vector3.UP*0.1
  add_child(r)
  portals.append(r)
  for j in range(3):
   var orbit = ring_mesh(.72+j*.16,Color(.24,.75,1,.5))
   orbit.rotation_degrees.x = 24+j*17
   orbit.rotation_degrees.z = j*45
   r.add_child(orbit)
  var marker = Label3D.new()
  marker.text = "RIFT ENTRY" if d == 0.0 else "CORE GATE"
  marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
  marker.font_size = 42
  marker.pixel_size = .01
  marker.position = r.position+Vector3(0,.3,-1.75)
  marker.modulate = Color("78cdda")
  add_child(marker)
 range_ring = ring_mesh(1.0,Color(0.3,0.9,1,0.6))
 add_child(range_ring)
 range_ring.hide()
 make_ui()
 refresh_ui()
 if "--smoke-test" in OS.get_cmdline_user_args():
  run_smoke_test.call_deferred()
 elif "--combat-test" in OS.get_cmdline_user_args():
  run_combat_test.call_deferred()
 elif "--vfx-test" in OS.get_cmdline_user_args():
  run_vfx_test.call_deferred()
 elif "--station-test" in OS.get_cmdline_user_args():
  run_station_test.call_deferred()
 elif "--capture" in OS.get_cmdline_user_args():
  capture_preview.call_deferred()

func make_space():
 var backdrop = MeshInstance3D.new()
 var plane = PlaneMesh.new()
 plane.size = Vector2(65,45)
 backdrop.mesh = plane
 backdrop.position.y = -7
 var nebula = ShaderMaterial.new()
 nebula.shader = load("res://nebula.gdshader")
 backdrop.material_override = nebula
 add_child(backdrop)
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
  add_child(s)
 for i in range(7):
  var haze = MeshInstance3D.new()
  var mesh = CylinderMesh.new()
  mesh.top_radius = 2.8+i*0.75
  mesh.bottom_radius = mesh.top_radius
  mesh.height = .01
  haze.mesh = mesh
  haze.position = Vector3(-11,-1.8-i*.01,-1)
  haze.material_override = mat(Color(.13,.12,.4,.035))
  add_child(haze)

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
  shader_mat.shader = load("res://wormhole.gdshader")
  instance.material_override = shader_mat
 add_child(instance)

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
 b.pressed.connect(callback)
 parent.add_child(b)
 return b

func make_ui():
 ui = CanvasLayer.new()
 add_child(ui)
 var top = panel(Vector2(22,20),Vector2(1396,82))
 label_at(top,"WORMHOLE / WARDENS",Vector2(22,12),25)
 label_at(top,"OUTER RIM DEFENSE COMMAND",Vector2(23,47),12,Color("6e91b6"))
 stats_label = label_at(top,"",Vector2(530,24),23)
 var side = panel(Vector2(1100,118),Vector2(318,760))
 label_at(side,"FLEET FABRICATOR",Vector2(20,18),19)
 label_at(side,"Deploy beyond the wormhole lane",Vector2(20,46),13,Color("8fa9c9"))
 for i in range(4):
  var t = TYPES[i]
  var descriptions = ["Precision laser · 5.1 range","Splash missiles · 6.4 range","Area pulse · 3.8 range","Slow beam · 4.6 range"]
  var b = button_at(side,"%s  %d cr\n%s" % [t.name,t.cost,descriptions[i]],Vector2(16,78+i*72),Vector2(286,62),choose_build.bind(i))
  b.add_theme_font_size_override("font_size",14)
  b.icon = load("res://assets/icons/"+t.model+".png")
  b.expand_icon = true
  b.add_theme_constant_override("icon_max_width",52)
  b.add_theme_constant_override("h_separation",9)
  b.alignment = HORIZONTAL_ALIGNMENT_LEFT
  b.add_theme_color_override("font_color",t.color)
  buy_buttons.append(b)
 label_at(side,"SHIP SYSTEMS",Vector2(20,385),17)
 detail_label = label_at(side,"",Vector2(20,418),15)
 upgrade_a = button_at(side,"",Vector2(16,540),Vector2(286,57),upgrade.bind(0))
 upgrade_b = button_at(side,"",Vector2(16,605),Vector2(286,57),upgrade.bind(1))
 sell_button = button_at(side,"",Vector2(16,680),Vector2(286,40),sell_selected)
 var bottom = panel(Vector2(22,768),Vector2(1062,110))
 wave_label = label_at(bottom,"",Vector2(20,15),21)
 status_label = label_at(bottom,"",Vector2(20,48),14,Color("91afcf"))
 label_at(bottom,"1–4  Build    •    Click  Deploy / inspect    •    Right-click / Esc  Cancel",Vector2(20,79),12,Color("6d8bae"))
 next_button = button_at(bottom,"NEXT WAVE  →",Vector2(820,23),Vector2(222,60),start_wave)
 toast_label = label_at(ui,"",Vector2(40,124),17,Color("73e6e2"))
 button_at(top,"RESTART",Vector2(1270,23),Vector2(108,36),func(): get_tree().reload_current_scene())

func choose_build(kind: int):
 if integrity <= 0: return
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
  guns.append({"yaw":yaw,"pitch":pitch,"home":pitch.position,"recoil":0.0,"muzzles":pitch.find_children("Muzzle_*","Node3D",true,false)})
 return guns

func cancel_build():
 build_type = -1
 if is_instance_valid(ghost): ghost.queue_free()
 ghost = null
 refresh_ui()

func can_place(p: Vector3) -> bool:
 if p.x < -21 or p.x > 10.5 or abs(p.z)>10.3: return false
 if p.distance_to(path.get_closest_point(p)) < 1.45: return false
 for t in towers:
  if p.distance_to(t.node.position) < 1.65: return false
 return true

func deploy(kind: int, p: Vector3) -> bool:
 if credits < TYPES[kind].cost or not can_place(p): return false
 var n = make_tower_model(kind)
 n.position = p
 add_child(n)
 var platform = ring_mesh(.93,Color(TYPES[kind].color, .28))
 platform.position.y = .035
 n.add_child(platform)
 var t = {"node":n,"kind":kind,"damage":TYPES[kind].damage,"range":TYPES[kind].range,"rate":TYPES[kind].rate,"cooldown":0.0,"branch":-1,"level":0,"invested":TYPES[kind].cost,"jet_clock":0.0,"guns":collect_guns(n),"shot":0}
 towers.append(t)
 credits -= TYPES[kind].cost
 if active: spent = true
 refresh_ui()
 return true

func _unhandled_input(event):
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode >= KEY_1 and event.keycode <= KEY_4: choose_build(event.keycode-KEY_1)
  if event.keycode == KEY_ESCAPE:
   cancel_build()
   selected = -1
   refresh_ui()
 if event is InputEventMouseButton and event.pressed:
  if event.button_index == MOUSE_BUTTON_RIGHT: cancel_build()
  if event.button_index == MOUSE_BUTTON_LEFT and integrity > 0:
   if build_type >= 0:
    if not deploy(build_type,pointer): notify("Cannot deploy: check credits, lane clearance, and nearby ships.")
   else:
    selected = -1
    for i in range(towers.size()):
     if pointer.distance_to(towers[i].node.position)<1.1: selected=i
    refresh_ui()

func upgrade(branch: int):
 if selected < 0 or integrity <= 0: return
 var t = towers[selected]
 var cost = upgrade_cost(t)
 if t.level >= 3 or credits < cost or (t.branch >= 0 and t.branch != branch): return
 credits -= cost
 t.invested += cost
 t.branch = branch
 t.level += 1
 if active: spent = true
 if branch == 0:
  t.damage *= 1.65
  if t.kind == 2: t.range += .25
 else:
  if t.kind == 0 or t.kind == 2: t.range += 1.2
  else: t.rate *= .72
  t.damage *= 1.16
 t.node.scale = Vector3.ONE*(1+t.level*.1)
 notify("%s upgraded to tier %d" % [TYPES[t.kind].name,t.level])
 refresh_ui()

func upgrade_cost(t: Dictionary) -> int:
 return int(TYPES[t.kind].cost * (0.7 + t.level*0.6))

func sell_selected():
 if selected < 0 or integrity <= 0: return
 var t = towers[selected]
 credits += int(t.invested*.65)
 t.node.queue_free()
 towers.remove_at(selected)
 selected = -1
 refresh_ui()

func start_wave():
 if active or integrity <= 0: return
 cancel_build()
 active = true
 spent = false
 wave += 1
 remaining = 8+wave*3
 spawn_clock = 0
 notify("Incoming wave %d · %s" % [wave,"DREADNOUGHT DETECTED" if wave%5==0 else "Hostile signatures approaching"])
 refresh_ui()

func spawn_enemy():
 var elite = remaining == 1 and wave%5 == 0
 var fast = remaining%4 == 0 and wave>=2 and not elite
 var armored = remaining%5 == 0 and wave>=3 and not elite
 var n = enemy_model.instantiate()
 add_child(n)
 var hp = (34.0+wave*14.0)*pow(1.13,wave-1)
 if elite: hp *= 7
 elif armored: hp *= 2.1
 elif fast: hp *= .7
 n.scale = Vector3.ONE*(1.7 if elite else (1.05 if armored else .7))
 var bar = MeshInstance3D.new()
 var bm = BoxMesh.new()
 bm.size = Vector3(1,.02,.10)
 bar.mesh = bm
 bar.material_override = mat(Color("ff6581"))
 add_child(bar)
 enemies.append({"node":n,"hp":hp,"maxhp":hp,"distance":0.0,"speed":(1.55+wave*.07)*(1.65 if fast else (.7 if elite else 1.0)),"slow":0.0,"factor":1.0,"reward":(50+wave*5 if elite else 10+wave),"elite":elite,"bar":bar,"jet_clock":0.0})

func _process(delta):
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
  ghost.visible = mouse.x < 1090 and mouse.y > 105 and mouse.y < 763
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
 if toast_time > 0:
  toast_time -= delta
  if toast_time<=0: toast_label.text=""
 if not active or integrity <= 0: return
 spawn_clock -= delta
 if remaining > 0 and spawn_clock <= 0:
  spawn_enemy()
  remaining -= 1
  spawn_clock = max(.25,.9-wave*.024)
 for e in enemies.duplicate():
  e.slow = max(0,e.slow-delta)
  e.distance += e.speed*delta*(e.factor if e.slow>0 else 1.0)
  if e.distance >= path.get_baked_length():
   integrity = maxi(0,integrity-(4 if e.elite else 1))
   remove_enemy(e,false)
   if integrity<=0:
    active = false
    notify("CORE LOST · Restart to defend another sector.")
    refresh_ui()
    return
   continue
  var pos = path.sample_baked(e.distance)
  var forward = path.sample_baked(min(e.distance+.15,path.get_baked_length()))
  e.node.position = pos+Vector3.UP*.3
  # Blender's -Y bow becomes +Z after glTF export; aim the model's front.
  if pos.distance_to(forward)>.001: e.node.look_at(forward+Vector3.UP*.3,Vector3.UP,true)
  e.bar.position = pos + Vector3(0,1,-.75)
  e.bar.scale.x = max(.01,e.hp/e.maxhp)
  e.jet_clock -= delta
  if e.jet_clock <= 0:
   e.jet_clock = .06
   for side in [-1,1]:
    fx.jet(e.node.to_global(Vector3(side*.4,.24,-.65)),-e.node.global_basis.z.normalized(),Color("ff647e"),2)
 for t in towers:
  t.cooldown -= delta
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
 if t.kind in [2,3]: return aim_station_guns(t,target_pos+Vector3.UP*.25,delta)
 var direction = target_pos-t.node.position
 var desired = atan2(direction.x,direction.z)
 var error = wrapf(desired-t.node.rotation.y,-PI,PI)
 var step = clampf(error,-delta*2.8,delta*2.8)
 t.node.rotate_y(step)
 t.jet_clock -= delta
 if t.kind == 0 and absf(error) > .035 and t.jet_clock <= 0:
  t.jet_clock = .035
  # Exhaust opposite the required force: bow and stern jets produce a turning couple.
  var side = -signf(step)
  var basis = t.node.global_basis.orthonormalized()
  fx.jet(t.node.to_global(Vector3(side*.62,.25,.55)),basis.x*side,Color("83ecff"),4)
  fx.jet(t.node.to_global(Vector3(-side*.62,.25,-.5)),-basis.x*side,Color("64baff"),3)
 return absf(error-step)<.20

func aim_station_guns(t: Dictionary, target_pos: Vector3, delta: float) -> bool:
 var ready = false
 for gun in t.guns:
  # Traverse is local to each mounting socket; the station body never rotates.
  var local_target: Vector3 = gun.yaw.get_parent().to_local(target_pos)
  var desired = atan2(local_target.x,local_target.z)
  var error = wrapf(desired-gun.yaw.rotation.y,-PI,PI)
  gun.yaw.rotation.y += clampf(error,-delta*4.4,delta*4.4)
  var elevation: Vector3 = gun.yaw.to_local(target_pos)-gun.pitch.position
  var pitch = -atan2(elevation.y,Vector2(elevation.x,elevation.z).length())
  gun.pitch.rotation.x = move_toward(gun.pitch.rotation.x,clampf(pitch,-.6,.6),delta*3.5)
  if absf(wrapf(desired-gun.yaw.rotation.y,-PI,PI))<.15: ready = true
 return ready

func fire_station_guns(t: Dictionary, target_pos: Vector3):
 for gun in t.guns:
  var forward: Vector3 = gun.pitch.global_basis.z.normalized()
  var toward: Vector3 = (target_pos-gun.pitch.global_position).normalized()
  if forward.dot(toward)<.96: continue
  var muzzle: Node3D = gun.muzzles[t.shot%gun.muzzles.size()]
  beam(muzzle.global_position,target_pos,TYPES[t.kind].color,.028,.16)
  fx.jet(muzzle.global_position,forward,TYPES[t.kind].color,3)
  gun.recoil = .045

func fire(t: Dictionary, target: Dictionary):
 var origin = t.node.position+Vector3.UP*.5
 var end = target.node.position
 t.shot += 1
 if t.kind in [0,1]:
  origin = t.node.to_global(Vector3(0,.35,1.05))
 if t.kind == 2:
  fire_station_guns(t,end+Vector3.UP*.25)
  pulse(t.node.position,t.range,TYPES[t.kind].color)
  for e in enemies.duplicate():
   if e.node.position.distance_to(t.node.position)<=t.range: hurt(e,t.damage)
 elif t.kind == 1:
  beam(origin,end,TYPES[1].color,.07,.22)
  pulse(end,1.5,Color("ffac55"))
  for e in enemies.duplicate():
   if e.node.position.distance_to(end)<1.5: hurt(e,t.damage)
 else:
  if t.kind == 3: fire_station_guns(t,end+Vector3.UP*.25)
  else: beam(origin,end,TYPES[t.kind].color,.035,.13)
  if t.kind == 3:
   target.slow = 2.0
   target.factor = max(.15,.5-(t.level*.10 if t.branch == 0 else 0))
  hurt(target,t.damage)

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

func hurt(e: Dictionary, damage: float):
 if not enemies.has(e): return
 e.hp -= damage
 fx.sparks(e.node.position+Vector3.UP*.25)
 if e.hp <= 0: remove_enemy(e,true)

func remove_enemy(e: Dictionary, killed: bool):
 if killed:
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
 active = false
 var base = 35+wave*8
 var bonus = 45+wave*10 if not spent else 0
 credits += base+bonus
 notify("Wave %d cleared  +%d cr   |   %s" % [wave,base,"No-purchase bonus +%d cr" % bonus if bonus>0 else "No-purchase bonus forfeited"])
 refresh_ui()

func notify(message: String):
 toast_label.text = message
 toast_time = 7

func refresh_ui():
 if stats_label == null: return
 stats_label.text = "%04d  CREDITS     %02d / 20  CORE     %d  KILLS" % [credits,integrity,kills]
 wave_label.text = "WAVE %02d   /   %s" % [wave,"CORE LOST" if integrity<=0 else ("ENGAGED" if active else "SECTOR STANDBY")]
 status_label.text = "%d incoming · %d in lane   |   Savings bonus: %s" % [remaining,enemies.size(),"forfeited" if spent else "+%d cr" % (45+wave*10)] if active else "Deploy and upgrade your fleet, then launch the next wave. Every fifth wave brings a dreadnought."
 next_button.disabled = active or integrity <= 0
 next_button.text = "WAVE IN PROGRESS" if active else "NEXT WAVE %02d  →" % (wave+1)
 for i in range(4): buy_buttons[i].disabled = credits<TYPES[i].cost or integrity<=0
 upgrade_a.hide()
 upgrade_b.hide()
 sell_button.hide()
 if build_type >= 0:
  var t = TYPES[build_type]
  detail_label.text = "%s / DEPLOYMENT\nDamage %.0f  ·  Range %.1f\nCooldown %.2fs\nGreen ring = valid placement\nClick repeatedly to build." % [t.name,t.damage,t.range,t.rate]
 elif selected >= 0 and selected<towers.size():
  var t = towers[selected]
  detail_label.text = "%s  /  TIER %d\nDamage %.0f  ·  Range %.1f\nCooldown %.2fs\n%s" % [TYPES[t.kind].name,t.level,t.damage,t.range,t.rate,"Choose one specialization:" if t.branch<0 else TYPES[t.kind].branches[t.branch]]
  for branch in range(2):
   var b = upgrade_a if branch == 0 else upgrade_b
   b.show()
   var desc = "Damage +65%" if branch == 0 else ("Range +1.2 · damage +16%" if t.kind in [0,2] else "Fire rate +39% · damage +16%")
   if t.kind == 3 and branch == 0: desc = "Stronger slow · damage +65%"
   b.text = "%s · %s\n%s" % [TYPES[t.kind].branches[branch],"MAX" if t.level>=3 else "%d cr" % upgrade_cost(t),desc]
   b.add_theme_font_size_override("font_size",13)
   var icon_name = ["beam","warhead","core","frost"][t.kind] if branch==0 else ("range" if t.kind in [0,2] else "rate")
   b.icon = load("res://assets/icons/"+icon_name+".svg")
   b.expand_icon = true
   b.add_theme_constant_override("icon_max_width",30)
   b.add_theme_constant_override("h_separation",8)
   b.disabled = integrity<=0 or t.level>=3 or credits<upgrade_cost(t) or (t.branch>=0 and t.branch!=branch)
  sell_button.show()
  sell_button.text = "Salvage ship  +%d cr" % int(t.invested*.65)
 else:
  detail_label.text = "Select a deployed ship to inspect\nits weapons and upgrade tree.\n\nTwo exclusive branches per tower.\nThree tiers per specialization."

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
 seed_test_fleet()
 wave = 3
 start_wave()
 set_process(false)
 for i in range(1300):
  _process(1.0/60.0)
  if i%60 == 0: await get_tree().process_frame
 selected = 2
 refresh_ui()
 toast_label.text = "Hold the corridor. Protect the core."
 await RenderingServer.frame_post_draw
 get_viewport().get_texture().get_image().save_png("res://preview.png")
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
 print("VFX TEST PASSED: left/right torque, smooth turning, hit sparks, inward collapse, cleanup")
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
