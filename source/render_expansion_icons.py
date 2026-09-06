"""Render expansion purchase icons and review images from editable sources.

Run after build_expansion_models.py. Rendering never changes exported models.
Station review images and icons assemble the same independent gun hierarchy
used by the game. Optional WARDENS_RENDER_SAMPLES overrides quality for drafts.
"""
import math
import os

import bpy
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "source")
ICON = os.path.join(ROOT, "assets", "icons")
PREVIEW = os.path.join(ROOT, "model_previews")
os.makedirs(ICON, exist_ok=True)
os.makedirs(PREVIEW, exist_ok=True)
SAMPLES = int(os.environ.get("WARDENS_RENDER_SAMPLES", "40"))


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=False)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)


def append_asset(name, parent):
    with bpy.data.libraries.load(os.path.join(SOURCE, name + ".blend"), link=False) as (data_from, data_to):
        data_to.objects = data_from.objects
    for obj in data_to.objects:
        if obj:
            bpy.context.collection.objects.link(obj)
            if obj.parent is None:
                obj.parent = parent
    return data_to.objects


def assembled(name, loc=(0, 0, 0)):
    root = bpy.data.objects.new(name + "_display", None)
    bpy.context.collection.objects.link(root)
    root.location = loc
    objects = append_asset(name, root)
    if name == "relay":
        for socket in [o for o in objects if o and o.name.startswith("GunSocket_")]:
            anchor = bpy.data.objects.new("Independent_weapon_display", None)
            bpy.context.collection.objects.link(anchor)
            anchor.parent = socket
            anchor.rotation_euler.z = math.atan2(socket.location.x, -socket.location.y)
            append_asset("relay_gun", anchor)
    return root


def studio(size=(256, 256), transparent=True):
    s = bpy.context.scene
    s.render.engine = "CYCLES"
    s.cycles.samples = SAMPLES
    s.cycles.use_denoising = True
    s.render.resolution_x, s.render.resolution_y = size
    s.render.resolution_percentage = 100
    s.render.film_transparent = transparent
    s.render.image_settings.file_format = "PNG"
    s.render.image_settings.color_mode = "RGBA"
    s.world.use_nodes = True
    s.world.node_tree.nodes["Background"].inputs[0].default_value = (.12, .16, .24, 1)
    s.world.node_tree.nodes["Background"].inputs[1].default_value = .45
    for pos, power, color, size in [((-4, -5, 7), 650, (.72, .85, 1), 5),
                                     ((4, 2, 5), 850, (.25, .7, 1), 4),
                                     ((0, 5, 4), 500, (1, .63, .37), 4)]:
        bpy.ops.object.light_add(type="AREA", location=pos)
        light = bpy.context.object
        light.data.energy = power
        light.data.color = color
        light.data.shape = "DISK"
        light.data.size = size
        light.rotation_euler = (-light.location).to_track_quat("-Z", "Y").to_euler()
    s.view_settings.view_transform = "AgX"
    return s


def camera(loc, target, scale):
    bpy.ops.object.camera_add(location=loc)
    obj = bpy.context.object
    obj.rotation_euler = (Vector(target) - obj.location).to_track_quat("-Z", "Y").to_euler()
    obj.data.type = "ORTHO"
    obj.data.ortho_scale = scale
    bpy.context.scene.camera = obj
    return obj


def label_material():
    mat = bpy.data.materials.get("Expansion gallery label")
    if mat is None:
        mat = bpy.data.materials.new("Expansion gallery label")
        mat.use_nodes = True
        p = mat.node_tree.nodes["Principled BSDF"]
        p.inputs["Base Color"].default_value = (.58, .8, 1, 1)
        p.inputs["Emission Color"].default_value = (.3, .6, 1, 1)
        p.inputs["Emission Strength"].default_value = .4
    return mat


def plinth(x, y):
    bpy.ops.mesh.primitive_cylinder_add(vertices=64, radius=1.56, depth=.15, location=(x, y, -.63))
    mat = bpy.data.materials.get("Expansion display plinth")
    if mat is None:
        mat = bpy.data.materials.new("Expansion display plinth")
        mat.use_nodes = True
        mat.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = (.022, .035, .062, 1)
        mat.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = .7
    bpy.context.object.data.materials.append(mat)


def render():
    for name in ["railgun", "relay", "shielded", "regenerator", "relay_gun"]:
        clear()
        assembled(name)
        scene = studio()
        scale = 3.35 if name in ["railgun", "relay"] else (1.0 if name == "relay_gun" else 2.7)
        target = (0, -.10, .15) if name == "railgun" else (0, 0, .16)
        if name == "relay_gun":
            target = (0, -.13, .15)
        camera((2.5, -3.7, 5), target, scale)
        scene.render.filepath = os.path.join(ICON, name + ".png")
        bpy.ops.render.render(write_still=True)

    clear()
    scene = studio((1400, 1120), False)
    cam = camera((0, -10, 13), (0, 0, 0), 8.9)
    entries = [("railgun", -2.0, 2.0, "RAILGUN  /  ARMOR PIERCING"),
               ("relay", 2.0, 2.0, "RELAY  /  FLEET SUPPORT"),
               ("shielded", -2.0, -1.9, "SHIELDED  /  DEFENSIVE VANES"),
               ("regenerator", 2.0, -1.9, "REGENERATOR  /  REPAIR PODS")]
    for name, x, y, label in entries:
        assembled(name, (x, y, 0))
        plinth(x, y)
        bpy.ops.object.text_add(location=(x, y - 1.76, -.50))
        txt = bpy.context.object
        txt.data.body = label
        txt.data.align_x = "CENTER"
        txt.data.size = .132
        txt.rotation_euler = cam.rotation_euler
        txt.data.materials.append(label_material())
    scene.render.filepath = os.path.join(PREVIEW, "expansion_gallery.png")
    bpy.ops.render.render(write_still=True)

    clear()
    assembled("relay")
    scene = studio((1000, 800), True)
    camera((3, -4, 1.50), (0, 0, .23), 3.7)
    scene.render.filepath = os.path.join(PREVIEW, "expansion_relay_side.png")
    bpy.ops.render.render(write_still=True)

    clear()
    assembled("railgun")
    scene = studio((1000, 800), True)
    camera((3, -4, -1.85), (0, -.12, 0), 3.5)
    scene.render.filepath = os.path.join(PREVIEW, "expansion_railgun_underside.png")
    bpy.ops.render.render(write_still=True)
    print("EXPANSION ICONS AND PREVIEWS COMPLETE")


if __name__ == "__main__":
    render()
