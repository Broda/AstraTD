import bpy, math, os
from mathutils import Vector
OUT = os.environ.get('WARDENS_ASSETS', os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'assets') if os.path.basename(os.path.dirname(__file__)) == 'source' else r'C:\Users\david.green\Documents\Codex\2026-09-05\does-godot-have-to-be-running\outputs\WormholeWardens\assets')
os.makedirs(OUT,exist_ok=True)
def material(name,color,metal=0.6,glow=0):
 m=bpy.data.materials.new(name); m.diffuse_color=(*color,1); m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF'); p.inputs['Base Color'].default_value=(*color,1); p.inputs['Metallic'].default_value=metal; p.inputs['Roughness'].default_value=.32
 p.inputs['Emission Color'].default_value=(*color,1); p.inputs['Emission Strength'].default_value=glow
 return m
def box(loc,scale,mat):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc); o=bpy.context.object;o.scale=scale;o.data.materials.append(mat)
 mod=o.modifiers.new('Machined edges','BEVEL');mod.width=.10;mod.segments=2
 bpy.context.view_layer.objects.active=o;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);bpy.ops.object.modifier_apply(modifier=mod.name)
 return o
def orb(loc,r,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,radius=r,location=loc);bpy.context.object.data.materials.append(mat)
def cone(loc,r,depth,mat):
 bpy.ops.mesh.primitive_cone_add(vertices=6,radius1=r,radius2=0,depth=depth,location=loc);o=bpy.context.object;o.rotation_euler[0]=math.pi/2;o.data.materials.append(mat)
def ring(r,z,mat):
 bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=.12,major_segments=32,minor_segments=6,location=(0,0,z));bpy.context.object.data.materials.append(mat)
def build(kind):
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 hull=material('Titanium',(0.18,.25,.38)); pale=material('Ceramic',(.62,.75,.84)); dark=material('Carbon',(.045,.065,.11))
 color=[(.15,.9,1),(.99,.55,.16),(.65,.32,1),(.2,1,.63),(1,.16,.37)][kind]
 light=material('Reactor',color,.25,.7)
 if kind==0:
  box((0,0,.25),(.42,1.5,.28),pale);cone((0,-.95,.25),.27,.8,pale)
  for x in [-.48,.48]:
   box((x,.2,.2),(.26,1.15,.24),hull);box((x,.82,.2),(.18,.16,.18),light);box((x,-.6,.25),(.10,.6,.1),dark)
  box((0,-.15,.43),(.21,.42,.10),light)
 elif kind==1:
  box((0,0,.25),(.75,1.45,.38),hull);cone((0,-.96,.25),.48,.65,pale)
  for x in [-.64,.64]:
   box((x,.1,.26),(.44,1.05,.3),pale)
   for y in [-.28,.08,.44]:box((x,y,.46),(.24,.20,.10),light)
  box((0,.84,.25),(.5,.18,.25),light)
 elif kind==2:
  ring(.86,.2,hull);ring(.84,.28,light);orb((0,0,.35),.35,light)
  for i in range(4):
   a=i*math.pi/2;x=math.cos(a);y=math.sin(a)
   o=box((x*.52,y*.52,.18),(.9,.14,.15),pale);o.rotation_euler[2]=a
   box((x,y,.28),(.34,.34,.45),hull)
 elif kind==3:
  ring(.64,.25,pale);orb((0,0,.3),.25,light)
  for x in [-.92,.92]:
   box((x,0,.2),(.48,1.35,.09),dark)
   for y in [-.4,0,.4]:box((x,y,.26),(.40,.24,.035),light)
  box((0,0,.1),(1.8,.18,.15),hull);ring(.4,.5,light)
 else:
  cone((0,-.25,.25),.4,1.35,hull)
  for x in [-.42,.42]:
   o=box((x,.25,.25),(.22,.85,.15),dark);o.rotation_euler[2]=x
   orb((x,.64,.25),.12,light)
  box((0,-.3,.35),(.18,.3,.10),light)
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=os.path.join(OUT,['lancer','bastion','nova','cryostat','raider'][kind]+'.glb'),export_format='GLB',use_selection=True)
 source=os.path.join(os.path.dirname(OUT),'source');os.makedirs(source,exist_ok=True)
 bpy.ops.wm.save_as_mainfile(filepath=os.path.join(source,['lancer','bastion','nova','cryostat','raider'][kind]+'.blend'))
for k in range(5):build(k)
