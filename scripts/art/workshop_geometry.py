import math
import bpy
from mathutils import Matrix, Vector

assembly = None
collisions = []

def create_scene(name):
    global assembly
    bpy.ops.wm.read_factory_settings(use_empty=True)
    assembly = bpy.data.collections.new(name)
    bpy.context.scene.collection.children.link(assembly)
    collisions.clear()

def append_source(path, predicate, offset, scale=1.0):
    with bpy.data.libraries.load(str(path), link=False) as (source, target):
        target.collections = source.collections
    for collection in target.collections:
        bpy.context.scene.collection.children.link(collection)
    bpy.context.view_layer.update()
    source_objects = sorted({obj for collection in target.collections for obj in collection.all_objects}, key=lambda obj: obj.name)
    selected = []
    for obj in source_objects:
        if obj.type in ('MESH', 'CURVE', 'FONT') and predicate(obj):
            assembly.objects.link(obj)
            selected.append(obj)
    transforms = {obj: Matrix.Translation(Vector(offset)) @ Matrix.Scale(scale, 4) @ obj.matrix_world for obj in selected}
    for obj in selected:
        obj.parent = None
        obj.matrix_world = transforms[obj]
        obj.animation_data_clear()
        obj.hide_render = False
        obj.hide_set(False)
    for obj in source_objects:
        if obj not in selected:
            bpy.data.objects.remove(obj, do_unlink=True)
    return selected


def material(name, color, metallic=0.0, roughness=0.7, emission=0.0):
    result = bpy.data.materials.new(name)
    result.diffuse_color = (*color, 1)
    result.use_nodes = True
    shader = result.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value = (*color, 1)
    shader.inputs['Metallic'].default_value = metallic
    shader.inputs['Roughness'].default_value = roughness
    if emission:
        shader.inputs['Emission Color'].default_value = (*color, 1)
        shader.inputs['Emission Strength'].default_value = emission
    return result


def collider(name, center, dimensions):
    collisions.append({'name': name, 'center': [center[0], center[2], -center[1]], 'size': [dimensions[0], dimensions[2], dimensions[1]]})


def finish(obj, name, surface, bevel=0):
    obj.name = name
    for collection in list(obj.users_collection):
        collection.objects.unlink(obj)
    assembly.objects.link(obj)
    obj.data.materials.append(surface)
    if bevel:
        modifier = obj.modifiers.new('Crafted edges', 'BEVEL')
        modifier.width = bevel
        modifier.segments = 2
        modifier = obj.modifiers.new('Weighted face normals', 'WEIGHTED_NORMAL')
        modifier.keep_sharp = True
    return obj


def box(name, center, dimensions, surface, bevel=0.025, solid=False):
    bpy.ops.mesh.primitive_cube_add(size=1, location=center)
    obj = bpy.context.object
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    finish(obj, name, surface, bevel)
    if solid:
        collider(name, center, dimensions)
    return obj


def cylinder(name, center, radius, depth, surface, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=center)
    return finish(bpy.context.object, name, surface, 0.012)


def rod(name, start, end, radius, surface):
    direction = Vector(end) - Vector(start)
    obj = cylinder(name, (Vector(start) + Vector(end)) / 2, radius, direction.length, surface, 12)
    obj.rotation_euler = direction.to_track_quat('Z', 'Y').to_euler()
    return obj


def tube(name, points, radius, surface, cyclic=False):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.resolution_u = 10
    curve.bevel_depth = radius
    curve.bevel_resolution = 2
    curve.use_fill_caps = True
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points) - 1)
    for point, coordinate in zip(spline.bezier_points, points):
        point.co = coordinate
        point.handle_left_type = 'AUTO'
        point.handle_right_type = 'AUTO'
    spline.use_cyclic_u = cyclic
    return finish(bpy.data.objects.new(name, curve), name, surface)


def ring(name, center, radius, thickness, surface, rotation=(0, 0, 0)):
    bpy.ops.mesh.primitive_torus_add(major_segments=48, minor_segments=8, location=center, major_radius=radius, minor_radius=thickness, rotation=rotation)
    return finish(bpy.context.object, name, surface)


def label(text, center, size, surface):
    curve = bpy.data.curves.new(text, 'FONT')
    curve.body = text
    curve.align_x = 'CENTER'
    curve.size = size
    curve.extrude = 0.003
    obj = bpy.data.objects.new(text, curve)
    obj.location = center
    obj.rotation_euler = (math.pi / 2, 0, 0)
    return finish(obj, text, surface)


def export_asset(output, stone):
    bpy.context.scene.frame_set(1)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in assembly.objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = next(iter(assembly.objects))
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.make_single_user(object=False, obdata=True, material=False, animation=False)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    buckets = {}
    for obj in list(assembly.objects):
        center = sum((vertex.co for vertex in obj.data.vertices), Vector()) / max(len(obj.data.vertices), 1)
        zone = int(center.x // 9)
        key = (zone, tuple(material.name if material else '' for material in obj.data.materials))
        buckets.setdefault(key, []).append(obj)
    for index, objects in enumerate(buckets.values()):
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()
        bpy.context.object.name = f'Crafted assembly {index:03}'

    for index, proxy in enumerate(collisions):
        center = (proxy['center'][0], -proxy['center'][2], proxy['center'][1])
        dimensions = (proxy['size'][0], proxy['size'][2], proxy['size'][1])
        if 'radius' in proxy:
            obj = cylinder(f'WorkshopProxy{index:03}-colonly', center, proxy['radius'], dimensions[2], stone, 8)
        else:
            obj = box(f'WorkshopProxy{index:03}-colonly', center, dimensions, stone, 0)
        bpy.context.view_layer.objects.active = obj
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)

    output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    for obj in assembly.objects:
        obj.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(output), export_format='GLB', use_selection=True, export_apply=True, export_animations=False, export_cameras=False, export_lights=False, export_yup=True)

    print('WORKSHOP_EXPORT', len(assembly.objects), 'meshes', len(collisions), 'collision proxies')


def lathe(name, center, profile, surface, segments=24):
    vertices = []
    for radius, height in profile:
        vertices.extend((radius * math.cos(index * math.tau / segments), radius * math.sin(index * math.tau / segments), height) for index in range(segments))
    faces = []
    for level in range(len(profile) - 1):
        for index in range(segments):
            following = (index + 1) % segments
            faces.append((level * segments + index, level * segments + following, (level + 1) * segments + following, (level + 1) * segments + index))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple((len(profile) - 1) * segments + index for index in range(segments)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = center
    for polygon in mesh.polygons:
        polygon.use_smooth = len(polygon.vertices) == 4
    return finish(obj, name, surface)


def profile(name, center, outline, depth, surface, bevel=0.015):
    vertices = [(horizontal, side * depth / 2, height) for side in (-1, 1) for horizontal, height in outline]
    count = len(outline)
    faces = [tuple(reversed(range(count))), tuple(range(count, count * 2))]
    faces.extend((index, (index + 1) % count, (index + 1) % count + count, index + count) for index in range(count))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.location = center
    return finish(obj, name, surface, bevel)
