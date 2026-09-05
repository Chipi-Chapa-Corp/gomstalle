import bpy
import math
from mathutils import Vector
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[2] / 'assets' / 'castle'
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
PALETTE = {
    'oak': ('51392b', 0.0), 'cut_oak': ('886748', 0.0), 'edge': ('b18c5d', 0.0),
    'stone': ('696568', 0.0), 'stone_light': ('81776e', 0.0), 'soot': ('302e32', 0.0),
    'iron': ('262b32', 0.7), 'pewter': ('9ba4a7', 0.75), 'brass': ('b89558', 0.75),
    'copper': ('a75c3b', 0.7), 'cream': ('d6c59d', 0.0), 'wine': ('672e42', 0.0),
    'green': ('657548', 0.0), 'crust': ('bc813e', 0.0), 'meat': ('8b4538', 0.0),
    'wax': ('e8ce99', 0.0), 'ember': ('e58336', 0.0), 'water': ('3e6268', 0.4),
}
MATERIALS = {}
for material_name, (hex_color, metal) in PALETTE.items():
    material = bpy.data.materials.new(material_name)
    srgb_channels = [int(hex_color[index:index + 2], 16) / 255 for index in (0, 2, 4)]
    material.diffuse_color = tuple(channel / 12.92 if channel < 0.04045 else ((channel + 0.055) / 1.055) ** 2.4 for channel in srgb_channels) + (1,)
    material.use_nodes = True
    shader = material.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = material.diffuse_color
    shader.inputs['Metallic'].default_value = metal
    shader.inputs['Roughness'].default_value = 0.48 if metal else 0.8
    if material_name == 'ember':
        shader.inputs['Emission Color'].default_value = material.diffuse_color
        shader.inputs['Emission Strength'].default_value = 2.0
    MATERIALS[material_name] = material


def finish(obj, name, material):
    obj.name = name
    obj.data.materials.append(MATERIALS[material])
    return obj


def box(name, center, dimensions, material, bevel=0.025, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if rotation:
        obj.rotation_euler = rotation
    if bevel:
        modifier = obj.modifiers.new('Crafted edges', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 1
        bpy.ops.object.modifier_apply(modifier=modifier.name)
        normal = obj.modifiers.new('Weighted planes', 'WEIGHTED_NORMAL')
        bpy.ops.object.modifier_apply(modifier=normal.name)
    return finish(obj, name, material)


def sphere(name, center, dimensions, material, subdivision=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivision, radius=1, location=center)
    obj = bpy.context.object
    obj.scale = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, material)


def rod(name, start, end, radius, material, vertices=10):
    delta = Vector(end) - Vector(start)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=delta.length, location=(Vector(start) + Vector(end)) / 2)
    obj = bpy.context.object
    obj.rotation_euler = delta.to_track_quat('Z', 'Y').to_euler()
    return finish(obj, name, material)


def lathe(name, center, profile, material, segments=16):
    vertices = []
    faces = []
    for radius, height in profile:
        for segment in range(segments):
            angle = segment * math.tau / segments
            vertices.append((center[0] + radius * math.cos(angle), center[1] + radius * math.sin(angle), center[2] + height))
    for layer in range(len(profile) - 1):
        for segment in range(segments):
            current = layer * segments + segment
            following = layer * segments + (segment + 1) % segments
            faces.append((current, following, following + segments, current + segments))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return finish(obj, name, material)


def plate(center, radius=0.33, material='pewter'):
    lathe('Dish with raised rim', center, [(0, 0), (radius * 0.75, 0), (radius, .045), (radius, .075), (radius * .76, .032), (0, .032)], material)


def bowl(center, radius=.3, material='copper'):
    lathe('Deep open bowl', center, [(0, 0), (radius * .55, 0), (radius * .85, .12), (radius, .3), (radius * .88, .3), (radius * .72, .12), (0, .06)], material)


def goblet(center):
    lathe('Footed wine goblet', center, [(0, 0), (.11, 0), (.12, .04), (.035, .08), (.035, .23), (.13, .28), (.16, .43), (.14, .45), (.11, .29), (0, .25)], 'brass', 12)


def candle(center, height=.5):
    lathe('Candle drip plate', center, [(0, 0), (.16, 0), (.18, .04), (.14, .065), (0, .04)], 'iron', 12)
    rod('Wax candle', (center[0], center[1], center[2] + .05), (center[0], center[1], center[2] + height), .065, 'wax')
    sphere('Small flame', (center[0], center[1], center[2] + height + .07), (.047, .047, .11), 'ember')


def bread(center, long=False):
    sphere('Baked loaf', center, (.47 if long else .3, .22, .16), 'crust', 2)
    for offset in [-.18, 0, .18] if long else [-.09, .09]:
        box('Scored bread crust', (center[0] + offset, center[1], center[2] + .13), (.04, .3, .016), 'cream', .004, (0, .15, -.35))


def jug(center, material='copper'):
    lathe('Serving jug', center, [(0, 0), (.16, 0), (.22, .12), (.24, .36), (.12, .53), (.13, .66), (.18, .69), (.145, .705), (.095, .65), (.08, .53)], material, 14)
    previous = (center[0] + .17, center[1], center[2] + .52)
    for step in range(1, 8):
        angle = math.pi * step / 7
        following = (center[0] + .17 + math.sin(angle) * .2, center[1], center[2] + .34 + math.cos(angle) * .18)
        rod('Jug handle', previous, following, .034, material, 6)
        previous = following


def plank_top(center, width, depth, height):
    for plank_index in range(5):
        box('Individual oak board', (center[0], center[1] - depth / 2 + (plank_index + .5) * depth / 5, center[2] + height), (width, depth / 5 - .018, .15), 'cut_oak', .022)
    for endpoint in [-1, 1]:
        box('Breadboard end', (center[0] + endpoint * (width / 2 - .07), center[1], center[2] + height + .004), (.14, depth + .04, .17), 'oak')


def table(center=(0, 0, 0), width=6.8, depth=2.2, height=1.15):
    plank_top(center, width, depth, height)
    for endpoint in [-1, 1]:
        horizontal = center[0] + endpoint * (width / 2 - .6)
        for side in [-1, 1]:
            box('Mortised trestle leg', (horizontal, center[1] + side * .65, center[2] + height / 2), (.22, .26, height), 'oak')
        box('Trestle foot', (horizontal, center[1], center[2] + .13), (.36, depth + .1, .22), 'oak')
        box('Trestle crossbeam', (horizontal, center[1], center[2] + .8), (.3, depth - .1, .22), 'oak')
    box('Long stretcher', (center[0], center[1], center[2] + .38), (width - .6, .18, .22), 'oak')


def save(name):
    bpy.ops.object.select_all(action='SELECT')
    bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    obj.data.uv_layers.new(name='Lightmap')
    obj.data.uv_layers.active_index = len(obj.data.uv_layers) - 1
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='SELECT')
    bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=.012)
    bpy.ops.object.mode_set(mode='OBJECT')
    bpy.context.scene.cursor.location = (0, 0, 0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / f'{name}.glb'), export_format='GLB', use_selection=True, export_materials='EXPORT', export_yup=True)
    print('FEAST_ASSET', name, sum(len(polygon.vertices) - 2 for polygon in obj.data.polygons))
    bpy.ops.object.delete(use_global=False)


def oven():
    box('Wide hearth foundation', (0, 0, .15), (7.2, 2.8, .3), 'stone', .06)
    box('Blackened rear fire wall', (0, .85, 1.6), (6.7, .5, 2.7), 'soot', .02)
    for column in [-3.1, -.5, 3.1]:
        for course in range(6):
            box('Dressed masonry pier', (column, .1, .5 + course * .42), (.55, 1.8, .4), 'stone_light' if course % 3 == 0 else 'stone', .025)
    for center_x, radius in [(-1.8, 1.01), (1.3, 1.45)]:
        for segment in range(11):
            first = math.pi * segment / 11
            last = math.pi * (segment + 1) / 11
            vertices = []
            for depth in [-.82, .92]:
                for arc_radius, angle in [(radius, first), (radius + .36, first), (radius + .36, last), (radius, last)]:
                    vertices.append((center_x + math.cos(angle) * arc_radius, depth, 1.32 + math.sin(angle) * arc_radius))
            mesh = bpy.data.meshes.new('Arch stone')
            mesh.from_pydata(vertices, [], [(0, 1, 2, 3), (4, 7, 6, 5), (0, 4, 5, 1), (1, 5, 6, 2), (2, 6, 7, 3), (3, 7, 4, 0)])
            obj = bpy.data.objects.new('Radial arch voussoir', mesh)
            bpy.context.collection.objects.link(obj)
            finish(obj, obj.name, 'stone_light' if segment % 3 == 1 else 'stone')
    box('Hearth lintel', (0, .15, 2.99), (7.2, 2, .28), 'stone_light', .05)
    box('Smoke hood', (0, .45, 3.35), (5.8, 1.35, .5), 'stone', .08)
    box('Soot crown', (0, .58, 3.66), (4.9, 1.05, .18), 'soot')
    for side in [-.7, 2.65]:
        rod('Spit upright', (side, -.62, .35), (side, -.62, 1.4), .045, 'iron')
        box('Spit foot', (side, -.62, .35), (.42, .5, .08), 'iron')
    rod('Turning spit', (-.85, -.62, 1.24), (2.95, -.62, 1.24), .045, 'iron')
    rod('Crank', (2.9, -.62, 1.24), (2.9, -.62, .99), .05, 'iron')
    rod('Crank grip', (2.9, -.62, .99), (3.15, -.62, .99), .065, 'oak')
    sphere('Roast on spit', (1.2, -.62, 1.24), (.86, .37, .38), 'meat', 2)
    for cut in [-.35, 0, .35]:
        box('Tied roast string', (1.2 + cut, -.64, 1.59), (.025, .42, .025), 'cream', .008)
    for coal_index in range(14):
        sphere('Hot coals', (.05 + (coal_index % 7) * .37, -.77 + (coal_index // 7) * .42, .36), (.19, .19, .09), 'ember' if coal_index % 3 else 'soot')
    for log_index in range(5):
        rod('Split firewood', (-2.4 + log_index % 3 * .38, -.66, .37 + log_index // 3 * .3), (-2.4 + log_index % 3 * .38, .45, .37 + log_index // 3 * .3), .15, 'oak')
    rod('Long bread peel handle', (-3.38, -.6, .25), (-3.38, .1, 2.4), .045, 'cut_oak')
    box('Bread peel blade', (-3.38, .1, 2.45), (.55, .1, .55), 'cut_oak', .06)
    save('feast_hearth')


def preparation():
    table(width=6.7, depth=2.25, height=1.15)
    plank_top((0, 0, 0), 5.6, 1.75, .3)
    for sack_x in [-2.0, -1.3]:
        sphere('Flour sack under table', (sack_x, 0, .62), (.35, .37, .38), 'cream', 2)
        rod('Gathered sack neck', (sack_x, 0, .82), (sack_x, 0, 1), .12, 'oak')
    for bowl_x in [1, 1.8, 2.5]:
        bowl((bowl_x, 0, .4), .3, 'copper')
    box('Meat chopping block', (-2.05, .05, 1.31), (1.7, 1.6, .17), 'edge')
    sphere('Joint for carving', (-2.05, 0, 1.56), (.57, .36, .22), 'meat', 2)
    rod('Exposed roast bone', (-2.45, 0, 1.56), (-2.9, 0, 1.56), .08, 'cream')
    box('Cleaver blade', (-1.55, -.15, 1.57), (.38, .035, .36), 'pewter', .01, (0, -.3, -.2))
    rod('Cleaver handle', (-1.4, -.18, 1.78), (-1.15, -.22, 1.94), .06, 'oak')
    box('Floured dough board', (.15, 0, 1.28), (2.15, 1.8, .08), 'cream', .04)
    sphere('Rolled dough', (.15, .2, 1.35), (.62, .39, .04), 'wax', 2)
    rod('Rolling pin', (-.45, -.49, 1.42), (.7, -.49, 1.42), .085, 'cut_oak')
    rod('Rolling pin handles', (-.7, -.49, 1.42), (.95, -.49, 1.42), .036, 'oak')
    bowl((.87, .62, 1.25), .24, 'cream')
    bread((-.6, .57, 1.39), True)
    box('Vegetable board', (2.25, -.1, 1.28), (1.4, 1.7, .08), 'edge')
    for vegetable_index in range(5):
        sphere('Cabbage head', (1.97 + vegetable_index % 2 * .47, .2 + vegetable_index // 2 * .22, 1.43), (.23, .21, .18), 'green', 2)
    for carrot_index in range(4):
        rod('Carrot', (1.94 + carrot_index * .18, -.5, 1.37), (2.11 + carrot_index * .18, -.1, 1.37), .045, 'crust')
    box('Kitchen knife', (2.8, -.33, 1.37), (.055, .39, .025), 'pewter', .008)
    box('Kitchen knife grip', (2.8, -.61, 1.37), (.07, .19, .07), 'oak', .01)
    save('feast_preparation')


def feast(name, interrupted):
    table(width=7.8, depth=2.5)
    box('Wine velvet table runner', (0, 0, 1.235), (7.85, .8, .035), 'wine', .012)
    for side in [-1, 1]:
        box('Hanging runner', (side * 3.93, 0, .91), (.03, .8, .67), 'wine', .01)
        box('Runner gold fringe', (side * 3.945, 0, .6), (.034, .82, .08), 'brass', .01)
    for seat_x in [-3.2, -1.6, 0, 1.6, 3.2]:
        for side in [-1, 1]:
            plate((seat_x, side * .86, 1.25))
            if not (interrupted and seat_x == 1.6 and side == -1):
                goblet((seat_x + .45, side * .98, 1.25))
            box('Folded table napkin', (seat_x - .38, side * .98, 1.29), (.16, .24, .035), 'cream', .015, (0, 0, .15))
            rod('Dining knife', (seat_x + .35, side * .56, 1.28), (seat_x + .35, side * .85, 1.28), .014, 'pewter', 6)
    for candle_x in [-2.05, 2.05]:
        candle((candle_x, 0, 1.27), .45)
    plate((-.9, 0, 1.27), .57, 'brass')
    if interrupted:
        sphere('Picked roast', (-.9, 0, 1.47), (.34, .22, .15), 'meat', 2)
        rod('Exposed platter bone', (-1.4, .05, 1.45), (-.5, .05, 1.45), .05, 'cream')
        sphere('Spilled red wine', (.75, -.35, 1.273), (.65, .24, .008), 'wine', 2)
        obj = lathe('Toppled cup', (1.17, -.38, 1.39), [(0, 0), (.13, 0), (.16, .26), (.13, .28), (.1, .05)], 'brass', 12)
        for vertex in obj.data.vertices:
            relative = vertex.co - Vector((1.17, -.38, 1.39))
            vertex.co = Vector((1.17, -.38, 1.39)) + Vector((relative.z, relative.y, -relative.x))
        bread((.1, .07, 1.39))
    else:
        sphere('Whole roast feast', (-.9, 0, 1.56), (.45, .32, .25), 'meat', 2)
        for drumstick_x in [-1.3, -.5]:
            sphere('Roasted drumstick', (drumstick_x, -.28, 1.47), (.18, .22, .13), 'meat', 2)
            rod('Drumstick bone', (drumstick_x, -.39, 1.47), (drumstick_x, -.6, 1.47), .04, 'cream')
        bowl((.55, 0, 1.27), .4, 'brass')
        for fruit_index in range(6):
            sphere('Fruit bowl apples', (.35 + fruit_index % 3 * .18, -.1 + fruit_index // 3 * .2, 1.54), (.11, .11, .11), 'green' if fruit_index % 2 else 'wine', 2)
        bread((1.37, 0, 1.4), True)
    jug((-2.88, 0, 1.25))
    save(name)


def sideboard():
    box('Sideboard cabinet', (0, .1, .68), (5, 1, 1.25), 'oak', .06)
    plank_top((0, 0, 0), 5.25, 1.35, 1.34)
    for door_x in [-1.65, 0, 1.65]:
        box('Sideboard framed door', (door_x, -.435, .7), (1.43, .075, .99), 'edge')
        box('Sideboard recessed panel', (door_x, -.483, .7), (1.18, .03, .73), 'oak')
        rod('Sideboard knob', (door_x + .39, -.5, .78), (door_x + .39, -.61, .78), .045, 'brass')
    for height in [1.65, 2.43]:
        box('Silver display shelf', (0, .37, height), (4.8, .48, .1), 'oak')
    for horizontal in [-2.3, 2.3]:
        box('Shelf carved upright', (horizontal, .5, 2.12), (.12, .15, 1.7), 'edge')
    for dish_x in [-1.7, -.9, 0, .9, 1.7]:
        goblet((dish_x, .32, 2.49))
    for pile_x in [-1.6, -.6]:
        for dish_index in range(5):
            plate((pile_x, -.13, 1.43 + dish_index * .06), .3)
    jug((1.55, -.05, 1.42), 'pewter')
    bowl((.65, -.13, 1.43), .38, 'pewter')
    save('feast_sideboard')


def pantry():
    for post_x in [-2.4, 0, 2.4]:
        for post_y in [-.65, .65]:
            box('Pantry rack upright', (post_x, post_y, 1.4), (.15, .15, 2.8), 'oak')
    for shelf_z in [.15, 1, 1.95, 2.8]:
        box('Pantry rack shelf', (0, 0, shelf_z), (5, 1.55, .13), 'cut_oak')
    for bin_x in [-1.8, -.6, .6, 1.8]:
        for board_y in [-.64, .64]:
            box('Produce bin rim', (bin_x, board_y, .45), (1.06, .09, .48), 'edge')
        for side in [-1, 1]:
            box('Produce bin side', (bin_x + side * .53, 0, .45), (.08, 1.3, .48), 'cut_oak')
        for item_index in range(8):
            sphere('Stored cabbage and turnips', (bin_x -.3 + item_index % 3 * .29, -.38 + item_index // 3 * .33, .44), (.2, .2, .18), 'green' if bin_x < 0 else 'cream', 2)
    for sack_x in [-1.9, -.9, .4]:
        sphere('Grain sack', (sack_x, 0, 1.41), (.34, .4, .4), 'cream', 2)
        rod('Tied sack neck', (sack_x, 0, 1.68), (sack_x, 0, 1.84), .08, 'oak')
    for jar_x in [-1.9, -.95, 0, .95, 1.9]:
        jug((jar_x, 0, 2.02), 'copper' if jar_x < 0 else 'cream')
    save('feast_pantry')


def wash():
    for foot_x in [-2.2, -.3]:
        box('Stone sink pier', (foot_x, 0, .52), (.35, 1.15, 1.04), 'stone')
    box('Stone basin floor', (-1.25, 0, .98), (2.75, 1.35, .18), 'stone_light')
    for basin_y in [-.64, .64]:
        box('Stone basin lip', (-1.25, basin_y, 1.2), (2.75, .15, .42), 'stone')
    for basin_x in [-2.55, .05]:
        box('Stone basin end', (basin_x, 0, 1.2), (.15, 1.35, .42), 'stone')
    box('Still water', (-1.25, 0, 1.14), (2.43, 1.06, .025), 'water', .01)
    table((1.35, 0, 0), 2.1, 1.3, 1.07)
    for rail_index in range(9):
        box('Draining rack slat', (.55 + rail_index * .2, 0, 1.19), (.07, 1.1, .08), 'edge', .01)
    for plate_index in range(4):
        plate((1 + plate_index * .24, 0, 1.23), .25)
    jug((2.09, .2, 1.24), 'cream')
    box('Water cistern', (-1.3, .53, 2.05), (1.4, .7, 1.05), 'copper', .07)
    rod('Cistern tap', (-1.3, .1, 1.69), (-1.3, -.15, 1.69), .07, 'brass')
    rod('Downturned tap', (-1.3, -.15, 1.69), (-1.3, -.15, 1.55), .065, 'brass')
    box('Floor gutter', (-1.25, -.92, .07), (2.9, .38, .12), 'soot')
    for grate_index in range(12):
        box('Drain grate', (-2.58 + grate_index * .24, -.92, .14), (.065, .38, .04), 'iron', .01)
    save('feast_wash')


def dais():
    box('Lower lord dais step', (0, 0, .15), (4.8, 6.8, .3), 'stone', .06)
    box('Upper lord dais step', (.23, 0, .45), (4.35, 6.4, .3), 'stone_light', .04)
    box('Dais crimson carpet', (.3, 0, .616), (3.9, 5.95, .028), 'wine', .008)
    for border_y in [-2.82, 2.82]:
        box('Woven carpet edge', (.3, border_y, .636), (3.65, .055, .015), 'brass', .005)
    box('Throne seat', (.77, 0, 1.3), (1.15, 1.55, .25), 'oak')
    box('Throne velvet cushion', (.65, 0, 1.46), (1.05, 1.35, .11), 'wine', .07)
    for seat_y in [-.67, .67]:
        for seat_x in [.3, 1.22]:
            box('Throne carved leg', (seat_x, seat_y, .98), (.16, .18, .78), 'oak')
        box('Throne arm rest', (.65, seat_y, 1.9), (1.3, .18, .18), 'edge')
        box('Throne arm pillar', (.2, seat_y, 1.64), (.13, .13, .54), 'oak')
    box('High throne back', (1.3, 0, 2.12), (.22, 1.58, 1.86), 'oak')
    box('Upholstered throne back', (1.17, 0, 2.12), (.035, 1.25, 1.42), 'wine')
    for finial_y in [-.71, .71]:
        rod('Throne back finial', (1.3, finial_y, 2.96), (1.3, finial_y, 3.3), .085, 'brass')
        sphere('Throne finial', (1.3, finial_y, 3.31), (.14, .14, .17), 'brass')
    for banner_y in [-2.3, 2.3]:
        box('Dais canopy pillar', (1.72, banner_y, 2.17), (.2, .2, 3.15), 'oak')
        box('Canopy side valance', (1.4, banner_y, 3.48), (.65, .12, .65), 'wine')
        box('Canopy gold hem', (1.4, banner_y, 3.17), (.67, .14, .1), 'brass')
    box('Canopy carved crown', (1.72, 0, 3.71), (.28, 4.95, .2), 'edge')
    box('Royal tapestry', (1.79, 0, 2.4), (.06, 4.2, 2.35), 'wine')
    for chevron_side in [-1, 1]:
        box('Gold royal chevron', (1.75, chevron_side * .43, 2.9), (.035, .13, 1.25), 'brass', .008, (chevron_side * -.58, 0, 0))
    table((-.65, 0, .6), 1.4, 2.2, .9)
    plate((-.65, -.45, 1.61), .36, 'brass')
    goblet((-.65, .42, 1.61))
    candle((-.65, .88, 1.61), .43)
    save('feast_dais')


def serving_hatch():
    for pillar_x in [-1.75, 1.75]:
        for course in range(9):
            box('Serving hatch jamb stone', (pillar_x, 0, .225 + course * .42), (.5, 1.12, .4), 'stone_light' if course % 3 == 0 else 'stone')
    for course in range(4):
        for stone_index in range(4):
            box('Serving hatch lintel course', (-1.3125 + stone_index * .875, 0, 2.46 + course * .44), (.863, 1.08, .428), 'stone_light' if (stone_index + course) % 4 == 0 else 'stone', .018)
    box('Hatch dark capstone', (0, 0, 3.92), (4.08, 1.13, .18), 'soot', .025)
    for edge_x in [-1.46, 1.46]:
        box('Hatch inset timber frame', (edge_x, -.61, 1.67), (.14, .18, 1.3), 'oak')
    box('Hatch timber head', (0, -.61, 2.27), (3.1, .19, .15), 'edge')
    box('Serving sill masonry', (0, 0, .5), (3.2, 1, 1), 'stone')
    plank_top((0, -.55, 0), 6.7, 2, 1.05)
    for support_x in [-2.85, 2.85]:
        box('Pass cabinet', (support_x, -.9, .5), (.85, 1.2, 1), 'oak')
        for shelf_height in [.25, .6]:
            box('Pass cabinet shelf', (support_x, -.98, shelf_height), (.75, 1.15, .08), 'cut_oak')
    for stack_index in range(5):
        plate((-2.72, -.7, 1.14 + stack_index * .058), .36)
    for plate_y in [-.1, -1.05]:
        plate((2.65, plate_y, 1.14), .38)
        bread((2.65, plate_y, 1.3))
    jug((-2.15, -1, 1.14), 'pewter')
    save('feast_serving_hatch')


def cookware():
    rod('Cookware hanging rail', (-2.2, 0, 1.4), (2.2, 0, 1.4), .055, 'iron')
    for bracket_x in [-2, 2]:
        rod('Wall rail bracket', (bracket_x, .45, 1.4), (bracket_x, -.12, 1.4), .045, 'iron')
        box('Wall rail mount', (bracket_x, .47, 1.4), (.18, .08, .3), 'iron')
    for pan_x, radius in [(-1.7, .32), (-.65, .43), (.55, .34)]:
        rod('Pan handle', (pan_x, 0, 1.35), (pan_x, 0, .55), .045, 'iron')
        pan = lathe('Hanging copper skillet', (pan_x, 0, .43), [(0, 0), (radius * .8, 0), (radius, .09), (radius, .18), (radius * .87, .17), (radius * .7, .065), (0, .06)], 'copper', 16)
        for vertex in pan.data.vertices:
            relative = vertex.co - Vector((pan_x, 0, .43))
            vertex.co = Vector((pan_x, 0, .43)) + Vector((relative.x, -relative.z, relative.y))
    for ladle_x in [1.3, 1.7]:
        rod('Long serving ladle', (ladle_x, 0, 1.35), (ladle_x, 0, .23), .035, 'iron')
        bowl((ladle_x, -.08, .12), .15, 'copper')
    save('feast_cookware')


def grain_station():
    box('Mill oak support', (0, 0, .52), (1.75, 1.75, .95), 'oak', .06)
    for leg_x in [-.7, .7]:
        for leg_y in [-.7, .7]:
            box('Mill leg', (leg_x, leg_y, .55), (.18, .18, 1.1), 'cut_oak')
    lathe('Lower quern stone', (0, 0, 1), [(0, 0), (.88, 0), (.88, .18), (0, .18)], 'stone', 20)
    lathe('Upper rotating quern', (0, 0, 1.2), [(.16, 0), (.83, 0), (.82, .21), (.17, .25), (.16, 0)], 'stone_light', 20)
    rod('Quern turning handle', (.62, 0, 1.38), (.62, 0, 1.96), .065, 'cut_oak')
    for groove_index in range(8):
        angle=groove_index * math.tau / 8
        rod('Stone radial channel', (.28 * math.cos(angle), .28 * math.sin(angle), 1.453), (.7 * math.cos(angle), .7 * math.sin(angle), 1.431), .009, 'soot', 4)
    bowl((-.2, -1.03, .12), .42, 'cut_oak')
    sphere('Milled flour', (-.2, -1.03, .32), (.33, .33, .1), 'cream', 2)
    for sack_x, sack_y in [(1.25, -.1), (1.18, .85), (-1.16, .6)]:
        sphere('Grain sack by mill', (sack_x, sack_y, .45), (.36, .4, .44), 'cream', 2)
        rod('Sack tie', (sack_x, sack_y, .74), (sack_x, sack_y, .93), .1, 'oak')
    save('feast_grain_station')


def banquet_architecture():
    for wall_y, inward in [(5.4, -1), (-5.4, 1)]:
        for panel_x in [-8, -4.5, -1, 2.5, 6, 9.5]:
            if wall_y < 0 and panel_x > 4:
                continue
            box('Oak wall panelling', (panel_x, wall_y, .68), (3.5, .15, 1.36), 'oak')
            front_y = wall_y + inward * .1
            for rail_z in [.12, 1.3]:
                box('Wainscot moulding', (panel_x, front_y, rail_z), (3.52, .16, .13), 'cut_oak')
            for stile_x in [-1.68, -.56, .56, 1.68]:
                box('Panel carved stile', (panel_x + stile_x, front_y, .69), (.09, .14, 1.16), 'edge')
            for inset_x in [-1.12, 0, 1.12]:
                box('Wainscot raised panel', (panel_x + inset_x, front_y, .7), (.89, .1, .85), 'cut_oak')
                box('Wainscot inset face', (panel_x + inset_x, front_y + inward * .055, .7), (.72, .035, .65), 'oak')
        for post_x in [-9.7, -1.7, 1.5, 10.5]:
            if wall_y < 0 and post_x > 5:
                continue
            box('Bay timber pilaster', (post_x, wall_y + inward * .12, 1.87), (.22, .3, 3.7), 'oak')
            box('Pilaster carved capital', (post_x, wall_y + inward * .18, 3.58), (.4, .45, .2), 'edge')
            box('Projecting carved bracket', (post_x, wall_y + inward * .45, 3.63), (.3, 1, .18), 'cut_oak')
            rod('Bracket diagonal brace', (post_x, wall_y + inward * .13, 2.94), (post_x, wall_y + inward * .83, 3.58), .12, 'oak', 4)
    tapestry_y = 5.25
    box('Great hunting tapestry', (2.4, tapestry_y, 2.58), (4.5, .075, 1.97), 'wine', .008)
    rod('Tapestry hanging pole', (-.05, tapestry_y, 3.7), (4.85, tapestry_y, 3.7), .055, 'brass')
    for hem_x in [.24, 4.56]:
        box('Woven tapestry side border', (hem_x, tapestry_y - .06, 2.6), (.09, .035, 1.83), 'brass', .006)
    for hem_z in [1.68, 3.5]:
        box('Woven tapestry end border', (2.4, tapestry_y - .06, hem_z), (4.32, .035, .09), 'brass', .006)
    for fringe_index in range(22):
        box('Tapestry fringe', (.28 + fringe_index * .2, tapestry_y, 1.51), (.035, .025, .18), 'brass', .004)
    sphere('Stag woven head', (2.4, tapestry_y - .075, 2.4), (.23, .055, .35), 'cream', 2)
    for antler_side in [-1, 1]:
        nodes=[(2.4 + antler_side * .12, 2.67), (2.4 + antler_side * .38, 2.97), (2.4 + antler_side * .69, 3.1), (2.4 + antler_side * .92, 3.36)]
        for node_index in range(len(nodes)-1):
            first, second=nodes[node_index:node_index+2]
            rod('Woven antler beam', (first[0], tapestry_y - .08, first[1]), (second[0], tapestry_y - .08, second[1]), .033, 'cream', 6)
        rod('Woven antler tine', (2.4 + antler_side * .38, tapestry_y - .08, 2.97), (2.4 + antler_side * .34, tapestry_y - .08, 3.31), .025, 'cream', 6)
        rod('Woven antler fork', (2.4 + antler_side * .69, tapestry_y - .08, 3.1), (2.4 + antler_side * 1.1, tapestry_y - .08, 3.15), .025, 'cream', 6)
        for leaf_index in range(4):
            leaf_x = 2.4 + antler_side * (1.15 + leaf_index * .14)
            sphere('Heraldic oak leaf', (leaf_x, tapestry_y - .08, 2.6 - leaf_index * .18), (.17, .045, .075), 'brass', 1)
    for crest_x in [-8.3, 12]:
        box('Hunting trophy timber mount', (crest_x, 5.21, 2.61), (.88, .12, 1.25), 'oak', .07)
        sphere('Trophy skull', (crest_x, 5.05, 2.6), (.22, .16, .33), 'cream', 2)
        for antler_side in [-1, 1]:
            rod('Mounted antler main branch', (crest_x + antler_side * .12, 5.03, 2.8), (crest_x + antler_side * .7, 4.92, 3.34), .045, 'cream')
            rod('Mounted antler outer prong', (crest_x + antler_side * .7, 4.92, 3.34), (crest_x + antler_side * .75, 4.93, 3.65), .024, 'cream')
            rod('Mounted antler fork', (crest_x + antler_side * .39, 4.97, 3.07), (crest_x + antler_side * .38, 4.85, 3.48), .028, 'cream')
    save('feast_banquet_architecture')


def cook_station():
    table(width=3.2, depth=1.6, height=1.1)
    plank_top((0, 0, 0), 2.8, 1.35, .3)
    lathe('Large iron stockpot', (-.72, 0, 1.19), [(0, 0), (.39, 0), (.6, .22), (.66, .64), (.6, .76), (.55, .76), (.56, .63), (.5, .24), (0, .1)], 'iron', 20)
    lathe('Stew in stockpot', (-.72, 0, 1.82), [(.55, 0), (0, 0)], 'meat', 20)
    for handle_side in [-1, 1]:
        rod('Stockpot handle stem', (-.72 + handle_side * .58, 0, 1.69), (-.72 + handle_side * .79, 0, 1.69), .055, 'iron')
        rod('Stockpot handle grip', (-.72 + handle_side * .79, -.18, 1.69), (-.72 + handle_side * .79, .18, 1.69), .055, 'iron')
    for vegetable_index in range(4):
        sphere('Vegetables in stock', (-.98 + vegetable_index % 2 * .39, -.19 + vegetable_index // 2 * .35, 1.84), (.13, .13, .035), 'green' if vegetable_index % 2 else 'crust', 2)
    rod('Long stockpot ladle', (-1.03, -.2, 1.8), (-.53, .37, 2.05), .03, 'cut_oak')
    for tray_y in [-.38, .38]:
        plate((.82, tray_y, 1.2), .4, 'pewter')
    for linen_index in range(3):
        box('Folded serving cloth', (.87, .12, .42 + linen_index * .045), (.83, .77, .04), 'cream', .012)
    bowl((-.8, 0, .39), .43, 'copper')
    save('feast_cook_station')


oven()
preparation()
feast('feast_table_full', False)
feast('feast_table_spilled', True)
sideboard()
pantry()
wash()
dais()

serving_hatch()
cookware()
grain_station()

banquet_architecture()

cook_station()
