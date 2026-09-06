extends RefCounted
## Shared owned, projected, and supported combat values. No scene objects or scale
## enter these calculations. Cooldowns are seconds; support bonuses are fractions.

const Data = preload("res://scripts/data/game_data.gd")
const MAX_DRONES := 3
const STAT_KEYS = ["tower_id", "damage", "range", "rate", "support_only", "aura_range", "support", "support_damage", "support_range", "support_fire_rate", "slow_power", "slow_duration", "splash_radius", "pulse_enabled", "drone_count", "drone_damage", "drone_rate", "drone_reach", "armor_pierce", "gun_count"]

static func base_stats(tower_id: String) -> Dictionary:
 var tower = Data.tower_by_id(tower_id)
 if tower.is_empty(): return {}
 return {"tower_id":tower_id,"damage":tower.damage,"range":tower.range,"rate":tower.rate,"support_only":tower.get("support_only",false),"aura_range":tower.get("aura_range",0.0),"support":tower.get("support_damage",0.0),"support_damage":tower.get("support_damage",0.0),"support_range":tower.get("support_range",0.0),"support_fire_rate":tower.get("support_fire_rate",0.0),"slow_power":tower.get("slow",0.0),"slow_duration":tower.get("slow_duration",0.0),"splash_radius":tower.get("splash_radius",0.0),"pulse_enabled":false,"drone_count":0,"drone_damage":tower.get("drone_damage",0.0),"drone_rate":tower.get("drone_rate",1.0),"drone_reach":tower.get("drone_reach",0.0),"armor_pierce":tower.get("armor_pierce",false),"gun_count":tower.get("gun_count",1)}

static func copy_stats(stats: Dictionary) -> Dictionary:
 var result: Dictionary = {}
 for key in STAT_KEYS:
  if stats.has(key): result[key] = stats[key]
 return result

static func apply_upgrade(stats: Dictionary, spec: Dictionary) -> Dictionary:
 if stats.is_empty() or spec.is_empty(): return stats
 stats.damage *= spec.get("damage_multiplier",1.0)
 stats.range += spec.get("range_add",0.0)
 stats.rate *= spec.get("rate_multiplier",1.0)
 stats.slow_power = minf(0.85,stats.get("slow_power",0.0)+spec.get("slow_add",0.0))
 stats.slow_duration = stats.get("slow_duration",0.0)+spec.get("slow_duration_add",0.0)
 stats.splash_radius = stats.get("splash_radius",0.0)+spec.get("splash_radius_add",0.0)
 stats.pulse_enabled = stats.get("pulse_enabled",false) or spec.get("pulse_unlock",false)
 stats.support_damage = stats.get("support_damage",stats.get("support",0.0))+spec.get("support_damage_add",spec.get("support_add",0.0))
 stats.support = stats.support_damage
 stats.support_range = stats.get("support_range",0.0)+spec.get("support_range_add",0.0)
 stats.support_fire_rate = stats.get("support_fire_rate",0.0)+spec.get("support_fire_rate_add",0.0)
 stats.aura_range = stats.get("aura_range",0.0)+spec.get("aura_range_add",0.0)
 stats.drone_count = clampi(stats.get("drone_count",0)+spec.get("drone_add",0),0,MAX_DRONES)
 return stats

static func preview(tower_id: String, owned_stats: Dictionary, owned_branch: int, owned_tier: int, target_branch: int, target_tier: int) -> Dictionary:
 if Data.upgrade_for(tower_id,target_branch,target_tier).is_empty(): return {}
 if owned_tier<0 or owned_tier>3 or (owned_tier==0)!=(owned_branch==-1): return {}
 if owned_tier>0 and owned_branch!=target_branch: return {}
 var result = copy_stats(owned_stats)
 if result.is_empty(): return {}
 # Inspecting an installed tier reports current owned stats, never applies it twice.
 for tier in range(owned_tier+1,target_tier+1):
  apply_upgrade(result,Data.upgrade_for(tower_id,target_branch,tier))
 return result

static func strongest_buffs(sources: Array) -> Dictionary:
 var result = {"damage":0.0,"range":0.0,"fire_rate":0.0}
 for source in sources:
  result.damage = maxf(result.damage,source.get("support_damage",source.get("support",0.0)))
  result.range = maxf(result.range,source.get("support_range",0.0))
  result.fire_rate = maxf(result.fire_rate,source.get("support_fire_rate",0.0))
 return result

static func effective(stats: Dictionary, buffs: Dictionary = {}) -> Dictionary:
 var result = copy_stats(stats)
 if result.is_empty(): return {}
 result.base_damage = stats.damage
 result.base_range = stats.range
 result.base_rate = stats.rate
 var eligible = not stats.get("support_only",false)
 var damage_bonus = maxf(0.0,buffs.get("damage",0.0)) if eligible else 0.0
 var range_bonus = maxf(0.0,buffs.get("range",0.0)) if eligible else 0.0
 var fire_bonus = maxf(0.0,buffs.get("fire_rate",0.0)) if eligible else 0.0
 result.damage *= 1.0+damage_bonus
 result.range *= 1.0+range_bonus
 result.rate /= 1.0+fire_bonus
 # These are already supported carrier values. Drones must not scan auras again.
 result.drone_damage = stats.get("drone_damage",0.0)*(1.0+damage_bonus)
 result.drone_rate = stats.get("drone_rate",1.0)/(1.0+fire_bonus)
 result.attacks_per_second = 1.0/result.rate if eligible else 0.0
 result.drone_attacks_per_second = 1.0/result.drone_rate if stats.get("drone_count",0)>0 else 0.0
 result.pulse_damage = result.damage if stats.get("pulse_enabled",false) else 0.0
 result.pulse_rate = result.rate
 result.buffs = {"damage":damage_bonus,"range":range_bonus,"fire_rate":fire_bonus}
 return result
