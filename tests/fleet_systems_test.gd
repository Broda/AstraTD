extends RefCounted
## Real-game acceptance for phases 1–3. Persistence is isolated per process.
## Economic measurements use stationary, armor-free targets and equal available
## budgets; they expose support tradeoffs and do not claim campaign balance.

const Data = preload("res://scripts/data/game_data.gd")
const Stats = preload("res://scripts/data/fleet_stats.gd")
const Targeting = preload("res://scripts/fleet/targeting.gd")
const Storage = preload("res://scripts/services/run_storage.gd")
const Settings = preload("res://scripts/services/game_settings.gd")
var game: Node
var checks := 0
var failures: Array[String] = []

func expect(condition: bool, message: String) -> bool:
 checks += 1
 if not condition:
  failures.append(message)
  push_error("FLEET SYSTEMS: "+message)
 return condition

func near(actual: float, expected: float, message: String):
 expect(is_equal_approx(actual,expected),message+" (%.5f vs %.5f)" % [actual,expected])

func reset():
 game.start_run("aurora_reach")
 game.credits = 100000
 game.settings.effects_intensity = "normal"

func legal_position() -> Vector3:
 for x in range(-19,10):
  for z in range(-9,10):
   var point = Vector3(x,0,z)
   if game.can_place(point): return point
 return Vector3.INF

func place(id: String) -> Dictionary:
 var point = legal_position()
 if not expect(point.is_finite(),"Legal placement exists for "+id): return {}
 if not expect(game.deploy(Data.tower_index(id),point),"Paid deployment succeeds for "+id): return {}
 return game.towers.back()

func fixture_tower(id: String, point: Vector3) -> Dictionary:
 return game.create_tower(Data.tower_index(id),point)

func buy(tower: Dictionary, branch: int, tier: int):
 game.selected = game.towers.find(tower)
 while tower.level < tier:
  var before: int = tower.level
  game.upgrade(branch)
  if not expect(tower.level==before+1,"A valid paid upgrade installs exactly one tier"): break

func activate():
 game.start_wave()
 game.remaining = 1
 game.spawn_clock = 100000.0

func enemy_at(point: Vector3, hp = 100000.0) -> Dictionary:
 game.spawn_enemy("raider")
 var enemy: Dictionary = game.enemies.back()
 var route = Curve3D.new()
 route.add_point(Vector3(point.x,0,point.z))
 route.add_point(Vector3(point.x,0,point.z+20))
 enemy.route = route
 enemy.distance = 0.0
 enemy.speed = 0.0
 enemy.hp = hp
 enemy.maxhp = hp
 enemy.shield = 0.0
 enemy.armor = 0.0
 enemy.regen = 0.0
 enemy.jet_clock = 100000.0
 enemy.node.position = Vector3(point.x,.3,point.z)
 return enemy

func run(node: Node):
 game = node
 game.set_process(false)
 var original_root = Storage.storage_root
 Storage.storage_root = "user://fleet_systems_%d" % OS.get_process_id()
 check_paid_previews_and_restoration()
 await game.get_tree().process_frame
 check_support_visibility_and_stacking()
 check_support_combat()
 await game.get_tree().process_frame
 check_targeting_controls()
 check_cryo_aiming()
 await game.get_tree().process_frame
 check_nova_live_behavior()
 check_effects_settings()
 await game.get_tree().process_frame
 report_relay_economics()
 game.clear_run()
 game.audio.queue_free()
 await game.get_tree().process_frame
 await game.get_tree().create_timer(.25).timeout
 var directory = DirAccess.open(Storage.storage_root)
 if directory != null:
  for filename in directory.get_files(): directory.remove(filename)
  DirAccess.remove_absolute(Storage.storage_root)
 Storage.storage_root = original_root
 if failures.is_empty(): print("FLEET SYSTEMS TEST PASSED: %d checks; paid previews, fleet persistence, support visibility/combat, targeting, legal Cryostat aiming, Nova drones, reduced effects, measured Relay economics" % checks)
 else: print("FLEET SYSTEMS TEST FAILED: %d / %d checks" % [failures.size(),checks])
 game.get_tree().quit(0 if failures.is_empty() else 1)

func check_paid_previews_and_restoration():
 reset()
 for definition in Data.TOWERS:
  for branch in range(definition.branch_ids.size()):
   var tower = place(definition.id)
   if tower.is_empty(): return
   game.selected = game.towers.find(tower)
   var original_scale: Vector3 = tower.node.scale
   var future: Dictionary = game.preview_upgrade(tower,branch,3)
   var future_cost = 0
   for tier in range(1,4): future_cost += Data.upgrade_for(definition.id,branch,tier).cost
   expect(future.state=="prerequisite" and future.cost==future_cost,"Future-tier cards include all prerequisite costs")
   var cash: int = game.credits
   game.credits = 0
   var unavailable: Dictionary = game.preview_upgrade(tower,branch,1)
   game.upgrade(branch)
   expect(unavailable.state=="unaffordable" and not unavailable.purchasable and tower.level==0,"Unaffordable tiers explain their state and cannot charge or install")
   game.credits = cash
   for tier in range(1,4):
    var preview: Dictionary = game.preview_upgrade(tower,branch,tier)
    var before_credits: int = game.credits
    var before_invested: int = tower.invested
    game.upgrade(branch)
    var spec: Dictionary = Data.upgrade_for(definition.id,branch,tier)
    expect(tower.level==tier and tower.branch==branch and before_credits-game.credits==spec.cost and tower.invested-before_invested==spec.cost,"Each real purchase charges exactly the displayed tier cost")
    var actual: Dictionary = game.effective_stats(tower)
    for key in ["damage","range","rate","support_damage","support_range","support_fire_rate","aura_range","drone_count","drone_damage","drone_rate","pulse_damage"]:
     near(actual[key],preview.after[key],"Paid combat stats match the effective preview: %s/%d/%d %s" % [definition.id,branch,tier,key])
    expect(tower.node.scale.is_equal_approx(original_scale),"Every upgrade preserves original fleet model size")
    expect(game.preview_upgrade(tower,branch,tier).state=="owned","Installed cards are explicitly marked owned")
    if tier==1:
     var alternative = (branch+1)%definition.branch_ids.size()
     var balance: int = game.credits
     game.upgrade(alternative)
     expect(tower.level==1 and tower.branch==branch and game.credits==balance and game.preview_upgrade(tower,alternative,1).state=="exclusive","Exclusive specializations reject alternate purchases without charge")
   if definition.id=="nova":
    game.select_target_priority("strongest")
    game.select_aim_mode("focus")
 for tier in [1,2]:
  var tower = place("nova")
  if tower.is_empty(): return
  buy(tower,2,tier)
 var snapshot: Dictionary = game.saved_run()
 expect(Storage.save_slot(1,snapshot).ok,"A complete fleet using every path and drone tier can save")
 var loaded: Dictionary = Storage.load_slot(1)
 if not expect(loaded.ok,"The complete fleet save loads"): return
 expect(game.restore_run(loaded.data).is_empty(),"All new paths restore through real game validation")
 expect(game.saved_run()==snapshot,"Saved targeting, aim mode, branch IDs, economy, and placements round trip exactly")
 for tower in game.towers:
  expect(tower.node.scale.is_equal_approx(Vector3.ONE),"Restoration preserves original model scale for every path")
  if tower.kind==2 and tower.branch==2:
   expect(tower.drone_count==tower.level and tower.drones.size()==tower.level,"Drone tiers 1/2/3 restore exactly one functional drone per tier")
 var stale = snapshot.duplicate(true)
 for record in stale.towers:
  var count: int = Data.tower_by_id(record.type_id).branch_ids.size()
  record.branch = (int(record.branch)+1)%count
 expect(game.restore_run(stale).is_empty() and game.saved_run()==snapshot,"Stable branch IDs override stale valid numeric indices including third paths")
 var legacy = snapshot.duplicate(true)
 for record in legacy.towers:
  record.erase("targeting")
  record.erase("aim_mode")
 expect(game.restore_run(legacy).is_empty(),"Old v1 saves without targeting settings remain playable")
 for tower in game.towers:
  expect(tower.targeting==("strongest" if tower.kind==4 else ("unslowed" if tower.kind==3 else "first")),"Legacy saves receive role-appropriate priority defaults")
  expect(tower.aim_mode=="distribute","Legacy Nova saves receive distributed aiming by default")
 expect(game.restore_run(snapshot).is_empty(),"A second restore succeeds without creating duplicate combat objects")
 for tower in game.towers:
  if tower.kind==2: expect(tower.drones.size()==tower.drone_count,"Repeated restoration cannot duplicate drones")

func check_support_visibility_and_stacking():
 reset()
 var receiver = fixture_tower("lancer",Vector3.ZERO)
 var damage = fixture_tower("support",Vector3(-2,0,0))
 var reach = fixture_tower("support",Vector3(2,0,0))
 var rapid = fixture_tower("support",Vector3(0,0,-2))
 buy(damage,0,3)
 buy(reach,1,3)
 buy(rapid,2,3)
 var effective: Dictionary = game.effective_stats(receiver)
 near(effective.damage,14.0*1.48,"Three overlapping Relays apply only strongest damage support")
 near(effective.range,5.1*1.36,"Overlapping support grants actual recipient range")
 near(effective.rate,.48/1.36,"Overlapping support grants actual rate of fire")
 expect(effective.sources.size()==3,"Selected recipients expose all in-range bonus sources")
 for source in effective.sources:
  expect(not source.name.is_empty() and source.has("damage") and source.has("range") and source.has("fire_rate"),"Each displayed source exposes its name and stat contributions")
 for relay in [damage,reach,rapid]:
  expect(game.support_sources(relay).is_empty() and game.effective_stats(relay).sources.is_empty(),"Relay support cannot feed back into other Relays")
  expect(relay.guns.is_empty() and relay.damage==0.0,"Pure-support Relays have no attached offensive gun assemblies")
 game.selected = game.towers.find(damage)
 game.update_support_visuals()
 expect(receiver.support_marker.visible and not reach.support_marker.visible and not rapid.support_marker.visible,"Selecting Relay highlights recipient ships and excludes Relays")
 expect(game.effective_stats(damage).affected_count==1,"Relay affected count uses the same eligibility as its aura")
 game.sell_selected()
 effective = game.effective_stats(receiver)
 near(effective.damage,14.0*1.18,"Selling the strongest Relay immediately removes its damage contribution")
 expect(effective.sources.size()==2,"Selling Relay immediately removes the source from recipient details")
 rapid.node.position = Vector3(30,0,0)
 near(game.effective_stats(receiver).rate,.48,"Leaving coverage immediately removes rate support")
 reset()
 receiver = fixture_tower("lancer",Vector3(5.9,0,0))
 reach = fixture_tower("support",Vector3.ZERO)
 game.selected = game.towers.find(reach)
 game.update_support_visuals()
 expect(not receiver.support_marker.visible,"A ship beyond current coverage is not claimed as supported")
 game.preview_support(1,1)
 expect(game.preview_ring.visible and receiver.support_marker.visible,"A coverage upgrade previews newly reached recipients")
 near(game.preview_ring.scale.x,6.0,"The coverage preview ring uses the projected aura radius")
 expect(receiver.support_marker.material_override.albedo_color.is_equal_approx(Color("ffc46b")),"Newly reached recipients use a distinct preview color")
 game.clear_upgrade_preview()
 game.update_support_visuals()
 expect(not game.preview_ring.visible and not receiver.support_marker.visible,"Clearing a preview removes projected support immediately")
 buy(reach,1,1)
 game.update_support_visuals()
 expect(receiver.support_marker.visible and game.effective_stats(reach).affected_count==1,"Purchased coverage matches its preview and affected count")
 game.choose_build(5)
 game.ghost.position = Vector3(.5,0,0)
 game.ghost.show()
 game.update_support_visuals()
 expect(receiver.support_marker.visible and not reach.support_marker.visible,"Relay placement highlights eligible recipients before purchase")
 game.cancel_build()

func check_support_combat():
 reset()
 var receiver = fixture_tower("lancer",Vector3.ZERO)
 var reach = fixture_tower("support",Vector3(0,0,-2))
 buy(reach,1,1)
 activate()
 var target = enemy_at(Vector3(0,0,5.5))
 expect(Targeting.candidates(game.enemies,receiver.node.position,receiver.range,"first").is_empty(),"Range test enemy is beyond the receiver's owned range")
 receiver.node.rotation.y = 0.0
 game._process(.01)
 expect(target.hp<target.maxhp,"Recipient range support enables real acquisition and damage beyond owned range")
 var hp: float = target.hp
 reach.node.position = Vector3(30,0,0)
 receiver.cooldown = 0.0
 game._process(.01)
 near(target.hp,hp,"Removing support prevents further acquisition beyond owned range")
 reset()
 receiver = fixture_tower("lancer",Vector3.ZERO)
 var rapid = fixture_tower("support",Vector3(0,0,-2))
 buy(rapid,2,3)
 activate()
 target = enemy_at(Vector3(0,0,3))
 game._process(.01)
 near(receiver.cooldown,.48/1.36,"The combat loop schedules its actual next shot using supported rate of fire")
 near(target.maxhp-target.hp,14.0*1.18,"The combat loop applies baseline Relay damage exactly once")
 var before: float = target.hp
 var effect_count: int = game.effects.size()
 game.fire(rapid,target)
 game.fire_station_guns(rapid,target.node.position)
 expect(target.hp==before and game.effects.size()==effect_count and rapid.shot==0,"Calling attack paths on Relay cannot damage or emit offensive beams")
 receiver.cooldown = receiver.last_rate*.5
 game.selected = game.towers.find(rapid)
 game.sell_selected()
 game._process(.01)
 near(receiver.cooldown,.48*.5-.01,"Relay removal preserves fractional firing progress instead of granting or delaying an extra shot")
 reset()
 receiver = fixture_tower("bastion",Vector3.ZERO)
 rapid = fixture_tower("support",Vector3(0,0,-2))
 buy(rapid,2,3)
 activate()
 target = enemy_at(Vector3(0,0,3))
 receiver.last_rate = game.effective_stats(receiver).rate
 receiver.cooldown = receiver.last_rate*.5
 buy(receiver,1,1)
 near(receiver.cooldown,game.effective_stats(receiver).rate*.5,"Upgrading an already supported receiver preserves its effective cooldown fraction")
 game._process(.01)
 near(receiver.cooldown,game.effective_stats(receiver).rate*.5-.01,"The next combat step must not apply the support cooldown ratio a second time")
 reset()
 receiver = fixture_tower("bastion",Vector3.ZERO)
 rapid = fixture_tower("support",Vector3(0,0,-2))
 activate()
 target = enemy_at(Vector3(0,0,3))
 receiver.cooldown = receiver.rate*.5
 buy(rapid,2,1)
 game._process(.01)
 near(receiver.cooldown,receiver.rate/1.12*.5-.01,"A Relay rate upgrade preserves existing recipients' fractional cooldown on the next step")

func check_targeting_controls():
 reset()
 var nova = fixture_tower("nova",Vector3.ZERO)
 var long_route = Curve3D.new()
 long_route.add_point(Vector3.ZERO)
 long_route.add_point(Vector3(100,0,0))
 var short_route = Curve3D.new()
 short_route.add_point(Vector3.ZERO)
 short_route.add_point(Vector3(20,0,0))
 var farther = enemy_at(Vector3(-1,0,2))
 var closer = enemy_at(Vector3(1,0,2))
 farther.route = long_route
 farther.distance = 90.0
 closer.route = short_route
 closer.distance = 15.0
 expect(Targeting.candidates(game.enemies,Vector3.ZERO,4,"first")[0]==closer,"Closest to Core uses remaining route distance across unequal lanes")
 expect(Targeting.candidates(game.enemies,Vector3.ZERO,4,"last")[0]==farther,"Last targets greatest remaining distance across unequal lanes")
 farther.hp = 200000.0
 farther.maxhp = 200000.0
 game.selected = game.towers.find(nova)
 game.select_target_priority("first")
 game.select_aim_mode("distribute")
 game.assign_nova_targets(nova)
 expect(nova.guns[0].target!=nova.guns[1].target,"Distributed Nova guns allocate distinct available targets")
 var locks: Array = []
 for gun in nova.guns: locks.append(gun.target)
 game.assign_nova_targets(nova)
 for index in range(nova.guns.size()): expect(nova.guns[index].target==locks[index],"Distributed target locks remain stable without a mode change")
 game.select_target_priority("strongest")
 game.select_aim_mode("focus")
 game.assign_nova_targets(nova)
 for gun in nova.guns: expect(gun.target==farther,"Changing priority and focus immediately retargets all Nova guns")
 game.select_target_priority("first")
 game.assign_nova_targets(nova)
 for gun in nova.guns: expect(gun.target==closer,"Changing priority clears old focus locks")
 var cryo = fixture_tower("cryostat",Vector3(0,0,-1))
 closer.slow = 1.0
 expect(Targeting.candidates(game.enemies,cryo.node.position,cryo.range,"unslowed")[0]==farther,"Cryostat's default favors threats that need slowing")

func check_cryo_aiming():
 reset()
 var cryo = fixture_tower("cryostat",Vector3.ZERO)
 var target = enemy_at(Vector3(0,0,-3))
 var aim: Vector3 = target.node.position+Vector3.UP*.25
 var all_rear = true
 for gun in cryo.guns:
  var local: Vector3 = gun.yaw.get_parent().to_local(aim)
  all_rear = all_rear and absf(atan2(local.x,local.z))>PI/2
 if not expect(all_rear,"Rear-target fixture must begin outside both Cryostat mount arcs"): return
 var hp: float = target.hp
 game.fire(cryo,target)
 expect(target.hp==hp and cryo.shot==0,"A rear target cannot be hit before the satellite rotates into legal alignment")
 var heading: float = cryo.node.rotation.y
 var particle_count: int = game.fx.particles.size()
 var observed_turn = false
 var observed_ready = false
 for step in range(240):
  var previous_heading: float = cryo.node.rotation.y
  var ready: bool = game.steer_ship(cryo,target.node.position,1.0/60)
  var turn: float = absf(wrapf(cryo.node.rotation.y-previous_heading,-PI,PI))
  expect(turn<=1.8/60.0+.00001,"Cryostat body rotation remains smoothly rate-limited")
  observed_turn = observed_turn or cryo.hull_turning
  for gun in cryo.guns: expect(absf(gun.yaw.rotation.y)<=PI/2+.00001,"Every gun stays inside ±90 degrees during hull rotation")
  var legal: bool = game.cryo_can_fire(cryo,aim)
  var before: float = target.hp
  game.fire(cryo,target)
  if not legal: expect(target.hp==before,"Unaligned frames cannot apply invisible rear damage")
  if ready and target.hp<before: observed_ready = true
 expect(not is_equal_approx(cryo.node.rotation.y,heading) and observed_turn,"Out-of-arc targets cause the whole satellite to turn")
 expect(game.fx.particles.size()>particle_count,"Cryostat hull rotation emits visible thruster particles")
 expect(observed_ready and target.hp<hp and target.slow>0.0,"After lawful rotation the cryo guns deal damage and apply slow")
 expect(not cryo.hull_turning,"Hull turning stops after gaining clearance inside both mount arcs")
 var settled: float = cryo.node.rotation.y
 for index in range(120):
  var jitter: Vector3 = target.node.position+Vector3(sin(index*.8)*.01,0,cos(index*.7)*.01)
  game.steer_ship(cryo,jitter,1.0/60)
 near(cryo.node.rotation.y,settled,"Small target motion after acquiring boundary clearance does not oscillate the hull")
 game.selected = game.towers.find(cryo)
 game.update_support_visuals()
 for gun in cryo.guns:
  expect(gun.arc.visible,"Selected Cryostat displays each legal firing arc")
  near(gun.arc.scale.x,cryo.range,"Legal firing arc scale matches effective weapon range")

func check_nova_live_behavior():
 reset()
 var nova = fixture_tower("nova",Vector3.ZERO)
 buy(nova,2,3)
 var before: Array = []
 for drone in nova.drones: before.append(drone.node.global_position)
 game.drone_controller.update(game,nova,.2,game.effective_stats(nova))
 for index in range(nova.drones.size()): expect(nova.drones[index].node.global_position!=before[index] and nova.drones[index].target==null,"Idle drones orbit their carrier without attacking")
 var carrier_relay = fixture_tower("support",Vector3(-5.5,0,0))
 var drone_local_relay = fixture_tower("support",Vector3(0,0,8))
 buy(drone_local_relay,0,3)
 expect(game.support_sources(nova).has(carrier_relay) and not game.support_sources(nova).has(drone_local_relay),"Drone inheritance fixture has carrier-only support and a stronger aura near enemies")
 activate()
 var first = enemy_at(Vector3(-.5,0,3.4))
 var second = enemy_at(Vector3(.5,0,3.4))
 game.selected = game.towers.find(nova)
 game.select_aim_mode("distribute")
 var stats: Dictionary = game.effective_stats(nova)
 for tick in range(180): game.drone_controller.update(game,nova,1.0/60,stats)
 expect(first.hp<first.maxhp and second.hp<second.maxhp,"Functional drones swarm and damage separate in-range enemies")
 expect(nova.drone_shots>0 and nova.drones.size()==3,"The fixed pool produces actual drone attacks without spawning extras")
 near(first.maxhp-first.hp+second.maxhp-second.hp,nova.drone_shots*18.0*1.18,"Live drones inherit carrier damage exactly once and ignore stronger drone-local auras")
 game.select_aim_mode("focus")
 for tick in range(30): game.drone_controller.update(game,nova,1.0/60,stats)
 for drone in nova.drones: expect(drone.target==nova.drones[0].target,"Focus mode makes all drones attack the same valid enemy")
 first.node.position = Vector3(30,.3,0)
 second.node.position = Vector3(-30,.3,0)
 var first_hp: float = first.hp
 var second_hp: float = second.hp
 for tick in range(90): game.drone_controller.update(game,nova,1.0/60,stats)
 expect(first.hp==first_hp and second.hp==second_hp,"Drones stop attacking immediately when enemies leave carrier range")
 for drone in nova.drones:
  expect(drone.target==null and drone.node.global_position.distance_to(nova.node.global_position)<1.7,"Out-of-range targets are released and drones return to the carrier")
 var transforms: Array = []
 for drone in nova.drones: transforms.append(drone.node.transform)
 game.toggle_pause()
 game._process(.5)
 for index in range(nova.drones.size()): expect(nova.drones[index].node.transform==transforms[index],"Pausing freezes drone movement with the rest of combat")

func check_effects_settings():
 reset()
 expect(Settings.defaults().get("effects_intensity")=="normal","New settings default to normal effect intensity")
 var legacy = Settings.defaults()
 legacy.erase("effects_intensity")
 expect(Settings.save_settings(legacy).ok,"Old settings without effects intensity remain readable")
 expect(Settings.load_settings().get("effects_intensity")=="normal","Old settings receive the normal effects default")
 var reduced = Settings.defaults()
 reduced.effects_intensity = "reduced"
 expect(Settings.save_settings(reduced).ok and Settings.load_settings().effects_intensity=="reduced","Reduced effects persist through settings loading")
 game.settings.effects_intensity = "normal"
 var before: int = game.effects.size()
 game.beam(Vector3.ZERO,Vector3(0,0,2),Color.WHITE,.03,.1)
 var normal_count: int = game.effects.size()-before
 game.settings.effects_intensity = "reduced"
 before = game.effects.size()
 game.beam(Vector3.ZERO,Vector3(0,0,2),Color.WHITE,.03,.1)
 expect(game.effects.size()-before==1 and normal_count>1,"Reduced effects retain the essential beam while removing its decorative glow")
 for index in range(300): game.pulse(Vector3.ZERO,1,Color.WHITE)
 expect(game.effects.size()<=game.MAX_EFFECTS,"Even repeated requests cannot exceed the bounded transient effect pool")

func economic_sample(receivers: int, with_relay: bool, invested: bool) -> Dictionary:
 reset()
 var receiver_cost = 100
 if invested:
  for tier in range(1,4): receiver_cost += Data.upgrade_for("lancer",0,tier).cost
 var budget = receivers*receiver_cost+190
 game.credits = budget
 var count = receivers if with_relay else receivers+1
 for index in range(count):
  var angle = index*TAU/count
  var tower = fixture_tower("lancer",Vector3(sin(angle)*2.5,0,cos(angle)*2.5))
  game.credits -= Data.tower_by_id("lancer").cost
  if index<receivers and invested: buy(tower,0,3)
  # The alternative spends the remaining budget on the best affordable damage
  # upgrade for its extra Lancer, instead of leaving 90 credits unused.
  if index==receivers and not with_relay: buy(tower,0,1)
  for _turn in range(90): game.steer_ship(tower,Vector3(0,.3,0),1.0/60)
 var relay: Dictionary = {}
 if with_relay:
  relay = fixture_tower("support",Vector3.ZERO)
  game.credits -= Data.tower_by_id("support").cost
  expect(game.support_recipients(relay.node.position,relay.aura_range).size()==receivers,"Economic sample covers all %d receivers without buffing its Relay" % receivers)
 activate()
 var target = enemy_at(Vector3.ZERO,1000000.0)
 for tick in range(240): game._process(1.0/60)
 return {"damage":target.maxhp-target.hp,"spent":budget-game.credits,"unspent":game.credits,"receivers":count}

func report_relay_economics():
 for invested in [false,true]:
  for count in [2,4,6]:
   var relay = economic_sample(count,true,invested)
   var weapon = economic_sample(count,false,invested)
   expect(relay.damage>0 and weapon.damage>0,"Both equal-budget economic scenarios must produce measurable combat damage")
   expect(relay.unspent==0 and weapon.unspent==20,"Economic comparisons spend affordable upgrades and report their remaining credits")
   print("RELAY ECONOMY: %d %s Lancers + Relay: %.2f damage / 4s, %d spent, %d unspent; same fleet + tier1 Lancer: %.2f damage / 4s, %d spent, %d unspent (stationary unarmored target; equal available budget)" % [count,"tier3" if invested else "base",relay.damage,relay.spent,relay.unspent,weapon.damage,weapon.spent,weapon.unspent])
