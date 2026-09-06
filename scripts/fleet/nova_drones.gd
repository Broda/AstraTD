extends RefCounted

# Transient combat state belongs to the carrier. Save restoration calls sync()
# after reconstructing its purchased tiers; no free-flying nodes survive a sale.
const Targeting = preload("res://scripts/fleet/targeting.gd")
const MAX_DRONES = 3
const FLIGHT_SPEED = 14.0
const ATTACK_DISTANCE = 1.4
const DRONE_COLOR = Color("a8c6ff")

func sync(owner: Dictionary, count: int) -> void:
 if not owner.has("drones"): owner.drones = []
 if not owner.has("drone_shots"): owner.drone_shots = 0
 count = clampi(count,0,MAX_DRONES)
 while owner.drones.size() > count:
  var removed: Dictionary = owner.drones.pop_back()
  if is_instance_valid(removed.node): removed.node.free()
 while owner.drones.size() < count:
  var index: int = owner.drones.size()
  var drone := _create_drone(index)
  owner.node.add_child(drone.node)
  drone.node.position = _idle_offset(index,0.0)
  owner.drones.append(drone)

func clear(owner: Dictionary) -> void:
 sync(owner,0)
 owner.drone_shots = 0

func update(game: Node, owner: Dictionary, delta: float, stats: Dictionary) -> void:
 # The caller owns the simulation clock: paused games do not advance this method,
 # and accelerated games pass scaled delta exactly once.
 if delta <= 0.0: return
 sync(owner,int(stats.get("drone_count",0)))
 if owner.drones.is_empty(): return
 var candidates: Array = []
 if game.active:
  candidates = Targeting.candidates(game.enemies,owner.node.global_position,float(stats.range),owner.get("targeting","first"))
 if owner.get("drone_priority",owner.get("targeting","first")) != owner.get("targeting","first"):
  for drone in owner.drones: drone.target = null
 owner.drone_priority = owner.get("targeting","first")
 _assign_targets(owner,candidates)
 var reduced: bool = stats.get("effects_intensity",game.settings.get("effects_intensity","normal")) == "reduced"
 var rate: float = maxf(.08,float(stats.get("drone_rate",.7)))
 for drone in owner.drones:
  drone.time += delta
  drone.flash = maxf(0.0,drone.flash-delta)
  drone.beam.visible = drone.flash > 0.0 and not reduced
  drone.core.scale = Vector3.ONE*(1.15 if drone.flash > 0.0 and not reduced else 1.0)
  # A changed rate preserves the fraction of the current firing interval.
  if not is_equal_approx(drone.last_rate,rate):
   drone.cooldown *= rate/drone.last_rate
   drone.last_rate = rate
  drone.cooldown = maxf(-rate,drone.cooldown-delta)
  var destination: Vector3 = owner.node.to_global(_idle_offset(drone.index,drone.time))
  var target = drone.target
  if _valid_target(game,owner,target,float(stats.range)):
   var phase: float = drone.time*2.8+drone.index*TAU/3.0
   var orbit_radius: float = .66+.09*drone.index
   destination = target.node.global_position+Vector3(cos(phase)*orbit_radius,.65+.10*sin(phase*1.7+drone.index),sin(phase)*orbit_radius)
  else:
   drone.target = null
   target = null
  var previous: Vector3 = drone.node.global_position
  drone.node.global_position = previous.move_toward(destination,FLIGHT_SPEED*delta)
  var forward: Vector3 = destination-drone.node.global_position
  if target != null:
   # Firing is independent of orbit tangent: the turret tracks the enemy while
   # the hull banks around it, so turning does not silently lower weapon DPS.
   forward = target.node.global_position+Vector3.UP*.3-drone.node.global_position
  if forward.length_squared()>.0001:
   drone.node.look_at(drone.node.global_position+forward,Vector3.UP,true)
  if target == null or drone.node.global_position.distance_to(target.node.global_position)>float(stats.get("drone_reach",ATTACK_DISTANCE)): continue
  if drone.cooldown <= 0.0 and _valid_target(game,owner,target,float(stats.range)):
   drone.cooldown += rate
   drone.shots += 1
   owner.drone_shots += 1
   var end: Vector3 = target.node.global_position+Vector3.UP*.25
   _show_shot(drone,end,reduced)
   # stats already includes support inherited through the carrier. Never query
   # auras at the drone position, or multiply a carrier bonus a second time.
   game.hurt(target,float(stats.get("drone_damage",0.0)))
   if game.has_method("play_cue"): game.play_cue("laser")

func _assign_targets(owner: Dictionary, candidates: Array) -> void:
 if owner.get("aim_mode","distribute") == "focus":
  var focused = null
  for drone in owner.drones:
   if candidates.has(drone.target):
    focused = drone.target
    break
  if focused == null and not candidates.is_empty(): focused = candidates[0]
  for drone in owner.drones: drone.target = focused
  return
 var claimed: Array = []
 for drone in owner.drones:
  if candidates.has(drone.target) and not claimed.has(drone.target):
   claimed.append(drone.target)
  else: drone.target = null
 for drone in owner.drones:
  if drone.target != null: continue
  for candidate in candidates:
   if not claimed.has(candidate):
    drone.target = candidate
    claimed.append(candidate)
    break
  if drone.target == null and not candidates.is_empty():
   drone.target = candidates[drone.index%candidates.size()]

func _valid_target(game: Node, owner: Dictionary, target, radius: float) -> bool:
 return target != null and game.active and game.enemies.has(target) and is_instance_valid(target.node) and float(target.hp)>0.0 and owner.node.global_position.distance_to(target.node.global_position)<=radius

func _idle_offset(index: int, time: float) -> Vector3:
 var angle: float = time*.85+index*TAU/3.0
 return Vector3(cos(angle)*1.05,1.1+.08*sin(time*1.5+index),sin(angle)*1.05)

func _material(color: Color) -> StandardMaterial3D:
 var material := StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.albedo_color = color
 return material

func _box(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
 var node := MeshInstance3D.new()
 var shape := BoxMesh.new()
 shape.size = size
 node.mesh = shape
 node.position = position
 node.material_override = _material(color)
 parent.add_child(node)
 return node

func _create_drone(index: int) -> Dictionary:
 var node := Node3D.new()
 node.name = "NovaDrone%d" % (index+1)
 _box(node,Vector3(.14,.095,.34),Vector3.ZERO,Color("d5deff"))
 _box(node,Vector3(.13,.035,.2),Vector3(-.13,-.005,-.055),Color("526aa2"))
 _box(node,Vector3(.13,.035,.2),Vector3(.13,-.005,-.055),Color("526aa2"))
 _box(node,Vector3(.065,.05,.075),Vector3(0,.025,.17),Color("e9f5ff"))
 var core := _box(node,Vector3(.07,.025,.13),Vector3(0,.06,.025),DRONE_COLOR)
 for side in [-1,1]:
  _box(node,Vector3(.055,.045,.065),Vector3(side*.115,.0,-.175),Color("67efff"))
 var beam := MeshInstance3D.new()
 beam.name = "ReusableWeaponBeam"
 var shape := CylinderMesh.new()
 shape.top_radius = .014
 shape.bottom_radius = .014
 shape.height = 1.0
 shape.radial_segments = 6
 shape.rings = 1
 beam.mesh = shape
 beam.material_override = _material(DRONE_COLOR)
 beam.visible = false
 beam.top_level = true
 node.add_child(beam)
 return {"node":node,"index":index,"target":null,"time":0.0,"cooldown":index*.12,"last_rate":.7,"shots":0,"beam":beam,"flash":0.0,"core":core}

func _show_shot(drone: Dictionary, end: Vector3, reduced: bool) -> void:
 var start: Vector3 = drone.node.global_position+drone.node.global_basis.z*.2
 var direction: Vector3 = end-start
 drone.flash = .035 if reduced else .09
 drone.beam.visible = not reduced
 if direction.length_squared()<.0001: return
 drone.beam.mesh.height = direction.length()
 drone.beam.global_position = (start+end)*.5
 drone.beam.global_basis = Basis(Quaternion(Vector3.UP,direction.normalized()))
