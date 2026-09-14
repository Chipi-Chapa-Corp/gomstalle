import bpy
import math
import random
from pathlib import Path
from mathutils import Vector


OUTPUT = Path(__file__).resolve().parents[2] / 'assets' / 'castle' / 'midnight_library'
GLB_PATH = OUTPUT / 'midnight_library.glb'
BLEND_PATH = OUTPUT / 'midnight_library.blend'
WINDOW_TEXTURE_PATH = OUTPUT / 'moon_window.png'
RANDOM = random.Random(1847)

PALETTE = {
    'Stone': '4a4e5a',
    'StoneLight': '747784',
    'StoneDark': '292d3b',
    'Mahogany': '321c1d',
    'MahoganyEdge': '6b3f2f',
    'LeatherCrimson': '6f263a',
    'LeatherTeal': '1f5355',
    'LeatherNavy': '293b5a',
    'LeatherOchre': 'a16b35',
    'Parchment': 'd5c098',
    'ParchmentLight': 'ead9b4',
    'Brass': 'bb8b46',
    'BrassDark': '604428',
    'Iron': '262b31',
    'RunnerCrimson': '5c2637',
    'RunnerTeal': '1c4d50',
    'WoodFloor': '302322',
    'WoodWarm': '64412f',
    'Wax': 'bfa575',
    'Candle': 'e4c98e',
    'Flame': 'ff8d35',
    'MoonGlass': '274a78',
    'GlassLead': '9eb5c2',
    'Marble': '8f8176',
    'Shadow': '171b27',
}

PROFILES = {
    'Stone': ('stone', .026),
    'StoneLight': ('stone', .026),
    'StoneDark': ('stone', .026),
    'Mahogany': ('wood', .024),
    'MahoganyEdge': ('wood_trim', 0),
    'LeatherCrimson': ('leather', 0),
    'LeatherTeal': ('leather', 0),
    'LeatherNavy': ('leather', 0),
    'LeatherOchre': ('leather', 0),
    'Parchment': ('paper', 0),
    'ParchmentLight': ('paper', 0),
    'Brass': ('metal', 0),
    'BrassDark': ('metal', 0),
    'Iron': ('metal', 0),
    'RunnerCrimson': ('fabric', .006),
    'RunnerTeal': ('fabric', .006),
    'WoodFloor': ('wood_floor', .020),
    'WoodWarm': ('wood', .024),
    'Wax': ('wax', .006),
    'Candle': ('wax', .006),
    'Flame': ('flame', 0),
    'MoonGlass': ('glass', 0),
    'GlassLead': ('metal', 0),
    'Marble': ('stone_trim', .018),
    'Shadow': ('shadow', 0),
}

BATCHES = {}
COLLISION_PROXIES = []
CANDLE_FIXTURES = []
BOOK_SPINES = 0
WINDOW_ART_OBJECT = None


def srgb(channel):
    value = int(channel, 16) / 255
    return value / 12.92 if value <= .04045 else ((value + .055) / 1.055) ** 2.4


def to_blender(vertex):
    return (vertex[0], -vertex[2], vertex[1])


def to_design(vertex):
    return (vertex[0], vertex[2], -vertex[1])


def setup_materials():
    materials = {}
    for name, color in PALETTE.items():
        material = bpy.data.materials.new(name)
        rgba = tuple(srgb(color[index:index + 2]) for index in (0, 2, 4)) + (1,)
        material.diffuse_color = rgba
        material.use_nodes = True
        shader = material.node_tree.nodes.get('Principled BSDF')
        shader.inputs['Base Color'].default_value = rgba
        shader.inputs['Roughness'].default_value = .27 if name in ('Brass', 'BrassDark', 'Iron') else .78
        shader.inputs['Metallic'].default_value = .82 if name in ('Brass', 'BrassDark', 'Iron', 'GlassLead') else 0
        if name == 'MoonGlass':
            shader.inputs['Base Color'].default_value = (srgb('27'), srgb('4a'), srgb('86'), 1)
            shader.inputs['Roughness'].default_value = .22
            shader.inputs['Emission Color'].default_value = (srgb('1c'), srgb('4b'), srgb('92'), 1)
            shader.inputs['Emission Strength'].default_value = 1.9
        if name == 'Flame':
            shader.inputs['Base Color'].default_value = (srgb('ff'), srgb('8d'), srgb('35'), 1)
            shader.inputs['Emission Color'].default_value = (1.0, srgb('68'), srgb('17'), 1)
            shader.inputs['Emission Strength'].default_value = 8.0
        if name == 'GlassLead':
            shader.inputs['Roughness'].default_value = .36
        materials[name] = material
    window_material = bpy.data.materials.new('WindowArt')
    window_material.diffuse_color = (1, 1, 1, 1)
    window_material.use_nodes = True
    window_nodes = window_material.node_tree.nodes
    window_shader = window_nodes.get('Principled BSDF')
    window_texture = window_nodes.new('ShaderNodeTexImage')
    window_texture.image = bpy.data.images.load(str(WINDOW_TEXTURE_PATH), check_existing=True)
    window_texture.image.colorspace_settings.name = 'sRGB'
    window_texture.image.pack()
    window_texture.interpolation = 'Linear'
    window_texture.extension = 'CLIP'
    window_material.node_tree.links.new(window_texture.outputs['Color'], window_shader.inputs['Base Color'])
    window_material.node_tree.links.new(window_texture.outputs['Color'], window_shader.inputs['Emission Color'])
    window_shader.inputs['Roughness'].default_value = .38
    window_shader.inputs['Metallic'].default_value = .08
    window_shader.inputs['Emission Strength'].default_value = 1.25
    materials['WindowArt'] = window_material
    return materials


MATERIALS = setup_materials()


def batch_key(material_name):
    profile, bevel = PROFILES[material_name]
    return material_name, profile, bevel


def add_geometry(material_name, vertices, faces, smooth=False):
    key = batch_key(material_name)
    batch = BATCHES.setdefault(key, {'vertices': [], 'faces': [], 'smooth': []})
    vertex_offset = len(batch['vertices'])
    batch['vertices'].extend(to_blender(vertex) for vertex in vertices)
    batch['faces'].extend(tuple(index + vertex_offset for index in face) for face in faces)
    batch['smooth'].extend([smooth] * len(faces))


def add_box(center, size, material_name, yaw=0, smooth=False):
    half_x, half_y, half_z = size[0] / 2, size[1] / 2, size[2] / 2
    vertices = []
    for horizontal, height, depth in ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1), (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)):
        local_x, local_z = horizontal * half_x, depth * half_z
        vertices.append((
            center[0] + local_x * math.cos(yaw) - local_z * math.sin(yaw),
            center[1] + height * half_y,
            center[2] + local_x * math.sin(yaw) + local_z * math.cos(yaw),
        ))
    add_geometry(material_name, vertices, [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)], smooth)


def add_cylinder(center, radius, height, material_name, segments=16, smooth=False):
    vertices = []
    for y in (-height / 2, height / 2):
        for index in range(segments):
            angle = index * math.tau / segments
            vertices.append((center[0] + radius * math.cos(angle), center[1] + y, center[2] + radius * math.sin(angle)))
    faces = [tuple(reversed(range(segments))), tuple(range(segments, segments * 2))]
    faces.extend((index, (index + 1) % segments, (index + 1) % segments + segments, index + segments) for index in range(segments))
    add_geometry(material_name, vertices, faces, smooth)


def add_rod(start, end, radius, material_name, segments=10, smooth=False):
    direction = Vector(end) - Vector(start)
    basis = direction.to_track_quat('Z', 'Y').to_matrix()
    vertices = []
    for endpoint in (Vector(start), Vector(end)):
        vertices.extend(tuple(endpoint + basis @ Vector((radius * math.cos(index * math.tau / segments), radius * math.sin(index * math.tau / segments), 0))) for index in range(segments))
    faces = [tuple(reversed(range(segments))), tuple(range(segments, segments * 2))]
    faces.extend((index, (index + 1) % segments, (index + 1) % segments + segments, index + segments) for index in range(segments))
    add_geometry(material_name, vertices, faces, smooth)


def add_torus(center, major_radius, minor_radius, material_name, axis='Y', segments=32, sides=8, smooth=True):
    vertices = []
    center_vector = Vector(center)
    for segment in range(segments):
        ring_angle = segment * math.tau / segments
        ring_cosine, ring_sine = math.cos(ring_angle), math.sin(ring_angle)
        if axis == 'Y':
            radial = Vector((ring_cosine, 0, ring_sine))
            axial = Vector((0, 1, 0))
        elif axis == 'Z':
            radial = Vector((ring_cosine, ring_sine, 0))
            axial = Vector((0, 0, 1))
        else:
            radial = Vector((0, ring_cosine, ring_sine))
            axial = Vector((1, 0, 0))
        for side in range(sides):
            tube_angle = side * math.tau / sides
            point = center_vector + radial * (major_radius + minor_radius * math.cos(tube_angle)) + axial * (minor_radius * math.sin(tube_angle))
            vertices.append(tuple(point))
    faces = []
    for segment in range(segments):
        next_segment = (segment + 1) % segments
        for side in range(sides):
            next_side = (side + 1) % sides
            faces.append((segment * sides + side, next_segment * sides + side, next_segment * sides + next_side, segment * sides + next_side))
    add_geometry(material_name, vertices, faces, smooth)


def add_sphere(center, radius, material_name, segments=20, rings=12):
    vertices = []
    for ring in range(rings + 1):
        polar = math.pi * ring / rings
        for segment in range(segments):
            azimuth = math.tau * segment / segments
            vertices.append((
                center[0] + radius * math.sin(polar) * math.cos(azimuth),
                center[1] + radius * math.cos(polar),
                center[2] + radius * math.sin(polar) * math.sin(azimuth),
            ))
    faces = []
    for ring in range(rings):
        for segment in range(segments):
            next_segment = (segment + 1) % segments
            faces.append((ring * segments + segment, ring * segments + next_segment, (ring + 1) * segments + next_segment, (ring + 1) * segments + segment))
    add_geometry(material_name, vertices, faces, True)


def add_disc_wedge(center, radius, start_angle, end_angle, depth, material_name, segments=5):
    points = [Vector((center[0], center[1], center[2] - depth / 2)), Vector((center[0], center[1], center[2] + depth / 2))]
    for index in range(segments + 1):
        angle = start_angle + (end_angle - start_angle) * index / segments
        point = Vector((center[0] + radius * math.cos(angle), center[1] + radius * math.sin(angle), center[2] - depth / 2))
        points.append(tuple(point))
        points.append(tuple(point + Vector((0, 0, depth))))
    vertices = [tuple(point) if isinstance(point, Vector) else point for point in points]
    faces = []
    for index in range(segments):
        front_left = 2 + index * 2
        front_right = front_left + 2
        back_left = front_left + 1
        back_right = front_right + 1
        faces.extend(((0, front_left, front_right), (1, back_right, back_left), (front_left, back_left, back_right, front_right)))
    add_geometry(material_name, vertices, faces, False)


def add_window_art(center, radius, depth):
    global WINDOW_ART_OBJECT
    design_vertices = [(center[0], center[1], center[2] + depth / 2)]
    for index in range(96):
        angle = index * math.tau / 96
        design_vertices.append((center[0] + radius * math.cos(angle), center[1] + radius * math.sin(angle), center[2] + depth / 2))
    faces = [(0, index + 1, (index + 1) % 96 + 1) for index in range(96)]
    mesh = bpy.data.meshes.new('MidnightLibrary_WindowArt')
    mesh.from_pydata([to_blender(vertex) for vertex in design_vertices], [], faces)
    mesh.update()
    uv_layer = mesh.uv_layers.new(name='UVMap')
    for polygon in mesh.polygons:
        for loop_index in polygon.loop_indices:
            vertex_index = mesh.loops[loop_index].vertex_index
            vertex = design_vertices[vertex_index]
            uv_layer.data[loop_index].uv = (.5 + (vertex[0] - center[0]) / (radius * 2), .5 + (vertex[1] - center[1]) / (radius * 2))
    WINDOW_ART_OBJECT = bpy.data.objects.new('MidnightLibrary_WindowArt', mesh)
    bpy.context.collection.objects.link(WINDOW_ART_OBJECT)
    mesh.materials.append(MATERIALS['WindowArt'])


def add_arch_tube(horizontal, depth, base_height, width, arch_height, radius, material_name):
    previous = None
    for index in range(19):
        angle = math.pi - math.pi * index / 18
        point = (horizontal, base_height + arch_height * math.sin(angle), depth + width * .5 * math.cos(angle))
        if previous is not None:
            add_rod(previous, point, radius, material_name, 8)
        previous = point


def add_collision(name, center, size, yaw=0):
    vertices = []
    half_x, half_y, half_z = size[0] / 2, size[1] / 2, size[2] / 2
    for horizontal, height, depth in ((-1, -1, -1), (1, -1, -1), (1, -1, 1), (-1, -1, 1), (-1, 1, -1), (1, 1, -1), (1, 1, 1), (-1, 1, 1)):
        local_x, local_z = horizontal * half_x, depth * half_z
        vertices.append((
            center[0] + local_x * math.cos(yaw) - local_z * math.sin(yaw),
            center[1] + height * half_y,
            center[2] + local_x * math.sin(yaw) + local_z * math.cos(yaw),
        ))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([to_blender(vertex) for vertex in vertices], [], [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])
    mesh.update()
    object_data = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(object_data)
    COLLISION_PROXIES.append(object_data)


def add_ramp_collision(name, horizontal, low_depth, high_depth, low_height, high_height, width):
    vertices = [
        (horizontal - width / 2, 0, low_depth),
        (horizontal + width / 2, 0, low_depth),
        (horizontal + width / 2, 0, high_depth),
        (horizontal - width / 2, 0, high_depth),
        (horizontal - width / 2, low_height, low_depth),
        (horizontal + width / 2, low_height, low_depth),
        (horizontal + width / 2, high_height, high_depth),
        (horizontal - width / 2, high_height, high_depth),
    ]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([to_blender(vertex) for vertex in vertices], [], [(3, 2, 1, 0), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)])
    mesh.update()
    object_data = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(object_data)
    COLLISION_PROXIES.append(object_data)


def add_floor():
    add_box((0, -.16, 0), (16, .32, 22), 'StoneDark')
    add_box((0, -.025, 0), (5.2, .055, 20.2), 'WoodFloor', yaw=0)
    for index in range(39):
        depth = -9.8 + index * .51
        add_box((0, .015, depth), (5.08, .035, .46), 'WoodWarm', yaw=RANDOM.uniform(-.008, .008))
    for depth in range(-10, 11, 2):
        for side in (-1, 1):
            add_box((side * 3.55, .02, depth), (1.72, .045, 1.82), 'Stone', yaw=RANDOM.uniform(-.025, .025))
            add_box((side * 4.45, .045, depth), (.045, .04, 1.68), 'BrassDark')
    add_box((0, .055, -5.2), (3.55, .045, 8.0), 'RunnerCrimson')
    add_box((0, .082, -5.2), (2.75, .025, 7.72), 'RunnerTeal')
    for depth in (-9.0, -7.0, -5.0, -3.0, -1.0, 1.0, 3.0, 5.0, 7.0, 9.0):
        add_torus((0, .112, depth), .78, .025, 'Brass', axis='Y', segments=32, sides=6)
        add_rod((-0.78, .112, depth), (.78, .112, depth), .018, 'Brass', 6)
        add_rod((0, .112, depth - .78), (0, .112, depth + .78), .018, 'Brass', 6)
    add_collision('MidnightLibraryGround-colonly', (0, -.125, 0), (16, .25, 22))


def add_room_shell():
    add_box((0, 5.3, -11.15), (16, 10.6, .62), 'Stone')
    add_box((-8.15, 5.3, 0), (.62, 10.6, 22), 'Stone')
    add_box((8.15, 5.3, 0), (.62, 10.6, 22), 'Stone')
    add_box((0, 10.38, -5.3), (16.2, .38, 11.1), 'StoneDark')
    add_box((0, 9.96, -5.3), (15.5, .16, 10.8), 'MahoganyEdge')
    add_box((0, .28, -10.76), (15.5, .38, .24), 'Marble')
    add_box((-7.7, .28, 0), (.24, .38, 21.3), 'Marble')
    add_box((7.7, .28, 0), (.24, .38, 21.3), 'Marble')
    add_collision('MidnightLibraryBackWall-colonly', (0, 5.3, -11.22), (16, 10.6, .62))
    add_collision('MidnightLibraryWestWall-colonly', (-8.15, 5.3, 0), (.62, 10.6, 22))
    add_collision('MidnightLibraryEastWall-colonly', (8.15, 5.3, 0), (.62, 10.6, 22))
    for height in (1.25, 3.15, 5.05, 6.95, 8.85):
        add_box((0, height, -10.78), (14.7, .14, .22), 'StoneLight')
    for horizontal in (-7.3, -4.1, -.9, 2.3, 5.5, 7.3):
        add_box((horizontal, 5.0, -10.77), (.18, 9.6, .18), 'StoneLight')
    for horizontal in (-7.05, 7.05):
        for depth in (-10.25, 10.25):
            add_cylinder((horizontal, 4.85, depth), .34, 9.65, 'StoneLight', 20, True)
            for flute in range(10):
                angle = flute * math.tau / 10
                add_rod((horizontal + .34 * math.cos(angle), .62, depth + .34 * math.sin(angle)), (horizontal + .34 * math.cos(angle), 9.05, depth + .34 * math.sin(angle)), .028, 'StoneDark', 6)
            add_torus((horizontal, .62, depth), .42, .08, 'Marble', axis='Y', segments=24, sides=6)
            add_torus((horizontal, 9.05, depth), .43, .08, 'Marble', axis='Y', segments=24, sides=6)


def add_rose_window():
    center = (0, 6.3, -10.78)
    add_torus(center, 2.72, .16, 'BrassDark', axis='Z', segments=64, sides=10)
    add_torus((center[0], center[1], center[2] - .035), 2.62, .07, 'Brass', axis='Z', segments=64, sides=8)
    add_torus((center[0], center[1], center[2] - .07), 1.32, .06, 'GlassLead', axis='Z', segments=48, sides=7)
    add_torus((center[0], center[1], center[2] + .015), 2.91, .10, 'MahoganyEdge', axis='Z', segments=64, sides=8)
    add_torus((center[0], center[1], center[2] + .035), 3.00, .055, 'BrassDark', axis='Z', segments=64, sides=8)
    add_torus((center[0], center[1], center[2] + .045), 3.09, .085, 'Mahogany', axis='Z', segments=64, sides=8)
    for index in range(12):
        angle = index * math.tau / 12
        ornament_center = (center[0] + 2.83 * math.cos(angle), center[1] + 2.83 * math.sin(angle), center[2] - .1)
        add_sphere(ornament_center, .085, 'Brass', 10, 6)
        tangent = Vector((-math.sin(angle), math.cos(angle), 0))
        for petal_side in (-1, 1):
            petal_center = Vector(ornament_center) + tangent * (.105 * petal_side) + Vector((0, 0, -.01))
            add_sphere(tuple(petal_center), .045, 'Brass', 8, 5)
    add_window_art(center, 2.60, .28)
    add_box((0, 3.16, -10.57), (6.15, .18, .30), 'MahoganyEdge')
    add_box((0, 9.44, -10.57), (6.15, .18, .30), 'MahoganyEdge')


def book_spine(side, horizontal, height, depth, width, leather, shelf_height, label=False, yaw=0):
    global BOOK_SPINES
    BOOK_SPINES += 1
    book_center = (side * 7.42 + math.sin(yaw) * .02, shelf_height + height / 2 + .06, depth)
    add_box(book_center, (.50, height, width), 'Parchment', yaw=yaw)
    spine_center = (side * 7.125 + math.sin(yaw) * .01, shelf_height + height / 2 + .06, depth)
    add_box(spine_center, (.065, height + .012, width + .012), leather, yaw=yaw)
    for relative_height in (-.37, .37):
        add_box((side * 7.082, spine_center[1] + height * relative_height, depth), (.026, .022, width + .018), 'Brass', yaw=yaw)
    if label:
        add_box((side * 7.066, spine_center[1] + RANDOM.uniform(-.04, .08), depth), (.018, height * .19, width * .57), 'ParchmentLight', yaw=yaw)


def add_side_shelves():
    bay_centers = (-8.55, -5.7, -2.85, 0, 2.85, 5.7, 8.55)
    bay_width = 2.64
    for side in (-1, 1):
        add_box((side * 7.46, 3.65, 0), (.78, 7.3, 20.15), 'Mahogany')
        for bay_index, depth in enumerate(bay_centers):
            add_box((side * 7.03, 3.78, depth), (.18, 7.7, .16), 'MahoganyEdge')
            for base_height in (.42, 4.25):
                add_box((side * 7.4, base_height, depth), (.78, .18, bay_width), 'MahoganyEdge')
                for shelf_index in range(1, 7):
                    shelf_height = base_height + shelf_index * .43
                    add_box((side * 7.4, shelf_height, depth), (.78, .12, bay_width), 'MahoganyEdge')
                    cursor = depth - bay_width / 2 + .10
                    while cursor < depth + bay_width / 2 - .08:
                        width = RANDOM.uniform(.11, .20)
                        if cursor + width > depth + bay_width / 2 - .06:
                            width = depth + bay_width / 2 - .06 - cursor
                        if width > .08:
                            height = RANDOM.uniform(.32, .42) if base_height < 1 else RANDOM.uniform(.32, .42)
                            leather = RANDOM.choice(('LeatherCrimson', 'LeatherTeal', 'LeatherNavy', 'LeatherOchre'))
                            book_spine(side, depth, height, cursor, width, leather, shelf_height, RANDOM.random() < .21, RANDOM.uniform(-.018, .018))
                        cursor += max(width, .095) + RANDOM.uniform(.018, .044)
            add_box((side * 7.41, 7.62, depth), (.84, .16, bay_width + .16), 'MahoganyEdge')
            add_arch_tube(side * 7.08, depth, 7.70, bay_width + .10, .49, .09, 'MahoganyEdge')
            add_box((side * 7.08, 4.02, depth - bay_width / 2 - .02), (.28, 7.38, .12), 'MahoganyEdge')
            add_box((side * 7.08, 4.02, depth + bay_width / 2 + .02), (.28, 7.38, .12), 'MahoganyEdge')
        for depth in (-10.04, -7.08, -4.22, -1.36, 1.5, 4.36, 7.22, 10.08):
            add_box((side * 7.00, 4.02, depth), (.30, 7.55, .12), 'MahoganyEdge')
    add_collision('MidnightLibraryWestShelves-colonly', (-7.42, 3.9, 0), (1.0, 7.9, 20.4))
    add_collision('MidnightLibraryEastShelves-colonly', (7.42, 3.9, 0), (1.0, 7.9, 20.4))


def add_balconies_and_stairs():
    for side in (-1, 1):
        add_box((side * 6.42, 3.72, 0), (2.95, .30, 20.6), 'WoodFloor')
        for depth in [index * .42 - 10.0 for index in range(49)]:
            add_box((side * 6.42, 3.89, depth), (2.82, .035, .36), 'WoodWarm', yaw=RANDOM.uniform(-.008, .008))
        rail_x = side * 5.02
        for depth in [index * 1.22 - 9.2 for index in range(16)]:
            add_box((rail_x, 4.35, depth), (.16, 1.26, .16), 'MahoganyEdge')
            add_cylinder((rail_x, 4.82, depth), .035, .88, 'Brass', 8, True)
        add_box((rail_x, 4.98, 0), (.14, .14, 19.1), 'MahoganyEdge')
        add_box((rail_x, 4.30, 0), (.12, .11, 19.2), 'Brass', yaw=0)
        add_collision(('MidnightLibraryWestBalcony' if side < 0 else 'MidnightLibraryEastBalcony') + '-colonly', (side * 6.42, 3.695, 0), (2.95, .35, 20.6))
    add_box((0, 3.72, -10.05), (10.3, .30, 1.2), 'WoodFloor')
    for horizontal in [index * .48 - 4.8 for index in range(21)]:
        add_box((horizontal, 3.89, -10.05), (.42, .035, 1.08), 'WoodWarm', yaw=RANDOM.uniform(-.008, .008))
    add_box((0, 4.35, -9.48), (10.1, .12, .16), 'MahoganyEdge')
    add_box((0, 4.98, -9.48), (10.1, .14, .14), 'Brass')
    for horizontal in (-4.8, -3.2, -1.6, 0, 1.6, 3.2, 4.8):
        add_cylinder((horizontal, 4.35, -9.48), .055, 1.2, 'Brass', 8, True)
    add_collision('MidnightLibraryBackBalcony-colonly', (0, 3.695, -10.05), (10.3, .35, 1.2))
    stair_x = 4.04
    for index in range(11):
        height = .34 + index * .31
        depth = 7.85 - index * .43
        add_box((stair_x, height, depth), (1.72, .18, .58), 'MahoganyEdge', yaw=0)
        add_box((stair_x, height - .12, depth + .20), (1.58, .25, .12), 'Mahogany')
    add_box((stair_x, 3.70, 3.15), (1.72, .18, .62), 'MahoganyEdge')
    add_box((stair_x, 3.58, 3.32), (1.58, .25, .12), 'Mahogany')
    for side in (-1, 1):
        add_rod((stair_x + side * .75, .18, 8.18), (stair_x + side * .75, 3.9, 3.8), .045, 'MahoganyEdge', 8)
        add_rod((stair_x + side * .75, .95, 8.18), (stair_x + side * .75, 4.52, 3.8), .055, 'Brass', 8)
    add_ramp_collision('MidnightLibraryStair-colonly', stair_x, 8.14, 2.84, .43, 3.87, 1.9)


def add_serving_opening():
    wall_depth = 0
    opening_center = -4.2
    opening_width = 1.9
    opening_height = 1.05
    left_wing_center = opening_center - opening_width / 2 - .72
    right_wing_center = opening_center + opening_width / 2 + .72
    add_box((left_wing_center, 1.22, wall_depth), (1.44, 2.44, .25), 'Mahogany', yaw=0)
    add_box((right_wing_center, 1.22, wall_depth), (1.44, 2.44, .25), 'Mahogany', yaw=0)
    add_box((opening_center, opening_height + .61, wall_depth), (opening_width, 1.22, .25), 'MahoganyEdge')
    add_box((opening_center, opening_height + .03, wall_depth + .15), (opening_width + .22, .12, .34), 'Marble')
    add_box((opening_center, 2.42, wall_depth), (4.9, .18, .34), 'MahoganyEdge')
    for horizontal in (left_wing_center, right_wing_center):
        add_box((horizontal, 1.20, wall_depth + .15), (1.26, 1.9, .08), 'MahoganyEdge')
        for row in range(2):
            for book_index in range(5):
                book_center = horizontal - .48 + book_index * .24
                add_box((book_center, 1.62 + row * .52, wall_depth + .17), (.18, .42, .15), RANDOM.choice(('LeatherCrimson', 'LeatherTeal', 'LeatherNavy', 'LeatherOchre')), yaw=RANDOM.uniform(-.035, .035))
    for index in range(7):
        horizontal = opening_center - .80 + index * .27
        add_box((horizontal, 2.59, wall_depth + .01), (.22, .24, .28), ('LeatherCrimson', 'LeatherOchre', 'LeatherTeal')[index % 3], yaw=RANDOM.uniform(-.025, .025))
    for horizontal in (left_wing_center - .63, right_wing_center + .63):
        add_box((horizontal, 1.28, wall_depth - .17), (.09, 2.28, .09), 'BrassDark')
    add_collision('MidnightLibraryServingLeft-colonly', (left_wing_center, 1.22, wall_depth), (1.44, 2.44, .25))
    add_collision('MidnightLibraryServingRight-colonly', (right_wing_center, 1.22, wall_depth), (1.44, 2.44, .25))
    add_collision('MidnightLibraryServingHeader-colonly', (opening_center, opening_height + .61, wall_depth), (opening_width, 1.22, .25))


def add_far_wall_panels():
    for horizontal in (-6.2, -4.2, 4.2, 6.2):
        add_box((horizontal, 5.55, -10.72), (1.48, 7.4, .18), 'StoneLight')
        add_box((horizontal, 5.55, -10.55), (1.10, 6.9, .08), 'StoneDark')
    for horizontal in (-3.25, 3.25):
        add_box((horizontal, 5.4, -10.68), (.24, 8.9, .25), 'Marble')
        add_torus((horizontal, 8.9, -10.53), .34, .055, 'BrassDark', axis='Z', segments=24, sides=6)


def add_desk(horizontal, depth, side):
    width, length = 2.05, 2.75
    add_box((horizontal, 1.05, depth), (width, .18, length), 'MahoganyEdge', yaw=side * .018)
    add_box((horizontal, .92, depth), (1.85, .12, length - .16), 'WoodWarm', yaw=side * .018)
    for end in (-1, 1):
        end_depth = depth + end * (length / 2 - .26)
        add_box((horizontal, .50, end_depth), (1.35, .92, .16), 'Mahogany', yaw=side * .018)
        add_box((horizontal, .13, end_depth), (1.68, .18, .34), 'MahoganyEdge', yaw=side * .018)
        add_torus((horizontal, .23, end_depth), .16, .035, 'BrassDark', axis='Y', segments=16, sides=6)
    add_box((horizontal, .42, depth), (.18, .15, length - .70), 'Mahogany')
    for drawer in range(2):
        drawer_depth = depth - .31 + drawer * .62
        add_box((horizontal + side * 1.045, .72, drawer_depth), (.045, .28, .48), 'MahoganyEdge', yaw=side * .018)
        add_box((horizontal + side * 1.074, .72, drawer_depth), (.022, .075, .16), 'Brass', yaw=side * .018)
    add_open_book((horizontal - .24 * side, depth - .27, 1.18), .72, side * .045)
    add_open_book((horizontal + .30 * side, depth + .40, 1.19), .56, -side * .025)
    add_cylinder((horizontal + .63 * side, 1.23, depth + .04), .11, .15, 'Iron', 16)
    add_cylinder((horizontal + .63 * side, 1.33, depth + .04), .075, .08, 'Shadow', 14)
    add_rod((horizontal + .57 * side, 1.35, depth + .04), (horizontal + .76 * side, 1.85, depth + .18), .018, 'MahoganyEdge', 7)
    for feather in range(5):
        start = (horizontal + (.72 + feather * .026) * side, 1.57 + feather * .035, depth + .15)
        end = (horizontal + (.91 + feather * .026) * side, 1.83 + feather * .035, depth + .18)
        add_rod(start, end, .008, 'ParchmentLight', 5)
    for page in range(3):
        add_box((horizontal + .58 * side, 1.22 + page * .008, depth - .54), (.54, .012, .38), 'ParchmentLight', yaw=side * (.12 + page * .03))
    add_box((horizontal - .66 * side, 1.23, depth + .58), (.38, .14, .28), 'LeatherCrimson', yaw=side * .12)
    add_box((horizontal - .66 * side, 1.32, depth + .58), (.31, .035, .22), 'Parchment', yaw=side * .12)
    for stack in range(3):
        add_box((horizontal + .59 * side, 1.22 + stack * .11, depth + .58), (.42, .09, .55), ('LeatherNavy', 'LeatherOchre', 'LeatherTeal')[stack], yaw=side * .08)
    add_collision(('MidnightLibraryWestDesk' if side < 0 else 'MidnightLibraryEastDesk') + '-colonly', (horizontal, .60, depth), (2.15, 1.35, 2.9))


def add_open_book(center, scale, yaw):
    horizontal, depth, height = center
    for side in (-1, 1):
        add_box((horizontal + side * .26 * scale, height, depth), (.52 * scale, .045, .72 * scale), 'LeatherCrimson', yaw=yaw)
        add_box((horizontal + side * .255 * scale, height + .034, depth), (.44 * scale, .025, .63 * scale), 'ParchmentLight', yaw=yaw)
        for line in range(6):
            line_depth = depth - .23 * scale + line * .075 * scale
            add_box((horizontal + side * .26 * scale, height + .053, line_depth), (.30 * scale, .006, .012), 'MahoganyEdge', yaw=yaw)
    add_box((horizontal, height + .038, depth + .04), (.035, .01, .62 * scale), 'RunnerCrimson', yaw=yaw)


def add_floor_books():
    placements = [
        (-3.58, .18, -3.62, -.24, .62, .23, 'LeatherCrimson'),
        (-3.18, .16, -4.06, .18, .55, .19, 'LeatherOchre'),
        (3.58, .17, -3.48, .31, .60, .24, 'LeatherTeal'),
        (3.20, .14, -3.98, -.12, .48, .18, 'LeatherNavy'),
        (4.18, .18, -4.25, .42, .64, .22, 'LeatherCrimson'),
        (-4.15, .16, -4.38, -.38, .57, .22, 'LeatherNavy'),
        (2.85, .20, 1.28, .17, .50, .19, 'LeatherOchre'),
        (-2.86, .18, 1.56, -.28, .55, .21, 'LeatherTeal'),
    ]
    for horizontal, height, depth, yaw, book_height, width, leather in placements:
        add_box((horizontal, height, depth), (.52, .12, .74), 'Parchment', yaw=yaw)
        add_box((horizontal, height + .075, depth), (.56, .06, .78), leather, yaw=yaw)
        add_box((horizontal, height + .12, depth), (.49, .025, .71), 'ParchmentLight', yaw=yaw)
        add_box((horizontal, height + .145, depth + .31), (.025, .014, .31), 'Brass', yaw=yaw)


def add_orrery():
    horizontal, depth = 0, -5.15
    add_box((horizontal, .18, depth), (1.84, .36, 1.84), 'Mahogany', yaw=.05)
    add_box((horizontal, .43, depth), (1.48, .16, 1.48), 'Marble', yaw=.05)
    add_box((horizontal, .72, depth), (1.15, .42, 1.15), 'MahoganyEdge', yaw=.05)
    add_torus((horizontal, 1.10, depth), .54, .07, 'Brass', axis='Y', segments=32, sides=8)
    add_cylinder((horizontal, 1.55, depth), .12, 1.22, 'BrassDark', 16, True)
    add_sphere((horizontal, 2.0, depth), .72, 'MoonGlass', 28, 16)
    add_torus((horizontal, 2.0, depth), .90, .045, 'Brass', axis='X', segments=40, sides=7)
    add_torus((horizontal, 2.0, depth), .98, .05, 'BrassDark', axis='Y', segments=40, sides=7)
    add_torus((horizontal, 2.0, depth), .86, .035, 'Brass', axis='Z', segments=40, sides=7)
    add_rod((-1.05, 2.0, depth), (1.05, 2.0, depth), .035, 'Brass', 8)
    add_rod((horizontal, 1.12, depth), (horizontal, 2.0, depth), .04, 'Brass', 8)
    planets = [
        ((1.24, 2.37, depth), .12, 'Brass'),
        ((-1.42, 1.72, depth), .10, 'Marble'),
        ((horizontal, 2.0, depth + .99), .14, 'LeatherOchre'),
        ((horizontal, 2.0, depth - 1.23), .09, 'MoonGlass'),
    ]
    for planet_center, planet_radius, material_name in planets:
        add_sphere(planet_center, planet_radius, material_name, 14, 9)
        add_rod((horizontal, 2.0, depth), planet_center, .022, 'BrassDark', 7)
    add_torus((horizontal, 2.0, depth), 1.25, .025, 'BrassDark', axis='Y', segments=48, sides=6)
    add_torus((horizontal, 2.0, depth), 1.42, .028, 'Brass', axis='X', segments=48, sides=6)


def add_chandelier(horizontal, depth, fixture_index):
    top_y = 9.92
    crown_y = 7.58
    add_rod((horizontal, top_y, depth), (horizontal, crown_y + .35, depth), .045, 'Iron', 8)
    add_torus((horizontal, crown_y + .30, depth), .34, .075, 'BrassDark', axis='Y', segments=24, sides=8)
    add_sphere((horizontal, crown_y, depth), .22, 'Brass', 16, 10)
    add_torus((horizontal, crown_y, depth), 1.12, .06, 'Brass', axis='Y', segments=36, sides=8)
    add_torus((horizontal, crown_y - .19, depth), .82, .04, 'BrassDark', axis='Y', segments=36, sides=7)
    for index in range(8):
        angle = index * math.tau / 8 + math.pi / 8
        inner = (horizontal + .22 * math.cos(angle), crown_y, depth + .22 * math.sin(angle))
        outer = (horizontal + 1.08 * math.cos(angle), crown_y - .04, depth + 1.08 * math.sin(angle))
        add_rod(inner, outer, .042, 'Brass', 8)
        candle_center = (horizontal + 1.12 * math.cos(angle), crown_y + .16, depth + 1.12 * math.sin(angle))
        add_cylinder(candle_center, .085, .32, 'Candle', 12, True)
        add_torus((candle_center[0], crown_y + .02, candle_center[2]), .14, .025, 'BrassDark', axis='Y', segments=16, sides=6)
        flame_center = (candle_center[0], crown_y + .39, candle_center[2])
        add_sphere(flame_center, .11, 'Flame', 12, 8)
        add_rod((candle_center[0], crown_y + .31, candle_center[2]), (candle_center[0], crown_y + .43, candle_center[2]), .035, 'Flame', 7)
    CANDLE_FIXTURES.append((fixture_index, (horizontal, crown_y + .30, depth), 8))


def add_wall_sconces():
    positions = [(-7.00, 6.8, -9.65), (7.00, 6.8, -9.65), (-7.00, 6.2, 4.2), (7.00, 6.2, 4.2)]
    for side, height, depth in positions:
        add_box((side, height, depth), (.18, .48, .42), 'MahoganyEdge')
        add_torus((side - math.copysign(.13, side), height + .08, depth), .20, .035, 'Brass', axis='X', segments=18, sides=6)
        add_rod((side - math.copysign(.15, side), height, depth), (side - math.copysign(.37, side), height + .12, depth), .025, 'Brass', 8)
        add_cylinder((side - math.copysign(.39, side), height + .18, depth), .07, .20, 'Candle', 12, True)
        add_sphere((side - math.copysign(.39, side), height + .34, depth), .09, 'Flame', 12, 8)


def add_stars_and_ornaments():
    for horizontal in (-5.8, 5.8):
        for depth in (-8.9, -1.7, 5.5):
            add_torus((horizontal, 8.55, depth), .30, .035, 'BrassDark', axis='Y', segments=20, sides=6)
            for point in range(8):
                angle = point * math.tau / 8
                add_rod((horizontal + .30 * math.cos(angle), 8.55, depth + .30 * math.sin(angle)), (horizontal + .43 * math.cos(angle), 8.55, depth + .43 * math.sin(angle)), .018, 'Brass', 6)
    for horizontal in (-5.6, 5.6):
        add_box((horizontal, 9.64, -5.4), (2.8, .08, .06), 'MahoganyEdge')
        for depth in (-6.6, -5.4, -4.2):
            add_box((horizontal, 9.70, depth), (.06, .16, .72), 'BrassDark')


def build_scene():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    for mesh in list(bpy.data.meshes):
        if mesh.users == 0:
            bpy.data.meshes.remove(mesh)
    add_floor()
    add_room_shell()
    add_far_wall_panels()
    add_rose_window()
    add_side_shelves()
    add_balconies_and_stairs()
    add_serving_opening()
    add_desk(-4.45, -1.35, -1)
    add_desk(4.45, -1.35, 1)
    add_floor_books()
    add_orrery()
    add_chandelier(-2.8, -2.0, 1)
    add_chandelier(2.8, -6.2, 2)
    add_wall_sconces()
    add_stars_and_ornaments()
    for key, batch in BATCHES.items():
        material_name, profile, bevel = key
        mesh_name = 'MidnightLibrary_' + material_name + '_' + profile
        mesh = bpy.data.meshes.new(mesh_name)
        mesh.from_pydata(batch['vertices'], [], batch['faces'])
        mesh.update()
        for polygon, smooth in zip(mesh.polygons, batch['smooth']):
            polygon.use_smooth = smooth
        object_data = bpy.data.objects.new(mesh_name, mesh)
        bpy.context.collection.objects.link(object_data)
        mesh.materials.append(MATERIALS[material_name])
        if bevel:
            modifier = object_data.modifiers.new('Hand softened edges', 'BEVEL')
            modifier.width = bevel
            modifier.segments = 2
            modifier.limit_method = 'ANGLE'
            normal = object_data.modifiers.new('Weighted face normals', 'WEIGHTED_NORMAL')
            normal.keep_sharp = True
    bpy.context.scene.unit_settings.system = 'METRIC'
    bpy.context.scene.unit_settings.scale_length = 1.0
    bpy.context.scene.world.color = (0.006, 0.009, 0.02)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.export_scene.gltf(
        filepath=str(GLB_PATH),
        export_format='GLB',
        export_apply=True,
        export_animations=False,
        export_cameras=False,
        export_lights=False,
        export_materials='EXPORT',
        export_yup=True,
    )
    bounds = [Vector((999, 999, 999)), Vector((-999, -999, -999))]
    for object_data in bpy.context.scene.objects:
        if object_data.type != 'MESH' or object_data.name.endswith('-colonly'):
            continue
        for vertex in object_data.data.vertices:
            design_vertex = to_design(object_data.matrix_world @ vertex.co)
            bounds[0].x = min(bounds[0].x, design_vertex[0])
            bounds[0].y = min(bounds[0].y, design_vertex[1])
            bounds[0].z = min(bounds[0].z, design_vertex[2])
            bounds[1].x = max(bounds[1].x, design_vertex[0])
            bounds[1].y = max(bounds[1].y, design_vertex[1])
            bounds[1].z = max(bounds[1].z, design_vertex[2])
    print('MIDNIGHT_LIBRARY_EXPORT', GLB_PATH)
    print('MIDNIGHT_LIBRARY_SOURCE', BLEND_PATH)
    print('MIDNIGHT_LIBRARY_BATCHES', len(BATCHES))
    print('MIDNIGHT_LIBRARY_COLLIDERS', len(COLLISION_PROXIES))
    print('MIDNIGHT_LIBRARY_BOOK_SPINES', BOOK_SPINES)
    print('MIDNIGHT_LIBRARY_BOUNDS', tuple(round(value, 3) for value in bounds[0]), tuple(round(value, 3) for value in bounds[1]))
    print('MIDNIGHT_LIBRARY_CANDLES', CANDLE_FIXTURES)


build_scene()
