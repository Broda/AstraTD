"""Build the expansion fleet, using the original fleet's scale and PBR maps.

Run: blender --background --python source/build_expansion_models.py
Blender -Y is the bow (Godot +Z). Editable sources preserve individual parts;
exports batch meshes by material and parent without merging aiming pivots.
No original fleet assets are changed. All texture maps are packed into sources.
"""
import math
import os
from collections import defaultdict

import bmesh
import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.environ.get("WARDENS_ASSETS", os.path.join(ROOT, "assets"))
SOURCE = os.path.join(ROOT, "source")
TEXTURES = os.path.join(ROOT, "assets", "textures")
M = {}
os.makedirs(OUT, exist_ok=True)
bpy.context.preferences.filepaths.save_version = 0


def texture(name, noncolor=False):
    path = os.path.join(TEXTURES, name + ".png")
    im = bpy.data.images.load(path, check_existing=True)
    if noncolor:
        im.colorspace_settings.name = "Non-Color"
    im.pack()
    return im


def material(name, color, metal=.6, rough=.4, glow=0, panel=None):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get("Principled BSDF")
    p.inputs["Base Color"].default_value = (*color, 1)
    p.inputs["Metallic"].default_value = metal
    p.inputs["Roughness"].default_value = rough
    p.inputs["Emission Color"].default_value = (*color, 1)
    p.inputs["Emission Strength"].default_value = glow
    if panel:
        n = m.node_tree.nodes.new("ShaderNodeTexImage")
        n.image = texture(panel)
        m.node_tree.links.new(n.outputs["Color"], p.inputs["Base Color"])
        r = m.node_tree.nodes.new("ShaderNodeTexImage")
        r.image = texture("armor_roughness", True)
        m.node_tree.links.new(r.outputs["Color"], p.inputs["Roughness"])
        n = m.node_tree.nodes.new("ShaderNodeTexImage")
        n.image = texture("armor_normal", True)
        normal = m.node_tree.nodes.new("ShaderNodeNormalMap")
        normal.inputs["Strength"].default_value = .45
        m.node_tree.links.new(n.outputs["Color"], normal.inputs["Color"])
        m.node_tree.links.new(normal.outputs["Normal"], p.inputs["Normal"])
    return m


def finish(obj, name, mat, bevel=0):
    obj.name = name
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new("Armor chamfers", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        bpy.ops.object.modifier_apply(modifier=mod.name)
        mod = obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
        mod.keep_sharp = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
    return obj


def box(name, loc, size, mat=None, bevel=.025):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.scale = size
    return finish(o, name, mat or M["hull"], min(bevel, min(size) * .18))


def cylinder(name, loc, radius, depth, mat=None, direction=(0, 0, 1), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc)
    o = bpy.context.object
    o.rotation_euler = Vector(direction).to_track_quat("Z", "Y").to_euler()
    return finish(o, name, mat or M["steel"], .008)


def ring(name, loc, radius, thick, mat=None, direction=(0, 0, 1)):
    bpy.ops.mesh.primitive_torus_add(major_segments=32, minor_segments=8, major_radius=radius,
                                   minor_radius=thick, location=loc)
    o = bpy.context.object
    o.rotation_euler = Vector(direction).to_track_quat("Z", "Y").to_euler()
    return finish(o, name, mat or M["steel"])


def sphere(name, loc, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1, location=loc)
    o = bpy.context.object
    o.scale = scale
    finish(o, name, mat)
    for p in o.data.polygons:
        p.use_smooth = True
    return o


def rod(name, start, end, radius, mat=None):
    a, b = Vector(start), Vector(end)
    return cylinder(name, (a + b) * .5, radius, (a - b).length, mat, (b - a).normalized(), 10)


def hull(name, sections, mat=None):
    vertices, faces = [], [(3, 2, 1, 0)]
    for y, w, lo, hi in sections:
        vertices.extend([(-w, y, lo), (w, y, lo), (w, y, hi), (-w, y, hi)])
    for i in range(len(sections) - 1):
        for j in range(4):
            faces.append((i * 4 + j, i * 4 + (j + 1) % 4, (i + 1) * 4 + (j + 1) % 4, (i + 1) * 4 + j))
    k = (len(sections) - 1) * 4
    faces.append((k, k + 1, k + 2, k + 3))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    o = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(o)
    bpy.ops.object.select_all(action="DESELECT")
    o.select_set(True)
    bpy.context.view_layer.objects.active = o
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=.025)
    bpy.ops.object.mode_set(mode="OBJECT")
    return finish(o, name, mat or M["hull"], .025)


def empty(name, loc):
    o = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(o)
    o.location = loc
    bpy.context.view_layer.update()
    return o


def engine(x, y, z, radius=.12):
    cylinder("Recessed thruster housing", (x, y, z), radius, .24, M["steel"], (0, 1, 0))
    cylinder("Engine throat", (x, y + .125, z), radius * .78, .012, M["black"], (0, 1, 0))
    ring("Ion exhaust rim", (x, y + .138, z), radius * .65, .018, M["glow"], (0, 1, 0))
    cylinder("Exhaust core", (x, y + .14, z), radius * .31, .013, M["glow"], (0, 1, 0))


def vents(x, y, z, width=.20):
    box("Recessed vent bed", (x, y, z), (width, .33, .025), M["black"], .008)
    for i in range(5):
        box("Radiator fin", (x, y - .13 + i * .065, z + .016), (width * .8, .014, .025), M["steel"], .002)


def socket(i, loc):
    cylinder("Fixed turret bearing", loc, .21, .065, M["steel"])
    ring("Bearing status ring", (loc[0], loc[1], loc[2] + .035), .175, .012, M["glow"])
    empty("GunSocket_" + str(i), (loc[0], loc[1], loc[2] + .045))


def railgun():
    # Narrow axial accelerator with a clearly open slot between two long rails.
    hull("Axial destroyer pressure hull", [(1.00, .26, -.22, .27), (.38, .32, -.26, .36),
                                           (-.31, .26, -.17, .27), (-.91, .09, -.08, .08)])
    hull("Ventral recoil keel", [(.85, .13, -.37, -.21), (-.82, .09, -.23, -.07)], M["steel"])
    hull("Elevated aft bridge", [(.72, .20, .28, .55), (.23, .19, .31, .57), (-.12, .09, .26, .39)], M["armor"])
    hull("Bridge amber glazing", [(.20, .167, .46, .57), (-.09, .075, .34, .41)], M["glass"])
    box("Accelerator recessed channel", (0, -.66, .09), (.15, 1.12, .055), M["black"])
    for side in [-1, 1]:
        x = side * .19
        box("Longitudinal mass driver rail", (x, -.61, .17), (.16, 1.72, .18), M["steel"])
        box("Ceramic rail jacket", (x, -.48, .273), (.17, 1.33, .055), M["armor"])
        box("Accelerator energized slot", (x - side * .082, -.70, .17), (.012, 1.29, .075), M["glow"], .002)
        for y in [-1.12, -.81, -.50, -.19]:
            box("Field clamp", (x, y, .30), (.205, .075, .045), M["accent"])
        box("Rail muzzle shield", (x, -1.42, .17), (.21, .14, .23), M["armor"])
        x = side * .51
        box("Recoil outrigger", (side * .36, .31, .02), (.41, .23, .15), M["steel"])
        box("Capacitor nacelle", (x, .39, .08), (.29, 1.14, .37))
        box("Nacelle upper armor", (x, .35, .294), (.28, .89, .07), M["armor"])
        box("Nacelle amber identity stripe", (x, .28, .341), (.055, .64, .025), M["accent"])
        for y in [.13, .43, .73]:
            cylinder("Side capacitor", (x + side * .17, y, .08), .069, .21, M["steel"])
            ring("Capacitor charge ring", (x + side * .17, y, .18), .071, .012, M["glow"])
        engine(x, 1.02, .08, .135)
        vents(x, .64, .35, .22)
        cylinder("Recessed maneuver nozzle", (x + side * .15, -.12, .16), .035, .03, M["black"], (side, 0, 0), 12)
    engine(0, 1.10, -.12, .12)
    vents(0, .75, .59, .20)
    rod("Targeting radar mast", (0, .72, .55), (0, .72, .78), .012, M["steel"])
    sphere("Targeting radar", (0, .72, .80), (.044, .044, .044), M["glow"])
    empty("Muzzle_0", (0, -1.51, .17))


def relay():
    # Triangular support silhouette; paired turrets are independent of the dish.
    cylinder("Hexagonal support core", (0, 0, .09), .37, .69, verts=6, mat=M["hull"])
    cylinder("Service core belly", (0, 0, -.36), .29, .21, M["steel"], verts=12)
    ring("Underside power manifold", (0, 0, -.47), .22, .026, M["glow"])
    cylinder("Upper command collar", (0, 0, .46), .40, .12, M["armor"], verts=6)
    for i in range(3):
        a = -math.pi / 2 + i * math.tau / 3
        x, y = math.cos(a), math.sin(a)
        rod("Radial pressure bridge", (x * .26, y * .26, .03), (x * 1.00, y * 1.00, .03), .095, M["hull"])
        rod("Upper radial brace", (x * .24, y * .24, .33), (x * .84, y * .84, .14), .026, M["steel"])
        rod("Underside diagonal brace", (x * .21, y * .21, -.31), (x * .92, y * .92, -.01), .032, M["steel"])
        cylinder("Signal amplifier pressure pod", (x * .98, y * .98, .10), .235, .35, M["hull"], verts=8)
        cylinder("Amplifier ceramic cap", (x * .98, y * .98, .30), .25, .075, M["armor"], verts=8)
        ring("Amplifier status halo", (x * .98, y * .98, .35), .16, .020, M["glow"])
        cylinder("Amplifier lower reactor", (x * .98, y * .98, -.15), .14, .16, M["steel"])
        if i == 0:
            sphere("Primary signal dome", (x * .98, y * .98, .43), (.14, .14, .15), M["glass"])
            rod("Forward signal aerial", (x * .98, y * .98, .51), (x * .98, y * .98, .73), .012, M["steel"])
        else:
            socket(i - 1, (x * .98, y * .98, .36))
    cylinder("Uplink mast base", (0, 0, .61), .11, .28, M["steel"])
    # Bowl with an open upper face, ribs, rim, and a physically separate feed.
    verts, faces = [], []
    for radius, z in [(.08, .66), (.26, .70), (.47, .86)]:
        for j in range(32):
            a = j * math.tau / 32
            verts.append((radius * math.cos(a), radius * math.sin(a), z))
    for i in range(2):
        for j in range(32):
            faces.append((i * 32 + j, i * 32 + (j + 1) % 32, (i + 1) * 32 + (j + 1) % 32, (i + 1) * 32 + j))
    mesh = bpy.data.meshes.new("Parabolic signal dish")
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    dish = bpy.data.objects.new("Parabolic signal dish", mesh)
    bpy.context.collection.objects.link(dish)
    bpy.ops.object.select_all(action="DESELECT")
    dish.select_set(True)
    bpy.context.view_layer.objects.active = dish
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=.025)
    bpy.ops.object.mode_set(mode="OBJECT")
    finish(dish, "Parabolic signal dish", M["armor"])
    mod = dish.modifiers.new("Pressure dish thickness", "SOLIDIFY")
    mod.thickness = .024
    bpy.ops.object.modifier_apply(modifier=mod.name)
    ring("Dish armored rim", (0, 0, .86), .47, .028, M["accent"])
    ring("Support transmitter halo", (0, 0, .91), .41, .016, M["glow"])
    for i in range(6):
        a = i * math.tau / 6
        x, y = math.cos(a), math.sin(a)
        rod("Dish radial stiffener", (x * .10, y * .10, .64), (x * .45, y * .45, .83), .015, M["steel"])
    for i in range(3):
        a = i * math.tau / 3
        rod("Receiver support", (.44 * math.cos(a), .44 * math.sin(a), .88), (0, 0, 1.10), .012, M["steel"])
    sphere("Uplink emitter", (0, 0, 1.08), (.065, .065, .065), M["glow"])
    empty("AuraEmitter", (0, 0, 1.10))


def relay_gun():
    cylinder("Traverse base", (0, 0, .03), .17, .08, M["steel"])
    ring("Traverse power rail", (0, 0, .08), .145, .012, M["glow"])
    box("Support defense breech", (0, .04, .14), (.26, .29, .15), M["armor"])
    for side in [-1, 1]:
        cylinder("Elevation bearing", (side * .14, -.02, .18), .057, .047, M["steel"], (1, 0, 0))
    pivot = empty("BarrelPivot", (0, -.02, .18))
    before = set(bpy.context.scene.objects)
    cylinder("Defense pulse barrel", (0, -.24, .18), .044, .43, M["steel"], (0, 1, 0))
    for y in [-.13, -.26, -.38]:
        ring("Pulse field collar", (0, y, .18), .055, .013, M["glow"], (0, 1, 0))
    cylinder("Muzzle guard", (0, -.47, .18), .060, .09, M["armor"], (0, 1, 0))
    cylinder("Emitter lens", (0, -.52, .18), .039, .012, M["glow"], (0, 1, 0))
    empty("Muzzle_0", (0, -.54, .18))
    for obj in set(bpy.context.scene.objects) - before:
        obj.parent = pivot
        obj.matrix_parent_inverse = pivot.matrix_world.inverted()
    box("Rear heat sink", (0, .19, .18), (.19, .075, .12), M["black"])


def shielded():
    hull("Shield escort armored body", [(.71, .26, -.20, .25), (.12, .37, -.24, .32), (-.48, .30, -.15, .20), (-.89, .06, -.04, .11)])
    hull("Reinforced shield keel", [(.59, .17, -.34, -.20), (-.54, .18, -.23, -.12)], M["steel"])
    hull("Armored command shell", [(.39, .24, .25, .45), (-.18, .27, .29, .43), (-.56, .14, .15, .26)], M["armor"])
    hull("Escort cockpit", [(-.18, .13, .36, .44), (-.49, .08, .24, .29)], M["glass"])
    for side in [-1, 1]:
        # Wide forward-facing shield vanes distinguish the defensive enemy.
        x = side * .54
        o = box("Swept defensive vane", (x, -.06, .10), (.24, 1.10, .39), M["armor"])
        o.rotation_euler.z = side * -.18
        box("Shield capacitor casing", (x, .24, .36), (.21, .55, .09), M["steel"])
        box("Shield emitter strip", (x, -.20, .319), (.09, .53, .035), M["glow"])
        rod("Ventral shield strut", (side * .15, -.25, -.22), (x, -.23, -.11), .032, M["steel"])
        cylinder("Shield generator socket", (x, -.59, .10), .115, .075, M["steel"], (0, -1, 0))
        ring("Forward shield emitter", (x, -.637, .10), .088, .018, M["glow"], (0, -1, 0))
        engine(x, .58, .08, .12)
        for y in [-.30, .03, .36]:
            box("Defensive vane rib", (x + side * .14, y, .10), (.05, .07, .37), M["accent"])
    engine(0, .84, -.01, .13)
    ring("Dorsal shield generator", (0, .25, .49), .12, .022, M["glow"])
    cylinder("Generator core", (0, .25, .46), .073, .10, M["steel"])
    empty("ShieldEmitter", (0, 0, .22))


def regenerator():
    hull("Repair frigate central spine", [(.85, .17, -.18, .23), (.21, .24, -.24, .32), (-.43, .15, -.12, .20), (-1.00, .025, -.03, .07)])
    hull("Repair conduit belly", [(.67, .11, -.34, -.17), (-.59, .07, -.20, -.08)], M["steel"])
    hull("Repair command blister", [(.36, .15, .28, .50), (-.04, .15, .27, .47), (-.42, .07, .17, .30)], M["armor"])
    hull("Green command glazing", [(-.07, .12, .35, .47), (-.38, .055, .25, .31)], M["glass"])
    for side in [-1, 1]:
        x = side * .44
        rod("Repair pod outrigger", (side * .15, .13, .01), (x, .13, .01), .075, M["steel"])
        cylinder("Cylindrical repair reservoir", (x, .16, .12), .18, 1.02, M["hull"], (0, 1, 0))
        sphere("Repair reservoir bow", (x, -.35, .12), (.18, .18, .18), M["armor"])
        for y in [-.19, .10, .39]:
            ring("Repair plasma conduit", (x, y, .12), .185, .027, M["glow"], (0, 1, 0))
            box("Reservoir top armor plate", (x, y, .322), (.25, .19, .044), M["armor"])
        box("Ventral reservoir rail", (x, .14, -.087), (.13, .89, .059), M["steel"])
        engine(x, .72, .12, .14)
        rod("Repair emitter boom", (x, -.38, .11), (side * .30, -.79, .11), .025, M["steel"])
        sphere("Repair boom emitter", (side * .30, -.79, .11), (.044, .044, .044), M["glow"])
    cylinder("Exposed repair reactor", (0, .54, .38), .135, .16, M["steel"])
    sphere("Repair reactor plasma", (0, .54, .53), (.11, .11, .12), M["glow"])
    ring("Repair reactor cage", (0, .54, .56), .145, .018, M["steel"])
    engine(0, .96, -.06, .10)
    empty("RepairEmitter", (0, .54, .59))


def export(name):
    bpy.ops.object.select_all(action="DESELECT")
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(SOURCE, name + ".blend"))
    groups = defaultdict(list)
    for obj in bpy.context.scene.objects:
        if obj.type == "MESH":
            groups[(obj.parent, obj.data.materials[0].name)].append(obj)
    for (parent, matname), objects in groups.items():
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        if len(objects) > 1:
            bpy.ops.object.join()
        bpy.context.object.name = "Surface_" + matname.replace(" ", "_")
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, name + ".glb"), export_format="GLB",
                             use_selection=True, export_yup=True)
    polygons = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    print("EXPANSION_ASSET", name, "surfaces", len(groups), "polygons", polygons)


def build():
    M["hull"] = material("Titanium Panels", (.31, .42, .56), .65, panel="titanium_panels_albedo")
    M["armor"] = material("Ceramic Armor", (.80, .83, .85), .24, panel="ceramic_armor_albedo")
    M["steel"] = material("Brushed Steel", (.16, .22, .29), .8, .32, panel="brushed_steel_albedo")
    M["black"] = material("Recess Carbon", (.017, .025, .037), .18, .68)
    entries = [("railgun", (1.0, .78, .13), railgun), ("relay", (.95, .52, .17), relay),
               ("relay_gun", (.95, .52, .17), relay_gun), ("shielded", (.09, .60, 1.0), shielded),
               ("regenerator", (.24, .95, .20), regenerator)]
    for name, color, fn in entries:
        bpy.ops.object.select_all(action="SELECT")
        bpy.ops.object.delete(use_global=False)
        M["accent"] = material(name + " Faction Enamel", tuple(c * .55 + .04 for c in color), .35, .3)
        M["glow"] = material(name + " Reactor", color, .1, .24, 1.1)
        M["glass"] = material(name + " Glazed Optics", tuple(c * .14 + .015 for c in color), .55, .13, .14)
        fn()
        export(name)
    print("EXPANSION FLEET BUILD COMPLETE")


if __name__ == "__main__":
    build()
