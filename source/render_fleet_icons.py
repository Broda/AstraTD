import bpy, os, math
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__))) if os.path.basename(os.path.dirname(__file__))=='source' else r'C:\_Projects\Personal\AstraTD'
os.makedirs(os.path.join(ROOT,'assets','icons'),exist_ok=True)
for name in ['lancer','bastion','nova','cryostat','raider']:
 bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,'source',name+'.blend'))
 for m in bpy.data.materials:
  if not m.use_nodes: continue
  p=m.node_tree.nodes.get('Principled BSDF')
  if p:
   p.inputs['Emission Strength'].default_value=min(p.inputs['Emission Strength'].default_value,.7)
   p.inputs['Roughness'].default_value=.4
   p.inputs['Metallic'].default_value=.4
 bpy.ops.object.select_all(action='SELECT')
 bpy.ops.export_scene.gltf(filepath=os.path.join(ROOT,'assets',name+'.glb'),export_format='GLB',use_selection=True)
 bpy.context.preferences.filepaths.save_version=0
 bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'source',name+'.blend'))
 if name=='raider': continue
 scene=bpy.context.scene
 scene.render.engine='CYCLES';scene.cycles.samples=24
 scene.render.resolution_x=192;scene.render.resolution_y=192;scene.render.resolution_percentage=100
 scene.render.film_transparent=True
 scene.world.color=(.18,.18,.18)
 bpy.ops.object.camera_add(location=(2.3,-3.3,6.2))
 camera=bpy.context.object;camera.rotation_euler=((Vector((0,0,.2))-camera.location).to_track_quat('-Z','Y').to_euler())
 camera.data.type='ORTHO';camera.data.ortho_scale=2.9;scene.camera=camera
 for location,power,color,size in [((-3,-4,7),480,(.7,.86,1),5),((3,2,4),360,(.2,.75,1),4),((0,4,3),200,(1,.5,.25),3)]:
  bpy.ops.object.light_add(type='AREA',location=location);light=bpy.context.object;light.data.energy=power;light.data.color=color;light.data.shape='DISK';light.data.size=size
  light.rotation_euler=((Vector((0,0,.2))-light.location).to_track_quat('-Z','Y').to_euler())
 scene.view_settings.view_transform='AgX'
 scene.render.filepath=os.path.join(ROOT,'assets','icons',name+'.png')
 bpy.ops.render.render(write_still=True)
