extends RefCounted
## Uses only legal placement, normal purchases, earned credits and combat damage.

const Data = preload("res://game_data.gd")
const MAP_IDS = ["aurora_reach","cobalt_bend","twin_rift"]
var candidates: Array = []
var route_samples: Array = []
var purchases = 0
var total_spent = 0

func run(game):
 print("BALANCE RUNNER STARTED")
 game.set_process(false)
 var results: Array = []
 var failures: Array = []
 var selected_map = ""
 var selected_strategy = ""
 for argument in OS.get_cmdline_user_args():
  if argument.begins_with("--balance-map="): selected_map=argument.trim_prefix("--balance-map=")
  if argument.begins_with("--balance-strategy="): selected_strategy=argument.trim_prefix("--balance-strategy=")
 for map_id in MAP_IDS:
  if not selected_map.is_empty() and selected_map!=map_id: continue
  for strategy in ["precision","combined_arms"]:
   if not selected_strategy.is_empty() and selected_strategy!=strategy: continue
   game.start_run(map_id)
   await game.get_tree().process_frame
   prepare_positions(game)
   purchases = 0
   total_spent = 0
   var plan = purchase_plan(strategy)
   var next_purchase = 0
   var frames_total = 0
   while game.integrity>0 and game.completed_waves<game.map_data.final_wave:
    next_purchase = spend_preparation(game,plan,next_purchase)
    assert(game.credits>=0,"A balance strategy may not spend unearned credits")
    var balance_before: int = game.credits
    var wave_before: int = game.wave
    game.start_wave()
    assert(game.active and game.wave==wave_before+1,"Balance campaign must manually start each legal next wave")
    var frames = 0
    while game.active and frames<12000:
     game._process(1.0/30.0)
     frames += 1
     if frames%300==0: await game.get_tree().process_frame
    frames_total += frames
    assert(frames<12000,"Balance wave exceeded 400 simulated seconds")
    assert(not game.spent,"All balance strategy purchases must occur between waves")
    assert(game.credits>=balance_before,"Normal combat cannot remove credits")
    print("BALANCE %s / %s wave=%d core=%d kills=%d credits=%d towers=%d" % [map_id,strategy,game.wave,game.integrity,game.kills,game.credits,game.towers.size()])
   var won: bool = game.integrity>0 and game.completed_waves==game.map_data.final_wave
   var fleet: Array = []
   for tower in game.towers:
    fleet.append("%s:%d/%d@(%.1f,%.1f)" % [Data.TOWERS[tower.kind].id,tower.branch,tower.level,tower.node.position.x,tower.node.position.z])
   var result = "%s / %s: %s, core %d/%d, %d kills, %d earned cr, %d spent cr, %d purchases, %.1fs simulated; fleet=%s" % [map_id,strategy,"VICTORY" if won else "DEFEAT",game.integrity,game.map_data.starting_core,game.kills,game.credits+total_spent-game.map_data.starting_credits,total_spent,purchases,frames_total/30.0,", ".join(fleet)]
   print("BALANCE RESULT "+result)
   results.append(result)
   if not won: failures.append(result)
 if results.is_empty(): failures.append("No campaigns matched the requested balance filters")
 if selected_map.is_empty() and selected_strategy.is_empty() and results.size()!=6: failures.append("The complete balance suite must run all six campaigns")
 for result in results: print(result)
 if failures.is_empty():
  print("BALANCE TEST PASSED: %d campaigns won with earned credits and normal combat" % results.size())
 else:
  for failure in failures: push_error("Unproven strategy: "+failure)
 game.get_tree().quit(0 if failures.is_empty() else 1)

func purchase_plan(strategy: String) -> Array:
 # Entries are [build kind] or [upgrade tower index, branch]. A plan only moves
 # forward when its next purchase is affordable; there is no combat spending.
 # Precision adds one missile cruiser for dense waves, then reinvests in rails.
 # Combined arms develops a Nova/Bastion/Relay station cluster.
 var plan: Array
 if strategy=="precision":
  plan=[[0],[4],[0,0],[3],[0,0],[1,0],[0,0],[0],[3,0],[3,0],[3,0],[1],[4,0],[1,0],[1,0],[4,0],[4,0],[2,0],[2,0],[2,0]]
  for _i in range(6):
   var index = 5+_i
   plan.append([0 if _i<3 else 4])
   for _tier in range(3): plan.append([index,0])
 else:
  plan=[[2],[1],[0,0],[5],[0,0],[1,0],[0,0],[2,0],[1,0],[1,0],[2,0],[2,0],[2],[3,0],[3,0],[3,0],[1],[4,1],[4,1],[4,1]]
  for _i in range(3):
   var index = 5+_i
   plan.append([2])
   for _tier in range(3): plan.append([index,0])
 return plan

func spend_preparation(game, plan: Array, next_purchase: int) -> int:
 assert(not game.active and game.can_manage(),"Purchases require preparation")
 while next_purchase<plan.size():
  var entry: Array = plan[next_purchase]
  var before: int = game.credits
  if entry.size()==1:
   var kind: int = entry[0]
   if game.credits<Data.TOWERS[kind].cost: break
   var position = best_position(game,kind)
   if position==Vector3.INF: break
   assert(game.deploy(kind,position),"Greedy placement must use normal legal deployment")
  else:
   var index: int = entry[0]
   assert(index<game.towers.size(),"Upgrade plan must refer to an already purchased tower")
   var tower: Dictionary = game.towers[index]
   var spec = Data.upgrade_for(Data.TOWERS[tower.kind].id,entry[1],tower.level+1)
   assert(not spec.is_empty(),"Upgrade plan must respect tier and branch limits")
   if game.credits<spec.cost: break
   game.selected=index
   var tier_before: int = tower.level
   game.upgrade(entry[1])
   assert(tower.level==tier_before+1,"Balance strategy must buy upgrades through the normal game action")
  assert(game.credits<before,"Every balance purchase must charge its normal price")
  total_spent += before-game.credits
  purchases += 1
  next_purchase += 1
 return next_purchase

func prepare_positions(game):
 candidates.clear()
 route_samples.clear()
 for route in game.map_paths:
  var length: float = route.get_baked_length()
  var distance = 0.0
  while distance<=length:
   route_samples.append({"position":route.sample_baked(distance),"weight":1.0+0.8*pow(distance/length,2)})
   distance+=1.2
 for xi in range(24):
  for zi in range(16):
   var position = Vector3(-19.5+xi*1.25,0,-9.4+zi*1.25)
   if game.can_place(position): candidates.append(position)
 assert(not candidates.is_empty(),"Every finite map must provide legal build locations")

func best_position(game, kind: int) -> Vector3:
 var result = Vector3.INF
 var best_score = -INF
 var reach: float = Data.TOWERS[kind].range
 for position in candidates:
  if not game.can_place(position): continue
  var score = 0.0
  for sample in route_samples:
   var distance: float = position.distance_to(sample.position)
   if distance<reach:
    score += sample.weight*(0.85+0.15*(1.0-distance/reach))
  if kind==5:
   # Relay benefits from supporting invested weapons at an existing chokepoint.
   for tower in game.towers:
    if tower.node.position.distance_to(position)<=reach:
     score += 0.3*tower.damage/tower.rate*(4.0 if tower.kind==2 else 1.0)
  elif kind==3:
   for tower in game.towers:
    if tower.node.position.distance_to(position)<tower.range:
     score *= 1.12
  if score>best_score:
   best_score=score
   result=position
 return result
