import bpy
import math
from mathutils import Vector
from pathlib import Path

OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "castle"
PALETTE = {
    'oak': ('51392b', 0.0), 'cut_oak': ('886748', 0.0), 'edge': ('b18c5d', 0.0),
    'stone': ('696568', 0.0), 'stone_light': ('81776e', 0.0), 'soot': ('302e32', 0.0),
    'iron': ('262b32', 0.7), 'pewter': ('9ba4a7', 0.75), 'brass': ('b89558', 0.75),
    'copper': ('a75c3b', 0.7), 'cream': ('d6c59d', 0.0), 'wine': ('672e42', 0.0),
    'green': ('657548', 0.0), 'crust': ('bc813e', 0.0), 'meat': ('8b4538', 0.0),
    'wax': ('e8ce99', 0.0), 'ember': ('e58336', 0.0), 'water': ('3e6268', 0.4),
}
MATERIALS = {}

def initialize_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
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


def candle(center, height=.5):
    lathe('Candle drip plate', center, [(0, 0), (.16, 0), (.18, .04), (.14, .065), (0, .04)], 'iron', 12)
    rod('Wax candle', (center[0], center[1], center[2] + .05), (center[0], center[1], center[2] + height), .065, 'wax')
    sphere('Small flame', (center[0], center[1], center[2] + height + .07), (.047, .047, .11), 'ember')


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


def save(name, collision_meshes=()):
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
    for proxy_name, vertices, faces in collision_meshes:
        mesh = bpy.data.meshes.new(proxy_name)
        mesh.from_pydata(vertices, [], faces)
        proxy = bpy.data.objects.new(proxy_name + '-colonly', mesh)
        bpy.context.collection.objects.link(proxy)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT / f'{name}.glb'), export_format='GLB', use_selection=True, export_materials='EXPORT', export_yup=True)
    print('FEAST_ASSET', name, sum(len(polygon.vertices) - 2 for polygon in obj.data.polygons))
    bpy.ops.object.delete(use_global=False)
