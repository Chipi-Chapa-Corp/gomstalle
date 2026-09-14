class_name PortalVisual
extends Node3D

const ColumnShader := preload("res://scenes/portal/column.gdshader")

var age := 0.0
var outer_ring := Node3D.new()
var inner_ring: MeshInstance3D
var column_material := ShaderMaterial.new()
var light := OmniLight3D.new()
var surface_material: ShaderMaterial

func _ready() -> void:
	var surface: MeshInstance3D = get_node("PortalSurface")
	surface_material = surface.get_active_material(0).duplicate()
	surface.material_override = surface_material
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("b7a16a")
	metal.metallic = 0.78
	metal.roughness = 0.28
	var luminous := StandardMaterial3D.new()
	luminous.albedo_color = Color("b9eed7")
	luminous.emission_enabled = true
	luminous.emission = Color("6dd9bd")
	luminous.emission_energy_multiplier = 2.0
	_frame(metal)
	add_child(outer_ring)
	_ring(outer_ring, 0.453, 0.466, metal)
	_ring(outer_ring, 0.405, 0.408, luminous)
	for index in 24:
		var glyph := MeshInstance3D.new()
		var stroke := BoxMesh.new()
		stroke.size = Vector3(0.009, 0.008, 0.027 if index % 3 == 0 else 0.015)
		stroke.material = luminous if index % 3 == 0 else metal
		glyph.mesh = stroke
		var angle := float(index) * TAU / 24.0
		glyph.position = Vector3(sin(angle) * 0.434, 0.035, cos(angle) * 0.434)
		glyph.rotation.y = angle
		outer_ring.add_child(glyph)
	inner_ring = _ring(self, 0.34, 0.343, luminous)
	inner_ring.position.y = 0.07
	var column := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = 0.37
	cylinder.top_radius = 0.27
	cylinder.height = 0.7
	cylinder.radial_segments = 64
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	column_material.shader = ColumnShader
	cylinder.material = column_material
	column.mesh = cylinder
	column.position.y = 0.35
	column.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(column)
	light.position.y = 0.18
	light.light_color = Color("72e4c6")
	light.light_energy = 2.8
	light.omni_range = 1.75
	light.omni_attenuation = 1.0
	light.light_volumetric_fog_energy = 0.6
	add_child(light)
	_particles(luminous)
	visibility_changed.connect(_visibility_changed)

func set_diameter(diameter: float) -> void:
	scale = Vector3.ONE * diameter

func _frame(metal: Material) -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("394449")
	stone.roughness = 0.82
	stone.metallic = 0.15
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_normal(Vector3.UP)
	for index in 64:
		var angle_start := float(index) * TAU / 64.0
		var angle_end := float(index + 1) * TAU / 64.0
		var direction_start := Vector3(sin(angle_start), 0, cos(angle_start))
		var direction_end := Vector3(sin(angle_end), 0, cos(angle_end))
		var outer_start := direction_start * (0.5 / maxf(absf(direction_start.x), absf(direction_start.z)))
		var outer_end := direction_end * (0.5 / maxf(absf(direction_end.x), absf(direction_end.z)))
		var inner_start := direction_start * 0.444
		var inner_end := direction_end * 0.444
		for vertex in [outer_start, inner_start, outer_end, outer_end, inner_start, inner_end]:
			surface.add_vertex(vertex + Vector3.UP * 0.014)
	var plate_mesh := surface.commit()
	plate_mesh.surface_set_material(0, stone)
	var plate := MeshInstance3D.new()
	plate.name = "StoneSurround"
	plate.mesh = plate_mesh
	add_child(plate)
	var support := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	collision.shape = plate_mesh.create_trimesh_shape()
	support.add_child(collision)
	add_child(support)
	for index in 4:
		var trim := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.99, 0.012, 0.008)
		bar.material = metal
		trim.mesh = bar
		trim.rotation.y = float(index) * PI * 0.5
		trim.position = Vector3(0, 0.023, 0.493).rotated(Vector3.UP, trim.rotation.y)
		add_child(trim)

func _ring(parent: Node3D, inside: float, outside: float, material: Material) -> MeshInstance3D:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = inside
	torus.outer_radius = outside
	torus.rings = 96
	torus.ring_segments = 8
	torus.material = material
	ring.mesh = torus
	ring.position.y = 0.03
	parent.add_child(ring)
	return ring

func _particles(material: Material) -> void:
	var particles := GPUParticles3D.new()
	particles.name = "SoulEmbers"
	particles.amount = 96
	particles.lifetime = 2.6
	particles.preprocess = 1.0
	particles.visibility_aabb = AABB(Vector3(-0.6, -0.1, -0.6), Vector3(1.2, 1.4, 1.2))
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_radius = 0.44
	process.emission_ring_inner_radius = 0.37
	process.emission_ring_height = 0.015
	process.direction = Vector3.UP
	process.spread = 8.0
	process.gravity = Vector3(0, 0.03, 0)
	process.initial_velocity_min = 0.04
	process.initial_velocity_max = 0.22
	process.scale_min = 0.4
	process.scale_max = 1.0
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0))
	gradient.add_point(0.2, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	particles.process_material = process
	var spark := SphereMesh.new()
	spark.radius = 0.005
	spark.height = 0.01
	spark.radial_segments = 6
	spark.rings = 3
	var spark_material := material.duplicate() as StandardMaterial3D
	spark_material.vertex_color_use_as_albedo = true
	spark_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark.material = spark_material
	particles.draw_pass_1 = spark
	add_child(particles)

func _visibility_changed() -> void:
	if visible:
		age = 0.0

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	age += delta
	var opening := smoothstep(0.0, 1.15, age)
	surface_material.set_shader_parameter("clock", age)
	surface_material.set_shader_parameter("opening", opening)
	column_material.set_shader_parameter("clock", age)
	column_material.set_shader_parameter("opening", opening)
	outer_ring.rotation.y = age * 0.08
	outer_ring.scale = Vector3.ONE * lerpf(0.8, 1.0, opening)
	inner_ring.rotation = Vector3(sin(age * 0.8) * 0.08, -age * 0.14, cos(age * 0.6) * 0.08)
	light.light_energy = (2.6 + sin(age * 2.2) * 0.15) * opening
