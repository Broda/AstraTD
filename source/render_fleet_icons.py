"""Render icons and a dimensional fleet gallery without changing game assets."""
import bpy, os, math
from mathutils import Vector
ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE=os.path.join(ROOT,'source')
ICON=os.path.join(ROOT,'assets','icons')
PREVIEW=os.path.join(ROOT,'model_previews')
os.makedirs(ICON,exist_ok=True);os.makedirs(PREVIEW,exist_ok=True)
open(os.path.join(PREVIEW,'.gdignore'),'w').close()

def append_asset(name,parent=None):
 with bpy.data.libraries.load(os.path.join(SOURCE,name+'.blend'),link=False) as (data_from,data_to):data_to.objects=data_from.objects
 for o in data_to.objects:
  if o is not None:bpy.context.collection.objects.link(o)
 if parent:
  for o in data_to.objects:
   if o and o.parent is None:o.parent=parent
 return data_to.objects

def assembled(name,loc=(0,0,0)):
 root=bpy.data.objects.new(name+'_display',None);bpy.context.collection.objects.link(root);root.location=loc
 objects=append_asset(name,root)
 if name in ['nova','cryostat']:
  for socket in [o for o in objects if o and o.name.startswith('GunSocket_')]:
   anchor=bpy.data.objects.new('Weapon_display',None);bpy.context.collection.objects.link(anchor);anchor.parent=socket
   # Fan the icon weapons outward, keeping the full body and gun separation visible.
   anchor.rotation_euler.z=math.atan2(socket.location.x,-socket.location.y)
   append_asset('nova_gun' if name=='nova' else 'cryo_gun',anchor)
 return root

def studio(size=(256,256),transparent=True):
 s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=32;s.cycles.use_denoising=True
 s.render.resolution_x=size[0];s.render.resolution_y=size[1];s.render.resolution_percentage=100;s.render.film_transparent=transparent
 s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.16,.24,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.45
 for pos,power,color,size in [((-4,-5,7),650,(.72,.85,1),5),((4,2,5),850,(.25,.7,1),4),((0,5,4),500,(1,.63,.37),4)]:
  bpy.ops.object.light_add(type='AREA',location=pos);light=bpy.context.object;light.data.energy=power;light.data.color=color;light.data.shape='DISK';light.data.size=size
  light.rotation_euler=(-light.location).to_track_quat('-Z','Y').to_euler()
 s.view_settings.view_transform='AgX'
 return s

def camera(loc,target,scale):
 bpy.ops.object.camera_add(location=loc);o=bpy.context.object;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();o.data.type='ORTHO';o.data.ortho_scale=scale;bpy.context.scene.camera=o
 return o

for name in ['lancer','bastion','nova','cryostat']:
 bpy.ops.wm.read_factory_settings(use_empty=False);bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
 assembled(name);s=studio();camera((2.5,-3.7,5.0),(0,0,.1),3.1)
 s.render.filepath=os.path.join(ICON,name+'.png');bpy.ops.render.render(write_still=True)

bpy.ops.wm.read_factory_settings(use_empty=False);bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
s=studio((1500,1040),False);s.cycles.samples=48
cam=camera((0,-10,13),(0,0,0),11.9)
for i,name in enumerate(['lancer','bastion','nova','cryostat','raider','nova_gun']):
 x=(-3.5,0,3.5)[i%3];y=1.9 if i<3 else -1.9
 assembled(name,(x,y,0))
 if name=='nova_gun':
  assembled('cryo_gun',(x+.7,y,.02))
  label='INDEPENDENT WEAPONS'
 else:label=name.upper()
 bpy.ops.mesh.primitive_cylinder_add(vertices=64,radius=1.52,depth=.15,location=(x,y,-.66));ped=bpy.context.object
 m=bpy.data.materials.get('Display plinth')
 if m is None:
  m=bpy.data.materials.new('Display plinth');m.diffuse_color=(.022,.035,.062,1);m.use_nodes=True;m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=(.022,.035,.062,1)
 ped.data.materials.append(m)
 bpy.ops.object.text_add(location=(x,y-1.6,-.55));text=bpy.context.object;text.data.body=label;text.data.align_x='CENTER';text.data.size=.17;text.rotation_euler=cam.rotation_euler
 label_mat=bpy.data.materials.get('Label')
 if label_mat is None:
  label_mat=bpy.data.materials.new('Label');label_mat.use_nodes=True;p=label_mat.node_tree.nodes['Principled BSDF'];p.inputs['Base Color'].default_value=(.58,.8,1,1);p.inputs['Emission Color'].default_value=(.3,.6,1,1);p.inputs['Emission Strength'].default_value=.4
 text.data.materials.append(label_mat)
s.render.filepath=os.path.join(PREVIEW,'fleet_gallery.png');bpy.ops.render.render(write_still=True)
# A low-angle station view exposes its underside trusses and the separate gun parts.
bpy.ops.wm.read_factory_settings(use_empty=False);bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
assembled('nova');s=studio((1000,800),True);camera((3,-4,1.35),(0,0,.1),3.5)
s.render.filepath=os.path.join(PREVIEW,'nova_side.png');bpy.ops.render.render(write_still=True)
print('FLEET ICONS AND GALLERY COMPLETE')
