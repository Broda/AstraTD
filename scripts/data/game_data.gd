extends RefCounted
## Stable, reusable content definitions. Runtime state must never be stored here.

const TOWERS = [
 {"id":"lancer", "name":"LANCER", "role":"Laser frigate", "model":"lancer", "cost":100, "damage":14.0, "range":5.1, "rate":0.48, "color":Color("55deff"), "branches":["Overcharged beams", "Long-range optics"], "branch_ids":["overcharge","optics"]},
 {"id":"bastion", "name":"BASTION", "role":"Missile cruiser · splash", "model":"bastion", "cost":170, "damage":42.0, "range":6.4, "rate":1.65, "color":Color("ffb454"), "branches":["Heavy warheads", "Rapid launchers"], "branch_ids":["warheads","launchers"]},
 {"id":"nova", "name":"NOVA", "role":"Defense station · four guns", "model":"nova", "cost":210, "damage":19.0, "range":3.8, "rate":1.05, "color":Color("b58aff"), "branches":["Pulse Generator", "Long-range guns"], "branch_ids":["pulse","guns"]},
 {"id":"cryostat", "name":"CRYOSTAT", "role":"Frost station · slows ships", "model":"cryostat", "cost":140, "damage":5.0, "range":4.6, "rate":0.7, "color":Color("62ffc1"), "branches":["Deep freeze", "Combat coolant"], "branch_ids":["freeze","coolant"], "slow":0.5, "slow_duration":2.0},
 {"id":"railgun", "name":"RAILGUN", "role":"Long-range armor piercing frigate", "model":"railgun", "cost":300, "damage":118.0, "range":8.2, "rate":2.35, "color":Color("ffd18a"), "branches":["Kinetic accelerator", "Targeting array"], "branch_ids":["accelerator","targeting"], "armor_pierce":true},
 {"id":"support", "name":"RELAY", "role":"Support station · nearby damage aura", "model":"relay", "cost":190, "damage":7.0, "range":5.6, "rate":1.1, "color":Color("73ffcf"), "branches":["Power amplification", "Extended relay"], "branch_ids":["amplification","relay"], "support":0.18}
]

const ENEMIES = {
 "raider":{"id":"raider", "name":"Raider", "model":"raider", "hp":48.0, "speed":1.62, "reward":11, "core_damage":1, "armor":0.0, "shield":0.0, "regen":0.0, "slow_resist":0.0, "scale":0.7, "color":Color("ff6581"), "description":"Standard hull. A flexible fleet handles these ships."},
 "swift":{"id":"swift", "name":"Swift", "model":"raider", "hp":33.6, "speed":2.673, "reward":11, "core_damage":1, "armor":0.0, "shield":0.0, "regen":0.0, "slow_resist":0.0, "scale":0.58, "color":Color("ffe77c"), "description":"Fast, fragile hull. Slow beams increase your firing window."},
 "armored":{"id":"armored", "name":"Armored", "model":"raider", "hp":100.8, "speed":1.62, "reward":11, "core_damage":1, "armor":4.0, "shield":0.0, "regen":0.0, "slow_resist":0.0, "scale":1.05, "color":Color("bec6da"), "description":"Reinforced hull reduces each hit by 4, to a minimum of 1. Railguns bypass armor."},
 "dreadnought":{"id":"dreadnought", "name":"Dreadnought", "model":"raider", "hp":336.0, "speed":1.134, "reward":55, "core_damage":4, "armor":6.0, "shield":0.0, "regen":0.0, "slow_resist":0.35, "scale":1.7, "color":Color("ff8e53"), "description":"Boss hull. Deals 4 core damage and resists 35% of slowing; focus heavy weapons."},
 "shielded":{"id":"shielded", "name":"Aegis", "model":"shielded", "hp":57.6, "speed":1.49, "reward":17, "core_damage":2, "armor":0.0, "shield":52.8, "regen":0.0, "slow_resist":0.1, "scale":0.95, "color":Color("69cdff"), "description":"Shield absorbs damage before hull and never regenerates. Sustained fire breaks it."},
 "regenerating":{"id":"regenerating", "name":"Mender", "model":"regenerator", "hp":79.2, "speed":1.38, "reward":19, "core_damage":2, "armor":0.0, "shield":0.0, "regen":3.6, "slow_resist":0.15, "scale":0.95, "color":Color("88ffc1"), "description":"Repairs hull continuously, capped at maximum health. Burst damage defeats regeneration."}
}

## Each row explicitly selects count, order, interval and scaling. New mechanics
## receive an introductory wave before appearing in combined/boss formations.
## Row: groups, interval, health multiplier, speed multiplier, completion, bonus.
const FINITE_WAVES = {
 "aurora_reach":[
  [[["raider",9]],0.95,0.90,0.94,43,55],
  [[["raider",6],["swift",4],["raider",3]],0.86,1.12,0.96,51,65],
  [[["raider",6],["armored",3],["swift",4]],0.84,1.40,0.98,59,75],
  [[["raider",7],["swift",5],["armored",3],["dreadnought",1]],0.79,1.75,1.00,85,90],
  [[["raider",6],["shielded",4],["swift",6]],0.76,2.18,1.03,75,95],
  [[["raider",5],["regenerating",4],["armored",4],["swift",5]],0.74,2.70,1.06,83,105],
  [[["swift",6],["shielded",4],["armored",4],["regenerating",3],["raider",5]],0.68,3.30,1.09,91,115],
  [[["raider",7],["shielded",4],["swift",6],["regenerating",3],["armored",4],["dreadnought",1]],0.64,4.00,1.12,180,150]
 ],
 "cobalt_bend":[
  [[["raider",11]],0.90,1.00,1.00,43,55],
  [[["raider",8],["swift",5]],0.84,1.28,1.02,51,65],
  [[["raider",7],["armored",4],["swift",5]],0.80,1.60,1.05,59,75],
  [[["raider",6],["shielded",4],["swift",6],["armored",2]],0.76,1.98,1.08,67,85],
  [[["raider",7],["armored",5],["swift",6],["shielded",3],["dreadnought",1]],0.72,2.45,1.11,110,110],
  [[["raider",7],["regenerating",5],["swift",7],["armored",3]],0.70,3.02,1.14,83,105],
  [[["shielded",5],["swift",8],["armored",5],["raider",6]],0.65,3.72,1.17,91,115],
  [[["swift",7],["regenerating",5],["armored",5],["shielded",5],["raider",5]],0.61,4.55,1.20,99,125],
  [[["armored",6],["swift",9],["shielded",6],["regenerating",5],["raider",5]],0.57,5.53,1.23,107,135],
  [[["swift",8],["shielded",6],["regenerating",5],["armored",7],["raider",7],["dreadnought",2]],0.55,6.65,1.26,230,180]
 ],
 "twin_rift":[
  [[["raider",12]],0.88,1.00,1.00,48,60],
  [[["raider",7],["swift",5],["armored",3]],0.82,1.26,1.03,56,70],
  [[["raider",6],["shielded",4],["swift",6],["armored",2]],0.77,1.58,1.06,64,80],
  [[["raider",6],["regenerating",3],["swift",6],["armored",4],["dreadnought",1]],0.73,1.95,1.09,115,110],
  [[["swift",7],["shielded",5],["armored",5],["raider",5]],0.69,2.39,1.12,80,100],
  [[["raider",6],["regenerating",5],["swift",7],["shielded",5]],0.66,2.91,1.15,88,110],
  [[["armored",6],["swift",8],["shielded",5],["regenerating",5],["raider",4]],0.62,3.52,1.18,96,120],
  [[["raider",6],["shielded",6],["swift",8],["regenerating",5],["armored",5],["dreadnought",1]],0.60,4.22,1.21,160,150],
  [[["swift",10],["armored",7],["shielded",6],["regenerating",5],["raider",5]],0.57,5.02,1.24,112,140],
  [[["shielded",8],["swift",10],["armored",7],["regenerating",6],["raider",5]],0.54,5.93,1.27,120,150],
  [[["armored",8],["regenerating",7],["swift",11],["shielded",8],["raider",5]],0.51,6.96,1.30,128,160],
  [[["swift",10],["shielded",8],["regenerating",7],["armored",9],["raider",6],["dreadnought",2]],0.48,8.12,1.33,300,210]
 ]
}

static func maps() -> Array:
 var result: Array = []
 result.append(_map("aurora_reach","Aurora Reach","Easy","A long, gentle corridor with generous shared firing windows. Learn each threat before the final siege.",520,25,8,[_path("aurora_reach",0)],Color("0a1431"),Color("62e5df")))
 result.append(_map("cobalt_bend","Cobalt Bend","Normal","Deep alternating bends reward overlapping fire and careful placement between the lanes.",460,20,10,[_path("cobalt_bend",0)],Color("12102d"),Color("b58aff")))
 result.append(_map("twin_rift","Twin Rift","Hard","Two winding approaches converge at the core. Split coverage or fortify their shared exit.",420,16,12,[_path("twin_rift",0),_path("twin_rift",1)],Color("201024"),Color("ffb06b")))
 result.append(_map("endless","Outer Rim","Endless","The original corridor: unchanged starting economy and endlessly escalating classic enemy formations.",440,20,0,[_path("endless",0)],Color("060b21"),Color("6ddedb")))
 return result

static func _map(id: String, title: String, difficulty: String, description: String, credits: int, core: int, final_wave: int, paths: Array, background: Color, accent: Color) -> Dictionary:
 var entries: Array = []
 var exits: Array = []
 for points in paths:
  entries.append(points[0])
  exits.append(points[points.size()-1])
 return {"id":id,"name":title,"difficulty":difficulty,"description":description,"starting_credits":credits,"starting_core":core,"starting_integrity":core,"final_wave":final_wave,"paths":paths,"entry_gates":entries,"exit_gates":exits,"bounds":Rect2(-21,-10.3,31.5,20.6),"theme":{"background":background,"accent":accent,"lane":accent.darkened(0.65),"preview":accent},"legacy":id=="endless"}

static func _path(map_id: String, branch: int) -> PackedVector3Array:
 var points = PackedVector3Array()
 for i in range(181):
  var progress = i/180.0
  var x = -20.0+progress*30.0
  var z = 0.0
  match map_id:
   "aurora_reach": z = sin(progress*TAU*1.05-0.35)*5.8
   "cobalt_bend": z = sin(progress*TAU*1.6-0.6)*6.2+sin(progress*TAU*3.2)*0.5
   "twin_rift":
    var side = -1.0 if branch==0 else 1.0
    z = side*(4.2+sin(progress*TAU*1.7)*2.8)*(1.0-smoothstep(0.78,1.0,progress))
   _: z = sin((x+18)*0.38)*5.1+sin((x+20)*0.8)*0.7
  points.append(Vector3(x,0,z))
 return points

static func map_by_id(id: String) -> Dictionary:
 for definition in maps():
  if definition.id==id: return definition
 return {}

static func tower_by_id(id: String) -> Dictionary:
 for definition in TOWERS:
  if definition.id==id: return definition.duplicate(true)
 return {}

static func tower_index(id: String) -> int:
 for i in range(TOWERS.size()):
  if TOWERS[i].id==id: return i
 return -1

static func enemy_by_id(id: String) -> Dictionary:
 return ENEMIES[id].duplicate(true) if ENEMIES.has(id) else {}

static func waves_for(map_id: String) -> Array:
 var result: Array = []
 if not FINITE_WAVES.has(map_id): return result
 for i in range(FINITE_WAVES[map_id].size()):
  result.append(wave_for(map_id,i+1))
 return result

static func wave_for(map_id: String, wave_number: int) -> Dictionary:
 if wave_number<1: return {}
 if map_id=="endless": return _endless_wave(wave_number)
 if not FINITE_WAVES.has(map_id) or wave_number>FINITE_WAVES[map_id].size(): return {}
 var row: Array = FINITE_WAVES[map_id][wave_number-1]
 var spawns: Array = []
 for group in row[0]:
  for _i in range(group[1]): spawns.append(group[0])
 var speed_multipliers: Array = []
 speed_multipliers.resize(spawns.size())
 speed_multipliers.fill(1.0)
 return {"id":"%s_wave_%02d" % [map_id,wave_number],"map_id":map_id,"number":wave_number,"spawns":spawns,"spawn_speed_multipliers":speed_multipliers,"interval":row[1],"health_scale":row[2],"speed_scale":row[3],"reward":row[4],"bonus":row[5],"kill_reward_add":wave_number-1,"legacy":false,"boss":spawns.has("dreadnought")}

static func _endless_wave(number: int) -> Dictionary:
 var spawns: Array = []
 var speed_multipliers: Array = []
 # Match the original countdown-based ordering, including armored precedence.
 for remaining in range(8+number*3,0,-1):
  var enemy_id = "raider"
  if remaining==1 and number%5==0: enemy_id="dreadnought"
  elif remaining%5==0 and number>=3: enemy_id="armored"
  elif remaining%4==0 and number>=2: enemy_id="swift"
  spawns.append(enemy_id)
  speed_multipliers.append(1.65 if enemy_id=="armored" and remaining%4==0 else 1.0)
 return {"id":"endless_wave_%04d" % number,"map_id":"endless","number":number,"spawns":spawns,"spawn_speed_multipliers":speed_multipliers,"interval":maxf(0.25,0.9-number*0.024),"health_scale":((34.0+number*14.0)*pow(1.13,number-1))/48.0,"speed_scale":(1.55+number*0.07)/1.62,"reward":35+number*8,"bonus":45+number*10,"kill_reward_add":number-1,"legacy":true,"boss":number%5==0}

static func enemy_for_wave(enemy_id: String, map_id: String, wave_number: int) -> Dictionary:
 var result = enemy_by_id(enemy_id)
 var formation = wave_for(map_id,maxi(1,wave_number))
 if result.is_empty() or formation.is_empty(): return {}
 result.hp *= formation.health_scale
 result.speed *= formation.speed_scale
 result.shield *= formation.health_scale
 result.regen *= formation.health_scale
 result.reward += formation.kill_reward_add*(5 if enemy_id=="dreadnought" else 1)
 if formation.legacy:
  result.armor = 0.0
  result.slow_resist = 0.0
 return result

static func upgrade_for(tower_id: String, branch: int, tier: int) -> Dictionary:
 var tower = tower_by_id(tower_id)
 if tower.is_empty() or branch<0 or branch>1 or tier<1 or tier>3: return {}
 var branch_id: String = tower.branch_ids[branch]
 var result = {"id":"%s_%s_t%d" % [tower_id,branch_id,tier],"tower_id":tower_id,"branch":branch,"branch_id":branch_id,"tier":tier,"name":tower.branches[branch],"cost":int(tower.cost*(0.7+(tier-1)*0.6)),"prerequisite":"%s_%s_t%d" % [tower_id,branch_id,tier-1] if tier>1 else "","exclusive_branch":tower.branch_ids[1-branch],"description":"","damage_multiplier":1.0,"range_add":0.0,"rate_multiplier":1.0,"slow_add":0.0,"pulse_unlock":false,"support_add":0.0}
 if tower_id=="support":
  result.support_add = 0.10 if branch==0 else 0.04
  result.range_add = 0.0 if branch==0 else 1.2
  result.description = "Aura damage +10 percentage points" if branch==0 else "Range +1.2 · aura damage +4 points"
 elif tower_id=="nova" and branch==0 and tier==1:
  result.pulse_unlock = true
  result.description = "Unlock area pulse; gun damage unchanged"
 elif branch==0:
  result.damage_multiplier = 1.65
  if tower_id=="nova": result.range_add=0.25
  if tower_id=="cryostat": result.slow_add=0.10
  result.description = "Damage +65%"
  if tower_id=="nova": result.description += " · range +0.25"
  if tower_id=="cryostat": result.description += " · slow +10 percentage points"
 else:
  result.damage_multiplier = 1.16
  if tower_id in ["lancer","nova","railgun"]:
   result.range_add = 1.2
   result.description = "Range +1.2 · damage +16%"
  else:
   result.rate_multiplier = 0.72
   result.description = "Cooldown −28% · damage +16%"
 return result
