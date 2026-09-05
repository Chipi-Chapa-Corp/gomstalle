import argparse
import math
import re
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import workshop_geometry as geometry
from workshop_geometry import box, collider, create_scene, cylinder, export_asset, lathe, material, ring, rod


SCROLL_PROTOTYPES: dict[tuple[float, float, bool], tuple[Vector, list[bpy.types.Object]]] = {}

def palette():
    colors = {'oak': '302722', 'wood': '76583b', 'edge': 'ac8756', 'paper': 'dbc799', 'ink': '302e33', 'brass': 'b99655', 'red': '7d3942', 'green': '355951', 'blue': '3b5362', 'wax': 'b44337', 'glow': 'ffd496'}
    result = {}
    for name, color in colors.items():
        channels = [int(color[index:index + 2], 16) / 255 for index in (0, 2, 4)]
        linear = [channel / 12.92 if channel <= .04045 else ((channel + .055) / 1.055) ** 2.4 for channel in channels]
        result[name] = material('Scholar | ' + name, linear, .7 if name == 'brass' else 0, .37 if name == 'brass' else .7, 2 if name == 'glow' else 0)
    return result


def sheet(center, colors, width=.62, depth=.84, illuminated=False):
    box('Handmade parchment', center, (width, depth, .012), colors['paper'], .005)
    for line in range(7):
        box('Manuscript writing', (center[0] + (width * .1 if illuminated and line < 3 else 0), center[1] - depth * .34 + line * depth * .09, center[2] + .008), (width * (.51 if illuminated and line < 3 else .76), .009, .003), colors['ink'], 0)
    if illuminated:
        box('Illuminated manuscript initial', (center[0] - width * .28, center[1] - depth * .25, center[2] + .009), (width * .17, depth * .25, .005), colors['red'], 0)
        for offset in (-1, 1):
            box('Gilded manuscript margin', (center[0] + offset * width * .46, center[1], center[2] + .009), (.01, depth * .93, .003), colors['brass'], 0)


def scroll(center, colors, radius=.09, length=.64, sealed=False):
    key = (radius, length, sealed)
    if key in SCROLL_PROTOTYPES:
        source_center, source_objects = SCROLL_PROTOTYPES[key]
        displacement = Vector(center) - source_center
        for source in source_objects:
            instance = source.copy()
            instance.location += displacement
            geometry.assembly.objects.link(instance)
        return
    previous_objects = set(geometry.assembly.objects)
    _create_scroll(center, colors, radius, length, sealed)
    SCROLL_PROTOTYPES[key] = (Vector(center), [obj for obj in geometry.assembly.objects if obj not in previous_objects])


def _create_scroll(center, colors, radius, length, sealed):
    paper = cylinder('Rolled archive parchment', center, radius, length, colors['paper'], 14)
    paper.rotation_euler.x = math.pi / 2
    rod('Parchment wooden spindle', (center[0], center[1] - length * .59, center[2]), (center[0], center[1] + length * .59, center[2]), .027, colors['wood'])
    for side in (-1, 1):
        ring('Visible rolled parchment edge', (center[0], center[1] + side * (length / 2 + .002), center[2]), radius * .64, .009, colors['edge'], (math.pi / 2, 0, 0), segments=12, sides=4)
    if sealed:
        binding = cylinder('Sealed document ribbon', center, radius + .003, .075, colors['red'], 14)
        binding.rotation_euler.x = math.pi / 2
        cylinder('Wax archive seal', (center[0], center[1], center[2] + radius), .047, .018, colors['wax'], 12)


def desk(center, width, depth, colors):
    box('Desk planked top', (center[0], center[1], 1.06), (width, depth, .16), colors['wood'], .04)
    for offset in (-1, 1):
        horizontal = center[0] + offset * (width / 2 - .26)
        box('Carved desk trestle', (horizontal, center[1], .53), (.20, depth * .73, 1.06), colors['oak'], .045)
        box('Trestle wide foot', (horizontal, center[1], .13), (.36, depth * .90, .20), colors['wood'], .045)
    box('Desk stretcher', (center[0], center[1], .33), (width - .4, .16, .18), colors['oak'])
    collider('Writing desk', (center[0], center[1], .58), (width, depth, 1.16))


def stool(center, colors):
    cylinder('Round stool seat', (center[0], center[1], .59), .34, .13, colors['wood'], 20)
    for angle in (0, 2.1, 4.2):
        rod('Splayed stool leg', (center[0] + math.cos(angle) * .29, center[1] + math.sin(angle) * .29, .06), (center[0] + math.cos(angle) * .20, center[1] + math.sin(angle) * .20, .55), .055, colors['oak'])
    collider('Writing stool', (center[0], center[1], .34), (.65, .65, .68))


def candle(center, colors):
    cylinder('Brass wax drip tray', center, .14, .035, colors['brass'], 18)
    cylinder('Candle wax', (center[0], center[1], center[2] + .17), .047, .3, colors['paper'], 12)
    lathe('Candle flame', (center[0], center[1], center[2] + .32), [(0, 0), (.025, .03), (.017, .09), (0, .15)], colors['glow'], 10)


def writing_set(center, colors):
    lathe('Ceramic inkwell', center, [(.08, 0), (.1, .04), (.09, .12), (.04, .16), (.04, .19)], colors['blue'], 16)
    rod('Quill nib and shaft', (center[0], center[1], center[2] + .1), (center[0] + .20, center[1] + .05, center[2] + .57), .008, colors['edge'])
    for feather in range(7):
        height = .24 + feather * .04
        for side in (-1, 1):
            rod('Quill feather vane', (center[0] + height * .39, center[1], center[2] + height), (center[0] + height * .39 + side * .04, center[1] + .018, center[2] + height + .1), .01, colors['paper'])


def cabinet(center, width, colors, columns=5, rows=4):
    height = rows * .52 + .24
    box('Archive cabinet back', (center[0], center[1] + .42, height / 2), (width, .13, height), colors['oak'])
    for edge in range(columns + 1):
        box('Archive pigeonhole upright', (center[0] - width / 2 + edge * width / columns, center[1], height / 2), (.075, .9, height), colors['wood'])
    for row in range(rows + 1):
        shelf_height = .14 + row * .52
        box('Archive pigeonhole shelf', (center[0], center[1], shelf_height), (width, .9, .075), colors['wood'])
        if row == rows:
            continue
        for column in range(columns):
            horizontal = center[0] - width / 2 + (column + .5) * width / columns
            for stack in range(3):
                scroll((horizontal + (stack - 1) * .18, center[1] - .03, shelf_height + .15), colors, sealed=stack == 1)
            box('Archive brass index holder', (horizontal, center[1] - .46, shelf_height), (.21, .015, .047), colors['brass'], 0)
    box('Cabinet crown molding', (center[0], center[1], height + .06), (width + .16, 1.03, .15), colors['oak'], .04)
    collider('Document cabinet', (center[0], center[1], height / 2), (width + .15, 1.04, height + .15))


def press(center, colors):
    desk(center, 2.1, 1.7, colors)
    for side in (-1, 1):
        horizontal = center[0] + side * .73
        box('Printing press upright', (horizontal, center[1], 2.05), (.22, .35, 2.35), colors['oak'])
        box('Press post brass collar', (horizontal, center[1], 2.85), (.25, .39, .14), colors['brass'])
    box('Carved press crosshead', (center[0], center[1], 3.07), (1.92, .5, .30), colors['wood'], .05)
    rod('Press threaded spindle', (center[0], center[1], 1.48), (center[0], center[1], 3.37), .09, colors['oak'])
    for turn in range(21):
        ring('Raised press screw thread', (center[0], center[1], 1.65 + turn * .07), .10, .019, colors['wood'], segments=16, sides=4)
    rod('Press screw handle', (center[0] - .7, center[1], 2.57), (center[0] + .7, center[1], 2.57), .043, colors['brass'])
    box('Suspended press platen', (center[0], center[1], 1.47), (1.34, 1.20, .20), colors['oak'], .045)
    sheet((center[0], center[1] - .34, 1.16), colors, 1.14, .89, True)


def build_scriptorium(output):
    SCROLL_PROTOTYPES.clear()
    create_scene('Illuminators and castle printing room')
    colors = palette()
    for horizontal in (-29.5, -20.5):
        desk((horizontal, -7.8), 3.5, 1.65, colors)
        for offset in (-.9, .9):
            sheet((horizontal + offset, -7.75, 1.16), colors, illuminated=True)
            writing_set((horizontal + offset + .37, -7.32, 1.15), colors)
            stool((horizontal + offset, -9.15), colors)
        candle((horizontal, -7.7, 1.16), colors)
        for pigment in range(5):
            cylinder('Illuminators pigment pot', (horizontal - .44 + pigment * .22, -7.2, 1.20), .065, .10, colors[('red', 'green', 'blue', 'brass', 'ink')[pigment]], 12)
        box('Desk parchment keeper', (horizontal, -7.1, 1.32), (1.3, .24, .27), colors['oak'])
        for roll in range(4):
            scroll((horizontal - .43 + roll * .28, -7.1, 1.5), colors, .085, .48)
    press((-29.4, -16.3), colors)
    desk((-23.6, -16.3), 3.7, 1.8, colors)
    for page in range(5):
        sheet((-24.8 + page * .58, -16.3, 1.16 + page * .006), colors, .53, .8, True)
    box('Printers type tray', (-23.6, -15.66, 1.25), (3.25, .36, .14), colors['oak'])
    for index in range(24):
        box('Individual printing block', (-25.05 + index * .127, -15.66, 1.35), (.085, .24, .14), colors['wood'], .01)
    candle((-22.1, -16.6, 1.17), colors)
    for horizontal in (-33.6, -15.4):
        cabinet((horizontal, -5.2), 2.6, colors, 4, 5)
    box('Drafting map frame', (-34.75, -10.1, 1.65), (.16, 4.7, 2.9), colors['oak'], .04)
    box('Pinned parchment map', (-34.65, -10.1, 1.7), (.02, 4.35, 2.53), colors['paper'], 0)
    for index in range(13):
        depth = -12.05 + index * .31
        rod('Map survey grid', (-34.63, depth, .58), (-34.63, depth, 2.84), .005, colors['wood'])
    for index in range(8):
        rod('Map survey grid', (-34.63, -12.2, .62 + index * .3), (-34.63, -8, .62 + index * .3), .005, colors['wood'])
    castle_source = (Path(__file__).resolve().parents[2] / 'scenes/world/castle_dressing.gd').read_text()
    bounds_line = next(line for line in castle_source.splitlines() if line.startswith('const ROOM_BOUNDS:'))
    for index, values in enumerate(re.findall(r'Rect2\(([^)]+)\)', bounds_line)):
        horizontal, depth, width, length = [float(value) for value in values.split(',')]
        center = (-34.60, -10.1 + (depth + length / 2 - 40) * .036, 1.7 + (horizontal + width / 2 - 6) * .028)
        box('Surveyed castle room', center, (.025, length * .036 - .026, width * .028 - .026), colors['blue' if index % 3 else 'green'], 0)
    for depth in (-14.9, -18.4):
        box('Drying rack upright', (-33.1, depth, 1.57), (.13, .13, 3.14), colors['oak'])
    for level in range(3):
        height = 1 + level * .78
        rod('Parchment drying line', (-33.1, -18.4, height), (-33.1, -14.9, height), .012, colors['edge'])
        for page in range(4):
            box('Fresh printed page hanging to dry', (-33.1, -18 + page * .78, height - .26), (.014, .55, .54), colors['paper'], 0)
            for line in range(5):
                box('Drying page printed lines', (-33.089, -18 + page * .78, height - .12 - line * .063), (.003, .38, .008), colors['ink'], 0)
    collider('Drying frame', (-33.1, -16.65, 1.56), (.25, 3.65, 3.12))
    for horizontal in (-32.0, -22.0, -14.5):
        box('Scriptorium carved wainscot', (horizontal, -4.48, 1.05), (2.25, .2, 2.1), colors['oak'])
    export_asset(output / 'scriptorium.glb', colors['oak'])


def build_archives(output):
    SCROLL_PROTOTYPES.clear()
    create_scene('Royal archive records and survey room')
    colors = palette()
    for horizontal in (-18.1, -9.9):
        for depth in (-74, -78, -88.7):
            cabinet((horizontal, depth), 2.0, colors, 3, 5)
    desk((-14, -75.8), 3.15, 4.0, colors)
    for offset in (-1.25, -.35, .55, 1.35):
        scroll((-14.7, -75.8 + offset, 1.25), colors, .11, .63, True)
        sheet((-13.6, -75.8 + offset, 1.17), colors, .9, .63, True)
    candle((-14, -75.8, 1.17), colors)
    desk((-14.3, -88.5), 4.1, 1.8, colors)
    sheet((-14.3, -88.5, 1.17), colors, 2.2, 1.45, True)
    writing_set((-12.6, -88, 1.16), colors)
    stool((-14.3, -87.1), colors)
    for horizontal in (-15.95, -12.65):
        candle((horizontal, -88.7, 1.17), colors)
    for horizontal in (-16.5, -12):
        cabinet((horizontal, -91.0), 3.3, colors, 5, 5)
    desk((-10.1, -71.1), 1.4, 2.5, colors)
    for stack in range(4):
        box('Tied stack of folded records', (-10.1, -70.35 - stack * .5, 1.32), (.8, .4, .32), colors['paper'], .018)
        box('Red tape binding records', (-10.1, -70.35 - stack * .5, 1.488), (.065, .43, .015), colors['red'], 0)
    box('Document dispatch cart platform', (-17.5, -86.4, .4), (1.35, 1.5, .12), colors['wood'])
    for side in (-1, 1):
        for end in (-1, 1):
            wheel = cylinder('Dispatch cart iron wheel', (-17.5 + side * .66, -86.4 + end * .48, .28), .23, .07, colors['ink'], 16)
            wheel.rotation_euler.y = math.pi / 2
        rod('Cart push handle upright', (-17.5 + side * .55, -86.95, .4), (-17.5 + side * .55, -86.95, 1.24), .04, colors['brass'])
    rod('Cart handle', (-18.05, -86.95, 1.24), (-16.95, -86.95, 1.24), .045, colors['wood'])
    for row in range(3):
        for column in range(4):
            scroll((-17.93 + column * .27, -86.4, .58 + row * .2), colors, .1, .84, True)
    collider('Dispatch cart', (-17.5, -86.4, .68), (1.55, 1.6, 1.36))
    for depth in (-68.65, -91.65):
        box('Archive wall heraldic panel', (-14, depth, 2.4), (1.25, .12, 2.2), colors['green'])
        box('Archive heraldic gilt inset', (-14, depth - .075, 2.4), (.63, .025, 1.4), colors['brass'])
    export_asset(output / 'archives.glb', colors['oak'])


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', type=Path, required=True)
    arguments = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    build_scriptorium(arguments.output)
    build_archives(arguments.output)


if __name__ == '__main__':
    main()
