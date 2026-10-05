"""The TARDIS doors set into the console room's south wall, closed and open.

    blender -b -P tools/blender/doors.py -- <out_dir> [size] [samples]

1 unit = 1 tile, same oblique Factorio view as rooms.py (height sheared north, camera straight
down). doors-closed.png / doors-open.png: the doorway is 3 tiles wide and 4 tiles tall; open,
the leaves swing inward and the doorway is pure white light (abstract, no view outside).
"""
import math
import sys

import bpy
from mathutils import Matrix

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = (argv[0] if argv else '//render').rstrip('/\\')
SIZE = int(argv[1]) if len(argv) > 1 else 384
SAMPLES = int(argv[2]) if len(argv) > 2 else 64
LIFT = 0.75

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'Standard'


def clear():
    # Clear in place (read_factory_settings would make Blender prune the user's extension wheels).
    for block in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for item in list(block):
            block.remove(item)
    world = bpy.data.worlds.get('void') or bpy.data.worlds.new('void')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.03, 0.03, 0.035, 1)
    scene.world = world


def mat(name, color, metallic=0.0, rough=0.6, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = color
    p.inputs['Metallic'].default_value = metallic
    p.inputs['Roughness'].default_value = rough
    if emit:
        p.inputs['Emission Color'].default_value = color
        p.inputs['Emission Strength'].default_value = emit
    return m


def box(size, loc, material, parent=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    b = bpy.context.object
    b.scale = size
    b.data.materials.append(material)
    if parent:
        b.parent = parent
    return b


def leaf(hinge_x, side, angle, blue, frame_mat, glass):
    """One door leaf, 1.5 wide, hinged at hinge_x; side = +1 opens to the right, -1 to the left."""
    pivot = bpy.data.objects.new('hinge', None)
    scene.collection.objects.link(pivot)
    pivot.location = (hinge_x, 0, 0)
    pivot.rotation_euler.z = side * angle
    w, h, t = 1.48, 3.6, 0.12
    cx = side * w / 2
    box((w, t, h), (cx, 0, h / 2), blue, pivot)
    # Raised panels: four rows; the top row is the window.
    for row in range(4):
        z = 0.45 + row * 0.82
        for face in (-1, 1):
            if row == 3:
                for col in range(3):
                    box((0.36, 0.02, 0.62), (cx + (col - 1) * 0.42, face * (t / 2 + 0.01), z + 0.32), glass, pivot)
            else:
                box((1.14, 0.03, 0.66), (cx, face * (t / 2 + 0.015), z + 0.3), frame_mat, pivot)
                box((1.0, 0.04, 0.52), (cx, face * (t / 2 + 0.03), z + 0.3), blue, pivot)
    return pivot


def doors(open_):
    clear()
    blue = mat('blue', (0.02, 0.07, 0.22, 1), rough=0.45)
    trim = mat('trim', (0.015, 0.05, 0.16, 1), rough=0.5)
    glass = mat('glass', (0.75, 0.85, 1.0, 1), rough=0.2, emit=1.2 if open_ else 0.35)
    stone = mat('stone', (0.3, 0.29, 0.27, 1), metallic=0.6, rough=0.55)
    brass = mat('brass', (0.72, 0.5, 0.22, 1), metallic=0.9, rough=0.35)
    sign = mat('sign', (0.02, 0.02, 0.025, 1), rough=0.4, emit=0.0)
    # Frame: two posts, lintel with the dark sign band, brass threshold.
    for x in (-1.72, 1.72):
        box((0.42, 0.5, 4.3), (x, 0, 2.15), trim)
    box((3.9, 0.55, 0.5), (0, 0, 4.05), trim)
    box((3.0, 0.08, 0.28), (0, -0.3, 4.05), sign)
    box((3.5, 0.6, 0.06), (0, 0, 0.03), brass)
    angle = math.radians(80) if open_ else 0
    leaf(-1.48, 1, angle, blue, trim, glass)
    leaf(1.48, -1, angle, blue, trim, glass)
    if open_:
        # The doorway is light: a glowing plane and a pool of light spilling into the room.
        box((2.96, 0.02, 3.7), (0, 0.15, 1.85), mat('light', (1, 1, 1, 1), emit=12.0))
        spill = bpy.data.objects.new('spill', bpy.data.lights.new('spill', 'AREA'))
        spill.data.energy, spill.data.size = 600, 3
        spill.location = (0, 0.3, 1.8)
        spill.rotation_euler = (math.radians(-90), 0, 0)
        scene.collection.objects.link(spill)
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy, sun.data.angle = 2.2, math.radians(10)
    sun.rotation_euler = (math.radians(30), math.radians(-20), 0)
    scene.collection.objects.link(sun)
    # Seen from inside the room, looking south: turn everything round so the inner face is shown.
    turn = Matrix.Rotation(math.pi, 4, 'Z')
    shear = Matrix(((1, 0, 0, 0), (0, 1, LIFT, 0), (0, 0, 1, 0), (0, 0, 0, 1)))
    bpy.context.view_layer.update()
    for ob in list(scene.objects):
        if ob.type == 'MESH':
            ob.data.transform(ob.matrix_world)
            ob.parent = None
            ob.matrix_world = Matrix.Identity(4)
            ob.data.transform(turn)
            ob.data.transform(shear)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    scene.collection.objects.link(cam)
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 8
    cam.location = (0, 1.6, 60)
    cam.data.clip_end = 200
    scene.camera = cam
    scene.render.filepath = f'{OUT}/doors-{"open" if open_ else "closed"}.png'
    bpy.ops.render.render(write_still=True)


doors(False)
doors(True)
