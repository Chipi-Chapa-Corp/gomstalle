import bpy
import math
import random
from pathlib import Path
from mathutils import Vector

OUTPUT = Path(__file__).resolve().parents[2] / 'assets' / 'castle' / 'library'
PALETTE = {
    'oak': '35291f', 'panel': '4b3626', 'edge': '806044', 'grain': '60452f',
    'brass': 'b49356', 'iron': '252b2b', 'pages': 'c6b48d', 'paper': 'e2cfaa',
    'burgundy': '653442', 'forest': '35544b', 'navy': '354452', 'ochre': '916d3e',
    'wax': 'e6cf98', 'glow': 'ffc77a', 'sea': '355c66', 'land': 'ad9b70',
}
GEOMETRY = {}
COLLISIONS = []
RANDOM = random.Random(641)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def linear(channel):
    value = int(channel, 16) / 255
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4


MATERIALS = {}
for name, color in PALETTE.items():
    material = bpy.data.materials.new('Library ' + name)
    material.diffuse_color = tuple(linear(color[index:index + 2]) for index in (0, 2, 4)) + (1,)
    material.use_nodes = True
    shader = material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = material.diffuse_color
    shader.inputs['Roughness'].default_value = .34 if name == 'brass' else .72
    shader.inputs['Metallic'].default_value = .75 if name in ('brass', 'iron') else 0
    if name == 'glow':
        shader.inputs['Emission Color'].default_value = material.diffuse_color
        shader.inputs['Emission Strength'].default_value = 3
    MATERIALS[name] = material


def geometry(name, vertices, faces, material, bevel=0):
    center = sum((Vector(vertex) for vertex in vertices), Vector()) / len(vertices)
    key = (int(center.x // 6), int(center.y // 6), material, bevel)
    batch = GEOMETRY.setdefault(key, {'vertices': [], 'faces': [], 'name': name})
    offset = len(batch['vertices'])
    batch['vertices'].extend(vertices)
    batch['faces'].extend(tuple(index + offset for index in face) for face in faces)


def box(name, center, size, material='oak', bevel=.018, yaw=0, solid=False):
    vertices = []
    for horizontal, depth, height in ((-1,-1,-1), (1,-1,-1), (1,1,-1), (-1,1,-1), (-1,-1,1), (1,-1,1), (1,1,1), (-1,1,1)):
        local_x, local_y = horizontal * size[0] / 2, depth * size[1] / 2
        vertices.append((center[0] + local_x * math.cos(yaw) - local_y * math.sin(yaw), center[1] + local_x * math.sin(yaw) + local_y * math.cos(yaw), center[2] + height * size[2] / 2))
    geometry(name, vertices, [(3,2,1,0), (4,5,6,7), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7)], material, bevel)
    if solid:
        COLLISIONS.append((name, center, size, yaw))


def rod(name, start, end, radius, material='brass', segments=12):
    direction = Vector(end) - Vector(start)
    basis = direction.to_track_quat('Z', 'Y').to_matrix()
    vertices = [tuple(Vector(endpoint) + basis @ Vector((radius * math.cos(index * math.tau / segments), radius * math.sin(index * math.tau / segments), 0))) for endpoint in (start, end) for index in range(segments)]
    faces = [tuple(reversed(range(segments))), tuple(range(segments, segments * 2))]
    faces.extend((index, (index + 1) % segments, (index + 1) % segments + segments, index + segments) for index in range(segments))
    geometry(name, vertices, faces, material)


def ring(name, center, radius, thickness, material='brass', tilt=0):
    points = []
    for index in range(49):
        angle = index * math.tau / 48
        points.append((center[0] + radius * math.cos(angle), center[1] + radius * math.sin(angle) * math.cos(tilt), center[2] + radius * math.sin(angle) * math.sin(tilt)))
    for index in range(48):
        rod(name, points[index], points[index + 1], thickness, material, 6)


def book(center, width=.18, height=.48, depth=.36, color=None):
    color = color or RANDOM.choice(('burgundy', 'forest', 'navy', 'ochre'))
    box('Bound paper', center, (width - .022, depth - .035, height - .045), 'pages', 0)
    for side in (-1, 1):
        box('Leather board', (center[0] + side * (width / 2 - .012), center[1], center[2]), (.024, depth, height), color, 0)
    box('Rounded leather spine', (center[0], center[1] - depth / 2, center[2]), (width, .04, height), color, .008)
    for offset in (-.32, .32):
        box('Raised spine band', (center[0], center[1] - depth / 2 - .025, center[2] + height * offset), (width + .007, .014, .018), 'brass', 0)
    box('Book spine label', (center[0], center[1] - depth / 2 - .023, center[2] + .025), (width * .6, .008, height * .15), 'pages', 0)


def bookcase(horizontal, depth, base=0, width=2.8, rows=4):
    height = rows * .57 + .28
    box('Recessed cabinet back', (horizontal, depth + .3, base + height / 2), (width, .12, height), 'panel')
    for side in (-1, 1):
        box('Fluted cabinet pilaster', (horizontal + side * (width / 2 - .09), depth, base + height / 2), (.18, .8, height), 'oak')
        box('Pilaster inlay', (horizontal + side * (width / 2 - .09), depth - .411, base + height / 2), (.036, .024, height - .2), 'edge', 0)
    for level in range(rows + 1):
        shelf_height = base + .17 + level * .57
        box('Shelf with rounded nosing', (horizontal, depth, shelf_height), (width, .8, .09), 'edge')
        if level == rows:
            continue
        cursor = horizontal - width / 2 + .23
        while cursor < horizontal + width / 2 - .35:
            book_width = RANDOM.uniform(.11, .23)
            book_height = RANDOM.uniform(.32, .48)
            book((cursor + book_width / 2, depth - .14, shelf_height + .05 + book_height / 2), book_width, book_height)
            cursor += book_width + RANDOM.uniform(.015, .035)
    box('Cabinet crown', (horizontal, depth - .01, base + height + .04), (width + .1, .91, .14), 'oak', .035)
    box('Brass category plate', (horizontal, depth - .48, base + height + .035), (.44, .025, .075), 'brass', .006)
    COLLISIONS.append(('Book cabinet', (horizontal, depth, base + height / 2), (width, .8, height), 0))


def west_bookcase(depth, base=0, width=2.8, rows=4):
    horizontal = -34.2
    previous_sizes = {key: len(batch['vertices']) for key, batch in GEOMETRY.items()}
    collision_start = len(COLLISIONS)
    bookcase(horizontal, depth, base, width, rows)
    for key, batch in GEOMETRY.items():
        for index in range(previous_sizes.get(key, 0), len(batch['vertices'])):
            vertex = batch['vertices'][index]
            batch['vertices'][index] = (horizontal - (vertex[1] - depth), depth + vertex[0] - horizontal, vertex[2])
    for index in range(collision_start, len(COLLISIONS)):
        name, center, size, yaw = COLLISIONS[index]
        COLLISIONS[index] = (name, center, size, yaw + math.pi / 2)


def open_book(center, scale=1):
    for side in (-1, 1):
        box('Atlas leather cover', (center[0] + side * .29 * scale, center[1], center[2]), (.6 * scale, .8 * scale, .045), 'burgundy', .012)
        box('Atlas open pages', (center[0] + side * .285 * scale, center[1], center[2] + .045), (.53 * scale, .74 * scale, .045), 'paper', .006)
        for line in range(8):
            box('Handwritten atlas lines', (center[0] + side * .29 * scale, center[1] - .26 * scale + line * .066 * scale, center[2] + .071), (.33 * scale, .007, .002), 'panel', 0)
    box('Ribbon bookmark', (center[0] + .13 * scale, center[1] - .11 * scale, center[2] + .075), (.035, .93 * scale, .003), 'forest', 0)


def lamp(center):
    rod('Lamp foot', center, (center[0], center[1], center[2] + .045), .16, 'brass', 24)
    rod('Lamp stem', center, (center[0], center[1], center[2] + .53), .035)
    box('Green reading lamp shade', (center[0], center[1], center[2] + .51), (.65, .32, .17), 'forest', .06)
    box('Warm lamp diffuser', (center[0], center[1], center[2] + .428), (.52, .23, .014), 'glow', .008)


def table(horizontal, depth, width, length):
    for plank in range(5):
        box('Desk planks', (horizontal - width / 2 + (plank + .5) * width / 5, depth, 1.07), (width / 5 - .009, length, .14), 'edge')
    for side in (-1, 1):
        box('Carved table trestle', (horizontal, depth + side * (length / 2 - .3), .52), (width * .73, .18, 1.04), 'oak', .035)
        box('Trestle foot', (horizontal, depth + side * (length / 2 - .3), .12), (width * .94, .36, .2), 'oak', .035)
    box('Table stretcher', (horizontal, depth, .31), (.16, length - .5, .15), 'panel')
    COLLISIONS.append(('Reading table', (horizontal, depth, .58), (width, length, 1.16), 0))


def bench(horizontal, depth, length):
    box('Leather padded bench', (horizontal, depth, .56), (.46, length, .16), 'forest', .05, solid=True)
    for side in (-1, 1):
        box('Bench end legs', (horizontal, depth + side * (length / 2 - .2), .27), (.35, .16, .54), 'oak', solid=True)


for horizontal in (-33.2, -30.25, -27.3, -24.35, -21.4, -18.45, -15.5):
    bookcase(horizontal, 10.65, 0, 2.8, 3)
    bookcase(horizontal, 10.65, 2.7, 2.8, 4)
    box('Gallery architectural backing', (horizontal, 11.17, 4.16), (2.96, .16, 3.13), 'panel')
    for side in (-1, 1):
        box('Raised gallery pilaster', (horizontal + side * 1.44, 10.63, 4.3), (.13, 1.06, 3.24), 'oak')
        box('Pilaster capital', (horizontal + side * 1.44, 10.61, 5.76), (.26, 1.14, .16), 'edge')
    previous = (horizontal - 1.38, 10.52, 5.38)
    for section in range(1, 19):
        angle = math.pi - math.pi * section / 18
        following = (horizontal + 1.38 * math.cos(angle), 10.52, 5.38 + .48 * math.sin(angle))
        rod('Arched library bay crown', previous, following, .07, 'edge', 6)
        previous = following
box('Library upper cornice', (-24.35, 10.99, 5.91), (21.65, .75, .18), 'oak', .03)

box('North gallery deck', (-24.35, 9.05, 2.53), (21.3, 3.5, .28), 'oak', solid=True)
box('West gallery deck', (-33.55, 3.65, 2.53), (2.9, 7.3, .28), 'oak', solid=True)
for plank in range(71):
    box('Gallery individual floorboards', (-34.85 + plank * .3, 9.05, 2.681), (.285, 3.45, .025), 'edge', .003)
for plank in range(24):
    box('Side gallery individual floorboards', (-33.55, .15 + plank * .3, 2.681), (2.85, .285, .025), 'edge', .003)
for horizontal in (-34.5, -30.9, -27.3, -23.7, -20.1, -16.5, -13.8):
    box('Gallery supporting column', (horizontal, 7.52, 1.25), (.22, .26, 2.5), 'oak', solid=True)
    rod('Diagonal gallery bracket', (horizontal, 7.52, 1.65), (horizontal, 8.3, 2.35), .09, 'oak', 6)
for horizontal in (-34.5, -30.9, -27.3, -23.7, -20.1, -17.2):
    box('Gallery balustrade newel', (horizontal, 7.4, 3.17), (.16, .16, 1), 'oak', solid=True)
for index in range(43):
    horizontal = -34.3 + index * .4
    rod('Gallery turned baluster', (horizontal, 7.4, 2.75), (horizontal, 7.4, 3.45), .035, 'brass', 8)
box('Gallery handrail', (-25.8, 7.4, 3.58), (17.7, .2, .12), 'edge', solid=True)
for depth in (0, 2.4, 4.8, 7.2):
    box('West gallery post', (-32.08, depth, 1.27), (.2, .2, 2.54), 'oak', solid=True)
    box('West gallery rail post', (-32.08, depth, 3.17), (.15, .15, 1), 'oak', solid=True)
for index in range(18):
    rod('West gallery baluster', (-32.08, index * .4, 2.75), (-32.08, index * .4, 3.47), .035, 'brass', 8)
box('West gallery handrail', (-32.08, 3.5, 3.58), (.2, 7.3, .12), 'edge', solid=True)
for step in range(14):
    height = (step + 1) * 2.67 / 14
    depth = 1.55 + step * .41
    box('Open oak stair tread', (-15.15, depth, height - .065), (1.85, .435, .13), 'edge')
    box('Stair riser', (-15.15, depth + .17, height - .13), (1.75, .09, .25), 'oak')
for side in (-1, 1):
    horizontal = -15.15 + side * .88
    rod('Stair stringer', (horizontal, 1.28, .02), (horizontal, 7.02, 2.62), .095, 'oak', 6)
    rod('Stair continuous handrail', (horizontal, 1.28, .95), (horizontal, 7.02, 3.55), .055, 'edge', 10)
    for step in (0, 4, 8, 13):
        height, depth = (step + 1) * 2.67 / 14, 1.55 + step * .41
        rod('Stair spindle', (horizontal, depth, height), (horizontal, depth, height + .85), .032, 'brass', 8)

for depth in (2.1, 5.15):
    west_bookcase(depth, 0, 2.6, 3)
for depth in (1.5, 4.6):
    west_bookcase(depth, 2.7, 2.8, 3)
    box('West gallery cabinet backing', (-34.7, depth, 3.72), (.2, 2.96, 2.23), 'panel')
for horizontal in (-26.9, -21.7):
    table(horizontal, 2.35, 1.55, 4.25)
    for side in (-1, 1):
        bench(horizontal + side * 1.15, 2.35, 3.45)
    for depth in (.85, 3.85):
        open_book((horizontal, depth, 1.15), .8)
        lamp((horizontal, depth + .7, 1.15))
        rod('Ink pot', (horizontal + .54, depth + .15, 1.15), (horizontal + .54, depth + .15, 1.28), .075, 'navy', 12)
        rod('Quill', (horizontal + .54, depth + .15, 1.25), (horizontal + .62, depth + .22, 1.54), .012, 'pages', 6)

table(-30.8, -1.5, 3.1, 1.15)
for drawer in range(6):
    for row in range(2):
        box('Card catalogue drawer', (-32.03 + drawer * .49, -2.11, .42 + row * .31), (.45, .08, .27), 'panel')
        box('Drawer index plate', (-32.03 + drawer * .49, -2.16, .45 + row * .31), (.19, .02, .07), 'brass', .004)
        rod('Drawer pull', (-32.08 + drawer * .49, -2.19, .39 + row * .31), (-31.98 + drawer * .49, -2.19, .39 + row * .31), .015)
open_book((-30.8, -1.5, 1.16), .75)
lamp((-31.85, -1.4, 1.16))
for index in range(4):
    box('Returned folio', (-29.8, -1.48, 1.21 + index * .105), (.52, .7, .09), ('forest', 'burgundy', 'ochre', 'navy')[index], .012, .07 * index)

table(-29.9, 5.85, 1.45, 1.15)
box('Bookbinding press bed', (-29.9, 5.85, 1.2), (.95, .66, .14), 'oak')
box('Pressed folio pages', (-29.9, 5.85, 1.38), (.62, .48, .22), 'pages', .012)
box('Book press platen', (-29.9, 5.85, 1.56), (.87, .6, .13), 'edge')
for side in (-1, 1):
    rod('Book press screw', (-29.9 + side * .49, 5.85, 1.18), (-29.9 + side * .49, 5.85, 1.98), .035, 'iron')
    rod('Book press handle', (-29.9 + side * .49, 5.68, 1.92), (-29.9 + side * .49, 6.02, 1.92), .025, 'edge')
for index in range(3):
    box('Unbound paper sheets', (-29.95, 5.36, 1.15 + index * .012), (.58, .28, .005), 'paper', 0, .06 * index)
rod('Linen binding thread', (-30.46, 5.85, 1.15), (-30.46, 5.85, 1.42), .065, 'pages', 16)
for height in (1.17, 1.4):
    rod('Thread spool flange', (-30.46, 5.85, height), (-30.46, 5.85, height + .025), .09, 'edge', 16)

for depth in (2.45, 6.4):
    box('Recessed window frame', (-12.98, depth, 2.88), (.16, 1.6, 2.35), 'oak')
    box('Blue library window glass', (-13.075, depth, 2.88), (.035, 1.39, 2.11), 'sea', .008)
    for side in (-1, 1):
        box('Window vertical mullion', (-13.11, depth + side * .69, 2.88), (.055, .05, 2.2), 'brass', .006)
    box('Window center mullion', (-13.11, depth, 2.88), (.055, .04, 2.2), 'brass', .006)
    for height in (1.81, 2.88, 3.95):
        box('Window cross mullion', (-13.11, depth, height), (.055, 1.44, .05), 'brass', .006)
    for level in range(4):
        height = 1.82 + level * .53
        for side in (-1, 1):
            rod('Diamond leaded glass', (-13.13, depth + side * .68, height), (-13.13, depth, height + .53), .012, 'brass', 6)
            rod('Diamond leaded glass', (-13.13, depth, height), (-13.13, depth + side * .68, height + .53), .012, 'brass', 6)
    box('Deep library window sill', (-13.18, depth, 1.66), (.55, 1.85, .16), 'edge')

box('Atlas exhibit pedestal', (-18.25, -1.45, .18), (1.65, 1.65, .36), 'oak', .05, solid=True)
rod('Globe stand', (-18.25, -1.45, .3), (-18.25, -1.45, 1.02), .16, 'edge', 16)
bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=.71, location=(-18.25, -1.45, 1.73))
globe = bpy.context.object
globe.name = 'Celestial atlas globe'
globe.data.materials.append(MATERIALS['sea'])
for polygon in globe.data.polygons:
    polygon.use_smooth = True
    center = polygon.center.normalized()
    if math.sin(center.x * 8 + center.z * 4) + math.cos(center.y * 10 - center.z * 7) > .62:
        if len(globe.data.materials) == 1:
            globe.data.materials.append(MATERIALS['land'])
        polygon.material_index = 1
ring('Globe brass meridian', (-18.25, -1.45, 1.73), .83, .035, tilt=math.pi / 2)
ring('Globe horizon ring', (-18.25, -1.45, 1.73), .87, .028)
for angle in range(0, 360, 30):
    radians = math.radians(angle)
    rod('Globe degree marker', (-18.25 + .84 * math.cos(radians), -1.45 + .84 * math.sin(radians), 1.77), (-18.25 + .91 * math.cos(radians), -1.45 + .91 * math.sin(radians), 1.77), .01)

for horizontal in (-29.2, -23.3, -17.4):
    rod('Bookcase ladder track', (horizontal - 1.3, 10.05, 5.3), (horizontal + 1.3, 10.05, 5.3), .04)
for side in (-1, 1):
    rod('Rolling ladder stile', (-24.6 + side * .34, 8.8, 2.74), (-24.6 + side * .34, 10.03, 5.38), .045, 'edge')
for rung in range(9):
    ratio = rung / 9
    rod('Rolling ladder rung', (-24.94, 8.8 + ratio * 1.23, 2.94 + ratio * 2.5), (-24.26, 8.8 + ratio * 1.23, 2.94 + ratio * 2.5), .035, 'edge')

for key, batch in GEOMETRY.items():
    mesh = bpy.data.meshes.new(batch['name'])
    mesh.from_pydata(batch['vertices'], [], batch['faces'])
    mesh.update()
    obj = bpy.data.objects.new(f'Library_{key[0]}_{key[1]}_{key[2]}_{key[3]}', mesh)
    bpy.context.collection.objects.link(obj)
    mesh.materials.append(MATERIALS[key[2]])
    if key[3]:
        modifier = obj.modifiers.new('Crafted softened edges', 'BEVEL')
        modifier.width = key[3]
        modifier.segments = 2
        modifier.affect = 'EDGES'
        normal = obj.modifiers.new('Weighted face normals', 'WEIGHTED_NORMAL')

for index, (name, center, size, yaw) in enumerate(COLLISIONS):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center, rotation=(0, 0, yaw))
    obj = bpy.context.object
    obj.name = f'LibraryProxy{index:03}-colonly'
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

stair_mesh = bpy.data.meshes.new('Continuous stair walking surface')
stair_mesh.from_pydata([
    (-16.075, 1.2, -.13), (-14.225, 1.2, -.13), (-14.225, 7.3, 2.52), (-16.075, 7.3, 2.52),
    (-16.075, 1.2, .05), (-14.225, 1.2, .05), (-14.225, 7.3, 2.7), (-16.075, 7.3, 2.7),
], [], [(0,3,2,1), (4,5,6,7), (0,1,5,4), (1,2,6,5), (2,3,7,6), (3,0,4,7)])
stair_proxy = bpy.data.objects.new('LibraryStairRamp-colonly', stair_mesh)
bpy.context.collection.objects.link(stair_proxy)

OUTPUT.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(OUTPUT / 'reading_gallery.glb'), export_format='GLB', export_apply=True, export_animations=False, export_cameras=False, export_lights=False)
print('LIBRARY_EXPORT', len(GEOMETRY), 'batches', len(COLLISIONS), 'colliders')
