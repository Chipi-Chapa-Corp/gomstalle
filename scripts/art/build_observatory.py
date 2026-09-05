import math
from pathlib import Path
import sys

import bpy
from mathutils import Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
from workshop_geometry import box, collider, create_scene, cylinder, export_asset, finish, lathe, ring, rod, tube
from build_scholars import palette, sheet, candle, writing_set, desk


def sphere(name, center, radius, surface):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=10, radius=radius, location=center)
    return finish(bpy.context.object, name, surface)


def telescope(colors):
    center = Vector((4.2, -87.5, 6.2))
    direction = Vector((-1, 1, .52)).normalized()
    lathe('Telescope masonry instrument pier', (4.2, -87.5, 4.05), [(1.1, 0), (1.1, .18), (.78, .32), (.63, 1.1), (.78, 1.25), (.78, 1.42)], colors['oak'], 32)
    cylinder('Equatorial brass bearing', (4.2, -87.5, 5.52), .81, .15, colors['brass'], 32)
    for side in (-1, 1):
        tube('Telescope curved mount fork', [(4.2 + side * .57, -87.5, 5.57), (4.2 + side * .85, -87.5, 5.82), (4.2 + side * .73, -87.5, 6.3)], .095, colors['brass'])
    rod('Optical telescope barrel', center - direction * 1.55, center + direction * 1.7, .53, colors['blue'])
    for distance in (-1.5, -.8, .25, 1.55):
        rod('Telescope engraved brass collar', center + direction * (distance - .055), center + direction * (distance + .055), .566, colors['brass'])
    rod('Telescope objective hood', center + direction * 1.45, center + direction * 1.84, .61, colors['oak'])
    rod('Telescope blue objective lens', center + direction * 1.848, center + direction * 1.865, .54, colors['green'])
    rod('Telescope silvered lens glint', center + direction * 1.869, center + direction * 1.875, .27, colors['blue'])
    rod('Telescope rear focus tube', center - direction * 1.95, center - direction * 1.45, .15, colors['brass'])
    rod('Telescope eyepiece', center - direction * 2.08, center - direction * 1.96, .21, colors['oak'])
    ring('Telescope declination setting circle', (4.2, -87.5, 6.15), .92, .04, colors['brass'], (math.pi / 2, 0, 0))
    for degree in range(0, 360, 10):
        angle = math.radians(degree)
        rod('Engraved telescope angular graduations', (4.2 + math.cos(angle) * .84, -87.56, 6.15 + math.sin(angle) * .84), (4.2 + math.cos(angle) * .93, -87.56, 6.15 + math.sin(angle) * .93), .008, colors['paper'])
    collider('Telescope instrument plinth', (4.2, -87.5, 5.2), (2.1, 2.1, 2.4))
    box('Astronomers observing step', (6.4, -89.1, 4.28), (1.15, .78, .45), colors['wood'], .045, True)
    box('Astronomers observing step', (6.4, -88.35, 4.14), (1.15, .73, .18), colors['wood'], .025, True)


def orrery(colors):
    center = Vector((1.0, -75.2, 0))
    lathe('Orrery octagonal cabinet', center, [(1.2, .05), (1.25, .18), (1.13, .32), (1.13, .9), (1.3, 1.04), (1.3, 1.16)], colors['oak'], 8)
    cylinder('Orrery brass face plate', (1, -75.2, 1.18), 1.25, .065, colors['brass'], 48)
    cylinder('Orrery midnight sky inset', (1, -75.2, 1.22), 1.16, .035, colors['blue'], 48)
    sphere('Orrery gilded sun', (1, -75.2, 1.95), .28, colors['brass'])
    rod('Orrery sun axle', (1, -75.2, 1.24), (1, -75.2, 1.95), .045, colors['brass'])
    for index, radius in enumerate((.42, .65, .89, 1.1)):
        ring('Orrery engraved planetary orbit', (1, -75.2, 1.25), radius, .009, colors['brass'], segments=40, sides=4)
        angle = .8 + index * 1.8
        endpoint = Vector((1 + math.cos(angle) * radius, -75.2 + math.sin(angle) * radius, 1.55 + index * .1))
        rod('Orrery working planet arm', (1, -75.2, 1.43 + index * .05), endpoint, .016, colors['brass'])
        sphere('Orrery colored planet', endpoint, .06 + index * .019, colors[('red', 'green', 'paper', 'blue')[index]])
    ring('Orrery meridian hoop', (1, -75.2, 1.66), 1.43, .028, colors['brass'], (math.pi / 2.2, .2, 0))
    for index in range(12):
        angle = math.tau * index / 12
        box('Orrery zodiac ivory index', (1 + math.cos(angle) * 1.2, -75.2 + math.sin(angle) * 1.2, 1.23), (.07, .05, .018), colors['paper'], .003)
    collider('Orrery cabinet', (1, -75.2, .64), (2.55, 2.55, 1.28))


def star_chart(center, colors, width, height):
    box('Framed star chart back', center, (width, .12, height), colors['oak'], .03)
    box('Midnight constellation chart', (center[0], center[1] - .07, center[2]), (width - .16, .035, height - .16), colors['blue'], .01)
    for radius in (.37, .7, 1.0):
        ring('Star chart celestial coordinate circle', (center[0], center[1] - .096, center[2]), radius * min(width, height) * .43, .006, colors['edge'], (math.pi / 2, 0, 0), segments=40, sides=4)
    points = [(center[0] + math.sin(index * 2.4) * width * .35, center[1] - .12, center[2] + math.cos(index * 1.8) * height * .34) for index in range(17)]
    for index, point in enumerate(points):
        sphere('Constellation chart gilded star', point, .025 if index % 3 else .04, colors['brass'])
        if index % 4:
            rod('Constellation chart connecting line', points[index - 1], point, .007, colors['paper'])


def build():
    create_scene('Astronomers instruments and celestial records')
    colors = palette()
    telescope(colors)
    orrery(colors)
    desk((-4.8, -75.2), 2.4, 4.0, colors)
    sheet((-4.8, -75.1, 1.16), colors, 1.7, 2.4, True)
    writing_set((-4.2, -76.5, 1.16), colors)
    candle((-5.4, -73.7, 1.16), colors)
    for offset in (-1, 1):
        rod('Drafting compass brass leg', (-4.8, -75.5, 1.17), (-4.8 + offset * .3, -74.6, 1.18), .015, colors['brass'])
    for horizontal in (-5, 8.5):
        star_chart((horizontal, -68.7, 2.3), colors, 3.3, 3.5)
    box('Instrument cabinet back', (10.5, -73.2, 1.65), (.14, 5.4, 3.3), colors['oak'])
    for level in range(4):
        height = .3 + level * .78
        box('Scientific instrument shelf', (10.2, -73.2, height), (.8, 5.4, .12), colors['wood'])
        if level < 3:
            for depth in (-71.3, -73.2, -75.1):
                box('Survey instrument case', (10.1, depth, height + .23), (.57, 1.35, .33), colors['blue'], .035)
                for side in (-1, 1):
                    box('Instrument case brass hinge', (9.81, depth + side * .42, height + .23), (.03, .09, .16), colors['brass'])
    collider('Survey instrument cabinet', (10.2, -73.2, 1.65), (.95, 5.55, 3.3))
    box('Upper observation chart desk', (2.0, -90.5, 4.62), (2.3, .9, 1.13), colors['oak'], .045, True)
    sheet((2.0, -90.5, 5.2), colors, 1.5, .67, True)
    candle((1.12, -90.5, 5.2), colors)
    writing_set((2.9, -90.5, 5.2), colors)
    for depth in (-86.4, -89.5):
        box('West tower records cabinet', (-6.6, depth, 1.2), (1.15, 2.3, 2.4), colors['oak'], .035, True)
        for drawer in range(8):
            box('Survey chart flat drawer', (-5.995, depth, .25 + drawer * .28), (.12, 2.0, .22), colors['wood'], .012)
            for side in (-1, 1):
                ring('Flat file brass pull', (-5.915, depth + side * .63, .25 + drawer * .28), .048, .012, colors['brass'], (0, math.pi / 2, 0), segments=16, sides=4)
    export_asset(Path(__file__).resolve().parents[2] / 'assets/castle/scholars/observatory.glb', colors['oak'])


build()
