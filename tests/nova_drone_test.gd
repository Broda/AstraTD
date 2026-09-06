extends SceneTree

const Drones = preload("res://scripts/fleet/nova_drones.gd")
var failures: Array = []
var checks = 0
var controller = Drones.new()
var game: DroneGame

class DroneGame extends Node3D:
 var active = true
 var settings = {"effects_intensity":"normal"}
 var enemies: Array = []
 var hits: Array = []
 func hurt(enemy: Dictionary, amount: float):
  hits.append({"enemy":enemy,"amount":amount})
  enemy.hp -= amount
  if enemy.hp<=0.0: enemies.erase(enemy)

func expect(condition: bool, message: String):
 checks += 1
 if not condition: failures.append(message)

func _init():
 _run.call_deferred()

func _run():
 game = DroneGame.new()
 root.add_child(game)
 check_pool_and_lifecycle()
 check_swarm_and_targets()
 check_range_recall_and_inheritance()
 check_clock_and_reduced_effects()
 check_long_session()
 game.free()
 if failures.is_empty():
  print("NOVA DRONE TEST PASSED: %d checks; 1/2/3 bounded fighters, functional damage, stable/distributed locks, focus and priority changes, death/range recall, one-time inherited damage, pause/speed, cooldowns, save-style reconstruction, reduced effects, long session" % checks)
 else:
  for failure in failures: push_error(failure)
 quit(0 if failures.is_empty() else 1)

func owner_at(position: Vector3 = Vector3.ZERO) -> Dictionary:
 var node = Node3D.new()
 game.add_child(node)
 node.position = position
 return {"node":node,"targeting":"first","aim_mode":"distribute"}

func enemy_at(position: Vector3, hp: float = 100000.0, distance: float = 0.0) -> Dictionary:
 var node = Node3D.new()
 game.add_child(node)
 node.position = position
 var route = Curve3D.new()
 route.add_point(Vector3.ZERO)
 route.add_point(Vector3(0,0,30))
 var enemy = {"node":node,"hp":hp,"shield":0.0,"slow":0.0,"distance":distance,"route":route}
 game.enemies.append(enemy)
 return enemy

func stats(count: int = 3) -> Dictionary:
 return {"drone_count":count,"drone_damage":21.0,"drone_rate":.7,"drone_reach":1.4,"range":4.0}

func advance(owner: Dictionary, values: Dictionary, seconds: float, speed: float = 1.0):
 var frames: int = int(round(seconds*60.0/speed))
 for frame in range(frames): controller.update(game,owner,speed/60.0,values)

func reset_enemies():
 for enemy in game.enemies:
  if is_instance_valid(enemy.node): enemy.node.free()
 game.enemies.clear()
 game.hits.clear()

func check_pool_and_lifecycle():
 var owner = owner_at()
 controller.sync(owner,0)
 expect(owner.drones.is_empty(),"An unupgraded Nova has no drones")
 var previous: Array = []
 for tier in range(1,4):
  controller.sync(owner,tier)
  expect(owner.drones.size()==tier,"Each drone tier adds exactly one fighter")
  for index in range(previous.size()): expect(owner.drones[index].node==previous[index],"Upgrade retains existing fighters")
  previous.clear()
  for drone in owner.drones:
   previous.append(drone.node)
   expect(drone.node.get_parent()==owner.node,"Carrier owns every drone for reset/sale cleanup")
   expect(drone.beam.get_parent()==drone.node,"Each fighter owns one reusable beam")
 controller.sync(owner,99)
 expect(owner.drones.size()==3,"Corrupt/unsupported counts cannot exceed the three-drone pool")
 for iteration in range(120): controller.sync(owner,3)
 expect(owner.node.get_child_count()==3,"Repeated reconstruction sync never duplicates nodes")
 expect(owner.node.scale==Vector3.ONE,"Drones never enlarge the carrier model")
 var removed = weakref(owner.drones[2].node)
 controller.sync(owner,1)
 expect(removed.get_ref()==null,"Shrinking a pool frees removed fighter nodes immediately")
 controller.clear(owner)
 expect(owner.drones.is_empty() and owner.node.get_child_count()==0,"Clear removes pooled nodes and state")
 controller.sync(owner,3)
 expect(owner.drones.size()==3 and owner.drone_shots==0,"Saved tier reconstruction creates the correct fresh pool")
 var child_ref = weakref(owner.drones[0].node)
 owner.node.free()
 expect(child_ref.get_ref()==null,"Selling/resetting the carrier frees drone visuals without a separate world list")

func check_swarm_and_targets():
 var owner = owner_at(Vector3(2,0,2))
 var values = stats()
 for index in range(4): enemy_at(Vector3(2.4+index*.35,0,3.0),100000.0,index)
 controller.update(game,owner,.016,values)
 var targets: Array = []
 for drone in owner.drones:
  expect(drone.target != null and not targets.has(drone.target),"Distribute assigns three distinct valid enemies")
  targets.append(drone.target)
 game.enemies.reverse()
 controller.update(game,owner,.016,values)
 for index in range(3): expect(owner.drones[index].target==targets[index],"Candidate ordering changes do not jitter valid locks")
 advance(owner,values,3.0)
 for drone in owner.drones:
  expect(drone.shots>1,"Each visible fighter actually attacks its enemy repeatedly")
  expect(drone.node.global_position.distance_to(drone.target.node.global_position)<1.4,"Attacking fighters swarm around their enemy")
 expect(owner.drone_shots==game.hits.size(),"Each drone shot produces exactly one accurate hit")
 for hit in game.hits: expect(is_equal_approx(hit.amount,21.0),"The combat API receives the already-effective drone damage exactly once")
 owner.aim_mode = "focus"
 controller.update(game,owner,.016,values)
 for drone in owner.drones: expect(drone.target==owner.drones[0].target,"Focus mode shares one stable enemy across all drones")
 var heavy = enemy_at(Vector3(3,0,2.8),900000.0)
 owner.targeting = "strongest"
 controller.update(game,owner,.016,values)
 expect(owner.drones[0].target==heavy,"Changing targeting immediately replaces old locks according to the new priority")
 game.enemies.erase(heavy)
 heavy.node.free()
 controller.update(game,owner,.016,values)
 for drone in owner.drones: expect(drone.target != heavy and drone.target != null,"Dead targets are replaced without stale node access")
 controller.clear(owner)
 owner.node.free()
 reset_enemies()

func check_range_recall_and_inheritance():
 var owner = owner_at()
 var values = stats(1)
 var enemy = enemy_at(Vector3(3.9,0,0))
 advance(owner,values,2.0)
 expect(owner.drone_shots>0,"Drones reach and attack an enemy inside effective carrier range")
 var shots: int = owner.drone_shots
 enemy.node.position.x = 4.01
 advance(owner,values,1.0)
 expect(owner.drone_shots==shots and owner.drones[0].target==null,"A drone already near an enemy stops damage as soon as that enemy exits carrier range")
 expect(owner.drones[0].node.global_position.distance_to(owner.node.global_position)<1.7,"An out-of-range target causes a return to carrier orbit")
 values.range = 4.2
 advance(owner,values,1.0)
 expect(owner.drone_shots>shots,"Inherited carrier range allows reacquisition without a second drone-position aura query")
 values.drone_damage = 31.5
 game.hits.clear()
 advance(owner,values,1.0)
 expect(not game.hits.is_empty(),"A buffed drone still deals functional damage")
 for hit in game.hits: expect(is_equal_approx(hit.amount,31.5),"A 50% carrier damage bonus is applied once, never squared")
 game.active = false
 shots = owner.drone_shots
 advance(owner,values,1.0)
 expect(owner.drone_shots==shots and owner.drones[0].target==null,"Preparation disables attacks and recalls drones even if an enemy is present")
 expect(owner.drones[0].node.global_position.distance_to(owner.node.global_position)<1.7,"Idle drones orbit the carrier during preparation")
 game.active = true
 controller.clear(owner)
 owner.node.free()
 reset_enemies()

func check_clock_and_reduced_effects():
 var shot_counts: Array = []
 for speed in [1.0,2.0,3.0]:
  var owner = owner_at()
  var values = stats(1)
  enemy_at(Vector3(0,0,0))
  advance(owner,values,7.0,speed)
  shot_counts.append(owner.drone_shots)
  var position: Vector3 = owner.drones[0].node.global_position
  var time: float = owner.drones[0].time
  var shots: int = owner.drone_shots
  controller.update(game,owner,0.0,values)
  expect(owner.drones[0].node.global_position==position and owner.drones[0].time==time and owner.drone_shots==shots,"A paused zero-delta update freezes motion, cooldown and damage")
  var drone: Dictionary = owner.drones[0]
  drone.cooldown = .35
  drone.last_rate = .7
  values.drone_rate = .35
  controller.update(game,owner,.01,values)
  expect(is_equal_approx(drone.cooldown,.165),"Rate-of-fire changes preserve cooldown progress")
  values.effects_intensity = "reduced"
  shots = owner.drone_shots
  advance(owner,values,1.0,speed)
  expect(owner.drone_shots>shots and not drone.beam.visible,"Reduced effects preserve damage while suppressing optional beams")
  expect(drone.node.visible and drone.core.visible,"Reduced effects retain visible drones and their aiming direction")
  controller.clear(owner)
  owner.node.free()
  reset_enemies()
 expect(absi(shot_counts[0]-shot_counts[1])<=1 and absi(shot_counts[0]-shot_counts[2])<=1,"1x/2x/3x yield the same shots over equal simulation time within one frame")

func check_long_session():
 var owners: Array = []
 var values = stats()
 for index in range(12):
  var owner = owner_at(Vector3(index%4*.4,0,index/4*.4))
  owners.append(owner)
 for index in range(8): enemy_at(Vector3(cos(index)*2.0,0,sin(index)*2.0),10000000.0,index)
 for frame in range(7200):
  for owner in owners: controller.update(game,owner,.05,values)
  if frame%120==0:
   for enemy in game.enemies: enemy.node.position = enemy.node.position.rotated(Vector3.UP,.05)
 var total_shots = 0
 for owner in owners:
  expect(owner.drones.size()==3 and owner.node.get_child_count()==3,"Six simulated minutes with 36 drones keeps each carrier's pool fixed")
  for drone in owner.drones: expect(drone.node.get_child_count()==8,"Long combat reuses all drone meshes and its single beam")
  total_shots += owner.drone_shots
  controller.clear(owner)
  owner.node.free()
 expect(total_shots>10000,"The bounded long-session workload exercises sustained functional combat")
 reset_enemies()
