extends SceneTree

const Data = preload("res://scripts/data/game_data.gd")
const Stats = preload("res://scripts/data/fleet_stats.gd")
var failures: Array = []
var checks := 0

func expect(condition: bool, message: String):
 checks += 1
 if not condition: failures.append(message)

func near(actual: float, expected: float, message: String):
 expect(is_equal_approx(actual,expected),message+" (%.5f vs %.5f)" % [actual,expected])

func _init():
 check_owned_and_preview()
 check_nova_weapons()
 check_relay_paths_and_effective_stats()
 if failures.is_empty():
  print("UPGRADE DATA TEST PASSED: %d checks; prerequisite projections, purchased nodes, exclusive paths, separate Nova weapons, strongest per-stat support, owner-only inheritance, Relay isolation" % checks)
 else:
  for failure in failures: push_error(failure)
 quit(0 if failures.is_empty() else 1)

func check_owned_and_preview():
 for tower in Data.TOWERS:
  var base = Stats.base_stats(tower.id)
  expect(base.tower_id==tower.id and base.drone_count==0 and not base.pulse_enabled,"Unupgraded ships have no paid weapons")
  expect(not base.has("scale"),"Stat calculations must never change model scale")
  for branch in range(tower.branch_ids.size()):
   var owned = Stats.base_stats(tower.id)
   for tier in range(1,4):
    var before = owned.duplicate(true)
    var preview = Stats.preview(tower.id,owned,-1 if tier==1 else branch,tier-1,branch,tier)
    expect(owned==before,"Preview must not mutate owned stats")
    Stats.apply_upgrade(owned,Data.upgrade_for(tower.id,branch,tier))
    expect(preview==owned,"The next-purchase preview must match the actual resulting stats")
    expect(Stats.preview(tower.id,owned,branch,tier,branch,tier)==owned,"An installed tier must show current stats without applying it again")
    for alternative in range(tower.branch_ids.size()):
     if alternative!=branch:
      expect(Stats.preview(tower.id,owned,branch,tier,alternative,1).is_empty(),"An exclusive path must not imply that it can be purchased")
 var lancer = Stats.base_stats("lancer")
 var final = Stats.preview("lancer",lancer,-1,0,0,3)
 near(final.damage,14.0*1.65*1.65*1.65,"A future tier preview must include all prerequisite multipliers")
 Stats.apply_upgrade(lancer,Data.upgrade_for("lancer",0,1))
 near(Stats.preview("lancer",lancer,0,1,0,3).damage,final.damage,"A future tier from an owned first tier applies only missing upgrades")
 expect(Stats.preview("lancer",lancer,0,1,0,4).is_empty(),"Out-of-range tiers must not produce fabricated stats")
 expect(Stats.preview("lancer",lancer,-1,1,0,2).is_empty(),"Inconsistent owned prerequisites must be rejected")
 var cooling = Stats.base_stats("cryostat")
 for tier in range(1,4): Stats.apply_upgrade(cooling,Data.upgrade_for("cryostat",0,tier))
 near(cooling.slow_power,0.8,"Deep freeze retains its real slowing progression")
 near(cooling.slow_duration,2.0,"Slowing duration must be explicit and stable")
 near(Stats.base_stats("bastion").splash_radius,1.5,"Bastion splash radius must be defined in shared stats")
 var runtime = Stats.base_stats("lancer")
 runtime.node = "scene object placeholder"
 runtime.guns = [{"cooldown":0.0}]
 expect(not Stats.effective(runtime).has("guns") and not Stats.copy_stats(runtime).has("node"),"Preview/effective copies must exclude scene state")

func check_nova_weapons():
 var nova = Stats.base_stats("nova")
 expect(nova.gun_count==4,"Nova must retain four independent guns")
 var initial = nova.duplicate(true)
 Stats.apply_upgrade(nova,Data.upgrade_for("nova",0,1))
 expect(nova.pulse_enabled and nova.drone_count==0,"The paid first pulse upgrade unlocks only the pulse")
 near(nova.damage,19.0,"The paid pulse unlock must not change gun damage")
 near(Stats.effective(nova).pulse_damage,19.0,"Pulse damage must be exposed independently from four gun hits")
 var drones = Stats.base_stats("nova")
 for tier in range(1,4):
  Stats.apply_upgrade(drones,Data.upgrade_for("nova",2,tier))
  expect(drones.drone_count==tier,"Every drone purchase adds exactly one deployed drone")
  expect(not drones.pulse_enabled and drones.damage==initial.damage and drones.range==initial.range and drones.rate==initial.rate,"Drones preserve all existing gun behavior and pulse exclusivity")
  var supported = Stats.effective(drones,{"damage":0.28,"range":0.24,"fire_rate":0.36})
  near(supported.drone_damage,18.0*1.28,"Drone damage inherits carrier damage support exactly once")
  near(supported.drone_rate,0.7/1.36,"Drone cooldown inherits carrier fire-rate support exactly once")
  near(supported.range,3.8*1.24,"Carrier weapon range defines supported drone engagement boundary")
  near(supported.drone_reach,1.4,"Drone-local weapon reach remains separate from carrier range")
  expect(drones.drone_damage==18.0 and drones.drone_rate==0.7,"Effective support cannot accumulate in owned drone stats")
 expect(Stats.effective(initial).pulse_damage==0.0 and Stats.effective(initial).drone_attacks_per_second==0.0,"Absent weapons must not imply active damage")

func check_relay_paths_and_effective_stats():
 var relay = Stats.base_stats("support")
 expect(relay.support_only and relay.damage==0.0 and relay.gun_count==0,"Relay has no offensive channels")
 near(relay.aura_range,5.6,"Relay support coverage is separately defined")
 var amplified = Stats.preview("support",relay,-1,0,0,3)
 var extended = Stats.preview("support",relay,-1,0,1,3)
 var rapid = Stats.preview("support",relay,-1,0,2,3)
 near(amplified.support_damage,0.48,"Damage path adds ten points each tier exactly once")
 near(amplified.support,amplified.support_damage,"Legacy support alias stays synchronized without duplicate gains")
 near(extended.support_range,0.36,"Range path grants recipient weapon range")
 near(extended.aura_range,6.8,"Coverage gains are distinct from recipient weapon range")
 near(extended.support_damage,0.18,"Range path retains only the baseline damage bonus")
 near(rapid.support_fire_rate,0.36,"Fire-control path increases attacks per second rather than subtracting cooldown points")
 near(rapid.support_damage,0.18,"Fire-control path cannot secretly gain damage")
 var weaker = relay.duplicate(true)
 weaker.support_damage=0.28
 weaker.support_range=0.12
 weaker.support_fire_rate=0.12
 var buffs = Stats.strongest_buffs([weaker,amplified,extended,rapid,amplified])
 near(buffs.damage,0.48,"Overlapping damage auras use strongest bonus without stacking")
 near(buffs.range,0.36,"Range may combine from a different Relay")
 near(buffs.fire_rate,0.36,"Fire rate may combine from a different Relay")
 var lancer = Stats.base_stats("lancer")
 var actual = Stats.effective(lancer,buffs)
 near(actual.damage,14.0*1.48,"Effective damage applies the strongest damage bonus")
 near(actual.range,5.1*1.36,"Effective weapon range applies the strongest range bonus")
 near(actual.rate,0.48/1.36,"A 36% fire-rate bonus divides cooldown by 1.36")
 near(actual.damage*actual.attacks_per_second,(14.0/0.48)*1.48*1.36,"Damage and fire-rate effects multiply their DPS contributions")
 near(actual.base_damage,14.0,"UI can distinguish owned stats from supported stats")
 expect(lancer.damage==14.0 and lancer.range==5.1 and lancer.rate==0.48,"Computing effective stats never mutates owned stats")
 var relay_buffed = Stats.effective(relay,buffs)
 expect(relay_buffed.damage==0.0 and relay_buffed.attacks_per_second==0.0 and relay_buffed.aura_range==relay.aura_range,"Relays cannot gain attacks or coverage through other Relays")
 near(relay_buffed.support_damage,relay.support_damage,"Relays cannot amplify other Relay bonuses")
 var removed = Stats.effective(lancer,Stats.strongest_buffs([]))
 expect(removed.damage==lancer.damage and removed.range==lancer.range and removed.rate==lancer.rate,"Removing all support immediately restores owned stats")
