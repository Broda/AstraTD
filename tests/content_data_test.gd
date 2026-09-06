extends SceneTree

const Data = preload("res://scripts/data/game_data.gd")
var failures: Array = []
var checks = 0

func expect(condition: bool, message: String):
 checks += 1
 if not condition: failures.append(message)

func _init():
 check_maps_and_waves()
 check_legacy_content()
 check_upgrades()
 check_copy_isolation()
 if failures.is_empty():
  print("CONTENT DATA TEST PASSED: %d checks; map geometry, finite formations, stable IDs, complete upgrades, legacy parity, defensive copies" % checks)
 else:
  for failure in failures: push_error(failure)
 quit(0 if failures.is_empty() else 1)

func check_maps_and_waves():
 var ids: Array = []
 for map in Data.maps():
  expect(not ids.has(map.id),"Duplicate map ID")
  ids.append(map.id)
  expect(map.starting_credits>=400 and map.starting_core>0,"Map must have viable starting resources")
  expect(map.paths.size()==(2 if map.id=="twin_rift" else 1),"Unexpected map path count")
  for i in range(map.paths.size()):
   var points: PackedVector3Array = map.paths[i]
   expect(points.size()==181,"Each map path must have smooth sampled geometry")
   expect(points[0]==map.entry_gates[i] and points[-1]==map.exit_gates[i],"Gates must match path endpoints")
   var curve = Curve3D.new()
   var max_z = -INF
   var min_z = INF
   for point in points:
    curve.add_point(point)
    max_z=maxf(max_z,point.z)
    min_z=minf(min_z,point.z)
    expect(map.bounds.has_point(Vector2(point.x,point.z)),"Path must remain within playable bounds")
   expect(curve.get_baked_length()>33.0,"Winding map must provide a meaningful firing window")
   expect(max_z-min_z>4.0,"Map must have distinct turns")
  if map.final_wave==0:
   expect(Data.waves_for(map.id).is_empty(),"Endless maps use generated waves without a misleading final wave")
   continue
  var waves = Data.waves_for(map.id)
  expect(waves.size()==map.final_wave,"Every finite wave must be defined")
  expect(Data.wave_for(map.id,0).is_empty() and Data.wave_for(map.id,map.final_wave+1).is_empty(),"Reject out-of-range finite waves")
  expect(waves[0].spawns.count("raider")==waves[0].spawns.size(),"First wave teaches basic enemies")
  expect(waves[-1].boss,"Final formation must include a boss")
  var seen: Array = []
  var previous_health = 0.0
  for formation in waves:
   expect(formation.health_scale>previous_health,"Health must escalate between authored waves")
   previous_health=formation.health_scale
   expect(formation.spawns.size()>=9 and formation.spawns.size()<=42,"Finite wave density must stay in its intended range")
   expect(formation.interval>=0.45 and formation.reward>0 and formation.bonus>0,"Wave timing and rewards must be valid")
   for enemy_id in formation.spawns:
    var enemy = Data.enemy_for_wave(enemy_id,map.id,formation.number)
    expect(not enemy.is_empty() and enemy.hp>0 and enemy.speed>0 and enemy.reward>0,"All wave enemies require valid definitions")
    for field in ["hp","speed","reward","core_damage","armor","shield","regen","slow_resist","model"]:
     expect(enemy.has(field),"Enemy missing explicit combat field: "+field)
    if not seen.has(enemy_id): seen.append(enemy_id)
  expect(seen.size()==Data.ENEMIES.size(),"Each finite campaign must introduce all enemy archetypes")
 expect(ids.size()==4,"Initial lineup must include three finite maps and the classic endless map")
 var hard = Data.map_by_id("twin_rift")
 expect(hard.entry_gates[0]!=hard.entry_gates[1] and hard.exit_gates[0]==hard.exit_gates[1],"Twin Rift needs separate entries and a shared core")
 expect(Data.map_by_id("missing").is_empty(),"Unknown content IDs must be rejected")

func check_legacy_content():
 var baseline = [["lancer",100,14.0,5.1,0.48],["bastion",170,42.0,6.4,1.65],["nova",210,19.0,3.8,1.05],["cryostat",140,5.0,4.6,0.7]]
 for i in range(baseline.size()):
  var tower = Data.TOWERS[i]
  var old: Array = baseline[i]
  expect(tower.id==old[0] and tower.cost==old[1] and tower.damage==old[2] and tower.range==old[3] and tower.rate==old[4],"Original tower stats and index order must be unchanged")
 var old_map = Data.map_by_id("endless")
 expect(old_map.starting_credits==440 and old_map.starting_core==20 and old_map.final_wave==0,"Legacy resources must be preserved")
 for point in old_map.paths[0]:
  expect(is_equal_approx(point.z,sin((point.x+18)*0.38)*5.1+sin((point.x+20)*0.8)*0.7),"Legacy path must be preserved")
 for number in range(1,21):
  var formation = Data.wave_for("endless",number)
  expect(formation.spawns.size()==8+number*3,"Legacy enemy count changed")
  expect(formation.reward==35+number*8 and formation.bonus==45+number*10,"Legacy completion rewards changed")
  expect(is_equal_approx(formation.interval,maxf(0.25,0.9-number*0.024)),"Legacy interval changed")
  expect(formation.spawn_speed_multipliers.size()==formation.spawns.size(),"Per-spawn speed modifiers must align")
  for i in range(formation.spawns.size()):
   var remaining = formation.spawns.size()-i
   var elite = remaining==1 and number%5==0
   var fast = remaining%4==0 and number>=2 and not elite
   var armored = remaining%5==0 and number>=3 and not elite
   var expected_id = "dreadnought" if elite else ("armored" if armored else ("swift" if fast else "raider"))
   var enemy = Data.enemy_for_wave(formation.spawns[i],"endless",number)
   var hp = (34.0+number*14.0)*pow(1.13,number-1)*(7.0 if elite else (2.1 if armored else (0.7 if fast else 1.0)))
   var speed = (1.55+number*0.07)*(1.65 if fast else (0.7 if elite else 1.0))
   expect(formation.spawns[i]==expected_id,"Legacy spawn ordering changed")
   expect(is_equal_approx(enemy.hp,hp),"Legacy health changed")
   expect(is_equal_approx(enemy.speed*formation.spawn_speed_multipliers[i],speed),"Legacy speed changed, including swift armored overlap")
   expect(enemy.reward==(50+number*5 if elite else 10+number),"Legacy kill reward changed")
   expect(enemy.armor==0.0 and enemy.slow_resist==0.0,"Legacy defense behavior changed")
 expect(Data.enemy_for_wave("raider","endless",0).hp>0,"Pre-wave test spawns must remain supported")

func check_upgrades():
 var ids: Array = []
 for tower in Data.TOWERS:
  expect(Data.tower_index(tower.id)>=0,"Every tower has a stable lookup")
  expect(tower.branches.size()==2 and tower.branch_ids.size()==2,"Every tower needs two branches")
  for branch in range(2):
   var last_id = ""
   for tier in range(1,4):
    var item = Data.upgrade_for(tower.id,branch,tier)
    expect(not ids.has(item.id),"Upgrade IDs must be unique")
    ids.append(item.id)
    expect(item.cost==int(tower.cost*(0.7+(tier-1)*0.6)),"Upgrade costs must preserve the existing tier curve")
    expect(item.prerequisite==last_id and item.exclusive_branch==tower.branch_ids[1-branch],"Upgrade prerequisites and exclusivity must be explicit")
    expect(not item.description.is_empty(),"Upgrade effect must be explained before purchase")
    last_id=item.id
   expect(Data.upgrade_for(tower.id,branch,4).is_empty(),"Tiers beyond three must be rejected")
 expect(ids.size()==36,"Six towers need six upgrades each")
 var pulse = Data.upgrade_for("nova",0,1)
 expect(pulse.pulse_unlock and pulse.damage_multiplier==1.0 and pulse.range_add==0.0 and pulse.cost==147,"Nova pulse unlock must not secretly increase gun damage or range")
 for tier in range(1,4):
  expect(not Data.upgrade_for("nova",1,tier).pulse_unlock,"Alternate Nova branch must never unlock pulse")
 expect(Data.upgrade_for("nova",0,2).damage_multiplier==1.65 and Data.upgrade_for("nova",0,2).range_add==0.25,"Higher pulse tiers must preserve baseline behavior")
 expect(Data.upgrade_for("cryostat",0,3).slow_add==0.1,"Freeze upgrades must explicitly improve slowing")
 expect(Data.TOWERS[4].armor_pierce and Data.TOWERS[5].support>0,"New roles need explicit mechanics")
 expect(Data.upgrade_for("support",0,1).support_add>Data.upgrade_for("support",1,1).support_add,"Support branches must offer a meaningful strength/range tradeoff")
 expect(Data.upgrade_for("missing",0,1).is_empty() and Data.upgrade_for("lancer",2,1).is_empty(),"Invalid upgrade IDs/branches must be rejected")

func check_copy_isolation():
 var enemy = Data.enemy_by_id("raider")
 enemy.hp=0
 expect(Data.enemy_by_id("raider").hp==48.0,"Runtime HP must not mutate enemy definitions")
 var tower = Data.tower_by_id("nova")
 tower.branches[0]="corrupted"
 expect(Data.tower_by_id("nova").branches[0]=="Pulse Generator","Runtime choices must not mutate tower definitions")
 var map = Data.map_by_id("aurora_reach")
 map.paths.clear()
 expect(Data.map_by_id("aurora_reach").paths.size()==1,"Loading a map must receive independent geometry")
 var formation = Data.wave_for("aurora_reach",1)
 formation.spawns.clear()
 expect(Data.wave_for("aurora_reach",1).spawns.size()==9,"Runtime spawning must not consume shared wave definitions")
