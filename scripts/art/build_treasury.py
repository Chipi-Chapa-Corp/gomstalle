import argparse
import math
from pathlib import Path
import sys
import bpy

sys.path.insert(0, str(Path(__file__).resolve().parent))
from workshop_geometry import bench, box, collider, create_scene, cylinder, export_asset, label, lathe, material, profile, ring, rod, scales, tube

parser = argparse.ArgumentParser()
parser.add_argument('--output', type=Path, required=True)
arguments = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])


def palette():
    return {
        'oak': material('Treasury | iron-dark oak', (0.08, 0.052, 0.036)),
        'oak_top': material('Treasury | worn counting oak', (0.22, 0.125, 0.063)),
        'iron': material('Treasury | blackened iron', (0.050, 0.07, 0.08), 0.7, 0.36),
        'brass': material('Treasury | aged brass', (0.42, 0.265, 0.085), 0.7, 0.35),
        'gold': material('Treasury | assayed gold', (0.70, 0.43, 0.065), 0.82, 0.27),
        'silver': material('Treasury | assayed silver', (0.53, 0.60, 0.63), 0.82, 0.3),
        'copper': material('Treasury | minted copper', (0.40, 0.16, 0.065), 0.73, 0.35),
        'leather': material('Treasury | oxblood ledger leather', (0.17, 0.025, 0.035)),
        'paper': material('Treasury | tally paper', (0.63, 0.51, 0.30)),
        'ink': material('Treasury | tally ink', (0.021, 0.037, 0.043)),
        'linen': material('Treasury | coin sack linen', (0.25, 0.22, 0.13)),
        'stone': material('Treasury | pale stone', (0.28, 0.31, 0.29)),
        'wax': material('Treasury | red seal wax', (0.47, 0.024, 0.027)),
    }


def station_title(text, center, width, colors):
    box('Treasury station title plate', center, (width, 0.075, 0.27), colors['iron'], 0.025)
    label(text, (center[0], center[1] - 0.045, center[2] - 0.045), 0.11, colors['paper'])


def coin_stack(center, count, surface, colors):
    for index in range(count):
        cylinder('Counted coin', (center[0], center[1], center[2] + 0.013 + index * 0.028), 0.095, 0.022, surface, 20)
    ring('Minted coin face rim', (center[0], center[1], center[2] + count * 0.028), 0.072, 0.006, colors['brass'], segments=20, sides=4)
    for axis in ((1, 0), (0, 1)):
        rod('Minted coin seal', (center[0] - axis[0] * 0.045, center[1] - axis[1] * 0.045, center[2] + count * 0.028), (center[0] + axis[0] * 0.045, center[1] + axis[1] * 0.045, center[2] + count * 0.028), 0.006, surface)


def coin_tray(center, colors, denomination):
    box('Divided counting tray base', center, (1.37, 0.87, 0.075), colors['oak'], 0.025)
    for offset in (-0.69, -0.23, 0.23, 0.69):
        box('Counting tray column divider', (center[0] + offset, center[1], center[2] + 0.12), (0.036, 0.88, 0.20), colors['oak_top'], 0.01)
    for offset in (-0.44, 0, 0.44):
        box('Counting tray row divider', (center[0], center[1] + offset, center[2] + 0.12), (1.4, 0.036, 0.20), colors['oak_top'], 0.01)
    for index in range(6):
        coin_stack((center[0] - 0.46 + (index % 3) * 0.46, center[1] - 0.22 + (index // 3) * 0.44, center[2] + 0.05), 3 + index, colors[denomination], colors)
    station_title(denomination.upper() + ' / 100', (center[0], center[1] - 0.47, center[2] + 0.11), 1.1, colors)


def ingot(center, surface):
    profile('Stamped cast ingot', center, [(-0.36, 0), (0.36, 0), (0.31, 0.17), (-0.31, 0.17)], 0.31, surface, 0.025)
    box('Raised assay mark', (center[0], center[1], center[2] + 0.181), (0.16, 0.055, 0.012), surface, 0.008)


def coin_sack(center, colors, scale=1):
    outline = [(0.15, 0), (0.28, 0.15), (0.27, 0.40), (0.13, 0.57), (0.08, 0.61), (0.13, 0.70)]
    lathe('Bound linen coin sack', center, [(radius * scale, height * scale) for radius, height in outline], colors['linen'], 20)
    ring('Coin sack twisted binding', (center[0], center[1], center[2] + 0.60 * scale), 0.091 * scale, 0.016, colors['paper'], segments=20, sides=5)
    rod('Sack seal cord', (center[0], center[1], center[2] + 0.6 * scale), (center[0] + 0.12, center[1] - 0.14, center[2] + 0.36 * scale), 0.01, colors['paper'])
    cylinder('Coin sack wax duty seal', (center[0] + 0.12, center[1] - 0.14, center[2] + 0.34 * scale), 0.06, 0.025, colors['wax'], 16).rotation_euler.x = math.pi / 2


def strapped_coffer(center, width, colors):
    depth = 1.35
    box('Iron-bound strongbox body', (center[0], center[1], center[2] + 0.54), (width, depth, 1.08), colors['oak'], 0.065)
    outline = [(-width / 2, 0), (width / 2, 0)]
    outline.extend((math.cos(index * math.pi / 16) * width / 2, math.sin(index * math.pi / 16) * 0.43) for index in range(1, 16))
    profile('Vaulted coffer lid', (center[0], center[1], center[2] + 1.08), outline, depth, colors['oak_top'], 0.035)
    for offset in (-0.45, 0.45):
        tube('Coffer curved iron binding', [(center[0] + math.cos(index * math.pi / 16) * width / 2, center[1] + offset, center[2] + 1.10 + math.sin(index * math.pi / 16) * 0.44) for index in range(17)], 0.04, colors['iron'])
    for horizontal in (-width * 0.36, width * 0.36):
        box('Coffer frontal strap', (center[0] + horizontal, center[1] - depth / 2 - 0.02, center[2] + 0.55), (0.13, 0.07, 1.1), colors['iron'], 0.02)
        for elevation in (0.18, 0.50, 0.83):
            cylinder('Coffer hammered rivet', (center[0] + horizontal, center[1] - depth / 2 - 0.075, center[2] + elevation), 0.036, 0.025, colors['brass'], 10).rotation_euler.x = math.pi / 2
    box('Strongbox hasp plate', (center[0], center[1] - depth / 2 - 0.075, center[2] + 0.87), (0.23, 0.12, 0.33), colors['brass'], 0.025)
    ring('Closed strongbox padlock bow', (center[0], center[1] - depth / 2 - 0.16, center[2] + 0.93), 0.095, 0.025, colors['iron'], (math.pi / 2, 0, 0), segments=24, sides=6)
    box('Closed strongbox padlock case', (center[0], center[1] - depth / 2 - 0.16, center[2] + 0.81), (0.19, 0.10, 0.17), colors['iron'], 0.04)
    collider('Locked treasury coffer', (center[0], center[1], center[2] + 0.77), (width + 0.08, depth + 0.22, 1.54))


def grille(start, end, colors):
    direction = (end[0] - start[0], end[1] - start[1])
    length = math.hypot(*direction)
    for elevation in (0.24, 0.82, 2.24):
        rod('Treasury grille horizontal rail', (start[0], start[1], elevation), (end[0], end[1], elevation), 0.032, colors['iron'])
    count = max(2, int(length / 0.32))
    for index in range(count + 1):
        ratio = index / count
        horizontal = start[0] + direction[0] * ratio
        depth = start[1] + direction[1] * ratio
        rod('Treasury grille vertical bar', (horizontal, depth, 0.16), (horizontal, depth, 2.58), 0.029, colors['iron'])
        lathe('Grille spearhead finial', (horizontal, depth, 2.58), [(0.025, 0), (0.075, 0.10), (0, 0.27)], colors['brass'], 8)
    collider('Treasury fixed grille', ((start[0] + end[0]) / 2, (start[1] + end[1]) / 2, 1.4), (abs(direction[0]) + 0.09, abs(direction[1]) + 0.09, 2.80))


def strongroom(colors):
    for horizontal in (40.1, 43.9):
        box('Strongroom gate pier footing', (horizontal, -51.0, 0.20), (0.62, 0.64, 0.40), colors['stone'], 0.045, True)
        box('Strongroom narrow iron gate pier', (horizontal, -51.0, 1.62), (0.27, 0.32, 2.85), colors['iron'], 0.025, True)
        lathe('Strongroom gate crown finial', (horizontal, -51.0, 3.05), [(0.16, 0), (0.16, 0.10), (0.09, 0.22), (0.045, 0.34), (0, 0.40)], colors['brass'], 12)
        grille((horizontal, -51), (horizontal, -48.8), colors)
        for elevation in (0.55, 2.0):
            cylinder('Open gate barrel hinge', (horizontal, -51.0, elevation), 0.08, 0.34, colors['brass'], 16)
    grille((36.6, -51), (39.85, -51), colors)
    grille((44.15, -51), (47.4, -51), colors)
    for horizontal in (38.35, 45.65):
        strapped_coffer((horizontal, -45.55, 0), 2.25, colors)
    box('Fitted deposit cabinet back', (36.69, -48.35, 1.48), (0.24, 3.5, 2.96), colors['oak'], 0.05)
    for elevation in (0.13, 1.5, 2.86):
        box('Deposit cabinet iron shelf', (37.13, -48.35, elevation), (1.08, 3.7, 0.15), colors['iron'], 0.025)
    for depth in (-47.3, -49.35):
        for elevation in (0.82, 2.15):
            box('Locked deposit compartment door', (37.68, depth, elevation), (0.12, 1.43, 1.04), colors['oak_top'], 0.04)
            box('Deposit compartment lock escutcheon', (37.77, depth - 0.35, elevation), (0.045, 0.19, 0.26), colors['brass'], 0.025)
            for side in (-1, 1):
                rod('Deposit door iron hinge', (37.77, depth + side * 0.45, elevation - 0.45), (37.77, depth + side * 0.45, elevation + 0.45), 0.022, colors['iron'])
    collider('Fitted strongroom deposit cabinet', (37.13, -48.35, 1.5), (1.18, 3.75, 3.0))
    station_title('THE CROWN RESERVE', (42, -44.42, 3.4), 4.6, colors)
    for side in (-1, 1):
        rod('Reserve heraldic crossed key', (42 + side * 0.43, -44.47, 2.52), (42 - side * 0.40, -44.47, 3.10), 0.035, colors['brass'])
        ring('Reserve heraldic key bow', (42 - side * 0.42, -44.47, 3.14), 0.115, 0.025, colors['brass'], (math.pi / 2, 0, 0), segments=24, sides=6)


def ingot_racks(colors):
    for depth, denomination in ((-54.2, 'gold'), (-55.8, 'silver')):
        box('Graded ingot rack iron base', (46.35, depth, 0.15), (1.75, 1.35, 0.3), colors['iron'], 0.035, True)
        for elevation in (0.38, 0.87):
            box('Grade-separated ingot tray', (46.35, depth, elevation), (1.72, 1.30, 0.13), colors['oak_top'], 0.035)
            for index in range(4):
                ingot((45.94 + (index % 2) * 0.8, depth - 0.32 + (index // 2) * 0.64, elevation + 0.08), colors[denomination])
        for horizontal in (45.6, 47.1):
            box('Ingot rack reinforced upright', (horizontal, depth + 0.58, 0.7), (0.13, 0.13, 1.4), colors['iron'], 0.025)
        station_title(denomination.upper() + ' / ASSAYED', (46.35, depth - 0.71, 0.74), 1.55, colors)
        collider('Treasury low ingot rack', (46.35, depth, 0.7), (1.8, 1.42, 1.4))


def assay_station(colors):
    bench((38.3, -54.15, 0), 2.9, 1.6, colors, True)
    scales((38.55, -54.2, 1.21), colors)
    box('Assay weight storage block', (37.37, -54.15, 1.20), (0.72, 0.70, 0.13), colors['oak'], 0.03)
    for index, radius in enumerate((0.06, 0.08, 0.10)):
        lathe('Calibrated brass assay weight', (37.17 + index * 0.21, -54.15, 1.28), [(radius, 0), (radius, 0.17), (radius * 0.4, 0.2), (radius * 0.55, 0.24)], colors['brass'], 16)
    ingot((39.15, -53.72, 1.16), colors['gold'])
    box('Assay touchstone', (37.32, -53.67, 1.20), (0.52, 0.26, 0.065), colors['ink'], 0.02)
    for offset in (-0.12, 0.02, 0.16):
        rod('Gold assay streak', (37.15 + offset, -53.60, 1.24), (37.23 + offset, -53.74, 1.24), 0.008, colors['gold'])
    station_title('WEIGH / TEST / RECORD', (38.3, -55.02, 0.94), 2.25, colors)


def seal_press(center, colors):
    box('Mint seal press base', (center[0], center[1], center[2] + 0.06), (0.63, 0.63, 0.12), colors['iron'], 0.04)
    for side in (-1, 1):
        rod('Seal press cheek', (center[0] + side * 0.27, center[1] + 0.15, center[2] + 0.08), (center[0] + side * 0.27, center[1] + 0.15, center[2] + 0.84), 0.055, colors['iron'])
    box('Seal press crosshead', (center[0], center[1] + 0.15, center[2] + 0.84), (0.74, 0.23, 0.16), colors['iron'], 0.035)
    rod('Seal press screw', (center[0], center[1] + 0.15, center[2] + 0.2), (center[0], center[1] + 0.15, center[2] + 1.08), 0.035, colors['brass'])
    for index in range(8):
        ring('Seal press screw thread', (center[0], center[1] + 0.15, center[2] + 0.49 + index * 0.065), 0.045, 0.009, colors['brass'], segments=20, sides=4)
    rod('Seal press turning lever', (center[0] - 0.32, center[1] + 0.15, center[2] + 1.08), (center[0] + 0.32, center[1] + 0.15, center[2] + 1.08), 0.027, colors['oak_top'])
    cylinder('Crown seal matrix', (center[0], center[1] + 0.15, center[2] + 0.28), 0.14, 0.09, colors['brass'], 24)
    box('Sealing document beneath press', (center[0], center[1] - 0.05, center[2] + 0.14), (0.37, 0.52, 0.018), colors['paper'], 0.006)
    cylinder('Pressed crown wax seal', (center[0], center[1] + 0.10, center[2] + 0.159), 0.074, 0.018, colors['wax'], 20)


def counting_house(colors):
    bench((42.0, -62.1, 0), 5.7, 1.65, colors, True)
    for horizontal, denomination in ((40.1, 'gold'), (42.0, 'silver')):
        coin_tray((horizontal, -62.1, 1.18), colors, denomination)
    seal_press((44.0, -62.1, 1.15), colors)
    station_title('THE ROYAL COUNTING HOUSE', (42, -62.99, 0.88), 3.2, colors)
    for horizontal in (40.1, 42.0, 43.9):
        box('Daily account leather folio', (horizontal, -62.62, 1.21), (0.70, 0.33, 0.045), colors['leather'], 0.012)
        box('Daily account tally sheet', (horizontal, -62.63, 1.243), (0.62, 0.27, 0.01), colors['paper'], 0)
        for index in range(4):
            box('Recorded tally stroke', (horizontal - 0.21 + index * 0.13, -62.63, 1.253), (0.018, 0.17, 0.005), colors['ink'], 0)
    bench((38.5, -66.8, 0), 2.55, 0.90, colors, True)
    for index in range(4):
        horizontal = 37.62 + index * 0.58
        box('Bound treasury ledger', (horizontal, -66.78, 1.24 + (index % 2) * 0.05), (0.46, 0.75, 0.16), colors['leather'], 0.025)
        for offset in (-0.17, 0.17):
            box('Ledger spine brass band', (horizontal + offset, -66.78, 1.33 + (index % 2) * 0.05), (0.034, 0.76, 0.017), colors['brass'], 0.005)
    for center in ((40.6, -66.9, 0), (41.35, -66.9, 0), (44.4, -66.9, 0)):
        coin_sack(center, colors, 1.1)
        collider('Sealed coin sack', (center[0], center[1], 0.40), (0.65, 0.65, 0.80))
    for horizontal in (40.3, 43.5):
        cylinder('Counting clerk stool cushion', (horizontal, -64.0, 0.67), 0.37, 0.16, colors['leather'], 24)
        for angle in (0, math.tau / 3, math.tau * 2 / 3):
            rod('Counting stool splayed leg', (horizontal + math.cos(angle) * 0.20, -64.0 + math.sin(angle) * 0.20, 0.59), (horizontal + math.cos(angle) * 0.34, -64.0 + math.sin(angle) * 0.34, 0.05), 0.035, colors['oak'])
        collider('Counting clerk stool', (horizontal, -64.0, 0.38), (0.78, 0.78, 0.76))


def build_treasury():
    create_scene('Royal counting house and crown reserve')
    colors = palette()
    strongroom(colors)
    ingot_racks(colors)
    assay_station(colors)
    counting_house(colors)
    export_asset(arguments.output / 'counting_house.glb', colors['stone'])


build_treasury()
