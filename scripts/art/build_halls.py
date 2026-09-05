import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import castle_mesh as geometry

from castle_interior import COLLISIONS, arch, beam, bench, block, candle, collider, desk, document, orb, point


def stairs(name, bottom, width, run, height, direction):
    steps = 11
    perpendicular = (-direction[1], direction[0])
    for step in range(steps):
        offset = (step + .5) * run / steps
        center = (bottom[0] + direction[0] * offset, height * (step + 1) / steps / 2, bottom[1] + direction[1] * offset)
        size = (width if direction[0] == 0 else run / steps, height * (step + 1) / steps, width if direction[1] == 0 else run / steps)
        block(name + ' stone tread', center, size, 'stone_light', .008)
        block(name + ' worn stair edge', (center[0], size[1] + .012, center[2]), (size[0], .025, size[2] * .25 if direction[0] == 0 else size[2]), 'stone', .005)
    vertices = []
    for side in (-1, 1):
        for distance, elevation in [(0, 0), (run, 0), (run, height)]:
            vertices.append(point((bottom[0] + perpendicular[0] * side * width / 2 + direction[0] * distance, elevation, bottom[1] + perpendicular[1] * side * width / 2 + direction[1] * distance)))
    COLLISIONS.append((name + ' smooth stair slope', vertices, [(0, 2, 1), (3, 4, 5), (0, 1, 4, 3), (1, 2, 5, 4), (0, 3, 5, 2)]))
    for side in (-1, 1):
        for fraction in (.08, .5, .95):
            horizontal = bottom[0] + perpendicular[0] * side * (width / 2 + .09) + direction[0] * run * fraction
            depth = bottom[1] + perpendicular[1] * side * (width / 2 + .09) + direction[1] * run * fraction
            beam('Stair baluster', (horizontal, height * fraction, depth), (horizontal, height * fraction + .8, depth), .045, 'brass')
        beam('Continuous rising handrail', (bottom[0] + perpendicular[0] * side * (width / 2 + .09), .8, bottom[1] + perpendicular[1] * side * (width / 2 + .09)), (bottom[0] + perpendicular[0] * side * (width / 2 + .09) + direction[0] * run, height + .8, bottom[1] + perpendicular[1] * side * (width / 2 + .09) + direction[1] * run), .06, 'oak')


def gatehouse():
    geometry.initialize_scene()
    COLLISIONS.clear()
    for side in (-1, 1):
        block('Gate limestone jamb', (side * 4.95, 1.65, -10.7), (.85, 3.3, 1.2), 'stone_light', .05, True)
        for elevation in (.25, 1.1, 2.0, 2.9):
            block('Gate jamb cut course', (side * 4.95, elevation, -10.66), (.96, .1, 1.25), 'stone', .01)
    arch('Gate stone voussoir', (0, 2.9, -10.7), 4.5, .65, 1.15)
    for plank in range(18):
        horizontal = -4.4 + (plank + .5) * 8.8 / 18
        top = 2.9 + math.sqrt(max(0, 4.45 ** 2 - horizontal ** 2))
        block('Closed outer gate oak board', (horizontal, top / 2, -10.82), (.475, top, .35), 'oak', .035)
        for elevation in (.95, 2.5):
            orb('Gate iron rivet', (horizontal, elevation, -10.57), (.045, .045, .025), 'iron')
    collider('Sealed castle outer gate', (0, 3.2, -10.8), (9, 6.4, .5))
    for elevation in (.95, 2.5, 4.1):
        block('Gate horizontal iron strap', (0, elevation, -10.59), (8.8, .19, .065), 'iron', .012)
    block('Heavy locked gate crossbar', (0, 1.75, -10.28), (9.7, .4, .42), 'cut_oak', .05)
    for horizontal in (-3.5, 3.5):
        block('Crossbar iron keeper', (horizontal, 1.75, -10.02), (.25, .65, .15), 'iron')
    for side in (-1, 1):
        beam('Gate lifting chain', (side * 4.6, 2, -10.15), (side * 3.1, 6, -10.15), .055)
        block('Guardhouse stone corbel', (side * 6.2, 2.45, -10.4), (1, .45, .65), 'stone_light')
        candle((side * 6.2, 2.7, -10.4), .75)
    desk((8.5, 0, -6.5), 2.4, 2.2)
    document((8.3, 1.2, -6.4), 1.0, 1.2, True)
    candle((9.05, 1.2, -7.15))
    for spear in range(4):
        depth = -7.2 + spear * .5
        beam('Guard halberd shaft', (10.55, .15, depth), (10.55, 2.85, depth), .045, 'cut_oak')
        orb('Guard halberd head', (10.55, 3.01, depth), (.13, .31, .05), 'pewter')
    block('Guard weapon retaining rack', (10.65, 1.1, -6.45), (.35, .19, 2.3), 'oak', .025, True)
    block('Public notices carved backboard', (-10.75, 1.7, -4.8), (.22, 2.8, 4.3), 'oak', .05, True)
    for notice in range(6):
        elevation = .98 + notice // 3 * 1.15
        depth = -6.12 + notice % 3 * 1.3
        block('Pinned public notice', (-10.605, elevation, depth), (.03, .85, .92), 'cream', .01)
        for line in range(4):
            block('Notice handwritten message', (-10.584, elevation + .2 - line * .13, depth), (.006, .017, .64), 'soot', 0)
        orb('Notice red wax seal', (-10.56, elevation - .22, depth + .25), (.025, .065, .065), 'wine')
    block('Arrival reception desk', (-9.3, .57, 7.5), (2.3, 1.14, 5.8), 'oak', .04, True)
    block('Reception counter top', (-9.2, 1.2, 7.5), (2.65, .16, 6), 'cut_oak')
    for depth in (5.2, 7.3, 9.4):
        block('Reception inset panel', (-8.126, .62, depth), (.06, .73, 1.6), 'edge')
    document((-8.8, 1.3, 6.1), .8, 1.1, True)
    document((-9.1, 1.32, 8.7), .7, .9)
    candle((-9.6, 1.3, 7.4), .6)
    for slot in range(5):
        depth = 5.15 + slot * 1.1
        block('Room key pigeonhole back', (-10.52, 1.83, depth), (.1, 1.1, 1.08), 'oak')
        block('Room key pigeonhole shelf', (-10.25, 1.34, depth), (.65, .08, 1.08), 'edge')
        block('Room key pigeonhole partition', (-10.25, 1.83, depth - .52), (.65, 1.08, .065), 'cut_oak')
        beam('Hanging brass room key', (-10.3, 1.8, depth), (-10.3, 2.1, depth), .035, 'brass')
        beam('Room key teeth', (-10.3, 1.81, depth), (-10.14, 1.81, depth), .035, 'brass')
    desk((0, 0, 12.2), 5.6, 3.4)
    block('Castle map parchment', (0, 1.19, 12.2), (4.7, .02, 2.75), 'cream', .01)
    for depth, width in [(11.35, 3.4), (13, 3.4)]:
        block('Miniature castle curtain wall', (0, 1.36, depth), (width, .3, .12), 'stone')
    for horizontal in (-1.7, 1.7):
        block('Miniature castle curtain wall', (horizontal, 1.36, 12.2), (.12, .3, 1.75), 'stone')
        for depth in (11.35, 13.0):
            geometry.lathe('Miniature castle tower', point((horizontal, 1.2, depth)), [(.2, 0), (.2, .5), (.24, .5), (.24, .58), (0, .58)], 'stone_light', 12)
    for horizontal, depth, height in [(-.8, 11.9, .35), (.7, 12.3, .6), (-.3, 12.55, .25)]:
        block('Miniature keep and inner court', (horizontal, 1.23 + height / 2, depth), (.6, height, .7), 'stone_light')
        beam('Map position pennant mast', (horizontal, 1.2 + height, depth), (horizontal, 1.7 + height, depth), .016, 'brass')
        block('Miniature pennant', (horizontal + .12, 1.63 + height, depth), (.23, .16, .025), 'wine', .005)
    for horizontal in (-2.35, 2.35):
        candle((horizontal, 1.2, 12.2))
    bench((-5.3, 0, 18.15), 5.2)
    bench((1, 0, 18.15), 4.7)
    for depth in (11.6, 17.9):
        block('Cloak rail upright', (10.35, 1.6, depth), (.16, 3.2, .16), 'cut_oak')
    beam('Arrival cloak hanging rail', (10.35, 2.9, 11.6), (10.35, 2.9, 17.9), .06, 'brass')
    for cloak in range(5):
        depth = 12 + cloak * 1.1
        obj = block('Hanging travelers cloak', (10.26, 1.88, depth), (.22, 1.82, .7), 'wine' if cloak % 2 else 'green', .08)
        obj.rotation_euler.y = -.08
        orb('Cloak hood', (10.28, 2.78, depth), (.26, .27, .25), 'wine' if cloak % 2 else 'green')
    block('Luggage bench', (9.45, .56, 14.8), (2.1, .14, 7.2), 'cut_oak', .03)
    for depth in (12, 14, 16.5):
        block('Traveling ironbound trunk', (9.25, .99, depth), (1.1, .75, 1.35), 'oak', .1)
        for side in (-1, 1):
            block('Trunk iron band', (9.25, 1.38, depth + side * .43), (1.1, .045, .09), 'iron', .005)
    collider('Cloak and luggage storage', (9.6, 1.6, 14.8), (2.5, 3.2, 7.4))
    geometry.save('hall_arrival', COLLISIONS)


def court_dais(center, width, depth):
    block('Raised stone audience court', (center[0], 1.06, center[1]), (width, 2.12, depth), 'stone', .015)
    collider('Raised court walking surface', (center[0], 1.1, center[1]), (width, 2.2, depth))
    for side in (-1, 1):
        block('Audience court side stone lip', (center[0] + side * (width / 2 + .03), 2.16, center[1]), (.06, .08, depth + .12), 'stone_light', .009)
        block('Audience court front stone lip', (center[0], 2.16, center[1] + side * (depth / 2 + .03)), (width, .08, .06), 'stone_light', .009)
    for column in range(round(width)):
        for row in range(round(depth)):
            block('Individually laid court paving slab', (center[0] - width / 2 + column + .5, 2.18, center[1] - depth / 2 + row + .5), (.975, .04, .975), 'stone_light' if (column + row) % 4 == 0 else 'stone', .007)
    for horizontal in range(round(width)):
        block('Dais front cut masonry panel', (center[0] - width / 2 + horizontal + .5, 1.0, center[1] + depth / 2 + .015), (.94, 1.6, .04), 'stone_light', .018)


def royal_seat():
    bench((3.5, 2.2, 46.8), 6.5)
    block('Audience seat high back', (3.5, 4.05, 46.35), (2.0, 2.4, .23), 'oak', .05, True)
    block('Embroidered royal seat cushion', (3.5, 3.93, 46.49), (1.54, 1.68, .08), 'wine')
    for horizontal in (.2, 6.8):
        block('Audience canopy carved post', (horizontal, 4.0, 46.1), (.21, 3.6, .21), 'cut_oak', .03, True)
        orb('Audience canopy gilded finial', (horizontal, 5.95, 46.1), (.18, .28, .18), 'brass')
    block('Audience canopy carved cornice', (3.5, 5.68, 46.1), (7, .35, .6), 'oak')
    block('Canopy gilded molding', (3.5, 5.8, 46.39), (6.8, .095, .06), 'brass')
    for horizontal in (1.15, 5.85):
        block('Heraldic hanging cloth', (horizontal, 4.32, 45.94), (1.2, 2.45, .045), 'wine')
        beam('Heraldic embroidered saltire', (horizontal - .4, 3.5, 46.0), (horizontal + .4, 5.12, 46.0), .025, 'edge')
        beam('Heraldic embroidered saltire', (horizontal + .4, 3.5, 46.0), (horizontal - .4, 5.12, 46.0), .025, 'edge')
    orb('Court gilded sun emblem', (3.5, 4.34, 46.58), (.36, .36, .035), 'brass')
    for ray in range(12):
        angle = ray * math.tau / 12
        beam('Royal sun emblem ray', (3.5 + math.cos(angle) * .42, 4.34 + math.sin(angle) * .42, 46.58), (3.5 + math.cos(angle) * .58, 4.34 + math.sin(angle) * .58, 46.58), .026, 'brass')


def musicians():
    block('Minstrels pipe organ case', (27.6, 2.85, 46.8), (3.6, 1.3, 1.05), 'oak', .04, True)
    for pipe in range(13):
        horizontal = 26.15 + pipe * .24
        height = 1.25 + 1.3 * (1 - abs(pipe - 6) / 6)
        beam('Polished organ pipe', (horizontal, 3.05, 46.65), (horizontal, 3.05 + height, 46.65), .095, 'pewter')
        block('Organ pipe speaking mouth', (horizontal, 3.2, 46.753), (.09, .13, .025), 'soot', .005)
    for keyboard in range(22):
        block('Organ ivory key', (26.64 + keyboard * .095, 3.02, 47.52), (.086, .065, .42), 'cream', .005)
        if keyboard % 7 not in (2, 6):
            block('Organ ebony key', (26.68 + keyboard * .095, 3.07, 47.42), (.04, .06, .25), 'soot', .002)
    bench((27.6, 2.2, 48.6), 2.0)
    beam('Harp carved pillar', (30.05, 2.3, 46.9), (30.05, 4.62, 46.9), .09, 'edge')
    beam('Harp curved neck upper', (30.05, 4.62, 46.9), (29.15, 4.24, 46.9), .11, 'cut_oak')
    beam('Harp resonating soundboard', (29.15, 4.24, 46.9), (30.05, 2.3, 46.9), .16, 'oak')
    for string in range(8):
        fraction = (string + 1) / 9
        beam('Harp taut string', (30.05 - fraction * .9, 4.62 - fraction * .38, 46.9), (30.05 - fraction * .55, 2.3 + fraction * 1.94, 46.9), .008, 'brass')
    collider('Minstrels harp', (29.65, 3.4, 46.9), (1.1, 2.5, .45))
    beam('Music stand column', (30.2, 2.2, 49.65), (30.2, 3.3, 49.65), .045, 'iron')
    block('Music stand score rest', (30.2, 3.31, 49.65), (1.05, .11, .6), 'cut_oak')
    document((30.2, 3.38, 49.65), .9, .48)


def grand_hall():
    geometry.initialize_scene()
    COLLISIONS.clear()
    court_dais((3.5, 48.5), 9, 5)
    stairs('Audience front stair', (2, 55), 4, 4, 2.2, (0, -1))
    stairs('Audience side stair', (10.8, 48), 3, 2.8, 2.2, (-1, 0))
    royal_seat()
    court_dais((28, 48.5), 6, 5)
    stairs('Minstrel front stair', (27.75, 55), 3.5, 4, 2.2, (0, -1))
    stairs('Minstrel side stair', (34.5, 48.5), 3, 3.5, 2.2, (-1, 0))
    musicians()
    for depth in (53, 59):
        arch('Grand hall open arcade voussoir', (12, 3.9, depth), 2.25, .36, .62, along_depth=True)
    for depth in (50, 56, 62):
        block('Arcade impost capital', (12, 3.88, depth), (1.45, .27, 1.6), 'stone_light')
        for side in (-1, 1):
            block('Arcade pier carved shield', (12 + side * .8, 2.55, depth), (.09, 1.05, .72), 'brass')
    desk((17.1, 0, 48), 3.4, 1.6)
    document((16.45, 1.2, 48), .7, 1.05, True)
    document((17.55, 1.205, 47.85), .7, .95)
    candle((18.35, 1.2, 48))
    for horizontal in (-8.2, -4.2):
        bench((horizontal, 0, 64.9), 3.3)
    for horizontal in (6.7, 9.1):
        block('Ceremonial standard stone plinth', (horizontal, .22, 65.15), (.75, .44, .75), 'stone_light', .055, True)
        beam('Ceremonial standard pole', (horizontal, .4, 65.15), (horizontal, 3.7, 65.15), .06, 'brass')
        beam('Ceremonial standard crossbar', (horizontal - .6, 3.25, 65.15), (horizontal + .6, 3.25, 65.15), .045, 'brass')
        block('Ceremonial royal standard', (horizontal, 2.6, 65.15), (1.1, 1.25, .045), 'wine')
        orb('Standard embroidered royal sun', (horizontal, 2.7, 65.20), (.24, .24, .027), 'edge')
        orb('Standard spear finial', (horizontal, 3.87, 65.15), (.09, .2, .09), 'brass')
    desk((26, 0, 64.65), 9, 1.9)
    block('Council cloth runner', (26, 1.2, 64.65), (7.6, .014, 1.0), 'wine', .005)
    for horizontal in (23.1, 26.0, 28.9):
        document((horizontal, 1.23, 64.6), 1.05, .8, True)
    for horizontal in (21.9, 30.1):
        candle((horizontal, 1.2, 64.65), .65)
    for horizontal in (-8.8, 18, 33.1):
        block('Grand hall wainscot panel', (horizontal, 1, 44.65), (2.6, 2, .2), 'oak', .03)
        for offset in (-.85, 0, .85):
            block('Wainscot raised stone arch inset', (horizontal + offset, 1.08, 44.78), (.61, 1.36, .075), 'cut_oak', .025)
    geometry.save('hall_grand', COLLISIONS)


if __name__ == '__main__':
    gatehouse()
    grand_hall()
