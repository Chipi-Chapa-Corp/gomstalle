import argparse
import math
from pathlib import Path
import sys
import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from workshop_geometry import box, collider, create_scene, cylinder, export_asset, finish, label, lathe, material, profile, ring, rod, tube

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
arguments = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
asset_root = Path(__file__).resolve().parents[2] / 'assets' / 'castle'


def palette():
    return {
        'walnut': material('Salon | carved walnut', (0.095, 0.043, 0.033)),
        'polished': material('Salon | polished walnut', (0.22, 0.095, 0.053), 0.05, 0.32),
        'velvet': material('Salon | plum velvet', (0.15, 0.032, 0.095), 0, 0.86),
        'silk': material('Salon | rose silk', (0.34, 0.105, 0.17), 0, 0.68),
        'brass': material('Salon | champagne brass', (0.55, 0.35, 0.13), 0.7, 0.32),
        'ivory': material('Salon | warm ivory', (0.67, 0.56, 0.38), 0, 0.58),
        'marble': material('Salon | dark green marble', (0.045, 0.095, 0.085), 0.08, 0.28),
        'stone': material('Gallery | pale limestone', (0.33, 0.32, 0.27)),
        'plaster': material('Salon | warm plaster', (0.42, 0.30, 0.24)),
        'black': material('Salon | hearth charcoal', (0.018, 0.022, 0.025)),
        'iron': material('Salon | hearth iron', (0.075, 0.085, 0.095), 0.68, 0.35),
        'ember': material('Salon | hearth embers', (0.67, 0.12, 0.015), 0, 0.7, 2.2),
        'paper': material('Gallery | aged catalogue paper', (0.64, 0.52, 0.34)),
        'ink': material('Gallery | blue ink', (0.055, 0.065, 0.12)),
        'canvas': material('Gallery | canvas lining', (0.26, 0.16, 0.10)),
    }


def ellipsoid(name, center, dimensions, surface):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, radius=1, location=center)
    obj = finish(bpy.context.object, name, surface)
    obj.scale = dimensions
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def plaque(text, center, width, colors):
    box('Engraved attribution plate', center, (width, 0.08, 0.22), colors['brass'], 0.025)
    label(text, (center[0], center[1] - 0.046, center[2] - 0.035), 0.092, colors['black'])


def placed_parts(build, center, angle=0):
    existing = set(bpy.data.objects)
    build()
    bpy.context.view_layer.update()
    transform = Matrix.Translation(Vector(center)) @ Matrix.Rotation(angle, 4, 'Z')
    for obj in set(bpy.data.objects) - existing:
        obj.matrix_world = transform @ obj.matrix_world


def upholstery(center, width, colors, angle=0):
    depth = 1.12 if width > 1.5 else 0.90
    def build():
        box('Upholstered seat carved apron', (0, 0, 0.46), (width, depth, 0.20), colors['polished'], 0.065)
        for horizontal in (-width / 2 + 0.16, width / 2 - 0.16):
            for offset in (-depth / 2 + 0.13, depth / 2 - 0.13):
                lathe('Turned cabriole seat leg', (horizontal, offset, 0), [(0.06, 0), (0.085, 0.06), (0.055, 0.16), (0.10, 0.32), (0.07, 0.42)], colors['walnut'], 16)
        count = 3 if width > 1.5 else 1
        for index in range(count):
            horizontal = -width / 2 + (index + 0.5) * width / count
            box('Individual velvet seat cushion', (horizontal, -0.035, 0.64), (width / count - 0.055, depth - 0.14, 0.20), colors['velvet'], 0.085)
        outline = [(-width / 2, 0.58), (-width / 2, 1.07), (-width * 0.37, 1.24), (0, 1.34), (width * 0.37, 1.24), (width / 2, 1.07), (width / 2, 0.58)]
        profile('Curved walnut seat crest', (0, depth / 2 - 0.07, 0), outline, 0.20, colors['walnut'], 0.045)
        profile('Shaped velvet seat back', (0, depth / 2 - 0.19, 0), [(horizontal * 0.91, 0.65 + (elevation - 0.58) * 0.85) for horizontal, elevation in outline], 0.11, colors['velvet'], 0.035)
        tube('Seat crest brass inlay', [(horizontal * 0.94, depth / 2 - 0.185, elevation - 0.045) for horizontal, elevation in outline[1:-1]], 0.016, colors['brass'])
        for horizontal in (-width / 2 + 0.065, width / 2 - 0.065):
            rod('Rolled velvet arm', (horizontal, -depth / 2 + 0.06, 0.88), (horizontal, depth / 2 - 0.08, 0.88), 0.12, colors['velvet'])
            rod('Carved arm support', (horizontal, -depth / 2 + 0.10, 0.46), (horizontal, -depth / 2 + 0.10, 0.88), 0.05, colors['polished'])
        for index in range(count * 2):
            horizontal = -width * 0.36 + index * width * 0.72 / max(count * 2 - 1, 1)
            ellipsoid('Backrest tuft button', (horizontal, depth / 2 - 0.26, 0.98), (0.032, 0.013, 0.032), colors['brass'])
        box('Loose silk seat cushion', (-width * 0.25, depth * 0.10, 0.79), (0.48, 0.38, 0.12), colors['silk'], 0.055).rotation_euler.z = 0.13
    placed_parts(build, center, angle)
    dimensions = (width + 0.1, depth + 0.08, 1.35)
    if abs(math.sin(angle)) > 0.5:
        dimensions = (dimensions[1], dimensions[0], dimensions[2])
    collider('Upholstered conversation seat', (center[0], center[1], center[2] + 0.675), dimensions)


def oval_table(center, width, depth, colors, height=0.76):
    top = cylinder('Oval polished table top', (center[0], center[1], center[2] + height), 1, 0.10, colors['polished'], 48)
    top.scale.x = width / 2
    top.scale.y = depth / 2
    edge = ring('Oval table brass edge', (center[0], center[1], center[2] + height + 0.045), 0.98, 0.018, colors['brass'])
    edge.scale.x = width / 2
    edge.scale.y = depth / 2
    for horizontal in (-width * 0.3, width * 0.3):
        lathe('Turned table pedestal', (center[0] + horizontal, center[1], center[2] + 0.08), [(0.19, 0), (0.13, 0.08), (0.08, 0.23), (0.14, 0.4), (0.16, height - 0.08)], colors['walnut'], 20)
        for offset in (-depth * 0.3, depth * 0.3):
            rod('Splayed table foot', (center[0] + horizontal, center[1], center[2] + 0.20), (center[0] + horizontal, center[1] + offset, center[2] + 0.08), 0.075, colors['walnut'])
    collider('Oval conversation table', (center[0], center[1], center[2] + height / 2), (width, depth, height + 0.1))


def cup(center, colors):
    cylinder('Ivory tea saucer', center, 0.145, 0.025, colors['ivory'], 24)
    lathe('Porcelain tea cup', (center[0], center[1], center[2] + 0.022), [(0.05, 0), (0.09, 0.035), (0.11, 0.14), (0.098, 0.15), (0.074, 0.045)], colors['ivory'], 20)
    ring('Tea cup gilt lip', (center[0], center[1], center[2] + 0.17), 0.105, 0.009, colors['brass'])
    ring('Tea cup handle', (center[0] + 0.12, center[1], center[2] + 0.1), 0.047, 0.012, colors['ivory'], (math.pi / 2, 0, 0))


def tea_service(center, colors):
    tray = cylinder('Silver service tray', center, 0.52, 0.035, colors['brass'], 36)
    tray.scale.y = 0.72
    lathe('Porcelain pear teapot', (center[0], center[1], center[2] + 0.04), [(0.12, 0), (0.20, 0.12), (0.19, 0.27), (0.12, 0.34), (0.10, 0.36)], colors['ivory'], 28)
    cylinder('Teapot gilt lid', (center[0], center[1], center[2] + 0.405), 0.12, 0.025, colors['brass'], 24)
    ellipsoid('Teapot lid finial', (center[0], center[1], center[2] + 0.445), (0.045, 0.045, 0.04), colors['brass'])
    tube('Curved teapot spout', [(center[0] + 0.14, center[1], center[2] + 0.18), (center[0] + 0.28, center[1], center[2] + 0.23), (center[0] + 0.31, center[1], center[2] + 0.38)], 0.035, colors['ivory'])
    ring('Teapot loop handle', (center[0] - 0.19, center[1], center[2] + 0.24), 0.14, 0.026, colors['ivory'], (math.pi / 2, 0, 0))
    for horizontal, offset in ((-0.74, -0.22), (0.63, 0.28)):
        cup((center[0] + horizontal, center[1] + offset, center[2]), colors)
    cylinder('Pastry plate', (center[0] + 0.90, center[1] - 0.18, center[2]), 0.22, 0.025, colors['ivory'], 24)
    for offset in (-0.085, 0.085):
        ellipsoid('Served small pastry', (center[0] + 0.90 + offset, center[1] - 0.18, center[2] + 0.06), (0.075, 0.065, 0.045), colors['paper'])


def salon_hearth(center, colors):
    box('Fitted hearth plaster chimney', (center[0], center[1] + 0.40, 1.9), (3.7, 0.75, 3.8), colors['plaster'], 0.05)
    box('Recessed black firebox', (center[0], center[1] - 0.005, 1.20), (2.25, 0.10, 2.25), colors['black'], 0.10)
    box('Marble hearth slab', (center[0], center[1] - 0.25, 0.12), (3.9, 1.55, 0.24), colors['marble'], 0.065, True)
    for side in (-1, 1):
        horizontal = center[0] + side * 1.42
        box('Marble fireplace pilaster foot', (horizontal, center[1] - 0.14, 0.39), (0.6, 0.62, 0.42), colors['marble'], 0.035)
        lathe('Carved marble fireplace column', (horizontal, center[1] - 0.14, 0.58), [(0.20, 0), (0.18, 0.12), (0.12, 0.26), (0.12, 1.52), (0.20, 1.65)], colors['marble'], 24)
        box('Marble fireplace capital', (horizontal, center[1] - 0.14, 2.34), (0.61, 0.63, 0.20), colors['marble'], 0.035)
    arch_points = [(center[0] + math.cos(index * math.pi / 16) * 1.11, center[1] - 0.17, 1.63 + math.sin(index * math.pi / 16) * 0.86) for index in range(17)]
    tube('Carved arched hearth molding', arch_points, 0.085, colors['brass'])
    box('Fireplace overmantel shelf', (center[0], center[1] - 0.12, 2.66), (3.65, 1.08, 0.24), colors['marble'], 0.06)
    box('Fireplace inset overmantel', (center[0], center[1] - 0.02, 3.16), (2.8, 0.10, 0.53), colors['walnut'], 0.035)
    label('THE EVENING ROOM', (center[0], center[1] - 0.09, 3.1), 0.15, colors['brass'])
    for horizontal in (-0.61, 0, 0.61):
        rod('Resting hearth log', (center[0] + horizontal - 0.2, center[1] - 0.20, 0.35), (center[0] + horizontal + 0.2, center[1] - 0.74, 0.35), 0.16, colors['walnut'])
        ellipsoid('Banked hearth glow', (center[0] + horizontal, center[1] - 0.39, 0.31), (0.25, 0.28, 0.09), colors['ember'])
    for horizontal in (-0.82, -0.41, 0, 0.41, 0.82):
        rod('Hearth grate upright', (center[0] + horizontal, center[1] - 0.8, 0.15), (center[0] + horizontal, center[1] - 0.8, 0.60), 0.025, colors['iron'])
    rod('Hearth grate rail', (center[0] - 0.95, center[1] - 0.8, 0.47), (center[0] + 0.95, center[1] - 0.8, 0.47), 0.03, colors['iron'])
    collider('Fitted parlor hearth', (center[0], center[1], 1.9), (3.75, 1.20, 3.8))


def game_table(center, colors):
    oval_table(center, 2.25, 1.85, colors, 0.83)
    for row in range(8):
        for column in range(8):
            box('Marquetry game board square', (center[0] - 0.49 + column * 0.14, center[1] - 0.49 + row * 0.14, 0.896), (0.14, 0.14, 0.015), colors['ivory' if (row + column) % 2 else 'walnut'], 0)
    for side, surface in ((-1, colors['ivory']), (1, colors['black'])):
        for index in range(6):
            horizontal = center[0] - 0.42 + index * 0.14
            offset = center[1] + side * (0.35 if index % 3 else 0.07)
            lathe('Chess pawn in unfinished game', (horizontal, offset, 0.92), [(0.045, 0), (0.034, 0.025), (0.020, 0.075), (0.035, 0.105), (0.027, 0.13), (0.005, 0.14)], surface, 12)
        for horizontal in (-0.43, 0.40):
            lathe('Remaining carved royal chess piece', (center[0] + horizontal, center[1] + side * 0.48, 0.92), [(0.05, 0), (0.035, 0.04), (0.023, 0.13), (0.035, 0.15), (0.018, 0.20)], surface, 12)
    box('Folded score card', (center[0] + 0.81, center[1], 0.903), (0.32, 0.43, 0.02), colors['paper'], 0.005)
    rod('Game score pencil', (center[0] + 0.68, center[1] - 0.14, 0.93), (center[0] + 0.94, center[1] + 0.13, 0.93), 0.012, colors['walnut'])


def build_parlor():
    create_scene('Mirror parlor evening conversation')
    colors = palette()
    salon_hearth((43.0, -0.95, 0), colors)
    for horizontal, width in ((30.7, 2.4), (38.8, 2.5), (46.15, 1.4)):
        box('Fitted walnut parlor wall panel', (horizontal, -0.43, 1.8), (width, 0.15, 3.6), colors['walnut'], 0.035)
        for side in (-1, 1):
            box('Gilt boiserie upright', (horizontal + side * (width / 2 - 0.12), -0.54, 1.8), (0.045, 0.05, 3.25), colors['brass'], 0.01)
        box('Gilt boiserie crown', (horizontal, -0.54, 3.4), (width - 0.20, 0.05, 0.045), colors['brass'], 0.01)
    rug = cylinder('Oval woven conversation rug', (43.0, -6.35, 0.085), 1, 0.018, colors['velvet'], 64)
    rug.scale = (3.95, 4.85, 1)
    trim = ring('Woven rug double border', (43.0, -6.35, 0.101), 0.95, 0.006, colors['paper'])
    trim.scale = (3.95, 4.85, 1)
    upholstery((43.0, -3.70, 0), 3.60, colors)
    upholstery((43.0, -9.05, 0), 3.60, colors, math.pi)
    oval_table((43.0, -6.4, 0), 3.0, 1.28, colors)
    tea_service((42.88, -6.4, 0.82), colors)
    game_table((32.6, -8.8, 0), colors)
    upholstery((30.50, -8.8, 0), 1.05, colors, math.pi / 2)
    upholstery((34.7, -8.60, 0), 1.05, colors, -math.pi / 2)
    oval_table((30.7, -2.0, 0), 2.35, 1.05, colors, 0.94)
    box('Parlor correspondence blotter', (30.7, -2.0, 1.00), (1.6, 0.7, 0.018), colors['velvet'], 0.02)
    for index in range(3):
        box('Unanswered sealed letter', (30.35 + index * 0.25, -2.05 + index * 0.09, 1.03 + index * 0.01), (0.40, 0.28, 0.015), colors['paper'], 0.005).rotation_euler.z = index * 0.1
        cylinder('Letter wax seal', (30.35 + index * 0.25, -2.05 + index * 0.09, 1.045 + index * 0.01), 0.045, 0.014, colors['silk'], 12)
    lathe('Correspondence ink bottle', (31.45, -2.0, 1.02), [(0.07, 0), (0.08, 0.10), (0.04, 0.14), (0.04, 0.20)], colors['ink'], 16)
    rod('Resting writing quill', (31.18, -1.91, 1.03), (31.44, -2.05, 1.43), 0.016, colors['ivory'])
    export_asset(arguments.output / 'parlor.glb', colors['stone'])


def portrait_surface(path):
    surface = material('Original portrait | ' + path.stem, (1, 1, 1), 0, 0.95)
    texture = surface.node_tree.nodes.new('ShaderNodeTexImage')
    texture.image = bpy.data.images.load(str(path), check_existing=True)
    surface.node_tree.links.new(texture.outputs['Color'], surface.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])
    return surface


def portrait_frame(center, width, height, colors, title, texture=None):
    box('Gallery canvas stretcher', center, (width, 0.12, height), colors['walnut'], 0.04)
    for inset, depth, thickness, surface in ((0, 0.03, 0.11, colors['polished']), (0.1, -0.045, 0.042, colors['brass']), (0.16, -0.06, 0.040, colors['walnut'])):
        for side in (-1, 1):
            box('Carved picture frame stile', (center[0] + side * (width / 2 - inset), center[1] + depth, center[2]), (thickness, 0.16, height - inset * 2), surface, 0.018)
            box('Carved picture frame rail', (center[0], center[1] + depth, center[2] + side * (height / 2 - inset)), (width - inset * 2, 0.16, thickness), surface, 0.018)
    for side in (-1, 1):
        ellipsoid('Frame carved corner rosette', (center[0] + side * (width / 2 - 0.09), center[1] - 0.095, center[2] + height / 2 - 0.09), (0.11, 0.04, 0.11), colors['brass'])
    if texture:
        bpy.ops.mesh.primitive_plane_add(size=1, location=(center[0], center[1] - 0.09, center[2]), rotation=(math.pi / 2, 0, 0))
        obj = finish(bpy.context.object, 'Original preserved ancestral painting', portrait_surface(texture))
        obj.scale = (width - 0.37, height - 0.37, 1)
    plaque(title, (center[0], center[1] - 0.09, center[2] - height / 2 - 0.25), width * 0.72, colors)


def medallion(center, title, kind, colors):
    border = ring('Oval gilded ancestral cartouche', center, 1, 0.085, colors['brass'], (math.pi / 2, 0, 0))
    border.scale = (0.79, 1, 1.1)
    ellipsoid('Inset velvet medallion field', (center[0], center[1] + 0.07, center[2]), (0.77, 0.10, 1.06), colors['velvet'])
    ellipsoid('Ancestral relief shoulders', (center[0], center[1] - 0.09, center[2] - 0.57), (0.51, 0.17, 0.27), colors['ivory'])
    ellipsoid('Ancestral relief head', (center[0], center[1] - 0.11, center[2] + 0.05), (0.29, 0.21, 0.40), colors['ivory'])
    ellipsoid('Carved ancestral nose', (center[0], center[1] - 0.31, center[2] + 0.015), (0.055, 0.06, 0.10), colors['stone'])
    for side in (-1, 1):
        ellipsoid('Carved inset eye', (center[0] + side * 0.10, center[1] - 0.297, center[2] + 0.13), (0.05, 0.015, 0.022), colors['walnut'])
        for index in range(3):
            ellipsoid('Sculpted ancestral hair lock', (center[0] + side * 0.28, center[1] - 0.08, center[2] + 0.28 - index * 0.21), (0.115, 0.12, 0.14), colors['stone'])
    rod('Relief ceremonial collar', (center[0] - 0.20, center[1] - 0.235, center[2] - 0.28), (center[0] + 0.20, center[1] - 0.235, center[2] - 0.28), 0.037, colors['brass'])
    if kind == 'crown':
        profile('Founder crown silhouette', (center[0], center[1] - 0.17, center[2] + 0.39), [(-0.34, 0), (-0.37, 0.34), (-0.18, 0.15), (0, 0.43), (0.18, 0.15), (0.37, 0.34), (0.34, 0)], 0.10, colors['brass'], 0.02)
    elif kind == 'star':
        profile('Astronomer ceremonial cap', (center[0], center[1] - 0.17, center[2] + 0.38), [(-0.36, 0), (-0.26, 0.12), (-0.02, 0.67), (0.13, 0.41), (0.30, 0.08), (0.36, 0)], 0.10, colors['ink'], 0.018)
        ring('Astronomer relief astrolabe', (center[0] + 0.30, center[1] - 0.28, center[2] - 0.48), 0.18, 0.027, colors['brass'], (math.pi / 2, 0, 0))
    else:
        for index in range(5):
            angle = index * math.tau / 5
            ellipsoid('Rose warden heraldic petal', (center[0] + math.cos(angle) * 0.09, center[1] - 0.28, center[2] - 0.49 + math.sin(angle) * 0.09), (0.07, 0.025, 0.07), colors['silk'])
        ellipsoid('Rose warden heraldic center', (center[0], center[1] - 0.31, center[2] - 0.49), (0.045, 0.015, 0.045), colors['brass'])
    plaque(title, (center[0], center[1] - 0.08, center[2] - 1.37), 1.55, colors)


def gallery_pilaster(horizontal, colors):
    box('Gallery pilaster limestone footing', (horizontal, -20.61, 0.20), (0.68, 0.70, 0.40), colors['stone'], 0.045, True)
    box('Gallery fluted walnut pilaster', (horizontal, -20.40, 1.85), (0.37, 0.28, 3.30), colors['walnut'], 0.035)
    for offset in (-0.11, 0, 0.11):
        rod('Pilaster slender gilt flute', (horizontal + offset, -20.57, 0.52), (horizontal + offset, -20.57, 3.18), 0.012, colors['brass'])
    box('Gallery carved pilaster capital', (horizontal, -20.47, 3.51), (0.74, 0.43, 0.29), colors['polished'], 0.035)
    for side in (-1, 1):
        ring('Gallery capital scroll', (horizontal + side * 0.20, -20.71, 3.46), 0.105, 0.026, colors['brass'], (math.pi / 2, 0, 0))


def viewing_bench(center, width, colors):
    box('Gallery viewing bench walnut apron', (center[0], center[1], 0.42), (width, 0.95, 0.22), colors['polished'], 0.065)
    for side in (-1, 1):
        box('Gallery carved bench trestle', (center[0] + side * (width / 2 - 0.26), center[1], 0.22), (0.17, 0.75, 0.44), colors['walnut'], 0.045)
    for index in range(3):
        box('Gallery low velvet bench cushion', (center[0] - width / 2 + (index + 0.5) * width / 3, center[1], 0.60), (width / 3 - 0.06, 0.88, 0.19), colors['velvet'], 0.075)
    collider('Gallery viewing bench', (center[0], center[1], 0.34), (width, 0.97, 0.70))


def curation_station(colors):
    box('Curator flat file cabinet', (-22.02, -37.8, 0.65), (2.1, 3.6, 1.3), colors['walnut'], 0.055, True)
    box('Curator canvas worktop', (-22.02, -37.8, 1.34), (2.25, 3.75, 0.12), colors['polished'], 0.05)
    for depth in (-36.6, -37.8, -39.0):
        for elevation in (0.31, 0.65, 0.99):
            box('Curator shallow catalogue drawer', (-20.935, depth, elevation), (0.08, 1.0, 0.23), colors['polished'], 0.025)
            ring('Curator drawer brass pull', (-20.87, depth, elevation), 0.06, 0.013, colors['brass'], (0, math.pi / 2, 0))
    box('Curator protective linen mat', (-22.0, -37.6, 1.411), (1.65, 1.7, 0.018), colors['canvas'], 0.01)
    for side in (-1, 1):
        page = box('Open provenance ledger page', (-21.9 + side * 0.25, -37.8, 1.45), (0.48, 0.72, 0.035), colors['paper'], 0.01)
        page.rotation_euler.y = side * 0.06
        for index in range(5):
            box('Ledger handwritten inventory line', (-21.9 + side * 0.25, -38.03 + index * 0.1, 1.481), (0.33, 0.011, 0.003), colors['ink'], 0)
    for offset in (-0.20, 0, 0.20):
        rod('Restorer fine brush handle', (-22.2 + offset, -36.5, 1.46), (-22.05 + offset, -36.1, 1.46), 0.019, colors['walnut'])
        rod('Restorer brush bristles', (-22.05 + offset, -36.1, 1.46), (-22.02 + offset, -35.99, 1.46), 0.022, colors['ivory'])
    ring('Curator magnifying glass frame', (-22.3, -38.65, 1.46), 0.17, 0.018, colors['brass'])
    rod('Curator magnifier handle', (-22.3, -38.8, 1.46), (-22.3, -39.16, 1.46), 0.03, colors['walnut'])
    for depth in (-40.1, -40.7):
        roll = cylinder('Unframed rolled canvas', (-22.45, depth, 0.46), 0.18, 1.45, colors['canvas'], 20)
        roll.rotation_euler.y = math.pi / 2
    collider('Stored rolled canvases', (-22.45, -40.4, 0.42), (1.65, 1.0, 0.84))
    for depth, width in ((-36.4, 1.4), (-40.2, 1.8)):
        def frame_parts():
            for side in (-1, 1):
                box('Stored empty portrait frame stile', (side * width / 2, 0, 0), (0.10, 0.15, 2.0), colors['brass'], 0.025)
                box('Stored empty portrait frame rail', (0, 0, side), (width, 0.15, 0.10), colors['brass'], 0.025)
        placed_parts(frame_parts, (-23.43, depth, 2.45), math.pi / 2)


def build_gallery():
    create_scene('Ancestral gallery and curators turn')
    colors = palette()
    for horizontal in (-23.1, -20.45, -15.5, -11.7, -9.9, -5.4, -3.5, 0.9, 3.1, 6.9, 11.05):
        gallery_pilaster(horizontal, colors)
    portrait_frame((-7.7, -20.60, 2.325), 2.6, 3.15, colors, 'SIR ROWAN / THE FIRST WATCH', asset_root / 'portrait_knight.png')
    portrait_frame((-1.2, -20.60, 2.2), 2.4, 2.9, colors, 'THE LAST STEWARD / STILL IN SERVICE', asset_root / 'portrait_skeleton_minion.png')
    for horizontal, title, kind in ((-21.77, 'THE FOUNDER / 01', 'crown'), (-13.6, 'THE ROSE WARDEN / 03', 'rose'), (5.0, 'THE STARGAZER / 07', 'star')):
        medallion((horizontal, -20.62, 2.05), title, kind, colors)
    for horizontal, width in ((-7.7, 4.3), (-1.2, 4.2), (5.0, 3.5)):
        points = [(horizontal - width / 2, -20.57, 3.70), (horizontal - width * 0.3, -20.57, 3.92), (horizontal, -20.57, 4.10), (horizontal + width * 0.3, -20.57, 3.92), (horizontal + width / 2, -20.57, 3.70)]
        tube('Gallery shallow arched pediment', points, 0.045, colors['polished'])
    portrait_frame((9.2, -20.60, 2.05), 1.6, 2.6, colors, 'THE HOUSE SEAL')
    ring('House heraldic ring', (9.2, -20.73, 2.12), 0.49, 0.035, colors['brass'], (math.pi / 2, 0, 0))
    for side in (-1, 1):
        rod('Crossed ceremonial keys', (9.2 + side * 0.29, -20.77, 1.76), (9.2 - side * 0.25, -20.77, 2.48), 0.025, colors['ivory'])
        ring('Ceremonial key bow', (9.2 - side * 0.28, -20.77, 2.53), 0.105, 0.022, colors['ivory'], (math.pi / 2, 0, 0))
    for horizontal, width in ((-11, 2.7), (0.2, 3.8), (8.3, 3.1)):
        viewing_bench((horizontal, -30.6, 0), width, colors)
    for horizontal in (-14.4, -3.3, 7.4):
        cylinder('Gallery round walnut floor inlay', (horizontal, -26.0, 0.083), 1.25, 0.018, colors['walnut'], 48)
        ring('Gallery inlaid compass border', (horizontal, -26.0, 0.10), 1.12, 0.012, colors['brass'])
        for index in range(16):
            angle = index * math.tau / 16
            following_angle = (index + 1) * math.tau / 16
            radius = 0.90 if index % 2 == 0 else 0.29
            following_radius = 0.90 if (index + 1) % 2 == 0 else 0.29
            mesh = bpy.data.meshes.new('Parquet compass ray')
            mesh.from_pydata([(horizontal, -26.0, 0.10), (horizontal + math.cos(angle) * radius, -26.0 + math.sin(angle) * radius, 0.10), (horizontal + math.cos(following_angle) * following_radius, -26.0 + math.sin(following_angle) * following_radius, 0.10)], [], [(0, 1, 2)])
            mesh.update()
            finish(bpy.data.objects.new('Parquet eight-point compass rose', mesh), 'Parquet eight-point compass rose', colors['paper' if index % 2 else 'polished'])
    curation_station(colors)
    upholstery((-19.8, -37.8, 0), 1.05, colors, -math.pi / 2)
    export_asset(arguments.output / 'gallery.glb', colors['stone'])


build_parlor()
build_gallery()
