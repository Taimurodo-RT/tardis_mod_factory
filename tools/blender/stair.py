"""Spiral stair between the console room and the Eye hall, as two Factorio sprites.

    blender -b -P tools/blender/stair.py -- <out_dir> [size] [samples]

stair-down.png: seen in the console room; the stair winds down a shaft lit orange by the star.
stair-up.png  : seen in the Eye hall; the stair climbs towards a pale light from the console room.
"""
import math
import sys

import bpy

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = (argv[0] if argv else '//render').rstrip('/\\')
SIZE = int(argv[1]) if len(argv) > 1 else 384
SAMPLES = int(argv[2]) if len(argv) > 2 else 64

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
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.02, 0.02, 0.025, 1)
    scene.world = world


def material(name, color, metallic, rough, emit=0.0):
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


def stair(direction):
    """direction +1 climbs up from the floor, -1 winds down into a shaft."""
    steel = material('steel', (0.42, 0.41, 0.39, 1), 0.7, 0.45)
    brass = material('brass', (0.72, 0.5, 0.22, 1), 0.9, 0.35)
    steps, rise, turn = 16, 0.17, math.radians(24)
    bpy.ops.mesh.primitive_cylinder_add(radius=0.11, depth=steps * rise + 0.4,
                                        location=(0, 0, direction * (steps * rise) / 2))
    bpy.context.object.data.materials.append(brass)
    for i in range(steps):
        a = i * turn + math.radians(-90)
        z = direction * (i + 0.5) * rise
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0.55 * math.cos(a), 0.55 * math.sin(a), z))
        st = bpy.context.object
        st.scale = (0.95, 0.36, 0.05)
        st.rotation_euler.z = a
        st.data.materials.append(steel)
        bpy.ops.mesh.primitive_cylinder_add(radius=0.025, depth=0.55,
                                            location=(1.02 * math.cos(a), 1.02 * math.sin(a), z + 0.27))
        bpy.context.object.data.materials.append(brass)
    # Brass collar where the stair meets this floor.
    bpy.ops.mesh.primitive_torus_add(major_radius=1.15, minor_radius=0.07, location=(0, 0, 0))
    bpy.context.object.data.materials.append(brass)
    if direction < 0:
        # Shaft walls and the star's glow far below.
        bpy.ops.mesh.primitive_cylinder_add(radius=1.12, depth=3.2, location=(0, 0, -1.6), end_fill_type='NOTHING')
        shaft = bpy.context.object
        shaft.data.materials.append(material('shaft', (0.05, 0.045, 0.045, 1), 0.3, 0.8))
        bpy.ops.mesh.primitive_circle_add(radius=1.12, fill_type='NGON', location=(0, 0, -3.1))
        bpy.context.object.data.materials.append(material('glow', (1.0, 0.42, 0.08, 1), 0, 1, emit=8.0))
        # The console-room floor around the opening hides the shaft's outside (holdout = transparent).
        bpy.ops.mesh.primitive_circle_add(radius=4, fill_type='NGON', location=(0, 0, 0.001))
        floor = bpy.context.object
        cut = floor.modifiers.new('hole', 'BOOLEAN')
        bpy.ops.mesh.primitive_cylinder_add(radius=1.12, depth=1, location=(0, 0, 0))
        hole = bpy.context.object
        hole.hide_render = True
        cut.object = hole
        hold = bpy.data.materials.new('holdout')
        hold.use_nodes = True
        nodes = hold.node_tree.nodes
        nodes.clear()
        h = nodes.new('ShaderNodeHoldout')
        o = nodes.new('ShaderNodeOutputMaterial')
        hold.node_tree.links.new(h.outputs['Holdout'], o.inputs['Surface'])
        floor.data.materials.append(hold)
        light = bpy.data.objects.new('under', bpy.data.lights.new('under', 'POINT'))
        light.data.energy, light.data.color = 450, (1.0, 0.5, 0.15)
        light.location = (0, 0, -2.7)
        scene.collection.objects.link(light)
    else:
        light = bpy.data.objects.new('above', bpy.data.lights.new('above', 'POINT'))
        light.data.energy, light.data.color = 110, (0.75, 0.9, 1.0)
        light.location = (0, 0.2, steps * rise + 0.6)
        scene.collection.objects.link(light)
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy, sun.data.angle = 2.0, math.radians(12)
    sun.rotation_euler = (math.radians(22), math.radians(-14), 0)
    scene.collection.objects.link(sun)
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    scene.collection.objects.link(cam)
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = 3.4 if direction < 0 else 4.4
    tilt = math.radians(40)
    centre_z = 0 if direction < 0 else steps * rise / 2
    cam.location = (0, -20 * math.sin(tilt), centre_z + 20 * math.cos(tilt))
    cam.rotation_euler = (tilt, 0, 0)
    scene.camera = cam


for name, direction in (('stair-down', -1), ('stair-up', 1)):
    clear()
    stair(direction)
    scene.render.filepath = f'{OUT}/{name}.png'
    bpy.ops.render.render(write_still=True)
