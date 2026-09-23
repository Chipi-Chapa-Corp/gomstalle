import math
from pathlib import Path

import bpy
from mathutils import Vector


OUTPUT = Path(__file__).resolve().parents[2] / 'assets' / 'castle' / 'grand_hall_v2'
PALETTE = {
    'midnight': ('273241', 0), 'slate': ('3d4755', 0), 'limestone': ('8e8a82', 0),
    'ivory': ('c1b59d', 0), 'chalk': ('dfd3b4', 0), 'shadow': ('202630', 0),
    'oak': ('49342b', 0), 'walnut': ('674936', 0), 'honey': ('947054', 0),
    'oxblood': ('6c2c3e', 0), 'red_light': ('954457', 0), 'navy': ('35485c', 0),
    'teal': ('397069', 0), 'gold': ('c69d57', .78), 'old_gold': ('916c39', .65),
    'iron': ('252b30', .75), 'silver': ('aab5b7', .72), 'parchment': ('e0cba2', 0),
    'wax': ('f2d8a3', 0), 'fire': ('ffc279', 0), 'glass': ('466c80', .15),
}
MATERIALS = {}
GEOMETRY = {}
COLLISIONS = []


def linear(channel):
    value = int(channel, 16) / 255
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4


def initialize():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for name, (color, metallic) in PALETTE.items():
        material = bpy.data.materials.new('Grand Hall ' + name)
        rgba = tuple(linear(color[index:index + 2]) for index in (0, 2, 4)) + (1,)
        material.diffuse_color = rgba
        material.use_nodes = True
        shader = material.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = rgba
        shader.inputs['Metallic'].default_value = metallic
        shader.inputs['Roughness'].default_value = .36 if metallic else .76
        if name == 'fire':
            shader.inputs['Emission Color'].default_value = rgba
            shader.inputs['Emission Strength'].default_value = 3
        MATERIALS[name] = material


def geometry(name, vertices, faces, material, bevel=0):
    vertices = [(vertex[0], -vertex[1], vertex[2]) for vertex in vertices]
    faces = [tuple(reversed(face)) for face in faces]
    center = sum((Vector(vertex) for vertex in vertices), Vector()) / len(vertices)
    key = (int(center.x // 8), int(center.y // 8), material, bevel)
    batch = GEOMETRY.setdefault(key, {'vertices': [], 'faces': [], 'name': name})
    offset = len(batch['vertices'])
    batch['vertices'].extend(vertices)
    batch['faces'].extend(tuple(index + offset for index in face) for face in faces)


def box(name, center, size, material, bevel=.015, yaw=0, solid=False):
    vertices = []
    for horizontal, depth, height in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1),
                                      (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)):
        local_x, local_y = horizontal * size[0] / 2, depth * size[1] / 2
        vertices.append((center[0] + local_x * math.cos(yaw) - local_y * math.sin(yaw),
                         center[1] + local_x * math.sin(yaw) + local_y * math.cos(yaw),
                         center[2] + height * size[2] / 2))
    geometry(name, vertices, [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5),
                              (2, 3, 7, 6), (3, 0, 4, 7)], material, bevel)
    if solid:
        COLLISIONS.append((name, center, size, yaw))


def rod(name, start, end, radius, material, sides=8):
    direction = Vector(end) - Vector(start)
    basis = direction.to_track_quat('Z', 'Y').to_matrix()
    vertices = [tuple(Vector(endpoint) + basis @ Vector((radius * math.cos(index * math.tau / sides),
                                                          radius * math.sin(index * math.tau / sides), 0)))
                for endpoint in (start, end) for index in range(sides)]
    faces = [tuple(reversed(range(sides))), tuple(range(sides, sides * 2))]
    faces.extend((index, (index + 1) % sides, (index + 1) % sides + sides, index + sides)
                 for index in range(sides))
    geometry(name, vertices, faces, material)


def ring(name, center, radius, thickness, material, plane='floor', segments=48):
    def position(angle):
        if plane == 'floor':
            return (center[0] + radius * math.cos(angle), center[1] + radius * math.sin(angle), center[2])
        return (center[0] + radius * math.cos(angle), center[1], center[2] + radius * math.sin(angle))
    for index in range(segments):
        rod(name, position(index * math.tau / segments), position((index + 1) * math.tau / segments),
            thickness, material, 6)


def ellipse(name, center, radius_x, radius_y, thickness, material, segments=32):
    for index in range(segments):
        angle_a = index * math.tau / segments
        angle_b = (index + 1) * math.tau / segments
        rod(name, (center[0] + radius_x * math.cos(angle_a), center[1] + radius_y * math.sin(angle_a), center[2]),
            (center[0] + radius_x * math.cos(angle_b), center[1] + radius_y * math.sin(angle_b), center[2]),
            thickness, material, 6)


def disc(name, center, radius, material, segments=24):
    vertices = [center]
    vertices.extend((center[0] + radius * math.cos(index * math.tau / segments),
                     center[1] + radius * math.sin(index * math.tau / segments), center[2])
                    for index in range(segments))
    geometry(name, vertices, [(0, index + 1, (index + 1) % segments + 1) for index in range(segments)], material)


def floor_inlay():
    box('Nave marble field brass perimeter', (15.55, 59.35, .025),
        (14.7, 16.8, .035), 'old_gold', .025)
    box('Nave marble field dark foundation', (15.55, 59.35, .045),
        (14.35, 16.45, .024), 'midnight', .018)
    for column in range(9):
        for row in range(10):
            px = 9.35 + column * 1.55
            py = 52.35 + row * 1.55
            if math.hypot(px - 15.55, py - 54.8) < 4.5:
                continue
            material = 'slate' if (column + row) % 4 else 'midnight'
            box('Nave individually inlaid dark marble paver', (px, py, .063),
                (1.52, 1.52, .013), material, .006)
    for side in (-1, 1):
        box('Nave gilded inner longitudinal seam',
            (15.55 + side * 6.92, 59.35, .075), (.04, 16.2, .008), 'gold', 0)
    for depth in (46.0, 51.7, 54.4, 62.5, 66.4):
        box('Court transverse limestone band', (11.8, depth, .026), (45.3, .18, .012), 'limestone', 0)
        box('Court transverse gold fillet', (11.8, depth + .15, .031), (45.3, .035, .01), 'old_gold', 0)
    for horizontal in (-10.6, -1.6, 10.4, 20.7, 34.1):
        box('Longitudinal court inlaid rule', (horizontal, 56.1, .028), (.055, 21, .012), 'old_gold', 0)
    box('Procession runner border', (15.55, 62.05, .083), (4.75, 11.1, .028), 'gold', .018)
    box('Procession runner', (15.55, 62.05, .099), (4.43, 10.8, .025), 'oxblood', .022)
    for side in (-1, 1):
        box('Runner embroidered inner stripe', (15.55 + side * 1.92, 62.05, .116), (.05, 10.4, .008), 'chalk', 0)
        box('Runner midnight selvedge', (15.55 + side * 2.13, 62.05, .116), (.045, 10.55, .008), 'navy', 0)
    for depth in (57.9, 60.4, 62.9, 65.4):
        for side in (-1, 1):
            x = 15.55 + side * 1.64
            for offset in (-.25, .25):
                rod('Runner repeated embroidered laurel', (x, depth + offset - .22, .119),
                    (x + side * .24, depth + offset, .119), .016, 'gold', 6)
                rod('Runner repeated embroidered laurel', (x + side * .24, depth + offset, .119),
                    (x, depth + offset + .22, .119), .016, 'gold', 6)
    for horizontal, color in ((2, 'oxblood'), (27.75, 'navy')):
        box('Court approach carpet gilded border', (horizontal, 58.25, .051),
            (3.1, 6.3, .025), 'gold', .012)
        box('Court approach carpet woven field', (horizontal, 58.25, .065),
            (2.88, 6.08, .02), color, .012)
        for side in (-1, 1):
            box('Court approach embroidered keyline',
                (horizontal + side * 1.19, 58.25, .079),
                (.045, 5.75, .006), 'chalk', 0)
        for depth in (56.5, 58.25, 60):
            sun_emblem((horizontal, depth, .079), .21, 'floor')
    disc('Ceremonial compass dark roundel', (15.55, 54.8, .083), 4.12, 'midnight', 64)
    ring('Compass outer bronze circlet', (15.55, 54.8, .094), 3.98, .06, 'gold', segments=64)
    ring('Compass inner stone circlet', (15.55, 54.8, .099), 3.33, .075, 'ivory', segments=64)
    ring('Compass central brass circlet', (15.55, 54.8, .104), 1.15, .04, 'gold')
    for ray in range(16):
        angle = ray * math.tau / 16
        length = 3.05 if ray % 2 == 0 else 2.2
        width = .24 if ray % 2 == 0 else .13
        tangent = Vector((-math.sin(angle), math.cos(angle), 0))
        inward = Vector((15.55 + math.cos(angle) * .82, 54.8 + math.sin(angle) * .82, .106))
        outward = Vector((15.55 + math.cos(angle) * length, 54.8 + math.sin(angle) * length, .106))
        vertices = [tuple(inward - tangent * width), tuple(outward), tuple(inward + tangent * width)]
        geometry('Inlaid radiating star points', vertices, [(0, 1, 2)], 'gold' if ray % 2 == 0 else 'ivory')
    disc('Compass heart', (15.55, 54.8, .114), .73, 'oxblood')
    ring('Compass heart rim', (15.55, 54.8, .119), .75, .035, 'chalk')
    for side in (-1, 1):
        for depth in (48.4, 51.0, 53.8, 61.4, 65.1):
            disc('Gold court floor rivet', (15.55 + side * 8.9, depth, .04), .085, 'old_gold', 12)


def court(center, width, depth, name):
    x, y = center
    box(name + ' continuous dressed stone base', (x, y, 1.06), (width, depth, 2.12), 'slate', .04)
    COLLISIONS.append((name + ' walking surface', (x, y, 1.1), (width, depth, 2.2), 0))
    for column in range(round(width * 2)):
        for row in range(round(depth * 2)):
            px = x - width / 2 + (column + .5) * .5
            py = y - depth / 2 + (row + .5) * .5
            material = 'limestone' if (column + row) % 7 < 2 else 'ivory'
            box(name + ' fitted stone paving', (px, py, 2.182), (.488, .488, .035), material, .005)
    for horizontal in (-1, 1):
        box(name + ' side gilded coping', (x + horizontal * (width / 2 - .09), y, 2.22),
            (.09, depth, .085), 'old_gold', .01)
    box(name + ' rear carved coping', (x, y - depth / 2 + .08, 2.22), (width, .11, .09), 'gold', .01)
    for column in range(round(width)):
        px = x - width / 2 + column + .5
        box(name + ' front recessed panel', (px, y + depth / 2 + .025, 1.15),
            (.86, .055, 1.55), 'midnight', .04)
        box(name + ' front raised limestone molding', (px, y + depth / 2 + .061, 1.15),
            (.7, .02, 1.36), 'limestone', .04)
        disc(name + ' front gilded rosette', (px, y + depth / 2 + .079, 1.15), .09, 'gold', 12)


def stair(name, bottom, width, run, height, direction, carpet):
    dx, dy = direction
    for step in range(11):
        along = (step + .5) * run / 11
        x, y = bottom[0] + dx * along, bottom[1] + dy * along
        elevation = (step + 1) * height / 11
        size = (width, run / 11, elevation) if dx == 0 else (run / 11, width, elevation)
        box(name + ' hewn stair tread', (x, y, elevation / 2), size, 'limestone', .012)
        surface = (width - .18, run / 11 - .025, .023) if dx == 0 else (run / 11 - .025, width - .18, .023)
        box(name + ' polished landing edge', (x, y, elevation + .014), surface, 'ivory', .005)
        if carpet:
            fabric = (width * .62, run / 11 - .025, .018) if dx == 0 else (run / 11 - .025, width * .62, .018)
            box(name + ' stair procession carpet', (x, y, elevation + .034), fabric, 'oxblood', .006)
    perpendicular = (-dy, dx)
    vertices = []
    for side in (-1, 1):
        for distance, elevation in ((0, 0), (run, 0), (run, height)):
            vertices.append((bottom[0] + perpendicular[0] * side * width / 2 + dx * distance,
                             bottom[1] + perpendicular[1] * side * width / 2 + dy * distance,
                             elevation))
    COLLISIONS.append((name + ' smooth ramp', vertices,
                       [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (0, 3, 5, 2)]))
    for side in (-1, 1):
        offset = side * (width / 2 + .11)
        for fraction in (0, .36, .72, 1):
            x = bottom[0] + perpendicular[0] * offset + dx * run * fraction
            y = bottom[1] + perpendicular[1] * offset + dy * run * fraction
            rod(name + ' turned brass baluster', (x, y, height * fraction + .13),
                (x, y, height * fraction + .78), .046, 'old_gold', 8)
        rod(name + ' oak rising handrail',
            (bottom[0] + perpendicular[0] * offset, bottom[1] + perpendicular[1] * offset, .82),
            (bottom[0] + perpendicular[0] * offset + dx * run,
             bottom[1] + perpendicular[1] * offset + dy * run, height + .82), .069, 'walnut', 10)


def pointed_arch(name, left, right, depth, base, crown, material, thickness=.1):
    middle = (left + right) / 2
    previous = (left, depth, base)
    for index in range(1, 17):
        ratio = index / 16
        x = left + (middle - left) * ratio
        z = base + (crown - base) * math.sin(ratio * math.pi / 2)
        following = (x, depth, z)
        rod(name, previous, following, thickness, material, 8)
        previous = following
    for index in range(1, 17):
        ratio = index / 16
        x = middle + (right - middle) * ratio
        z = base + (crown - base) * math.cos(ratio * math.pi / 2)
        following = (x, depth, z)
        rod(name, previous, following, thickness, material, 8)
        previous = following


def sun_emblem(center, radius, plane='wall'):
    ring('Royal sun engraved aureole', center, radius, .045, 'gold', plane)
    if plane == 'wall':
        disc_center = (center[0], center[1] + .02, center[2])
        for ray in range(16):
            angle = ray * math.tau / 16
            rod('Royal gilded sun ray',
                (center[0] + math.cos(angle) * radius * 1.12, center[1] + .025,
                 center[2] + math.sin(angle) * radius * 1.12),
                (center[0] + math.cos(angle) * radius * 1.55, center[1] + .025,
                 center[2] + math.sin(angle) * radius * 1.55), .032, 'gold', 6)
        for ring_radius in (.2, .38):
            ring('Royal sun inner enamel', disc_center, ring_radius, .04, 'gold', 'wall')
    else:
        disc('Royal sun enamel', center, radius * .58, 'gold')


def throne():
    for x in (.15, 6.85):
        box('Royal canopy carved front pillar', (x, 46.55, 4.12), (.26, .3, 3.9), 'walnut', .05)
        box('Royal canopy square gilded capital', (x, 46.55, 5.92), (.42, .44, .22), 'gold', .025)
        rod('Royal canopy spear finial', (x, 46.55, 6.04), (x, 46.55, 6.48), .08, 'old_gold')
    box('Royal canopy coffered roof', (3.5, 47.35, 6.09), (7.45, 2.4, .28), 'walnut', .08)
    for x in (1, 2.25, 3.5, 4.75, 6):
        box('Canopy gold leaf ceiling lozenge', (x, 47.35, 5.94), (.48, 1.15, .018), 'old_gold', .005)
    box('Royal canopy carved cornice', (3.5, 48.55, 5.9), (7.5, .29, .34), 'honey', .06)
    box('Royal canopy gold cornice', (3.5, 48.74, 5.91), (7.2, .055, .11), 'gold', .009)
    for x in (1.2, 5.8):
        box('Royal velvet canopy hanging', (x, 48.55, 4.86), (1.45, .07, 1.55), 'oxblood', .03)
        for strand in (-.45, 0, .45):
            rod('Canopy hanging gold embroidery', (x + strand, 48.6, 4.2),
                (x + strand, 48.6, 5.47), .025, 'gold', 6)
        for tassel in range(5):
            rod('Canopy gold tassels', (x - .58 + tassel * .29, 48.59, 4.18),
                (x - .58 + tassel * .29, 48.59, 3.97), .022, 'gold', 6)
    box('Throne carved wing back', (3.5, 47.02, 3.78), (2.5, .35, 3.1), 'oak', .12, solid=True)
    box('Throne oxblood upholstery', (3.5, 47.25, 3.72), (1.86, .08, 2.3), 'oxblood', .07)
    box('Throne seat cushion', (3.5, 48.05, 2.83), (2.13, 1.65, .28), 'red_light', .11)
    for x in (2.25, 4.75):
        box('Throne lion arm', (x, 48.07, 3.08), (.38, 1.55, .36), 'walnut', .12, solid=True)
        box('Throne carved claw', (x, 48.72, 2.57), (.5, .46, .64), 'oak', .1)
        for toe in (-.12, 0, .12):
            rod('Gilded lion claw', (x + toe, 48.95, 2.32), (x + toe, 49.07, 2.3), .035, 'gold', 8)
    box('Throne raised back crest', (3.5, 47.06, 5.51), (3.1, .42, .28), 'honey', .1)
    sun_emblem((3.5, 47.31, 4.4), .42)
    box('Royal footstool', (3.5, 49.35, 2.4), (1.85, .78, .4), 'walnut', .07)
    box('Footstool embroidered cushion', (3.5, 49.35, 2.63), (1.7, .68, .1), 'oxblood', .06)
    for x in (-3.5, 10.2):
        box('Audience wall heraldic tapestry', (x, 44.74, 4.35), (2.7, .09, 3.2), 'oxblood', .04)
        box('Heraldic tapestry golden hem', (x, 44.83, 2.77), (2.85, .025, .16), 'gold', .015)
        for side in (-1, 1):
            rod('Heraldic sunburst branch', (x, 44.82, 3.8),
                (x + side * .93, 44.82, 5.2), .04, 'gold', 8)
        sun_emblem((x, 44.82, 4.45), .3)


def organ():
    box('Minstrels carved organ plinth', (28, 46.68, 2.49), (5.1, 1.1, .56), 'walnut', .07,
        solid=True)
    box('Organ key desk', (28, 47.6, 3.16), (3.5, 1.1, .22), 'honey', .05, solid=True)
    box('Organ carved pipe case', (28, 46.13, 4.37), (5.15, .72, 3.7), 'oak', .12, solid=True)
    box('Organ velvet pipe recess', (28, 46.57, 4.56), (4.75, .035, 3.2), 'midnight', .005)
    for index in range(21):
        x = 25.75 + index * .225
        profile = 1.15 + 1.7 * (1 - abs(index - 10) / 10)
        rod('Polished organ flue pipe', (x, 46.72, 3.47), (x, 46.72, 3.47 + profile), .078,
            'silver', 12)
        box('Organ pipe black speaking lip', (x, 46.812, 3.72), (.105, .02, .095), 'shadow', .006)
        rod('Organ gilded pipe lip', (x - .07, 46.83, 3.75), (x + .07, 46.83, 3.75),
            .013, 'gold', 6)
    for key in range(29):
        x = 26.36 + key * .116
        box('Organ ivory manual key', (x, 47.59, 3.29), (.107, .57, .045), 'chalk', .005)
        if key % 7 in (1, 2, 4, 5, 6):
            box('Organ ebony chromatic key', (x + .047, 47.43, 3.33), (.052, .31, .04),
                'shadow', .002)
    box('Organ pipe arcade crown', (28, 46.62, 6.21), (5.44, .91, .25), 'honey', .06)
    pointed_arch('Organ carved pointed upper arch', 25.44, 30.56, 46.82, 6.15, 7.05,
                 'gold', .085)
    for side in (-1, 1):
        x = 28 + side * 2.73
        rod('Organ spire', (x, 46.62, 5.96), (x, 46.62, 6.9), .085, 'gold')
        disc('Organ carved stop seal', (x - side * .32, 47.18, 3.35), .12, 'old_gold', 12)
    box('Organ oak performance stool', (28, 48.6, 2.55), (1.7, .55, .55), 'oak', .08,
        solid=True)
    for x in (25.15, 30.75):
        box('Minstrel sound chamber tapestry', (x, 44.74, 4.2), (1.0, .09, 2.8), 'navy', .02)
        for height in (3.45, 4.2, 4.95):
            rod('Tapestry woven music stave', (x - .35, 44.81, height),
                (x + .35, 44.81, height), .018, 'gold', 6)
        for horizontal in (-.22, .14):
            disc('Tapestry golden musical note', (x + horizontal, 44.84, 3.9 + horizontal),
                 .075, 'gold', 12)


def harp():
    x, y = 25.3, 48.1
    rod('Harp carved resonator foot', (x, y, 2.3), (x + .75, y, 2.3), .13, 'walnut')
    rod('Harp tall gilt pillar', (x, y, 2.3), (x, y, 4.95), .12, 'gold', 12)
    for index in range(13):
        ratio = index / 12
        sx = x + .78 * ratio
        sz = 4.95 - .42 * ratio - .35 * math.sin(math.pi * ratio)
        if index:
            rod('Harp curved carved neck', previous, (sx, y, sz), .11, 'walnut', 10)
        previous = (sx, y, sz)
    rod('Harp resonating soundboard', (x + .78, y, 4.53), (x + .75, y, 2.3), .16,
        'honey', 12)
    for string in range(12):
        fraction = (string + 1) / 13
        rod('Harp individual silver string', (x + .78 * fraction, y, 4.95 - .42 * fraction - .35 * math.sin(math.pi * fraction)),
            (x + .77, y, 2.35 + fraction * 1.9), .008, 'silver', 6)
    COLLISIONS.append(('Minstrel harp', (25.68, 48.1, 3.4), (1.08, .42, 2.3), 0))


def hall_architecture():
    for x in (11.35, 20.0):
        for depth in (50.2,):
            box('Nave pier limestone core', (x, depth, 2.25), (.78, .78, 4.5), 'slate', .06,
                solid=True)
            box('Nave pier cut stone foot', (x, depth, .33), (1.15, 1.15, .66), 'ivory', .035)
            box('Nave pier carved capital', (x, depth, 4.48), (1.18, 1.18, .32),
                'ivory', .08)
            for side in (-1, 1):
                box('Pier gold inset fluting', (x + side * .19, depth + .404, 2.44),
                    (.05, .013, 3.1), 'old_gold', .006)
            for height in (1.08, 3.78):
                box('Pier recessed ashlar joint', (x, depth + .405, height),
                    (.57, .02, .025), 'limestone', 0)
    for depth in (50.2,):
        pointed_arch('Monumental nave ivory rib', 11.35, 20.0, depth, 4.42, 7.25,
                     'ivory', .16)
        pointed_arch('Monumental nave gilded inner molding', 11.55, 19.8, depth + .08,
                     4.43, 7.02, 'gold', .045)
        box('Nave high carved keystone', (15.67, depth, 7.14), (.5, .56, .45),
            'gold', .08)
        for side in (-1, 1):
            x = 15.67 + side * 3.38
            box('Arch springing engraved square', (x, depth + .49, 4.45),
                (.4, .035, .34), 'gold', .01)
    for x, depth in ((-9.5, 47.0), (-2.0, 47.0), (11.9, 45.0), (18.9, 45.0),
                     (23.3, 45.0), (33.4, 45.0)):
        if x == 11.9 or x == 18.9:
            continue
        box('North wall fitted dark oak dado', (x, depth, 1.11),
            (2.65, .13, 2.05), 'oak', .055)
        for offset in (-.73, .73):
            box('North wall raised panel molding', (x + offset, depth + .083, 1.12),
                (.84, .035, 1.62), 'honey', .025)
        box('North wall gilded dado cap', (x, depth + .1, 2.15),
            (2.75, .07, .08), 'gold', .012)
    for x in (-8.8, -4.7, 2.1, 6.8, 23.6, 33.2):
        box('Court heraldic wall pier', (x, 44.78, 4.16), (.46, .45, 4.2),
            'limestone', .06)
        box('Court pier gilded capital', (x, 44.83, 6.21), (.7, .58, .21),
            'gold', .025)
    for x, start, end in ((3.5, -.5, 7.5), (28, 24.2, 31.8)):
        pointed_arch('Court monumental wall archivolt', start, end, 44.94, 5.85, 7.2,
                     'ivory', .11)
        pointed_arch('Court inner brass archivolt', start + .24, end - .24, 45.06,
                     5.82, 6.93, 'old_gold', .04)
    for x in (-10.6, 35.2):
        for depth in (55.7, 62.3):
            box('Side wall heraldic niche', (x, depth, 3.7), (.17, 2.55, 2.6),
                'midnight', .06)
            box('Side wall tapestry', (x + (.12 if x < 0 else -.12), depth, 3.72),
                (.035, 2.04, 2.13), 'oxblood' if x < 0 else 'navy', .025)
            for offset in (-.75, .75):
                box('Side wall tapestry woven border',
                    (x + (.15 if x < 0 else -.15), depth + offset, 3.72),
                    (.02, .055, 2.04), 'gold', .004)
            for dot in range(4):
                disc('Heraldic wall badge', (x + (.17 if x < 0 else -.17),
                                            depth - .6 + dot * .4, 4.15), .09, 'gold', 12)


def chandelier():
    center = (15.67, 54.8, 7.13)
    ring('Great ceremonial old gold wheel', center, 1.72, .073, 'old_gold', segments=48)
    ring('Chandelier gilded inner wheel', center, 1.08, .045, 'gold', segments=40)
    disc('Chandelier pierced heraldic boss', (center[0], center[1], center[2] + .03),
         .31, 'old_gold')
    for index in range(8):
        angle = index * math.tau / 8
        inner = (center[0] + math.cos(angle) * .31, center[1] + math.sin(angle) * .31, center[2])
        outer = (center[0] + math.cos(angle) * 1.72, center[1] + math.sin(angle) * 1.72, center[2])
        rod('Chandelier eight slender brass spokes', inner, outer, .032, 'gold', 8)
        rod('Chandelier candle support', outer, (outer[0], outer[1], 7.4), .044,
            'old_gold', 8)
        rod('Chandelier ivory candle', (outer[0], outer[1], 7.4),
            (outer[0], outer[1], 7.68), .052, 'wax', 8)
        rod('Chandelier warm flame', (outer[0], outer[1], 7.68),
            (outer[0], outer[1], 7.83), .038, 'fire', 8)
        if index % 2 == 0:
            rod('Chandelier four suspension chains', outer,
                (center[0] + math.cos(angle) * .45,
                 center[1] + math.sin(angle) * .45, 8.35),
                .023, 'old_gold', 6)
    rod('Chandelier main suspension', (center[0], center[1], 7.13),
        (center[0], center[1], 8.8), .064, 'iron')


def carved_bench(x, depth, width, facing):
    box('Court spectators aged oak pew', (x, depth, .62), (width, .68, .19), 'walnut',
        .05, solid=True)
    box('Pew oxblood quilted cushion', (x, depth, .73), (width - .35, .58, .09),
        'oxblood', .03)
    box('Court spectators carved pew back', (x, depth - facing * .34, 1.16),
        (width, .2, 1.2), 'oak', .07, solid=True)
    for offset in range(1, round(width)):
        px = x - width / 2 + offset * width / round(width)
        box('Pew back raised Gothic panel', (px, depth - facing * .34 + facing * .112, 1.16),
            (.35, .035, .8), 'honey', .03)
    for side in (-1, 1):
        xx = x + side * (width / 2 - .16)
        box('Pew carved end standard', (xx, depth, .65), (.27, .86, 1.24),
            'oak', .055)
        rod('Pew finial', (xx, depth - facing * .3, 1.26),
            (xx, depth - facing * .3, 1.5), .08, 'gold', 8)


def council_table():
    x, y = 27.0, 64.4
    for plank in range(8):
        px = x - 4.05 + (plank + .5) * 8.1 / 8
        box('Council oak planked table top', (px, y, 1.13),
            (1.0, 1.8, .19), 'walnut' if plank % 3 else 'honey', .025)
    box('Council table oxblood damask runner', (x, y, 1.244), (7.3, .71, .028),
        'oxblood', .008)
    for side in (-1, 1):
        xx = x + side * 3.45
        box('Council table trestle pier', (xx, y, .56), (.38, 1.52, 1.11),
            'oak', .045, solid=True)
        box('Council table trestle foot', (xx, y, .15), (.64, 2.0, .23),
            'walnut', .04)
    box('Council table oak stretcher', (x, y, .46), (7.1, .2, .2), 'oak', .035)
    for index, xx in enumerate((23.5, 27.0, 30.5)):
        box('Council assigned parchment', (xx, 64.35, 1.265), (.96, .66, .025),
            'parchment', .014, yaw=(index - 1) * .09)
        for line in range(5):
            box('Council handwritten decree', (xx, 64.12 + line * .087, 1.282),
                (.66 - line % 3 * .08, .009, .003), 'midnight', 0)
        disc('Council red wax seal', (xx + .34, 64.56, 1.29), .08, 'oxblood', 12)
    for xx in (22.95, 31.05):
        disc('Council candlestick foot', (xx, 64.4, 1.3), .16, 'gold', 16)
        rod('Council silver candlestick', (xx, 64.4, 1.3),
            (xx, 64.4, 1.74), .038, 'silver')
        rod('Council wax taper', (xx, 64.4, 1.74),
            (xx, 64.4, 1.95), .05, 'wax')
        rod('Council candle flame', (xx, 64.4, 1.95),
            (xx, 64.4, 2.1), .035, 'fire')
    for xx in (24.4, 27, 29.6):
        for sign in (-1, 1):
            box('Council matching carved chair seat', (xx, y + sign * 1.6, .54),
                (.68, .62, .16), 'walnut', .045, solid=True)
            box('Council chair upholstered seat', (xx, y + sign * 1.6, .64),
                (.56, .53, .07), 'navy', .028)
            box('Council carved chair back', (xx, y + sign * 1.94, 1.17),
                (.69, .16, 1.22), 'oak', .05, solid=True)
            box('Council chair back inset', (xx, y + sign * 1.84, 1.19),
                (.45, .035, .7), 'navy', .04)
            for side in (-1, 1):
                box('Council chair turned leg', (xx + side * .25, y + sign * 1.6,
                                                  .26), (.11, .11, .52), 'oak', .025)


def audience_gallery():
    for depth in (62.0, 64.9):
        carved_bench(-6.7, depth, 5.5, -1)
    box('Audience oath lectern foot', (-4.4, 59.65, .16), (1.13, .88, .32),
        'slate', .055, solid=True)
    rod('Audience oath lectern column', (-4.4, 59.65, .32),
        (-4.4, 59.65, 1.18), .14, 'walnut', 12)
    box('Audience oath parchment rest', (-4.4, 59.65, 1.2), (1.25, .85, .12),
        'honey', .04)
    box('Audience illuminated proclamation', (-4.4, 59.65, 1.274),
        (.96, .63, .022), 'parchment', .01)
    for line in range(5):
        box('Illuminated proclamation lettering', (-4.4, 59.45 + line * .086, 1.289),
            (.61, .009, .003), 'midnight', 0)
    disc('Proclamation royal wax seal', (-4.08, 59.86, 1.295), .075, 'oxblood', 12)


def build():
    initialize()
    floor_inlay()
    court((3.5, 48.5), 9, 5, 'Royal audience dais')
    stair('Audience front ascent', (2, 55), 4, 4, 2.2, (0, -1), True)
    stair('Audience side ascent', (10.8, 48), 3, 2.8, 2.2, (-1, 0), False)
    court((28, 48.5), 6, 5, 'Minstrels performance dais')
    stair('Minstrel front ascent', (27.75, 55), 3.5, 4, 2.2, (0, -1), True)
    stair('Minstrel side ascent', (34.5, 48.5), 3, 3.5, 2.2, (-1, 0), False)
    hall_architecture()
    throne()
    organ()
    harp()
    chandelier()
    audience_gallery()
    council_table()
    for key, batch in GEOMETRY.items():
        mesh = bpy.data.meshes.new(batch['name'])
        mesh.from_pydata(batch['vertices'], [], batch['faces'])
        mesh.update()
        obj = bpy.data.objects.new(f'GrandHall_{key[0]}_{key[1]}_{key[2]}_{key[3]}', mesh)
        bpy.context.collection.objects.link(obj)
        mesh.materials.append(MATERIALS[key[2]])
        if key[3]:
            modifier = obj.modifiers.new('Softened carved edges', 'BEVEL')
            modifier.width = key[3]
            modifier.segments = 2
            normal = obj.modifiers.new('Weighted plane normals', 'WEIGHTED_NORMAL')
    for index, collision in enumerate(COLLISIONS):
        if len(collision) == 4:
            name, center, size, yaw = collision
            bpy.ops.mesh.primitive_cube_add(size=1, location=(center[0], -center[1], center[2]),
                                            rotation=(0, 0, -yaw))
            obj = bpy.context.object
            obj.name = f'GrandHallSolid{index:03}-colonly'
            obj.dimensions = size
            bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        else:
            name, vertices, faces = collision
            mesh = bpy.data.meshes.new(name)
            mesh.from_pydata([(vertex[0], -vertex[1], vertex[2]) for vertex in vertices], [], faces)
            obj = bpy.data.objects.new(f'GrandHallRamp{index:03}-colonly', mesh)
            bpy.context.collection.objects.link(obj)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / 'grand_hall_v2.blend'))
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / 'grand_hall_v2.glb'), export_format='GLB',
                              export_apply=True, export_animations=False,
                              export_cameras=False, export_lights=False)
    triangles = sum(sum(len(face) - 2 for face in batch['faces']) for batch in GEOMETRY.values())
    print('GRAND_HALL_V2_EXPORT', len(GEOMETRY), 'batches', len(COLLISIONS),
          'colliders', triangles, 'source triangles')


if __name__ == '__main__':
    build()
