"""Round-room art for the console room and the Eye hall, rendered in one style.

    blender -b -P tools/blender/rooms.py -- <out_dir> [samples]

1 Blender unit = 1 Factorio tile. Heights are sheared north (y += z * LIFT) and the camera looks
straight down, which gives Factorio's oblique view: the floor keeps square tiles while walls show
their faces. Outputs (transparent background, centred on the room's centre):

  eye-floor.png    2048 px, 68 tiles: Eye hall floor with a round pit for the star
  eye-wall.png     2048 px, 68 tiles: closed wall ring and dark hull around it
  console-wall.png 1024 px, 36 tiles: wall ring with north, east and south openings, and hull
"""
import math
import sys

import bmesh
import bpy
from mathutils import Matrix

argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
OUT = (argv[0] if argv else '//render').rstrip('/\\')
SAMPLES = int(argv[1]) if len(argv) > 1 else 64
ONLY = set(argv[2:])  # optional subset: eye-floor eye-wall console-wall
LIFT = 0.75

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
scene.cycles.device = 'CPU'
scene.cycles.samples = SAMPLES
scene.cycles.use_denoising = True
scene.render.film_transparent = True
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
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = 1.0
    scene.world = world


# ---------- materials ----------

def polar_seams(t, rings, spokes, width):
    """Dark seams on concentric circles (radii list) and radial spokes, from object coordinates."""
    coord = t.nodes.new('ShaderNodeTexCoord')
    sep = t.nodes.new('ShaderNodeSeparateXYZ')
    t.links.new(coord.outputs['Object'], sep.inputs[0])
    length = t.nodes.new('ShaderNodeVectorMath')
    length.operation = 'LENGTH'
    t.links.new(coord.outputs['Object'], length.inputs[0])
    seam = None
    for r in rings:
        d = t.nodes.new('ShaderNodeMath')
        d.operation = 'SUBTRACT'
        d.inputs[1].default_value = r
        t.links.new(length.outputs['Value'], d.inputs[0])
        a = t.nodes.new('ShaderNodeMath')
        a.operation = 'ABSOLUTE'
        t.links.new(d.outputs['Value'], a.inputs[0])
        lt = t.nodes.new('ShaderNodeMath')
        lt.operation = 'LESS_THAN'
        lt.inputs[1].default_value = width
        t.links.new(a.outputs['Value'], lt.inputs[0])
        if seam is None:
            seam = lt.outputs['Value']
        else:
            mx = t.nodes.new('ShaderNodeMath')
            mx.operation = 'MAXIMUM'
            t.links.new(seam, mx.inputs[0])
            t.links.new(lt.outputs['Value'], mx.inputs[1])
            seam = mx.outputs['Value']
    if spokes:
        ang = t.nodes.new('ShaderNodeMath')
        ang.operation = 'ARCTAN2'
        t.links.new(sep.outputs['Y'], ang.inputs[0])
        t.links.new(sep.outputs['X'], ang.inputs[1])
        mul = t.nodes.new('ShaderNodeMath')
        mul.operation = 'MULTIPLY'
        mul.inputs[1].default_value = spokes / (2 * math.pi)
        t.links.new(ang.outputs['Value'], mul.inputs[0])
        fr = t.nodes.new('ShaderNodeMath')
        fr.operation = 'FRACT'
        t.links.new(mul.outputs['Value'], fr.inputs[0])
        # distance to the nearest spoke, in tiles: |fract - 0.5| flipped, times the arc length
        sub = t.nodes.new('ShaderNodeMath')
        sub.operation = 'SUBTRACT'
        sub.inputs[1].default_value = 0.5
        t.links.new(fr.outputs['Value'], sub.inputs[0])
        ab = t.nodes.new('ShaderNodeMath')
        ab.operation = 'ABSOLUTE'
        t.links.new(sub.outputs['Value'], ab.inputs[0])
        inv = t.nodes.new('ShaderNodeMath')
        inv.operation = 'SUBTRACT'
        inv.inputs[0].default_value = 0.5
        t.links.new(ab.outputs['Value'], inv.inputs[1])
        arc = t.nodes.new('ShaderNodeMath')
        arc.operation = 'MULTIPLY'
        t.links.new(inv.outputs['Value'], arc.inputs[0])
        circ = t.nodes.new('ShaderNodeMath')
        circ.operation = 'MULTIPLY'
        circ.inputs[1].default_value = 2 * math.pi / spokes
        t.links.new(length.outputs['Value'], circ.inputs[0])
        t.links.new(circ.outputs['Value'], arc.inputs[1])
        lt = t.nodes.new('ShaderNodeMath')
        lt.operation = 'LESS_THAN'
        lt.inputs[1].default_value = width
        t.links.new(arc.outputs['Value'], lt.inputs[0])
        if seam is None:
            seam = lt.outputs['Value']
        else:
            mx = t.nodes.new('ShaderNodeMath')
            mx.operation = 'MAXIMUM'
            t.links.new(seam, mx.inputs[0])
            t.links.new(lt.outputs['Value'], mx.inputs[1])
            seam = mx.outputs['Value']
    return seam


def plate(name, color, metallic=0.7, rough=0.55, rings=(), spokes=0, seam_width=0.05, grime=1.4, emit=None):
    """Worn metal plate with grime and optional polar panel seams."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    t = m.node_tree
    p = t.nodes['Principled BSDF']
    p.inputs['Metallic'].default_value = metallic
    coord = t.nodes.new('ShaderNodeTexCoord')
    noise = t.nodes.new('ShaderNodeTexNoise')
    noise.inputs['Scale'].default_value = grime
    noise.inputs['Detail'].default_value = 10
    noise.inputs['Roughness'].default_value = 0.68
    t.links.new(coord.outputs['Object'], noise.inputs['Vector'])
    ramp = t.nodes.new('ShaderNodeValToRGB')
    r = ramp.color_ramp
    r.elements[0].position, r.elements[0].color = 0.32, tuple(c * 0.45 for c in color[:3]) + (1,)
    r.elements[1].position, r.elements[1].color = 0.66, color
    t.links.new(noise.outputs['Fac'], ramp.inputs['Fac'])
    base = ramp.outputs['Color']
    if rings or spokes:
        mix = t.nodes.new('ShaderNodeMix')
        mix.data_type = 'RGBA'
        mix.inputs['B'].default_value = (0.02, 0.02, 0.02, 1)
        t.links.new(polar_seams(t, rings, spokes, seam_width), mix.inputs['Factor'])
        t.links.new(base, mix.inputs['A'])
        base = mix.outputs['Result']
    t.links.new(base, p.inputs['Base Color'])
    rough_map = t.nodes.new('ShaderNodeMapRange')
    rough_map.inputs['To Min'].default_value = rough - 0.15
    rough_map.inputs['To Max'].default_value = rough + 0.2
    t.links.new(noise.outputs['Fac'], rough_map.inputs['Value'])
    t.links.new(rough_map.outputs['Result'], p.inputs['Roughness'])
    if emit:
        p.inputs['Emission Color'].default_value = emit[0]
        p.inputs['Emission Strength'].default_value = emit[1]
    return m


def grate(name, color, cells):
    """Industrial floor grating: a brick pattern of dark slots."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    t = m.node_tree
    p = t.nodes['Principled BSDF']
    p.inputs['Metallic'].default_value = 0.8
    p.inputs['Roughness'].default_value = 0.5
    coord = t.nodes.new('ShaderNodeTexCoord')
    brick = t.nodes.new('ShaderNodeTexBrick')
    brick.inputs['Scale'].default_value = cells
    brick.inputs['Mortar Size'].default_value = 0.035
    brick.inputs['Color1'].default_value = (0.012, 0.011, 0.01, 1)
    brick.inputs['Color2'].default_value = (0.016, 0.015, 0.014, 1)
    brick.inputs['Mortar'].default_value = color
    t.links.new(coord.outputs['Object'], brick.inputs['Vector'])
    t.links.new(brick.outputs['Color'], p.inputs['Base Color'])
    return m


# ---------- geometry ----------

def annulus(r_in, r_out, z=0.0, segments=256):
    bpy.ops.mesh.primitive_circle_add(vertices=segments, radius=r_out, fill_type='NOTHING', location=(0, 0, z))
    ob = bpy.context.object
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    outer = list(bm.verts)
    inner = [bm.verts.new((v.co.x * r_in / r_out, v.co.y * r_in / r_out, v.co.z)) for v in outer]
    n = len(outer)
    for i in range(n):
        bm.faces.new((outer[i], outer[(i + 1) % n], inner[(i + 1) % n], inner[i]))
    bm.to_mesh(ob.data)
    bm.free()
    return ob


def wall_ring(r_in, r_out, height, openings, segments=256, z0=0.0):
    """Solid wall: inner face, top, outer face. openings: (angle_deg, half_width_tiles)."""
    me = bpy.data.meshes.new('wall')
    ob = bpy.data.objects.new('wall', me)
    scene.collection.objects.link(ob)
    bm = bmesh.new()

    def is_open(a):
        for c, half in openings:
            d = (math.degrees(a) - c + 180) % 360 - 180
            if abs(math.radians(d)) * r_in < half:
                return True
        return False

    angles = [2 * math.pi * i / segments for i in range(segments)]
    rows = []
    for a in angles:
        ca, sa = math.cos(a), math.sin(a)
        rows.append([bm.verts.new((r * ca, r * sa, z)) for r, z in
                     ((r_in, z0), (r_in, height), (r_out, height), (r_out, z0))])
    for i in range(segments):
        if is_open(angles[i]) or is_open(angles[(i + 1) % segments]):
            continue
        a, b = rows[i], rows[(i + 1) % segments]
        for k in range(3):
            bm.faces.new((a[k], b[k], b[k + 1], a[k + 1]))
    # Close the wall ends at each opening.
    for i in range(segments):
        here, nxt = is_open(angles[i]), is_open(angles[(i + 1) % segments])
        if here != nxt:
            row = rows[(i + 1) % segments] if here else rows[i]
            try:
                bm.faces.new(row)
            except ValueError:
                pass
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    return ob


def disc(r, z, location=(0, 0)):
    bpy.ops.mesh.primitive_circle_add(vertices=96, radius=r, fill_type='NGON', location=(location[0], location[1], z))
    return bpy.context.object


def shear_everything():
    """Factorio's oblique view: height moves things north on screen."""
    m = Matrix(((1, 0, 0, 0), (0, 1, LIFT, 0), (0, 0, 1, 0), (0, 0, 0, 1)))
    for ob in scene.objects:
        if ob.type != 'MESH':
            continue
        ob.data.transform(ob.matrix_world)
        ob.matrix_world = Matrix.Identity(4)
        ob.data.transform(m)
        ob.data.update()


def lights(star=None):
    sun = bpy.data.objects.new('sun', bpy.data.lights.new('sun', 'SUN'))
    sun.data.energy, sun.data.angle = 2.2, math.radians(10)
    sun.rotation_euler = (math.radians(30), math.radians(-20), 0)
    scene.collection.objects.link(sun)
    if star:
        glow = bpy.data.objects.new('star', bpy.data.lights.new('star', 'POINT'))
        glow.data.energy, glow.data.color, glow.data.shadow_soft_size = star, (1.0, 0.55, 0.2), 4
        glow.location = (0, 0, 6)
        scene.collection.objects.link(glow)


def camera(extent, size):
    cam = bpy.data.objects.new('cam', bpy.data.cameras.new('cam'))
    scene.collection.objects.link(cam)
    cam.data.type = 'ORTHO'
    cam.data.ortho_scale = extent
    cam.location = (0, 0, 60)
    cam.data.clip_end = 200
    scene.camera = cam
    scene.render.resolution_x = scene.render.resolution_y = size


def render(name):
    scene.render.filepath = f'{OUT}/{name}.png'
    bpy.ops.render.render(write_still=True)


def wall_materials():
    stone = plate('wall', (0.33, 0.31, 0.28, 1), rings=(), spokes=48, seam_width=0.06, grime=0.6)
    hull = plate('hull', (0.12, 0.12, 0.13, 1), metallic=0.5, rough=0.7, spokes=24, seam_width=0.05, grime=0.5)
    brass = plate('brass', (0.72, 0.5, 0.22, 1), metallic=0.9, rough=0.35, grime=3)
    lamp = plate('lamp', (1.0, 0.55, 0.15, 1), emit=((1.0, 0.5, 0.12, 1), 12.0))
    return stone, hull, brass, lamp


def build_wall(r_in, r_out, height, openings, hull_out):
    stone, hull, brass, lamp = wall_materials()
    lamp_dim = plate('roundel', (0.2, 0.17, 0.12, 1), metallic=0.6, rough=0.5, emit=((1.0, 0.55, 0.2, 1), 0.6))
    wall = wall_ring(r_in, r_out, height, openings)
    wall.data.materials.append(stone)
    # Brass cap rail and amber lamps along the top inner edge.
    cap = wall_ring(r_in - 0.05, r_in + 0.35, height + 0.12, openings, z0=height - 0.1)
    cap.data.materials.append(brass)
    count = int(2 * math.pi * r_in / 3.2)
    for i in range(count):
        a = 2 * math.pi * (i + 0.5) / count
        if any(abs(((math.degrees(a) - c + 180) % 360 - 180)) * math.pi / 180 * r_in < h + 0.8 for c, h in openings):
            continue
        bpy.ops.mesh.primitive_cube_add(size=1, location=((r_in + 0.6) * math.cos(a), (r_in + 0.6) * math.sin(a),
                                                          height + 0.06))
        b = bpy.context.object
        b.scale = (0.28, 0.5, 0.08)
        b.rotation_euler.z = a
        b.data.materials.append(lamp)
    # Dark hull falling away outside the wall.
    h = wall_ring(r_out, hull_out, 0.02, openings, z0=-0.02)
    h.data.materials.append(hull)
    # Roundels on the inner face, the TARDIS signature; only the northern half faces the viewer.
    count = int(2 * math.pi * r_in / 4.0)
    for i in range(count):
        a = 2 * math.pi * (i + 0.25) / count
        if math.sin(a) < -0.2:
            continue
        if any(abs(((math.degrees(a) - c + 180) % 360 - 180)) * math.pi / 180 * r_in < hw + 1.2 for c, hw in openings):
            continue
        x, y = (r_in - 0.02) * math.cos(a), (r_in - 0.02) * math.sin(a)
        bpy.ops.mesh.primitive_torus_add(major_radius=height * 0.3, minor_radius=0.07, location=(x, y, height * 0.48))
        ring = bpy.context.object
        ring.rotation_euler = (math.pi / 2, 0, a + math.pi / 2)
        ring.data.materials.append(brass)
        bpy.ops.mesh.primitive_cylinder_add(radius=height * 0.24, depth=0.05, location=(x, y, height * 0.48))
        face = bpy.context.object
        face.rotation_euler = (math.pi / 2, 0, a + math.pi / 2)
        face.data.materials.append(lamp_dim)
    return wall


def eye_floor():
    steel = plate('floor', (0.17, 0.16, 0.15, 1), rings=(9, 15.5, 22, 24, 29.4), spokes=24, seam_width=0.05, grime=2.2)
    brass = plate('brass-floor', (0.42, 0.3, 0.15, 1), metallic=0.85, rough=0.45, rings=(8.4,), spokes=16, grime=2.5)
    mesh = grate('grate', (0.2, 0.19, 0.17, 1), 2.5)
    base = annulus(9, 29.6)
    base.data.materials.append(steel)
    inner = annulus(7.4, 9, z=0.0)
    inner.data.materials.append(brass)
    band = annulus(22, 24, z=0.005)
    band.data.materials.append(mesh)
    for x, y in ((0, 17), (0, -17), (17, 0), (-17, 0)):
        pad = disc(3.5, 0.01, (x, y))
        pad.data.materials.append(brass)
    # Walkway grates along the axes between the brass ring and the pads.
    for (cx, cy, sx, sy) in ((0, 11.25, 4, 4.5), (0, -11.25, 4, 4.5), (11.25, 0, 4.5, 4), (-11.25, 0, 4.5, 4),
                             (0, 25, 4, 4.2), (0, -25, 4, 4.2), (25, 0, 4.2, 4), (-25, 0, 4.2, 4)):
        bpy.ops.mesh.primitive_plane_add(size=1, location=(cx, cy, 0.008))
        g = bpy.context.object
        g.scale = (sx, sy, 1)
        bpy.ops.object.transform_apply(scale=True)
        g.data.materials.append(mesh)
    # The pit: a brass lip and a deep shaft lit by the star from inside.
    lip = wall_ring(7.4, 7.9, 0.25, ())
    lip.data.materials.append(brass)
    shaft = plate('shaft', (0.08, 0.06, 0.055, 1), metallic=0.4, rough=0.8, spokes=32)
    bpy.ops.mesh.primitive_cylinder_add(vertices=128, radius=7.4, depth=8, location=(0, 0, -4), end_fill_type='NOTHING')
    s = bpy.context.object
    s.data.materials.append(shaft)
    bottom = disc(7.4, -8)
    bottom.data.materials.append(plate('deep', (0.02, 0.012, 0.01, 1), emit=((1.0, 0.35, 0.06, 1), 0.07)))


def wanted(name):
    return not ONLY or name in ONLY


# Eye hall floor
if wanted('eye-floor'):
    clear()
    eye_floor()
    lights(star=5000)
    shear_everything()
    camera(68, 2048)
    render('eye-floor')

# Eye hall wall: closed ring
if wanted('eye-wall'):
    clear()
    build_wall(29.6, 31.9, 2.4, (), 34)
    lights()
    shear_everything()
    camera(68, 2048)
    render('eye-wall')

# Console room wall: corridors north (rooms) and east (cargo hold); the exit doors sit in the
# south wall as their own sprite.
if wanted('console-wall'):
    clear()
    build_wall(13.4, 15.4, 2.0, ((90, 2.2), (0, 2.2)), 17.2)
    lights()
    shear_everything()
    camera(36, 1024)
    render('console-wall')
