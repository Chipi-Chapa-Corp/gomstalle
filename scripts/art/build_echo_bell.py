import math
import struct
import wave
from pathlib import Path

import bpy
from mathutils import Vector


OUTPUT = Path(__file__).resolve().parents[2] / "assets" / "castle" / "echo_bell"
GLB_PATH = OUTPUT / "echo_bell.glb"
BLEND_PATH = OUTPUT / "echo_bell.blend"
WAV_PATH = OUTPUT / "bell_chime.wav"


def srgb(value: str) -> float:
    channel = int(value, 16) / 255.0
    return channel / 12.92 if channel <= 0.04045 else ((channel + 0.055) / 1.055) ** 2.4


def material(name: str, color: str, metallic: float, roughness: float) -> bpy.types.Material:
    result = bpy.data.materials.new(name)
    rgba = (srgb(color[0:2]), srgb(color[2:4]), srgb(color[4:6]), 1.0)
    result.diffuse_color = rgba
    result.use_nodes = True
    shader = result.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Base Color"].default_value = rgba
    shader.inputs["Metallic"].default_value = metallic
    shader.inputs["Roughness"].default_value = roughness
    return result


def bevel(obj: bpy.types.Object, amount: float, segments: int = 3) -> None:
    modifier = obj.modifiers.new("EdgeSoftening", "BEVEL")
    modifier.width = amount
    modifier.segments = segments
    modifier.limit_method = "ANGLE"
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=modifier.name)


def assign(obj: bpy.types.Object, mat: bpy.types.Material) -> bpy.types.Object:
    obj.data.materials.append(mat)
    return obj


def cone(name: str, radius_bottom: float, radius_top: float, depth: float, z: float, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=32, radius1=radius_bottom, radius2=radius_top, depth=depth, location=(0, 0, z))
    obj = bpy.context.object
    obj.name = name
    assign(obj, mat)
    bevel(obj, 0.018, 3)
    return obj


def torus(name: str, major: float, minor: float, z: float, mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=32, minor_segments=10, location=(0, 0, z))
    obj = bpy.context.object
    obj.name = name
    assign(obj, mat)
    return obj


def sphere(name: str, radius: float, location: tuple[float, float, float], scale: tuple[float, float, float], mat: bpy.types.Material) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=12, radius=radius, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    assign(obj, mat)
    bpy.ops.object.shade_smooth()
    return obj


def rod(name: str, start: tuple[float, float, float], end: tuple[float, float, float], radius: float, mat: bpy.types.Material) -> bpy.types.Object:
    origin = Vector(start)
    direction = Vector(end) - origin
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=radius, depth=direction.length, location=(origin + Vector(end)) * 0.5)
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    assign(obj, mat)
    bevel(obj, radius * 0.5, 2)
    return obj


def curved_handle(mat: bpy.types.Material) -> bpy.types.Object:
    curve = bpy.data.curves.new("WoodenHandleCurve", "CURVE")
    curve.dimensions = "3D"
    curve.resolution_u = 3
    curve.bevel_depth = 0.07
    curve.bevel_resolution = 3
    spline = curve.splines.new("BEZIER")
    spline.bezier_points.add(4)
    points = [(-0.18, 0, 0.82), (-0.18, 0, 1.04), (0, 0, 1.20), (0.18, 0, 1.04), (0.18, 0, 0.82)]
    for point, coordinate in zip(spline.bezier_points, points):
        point.co = coordinate
        point.handle_left_type = "AUTO"
        point.handle_right_type = "AUTO"
    obj = bpy.data.objects.new("CarvedWoodHandle", curve)
    bpy.context.collection.objects.link(obj)
    assign(obj, mat)
    return obj


def create_chime() -> None:
    sample_rate = 22050
    duration = 1.7
    frame_count = int(sample_rate * duration)
    frequencies = ((659.25, 0.72, 0.38), (987.77, 0.42, 0.23), (1480.0, 0.23, 0.16), (1975.5, 0.16, 0.08))
    frames = bytearray()
    for index in range(frame_count):
        time_value = index / sample_rate
        envelope = math.exp(-2.8 * time_value) * min(1.0, time_value * 90.0)
        sample = sum(math.sin(math.tau * frequency * time_value) * amplitude * math.exp(-decay * time_value) for frequency, amplitude, decay in frequencies)
        sample *= envelope * 0.58
        sample = max(-1.0, min(1.0, sample))
        frames.extend(struct.pack("<h", int(sample * 32767)))
    with wave.open(str(WAV_PATH), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(sample_rate)
        stream.writeframes(frames)


def build() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        for datablock in list(datablocks):
            if datablock.users == 0:
                datablocks.remove(datablock)

    brass = material("EchoBell Brass", "a87535", 0.84, 0.25)
    brass_dark = material("EchoBell Brass Dark", "5b3825", 0.78, 0.31)
    wood = material("EchoBell Walnut", "3c211b", 0.0, 0.42)
    wood_edge = material("EchoBell Handle Edge", "765034", 0.0, 0.52)

    bell = cone("BellBody", 0.38, 0.22, 0.35, 0.36, brass)
    bell.scale = (1.0, 1.0, 0.88)
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    dome = sphere("BellDome", 0.24, (0, 0, 0.60), (1.0, 1.0, 0.73), brass)
    rim = torus("BellRim", 0.34, 0.055, 0.18, brass_dark)
    rim_inner = torus("BellRimHighlight", 0.29, 0.025, 0.22, brass)
    torus("BellEngravedBand", 0.265, 0.018, 0.46, brass_dark)
    torus("BellCapBand", 0.17, 0.024, 0.75, brass)
    clapper = sphere("BellClapper", 0.07, (0, 0, 0.12), (1.0, 1.0, 0.9), brass_dark)
    clapper_stem = rod("BellClapperStem", (0, 0, 0.14), (0, 0, 0.38), 0.018, brass_dark)
    handle = curved_handle(wood)
    rod("HandleGrip", (-0.18, 0, 0.84), (0.18, 0, 0.84), 0.078, wood_edge)
    sphere("HandleCap", 0.085, (-0.18, 0, 0.81), (1.0, 1.0, 0.72), brass_dark)
    sphere("HandleCapRight", 0.085, (0.18, 0, 0.81), (1.0, 1.0, 0.72), brass_dark)

    bpy.ops.object.select_all(action="SELECT")
    for obj in bpy.context.selected_objects:
        obj.select_set(True)
    bpy.ops.wm.save_as_mainfile(filepath=str(BLEND_PATH))
    bpy.ops.export_scene.gltf(filepath=str(GLB_PATH), export_format="GLB", export_yup=True, export_apply=True, export_materials="EXPORT", export_texcoords=True)
    create_chime()


build()
