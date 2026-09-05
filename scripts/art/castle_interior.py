import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import castle_mesh as geometry

COLLISIONS = []


def point(position):
    return (position[0], -position[2], position[1])


def block(name, center, size, surface='oak', bevel=.025, solid=False):
    result = geometry.box(name, point(center), (size[0], size[2], size[1]), surface, bevel)
    if solid:
        collider(name, center, size)
    return result


def beam(name, start, end, radius, surface='iron'):
    return geometry.rod(name, point(start), point(end), radius, surface)


def orb(name, center, size, surface):
    return geometry.sphere(name, point(center), (size[0], size[2], size[1]), surface)


def collider(name, center, size):
    vertices = [point((center[0] + horizontal * size[0] / 2, center[1] + height * size[1] / 2, center[2] + depth * size[2] / 2)) for depth in (-1, 1) for height in (-1, 1) for horizontal in (-1, 1)]
    faces = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    COLLISIONS.append((name, vertices, [tuple(reversed(face)) for face in faces]))


def arch(name, center, radius, thickness, depth, surface='stone_light', along_depth=False):
    for segment in range(17):
        angles = [segment * math.pi / 17, (segment + 1) * math.pi / 17]
        outline = [(math.cos(angle) * ring, math.sin(angle) * ring) for ring, angle in [(radius, angles[0]), (radius, angles[1]), (radius + thickness, angles[1]), (radius + thickness, angles[0])]]
        vertices = []
        for side in (-1, 1):
            for horizontal, height in outline:
                world = (center[0] + (side * depth / 2 if along_depth else horizontal), center[1] + height, center[2] + (horizontal if along_depth else side * depth / 2))
                vertices.append(point(world))
        mesh = geometry.bpy.data.meshes.new(name)
        faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
        mesh.from_pydata(vertices, [], faces if along_depth else [tuple(reversed(face)) for face in faces])
        obj = geometry.bpy.data.objects.new(name, mesh)
        geometry.bpy.context.collection.objects.link(obj)
        geometry.finish(obj, name, surface)


def document(center, width=.65, depth=.9, seal=False):
    block('Parchment sheet', center, (width, .014, depth), 'cream', .003)
    for line in range(6):
        block('Handwritten ledger line', (center[0], center[1] + .011, center[2] - depth * .33 + line * depth * .105), (width * .72, .003, .011), 'soot', 0)
    if seal:
        orb('Wax seal', (center[0] + width * .27, center[1] + .035, center[2] + depth * .3), (.075, .025, .075), 'wine')


def candle(center, height=.48):
    geometry.candle(point(center), height)


def desk(center, width, depth, height=1.1):
    geometry.table(point(center), width, depth, height)
    collider('Solid oak desk', (center[0], center[1] + height / 2, center[2]), (width, height + .17, depth))


def bench(center, width, surface='oak'):
    block('Bench seat cushion', (center[0], center[1] + .61, center[2]), (width, .17, .67), 'wine', .07)
    block('Bench carved back', (center[0], center[1] + 1.03, center[2] - .32), (width, .95, .12), surface, .03)
    for side in (-1, 1):
        block('Bench scroll arm', (center[0] + side * (width / 2 - .1), center[1] + .85, center[2]), (.16, .15, .85), 'cut_oak')
        block('Bench broad foot', (center[0] + side * (width / 2 - .2), center[1] + .28, center[2]), (.24, .55, .6), surface)
    for division in range(max(2, round(width / .6))):
        block('Carved bench panel inset', (center[0] - width / 2 + .3 + division * (width - .6) / max(1, round(width / .6) - 1), center[1] + 1.08, center[2] - .242), (.29, .5, .025), 'edge', .015)
    collider('Court seating', (center[0], center[1] + .74, center[2]), (width, 1.48, .85))
