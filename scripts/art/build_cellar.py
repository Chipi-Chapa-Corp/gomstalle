import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import castle_mesh as geometry
from castle_interior import COLLISIONS, beam, block, candle, collider, desk, document, orb, point


def barrel(center, radius, length, axis=(1, 0), tap=False):
    perpendicular = (-axis[1], axis[0])
    def location(distance, angle, radial):
        return point((center[0] + axis[0] * distance + perpendicular[0] * math.cos(angle) * radial, center[1] + math.sin(angle) * radial, center[2] + axis[1] * distance + perpendicular[1] * math.cos(angle) * radial))
    profile = [(-length / 2, .81), (-length * .38, .9), (0, 1), (length * .38, .9), (length / 2, .81)]
    for stave in range(18):
        angle_start = stave * math.tau / 18 + .008
        angle_end = (stave + 1) * math.tau / 18 - .008
        vertices = [location(distance, angle, radius * bulge) for distance, bulge in profile for angle in (angle_start, angle_end)]
        faces = [(index * 2, index * 2 + 1, index * 2 + 3, index * 2 + 2) for index in range(len(profile) - 1)]
        mesh = geometry.bpy.data.meshes.new('Individual curved oak barrel stave')
        mesh.from_pydata(vertices, [], [tuple(reversed(face)) for face in faces])
        obj = geometry.bpy.data.objects.new('Individual curved oak barrel stave', mesh)
        geometry.bpy.context.collection.objects.link(obj)
        geometry.finish(obj, 'Individual curved oak barrel stave', 'cut_oak' if stave % 3 else 'oak')
    for distance, bulge in [(-length * .43, .865), (-length * .27, .93), (length * .27, .93), (length * .43, .865)]:
        for segment in range(24):
            start = location(distance, segment * math.tau / 24, radius * bulge + .025)
            end = location(distance, (segment + 1) * math.tau / 24, radius * bulge + .025)
            geometry.rod('Forged barrel hoop', start, end, .045 * radius, 'iron', 6)
    for end in (-1, 1):
        distance = end * (length / 2 + .006)
        for plank in range(9):
            offset = (-.72 + plank * .18) * radius
            height = math.sqrt(max(.01, (radius * .8) ** 2 - offset ** 2)) * 2
            block('Barrel head planked board', (center[0] + axis[0] * distance + perpendicular[0] * offset, center[1], center[2] + axis[1] * distance + perpendicular[1] * offset), ((.07 if axis[0] else .17 * radius), height, (.07 if axis[1] else .17 * radius)), 'cut_oak', .006)
    if tap:
        distance = length / 2 + .11
        spigot = (center[0] + axis[0] * distance, center[1] - radius * .42, center[2] + axis[1] * distance)
        beam('Brass barrel spigot', spigot, (spigot[0] + axis[0] * .25, spigot[1], spigot[2] + axis[1] * .25), .05, 'brass')
        beam('Downturned tap outlet', (spigot[0] + axis[0] * .25, spigot[1], spigot[2] + axis[1] * .25), (spigot[0] + axis[0] * .25, spigot[1] - .15, spigot[2] + axis[1] * .25), .044, 'brass')
        beam('Tap stopcock handle', (spigot[0] + axis[0] * .12, spigot[1] + .05, spigot[2] + axis[1] * .12), (spigot[0] + axis[0] * .12, spigot[1] + .24, spigot[2] + axis[1] * .12), .025, 'iron')
    collider('Stored wine barrel', center, ((length if axis[0] else radius * 2), radius * 2, (length if axis[1] else radius * 2)))


def cradle(center, radius, length, axis):
    perpendicular = (-axis[1], axis[0])
    for distance in (-length * .3, length * .3):
        for side in (-1, 1):
            start = (center[0] + axis[0] * distance + perpendicular[0] * side * radius * .88, .14, center[1] + axis[1] * distance + perpendicular[1] * side * radius * .88)
            end = (center[0] + axis[0] * distance, radius * .53, center[1] + axis[1] * distance)
            beam('Barrel cradle angled oak support', start, end, .13, 'oak')
        block('Cradle broad timber foot', (center[0] + axis[0] * distance, .12, center[1] + axis[1] * distance), ((.32 if axis[0] else radius * 2), .24, (.32 if axis[1] else radius * 2)), 'oak')


def bottle(center, scale=1, color='green'):
    profile = [(.0, 0), (.105, 0), (.12, .035), (.12, .34), (.095, .43), (.045, .48), (.045, .66), (.055, .68), (.055, .72), (0, .72)]
    geometry.lathe('Corked cellar wine bottle', point(center), [(radius * scale, height * scale) for radius, height in profile], color, 12)
    geometry.lathe('Bottle cork', point((center[0], center[1] + .72 * scale, center[2])), [(.04 * scale, 0), (.04 * scale, .05 * scale), (0, .05 * scale)], 'crust', 10)
    block('Bottle parchment label', (center[0], center[1] + .23 * scale, center[2] + .122 * scale), (.14 * scale, .17 * scale, .015), 'cream', .003)


def cellar():
    geometry.initialize_scene()
    COLLISIONS.clear()
    barrel((-30, 2.05, 22.25), 1.65, 2.25, (0, 1), True)
    cradle((-30, 22.25), 1.65, 2.25, (0, 1))
    for depth in (29.4, 34.2, 39.0):
        barrel((-34.2, 1.5, depth), 1.15, 2.1, (1, 0), depth == 29.4)
        cradle((-34.2, depth), 1.15, 2.1, (1, 0))
    for horizontal in (-28.1, -25.0):
        block('Wine rack carved upright', (horizontal, 1.45, 30.4), (.15, 2.9, 1.1), 'oak', .025)
    block('Wine rack back', (-26.55, 1.45, 29.88), (3.25, 2.9, .12), 'oak')
    for shelf in range(4):
        height = .2 + shelf * .72
        block('Cellar bottle shelf', (-26.55, height, 30.4), (3.3, .12, 1.12), 'cut_oak')
        for slot in range(7):
            horizontal = -27.8 + slot * .42
            bottle((horizontal, height + .07, 30.65), .83, 'green' if shelf % 2 else 'water')
        for horizontal in (-27.55, -25.55):
            block('Brass cellar rack index', (horizontal, height, 30.975), (.45, .12, .025), 'brass', .005)
    collider('Cellar bottle storage rack', (-26.55, 1.48, 30.4), (3.35, 2.97, 1.15))
    desk((-29.0, 0, 41.2), 5.6, 2.0)
    document((-27.1, 1.21, 41.25), .7, 1.0, True)
    candle((-26.7, 1.22, 40.65), .62)
    for horizontal in (-30.9, -30.25, -29.6):
        bottle((horizontal, 1.22, 41.35), 1.1)
    block('Corking press foot', (-28.45, 1.25, 41.1), (.7, .09, .85), 'iron')
    beam('Corking press upright', (-28.45, 1.3, 40.87), (-28.45, 2.32, 40.87), .055, 'iron')
    beam('Cork press upper arm', (-28.45, 2.28, 40.87), (-28.45, 2.28, 41.25), .06, 'iron')
    beam('Cork press handle', (-28.45, 2.28, 41.15), (-27.98, 2.45, 41.15), .028, 'cut_oak')
    bottle((-28.45, 1.31, 41.15), .94)
    geometry.lathe('Copper wine funnel', point((-29.0, 1.23, 40.9)), [(.025, 0), (.025, .18), (.22, .4), (.24, .4), (.24, .43)], 'copper', 16)
    block('Open cork storage tray', (-27.1, 1.3, 41.95), (.8, .15, .35), 'oak')
    for cork in range(9):
        orb('Loose cork stopper', (-27.4 + cork % 5 * .14, 1.42, 41.87 + cork // 5 * .14), (.055, .055, .055), 'crust')
    block('Barrel transport trolley bed', (-29.5, .45, 36.3), (1.85, .16, 2.15), 'cut_oak')
    barrel((-29.5, 1.29, 36.3), .72, 1.75, (0, 1))
    for side in (-1, 1):
        for depth in (35.65, 36.95):
            beam('Trolley iron rim wheel', (-29.5 + side * 1.04 - .04, .37, depth), (-29.5 + side * 1.04 + .04, .37, depth), .31, 'iron')
        beam('Trolley pulling handle', (-29.5 + side * .7, .44, 35.22), (-29.5 + side * .7, .9, 34.4), .05, 'oak')
    beam('Trolley handle crossbar', (-30.2, .9, 34.4), (-28.8, .9, 34.4), .05, 'oak')
    collider('Barrel trolley route obstacle', (-29.5, .9, 35.85), (2.2, 1.8, 3.2))
    for depth in (37.4, 38.8):
        block('Transport bottle crate base', (-25.55, .13, depth), (1.3, .14, 1.2), 'oak', .015)
        for side in (-1, 1):
            for height in (.28, .57):
                block('Bottle crate open side slat', (-25.55 + side * .61, height, depth), (.08, .12, 1.2), 'cut_oak', .01)
                block('Bottle crate open end slat', (-25.55, height, depth + side * .56), (1.2, .12, .08), 'cut_oak', .01)
        for horizontal in (-25.9, -25.55, -25.2):
            for offset in (-.25, .25):
                bottle((horizontal, .21, depth + offset), .7)
        collider('Open transport bottle crate', (-25.55, .42, depth), (1.3, .8, 1.2))
    block('Spigot drip tray', (-32.85, .15, 29.4), (.55, .16, .8), 'copper')
    beam('Cellarmaster wine gauge stick', (-31.9, 0, 22), (-31.9, 3.2, 22.5), .04, 'cut_oak')
    geometry.save('cellar_working', COLLISIONS)


if __name__ == '__main__':
    cellar()
