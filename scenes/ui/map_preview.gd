extends Control
var definition: Dictionary
func _draw():
 draw_style_box(_background(),Rect2(Vector2.ZERO,size))
 var bounds: Rect2 = definition.bounds
 for points in definition.paths:
  var line = PackedVector2Array()
  for point in points:
   line.append(Vector2(16,14)+(Vector2(point.x,point.z)-bounds.position)/bounds.size*(size-Vector2(32,28)))
  draw_polyline(line,Color(definition.theme.accent,.16),13,true)
  draw_polyline(line,definition.theme.accent,2,true)
  draw_circle(line[0],5,Color("ff8090"))
  draw_circle(line[line.size()-1],6,Color("82ffbd"))
func _background() -> StyleBoxFlat:
 var style = StyleBoxFlat.new()
 style.bg_color = definition.theme.background.lightened(.035)
 style.set_corner_radius_all(10)
 return style
