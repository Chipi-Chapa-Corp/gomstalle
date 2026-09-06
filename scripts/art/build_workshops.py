import argparse
import math
from pathlib import Path
import sys
import bpy
sys.path.insert(0, str(Path(__file__).resolve().parent))
from workshop_geometry import bench, box, collider, create_scene, cylinder, export_asset, finish, label, lathe, material, profile, ring, rod, scales, tube

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
arguments = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])


def palette():
    return {
        'stone': material('Workshop | basalt', (0.105, 0.14, 0.16)),
        'edge': material('Workshop | sandstone', (0.24, 0.27, 0.25)),
        'oak': material('Workshop | aged oak', (0.12, 0.055, 0.025)),
        'oak_top': material('Workshop | worn oak', (0.24, 0.125, 0.05)),
        'iron': material('Workshop | forged iron', (0.045, 0.065, 0.075), 0.72, 0.44),
        'steel': material('Workshop | worn steel', (0.25, 0.31, 0.34), 0.76, 0.34),
        'brass': material('Workshop | brass fittings', (0.49, 0.28, 0.07), 0.7, 0.31),
        'green': material('Workshop | green bottle glaze', (0.025, 0.125, 0.065), 0.08, 0.23),
        'amber': material('Workshop | amber bottle glaze', (0.30, 0.105, 0.02), 0.08, 0.25),
        'paper': material('Workshop | cream labels', (0.62, 0.49, 0.28)),
        'leather': material('Workshop | oxblood leather', (0.24, 0.04, 0.025)),
        'leaf': material('Workshop | dried sage', (0.07, 0.13, 0.035)),
        'water': material('Workshop | quench water', (0.035, 0.12, 0.15), 0.13, 0.22),
        'coal': material('Workshop | coal', (0.018, 0.02, 0.018)),
        'ember': material('Workshop | banked embers', (0.8, 0.17, 0.018), 0, 0.6, 2.2)
    }


def plaque(text, center, width, colors, reverse=False):
    box('Carved station plaque', center, (width, 0.10, 0.38), colors['oak'], 0.035)
    lettering = label(text, (center[0], center[1] + (0.06 if reverse else -0.06), center[2] - 0.06), 0.15, colors['paper'])
    if reverse:
        lettering.rotation_euler.z = math.pi


def jar(center, size, colors, style=0):
    outline = [(0.18, 0), (0.22, 0.04), (0.23, 0.30), (0.19, 0.39), (0.085, 0.46), (0.08, 0.62), (0.10, 0.65)] if style else [(0.18, 0), (0.24, 0.04), (0.24, 0.40), (0.20, 0.44), (0.20, 0.49)]
    lathe('Apothecary labeled vessel', center, [(radius * size, height * size) for radius, height in outline], colors['amber' if style else 'green'])
    cylinder('Vessel cream identification band', (center[0], center[1], center[2] + 0.23 * size), 0.243 * size, 0.17 * size, colors['paper'], 24)
    cylinder('Sealed cork stopper', (center[0], center[1], center[2] + (0.67 if style else 0.52) * size), (0.08 if style else 0.205) * size, 0.055 * size, colors['oak_top'], 16)


def mortar(center, colors, scale=1):
    lathe('Stone grinding mortar', center, [(0.18 * scale, 0), (0.23 * scale, 0.09 * scale), (0.27 * scale, 0.30 * scale), (0.24 * scale, 0.33 * scale), (0.20 * scale, 0.27 * scale), (0.12 * scale, 0.07 * scale)], colors['edge'])
    rod('Mortar pestle', (center[0] - 0.1 * scale, center[1], center[2] + 0.18 * scale), (center[0] + 0.25 * scale, center[1], center[2] + 0.70 * scale), 0.06 * scale, colors['edge'])


def herb_rail(center, width, colors):
    rod('Drying rail', (center[0] - width / 2, center[1], center[2]), (center[0] + width / 2, center[1], center[2]), 0.035, colors['iron'])
    for side in (-1, 1):
        rod('Rail masonry bracket', (center[0] + side * width / 2, center[1], center[2]), (center[0] + side * width / 2, center[1] - 0.45, center[2] + 0.15), 0.03, colors['iron'])
    for index in range(int(width / 0.4)):
        horizontal = center[0] - width / 2 + 0.22 + index * 0.4
        rod('Herb bundle binding', (horizontal, center[1], center[2]), (horizontal, center[1], center[2] - 0.22), 0.012, colors['paper'])
        for angle in (0, 2.1, 4.2):
            rod('Dried herb stem', (horizontal, center[1], center[2] - 0.2), (horizontal + math.cos(angle) * 0.13, center[1] + math.sin(angle) * 0.13, center[2] - 0.75), 0.013, colors['leaf'])
            bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=1, location=(horizontal + math.cos(angle) * 0.1, center[1] + math.sin(angle) * 0.1, center[2] - 0.55))
            finish(bpy.context.object, 'Dried sage cluster', colors['leaf']).scale = (0.09, 0.075, 0.24)


def build_apothecary():
    create_scene('Apothecary dispensing workshop')
    colors = palette()
    for horizontal, title, width in ((30.7, 'SALTS', 2.5), (33.4, 'ROOTS', 2.5), (42.6, 'TINCTURES', 3.5)):
        box('Ingredient cabinet back', (horizontal, -12.58, 1.7), (width, 0.16, 3.4), colors['oak'], 0.04)
        collider('Ingredient cabinet', (horizontal, -13.0, 1.65), (width + 0.08, 0.95, 3.3))
        for side in (-1, 1):
            box('Turned cabinet upright', (horizontal + side * (width / 2 - 0.08), -13.0, 1.58), (0.18, 0.85, 3.16), colors['oak_top'])
            cylinder('Cabinet finial', (horizontal + side * (width / 2 - 0.08), -13.0, 3.5), 0.13, 0.25, colors['brass'], 12)
        for elevation in (0.30, 1.04, 1.80, 2.56):
            box('Ingredient shelf', (horizontal, -13.0, elevation), (width, 0.85, 0.12), colors['oak_top'])
            for index in range(5):
                jar((horizontal - width * 0.36 + index * width * 0.18, -13.12, elevation + 0.07), 0.74, colors, index % 2)
        pediment = profile('Curved cabinet pediment', (horizontal, -13.0, 3.31), [(-1.6, -0.15), (-1.6, 0.08), (-0.7, 0.14), (0, 0.48), (0.7, 0.14), (1.6, 0.08), (1.6, -0.15)], 0.4, colors['oak_top'])
        pediment.scale.x = width / 3.2
        plaque(title, (horizontal, -13.42, 3.21), width - 0.20, colors)
    bench((32.4, -16.2, 0), 5.7, 1.22, colors, True)
    box('Counter brass footrail', (32.4, -15.47, 0.23), (5.7, 0.08, 0.08), colors['brass'])
    for horizontal in (30.7, 32.4, 34.1):
        box('Prescription writing mat', (horizontal, -16.2, 1.13), (1.18, 0.74, 0.025), colors['leather'], 0.015)
        jar((horizontal + 0.26, -16.3, 1.16), 0.8, colors, 1)
        box('Folded prescription sheet', (horizontal - 0.26, -16.05, 1.17), (0.34, 0.4, 0.018), colors['paper'], 0.005)
    scales((32.0, -16.3, 1.2), colors)
    mortar((30.3, -16.17, 1.18), colors, 0.8)
    bench((44.3, -17.75, 0), 3.0, 1.25, colors)
    mortar((43.45, -17.7, 1.14), colors)
    for horizontal in (44.0, 44.65):
        box('Press support upright', (horizontal, -17.77, 1.9), (0.15, 0.24, 1.6), colors['oak'])
    box('Press crosshead', (44.325, -17.77, 2.69), (1.02, 0.32, 0.23), colors['oak_top'])
    rod('Threaded press screw', (44.325, -17.77, 1.48), (44.325, -17.77, 2.97), 0.05, colors['iron'])
    for elevation in range(12):
        ring('Press screw thread', (44.325, -17.77, 1.69 + elevation * 0.1), 0.06, 0.012, colors['iron'])
    rod('Press turning handle', (43.95, -17.77, 2.97), (44.7, -17.77, 2.97), 0.035, colors['oak_top'])
    cylinder('Press platen', (44.325, -17.77, 1.56), 0.32, 0.12, colors['iron'])
    lathe('Herb press bowl', (44.325, -17.77, 1.14), [(0.30, 0), (0.36, 0.08), (0.36, 0.25), (0.31, 0.27), (0.29, 0.10)], colors['brass'])
    jar((45.25, -17.8, 1.15), 0.9, colors, 1)
    herb_rail((44.0, -19.0, 3.6), 3.0, colors)
    plaque('THE APOTHECARY', (38.0, -12.72, 4.1), 5.7, colors)
    for horizontal in (29, 46.8):
        box('Shop wainscot pier', (horizontal, -18.5, 1.65), (0.34, 1.8, 3.3), colors['oak'], 0.04, True)
    export_asset(arguments.output / 'apothecary.glb', colors['stone'])


def sword(center, colors, angle=0):
    parts = []
    parts.append(profile('Tempered sword blade', center, [(-0.065, 0), (-0.065, 0.95), (0, 1.22), (0.065, 0.95), (0.065, 0)], 0.035, colors['steel'], 0.005))
    parts.append(box('Forged sword guard', (center[0], center[1], center[2] - 0.03), (0.43, 0.075, 0.06), colors['iron'], 0.012))
    parts.append(cylinder('Bound leather grip', (center[0], center[1], center[2] - 0.21), 0.043, 0.30, colors['leather'], 12))
    parts.append(cylinder('Sword pommel', (center[0], center[1], center[2] - 0.4), 0.075, 0.08, colors['brass'], 8))
    if angle:
        from mathutils import Matrix, Vector
        transform = Matrix.Translation(Vector(center)) @ Matrix.Rotation(angle, 4, 'Y') @ Matrix.Translation(-Vector(center))
        bpy.context.view_layer.update()
        for obj in parts:
            obj.matrix_world = transform @ obj.matrix_world


def armor_stand(center, colors):
    cylinder('Armor stand footing', (center[0], center[1], 0.10), 0.58, 0.20, colors['stone'], 8)
    rod('Armor support post', (center[0], center[1], 0.2), (center[0], center[1], 2.3), 0.085, colors['oak'])
    collider('Armor display', (center[0], center[1], 1.24), (1.05, 0.88, 2.48))
    for side in (-1, 1):
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8, location=(center[0] + side * 0.38, center[1], 1.68))
        finish(bpy.context.object, 'Forged shoulder pauldron', colors['steel']).scale = (0.30, 0.24, 0.18)
        cylinder('Segmented arm cuff', (center[0] + side * 0.48, center[1], 1.25), 0.15, 0.5, colors['steel'], 12)
    lathe('Riveted breastplate', (center[0], center[1], 0.9), [(0.26, 0), (0.32, 0.16), (0.37, 0.40), (0.43, 0.63), (0.30, 0.85), (0.15, 0.88)], colors['steel'], 20).scale.y = 0.65
    ring('Breastplate waist rim', (center[0], center[1], 0.95), 0.28, 0.035, colors['brass']).scale.y = 0.65
    lathe('Great helm dome', (center[0], center[1], 1.86), [(0.25, 0), (0.28, 0.20), (0.26, 0.40), (0.19, 0.52), (0.07, 0.60)], colors['steel'], 20)
    for side in (-1, 1):
        box('Helm visor eye slit', (center[0] + side * 0.11, center[1] - 0.26, 2.20), (0.18, 0.025, 0.04), colors['iron'], 0.005)
    box('Helm nasal ridge', (center[0], center[1] - 0.28, 2.1), (0.065, 0.055, 0.32), colors['brass'], 0.01)


def build_armory():
    create_scene('Armory forge and repair workshop')
    colors = palette()
    for horizontal in (14.3, 16.3):
        armor_stand((horizontal, -2.0, 0), colors)
    for horizontal in (20.3, 22.7, 25.1):
        box('Weapon inventory rack back', (horizontal, -1.15, 1.65), (2.2, 0.16, 3.3), colors['oak'], 0.025, True)
        for height in (0.75, 2.08):
            box('Sword rack crossbar', (horizontal, -1.38, height), (2.0, 0.32, 0.16), colors['oak_top'])
        for offset in (-0.65, 0, 0.65):
            sword((horizontal + offset, -1.65, 1.08), colors)
        plaque('BLADES / III', (horizontal, -1.28, 2.92), 1.9, colors)
    for depth in (5.0, 9.0, 13.0):
        collider('Shield rack', (13.15, -depth, 1.4), (0.4, 2.8, 2.8))
        for offset in (-1.28, 1.28):
            box('Shield rack upright', (13.1, -depth + offset, 1.4), (0.20, 0.18, 2.8), colors['oak_top'], 0.025)
        for elevation in (0.65, 1.55, 2.3):
            box('Shield hanging rail', (13.15, -depth, elevation), (0.20, 2.8, 0.14), colors['oak_top'], 0.02)
        for offset in (-0.7, 0.7):
            shield = profile('Bowed heater shield', (13.42, -depth + offset, 1.0), [(-0.40, 0.58), (0.40, 0.58), (0.38, 0.05), (0.20, -0.38), (0, -0.60), (-0.20, -0.38), (-0.38, 0.05)], 0.10, colors['leather'], 0.04)
            shield.rotation_euler.z = math.pi / 2
            tube('Shield rolled brass rim', [(13.49, -depth + offset + horizontal, 1.0 + elevation) for horizontal, elevation in [(-0.40, 0.58), (0.40, 0.58), (0.38, 0.05), (0.20, -0.38), (0, -0.60), (-0.20, -0.38), (-0.38, 0.05)]], 0.022, colors['brass'], True)
            box('Shield vertical boss strap', (13.50, -depth + offset, 1.06), (0.05, 0.12, 1.10), colors['brass'])
            cylinder('Shield central boss', (13.58, -depth + offset, 1.12), 0.14, 0.10, colors['steel'], 16).rotation_euler.y = math.pi / 2
    bench((15.7, -13.7, 0), 2.1, 3.8, colors)
    for depth in (-12.6, -13.7, -14.8):
        box('Riveting work mat', (15.7, depth, 1.14), (1.5, 0.8, 0.04), colors['leather'], 0.03)
        lathe('Unfinished curved armor plate', (15.5, depth, 1.17), [(0.25, 0), (0.35, 0.15), (0.31, 0.32), (0.12, 0.40)], colors['steel'], 16).scale.y = 0.65
        rod('Riveting hammer handle', (16.0, depth - 0.22, 1.22), (16.0, depth + 0.20, 1.22), 0.034, colors['oak_top'])
        box('Riveting hammer face', (16.0, depth + 0.22, 1.22), (0.2, 0.12, 0.14), colors['steel'], 0.02)
    box('Rivet drawer cabinet', (15.7, -15.38, 1.43), (1.65, 0.38, 0.6), colors['oak'], 0.035)
    for offset in (-0.55, 0, 0.55):
        box('Small rivet storage drawer', (15.7 + offset, -15.13, 1.45), (0.45, 0.12, 0.36), colors['oak_top'], 0.02)
        cylinder('Rivet drawer knob', (15.7 + offset, -15.04, 1.45), 0.045, 0.06, colors['brass'], 12).rotation_euler.x = math.pi / 2
    bench((23.0, -3.85, 0), 3.7, 1.25, colors)
    for horizontal in (21.55, 24.45):
        for depth in (-3.32, -4.38):
            wheel = cylinder('Armor trolley cast wheel', (horizontal, depth, 0.21), 0.20, 0.09, colors['iron'], 16)
            wheel.rotation_euler.x = math.pi / 2
            ring('Trolley wheel rim', (horizontal, depth - 0.05, 0.21), 0.19, 0.025, colors['steel'], (math.pi / 2, 0, 0))
    for horizontal in (21.8, 23.0, 24.1):
        box('Armor transit padded cradle', (horizontal, -3.85, 1.17), (0.85, 0.88, 0.12), colors['leather'], 0.06)
        lathe('Armor awaiting repair', (horizontal, -3.85, 1.25), [(0.27, 0), (0.38, 0.16), (0.4, 0.35), (0.25, 0.55)], colors['steel'], 16).scale.y = 0.7
    for depth in (-3.38, -4.32):
        rod('Trolley handle stanchion', (25.0, depth, 0.7), (25.0, depth, 1.52), 0.035, colors['iron'])
    rod('Trolley pushing handle', (25.0, -3.38, 1.52), (25.0, -4.32, 1.52), 0.045, colors['oak_top'])
    bench((22.4, -9.9, 0), 4.2, 1.7, colors)
    box('Armor repair leather pad', (22.5, -9.9, 1.14), (1.5, 1.15, 0.045), colors['leather'], 0.035)
    for index in range(3):
        horizontal = 21.0 + index * 0.8
        rod('Repair hammer shaft', (horizontal, -10.3, 1.2), (horizontal + 0.45, -9.8, 1.2), 0.04, colors['oak_top'])
        box('Repair hammer head', (horizontal + 0.46, -9.79, 1.2), (0.24, 0.13, 0.14), colors['steel'], 0.025)
    sword((23.9, -9.9, 1.25), colors, -math.pi / 2)
    for index in range(6):
        ring('Unfinished mail rings', (22.0 + (index % 3) * 0.12, -9.8 + (index // 3) * 0.12, 1.2), 0.095, 0.018, colors['steel'])
    for side in (-1, 1):
        box('Forge pier footing', (25 + side * 1.48, -17.35, 0.18), (0.85, 2.2, 0.36), colors['edge'], 0.04, True)
        for elevation in range(5):
            box('Forge dressed pier course', (25 + side * 1.48, -17.35, 0.60 + elevation * 0.5), (0.7, 1.95, 0.45), colors['stone'], 0.045, True)
    box('Forge fire back', (25, -18.17, 1.52), (2.8, 0.4, 3.04), colors['stone'], 0.04, True)
    box('Forge coal bed', (25, -17.20, 0.98), (2.6, 1.6, 0.35), colors['iron'], 0.045, True)
    for index in range(11):
        angle = math.pi * index / 10
        stone = box('Forged hearth arch voussoir', (25 + math.cos(angle) * 1.48, -16.46, 2.75 + math.sin(angle) * 0.78), (0.5, 0.35, 0.38), colors['edge'], 0.035)
        stone.rotation_euler.y = math.pi / 2 - angle
    box('Chimney corbel', (25, -17.38, 3.67), (3.3, 2.1, 0.27), colors['edge'], 0.035)
    box('Blackened forge chimney', (25, -17.5, 4.22), (2.4, 1.5, 0.85), colors['stone'], 0.035)
    for index in range(12):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1, radius=0.23, location=(24.2 + (index % 4) * 0.53, -17.65 + (index // 4) * 0.38, 1.22))
        finish(bpy.context.object, 'Banked forge coals', colors['ember' if index % 3 else 'coal']).scale.z = 0.55
    for horizontal in (24.25, 25.0, 25.75):
        rod('Heating iron billet', (horizontal, -17.45, 1.35), (horizontal, -16.05, 1.35), 0.045, colors['steel'])
    box('Anvil oak stump', (21.8, -14.7, 0.46), (1.0, 0.84, 0.92), colors['oak_top'], 0.09, True)
    profile('Forged horn anvil', (21.8, -14.7, 0.93), [(-0.50, 0), (-0.50, 0.12), (-0.23, 0.24), (-0.20, 0.45), (-0.43, 0.52), (-0.45, 0.69), (0.48, 0.69), (0.94, 0.55), (0.44, 0.48), (0.22, 0.39), (0.23, 0.24), (0.5, 0.12), (0.5, 0)], 0.50, colors['steel'], 0.045)
    collider('Anvil', (21.9, -14.7, 1.3), (1.3, 0.55, 0.75))
    lathe('Quench water tub', (25.8, -12.8, 0), [(0.5, 0), (0.58, 0.14), (0.66, 0.88), (0.61, 0.92), (0.52, 0.2)], colors['oak_top'])
    for elevation in (0.18, 0.75):
        ring('Quench tub iron hoop', (25.8, -12.8, elevation), 0.59 + elevation * 0.055, 0.04, colors['iron'])
    cylinder('Quench water surface', (25.8, -12.8, 0.76), 0.58, 0.025, colors['water'])
    collider('Quench tub', (25.8, -12.8, 0.45), (1.25, 1.25, 0.9))
    profile('Leather forge bellows', (23.0, -17.5, 0.95), [(-0.54, 0), (-0.48, 0.30), (0.25, 0.40), (0.68, 0.18), (0.25, -0.05)], 0.58, colors['leather'], 0.04)
    collider('Forge bellows', (23.04, -17.5, 0.67), (1.30, 0.65, 1.34))
    tube('Bellows fire nozzle', [(23.6, -17.5, 1.1), (23.9, -17.5, 1.0), (24.25, -17.5, 1.0)], 0.085, colors['iron'])
    for depth in (-17.22, -17.78):
        rod('Bellows oak cheek', (22.55, depth, 1.13), (23.35, depth, 1.13), 0.04, colors['oak_top'])
    plaque('THE CASTLE ARMORY', (22.8, -0.88, 3.9), 5.8, colors)
    plaque('FORGE & TEMPER', (25.0, -16.20, 3.62), 3.0, colors, True)
    export_asset(arguments.output / 'armory.glb', colors['stone'])


build_apothecary()
build_armory()
