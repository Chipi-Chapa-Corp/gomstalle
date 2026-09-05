import argparse
import math
from pathlib import Path
import sys
import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from workshop_geometry import box, collider, create_scene, cylinder, export_asset, finish, label, lathe, material, profile, ring, rod, tube

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
arguments = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])


def palette():
    return {
        'stone': material('Memorial | blue limestone', (0.19, 0.24, 0.27)),
        'pale': material('Memorial | carved alabaster', (0.54, 0.55, 0.48)),
        'dark': material('Memorial | deep carved recess', (0.027, 0.04, 0.052)),
        'gold': material('Memorial | aged gilt bronze', (0.47, 0.29, 0.10), 0.7, 0.4),
        'wood': material('Memorial | dark choir oak', (0.15, 0.072, 0.038)),
        'edge': material('Memorial | polished oak edges', (0.27, 0.13, 0.063)),
        'cloth': material('Memorial | worn midnight brocade', (0.052, 0.10, 0.18)),
        'wax': material('Memorial | honey beeswax', (0.74, 0.52, 0.22)),
        'flame': material('Memorial | candle flame', (1.0, 0.50, 0.12), 0, 0.7, 2.6),
        'bone': material('Memorial | aged bone', (0.57, 0.48, 0.33)),
        'iron': material('Memorial | blackened wrought iron', (0.055, 0.065, 0.07), 0.65, 0.4),
        'red': material('Memorial | oxblood velvet', (0.20, 0.028, 0.036)),
        'paper': material('Memorial | vellum', (0.62, 0.52, 0.34)),
        'glass': material('Memorial | turquoise enamel', (0.035, 0.24, 0.28), 0.3, 0.32),
    }


def oval(name, center, dimensions, surface):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=8, radius=1, location=center)
    obj = finish(bpy.context.object, name, surface)
    obj.scale = dimensions
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def candle(center, height, colors):
    cylinder('Wax spill saucer', center, 0.14, 0.025, colors['gold'], 16)
    cylinder('Hand poured beeswax candle', (center[0], center[1], center[2] + height / 2), 0.068, height, colors['wax'], 12)
    for side in (-1, 1):
        oval('Uneven wax drip', (center[0] + side * 0.053, center[1], center[2] + height * 0.68), (0.028, 0.032, height * 0.17), colors['wax'])
    oval('Small living candle flame', (center[0], center[1], center[2] + height + 0.065), (0.033, 0.033, 0.09), colors['flame'])


def pointed_panel(name, center, width, height, colors):
    outline = [(-width / 2, 0), (-width / 2, height * 0.69), (-width * 0.35, height * 0.88), (0, height), (width * 0.35, height * 0.88), (width / 2, height * 0.69), (width / 2, 0)]
    profile(name, center, outline, 0.18, colors['wood'], 0.03)
    tube('Gilt pointed tracery border', [(center[0] + horizontal * 0.91, center[1] - 0.11, center[2] + 0.08 + elevation * 0.94) for horizontal, elevation in outline], 0.026, colors['gold'])


def pew(center, width, colors):
    box('Choir pew seat', (center[0], center[1], 0.55), (width, 0.82, 0.16), colors['edge'], 0.045)
    box('Choir pew low back', (center[0], center[1] - 0.34, 0.88), (width, 0.13, 0.62), colors['wood'], 0.03)
    box('Choir pew hymn shelf', (center[0], center[1] - 0.48, 0.98), (width - 0.12, 0.27, 0.075), colors['edge'])
    for side in (-1, 1):
        horizontal = center[0] + side * (width / 2 - 0.10)
        box('Carved pew cheek', (horizontal, center[1], 0.54), (0.20, 1.05, 1.07), colors['wood'], 0.07)
        cylinder('Pew cheek rosette', (horizontal, center[1], 1.09), 0.16, 0.20, colors['gold'], 16).rotation_euler.y = math.pi / 2
    box('Kneeler velvet cushion', (center[0], center[1] + 0.74, 0.18), (width - 0.5, 0.35, 0.16), colors['cloth'], 0.045)
    for horizontal in (-0.8, 0.6):
        box('Resting bound hymn book', (center[0] + horizontal, center[1] - 0.48, 1.045), (0.27, 0.20, 0.055), colors['red'])
    collider('Choir pew and kneeler', (center[0], center[1] + 0.13, 0.57), (width + 0.12, 1.46, 1.14))


def build_chapel():
    create_scene('Candle chapel of the last watch')
    colors = palette()
    box('Long processional aisle runner', (-6, -38, 0.035), (2.2, 10.0, 0.045), colors['cloth'], 0)
    for horizontal in (-6.97, -5.03):
        box('Runner gilt woven edge', (horizontal, -38, 0.06), (0.035, 10, 0.012), colors['gold'], 0)
    for horizontal, width, height in ((0.5, 2.6, 3.25), (3.5, 3.0, 4.2), (6.5, 2.6, 3.25)):
        pointed_panel('Memorial carved triptych', (horizontal, -32.72, 0.6), width, height, colors)
        ring('Triptych halo', (horizontal, -32.85, 2.7), 0.56, 0.045, colors['gold'], (math.pi / 2, 0, 0), 24)
        profile('Gilt votive sun ray', (horizontal, -32.90, 1.22), [(-0.12, 0), (-0.38, 0.8), (0, 1.8), (0.38, 0.8), (0.12, 0)], 0.055, colors['glass'], 0.01)
    box('Alabaster altar foot', (3.5, -33.7, 0.17), (5.7, 1.6, 0.34), colors['stone'], 0.06)
    box('Carved altar chest', (3.5, -33.7, 0.79), (5.25, 1.27, 1.1), colors['pale'], 0.07)
    box('Overhanging altar mensa', (3.5, -33.7, 1.42), (5.8, 1.60, 0.22), colors['pale'], 0.055)
    box('Velvet altar hanging', (3.5, -34.365, 0.92), (2.35, 0.045, 0.92), colors['cloth'], 0.015)
    ring('Embroidered altar sun', (3.5, -34.40, 0.94), 0.27, 0.024, colors['gold'], (math.pi / 2, 0, 0), 24)
    for horizontal in (1.15, 1.6, 2.02, 4.98, 5.4, 5.85):
        candle((horizontal, -33.7, 1.55), 0.25 + 0.13 * math.sin(horizontal * 2) ** 2, colors)
    box('Open memorial register vellum', (3.5, -33.85, 1.58), (1.05, 0.58, 0.09), colors['paper'], 0.015)
    label('KEEP THE LAST LIGHT', (3.5, -34.43, 1.11), 0.12, colors['gold'])
    collider('Memorial altar', (3.5, -33.7, 0.82), (5.8, 1.65, 1.65))
    for depth in (37.7, 40.8):
        pew((-0.6, -depth, 0), 4.0, colors)
        pew((6.2, -depth, 0), 4.0, colors)
    for depth in (34.2, 39.4):
        box('Votive rack stone plinth', (-10.0, -depth, 0.28), (1.45, 2.05, 0.55), colors['stone'], 0.04)
        for tier in range(3):
            box('Wrought votive candle tier', (-10.0, -depth + tier * 0.30, 0.90 + tier * 0.29), (1.25, 0.25, 0.065), colors['iron'])
            for column in range(4):
                candle((-10.45 + column * 0.30, -depth + tier * 0.30, 0.95 + tier * 0.29), 0.12 + 0.12 * ((column + tier) % 3), colors)
        collider('Memorial votive candle rack', (-10, -depth + 0.25, 0.90), (1.55, 2.10, 1.8))
    export_asset(arguments.output / 'chapel.glb', colors['stone'])


def tomb(center, width, length, colors, royal=False):
    box('Tomb stepped stone foot', (center[0], center[1], 0.16), (width + 0.30, length + 0.30, 0.32), colors['stone'], 0.05)
    box('Carved burial chest', (center[0], center[1], 0.70), (width, length, 0.90), colors['pale'], 0.08)
    box('Chamfered effigy tomb lid', (center[0], center[1], 1.21), (width + 0.18, length + 0.16, 0.22), colors['pale'], 0.09)
    box('Stone effigy pillow', (center[0], center[1] + length * 0.31, 1.40), (width * 0.69, 0.58, 0.20), colors['stone'], 0.08)
    oval('Reclining carved noble head', (center[0], center[1] + length * 0.30, 1.61), (0.28, 0.32, 0.22), colors['pale'])
    oval('Carved folded royal cloak', (center[0], center[1] - 0.12, 1.43), (width * 0.35, length * 0.31, 0.16), colors['stone'])
    for side in (-1, 1):
        rod('Effigy resting forearm', (center[0] + side * 0.45, center[1] + 0.47, 1.48), (center[0] + side * 0.09, center[1], 1.57), 0.10, colors['pale'])
        oval('Effigy joined hands', (center[0] + side * 0.06, center[1] - 0.06, 1.61), (0.07, 0.15, 0.06), colors['pale'])
    box('Ceremonial sword on effigy', (center[0], center[1] - 0.55, 1.62), (0.11, 1.30, 0.035), colors['gold'])
    box('Ceremonial sword crossguard', (center[0], center[1] - 0.02, 1.64), (0.46, 0.08, 0.045), colors['gold'])
    if royal:
        ring('Effigy royal circlet', (center[0], center[1] + length * 0.30, 1.68), 0.285, 0.035, colors['gold'], segments=24)
        for side in (-1, 1):
            for depth in (-0.85, 0.0, 0.85):
                ring('Burial chest bronze rosette', (center[0] + side * (width / 2 + 0.015), center[1] + depth, 0.78), 0.14, 0.03, colors['gold'], (0, math.pi / 2, 0), 16)
    collider('Effigy tomb', (center[0], center[1], 0.85), (width + 0.32, length + 0.32, 1.7))


def build_crypt():
    create_scene('Royal crypt of the sleeping court')
    colors = palette()
    canopy_colors = {**colors, 'wood': colors['stone']}
    for horizontal in (-30.0, -27.0, -24.0):
        pointed_panel('Royal memorial wall canopy', (horizontal, -44.85, 0.3), 2.8, 4.45 if horizontal == -27 else 3.65, canopy_colors)
        label('THE SLEEPING COURT' if horizontal == -27 else 'IN SILENT VIGIL', (horizontal, -44.98, 2.8), 0.13, colors['gold'])
    for horizontal in (-31.7, -22.3):
        lathe('Royal canopy fluted pillar', (horizontal, -45.1, 0), [(0.30, 0), (0.30, 0.18), (0.19, 0.28), (0.19, 3.20), (0.32, 3.32), (0.32, 3.52)], colors['pale'], 16)
        collider('Royal canopy wall pillar', (horizontal, -45.1, 1.76), (0.68, 0.68, 3.52))
    tomb((-27, -48.0, 0), 2.7, 4.0, colors, True)
    for horizontal, depth in ((-32, 56), (-19.3, 51.5), (-19.3, 62.8), (-32, 63.2)):
        tomb((horizontal, -depth, 0), 1.85, 3.2, colors)
        candle((horizontal + 0.59, -depth - 1.0, 1.34), 0.24, colors)
    for radius in (2.4, 2.65):
        ring('Inlaid dynastic floor seal', (-26, -56.6, 0.065), radius, 0.022, colors['gold'], segments=64)
    for index in range(8):
        angle = index * math.tau / 8
        rod('Heraldic floor compass ray', (-26 + math.cos(angle) * 0.45, -56.6 + math.sin(angle) * 0.45, 0.065), (-26 + math.cos(angle) * 2.1, -56.6 + math.sin(angle) * 2.1, 0.065), 0.018, colors['gold'])
    for horizontal in (-30.7, -23.3):
        lathe('Royal vigil bronze candlestand', (horizontal, -47.5, 0), [(0.35, 0), (0.31, 0.14), (0.12, 0.27), (0.07, 1.1), (0.18, 1.25), (0.31, 1.30)], colors['gold'], 20)
        candle((horizontal, -47.5, 1.32), 0.46, colors)
        collider('Royal vigil candlestand', (horizontal, -47.5, 0.9), (0.75, 0.75, 1.8))
    box('Caretaker offering shelf', (-34.4, -50.8, 0.72), (1.4, 2.6, 1.44), colors['wood'], 0.035, True)
    for depth in (50.2, 51.2):
        box('Folded burial cloth', (-34.4, -depth, 1.50), (1.02, 0.70, 0.10), colors['cloth'], 0.04)
        candle((-34.4, -depth, 1.58), 0.27, colors)
    export_asset(arguments.output / 'crypt.glb', colors['stone'])


def skull(center, colors):
    oval('Ossuary rounded cranium', center, (0.16, 0.125, 0.18), colors['bone'])
    box('Ossuary upper jaw', (center[0], center[1] - 0.067, center[2] - 0.12), (0.20, 0.13, 0.11), colors['bone'], 0.025)
    for side in (-1, 1):
        oval('Hollow skull eye socket', (center[0] + side * 0.064, center[1] - 0.112, center[2]), (0.045, 0.023, 0.055), colors['dark'])
    oval('Skull nose opening', (center[0], center[1] - 0.137, center[2] - 0.07), (0.022, 0.018, 0.029), colors['dark'])


def bone(start, end, colors):
    rod('Sorted long bone shaft', start, end, 0.035, colors['bone'])
    for point in (start, end):
        for side in (-1, 1):
            oval('Bone joint condyle', (point[0] + side * 0.035, point[1], point[2]), (0.045, 0.05, 0.05), colors['bone'])


def bone_cabinet(center, colors):
    box('Mortuary niche stone backing', (center[0], center[1] + 0.18, 1.9), (3.5, 0.35, 3.8), colors['stone'], 0.04)
    box('Mortuary niche dark inset', (center[0], center[1] - 0.035, 1.9), (3.12, 0.08, 3.35), colors['dark'], 0.015)
    for tier in range(4):
        elevation = 0.43 + tier * 0.82
        box('Stone ossuary niche shelf', (center[0], center[1] - 0.38, elevation), (3.4, 0.92, 0.10), colors['pale'])
        for column in range(6):
            horizontal = center[0] - 1.3 + column * 0.52
            skull((horizontal, center[1] - 0.43, elevation + 0.25), colors)
        for horizontal in (-0.8, 0.8):
            box('Niche carved divider', (center[0] + horizontal, center[1] - 0.34, elevation + 0.41), (0.10, 0.82, 0.72), colors['pale'])
    label('NAMES ARE KEPT', (center[0], center[1] - 0.08, 3.56), 0.15, colors['gold'])
    collider('Fitted bone niche cabinet', (center[0], center[1] - 0.25, 1.9), (3.55, 1.12, 3.8))


def build_ossuary():
    create_scene('Ossuary bone archivists workshop')
    colors = palette()
    bone_cabinet((-32.8, -68.85, 0), colors)
    bone_cabinet((-22.65, -68.85, 0), colors)
    for horizontal, depth, width in ((-32.4, 76, 3.3), (-23.4, 77, 2.6)):
        box('Mortuary preparation bench top', (horizontal, -depth, 0.98), (width, 1.65, 0.15), colors['edge'], 0.04)
        for side in (-1, 1):
            box('Mortuary bench trestle', (horizontal + side * (width / 2 - 0.22), -depth, 0.48), (0.18, 1.45, 0.91), colors['wood'], 0.025)
        box('Preparation linen cloth', (horizontal, -depth, 1.072), (width - 0.35, 1.20, 0.026), colors['paper'], 0.015)
        for offset in (-0.5, 0, 0.5):
            bone((horizontal + offset, -depth - 0.38, 1.14), (horizontal + offset + 0.12, -depth + 0.36, 1.14), colors)
        skull((horizontal - width * 0.31, -depth, 1.25), colors)
        candle((horizontal + width * 0.33, -depth + 0.4, 1.08), 0.28, colors)
        collider('Mortuary working table', (horizontal, -depth, 0.62), (width, 1.68, 1.25))
    for depth in (83, 88):
        box('Coffin-rest trestle foot', (-33.0, -depth, 0.24), (2.3, 1.9, 0.48), colors['wood'], 0.035)
        outline = [(-0.72, 0), (-1.0, 0.9), (-0.85, 2.65), (0.85, 2.65), (1.0, 0.9), (0.72, 0)]
        coffin = profile('Open polygonal coffin frame', (-33.0, -depth - 1.3, 0.60), outline, 0.60, colors['wood'], 0.05)
        coffin.rotation_euler.x = -math.pi / 2
        box('Coffin velvet lining', (-33, -depth, 0.92), (1.35, 2.0, 0.08), colors['red'], 0.04)
        collider('Coffin-rest bay', (-33, -depth, 0.7), (2.35, 3.0, 1.4))
    box('Ossuary record keeper lectern', (-23.4, -89.2, 0.58), (1.70, 1.25, 1.16), colors['wood'], 0.035, True)
    box('Open register of the departed', (-23.4, -89.2, 1.21), (1.30, 0.83, 0.08), colors['paper'], 0.015)
    candle((-24.0, -89.5, 1.27), 0.26, colors)
    for radius in (1.9, 2.1):
        ring('Bone keeper floor mosaic', (-27.7, -81, 0.06), radius, 0.025, colors['bone'], segments=48)
    for index in range(12):
        angle = index * math.tau / 12
        start = (-27.7 + math.cos(angle) * 1.28, -81 + math.sin(angle) * 1.28, 0.065)
        end = (-27.7 + math.cos(angle) * 1.78, -81 + math.sin(angle) * 1.78, 0.065)
        rod('Mosaic bone ray', start, end, 0.025, colors['bone'])
        for point in (start, end):
            cylinder('Mosaic bone joint', point, 0.065, 0.012, colors['bone'], 8)
    export_asset(arguments.output / 'ossuary.glb', colors['stone'])


build_chapel()
build_crypt()
build_ossuary()
