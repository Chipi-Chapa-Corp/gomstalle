import bpy
import math
from pathlib import Path
from mathutils import Vector

OUTPUT = Path(__file__).resolve().parents[2] / 'assets' / 'castle' / 'banquet_v2'
PALETTE = {
    'black_oak': ('241b1c', 0, .79),
    'oak': ('493028', 0, .7),
    'carved_oak': ('76513a', 0, .68),
    'gold_oak': ('9a7249', 0, .64),
    'aged_brass': ('ab8653', .78, .35),
    'bright_brass': ('d4b16e', .8, .27),
    'iron': ('293039', .72, .51),
    'pewter': ('8999a1', .77, .4),
    'velvet': ('67273b', 0, .9),
    'velvet_light': ('9d4154', 0, .84),
    'linen': ('d8c9aa', 0, .87),
    'parchment': ('e6d9b9', 0, .89),
    'shadow_blue': ('263e4a', 0, .69),
    'sea_glass': ('477c82', .16, .34),
    'spectral': ('65dbc9', 0, .48),
    'wax': ('e8d5a6', 0, .76),
    'flame': ('ffb663', 0, .35),
    'wine': ('4c142b', 0, .34),
    'roast': ('9b4c2d', 0, .62),
    'fruit': ('8a5830', 0, .56),
    'leaf': ('466044', 0, .7),
    'stone': ('665d60', 0, .89),
    'stone_light': ('91817b', 0, .85),
}
GEOMETRY = {}
COLLISIONS = []
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)


def linear(channel):
    value = int(channel, 16) / 255
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4


MATERIALS = {}
for name, (color, metallic, roughness) in PALETTE.items():
    material = bpy.data.materials.new('Banquet ' + name)
    material.diffuse_color = tuple(linear(color[index:index + 2]) for index in (0, 2, 4)) + (1,)
    material.use_nodes = True
    shader = material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = material.diffuse_color
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    if name in ('flame', 'spectral'):
        shader.inputs['Emission Color'].default_value = material.diffuse_color
        shader.inputs['Emission Strength'].default_value = 2.8 if name == 'flame' else 1.7
    MATERIALS[name] = material


def mesh(name, vertices, faces, material):
    center = sum((Vector(vertex) for vertex in vertices), Vector()) / len(vertices)
    key = (int(center.x // 7), int(center.y // 7), material)
    batch = GEOMETRY.setdefault(key, {'name': name, 'vertices': [], 'faces': []})
    offset = len(batch['vertices'])
    batch['vertices'].extend(vertices)
    batch['faces'].extend(tuple(vertex + offset for vertex in face) for face in faces)


def box(name, center, size, material='oak', yaw=0):
    cosine, sine = math.cos(yaw), math.sin(yaw)
    vertices = []
    for side_x, side_y, side_z in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)):
        x, y = side_x * size[0] * .5, side_y * size[1] * .5
        vertices.append((center[0] + x * cosine - y * sine, center[1] + x * sine + y * cosine, center[2] + side_z * size[2] * .5))
    mesh(name, vertices, ((3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)), material)


def drooping_board(name, center, size, material, pitch):
    cosine, sine = math.cos(pitch), math.sin(pitch)
    vertices = []
    for side_x, side_y, side_z in ((-1, -1, -1), (1, -1, -1), (1, 1, -1), (-1, 1, -1), (-1, -1, 1), (1, -1, 1), (1, 1, 1), (-1, 1, 1)):
        x, y, z = side_x * size[0] * .5, side_y * size[1] * .5, side_z * size[2] * .5
        vertices.append((center[0] + x, center[1] + y * cosine - z * sine, center[2] + y * sine + z * cosine))
    mesh(name, vertices, ((3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)), material)


def rod(name, start, end, radius, material='aged_brass', segments=8):
    direction = Vector(end) - Vector(start)
    basis = direction.to_track_quat('Z', 'Y').to_matrix()
    vertices = [tuple(Vector(endpoint) + basis @ Vector((radius * math.cos(index * math.tau / segments), radius * math.sin(index * math.tau / segments), 0))) for endpoint in (start, end) for index in range(segments)]
    faces = [tuple(reversed(range(segments))), tuple(range(segments, 2 * segments))]
    faces.extend((index, (index + 1) % segments, (index + 1) % segments + segments, index + segments) for index in range(segments))
    mesh(name, vertices, faces, material)


def lathe(name, center, profile, material, segments=12):
    vertices = []
    faces = []
    for radius, elevation in profile:
        for segment in range(segments):
            angle = segment * math.tau / segments
            vertices.append((center[0] + radius * math.cos(angle), center[1] + radius * math.sin(angle), center[2] + elevation))
    for ring in range(len(profile) - 1):
        for segment in range(segments):
            next_segment = (segment + 1) % segments
            faces.append((ring * segments + segment, ring * segments + next_segment, (ring + 1) * segments + next_segment, (ring + 1) * segments + segment))
    mesh(name, vertices, faces, material)


def ellipsoid(name, center, radii, material, sides=12, levels=6):
    vertices = []
    faces = []
    for level in range(levels + 1):
        latitude = -math.pi / 2 + math.pi * level / levels
        for side in range(sides):
            longitude = math.tau * side / sides
            vertices.append((center[0] + radii[0] * math.cos(latitude) * math.cos(longitude), center[1] + radii[1] * math.cos(latitude) * math.sin(longitude), center[2] + radii[2] * math.sin(latitude)))
    for level in range(levels):
        for side in range(sides):
            next_side = (side + 1) % sides
            faces.append((level * sides + side, level * sides + next_side, (level + 1) * sides + next_side, (level + 1) * sides + side))
    mesh(name, vertices, faces, material)


def arc(name, center, radius, start, stop, elevation, material, width=.045, segments=18):
    previous = (center[0] + radius * math.cos(start), center[1] + radius * math.sin(start), elevation)
    for index in range(1, segments + 1):
        angle = start + (stop - start) * index / segments
        following = (center[0] + radius * math.cos(angle), center[1] + radius * math.sin(angle), elevation)
        rod(name, previous, following, width, material, 6)
        previous = following


def clearance(name, center, size):
    COLLISIONS.append((name, center, size))


def pendant(center, height=.43, spectral=False):
    lathe('Sconce drip pan', center, ((0, 0), (.15, 0), (.18, .03), (.13, .055), (0, .05)), 'aged_brass')
    rod('Beeswax candle', (center[0], center[1], center[2] + .045), (center[0], center[1], center[2] + height), .055, 'wax', 10)
    ellipsoid('Candle tongue', (center[0], center[1], center[2] + height + .06), (.045, .04, .09), 'spectral' if spectral else 'flame', 8, 4)


def goblet(center, upright=True):
    if upright:
        lathe('Tarnished wine chalice', center, ((0, 0), (.11, 0), (.13, .025), (.035, .065), (.035, .23), (.15, .28), (.17, .43), (.135, .46), (.115, .3)), 'aged_brass')
        lathe('Ruby wine surface', (center[0], center[1], center[2] + .39), ((0, 0), (.125, 0)), 'wine')
    else:
        rod('Fallen goblet stem', center, (center[0] + .28, center[1] + .06, center[2] + .03), .03, 'aged_brass')
        lathe('Fallen goblet bowl', (center[0] + .29, center[1] + .06, center[2] + .03), ((0, 0), (.14, .02), (.17, .18)), 'aged_brass', 10)


def platter(center, radius=.35):
    lathe('Silver service plate', center, ((0, 0), (radius * .75, 0), (radius, .035), (radius * .85, .06), (radius * .71, .03), (0, .025)), 'pewter', 18)
    arc('Fine gold plate rim', (center[0], center[1]), radius * .92, 0, math.tau, center[2] + .045, 'bright_brass', .009, 24)


def crown(center, scale=1, material='bright_brass'):
    radius = .35 * scale
    for level in (0, .14):
        arc('Royal crown band', center, radius, 0, math.tau, center[2] + level * scale, material, .023 * scale, 18)
    for angle in range(0, 360, 45):
        radians = math.radians(angle)
        x = center[0] + radius * math.cos(radians)
        y = center[1] + radius * math.sin(radians)
        rod('Crown chased point', (x, y, center[2] + .12 * scale), (x, y, center[2] + .33 * scale), .021 * scale, material, 6)
        ellipsoid('Crown pearl', (x, y, center[2] + .34 * scale), (.043 * scale, .043 * scale, .055 * scale), 'spectral' if material == 'spectral' else 'linen', 8, 4)


def carved_chair(x, z, yaw=0, fallen=False):
    y = -z
    if fallen:
        box('Abandoned chair frame', (x, y, .32), (.72, .65, .13), 'carved_oak', yaw)
        box('Abandoned velvet seat', (x, y, .405), (.52, .47, .08), 'velvet', yaw)
        box('Chair back toppled aside', (x - .33, y - .27, .32), (.1, .65, 1.25), 'oak', yaw + .3)
        clearance('fallen_chair', (x, y, .28), (1.13, 1.08, .56))
        return
    box('High chair saddle seat', (x, y, .69), (.66, .64, .14), 'carved_oak', yaw)
    box('Velvet upholstered chair', (x, y, .78), (.51, .5, .09), 'velvet', yaw)
    for side in (-1, 1):
        box('Chair turned legs', (x + side * .26, y, .36), (.08, .5, .72), 'black_oak', yaw)
        rod('Chair upright', (x + side * .26, y + .27, .75), (x + side * .26, y + .27, 1.55), .062, 'black_oak', 8)
        rod('Chair arm', (x + side * .32, y - .29, 1.02), (x + side * .32, y + .28, 1.08), .045, 'gold_oak', 6)
    box('Chair high shaped back', (x, y + .3, 1.23), (.65, .09, .83), 'oak', yaw)
    box('Chair inset crest cushion', (x, y + .245, 1.2), (.46, .035, .54), 'velvet_light', yaw)
    box('Chair carved crest cap', (x, y + .3, 1.68), (.78, .13, .11), 'gold_oak', yaw)
    clearance('banquet_chair', (x, y, .85), (.72, .72, 1.7))


def table(x, z, ruined=False):
    y = -z
    for plank in range(8):
        if ruined and plank == 7:
            continue
        box('Continuous oak feast planking', (x - 3.5 + plank, y, 1.15), (.98, 2.18, .14), 'oak' if ruined else ('carved_oak' if plank % 3 else 'gold_oak'))
    if ruined:
        drooping_board('Broken banquet end', (x + 3.52, y - .34, .91), (.96, 1.32, .14), 'carved_oak', .58)
        rod('Exposed snapped table joinery', (x + 3.02, y - 1.02, .93), (x + 3.38, y - 1.35, .61), .05, 'black_oak', 6)
        rod('Exposed snapped table joinery', (x + 3.58, y - .99, .95), (x + 3.85, y - 1.3, .67), .038, 'black_oak', 6)
    for side in (-1, 1):
        foot_x = x + side * 3.14
        box('Great table trestle', (foot_x, y, .55), (.27, 1.73, 1.1), 'black_oak')
        box('Trestle foot', (foot_x, y, .11), (.42, 2.13, .2), 'oak')
        rod('Trestle diagonal carving', (foot_x, y - .77, .16), (foot_x, y + .77, .93), .055, 'gold_oak', 6)
    if ruined:
        box('Broken feast table frieze', (x - 2.12, y - 1.15, .97), (3.66, .11, .26), 'black_oak')
        drooping_board('Shattered edge rail', (x + 1.95, y - 1.16, .74), (2.65, .11, .22), 'black_oak', .46)
    else:
        box('Table side frieze', (x, y - 1.15, .97), (7.9, .11, .26), 'black_oak')
    box('Table side frieze', (x, y + 1.15, .97), (7.9, .11, .26), 'black_oak')
    if ruined:
        box('Ruptured runner remaining on table', (x - 1.4, y + .1, 1.232), (5.12, .94, .024), 'velvet')
        cloth_top = [(x + offset, y - .38, 1.24) for offset in (.15, .9, 1.8, 2.55, 3.2, 3.9)]
        cloth_hem = [(x + .28, y - 1.25, .82), (x + .98, y - 1.35, .64), (x + 1.8, y - 1.52, .22), (x + 2.55, y - 1.39, .58), (x + 3.2, y - 1.48, .3), (x + 3.76, y - 1.36, .54)]
        cloth_faces = [(index + 6, index + 7, index + 1, index) for index in range(5)]
        mesh('Torn wine velvet slipping from table', cloth_top + cloth_hem, cloth_faces + [tuple(reversed(face)) for face in cloth_faces], 'velvet_light')
        rod('Torn cloth trailing gold braid', (x + .25, y - 1.27, .82), (x + 1.8, y - 1.53, .22), .025, 'aged_brass', 6)
        rod('Torn cloth trailing gold braid', (x + 3.07, y - 1.48, .3), (x + 3.76, y - 1.36, .54), .025, 'aged_brass', 6)
    else:
        for side in (-1, 1):
            box('Hand-woven wine runner', (x, y + side * .11, 1.232), (8.02, .5, .024), 'velvet')
    for end in (-1, 1):
        if not (ruined and end == 1):
            box('Hanging runner end', (x + end * 4.025, y, .88), (.034, 1.22, .68), 'velvet')
            for index in range(9):
                box('Gold tassel fringe', (x + end * 4.045, y - .52 + index * .13, .525), (.026, .024, .11), 'bright_brass')
    clearance('banquet_table', (x, y, .62), (8.04, 2.44, 1.24))
    for index, place_x in enumerate((x - 3.03, x - 1.5, x + .05, x + 1.58, x + 3.07)):
        for side in (-1, 1):
            place_y = y + side * .8
            if ruined and ((side == -1 and index >= 1) or (side == 1 and index in (2, 4))):
                continue
            platter((place_x, place_y, 1.225), .3)
            if not (ruined and index == 2 and side == 1):
                goblet((place_x + .43, place_y + side * .13, 1.25))
            box('Linen napkin fold', (place_x - .39, place_y, 1.27), (.22, .24, .025), 'linen', .09 * (index % 3 - 1))
            rod('Silver dining knife', (place_x + .34, place_y - .19, 1.27), (place_x + .34, place_y + .13, 1.27), .012, 'pewter', 6)
    for wax_x in (x - 2.25, x + 2.18):
        for candle_y in (-.17, .17):
            pendant((wax_x, y + candle_y, 1.24), .45 if candle_y < 0 else .36, ruined and wax_x > x)
    if ruined:
        ellipsoid('Wine poured over the ruined table edge', (x + 2.12, y - .91, 1.246), (.82, .29, .009), 'wine', 16, 4)
        for spill in range(4):
            spill_x = x + 1.62 + spill * .28
            rod('Dark wine descending torn cloth', (spill_x, y - 1.28, .82), (spill_x + .08, y - 1.46, .31 + .07 * spill), .021, 'wine', 6)
        ellipsoid('Wine pooled beneath broken table', (x + 2.16, y - 1.81, .055), (1.03, .47, .013), 'wine', 18, 4)
        ellipsoid('The final royal course lies in wine', (x + 2.8, y - 1.83, .13), (.31, .18, .1), 'roast', 12, 5)
        for shard in range(5):
            box('Scattered silver from interrupted service', (x + 1.3 + shard * .29, y - 1.71 + .12 * (shard % 2), .07), (.13, .09, .013), 'pewter', .48 * shard)
        platter((x - .95, y, 1.24), .59)
        for rib in range(5):
            rod('Picked-clean royal banquet bone', (x - 1.32 + rib * .17, y - .18, 1.3), (x - 1.22 + rib * .17, y + .19, 1.31), .029, 'linen', 6)
        platter((x + .85, y, 1.24), .44)
        ellipsoid('Sundered silver reliquary', (x + .85, y, 1.39), (.25, .24, .13), 'pewter', 12, 5)
        for index in range(8):
            angle = index * math.tau / 8
            rod('Last guests ethereal trace', (x + .85 + .2 * math.cos(angle), y + .2 * math.sin(angle), 1.4), (x + .85 + .33 * math.cos(angle + .16), y + .33 * math.sin(angle + .16), 1.79 + .1 * (index % 3)), .012, 'spectral', 6)
        crown((x + .85, y, 1.98), .95, 'spectral')
        ellipsoid('Wine interrupted mid-toast', (x + 1.55, y + .62, 1.247), (.55, .23, .008), 'wine', 16, 4)
        goblet((x + 1.15, y + .64, 1.31), False)
        box('Torn summons left on table', (x - 2.75, y - .17, 1.265), (.65, .46, .008), 'parchment', .13)
        for row in range(4):
            box('Ink on summons', (x - 2.76, y - .32 + row * .075, 1.273), (.38 - row * .04, .011, .002), 'shadow_blue', .13)
        rod('Broken wax seal ribbon', (x - 2.55, y + .08, 1.27), (x - 2.46, y + .33, 1.27), .018, 'velvet_light', 6)
        for shard in range(4):
            box('Dropped plate fragments', (x + 2.6 + shard * .13, y + .33 + shard % 2 * .1, 1.278), (.11, .06, .01), 'pewter', shard * .49)
    else:
        platter((x - .95, y, 1.24), .59)
        ellipsoid('Carved roast at the feast', (x - .95, y, 1.47), (.48, .28, .2), 'roast', 14, 6)
        for rib in range(5):
            rod('Roast rib scoring', (x - 1.28 + rib * .16, y - .21, 1.61), (x - 1.2 + rib * .16, y + .16, 1.62), .016, 'fruit', 6)
        platter((x + .85, y, 1.24), .44)
        for fruit in range(7):
            ellipsoid('Forgotten fruit', (x + .55 + fruit % 3 * .19, y - .18 + fruit // 3 * .19, 1.38 + fruit // 3 * .07), (.1, .1, .1), 'fruit' if fruit % 3 else 'velvet_light', 8, 4)
        box('Intact sealed invitation', (x + 2.7, y + .12, 1.26), (.5, .36, .011), 'parchment', -.16)
        ellipsoid('Scarlet wax seal', (x + 2.7, y + .11, 1.28), (.07, .07, .014), 'velvet_light', 10, 4)


def wall_bay(x, y, inward=1, width=3.6):
    for side in (-1, 1):
        post_x = x + side * width * .5
        box('Rhythmic hall pilaster', (post_x, y + inward * .08, 2.05), (.17, .22, 3.9), 'black_oak')
        box('Carved oak capital', (post_x, y + inward * .15, 3.85), (.41, .38, .21), 'gold_oak')
        rod('Hammerbeam diagonal', (post_x, y + inward * .2, 3.26), (post_x - side * .63, y + inward * .58, 4.05), .082, 'carved_oak', 6)
    box('Deep lintel and moulding', (x, y + inward * .12, 4.05), (width + .16, .32, .18), 'black_oak')
    box('Gold lintel arris', (x, y + inward * .28, 3.97), (width - .28, .035, .028), 'aged_brass')


def antler_crest(x, y, height, material='bright_brass', scale=1):
    ellipsoid('Heraldic crowned hart', (x, y, height), (.19 * scale, .042, .26 * scale), material, 10, 4)
    for side in (-1, 1):
        joints = [(x + side * .08 * scale, height + .14 * scale), (x + side * .28 * scale, height + .39 * scale), (x + side * .63 * scale, height + .46 * scale), (x + side * .82 * scale, height + .77 * scale)]
        for start, end in zip(joints, joints[1:]):
            rod('Hart antler beam', (start[0], y, start[1]), (end[0], y, end[1]), .027 * scale, material, 6)
        for start, end in (((.28, .39), (.22, .69)), ((.63, .46), (.64, .81)), ((.82, .77), (1.05, .85))):
            rod('Hart antler tine', (x + side * start[0] * scale, y, height + start[1] * scale), (x + side * end[0] * scale, y, height + end[1] * scale), .019 * scale, material, 6)


def banner(x, z, width=2.2):
    y = -z
    rod('Royal mourning tapestry pole', (x - width * .59, y, 3.86), (x + width * .59, y, 3.86), .045, 'aged_brass')
    box('Long pointed heraldic hanging', (x, y, 2.71), (width, .04, 2.0), 'velvet')
    box('Woven narrow border', (x - width * .45, y - .03, 2.7), (.055, .025, 1.88), 'aged_brass')
    box('Woven narrow border', (x + width * .45, y - .03, 2.7), (.055, .025, 1.88), 'aged_brass')
    box('Banquet banner lower selvedge', (x, y - .03, 1.77), (width * .9, .025, .04), 'aged_brass')
    antler_crest(x, y - .044, 2.45, 'bright_brass', .72)
    for tassel in range(9):
        rod('Hanging banner bullion', (x - .94 + tassel * .23, y, 1.76), (x - .94 + tassel * .23, y, 1.59 - .05 * (tassel % 3)), .018, 'aged_brass', 6)


def gallery():
    box('Minstrels gallery cantilever', (26.7, -21.32, 2.66), (16.3, 1.55, .22), 'black_oak')
    for plank in range(28):
        box('Gallery oiled floorboards', (18.72 + plank * .59, -21.32, 2.784), (.575, 1.52, .026), 'carved_oak')
    for x in (19.1, 22.9, 26.7, 30.5, 34.3):
        box('Wall-mounted gallery corbel', (x, -20.91, 2.42), (.2, .95, .18), 'gold_oak')
        rod('Gallery diagonal bracket', (x, -20.62, 1.63), (x, -21.82, 2.73), .08, 'black_oak', 6)
        box('Gallery balustrade newel', (x, -22.13, 3.17), (.17, .17, .86), 'black_oak')
        box('Gallery newel gold finial', (x, -22.13, 3.66), (.22, .22, .13), 'bright_brass')
    box('Gallery continuous handrail', (26.7, -22.13, 3.64), (16.1, .15, .12), 'gold_oak')
    box('Gallery lower rail', (26.7, -22.13, 2.94), (16.1, .11, .08), 'carved_oak')
    for index in range(62):
        x = 18.82 + index * .255
        rod('Slender twisted gallery spindle', (x, -22.13, 2.96), (x + .035 * (index % 2 * 2 - 1), -22.13, 3.56), .025, 'aged_brass', 6)
    for harp_x in (21.0, 27.3, 32.9):
        box('Abandoned sheet music stand', (harp_x, -21.27, 3.57), (.76, .12, .57), 'black_oak', -.12)
        box('Parchment music folio', (harp_x, -21.37, 3.58), (.63, .02, .42), 'parchment', -.12)
        for stave in range(5):
            box('Music stave', (harp_x, -21.391, 3.43 + stave * .065), (.49, .005, .005), 'shadow_blue')
        rod('Music stand turned stem', (harp_x, -21.27, 2.8), (harp_x, -21.27, 3.3), .05, 'carved_oak', 8)


def wall_architecture():
    for x in (18.1, 22.0, 25.9, 29.8, 33.7, 37.6, 41.5, 45.4):
        wall_bay(x, -20.46, -1, 3.75)
    for x in (17.0, 21.0, 25.0, 29.0, 33.0, 42.4, 46.0):
        wall_bay(x, -31.43, 1, 3.6)
    for x in (16.7, 41.7, 45.0):
        banner(x, 31.24, 2.0)
    for x in (17.0, 39.4, 44.0):
        antler_crest(x, -20.78, 2.35, 'aged_brass', .78)
    for x in (17.2, 23.5, 30.0, 43.6):
        box('Wainscot oak field', (x, -31.27, .67), (2.6, .1, 1.32), 'black_oak')
        for inset in (-.77, 0, .77):
            box('Individual carved wainscot panel', (x + inset, -31.36, .67), (.65, .055, 1.06), 'carved_oak')
            box('Recessed panel center', (x + inset, -31.399, .68), (.48, .012, .78), 'oak')
    box('Stone threshold on east wall', (47.48, -26, .28), (.25, 6.5, .56), 'stone')
    for z in (22.4, 29.5):
        box('East wall velvet canopy anchor', (47.25, -z, 2.35), (.15, .46, 3.3), 'black_oak')
    gallery()


def dais():
    box('Royal mourning dais first step', (44.55, -26, .13), (5.55, 7.1, .26), 'stone')
    box('Royal mourning dais raised floor', (44.92, -26, .37), (4.8, 6.53, .24), 'stone_light')
    box('Royal wine carpet', (44.9, -26, .506), (4.53, 6.1, .03), 'velvet')
    for side in (-1, 1):
        box('Dais embroidered edging', (44.95, -26 + side * 2.94, .525), (4.43, .045, .012), 'bright_brass')
        rod('Canopy slender upright', (46.8, -26 + side * 2.67, .5), (46.8, -26 + side * 2.67, 3.88), .073, 'aged_brass', 10)
        box('Canopy parted curtain', (46.7, -26 + side * 2.4, 2.89), (.14, .67, 1.83), 'velvet')
        box('Canopy braided curtain hem', (46.62, -26 + side * 2.08, 2.17), (.033, .09, .5), 'bright_brass')
        rod('Canopy curtain tieback', (46.55, -26 + side * 2.4, 2.25), (46.55, -26 + side * 2.07, 2.29), .034, 'bright_brass')
    box('Canopy dark roof beam', (46.76, -26, 3.86), (.63, 5.82, .24), 'black_oak')
    box('Canopy gold face rail', (46.37, -26, 3.81), (.045, 5.75, .1), 'bright_brass')
    for index in range(13):
        box('Canopy hanging bullion', (46.32, -28.55 + index * .43, 3.62), (.026, .026, .34), 'aged_brass')
    box('Empty royal throne plinth', (45.6, -26, .65), (2.15, 2.15, .24), 'black_oak')
    box('Throne fitted velvet cushion', (45.6, -26, 1.03), (1.23, 1.27, .16), 'velvet_light')
    box('Throne broad carved seat', (45.65, -26, .92), (1.55, 1.56, .22), 'gold_oak')
    box('Throne towering back', (46.42, -26, 1.86), (.22, 1.79, 2.26), 'black_oak')
    box('Throne embroidered back', (46.28, -26, 1.87), (.05, 1.4, 1.68), 'velvet')
    for side in (-1, 1):
        box('Royal throne arm', (45.4, -26 + side * .77, 1.3), (1.28, .2, .18), 'carved_oak')
        rod('Throne arm gold trim', (44.83, -26 + side * .77, 1.41), (46.0, -26 + side * .77, 1.41), .027, 'bright_brass', 6)
        box('Throne side guardian post', (46.45, -26 + side * .82, 1.87), (.18, .18, 2.2), 'gold_oak')
    antler_crest(46.24, -26, 1.82, 'bright_brass', .67)
    box('Empty royal velvet cushion', (45.55, -26, 1.052), (1.04, 1.08, .028), 'velvet_light')
    for z in (23.2, 28.8):
        lathe('Lord table torch foot', (43.35, -z, .5), ((0, 0), (.17, .02), (.12, .1), (.06, .22)), 'aged_brass')
        rod('Standing banquet torch', (43.35, -z, .67), (43.35, -z, 2.15), .06, 'black_oak', 8)
        pendant((43.35, -z, 2.13), .4)
    clearance('dais_step', (44.55, -26, .13), (5.55, 7.1, .26))
    clearance('dais_floor', (44.92, -26, .37), (4.8, 6.53, .24))
    clearance('throne', (45.96, -26, 1.65), (1.62, 2.2, 2.3))


def service_niche():
    x, y = 15.6, -26.1
    box('Banquet service credenza carcass', (x, y, .68), (2.36, 1.09, 1.28), 'black_oak')
    box('Credenza carved top', (x, y, 1.34), (2.5, 1.17, .12), 'gold_oak')
    for side in (-1, 1):
        box('Credenza panel door', (x + side * .56, y - .57, .68), (.98, .07, 1.04), 'carved_oak')
        box('Credenza recessed field', (x + side * .56, y - .62, .68), (.72, .019, .78), 'oak')
        ellipsoid('Door bright brass knob', (x + side * .21, y - .645, .72), (.035, .034, .035), 'bright_brass', 8, 4)
    for index in range(4):
        platter((x - .74 + index * .5, y - .15, 1.405), .18)
    box('Scribe inventory folio', (x + .35, y + .25, 1.407), (.56, .44, .014), 'parchment', -.17)
    clearance('service_credenza', (x, y, .7), (2.5, 1.2, 1.4))


def mourning_chandelier():
    center = (30, -26)
    arc('Ancestral seal floor inlay', center, 1.03, 0, math.tau, .072, 'aged_brass', .024, 36)
    arc('Ancestral seal ghost circle', center, .59, 0, math.tau, .073, 'spectral', .008, 28)
    for angle in range(0, 360, 45):
        radians = math.radians(angle)
        direction = (math.cos(radians), math.sin(radians))
        rod('Eight-point remembrance star', (30 + .62 * direction[0], -26 + .62 * direction[1], .073), (30 + .99 * direction[0], -26 + .99 * direction[1], .073), .012, 'bright_brass', 6)
    rod('Hanging iron spine', (30, -26, 4.15), (30, -26, 3.34), .065, 'iron', 10)
    for elevation, radius in ((2.55, 1.13), (3.14, .77)):
        arc('Suspended stag-wheel hoop', center, radius, 0, math.tau, elevation, 'iron', .042, 30)
        arc('Spectral inner hoop chasing', center, radius - .055, 0, math.tau, elevation + .012, 'spectral', .011, 30)
    for angle in range(0, 360, 45):
        radians = math.radians(angle)
        x, y = 30 + 1.13 * math.cos(radians), -26 + 1.13 * math.sin(radians)
        high_x, high_y = 30 + .77 * math.cos(radians), -26 + .77 * math.sin(radians)
        rod('Stag-wheel eight hanging ribs', (x, y, 2.55), (high_x, high_y, 3.14), .032, 'aged_brass', 6)
        pendant((x, y, 2.57), .31, True)
    antler_crest(30, -26, 2.53, 'linen', 1.18)
    for side in (-1, 1):
        ellipsoid('Unquiet hart eye', (30 + side * .11, -26.07, 2.54), (.044, .027, .038), 'spectral', 8, 4)
    for angle in (45, 135, 225, 315):
        radians = math.radians(angle)
        x, y = 30 + .99 * math.cos(radians), -26 + .99 * math.sin(radians)
        rod('Thin funerary hanging chain', (x, y, 2.51), (x, y, 2.09), .013, 'aged_brass', 6)
        ellipsoid('Free spectral tear', (x, y, 2.07), (.06, .06, .11), 'spectral', 8, 4)


wall_architecture()
for x, z in ((24.5, 26), (35.5, 26)):
    box('Distinctive woven table carpet border', (x, -z, .024), (8.9, 5.46, .016), 'aged_brass')
    box('Midnight woven carpet', (x, -z, .036), (8.72, 5.28, .014), 'velvet' if x < 30 else 'shadow_blue')
    for side in (-1, 1):
        box('Carpet long woven key line', (x, -z + side * 2.48, .048), (8.43, .024, .006), 'bright_brass')
    table(x, z, x > 30)
for x, z, yaw in ((22.1, 23.55, .08), (26.55, 23.65, -.13), (21.0, 28.38, -.09), (26.8, 28.42, .12), (32.8, 23.52, -.11), (38.35, 23.62, .14), (34.15, 23.5, .13)):
    carved_chair(x, z, yaw)
carved_chair(32.55, 28.45, -.22, True)
service_niche()
dais()
mourning_chandelier()
for x, z in ((16.7, 22.15), (41.7, 22.15), (17.0, 29.35), (43.35, 29.36)):
    rod('Hall tall iron candlestick', (x, -z, .12), (x, -z, 1.7), .055, 'iron', 8)
    box('Candlestick broad foot', (x, -z, .1), (.36, .36, .18), 'aged_brass')
    for side in (-1, 1):
        pendant((x + side * .13, -z, 1.65), .3 + .08 * (side > 0))

for key, batch in GEOMETRY.items():
    geometry_mesh = bpy.data.meshes.new(batch['name'])
    geometry_mesh.from_pydata(batch['vertices'], [], batch['faces'])
    geometry_mesh.update()
    obj = bpy.data.objects.new(f'Banquet_{key[0]}_{key[1]}_{key[2]}', geometry_mesh)
    bpy.context.collection.objects.link(obj)
    geometry_mesh.materials.append(MATERIALS[key[2]])

for index, (name, center, size) in enumerate(COLLISIONS):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.name = f'Banquet_{name}_{index:03}-colonly'
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)

OUTPUT.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(OUTPUT / 'haunted_feast.blend'))
bpy.ops.export_scene.gltf(filepath=str(OUTPUT / 'haunted_feast.glb'), export_format='GLB', export_apply=True, export_animations=False, export_cameras=False, export_lights=False)
print('BANQUET_EXPORT', len(GEOMETRY), 'batches', len(COLLISIONS), 'colliders', sum(len(batch['faces']) for batch in GEOMETRY.values()), 'faces')
