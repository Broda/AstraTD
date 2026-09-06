"""Reproducible full-3D fleet, UV-mapped PBR panels and articulated station guns.
Blender -Y is the bow, exported as Godot +Z. Sources retain individual parts;
GLBs batch static parts by material while preserving weapon pivots and sockets.
"""
import bpy, bmesh, math, os
import numpy as np
from mathutils import Vector
from collections import defaultdict
ROOT=os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT=os.environ.get('WARDENS_ASSETS',os.path.join(ROOT,'assets'))
SOURCE=os.path.join(ROOT,'art','models');TEXTURES=os.path.join(OUT,'textures')
os.makedirs(TEXTURES,exist_ok=True);bpy.context.preferences.filepaths.save_version=0
COLORS=[(.09,.70,.95),(.98,.46,.075),(.50,.19,.92),(.08,.90,.64),(.95,.08,.19)]
M={}

def image(name,rgb,noncolor=False):
 h,w=rgb.shape[:2];im=bpy.data.images.new(name,width=w,height=h,alpha=True)
 if noncolor:im.colorspace_settings.name='Non-Color'
 rgba=np.concatenate((rgb,np.ones((h,w,1),dtype=np.float32)),axis=2)
 im.pixels.foreach_set(rgba.astype(np.float32).ravel());im.filepath_raw=os.path.join(TEXTURES,name+'.png');im.file_format='PNG';im.save();im.pack();return im

def textures():
 y,x=np.mgrid[0:512,0:512];rng=np.random.default_rng(781);px=x%128;py=y%128
 edge=np.minimum.reduce([px,py,127-px,127-py]);grain=rng.normal(0,.022,(512,512))
 tone=rng.uniform(.80,1.02,(4,4))[y//128,x//128]+grain
 height=np.full((512,512),.55);height[edge<3]=.1;height[(edge>=3)&(edge<5)]=.72
 tone[edge<3]=.27;tone[(edge>=3)&(edge<5)]=1.15
 tone[(rng.random((512,512))>.994)&(edge>8)]+=.2
 for cy in [12,115]:
  for cx in [12,115]:
   d=(px-cx)**2+(py-cy)**2;tone[d<10]=.32;height[d<10]=.3;tone[(d>=10)&(d<20)]=1.1
 tone[(px>84)&(px<109)&(py>91)&(py<95)]=.5
 base=np.clip(np.stack([tone*.66,tone*.72,tone*.82],2),0,1)
 rough=np.clip(.43+grain*1.6+(edge<4)*.21,0,1)
 r=image('armor_roughness',np.stack([rough]*3,2),True)
 gy,gx=np.gradient(height);n=np.stack([-gx*2,-gy*2,np.ones_like(gx)],2);n/=np.linalg.norm(n,axis=2,keepdims=True)
 n=image('armor_normal',n*.5+.5,True)
 cells=np.ones((512,512,3))*np.array([.025,.07,.16]);cells+=rng.random((512,512,1))*.015
 seam=(x%64<3)|(y%64<3);cells[seam]=[.18,.33,.48];cells[(x%16<1)&~seam]=[.12,.26,.39]
 return base,r,n,image('radiator_cells',cells)

def material(name,color,metal=.6,rough=.4,glow=0,textured=False,solar=False):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF')
 p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=glow
 if textured or solar:
  n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=TEX[3] if solar else image(name.lower().replace(' ','_')+'_albedo',np.clip(TEX[0]*np.array(color)*1.35,0,1))
  m.node_tree.links.new(n.outputs['Color'],p.inputs['Base Color'])
  if textured:
   r=m.node_tree.nodes.new('ShaderNodeTexImage');r.image=TEX[1];m.node_tree.links.new(r.outputs['Color'],p.inputs['Roughness'])
   n=m.node_tree.nodes.new('ShaderNodeTexImage');n.image=TEX[2];b=m.node_tree.nodes.new('ShaderNodeNormalMap');b.inputs['Strength'].default_value=.45
   m.node_tree.links.new(n.outputs['Color'],b.inputs['Color']);m.node_tree.links.new(b.outputs['Normal'],p.inputs['Normal'])
 return m

def finish(o,name,mat,bevel=0):
 o.name=name;o.data.materials.append(mat);bpy.context.view_layer.objects.active=o
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:
  mod=o.modifiers.new('Armor chamfers','BEVEL');mod.width=bevel;mod.segments=2;bpy.ops.object.modifier_apply(modifier=mod.name)
  mod=o.modifiers.new('Weighted normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
 return o

def box(name,loc,scale,mat=None,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.scale=scale
 return finish(o,name,mat or M['hull'],min(bevel,min(scale)*.18))

def cylinder(name,loc,radius,depth,mat=None,direction=(0,0,1),verts=16):
 bpy.ops.mesh.primitive_cylinder_add(vertices=verts,radius=radius,depth=depth,location=loc);o=bpy.context.object
 o.rotation_euler=Vector(direction).to_track_quat('Z','Y').to_euler();return finish(o,name,mat or M['steel'],.008)

def ring(name,loc,radius,thick,mat=None,direction=(0,0,1)):
 bpy.ops.mesh.primitive_torus_add(major_segments=32,minor_segments=8,major_radius=radius,minor_radius=thick,location=loc);o=bpy.context.object
 o.rotation_euler=Vector(direction).to_track_quat('Z','Y').to_euler();return finish(o,name,mat or M['steel'])

def sphere(name,loc,scale,mat):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,radius=1,location=loc);o=bpy.context.object;o.scale=scale;finish(o,name,mat)
 for p in o.data.polygons:p.use_smooth=True
 return o

def rod(name,a,b,radius,mat=None):
 a,b=Vector(a),Vector(b);return cylinder(name,(a+b)*.5,radius,(a-b).length,mat,(b-a).normalized(),10)

def hull(name,sections,mat=None):
 vs=[]
 for y,w,lo,hi in sections:vs.extend([(-w,y,lo),(w,y,lo),(w,y,hi),(-w,y,hi)])
 fs=[(3,2,1,0)]
 for s in range(len(sections)-1):
  for j in range(4):fs.append((s*4+j,s*4+(j+1)%4,(s+1)*4+(j+1)%4,(s+1)*4+j))
 k=(len(sections)-1)*4;fs.append((k,k+1,k+2,k+3))
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(vs,[],fs);mesh.update()
 bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=bm.faces);bm.to_mesh(mesh);bm.free()
 o=bpy.data.objects.new(name,mesh);bpy.context.collection.objects.link(o);bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
 bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.uv.smart_project(island_margin=.025);bpy.ops.object.mode_set(mode='OBJECT')
 return finish(o,name,mat or M['hull'],.025)

def empty(name,loc):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);o.location=loc;bpy.context.view_layer.update();return o

def engine(x,y,z,r=.12):
 cylinder('Recessed thruster housing',(x,y,z),r,.24,M['steel'],(0,1,0))
 cylinder('Engine throat',(x,y+.125,z),r*.78,.01,M['black'],(0,1,0))
 ring('Ion exhaust rim',(x,y+.135,z),r*.65,.018,M['glow'],(0,1,0))
 cylinder('Exhaust core',(x,y+.14,z),r*.31,.012,M['glow'],(0,1,0))

def vents(x,y,z,count=5,width=.20):
 box('Recessed vent bed',(x,y,z),(width,.33,.025),M['black'],.008)
 for i in range(count):box('Radiator fin',(x,y-.13+i*.065,z+.016),(width*.8,.014,.025),M['steel'],.002)

def socket(i,loc):
 cylinder('Fixed turret bearing',loc,.21,.065,M['steel']);ring('Bearing status ring',(loc[0],loc[1],loc[2]+.035),.175,.012,M['glow'])
 empty('GunSocket_'+str(i),(loc[0],loc[1],loc[2]+.045))

def lancer():
 hull('Tapered pressure hull',[(.85,.22,-.19,.22),(.15,.32,-.23,.33),(-.68,.17,-.13,.23),(-1.23,.025,-.045,.08)])
 hull('Ventral armored keel',[(.65,.12,-.30,-.18),(-.65,.09,-.23,-.10)],M['steel'])
 hull('Raised bridge',[(.30,.16,.29,.49),(-.12,.16,.29,.54),(-.43,.08,.22,.35)],M['armor'])
 hull('Inset glazed cockpit',[(-.13,.136,.40,.55),(-.41,.06,.30,.365)],M['glass'])
 for side in [-1,1]:
  x=side*.49;box('Nacelle spar',(side*.34,.20,.05),(.42,.16,.14),M['steel']);box('Nacelle pressure pod',(x,.2,.09),(.28,1.33,.32))
  box('Nacelle ceramic armor',(x,.15,.275),(.25,.86,.065),M['armor']);box('Navigation strip',(x,.10,.315),(.032,.52,.02),M['glow'])
  engine(x,.90,.08,.125);vents(x,.46,.32,4,.21)
  rod('Forward laser barrel',(side*.28,-.4,.13),(side*.28,-1.05,.13),.038,M['steel']);ring('Laser lens',(side*.28,-1.055,.13),.030,.009,M['glow'],(0,-1,0))
  for y in [-.55,.5]:
   cylinder('RCS recess',(side*.63,y,.25),.041,.04,M['black'],(side,0,0),12);ring('RCS nozzle',(side*.655,y,.25),.034,.008,M['steel'],(side,0,0))
 vents(0,.57,.29,4,.21);cylinder('Dorsal access hatch',(0,.27,.57),.075,.025,M['steel'])
 rod('Sensor mast',(0,.56,.3),(0,.56,.7),.015,M['steel']);sphere('Sensor tip',(0,.56,.70),(.027,.027,.027),M['glow'])

def bastion():
 hull('Heavy cruiser hull',[(.90,.31,-.29,.34),(.15,.43,-.32,.41),(-.72,.29,-.19,.27),(-1.23,.035,-.06,.09)])
 hull('Armored belly keel',[(.8,.20,-.42,-.25),(-.65,.15,-.32,-.14)],M['steel']);box('Command deck',(0,.30,.47),(.48,.62,.19),M['armor'])
 hull('Raised command bridge',[(.53,.20,.52,.76),(.10,.19,.52,.73),(-.13,.12,.44,.56)],M['steel'])
 box('Forward bridge glazing',(0,.075,.685),(.34,.035,.085),M['glass'])
 for x in [-.14,-.07,0,.07,.14]:box('Bridge window frame',(x,.051,.69),(.012,.018,.09),M['steel'],.002)
 for side in [-1,1]:
  x=side*.63;box('Armored weapon nacelle',(x,.12,.12),(.41,1.40,.43));box('Missile bay ceramic cover',(x,.06,.365),(.37,1.18,.08),M['armor'])
  for y in [-.33,.03,.39]:
   box('Launch cell collar',(x,y,.424),(.29,.27,.055),M['steel']);cylinder('Missile silo hatch',(x,y,.465),.083,.06,M['accent'],verts=12)
   box('Cell indicator',(x+.12,y,.46),(.025,.12,.022),M['glow'],.004)
  box('Side armor stripe',(x+side*.215,.1,.20),(.025,.85,.08),M['accent'])
  for y in [-.35,0,.35]:rod('Structural rib',(x+side*.22,y,-.10),(x+side*.22,y,.28),.023,M['steel'])
  engine(x,.94,.06,.16);engine(side*.18,.99,-.10,.11)
 vents(0,.72,.37,4,.27);rod('Communications mast',(0,.5,.78),(0,.5,.96),.017,M['steel'])

def nova():
 cylinder('Octagonal pressure core',(0,0,.12),.40,.78,M['hull'],verts=8);cylinder('Upper armored crown',(0,0,.48),.43,.12,M['armor'],verts=8)
 cylinder('Underside service drum',(0,0,-.34),.30,.22,M['steel'],verts=12);ring('Underside power manifold',(0,0,-.46),.22,.028,M['glow'])
 sphere('Contained reactor',(0,0,.68),(.24,.24,.25),M['glass']);sphere('Reactor emitter',(0,0,.69),(.125,.125,.15),M['glow']);ring('Upper reactor guard',(0,0,.65),.29,.025,M['steel'])
 ring('Habitat pressure ring',(0,0,.11),.85,.11,M['hull']);ring('Ring armor lip',(0,0,.235),.85,.035,M['armor']);ring('Reactor distribution rail',(0,0,-.01),.85,.019,M['glow'])
 for i in range(8):
  a=i*math.pi/4;x,y=math.cos(a),math.sin(a)
  rod('Ring radial truss',(x*.32,y*.32,-.17),(x*.87,y*.87,-.09),.04,M['steel']);rod('Angled load brace',(x*.3,y*.3,-.32),(x*.82,y*.82,.13),.027,M['steel'])
  o=box('Outer ring armor',(x*.85,y*.85,.14),(.29,.20,.24),M['armor']);o.rotation_euler[2]=a
  if i%2==0:socket(i//2,(x*.77,y*.77,.35))
  else:
   box('Docking collar',(x*.84,y*.84,.34),(.18,.18,.16),M['steel']);box('Docking beacon',(x*.84,y*.84,.43),(.08,.08,.025),M['glow'])
 for a in range(4):
  x,y=math.cos(a*math.pi/2),math.sin(a*math.pi/2)
  box('Habitat window',(x*.405,y*.405,.27),(.055 if abs(x)>.5 else .18,.18 if abs(x)>.5 else .055,.075),M['glow'])

def cryostat():
 cylinder('Cryogenic pressure drum',(0,0,.12),.35,.75,M['hull'],verts=12);cylinder('Heat exchanger crown',(0,0,.48),.39,.10,M['armor'],verts=12)
 cylinder('Lower coolant vessel',(0,0,-.35),.29,.23,M['steel']);sphere('Containment dome',(0,0,.65),(.26,.26,.17),M['glass']);ring('Cold plasma ring',(0,0,.58),.285,.025,M['glow'])
 for z in [-.2,0,.2]:ring('Coolant loop',(0,0,z),.36,.022,M['accent'])
 for side in [-1,1]:
  x=side*.86;box('Radiator structural wing',(x,0,.12),(.48,1.45,.13),M['steel']);box('Radiator cell surface',(x,0,.204),(.425,1.36,.025),M['solar'],.005)
  box('Radiator underside',(x,0,.041),(.425,1.34,.035),M['black'],.005)
  for y in [-.69,-.23,.23,.69]:box('Radiator cross rib',(x,y,.235),(.48,.025,.045),M['armor'],.005)
  for dx in [-.23,.23]:box('Radiator edge rail',(x+dx,0,.24),(.03,1.46,.055),M['armor'],.005)
  rod('Radiator support',(side*.27,0,.08),(x,0,.08),.055,M['steel'])
  for y in [-.5,.5]:rod('Diagonal wing strut',(side*.22,0,-.25),(x,y,.05),.022,M['steel'])
  cylinder('Coolant tank',(side*.40,.1,.10),.085,.57,M['armor']);ring('Tank valve',(side*.40,.1,.41),.06,.014,M['glow'])
  box('Weapon outrigger',(0,side*.5,.22),(.21,.4,.14),M['steel']);socket(0 if side<0 else 1,(0,side*.64,.38))
 for x in [-.13,.13]:rod('Thermal antenna',(x,.25,.50),(x,.25,.94),.012,M['steel'])

def raider():
 hull('Raider faceted fuselage',[(.73,.20,-.16,.18),(.20,.31,-.22,.27),(-.35,.22,-.13,.23),(-.95,.015,-.02,.04)])
 hull('Raider underside armor',[(.55,.12,-.28,-.16),(-.40,.09,-.21,-.10)],M['steel']);hull('Crimson dorsal armor',[(.5,.16,.19,.23),(-.2,.16,.24,.30),(-.68,.04,.10,.16)],M['accent'])
 hull('Raider canopy',[(-.22,.09,.29,.35),(-.50,.06,.18,.23)],M['glass'])
 for side in [-1,1]:
  o=box('Angular interceptor wing',(side*.38,.22,.05),(.24,.85,.14),M['steel']);o.rotation_euler[2]=side*.30
  box('Wing armor strip',(side*.42,.20,.135),(.065,.52,.035),M['accent']);engine(side*.40,.67,.13,.095)
  rod('Forward disruptor',(side*.23,-.15,.02),(side*.23,-.69,.02),.023,M['steel'])
 vents(0,.48,.28,3,.16)

def gun(cryo=False):
 cylinder('Turret rotating base',(0,0,.03),.18,.09,M['steel']);ring('Turret traverse race',(0,0,.082),.15,.013,M['glow'])
 box('Armored gun head',(0,.03,.14),(.28,.30,.14),M['armor'])
 for side in [-1,1]:cylinder('Elevation bearing',(side*.15,-.01,.18),.065,.055,M['steel'],(1,0,0))
 pivot=empty('BarrelPivot',(0,-.01,.18));before=set(bpy.context.scene.objects)
 if cryo:
  cylinder('Cryo projector barrel',(0,-.24,.18),.067,.47,M['steel'],(0,1,0))
  for y in [-.09,-.21,-.33]:ring('Superconducting coil',(0,y,.18),.093,.023,M['glow'],(0,1,0))
  cylinder('Focusing shroud',(0,-.48,.18),.085,.09,M['armor'],(0,1,0));cylinder('Frozen lens',(0,-.532,.18),.063,.012,M['glow'],(0,1,0));empty('Muzzle_0',(0,-.55,.18))
 else:
  for side in [-1,1]:
   x=side*.077;cylinder('Pulse accelerator',(x,-.24,.18),.041,.44,M['steel'],(0,1,0))
   for y in [-.12,-.29,-.40]:ring('Accelerator field coil',(x,y,.18),.047,.011,M['glow'],(0,1,0))
   cylinder('Emitter shroud',(x,-.49,.18),.051,.08,M['armor'],(0,1,0));cylinder('Emitter lens',(x,-.536,.18),.03,.013,M['glow'],(0,1,0));empty('Muzzle_'+str(0 if side<0 else 1),(x,-.55,.18))
 for obj in set(bpy.context.scene.objects)-before:obj.parent=pivot;obj.matrix_parent_inverse=pivot.matrix_world.inverted()
 box('Rear breech heat sink',(0,.18,.20),(.22,.11,.13),M['black'])

def export(name):
 model_dir=os.path.join(OUT,'models',name)
 os.makedirs(model_dir,exist_ok=True);os.makedirs(SOURCE,exist_ok=True)
 bpy.ops.object.select_all(action='DESELECT');bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE,name+'.blend'))
 groups=defaultdict(list)
 for o in bpy.context.scene.objects:
  if o.type=='MESH':groups[(o.parent,o.data.materials[0].name)].append(o)
 for (parent,matname),objects in groups.items():
  bpy.ops.object.select_all(action='DESELECT')
  for obj in objects:obj.select_set(True)
  bpy.context.view_layer.objects.active=objects[0]
  if len(objects)>1:bpy.ops.object.join()
  bpy.context.object.name='Surface_'+matname.replace(' ','_')
 bpy.ops.object.select_all(action='SELECT');bpy.ops.export_scene.gltf(filepath=os.path.join(model_dir,name+'.glb'),export_format='GLB',use_selection=True,export_yup=True)
 print('ASSET',name,'surfaces',len(groups),'polygons',sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type=='MESH'))

bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);TEX=textures()
for name,kind,fn in [('lancer',0,lancer),('bastion',1,bastion),('nova',2,nova),('cryostat',3,cryostat),('raider',4,raider),('nova_gun',2,lambda:gun(False)),('cryo_gun',3,lambda:gun(True))]:
 bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False);color=COLORS[kind]
 if not M:
  M['hull']=material('Titanium Panels',(.31,.42,.56),.65,textured=True);M['armor']=material('Ceramic Armor',(.80,.83,.85),.24,textured=True)
  M['steel']=material('Brushed Steel',(.16,.22,.29),.8,.32,textured=True);M['black']=material('Recess Carbon',(.017,.025,.037),.18,.68)
  M['solar']=material('Radiator Cells',(.1,.2,.4),.55,.25,solar=True)
 M['accent']=material(name+' Faction Enamel',tuple(c*.55+.04 for c in color),.35,.3)
 M['glow']=material(name+' Reactor',color,.1,.24,1.1);M['glass']=material(name+' Glazed Optics',tuple(c*.14+.015 for c in color),.55,.13,.14)
 fn();export(name)
print('FLEET BUILD COMPLETE')
