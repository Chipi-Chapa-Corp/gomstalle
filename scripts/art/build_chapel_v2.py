import math
from pathlib import Path

import bpy
from mathutils import Vector


OUTPUT = Path(__file__).resolve().parents[2] / 'assets' / 'castle' / 'chapel_v2'
PALETTE = {
    'Basalt': '252b38',
    'Slate': '354052',
    'SlateLight': '505d6b',
    'Limestone': '8b8d87',
    'Alabaster': 'c4b9a5',
    'Ivory': 'e3d4b1',
    'Shadow': '151a25',
    'Oak': '372620',
    'Walnut': '644332',
    'Velvet': '58283d',
    'VelvetEdge': 'a05762',
    'Bronze': 'ab7840',
    'Gold': 'e0b362',
    'Iron': '262d33',
    'Wax': 'd5b67a',
    'AmberGlass': 'e9a74c',
    'Flame': 'ffaf53',
    'Halo': 'ffcc78',
    'TealGlass': '235c69',
}
BEVELS = {
    'Basalt': .018,
    'Slate': .012,
    'SlateLight': .012,
    'Limestone': .025,
    'Alabaster': .018,
    'Ivory': .01,
    'Oak': .02,
    'Walnut': .016,
    'Velvet': .008,
}
EMISSIONS = {'Flame': 6.0, 'AmberGlass': 1.6, 'Halo': 2.4}
METALS = {'Bronze': .72, 'Gold': .78, 'Iron': .55}
BATCHES = {}
COLLISIONS = []
MATERIALS = {}


def linear(channel):
    value = int(channel, 16) / 255
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4


def to_blender(point):
    return (point[0], -point[2], point[1])


def material(name, color):
    result = bpy.data.materials.new('Chapel ' + name)
    rgba = tuple(linear(color[index:index + 2]) for index in (0, 2, 4)) + (1,)
    result.diffuse_color = rgba
    result.use_nodes = True
    shader = result.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = rgba
    shader.inputs['Metallic'].default_value = METALS.get(name, 0)
    shader.inputs['Roughness'].default_value = .32 if name in METALS else .73
    if name in EMISSIONS:
        shader.inputs['Emission Color'].default_value = rgba
        shader.inputs['Emission Strength'].default_value = EMISSIONS[name]
    return result


def geometry(name, points, faces, surface):
    bucket = BATCHES.setdefault(surface, {'points': [], 'faces': [], 'names': set()})
    offset = len(bucket['points'])
    bucket['points'].extend(to_blender(point) for point in points)
    bucket['faces'].extend(tuple(vertex + offset for vertex in face) for face in faces)
    bucket['names'].add(name)


def box(name, center, size, surface, yaw=0):
    cosine, sine = math.cos(yaw), math.sin(yaw)
    points = []
    for side_x, side_y, side_z in ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1), (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)):
        local_x, local_z = side_x * size[0] / 2, side_z * size[2] / 2
        points.append((center[0] + local_x * cosine - local_z * sine, center[1] + side_y * size[1] / 2, center[2] + local_x * sine + local_z * cosine))
    geometry(name, points, ((3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)), surface)


def rod(name, start, end, radius, surface, sides=8):
    direction = Vector(end) - Vector(start)
    basis = direction.to_track_quat('Z', 'Y').to_matrix()
    points = []
    for endpoint in (Vector(start), Vector(end)):
        for index in range(sides):
            angle = index * math.tau / sides
            points.append(tuple(endpoint + basis @ Vector((radius * math.cos(angle), radius * math.sin(angle), 0))))
    faces = [tuple(reversed(range(sides))), tuple(range(sides, 2 * sides))]
    faces.extend((index, (index + 1) % sides, (index + 1) % sides + sides, index + sides) for index in range(sides))
    geometry(name, points, faces, surface)


def cylinder(name, center, radius, height, surface, sides=16):
    points = []
    for elevation in (-height / 2, height / 2):
        for index in range(sides):
            angle = math.tau * index / sides
            points.append((center[0] + radius * math.cos(angle), center[1] + elevation, center[2] + radius * math.sin(angle)))
    faces = [tuple(reversed(range(sides))), tuple(range(sides, 2 * sides))]
    faces.extend((index, (index + 1) % sides, (index + 1) % sides + sides, index + sides) for index in range(sides))
    geometry(name, points, faces, surface)


def ring(name, center, radius_x, radius_y, surface, plane='xy', thickness=.045, segments=48, sides=6):
    points = []
    for index in range(segments):
        angle = math.tau * index / segments
        cosine, sine = math.cos(angle), math.sin(angle)
        for side in range(sides):
            tube = math.tau * side / sides
            width = math.cos(tube) * thickness
            depth = math.sin(tube) * thickness
            if plane == 'xy':
                points.append((center[0] + (radius_x + width) * cosine, center[1] + (radius_y + width) * sine, center[2] + depth))
            elif plane == 'yz':
                points.append((center[0] + depth, center[1] + (radius_x + width) * cosine, center[2] + (radius_y + width) * sine))
            else:
                points.append((center[0] + (radius_x + width) * cosine, center[1] + depth, center[2] + (radius_y + width) * sine))
    faces = []
    for index in range(segments):
        following = (index + 1) % segments
        for side in range(sides):
            next_side = (side + 1) % sides
            faces.append((index * sides + side, following * sides + side, following * sides + next_side, index * sides + next_side))
    geometry(name, points, faces, surface)


def silhouette(name, outline, depth, thickness, surface):
    points = [(horizontal, height, depth - thickness / 2) for horizontal, height in outline]
    points.extend((horizontal, height, depth + thickness / 2) for horizontal, height in outline)
    count = len(outline)
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    faces.extend((index, (index + 1) % count, (index + 1) % count + count, index + count) for index in range(count))
    geometry(name, points, faces, surface)


def collider(name, center, size):
    COLLISIONS.append((name, center, size))


def candle(center, height, width=.075):
    cylinder('Cast bronze candle cup', (center[0], center[1] - .015, center[2]), width * 1.8, .035, 'Bronze', 12)
    cylinder('Hand poured beeswax', (center[0], center[1] + height / 2, center[2]), width, height, 'Wax', 12)
    rod('Wax tear', (center[0] + width * .73, center[1] + height * .42, center[2]), (center[0] + width * .83, center[1] + height * .86, center[2]), width * .13, 'Ivory', 6)
    flame = (center[0], center[1] + height + .08, center[2])
    silhouette('Tapered candle flame', ((flame[0] - .048, flame[1] - .06), (flame[0] - .026, flame[1] + .03), (flame[0] + .015, flame[1] + .16), (flame[0] + .052, flame[1] - .008), (flame[0] + .032, flame[1] - .06)), flame[2], .065, 'Flame')


def arch(name, horizontal, depth, base_height, width, apex, surface, radius=.11):
    steps = 15
    left = []
    right = []
    for index in range(steps + 1):
        fraction = index / steps
        rise = (apex - base_height) * (1 - (1 - fraction) ** 1.5)
        left.append((horizontal - width / 2 + width / 2 * fraction, base_height + rise, depth))
        right.append((horizontal + width / 2 - width / 2 * fraction, base_height + rise, depth))
    for path in (left, right):
        for start, end in zip(path, path[1:]):
            rod(name, start, end, radius, surface, 8)


def side_arch(name, horizontal, depth, base_height, width, apex, surface, radius=.06):
    for side in (-1, 1):
        previous = None
        for index in range(16):
            fraction = index / 15
            rise = (apex - base_height) * (1 - (1 - fraction) ** 1.5)
            point = (horizontal, base_height + rise, depth + side * width / 2 * (1 - fraction))
            if previous is not None:
                rod(name, previous, point, radius, surface, 8)
            previous = point


def floor():
    box('Deep blue chapel stone', (0, .017, 38), (23.25, .06, 11.3), 'Basalt')
    for row in range(8):
        depth = 32.75 + row * 1.49
        for column in range(15):
            horizontal = min(11.15, -11.0 + column * 1.58 + (row % 2) * .26)
            surface = 'SlateLight' if (row * 7 + column * 3) % 13 == 0 else 'Slate'
            box('Honed stone chapel paver', (horizontal, .068, depth), (1.49, .04, 1.43), surface)
    for horizontal in (-7.35, -4.65):
        box('Processional runner bronze piping', (horizontal, .123, 38), (.035, .016, 11.5), 'Gold')
    box('Last watch processional runner', (-6, .125, 38), (2.63, .025, 11.5), 'Velvet')
    for depth in (33.3, 35.8, 38.3, 40.8, 43.2):
        ring('Runner embroidered eight-point vigil seal', (-6, .144, depth), .47, .47, 'Bronze', 'xz', .015, 32, 5)
        for spoke in range(8):
            angle = math.tau * spoke / 8
            rod('Runner vigil star stitch', (-6 + .12 * math.cos(angle), .146, depth + .12 * math.sin(angle)), (-6 + .43 * math.cos(angle), .146, depth + .43 * math.sin(angle)), .011, 'Gold', 6)
    for depth in (36.5, 39.0, 41.5):
        box('Altar approach limestone seam', (3.5, .112, depth), (7.8, .017, .045), 'Alabaster')
    for horizontal in (-.15, 7.15):
        box('Altar approach bronze edge', (horizontal, .113, 39.15), (.045, .017, 7.65), 'Bronze')
    for radius in (1.15, 1.32):
        ring('Chapel vigil compass', (3.5, .132, 39.1), radius, radius, 'Gold', 'xz', .018, 64, 5)
    for index in range(12):
        angle = index * math.tau / 12
        rod('Vigil compass ray', (3.5 + .48 * math.cos(angle), .135, 39.1 + .48 * math.sin(angle)), (3.5 + 1.03 * math.cos(angle), .135, 39.1 + 1.03 * math.sin(angle)), .015, 'Bronze', 6)


def canopy():
    for depth in (33.18, 35.52):
        for horizontal in (.04, 6.96):
            box('Ciborium black plinth', (horizontal, .28, depth), (.70, .56, .70), 'Basalt')
            cylinder('Ciborium alabaster column', (horizontal, 2.75, depth), .24, 4.7, 'Limestone', 16)
            for index in range(8):
                angle = math.tau * index / 8
                rod('Fluted ciborium shaft', (horizontal + .25 * math.cos(angle), .75, depth + .25 * math.sin(angle)), (horizontal + .25 * math.cos(angle), 4.88, depth + .25 * math.sin(angle)), .022, 'Alabaster', 6)
            cylinder('Ciborium bronze collar', (horizontal, 5.12, depth), .38, .18, 'Bronze', 16)
            box('Ciborium carved capital', (horizontal, 5.23, depth), (.78, .20, .78), 'Alabaster')
            collider('Chapel canopy pillar', (horizontal, 2.64, depth), (.78, 5.28, .78))
        arch('Ciborium pointed limestone arch', 3.5, depth, 5.33, 6.92, 6.9, 'Alabaster', .15)
        arch('Ciborium gilt inner arch', 3.5, depth + .105, 5.33, 6.46, 6.7, 'Gold', .047)
        box('Ciborium roof iron tie', (3.5, 5.22, depth), (6.95, .13, .13), 'Iron')
    for horizontal in (.04, 6.96):
        for elevation in (5.14, 5.96):
            rod('Longitudinal canopy rib', (horizontal, elevation, 33.18), (horizontal, elevation, 35.52), .085, 'Iron', 8)
    for depth in (33.55, 34.35, 35.15):
        for horizontal in (.92, 6.08):
            rod('Ciborium vaulted diagonal', (horizontal, 5.39, depth), (3.5, 6.87, depth), .06, 'Bronze', 8)
        ring('Canopy openwork celestial crown', (3.5, 6.87, depth), .23, .23, 'Gold', 'xy', .024, 20, 6)
    for side in (-1, 1):
        for index in range(7):
            depth = 33.55 + index * .27
            rod('Ciborium gothic side tracery', (3.5 + side * 3.0, 5.39, depth), (3.5 + side * 2.2, 6.59, depth), .03, 'Gold', 6)


def altar():
    box('Altar lower black marble dais', (3.5, .16, 34.28), (6.0, .32, 2.72), 'Basalt')
    box('Altar upper alabaster step', (3.5, .36, 34.0), (5.35, .12, 2.04), 'Limestone')
    for horizontal in (1.0, 2.06, 4.94, 6.0):
        box('Altar bronze riser tooth', (horizontal, .18, 35.65), (.54, .19, .055), 'Bronze')
    box('Altar carved stone chest', (3.5, .93, 33.98), (4.58, 1.13, 1.10), 'Alabaster')
    box('Altar dark recess front', (3.5, .95, 34.548), (3.85, .72, .038), 'Shadow')
    box('Altar white marble mensa', (3.5, 1.57, 34.0), (5.12, .20, 1.43), 'Ivory')
    box('Altar mensa bronze lip', (3.5, 1.455, 34.74), (5.18, .045, .075), 'Bronze')
    box('Vigil banner oxblood field', (3.5, 1.00, 34.585), (1.44, .80, .03), 'Velvet')
    box('Vigil banner stitched border', (3.5, 1.00, 34.608), (1.32, .68, .012), 'VelvetEdge')
    box('Vigil banner inner field', (3.5, 1.00, 34.621), (1.20, .57, .012), 'Velvet')
    silhouette('Embroidered vigil flame', ((3.5, .82), (3.35, 1.00), (3.46, .98), (3.55, 1.22), (3.65, 1.02)), 34.64, .018, 'Gold')
    for horizontal in (1.35, 1.77, 5.23, 5.65):
        candle((horizontal, 1.68, 33.75), .38 + .08 * (horizontal % 1))
    box('Altar open ledger walnut binding', (3.5, 1.69, 34.14), (1.06, .06, .52), 'Walnut', .05)
    for side in (-1, 1):
        box('Altar hand lettered memorial page', (3.5 + side * .255, 1.735, 34.14), (.48, .016, .46), 'Ivory', side * .06)
        for line in range(4):
            box('Ledger illuminated line', (3.5 + side * .255, 1.748, 33.98 + line * .075), (.28, .003, .009), 'Bronze')
    collider('Chapel altar and dais', (3.5, .78, 34.28), (6.0, 1.56, 2.72))


def icon():
    box('Icon sanctuary stone backing', (3.5, 4.02, 32.82), (4.82, 4.74, .20), 'Basalt')
    silhouette('Icon pointed carved surround', ((.98, 1.7), (.98, 5.23), (1.52, 5.98), (3.5, 6.45), (5.48, 5.98), (6.02, 5.23), (6.02, 1.7)), 33.00, .14, 'Alabaster')
    silhouette('Icon black recessed lancet', ((1.28, 1.92), (1.28, 5.10), (1.75, 5.78), (3.5, 6.17), (5.25, 5.78), (5.72, 5.10), (5.72, 1.92)), 33.11, .045, 'Shadow')
    silhouette('Icon blue enamel field', ((1.53, 2.13), (1.53, 4.98), (1.94, 5.54), (3.5, 5.91), (5.06, 5.54), (5.47, 4.98), (5.47, 2.13)), 33.18, .035, 'TealGlass')
    for horizontal in (1.72, 5.28):
        for height in (2.5, 3.4, 4.3, 5.05):
            rod('Icon leaf stem', (horizontal, height - .26, 33.24), (horizontal, height + .26, 33.24), .022, 'Gold', 6)
            for side in (-1, 1):
                rod('Icon hammered gold leaf', (horizontal, height, 33.24), (horizontal + side * .32, height + .20, 33.24), .024, 'Halo', 6)
    ring('Icon large gilt mandorla', (3.5, 4.08, 33.29), 1.33, 1.55, 'Halo', 'xy', .075, 64, 8)
    ring('Icon enamel inner mandorla', (3.5, 4.08, 33.31), 1.18, 1.4, 'Gold', 'xy', .032, 64, 6)
    for index in range(16):
        angle = math.tau * index / 16
        start = (3.5 + 1.44 * math.cos(angle), 4.08 + 1.66 * math.sin(angle), 33.30)
        end = (3.5 + 1.77 * math.cos(angle), 4.08 + 1.93 * math.sin(angle), 33.30)
        rod('Icon hammered bronze sun ray', start, end, .035 if index % 2 == 0 else .018, 'Halo', 6)
    silhouette('Icon ivory candle', ((3.12, 2.83), (3.88, 2.83), (3.82, 4.14), (3.18, 4.14)), 33.38, .055, 'Ivory')
    silhouette('Icon luminous sacred flame', ((3.5, 3.94), (3.14, 4.35), (3.27, 4.82), (3.49, 5.36), (3.84, 4.86), (3.89, 4.43), (3.71, 4.14)), 33.45, .07, 'AmberGlass')
    silhouette('Icon flame central heart', ((3.5, 4.17), (3.35, 4.43), (3.52, 4.95), (3.68, 4.40)), 33.52, .055, 'Flame')
    for horizontal in (2.53, 4.47):
        rod('Icon descending teardrop', (horizontal, 3.21, 33.35), (horizontal, 2.67, 33.35), .037, 'Halo', 8)
        ring('Icon small bronze star', (horizontal, 2.57, 33.35), .11, .11, 'Gold', 'xy', .028, 8, 6)


def memorial_wall():
    for depth, index in ((34.3, 0), (37.35, 1), (40.4, 2)):
        box('Wall of names stone slab', (-11.25, 2.37, depth), (.22, 3.54, 2.53), 'Limestone')
        box('Wall of names inset basalt', (-11.095, 2.35, depth), (.045, 3.10, 2.18), 'Basalt')
        for rail in (-.92, .92):
            box('Wall of names gilt upright', (-11.059, 2.31, depth + rail), (.023, 2.96, .04), 'Bronze')
        for line in range(8):
            line_depth = depth - .73 + (line % 3) * .73
            elevation = 1.15 + line * .30
            box('Cut bronze memorial name', (-11.055, elevation, line_depth), (.022, .025, .43 if (line + index) % 3 else .33), 'Gold')
        ring('Memorial tablet octagonal seal', (-11.03, 3.74, depth), .23, .23, 'Gold', 'yz', .03, 8, 6)
        rod('Tablet seal descending mark', (-11.0, 3.9, depth), (-11.0, 3.57, depth), .028, 'Gold', 6)
    box('Votive table dark stone base', (-10.06, .27, 38.0), (1.26, .54, 8.5), 'Basalt')
    box('Votive table polished bronze rail', (-10.06, .60, 38.0), (1.36, .12, 8.65), 'Bronze')
    for depth in (34.55, 35.15, 35.82, 36.55, 37.24, 37.89, 38.59, 39.28, 39.95, 40.62, 41.35):
        for horizontal in (-10.42, -9.88):
            candle((horizontal, .68, depth), .25 + .07 * ((int(depth * 10) + int(horizontal * 10)) % 3), .063)
    collider('Chapel votive memorial table', (-10.06, .37, 38.0), (1.36, .74, 8.65))


def side_altar():
    box('Private prayer seat walnut', (9.25, .57, 39.65), (1.04, .18, 2.38), 'Walnut')
    box('Private prayer seat high back', (9.65, 1.12, 39.65), (.17, 1.2, 2.38), 'Oak')
    box('Private prayer seat crimson cushion', (9.15, .72, 39.65), (.77, .10, 1.95), 'Velvet')
    for depth in (38.48, 40.82):
        box('Private prayer seat carved cheek', (9.2, .61, depth), (1.2, 1.22, .16), 'Oak')
        ring('Seat carved devotional roundel', (8.83, .96, depth - .096), .13, .13, 'Gold', 'xy', .023, 16, 6)
    box('Private prayer kneeler oak frame', (7.83, .24, 39.65), (.78, .32, 2.05), 'Oak')
    box('Private prayer kneeler worn velvet', (7.83, .43, 39.65), (.7, .12, 1.86), 'Velvet')
    collider('Chapel private prayer station', (8.65, .62, 39.65), (2.4, 1.24, 2.55))
    box('East wall teal glass niche', (11.33, 2.94, 40.0), (.12, 3.38, 2.9), 'TealGlass')
    for depth in (38.52, 41.48):
        box('East wall limestone jamb', (11.22, 2.94, depth), (.29, 3.77, .23), 'Limestone')
    for depth in (39.02, 40.0, 40.98):
        box('East wall stained glass mullion', (11.18, 2.88, depth), (.05, 3.21, .045), 'Gold')
    for height in (1.93, 2.98, 4.03):
        box('East wall stained glass crossbar', (11.18, height, 40.0), (.05, .045, 2.75), 'Gold')
        for depth in (39.5, 40.5):
            rod('East wall glass diamond lead', (11.13, height - .48, depth), (11.13, height, depth + .48), .017, 'Alabaster', 6)
            rod('East wall glass diamond lead', (11.13, height, depth + .48), (11.13, height + .48, depth), .017, 'Alabaster', 6)
    side_arch('East wall pointed enamel niche', 11.18, 40.0, 4.75, 2.9, 5.32, 'Gold')


def hanging_lamps():
    for horizontal, depth, height in ((-.55, 37.18, 4.52), (7.55, 37.28, 4.67), (3.5, 41.82, 5.42)):
        rod('Suspended bronze sanctuary chain', (horizontal, 7.88, depth), (horizontal, height + .35, depth), .021, 'Iron', 7)
        ring('Hanging sanctuary lamp crown', (horizontal, height + .19, depth), .33, .33, 'Bronze', 'xz', .045, 24, 6)
        for index in range(4):
            angle = math.tau * index / 4
            rod('Lamp forged basket', (horizontal + .30 * math.cos(angle), height + .19, depth + .30 * math.sin(angle)), (horizontal + .14 * math.cos(angle), height - .45, depth + .14 * math.sin(angle)), .024, 'Bronze', 6)
        cylinder('Suspended amber lamp glass', (horizontal, height - .15, depth), .22, .52, 'AmberGlass', 12)
        cylinder('Hanging sanctuary lamp point', (horizontal, height - .49, depth), .12, .15, 'Bronze', 12)
        ring('Lamp hammered gilt waist', (horizontal, height - .10, depth), .24, .24, 'Gold', 'xz', .023, 24, 6)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for name, color in PALETTE.items():
        MATERIALS[name] = material(name, color)
    floor()
    canopy()
    altar()
    icon()
    memorial_wall()
    side_altar()
    hanging_lamps()
    for surface, batch in BATCHES.items():
        mesh = bpy.data.meshes.new('ChapelV2 ' + surface)
        mesh.from_pydata(batch['points'], [], batch['faces'])
        mesh.update()
        object_data = bpy.data.objects.new('ChapelV2_' + surface, mesh)
        bpy.context.collection.objects.link(object_data)
        mesh.materials.append(MATERIALS[surface])
        if surface in BEVELS:
            modifier = object_data.modifiers.new('Cut and softened stonework', 'BEVEL')
            modifier.width = BEVELS[surface]
            modifier.segments = 2
            modifier.limit_method = 'ANGLE'
            normal = object_data.modifiers.new('Weighted face normals', 'WEIGHTED_NORMAL')
            normal.keep_sharp = True
    for index, (name, center, size) in enumerate(COLLISIONS):
        bpy.ops.mesh.primitive_cube_add(size=1, location=to_blender(center))
        object_data = bpy.context.object
        object_data.name = f'ChapelV2Proxy{index:02d}-{name.replace(" ", "")}-colonly'
        object_data.dimensions = (size[0], size[2], size[1])
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    bpy.context.scene.unit_settings.system = 'METRIC'
    OUTPUT.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / 'candle_chapel.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / 'candle_chapel.glb'), export_format='GLB', export_apply=True, export_animations=False, export_cameras=False, export_lights=False, export_yup=True)
    for depth in range(32, 45):
        for name, center, size in COLLISIONS:
            if abs(-6 - center[0]) < size[0] / 2 + .55 and abs(depth - center[2]) < size[2] / 2 + .55:
                raise AssertionError(f'Route x=-6 z={depth} blocked by {name}')
    vertices = [(point[0], point[2], -point[1]) for batch in BATCHES.values() for point in batch['points']]
    minimum = tuple(round(min(point[axis] for point in vertices), 3) for axis in range(3))
    maximum = tuple(round(max(point[axis] for point in vertices), 3) for axis in range(3))
    print('CHAPEL_V2_EXPORT', OUTPUT / 'candle_chapel.glb')
    print('CHAPEL_V2_BATCHES', len(BATCHES))
    print('CHAPEL_V2_COLLIDERS', len(COLLISIONS))
    print('CHAPEL_V2_VERTICES', sum(len(batch['points']) for batch in BATCHES.values()))
    print('CHAPEL_V2_BOUNDS', minimum, maximum)
    print('CHAPEL_V2_ROUTE', 'x=-6 z=32..44 clear at 0.55m radius')


build()
