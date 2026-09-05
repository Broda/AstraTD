extends Node3D

const CAPACITY = 2400
var particles: Array = []
var cloud: MultiMeshInstance3D
var random = RandomNumberGenerator.new()

func _ready():
 random.seed = 8451
 cloud = MultiMeshInstance3D.new()
 var mm = MultiMesh.new()
 mm.transform_format = MultiMesh.TRANSFORM_3D
 mm.use_colors = true
 var quad = QuadMesh.new()
 quad.size = Vector2.ONE
 mm.mesh = quad
 mm.instance_count = CAPACITY
 mm.visible_instance_count = 0
 cloud.multimesh = mm
 var material = StandardMaterial3D.new()
 material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
 material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
 material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
 material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
 material.vertex_color_use_as_albedo = true
 material.no_depth_test = false
 var texture = Image.create(48,48,false,Image.FORMAT_RGBA8)
 for y in range(48):
  for x in range(48):
   var radius = Vector2(x-23.5,y-23.5).length()/23.5
   var alpha = pow(maxf(0,1-radius),2.8)
   texture.set_pixel(x,y,Color(1,1,1,alpha))
 material.albedo_texture = ImageTexture.create_from_image(texture)
 cloud.material_override = material
 add_child(cloud)

func add_particle(pos: Vector3, velocity: Vector3, color: Color, life: float, size: float, center = Vector3.INF):
 if particles.size() >= CAPACITY: return
 particles.append({"pos":pos,"start":pos,"vel":velocity,"color":color,"life":life,"max":life,"size":size,"center":center})

func jet(pos: Vector3, direction: Vector3, color: Color, count = 3):
 for i in range(count):
  var spread = Vector3(random.randf_range(-.3,.3),random.randf_range(-.12,.12),random.randf_range(-.3,.3))
  add_particle(pos,(direction+spread)*random.randf_range(1.5,3.7),color,random.randf_range(.15,.34),random.randf_range(.18,.32))

func sparks(pos: Vector3, color = Color("ffc675")):
 for i in range(13):
  var angle = random.randf()*TAU
  var direction = Vector3(cos(angle),random.randf_range(-.15,.7),sin(angle))
  add_particle(pos,direction*random.randf_range(1.1,4.2),color.lerp(Color.WHITE,random.randf()*.65),random.randf_range(.16,.42),random.randf_range(.12,.24))
 add_particle(pos,Vector3.ZERO,Color("e5faff"),.12,.85)

func implode(pos: Vector3, large: bool):
 var radius = 2.0 if large else 1.15
 for i in range(65 if large else 36):
  var angle = random.randf()*TAU
  var offset = Vector3(cos(angle),random.randf_range(-.25,.25),sin(angle))*random.randf_range(.35,radius)
  add_particle(pos+offset,Vector3.ZERO,Color("b999ff").lerp(Color("72ebff"),random.randf()),random.randf_range(.4,.72),random.randf_range(.16,.34),pos)
 add_particle(pos,Vector3.ZERO,Color("b4ddff"),.7,1.6 if large else 1.0)

func update(delta: float):
 for i in range(particles.size()-1,-1,-1):
  var p = particles[i]
  p.life -= delta
  if p.life <= 0:
   particles.remove_at(i)
   continue
  var age = 1.0-p.life/p.max
  if p.center != Vector3.INF:
   p.pos = p.center + (p.start-p.center).rotated(Vector3.UP,age*3.5)*pow(1-age,1.6)
  else:
   p.pos += p.vel*delta
   p.vel *= exp(-2.0*delta)
 for i in range(particles.size()):
  var p = particles[i]
  var age = 1.0-p.life/p.max
  var scale = p.size*(.4+.6*(1-age))
  cloud.multimesh.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*scale),p.pos))
  var color: Color = p.color
  color.a = pow(1-age,.7)
  cloud.multimesh.set_instance_color(i,color)
 cloud.multimesh.visible_instance_count = particles.size()
