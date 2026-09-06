extends RefCounted
## Shared targeting rules. First/Last compare remaining path length across lanes.

const MODES = ["first", "last", "strongest", "nearest", "unslowed"]

static func remaining(enemy: Dictionary) -> float:
 var route = enemy.get("route")
 return maxf(0.0, route.get_baked_length() - enemy.get("distance", 0.0)) if route != null else -float(enemy.get("distance", 0.0))

static func candidates(enemies: Array, origin: Vector3, reach: float, priority: String) -> Array:
 var result: Array = []
 for enemy in enemies:
  if enemy.get("hp", 0.0) > 0 and is_instance_valid(enemy.get("node")) and enemy.node.global_position.distance_to(origin) <= reach:
   result.append(enemy)
 result.sort_custom(func(a, b):
  match priority:
   "strongest":
    var a_health: float = a.hp + a.get("shield", 0.0)
    var b_health: float = b.hp + b.get("shield", 0.0)
    if not is_equal_approx(a_health, b_health): return a_health > b_health
   "nearest":
    var a_distance = a.node.global_position.distance_squared_to(origin)
    var b_distance = b.node.global_position.distance_squared_to(origin)
    if not is_equal_approx(a_distance, b_distance): return a_distance < b_distance
   "unslowed":
    if (a.get("slow", 0.0) <= 0.0) != (b.get("slow", 0.0) <= 0.0): return a.get("slow", 0.0) <= 0.0
   "last":
    if not is_equal_approx(remaining(a), remaining(b)): return remaining(a) > remaining(b)
  if not is_equal_approx(remaining(a), remaining(b)): return remaining(a) < remaining(b)
  return a.get("spawn_id", 0) < b.get("spawn_id", 0))
 return result
