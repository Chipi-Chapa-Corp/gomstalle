import argparse
import math
from pathlib import Path
import bpy
import sys
sys.path.insert(0, str(Path(__file__).resolve().parent))
from workshop_geometry import append_source, box, collider, collisions, create_scene, cylinder, export_asset, finish, label, material, ring, rod, tube

parser = argparse.ArgumentParser()
parser.add_argument('--laboratory', type=Path, required=True)
parser.add_argument('--refinery', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
arguments = parser.parse_args(__import__('sys').argv[__import__('sys').argv.index('--') + 1:])
create_scene('Alchemy working bays')

lab_exclusions = ('human_ref', 'room_air', 'banner_red', 'barrel_large', 'keg', 'box_small', 'stool', 'trunk_small', 'sword_shield', 'torch_lit', 'keyring', 'staff', 'pillar_decorated', 'rune_', 'lantern_', 'lectern_', 'candle_lit', 'candle_triple', 'spellbook_open.001')
lab_collections = {'gomstalle_assets', 'custom_assets', 'props'}

def include_lab(obj):
    return not obj.name.startswith(lab_exclusions) and bool({collection.name for collection in obj.users_collection} & lab_collections)

append_source(arguments.laboratory, include_lab, (13.5, 1.5, 0.05))
widow_architecture = ('Apothecary niche', 'Great retort recess', 'North ', 'Pier base', 'Pier upper', 'Seated pier')
widow_exclusions = ('Scale reference', 'Gomstalle | keyring', 'Pendant chain')
widow_collections = {'Retort assembly', 'Condenser assembly', 'Workstations', 'Story props', 'Gomstalle assets'}

def include_widow(obj):
    return not obj.name.startswith(widow_exclusions) and (bool({collection.name for collection in obj.users_collection} & widow_collections) or obj.name.startswith(widow_architecture))

append_source(arguments.refinery, include_widow, (42, 7.55, 0.05), 1.1)

stone = material('Laboratory | basalt', (0.15, 0.21, 0.22))
stone_edge = material('Laboratory | dressed limestone', (0.29, 0.34, 0.32))
wood = material('Laboratory | aged oak', (0.19, 0.095, 0.045))
wood_top = material('Laboratory | worn oak', (0.29, 0.17, 0.075))
copper = material('Laboratory | hammered copper', (0.46, 0.19, 0.065), 0.72, 0.36)
brass = material('Laboratory | polished brass', (0.60, 0.39, 0.13), 0.72, 0.29)
iron = material('Laboratory | black iron', (0.04, 0.07, 0.075), 0.5, 0.48)
teal = material('Laboratory | ward glass', (0.055, 0.46, 0.34), 0.15, 0.22, 0.55)
ink = material('Laboratory | dark green glaze', (0.035, 0.115, 0.085), 0.12, 0.26)
paper = material('Laboratory | ivory lettering', (0.78, 0.65, 0.39))

for horizontal in (14, 26.5, 36.5, 46.8):
    for depth in (4.4, 10.9):
        box('Bay pier footing', (horizontal, depth, 0.20), (0.86, 0.86, 0.40), stone_edge, 0.06, True)
        box('Bay carved pier', (horizontal, depth, 2.15), (0.48, 0.48, 3.55), stone, 0.04, True)
        box('Bay capital', (horizontal, depth, 3.98), (0.88, 0.88, 0.28), stone_edge, 0.05)
        box('Oak cap seat', (horizontal, depth, 4.18), (0.76, 0.76, 0.20), wood)
    for depth in (4.8, 10.5):
        box('Bay wall bracket', (horizontal, depth, 4.46), (0.34, 1.45, 0.40), wood, 0.04)
    for depth in (4.6, 10.7):
        brace = box('Pegged diagonal knee', (horizontal, depth + (0.4 if depth < 7 else -0.4), 4.05), (0.24, 1.25, 0.24), wood)
        brace.rotation_euler.x = math.radians(38 if depth < 7 else -38)
        cylinder('Brass mortise peg', (horizontal, depth, 4.21), 0.085, 0.28, brass, 12).rotation_euler.y = math.pi / 2
box('Herb rack cantilever', (16.2, 10.25, 4.3), (3.5, 0.20, 0.18), wood)
for horizontal in (14.85, 17.5):
    rod('Herb rack wall support', (horizontal, 9.0, 4.16), (horizontal, 11.1, 4.3), 0.035, iron)
for depth in (10.9,):
    box('Continuous oak header', (30.4, depth, 4.55), (33.7, 0.34, 0.42), wood, 0.035)

for horizontal, width in ((20.25, 11.8), (31.5, 8.1)):
    box('Back wall workstation lining', (horizontal, 11.18, 1.62), (width, 0.28, 3.24), stone, 0.03, True)
    box('Workstation wall coping', (horizontal, 11.18, 3.3), (width + 0.16, 0.44, 0.16), stone_edge)
    for course in range(5):
        for column in range(int(width / 1.5)):
            position = horizontal - width / 2 + 0.85 + column * 1.5 + (0.35 if course % 2 else 0)
            box('Dressed ashlar course', (position, 11.015, 0.35 + course * 0.59), (1.35, 0.1, 0.48), stone_edge, 0.035)

box('Preparation shelf backing', (14.10, 7.85, 1.55), (0.20, 4.7, 3.1), wood, 0.025, True)
box('Collection shelf backing', (24.7, 5.8, 1.55), (0.22, 3.0, 3.1), wood, 0.025, True)
box('Refinery preparation backing', (37.68, 7.7, 1.85), (0.20, 5.1, 3.7), wood, 0.025, True)
box('Refinery ward stock backing', (46.37, 7.7, 1.62), (0.20, 5.1, 3.24), wood, 0.025, True)

for center, radius, height, surface in (((31.5, 7.55, 0.15), 3.2, 0.3, stone), ((31.5, 7.55, 0.40), 2.7, 0.2, stone_edge), ((31.5, 7.55, 0.59), 2.3, 0.18, stone)):
    cylinder('Octagonal warding dais', center, radius, height, surface, 8)
    collider('Warding dais', center, (radius * 2, radius * 2, height))
    collisions[-1]['radius'] = radius
ring('Inlaid ward circle', (31.5, 7.55, 0.70), 2.0, 0.035, brass)
ring('Illuminated ward circuit', (31.5, 7.55, 0.72), 1.78, 0.026, teal)
cylinder('Containment basin pedestal', (31.5, 7.55, 0.94), 0.95, 0.5, iron, 12)
cylinder('Containment copper reservoir', (31.5, 7.55, 1.2), 0.80, 0.5, copper, 32)
ring('Reservoir lip', (31.5, 7.55, 1.47), 0.82, 0.065, brass)
cylinder('Warding essence pool', (31.5, 7.55, 1.46), 0.73, 0.02, teal)
collider('Containment vessel', (31.5, 7.55, 1.06), (1.9, 1.9, 0.85))
for index in range(6):
    angle = index * math.tau / 6
    cosine, sine = math.cos(angle), math.sin(angle)
    base = (31.5 + cosine * 1.6, 7.55 + sine * 1.6, 0.8)
    cylinder('Ribbed containment shoe', base, 0.22, 0.25, iron, 8)
    tube('Curved containment rib', [base, (31.5 + cosine * 1.8, 7.55 + sine * 1.8, 1.9), (31.5 + cosine * 1.35, 7.55 + sine * 1.35, 3.3), (31.5 + cosine * 0.45, 7.55 + sine * 0.45, 3.75)], 0.055, brass)
    box('Engraved ward marker', (31.5 + cosine * 2.03, 7.55 + sine * 2.03, 0.73), (0.17, 0.28, 0.025), teal, 0.005).rotation_euler.z = angle
ring('Containment crown', (31.5, 7.55, 3.74), 0.48, 0.10, copper)
ring('Armillary meridian', (31.5, 7.55, 2.4), 0.66, 0.035, brass, (math.pi / 2, 0.3, 0))
ring('Armillary equator', (31.5, 7.55, 2.4), 0.69, 0.035, brass, (0.4, 0, 0))
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.48, location=(31.5, 7.55, 2.4))
finish(bpy.context.object, 'Suspended salt crystal', teal).scale = (0.68, 0.68, 1.5)

for horizontal in (28.4, 34.6):
    box('Warding instrument bench', (horizontal, 10.08, 0.98), (1.8, 0.9, 0.18), wood_top, 0.03, True)
    for offset in (-0.65, 0.65):
        box('Instrument bench trestle', (horizontal + offset, 10.08, 0.45), (0.17, 0.7, 0.9), wood, 0.02, True)
    for index in range(3):
        cylinder('Calibrated salt jar', (horizontal - 0.55 + index * 0.52, 10.04, 1.28), 0.14, 0.42, ink, 16)
        cylinder('Sealed brass jar lid', (horizontal - 0.55 + index * 0.52, 10.04, 1.51), 0.15, 0.06, brass, 16)
    box('Instrument recipe plaque', (horizontal, 10.96, 1.98), (1.45, 0.12, 0.65), wood)
    label('SALTS / III' if horizontal < 30 else 'WARD / VI', (horizontal, 10.89, 2.04), 0.14, paper)

for horizontal, text in ((20.2, 'THE TRANSMUTER'), (31.5, 'WARD CALIBRATION'), (42.0, "WIDOW'S SALT")):
    box('Laboratory bay plaque', (horizontal, 10.95, 4.98), (4.1, 0.16, 0.64), wood)
    box('Plaque brass upper border', (horizontal, 10.85, 5.25), (3.9, 0.05, 0.035), brass)
    label(text, (horizontal, 10.84, 4.96), 0.25, paper)

for depth, height in ((10.52, 3.35), (10.78, 3.56)):
    tube('Continuous cooling supply', [(24.3, 9.1, 0.85), (25.7, 10.0, 1.3), (26.9, depth, height), (35.6, depth, height), (39.5, depth, height), (45.0, depth, 2.55)], 0.075, copper)
    for horizontal in (27.1, 29.5, 33.6, 36.1, 39.6):
        ring('Cooling pipe union', (horizontal, depth, height), 0.115, 0.032, brass, (0, math.pi / 2, 0))
        rod('Pipe masonry anchor', (horizontal, depth, height), (horizontal, 11.15, height), 0.035, iron)

for name, center, size in [
    ('Grand hearth', (19.5, 9.45, 1.10), (3.7, 2.3, 2.2)),
    ('Condenser trough', (22.05, 9.55, 0.36), (1.9, 0.85, 0.72)),
    ('Preparation bench', (15.35, 5, 0.52), (1.15, 2.7, 1.04)),
    ('Collection bench', (23.85, 4.6, 0.53), (2.0, 4.0, 1.06)),
    ('Dried herb cabinet', (16.2, 9.92, 0.88), (1.55, 0.5, 1.76)),
    ('Mineral storage chest', (24.5, 7.55, 0.68), (1.5, 1.7, 1.36)),
    ('Refinery retort', (41.285, 9.915, 1.3), (2.1, 2.1, 2.6)),
    ('Refinery condenser', (43.375, 10.058, 1.4), (1.0, 1.1, 2.8)),
    ('Refinery preparation bench', (38.436, 7.825, 0.55), (0.92, 3.08, 1.1)),
    ('Refinery collection bench', (44.73, 9.706, 0.53), (1.48, 0.87, 1.06)),
    ('Refinery dispatch desk', (44.805, 4.8, 0.56), (1.98, 0.99, 1.12)),
    ('Refinery incoming chest', (38.777, 4.723, 0.42), (1.36, 1.1, 0.84)),
    ('Refinery stock cabinet', (46.0, 8.15, 1.18), (0.58, 3.1, 2.36))
]:
    collider(name, center, size)

for surface in bpy.data.materials:
    if not surface.use_nodes:
        continue
    shader = surface.node_tree.nodes.get('Principled BSDF')
    if shader is None:
        continue
    for link in list(shader.inputs['Base Color'].links):
        if link.from_node.type == 'MIX':
            surface.node_tree.links.remove(link)
    if surface.name == 'stone_wall':
        shader.inputs['Base Color'].default_value = (0.18, 0.22, 0.23, 1)
    elif surface.name == 'herb_green':
        shader.inputs['Base Color'].default_value = (0.07, 0.16, 0.04, 1)

export_asset(arguments.output / 'working_bays.glb', stone)
