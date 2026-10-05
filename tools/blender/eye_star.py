"""Eye of Harmony: a captive star inside three tumbling containment rings, rendered as a
seamless loop for a Factorio animation.

    blender -b -P tools/blender/eye_star.py -- <out_dir> [frames] [size] [samples] [only_frame]

Writes <out_dir>/0001.png ... with a transparent background. Everything loops exactly:
ring rotations are whole turns, and the surface noise is sampled along a closed circle.
"""
import math
import sys

import bpy

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = argv[0] if argv else '//render/'
FRAMES = int(argv[1]) if len(argv) > 1 else 96
SIZE = int(argv[2]) if len(argv) > 2 else 384
SAMPLES = int(argv[3]) if len(argv) > 3 else 48
ONLY = int(argv[4]) if len(argv) > 4 else 0

# Clear the startup scene in place. (read_factory_settings would also reset the user's add-on and
# extension state, which makes Blender prune their installed Python wheels.)
for block in (bpy.data.objects, bpy.data.meshes, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
    for item in list(block):
        block.remove(item)
scene = bpy.context.scene
scene.frame_start, scene.frame_end = 1, FRAMES
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.render.film_transparent = True
scene.render.resolution_x = scene.render.resolution_y = SIZE
scene.render.image_settings.file_format = 'PNG'
scene.render.image_settings.color_mode = 'RGBA'
scene.view_settings.view_transform = 'Standard'
scene.view_settings.look = 'None'

world = bpy.data.worlds.new('void')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs['Color'].default_value = (0.02, 0.02, 0.025, 1)
scene.world = world


def driver(socket, expr):
    d = socket.driver_add('default_value').driver
    d.type = 'SCRIPTED'
    d.expression = expr


def node(tree, kind, **inputs):
    n = tree.nodes.new(kind)
    for k, v in inputs.items():
        n.inputs[k].default_value = v
    return n


def star_material():
    m = bpy.data.materials.new('star')
    m.use_nodes = True
    t = m.node_tree
    t.nodes.clear()
    coord = t.nodes.new('ShaderNodeTexCoord')
    offset = t.nodes.new('ShaderNodeCombineXYZ')
    # The sample point travels round a closed circle: the boiling surface loops seamlessly.
    driver(offset.inputs['X'], f'0.9*cos(frame/{FRAMES}*2*pi)')
    driver(offset.inputs['Y'], f'0.9*sin(frame/{FRAMES}*2*pi)')
    add = t.nodes.new('ShaderNodeVectorMath')
    add.operation = 'ADD'
    t.links.new(coord.outputs['Object'], add.inputs[0])
    t.links.new(offset.outputs['Vector'], add.inputs[1])
    cells = node(t, 'ShaderNodeTexNoise', Scale=5.5, Detail=8.0, Roughness=0.62)
    t.links.new(add.outputs['Vector'], cells.inputs['Vector'])
    ramp = t.nodes.new('ShaderNodeValToRGB')
    r = ramp.color_ramp
    r.elements[0].position, r.elements[0].color = 0.3, (0.32, 0.025, 0.0, 1)
    r.elements[1].position, r.elements[1].color = 0.78, (1.0, 0.82, 0.4, 1)
    mid = r.elements.new(0.52)
    mid.color = (1.0, 0.33, 0.02, 1)
    t.links.new(cells.outputs['Fac'], ramp.inputs['Fac'])
    # Limb: the edge of the disc glows hotter, like a real star seen through its photosphere.
    weight = node(t, 'ShaderNodeLayerWeight', Blend=0.18)
    limb = t.nodes.new('ShaderNodeMix')
    limb.data_type = 'RGBA'
    limb.inputs['B'].default_value = (1.0, 0.55, 0.12, 1)
    t.links.new(weight.outputs['Fresnel'], limb.inputs['Factor'])
    t.links.new(ramp.outputs['Color'], limb.inputs['A'])
    emit = node(t, 'ShaderNodeEmission', Strength=2.2)
    t.links.new(limb.outputs['Result'], emit.inputs['Color'])
    out = t.nodes.new('ShaderNodeOutputMaterial')
    t.links.new(emit.outputs['Emission'], out.inputs['Surface'])
    return m


def corona_material():
    m = bpy.data.materials.new('corona')
    m.use_nodes = True
    t = m.node_tree
    t.nodes.clear()
    weight = node(t, 'ShaderNodeLayerWeight', Blend=0.5)
    # Facing the camera = transparent; grazing = soft orange haze.
    curve = t.nodes.new('ShaderNodeMath')
    curve.operation = 'POWER'
    curve.inputs[1].default_value = 4.0
    invert = t.nodes.new('ShaderNodeMath')
    invert.operation = 'SUBTRACT'
    invert.inputs[0].default_value = 1.0
    t.links.new(weight.outputs['Facing'], invert.inputs[1])
    t.links.new(invert.outputs['Value'], curve.inputs[0])
    flip = t.nodes.new('ShaderNodeMath')
    flip.operation = 'SUBTRACT'
    flip.inputs[0].default_value = 1.0
    t.links.new(curve.outputs['Value'], flip.inputs[1])
    emit = node(t, 'ShaderNodeEmission', Color=(1.0, 0.38, 0.05, 1), Strength=1.1)
    clear = t.nodes.new('ShaderNodeBsdfTransparent')
    mix = t.nodes.new('ShaderNodeMixShader')
    t.links.new(flip.outputs['Value'], mix.inputs['Fac'])
    t.links.new(emit.outputs['Emission'], mix.inputs[1])
    t.links.new(clear.outputs['BSDF'], mix.inputs[2])
    out = t.nodes.new('ShaderNodeOutputMaterial')
    t.links.new(mix.outputs['Shader'], out.inputs['Surface'])
    return m


def metal(name, color, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = color
    p.inputs['Metallic'].default_value = 1.0
    p.inputs['Roughness'].default_value = rough
    return m


def glow(name, color, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = m.node_tree.nodes['Principled BSDF']
    p.inputs['Base Color'].default_value = color
    p.inputs['Emission Color'].default_value = color
    p.inputs['Emission Strength'].default_value = strength
    return m


steel = metal('steel', (0.42, 0.41, 0.4, 1), 0.42)
brass = metal('brass', (0.8, 0.56, 0.24, 1), 0.32)
amber = glow('amber', (1.0, 0.45, 0.08, 1), 5.0)

bpy.ops.mesh.primitive_uv_sphere_add(segments=96, ring_count=48, radius=1.0)
star = bpy.context.object
star.data.materials.append(star_material())
bpy.ops.object.shade_smooth()

bpy.ops.mesh.primitive_uv_sphere_add(segments=64, ring_count=32, radius=1.32)
corona = bpy.context.object
corona.data.materials.append(corona_material())
corona.visible_shadow = False
bpy.ops.object.shade_smooth()


def ring(major, minor, tilt, axis, turns, clamps, phase=0.0, precess=0):
    """A ring on a pivot: tilt sets its plane, the ring spins `turns` whole turns per loop about
    `axis`, and the pivot precesses `precess` whole turns about the vertical, like a gyroscope."""
    pivot = bpy.data.objects.new(f'pivot{major}', None)
    scene.collection.objects.link(pivot)
    pivot.rotation_euler = tilt
    if precess:
        pivot.keyframe_insert('rotation_euler', index=2, frame=1)
        pivot.rotation_euler.z = tilt[2] + precess * 2 * math.pi
        pivot.keyframe_insert('rotation_euler', index=2, frame=FRAMES + 1)
    # A flat steel band (a torus squashed along its axis) with a glowing conduit on its inner face.
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=128, minor_segments=24)
    body = bpy.context.object
    body.data.materials.append(steel)
    body.scale.z = 0.42
    bpy.ops.object.transform_apply(scale=True)
    bpy.ops.object.shade_smooth()
    body.parent = pivot
    bpy.ops.mesh.primitive_torus_add(major_radius=major - minor * 0.92, minor_radius=minor * 0.22, major_segments=128, minor_segments=12)
    strip = bpy.context.object
    strip.data.materials.append(amber)
    strip.parent = body
    for i in range(clamps):
        a = 2 * math.pi * i / clamps
        bpy.ops.mesh.primitive_cube_add(size=1)
        c = bpy.context.object
        c.scale = (minor * 2.4, minor * 3.4, minor * 1.6)
        c.location = (major * math.cos(a), major * math.sin(a), 0)
        c.rotation_euler.z = a
        c.data.materials.append(brass)
        c.parent = body
    body.rotation_mode = 'XYZ'
    idx = 'XYZ'.index(axis)
    start = list(body.rotation_euler)
    start[idx] = phase
    body.rotation_euler = start
    body.keyframe_insert('rotation_euler', index=idx, frame=1)
    end = list(start)
    end[idx] = phase + turns * 2 * math.pi
    body.rotation_euler = end
    # Frame FRAMES+1 equals frame 1, so the rendered 1..FRAMES loop has no repeated frame.
    body.keyframe_insert('rotation_euler', index=idx, frame=FRAMES + 1)
    for fc in body.animation_data.action.fcurves if hasattr(body.animation_data.action, 'fcurves') else []:
        for k in fc.keyframe_points:
            k.interpolation = 'LINEAR'
    return body


# Key light from the top-left, as in Factorio's own renders.
sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
sun.data.energy = 2.5
sun.rotation_euler = (math.radians(35), math.radians(-30), math.radians(-40))
scene.collection.objects.link(sun)

rings = [
    ring(1.62, 0.13, (0, 0, 0), 'Z', 1, 6),
    ring(1.98, 0.14, (math.radians(62), 0, 0), 'Z', -1, 4, precess=1),
    ring(2.34, 0.15, (0, math.radians(75), math.radians(25)), 'Z', 1, 8, phase=0.4, precess=-1),
]
# Slot-based actions (Blender 4.4+) keep fcurves in channelbags; force linear keys there too.
for a in bpy.data.actions:
    for layer in getattr(a, 'layers', []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                for fc in bag.fcurves:
                    for k in fc.keyframe_points:
                        k.interpolation = 'LINEAR'

# Orthographic camera at a Factorio-like angle: looking down, tilted towards the north.
cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
scene.collection.objects.link(cam)
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 5.6
tilt = math.radians(40)
cam.location = (0, -20 * math.sin(tilt), 20 * math.cos(tilt))
cam.rotation_euler = (tilt, 0, 0)
scene.camera = cam

scene.render.filepath = OUT.rstrip('/\\') + '/'
if ONLY:
    scene.frame_set(ONLY)
    scene.render.filepath = OUT.rstrip('/\\') + f'/still_{ONLY:04d}.png'
    bpy.ops.render.render(write_still=True)
else:
    bpy.ops.render.render(animation=True)
