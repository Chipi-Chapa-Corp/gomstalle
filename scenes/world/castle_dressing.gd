class_name CastleDressing
extends Node3D

@export var baked_scene: PackedScene

var uses_baked_lighting: bool = false

const ROOM_NAMES: Array[String] = ["The Midnight Library", "The Scriptorium", "The Arrival Hall", "The Alchemist's Still", "The Armory", "The Mirror Parlor", "The Apothecary", "The Wine Cellar", "The Portrait Gallery", "The Candle Chapel", "The Banquet Hall", "The Old Kitchen", "The Royal Crypt", "The Grand Hall", "The Treasury", "The Ossuary", "The Lost Archives", "The Astronomer's Tower"]
const ROOM_BOUNDS: Array[Rect2] = [Rect2(-36, -12, 24, 16), Rect2(-36, 4, 24, 16), Rect2(-12, -12, 24, 32), Rect2(12, -12, 36, 12), Rect2(12, 0, 16, 20), Rect2(28, 0, 20, 12), Rect2(28, 12, 20, 8), Rect2(-36, 20, 12, 24), Rect2(-24, 20, 36, 12), Rect2(-12, 32, 24, 12), Rect2(12, 20, 36, 12), Rect2(12, 32, 36, 12), Rect2(-36, 44, 24, 24), Rect2(-12, 44, 48, 24), Rect2(36, 44, 12, 24), Rect2(-36, 68, 16, 24), Rect2(-20, 68, 12, 24), Rect2(-8, 68, 20, 24)]
const AMBER := Color("ffbe70")
const MOONLIGHT := Color("8faed9")
const SPECTRAL := Color("70d9c4")
const CRIMSON := Color("672b39")
const INK := Color("263d52")
const BRASS := Color("a17c43")
const TIMBER := Color("4b332c")
const IRON := Color("252e39")
const STONE := Color("595e70")
const CUSTOM_MODELS: Array[String] = ["clock", "mirror", "lectern", "sarcophagus", "soul_cage", "brazier", "alembic", "preparation", "herb_rack", "wash_station", "feast_hearth", "feast_preparation", "feast_table_full", "feast_table_spilled", "feast_sideboard", "feast_pantry", "feast_wash", "feast_dais", "feast_serving_hatch", "feast_cookware", "feast_grain_station", "feast_banquet_architecture", "feast_cook_station"]
const SPOOKY_MODELS: Array[String] = ["skull", "skull_candle", "bone_A", "bone_B", "bone_C", "ribcage", "coffin", "coffin_decorated", "bench", "lantern_standing", "lantern_hanging", "shrine_candles", "plaque_candles", "pumpkin_orange_small", "pumpkin_orange_jackolantern"]
const RESOURCE_MODELS: Array[String] = ["Copper_Nuggets", "Copper_Bars", "Iron_Bars", "Gold_Bars_Stack_Small", "Silver_Bars", "Parts_Cog", "Textiles_Stack_Small"]
const SMALL_MODELS: Array[String] = ["spellbook_open", "spellbook_closed", "mug_full", "mug_empty", "staff", "wand"]

var _models: Dictionary[String, PackedScene] = {}
var _materials: Dictionary[Color, StandardMaterial3D] = {}
var _prop_count: int = 0
var _furniture_bounds: Array[AABB] = []

static func get_room_name(world_position: Vector3) -> String:
	var floor_position := Vector2(world_position.x, world_position.z)
	for room_index in ROOM_BOUNDS.size():
		if ROOM_BOUNDS[room_index].has_point(floor_position):
			return ROOM_NAMES[room_index]
	if Rect2(-24, 32, 12, 12).has_point(floor_position):
		return ROOM_NAMES[8]
	return "Castle Grounds"

func get_furniture_bounds() -> Array[AABB]:
	return _furniture_bounds

func _ready() -> void:
	var lighting_mode := OS.get_environment("GOMSTALLE_LIGHTING_MODE")
	if lighting_mode == "baked":
		baked_scene = load("res://assets/lighting/castle.scn")
	if baked_scene != null and lighting_mode != "source":
		_load_baked_castle()
		return
	_build_library()
	_build_scriptorium()
	_build_arrival()
	_build_alchemy()
	_build_armory()
	_build_parlor()
	_build_apothecary()
	_build_cellar()
	_build_gallery()
	_build_chapel()
	_build_banquet()
	_build_kitchen()
	_build_crypt()
	_build_grand_hall()
	_build_treasury()
	_build_ossuary()
	_build_archives()
	_build_observatory()
	set_meta("furnished_rooms", ROOM_NAMES.size())
	set_meta("placed_props", _prop_count)

func _load_baked_castle() -> void:
	uses_baked_lighting = true
	var saved: Node3D = baked_scene.instantiate()
	_furniture_bounds.assign(saved.get_meta("furniture_bounds"))
	for key in ["furnished_rooms", "placed_props"]:
		set_meta(key, saved.get_meta(key))
	saved.get_node("WorldEnvironment").free()
	for descendant in saved.find_children("*", "", true, false):
		descendant.owner = null
	for child in saved.get_children():
		child.reparent(self, false)
	saved.free()

func open_baked_floor(cell: Vector3i) -> void:
	if uses_baked_lighting:
		get_node("Floors/Floor_%d_%d_%d" % [cell.x, cell.y, cell.z]).visible = false

func _room(room_index: int, accent: Color) -> Node3D:
	var room := Node3D.new()
	room.name = ROOM_NAMES[room_index].replace(" ", "").replace("'", "")
	room.set_meta("room_name", ROOM_NAMES[room_index])
	room.set_meta("room_bounds", ROOM_BOUNDS[room_index])
	add_child(room)
	var center: Vector2 = ROOM_BOUNDS[room_index].get_center()
	var light := OmniLight3D.new()
	light.name = "RoomFill"
	light.position = Vector3(center.x, 5.5, center.y)
	light.light_color = accent.lerp(MOONLIGHT, 0.55)
	light.light_energy = 1.3
	light.omni_range = maxf(ROOM_BOUNDS[room_index].size.x, ROOM_BOUNDS[room_index].size.y) * 0.62
	light.omni_attenuation = 0.8
	light.shadow_enabled = false
	room.add_child(light)
	_cornice(room, ROOM_BOUNDS[room_index])
	return room

func _build_library() -> void:
	var room := _room(0, AMBER)
	_assembly(room, "res://assets/castle/library/reading_gallery.glb", "ReadingGallery")
	for horizontal in [-26.9, -21.7]:
		for depth in [-1.55, -4.55]:
			_practical(room, Vector3(horizontal, 1.55, depth), AMBER, 0.9, 3.8)
	_practical(room, Vector3(-31.85, 1.65, 1.4), AMBER, 1.2, 4)
	_practical(room, Vector3(-18.25, 2.7, 1.45), MOONLIGHT, 1.0, 4)
	_sconce(room, Vector3(-29.2, 4.6, -10.1), 0, AMBER)
	_sconce(room, Vector3(-20.4, 4.6, -10.1), 0, AMBER)

func _build_scriptorium() -> void:
	var room := _room(1, SPECTRAL)
	_carpet(room, Vector3(-24, 0.07, 12), Vector2(5, 12), CRIMSON)
	for depth in [8.0, 15.0]:
		_prop(room, "table_long", Vector3(-29, 0, depth), PI / 2)
		_prop(room, "chair", Vector3(-29, 0, depth + 1.8), PI)
		_prop(room, "spellbook_open", Vector3(-29, 1.02, depth), 0, 1.0, false)
		_prop(room, "candle_triple", Vector3(-30.4, 1.02, depth), 0, 1.0, false)
		_prop(room, "bottle_A_green", Vector3(-27.5, 1.02, depth), 0, 0.8, false)
		_bookcase(room, Vector3(-14, 0, depth), -PI / 2)
	_prop(room, "lectern", Vector3(-23, 0, 6), 0, 1.2)
	_prop(room, "soul_cage", Vector3(-33.8, 0, 15.3), 0, 1.1)
	_prop(room, "mirror", Vector3(-20, 0, 5.3), 0)
	_prop(room, "trunk_large_C", Vector3(-16, 0, 17.8), 0)
	_banner(room, Vector3(-22, 0, 4.8), "green")
	_practical(room, Vector3(-33.8, 2, 15.3), SPECTRAL, 2.8, 6)
	_chandelier(room, Vector3(-24, 3.4, 12), AMBER)
	_book_stack(room, Vector3(-27.4, 1.02, 15), 4)
	_prop(room, "spellbook_closed", Vector3(-29.8, 1.04, 8.3), 0.3, 0.9, false)
	_prop(room, "mug_full", Vector3(-27.6, 1.03, 8), 0, 0.7, false)
	_prop(room, "box_small", Vector3(-33, 0, 10.5), 0)
	_book_stack(room, Vector3(-32.5, 0.05, 12), 4)

func _build_arrival() -> void:
	var room := _room(2, AMBER)
	_carpet(room, Vector3(0, 0.07, 10), Vector2(5.5, 15), CRIMSON)
	_carpet(room, Vector3(0, 0.07, -7), Vector2(5.5, 5), CRIMSON)
	for horizontal in [-8.0, 8.0]:
		for depth in [-7.0, 15.0]:
			_prop(room, "pillar_decorated", Vector3(horizontal, 0, depth), 0, 0.7)
			_prop(room, "brazier", Vector3(horizontal, 0, depth + 2), 0, 1.1)
			_practical(room, Vector3(horizontal, 1.8, depth + 2), AMBER, 2.3, 6)
	_prop(room, "table_medium_tablecloth_decorated_B", Vector3(7.3, 0, 5), 0)
	_prop(room, "chair", Vector3(7.3, 0, 7), PI)
	_prop(room, "clock", Vector3(0, 0, -10.6), 0, 1.25)
	_banner(room, Vector3(-5, 0, -11.1), "red")
	_banner(room, Vector3(5, 0, -11.1), "red")
	for depth in [-5.0, 11.0]:
		_chandelier(room, Vector3(0, 3.5, depth), AMBER)

func _build_alchemy() -> void:
	var room := _room(3, SPECTRAL)
	_assembly(room, "res://assets/castle/alchemy/working_bays.glb", "AlchemicalWorkingBays")
	_practical(room, Vector3(19.5, 1.0, -8.9), AMBER, 3.1, 7)
	_practical(room, Vector3(22.5, 1.0, -9.3), SPECTRAL, 1.5, 4)
	_practical(room, Vector3(31.5, 2.4, -7.55), SPECTRAL, 2.4, 7)
	_practical(room, Vector3(41.3, 0.8, -9.1), AMBER, 2.6, 6)
	_practical(room, Vector3(44.5, 1.6, -9.2), SPECTRAL, 1.4, 4)
	_sconce(room, Vector3(13, 2.5, -6), PI / 2, AMBER)

func _build_armory() -> void:
	var room := _room(4, MOONLIGHT)
	_assembly(room, "res://assets/castle/workshops/armory.glb", "ArmoryForgeAndRepair")
	_practical(room, Vector3(25, 1.55, 16.6), AMBER, 3.0, 8)
	_practical(room, Vector3(22.5, 3.1, 3.8), MOONLIGHT, 1.7, 8)
	_sconce(room, Vector3(13, 2.5, 7), PI / 2, AMBER)

func _build_parlor() -> void:
	var room := _room(5, Color("c5a0d5"))
	_assembly(room, "res://assets/castle/social/parlor.glb", "EveningConversation")
	_prop(room, "mirror", Vector3(38.8, 0, 1.05), 0, 1.45)
	_practical(room, Vector3(43, 0.8, 1.6), AMBER, 2.1, 6)
	_practical(room, Vector3(43, 2.6, 6.4), AMBER, 1.2, 6)
	_sconce(room, Vector3(30.7, 2.7, 0.9), 0, AMBER)
	_sconce(room, Vector3(40.45, 2.7, 0.9), 0, AMBER)

func _build_apothecary() -> void:
	var room := _room(6, SPECTRAL)
	_assembly(room, "res://assets/castle/workshops/apothecary.glb", "ApothecaryDispensingWorkshop")
	_practical(room, Vector3(32, 2.6, 15.7), AMBER, 1.7, 7)
	_practical(room, Vector3(44, 2.5, 17), AMBER, 1.5, 5)
	_sconce(room, Vector3(29, 2.4, 16), PI / 2, AMBER)

func _build_cellar() -> void:
	var room := _room(7, AMBER)
	for depth in [23.0, 29.0, 35.0, 41.0]:
		_prop(room, "keg_decorated", Vector3(-33.5, 0, depth), PI / 2)
		_prop(room, "barrel_small", Vector3(-26, 0, depth + 0.4), 0)
	_prop(room, "table_small_decorated_A", Vector3(-29, 0, 38), 0)
	_prop(room, "stool", Vector3(-29, 0, 36.4), 0)
	_prop(room, "box_small", Vector3(-32, 0, 32), 0, 1.1)
	_prop(room, "trunk_medium_B", Vector3(-29.5, 0, 33), 0)
	_prop(room, "bottle_B_brown", Vector3(-29.3, 1.02, 38), 0, 1.0, false)
	_prop(room, "mug_full", Vector3(-28.6, 1.02, 38.2), 0, 0.8, false)
	_prop(room, "box_small", Vector3(-26, 0, 37.5), 0, 0.8)
	_prop(room, "bottle_C_brown", Vector3(-31.5, 0.2, 26.5), 0, 1.0, false).rotation.z = PI / 2
	_stain(room, Vector3(-31.3, 0.07, 26.5), Vector2(1.6, 1), Color("462b34"))
	for depth in [24.0, 38.0]:
		_sconce(room, Vector3(-35.2, 2.5, depth), PI / 2, AMBER)

func _build_gallery() -> void:
	var room := _room(8, Color("b9a1d3"))
	_assembly(room, "res://assets/castle/social/gallery.glb", "AncestralGallery")
	for horizontal in [-15.4, -5.5, 7.0]:
		_sconce(room, Vector3(horizontal, 2.8, 20.85), 0, AMBER)
	_practical(room, Vector3(-7.7, 3.1, 22.0), AMBER, 1.1, 5)
	_practical(room, Vector3(1.0, 3.1, 22.0), AMBER, 1.1, 5)
	_sconce(room, Vector3(-23.0, 2.8, 37.8), PI / 2, AMBER)

func _build_chapel() -> void:
	var room := _room(9, AMBER)
	_assembly(room, "res://assets/castle/memorials/chapel.glb", "SanctuaryOfTheLastWatch")
	for horizontal in [1.5, 5.5]:
		_practical(room, Vector3(horizontal, 2.0, 33.7), AMBER, 1.1, 5)
	for depth in [34.2, 39.4]:
		_practical(room, Vector3(-10, 2.0, depth), AMBER, 1.1, 5)
	_sconce(room, Vector3(9.8, 3.0, 32.9), 0, SPECTRAL)
	_practical(room, Vector3(2.5, 3.7, 39), AMBER, 1.2, 7)

func _build_banquet() -> void:
	var room := _room(10, Color("e6b784"))
	var first_table := _prop(room, "feast_table_full", Vector3(24.5, 0, 26), 0, 1, false)
	var second_table := _prop(room, "feast_table_spilled", Vector3(35.5, 0, 26), 0, 1, false)
	for table: Node3D in [first_table, second_table]:
		_add_collision(table, Vector3(0, 0.61, 0), Vector3(7.8, 1.22, 2.5))
		for seat in [-3.2, -1.6, 0.0, 1.6, 3.2]:
			_prop(room, "chair", table.position + Vector3(seat, 0, -2), 0, 0.92)
			if table == first_table or seat != 1.6:
				_prop(room, "chair", table.position + Vector3(seat, 0, 2), PI, 0.92)
		_practical(room, table.position + Vector3(0, 2.3, 0), AMBER, 2.4, 7)
	_prop(room, "chair", Vector3(37.2, 0, 28.7), PI + 0.35, 0.92)
	_prop(room, "feast_sideboard", Vector3(25.5, 0, 21.3))
	var dais := _prop(room, "feast_dais", Vector3(45.1, 0, 26), 0, 1, false)
	_add_collision(dais, Vector3(0, 0.15, 0), Vector3(4.8, 0.3, 6.8))
	_add_collision(dais, Vector3(0.23, 0.45, 0), Vector3(4.35, 0.3, 6.4))
	_add_collision(dais, Vector3(0.77, 1.7, 0), Vector3(1.4, 2.2, 1.7))
	_add_collision(dais, Vector3(1.76, 2.1, 0), Vector3(0.3, 3.0, 4.95))
	_add_collision(dais, Vector3(-0.65, 1.1, 0), Vector3(1.4, 1, 2.2))
	_practical(room, Vector3(43, 2.8, 26), AMBER, 2.8, 7)
	_prop(room, "feast_banquet_architecture", Vector3(30, 0, 26), 0, 1, false)
	_portrait(room, Vector3(14.1, 2.25, 25.5), PI / 2, "portrait_knight")
	_prop(room, "table_medium_tablecloth_decorated_B", Vector3(14.7, 0, 26), 0)
	_prop(room, "bottle_A_brown", Vector3(14.7, 1.03, 26), 0, 1, false)
	_prop(room, "candle_triple", Vector3(14.7, 1.03, 25.1), 0, 0.8, false)
	_stain(room, Vector3(37.1, 0.07, 27.5), Vector2(1.1, 0.5), Color("572d3c"))

func _build_kitchen() -> void:
	var room := _room(11, Color("d8af77"))
	var hearth := _prop(room, "feast_hearth", Vector3(44.425, 0, 33.3), 0, 0.85, false)
	_add_collision(hearth, Vector3(0, 1.875, 0), Vector3(7.2, 3.75, 2.8))
	_practical(room, Vector3(44.2, 1.25, 34.5), Color("ff9c50"), 3.8, 8)
	var serving_hatch := _prop(room, "feast_serving_hatch", Vector3(38, 0, 32), 0, 1, false)
	_add_collision(serving_hatch, Vector3(0, 0.5, 0), Vector3(3.2, 1, 1))
	_add_collision(serving_hatch, Vector3(0, 1.05, 0.55), Vector3(6.7, 0.15, 2))
	_add_collision(serving_hatch, Vector3(0, 3.12, 0), Vector3(3.5, 1.76, 1.08))
	for jamb in [-1.75, 1.75]:
		_add_collision(serving_hatch, Vector3(jamb, 2, 0), Vector3(0.5, 4, 1.12))
	for cabinet in [-2.85, 2.85]:
		_add_collision(serving_hatch, Vector3(cabinet, 0.5, 0.9), Vector3(0.85, 1, 1.2))
	_prop(room, "feast_cookware", Vector3(31.8, 1.6, 32.95), 0, 1, false)
	_prop(room, "feast_grain_station", Vector3(27.6, 0, 38.2))
	var cook_station := _prop(room, "feast_cook_station", Vector3(43.4, 0, 38.5), 0, 1, false)
	_add_collision(cook_station, Vector3(0, 0.6, 0), Vector3(3.2, 1.2, 1.6))
	var preparation := _prop(room, "feast_preparation", Vector3(34.5, 0, 38.2), 0, 1, false)
	_add_collision(preparation, Vector3(0, 0.6, 0), Vector3(6.7, 1.2, 2.25))
	_prop(room, "feast_pantry", Vector3(15.4, 0, 39.3), PI / 2)
	_prop(room, "lantern_standing", Vector3(16.05, 1.075, 37.7), 0, 0.55, false)
	_practical(room, Vector3(16.5, 1.6, 37.7), AMBER, 1.8, 5)
	var wash := _prop(room, "feast_wash", Vector3(30, 0, 42.8), PI, 1, false)
	_add_collision(wash, Vector3(0, 0.68, 0), Vector3(5.5, 1.36, 1.5))
	_add_collision(wash, Vector3(-1.3, 2.05, -0.53), Vector3(1.4, 1.05, 0.7))
	_prop(room, "barrel_small", Vector3(17.4, 0, 42.2), 0, 0.95)
	_prop(room, "barrel_small", Vector3(15.2, 0, 42.3), 0, 0.85)
	_prop(room, "herb_rack", Vector3(25.8, 2.6, 32.9), 0, 1.15, false)
	_prop(room, "table_long", Vector3(27, 0, 33.2), PI / 2, 1.15)
	_prop(room, "plate_stack", Vector3(25.7, 1.18, 33.2), 0, 1.25, false)
	_prop(room, "plate_stack", Vector3(26.5, 1.18, 33.2), 0, 0.9, false)
	_prop(room, "plate_food_B", Vector3(28.2, 1.18, 33.2), 0, 1.15, false)
	_sconce(room, Vector3(21, 2.5, 32.9), 0, AMBER)
	_practical(room, Vector3(34, 3.2, 38), AMBER, 1.9, 8)

func _build_crypt() -> void:
	var room := _room(12, SPECTRAL)
	_assembly(room, "res://assets/castle/memorials/crypt.glb", "TombsOfTheSleepingCourt")
	for horizontal in [-30.7, -23.3]:
		_practical(room, Vector3(horizontal, 2.1, 47.5), AMBER, 1.1, 5)
	for depth in [53.0, 63.0]:
		_sconce(room, Vector3(-35, 2.7, depth), PI / 2, SPECTRAL)
	_practical(room, Vector3(-25.5, 3.5, 57), SPECTRAL, 1.5, 9)

func _build_grand_hall() -> void:
	var room := _room(13, AMBER)
	_carpet(room, Vector3(12, 0.07, 56), Vector2(43, 5), CRIMSON)
	for horizontal in [-7.0, 1.0, 23.0, 31.0]:
		_prop(room, "table_long_tablecloth", Vector3(horizontal, 0, 48), PI / 2)
		_prop(room, "candle_triple", Vector3(horizontal, 1.02, 48), 0, 1.1, false)
		_prop(room, "sword_shield_gold", Vector3(horizontal, 1.25, 48), 0, 0.7, false)
		_prop(room, "trunk_large_C", Vector3(horizontal, 0, 64), PI / 2, 1.1)
		_banner(room, Vector3(horizontal, 0, 44.8), "red")
	for horizontal in [-3.0, 27.0]:
		_chandelier(room, Vector3(horizontal, 3.5, 56), AMBER)
	for depth in [47.0, 65.0]:
		_prop(room, "brazier", Vector3(9.8, 0, depth), 0, 1.2)
		_prop(room, "brazier", Vector3(14.2, 0, depth), 0, 1.2)
		_practical(room, Vector3(12, 2, depth), AMBER, 2, 8)
	_platform(room, Vector3(-6, 0.6, 61), Vector3(3, 1.2, 2.5))
	_platform(room, Vector3(-1, 1.2, 61), Vector3(3, 2.4, 2.5))
	_platform(room, Vector3(5, 1.2, 61), Vector3(3, 2.4, 2.5))
	_platform(room, Vector3(19, 0.6, 51), Vector3(3, 1.2, 2.5))
	_platform(room, Vector3(24, 1.2, 51), Vector3(3, 2.4, 2.5))
	_platform(room, Vector3(30, 1.2, 51), Vector3(3, 2.4, 2.5))
	_prop(room, "chest_gold", Vector3(5, 2.4, 61), 0, 0.8)
	_prop(room, "soul_cage", Vector3(30, 2.4, 51), 0, 0.75)

func _build_treasury() -> void:
	var room := _room(14, AMBER)
	_carpet(room, Vector3(42, 0.07, 56), Vector2(4.5, 17), INK)
	for depth in [51.0, 57.0, 64.0]:
		_prop(room, "chest_gold", Vector3(45.7, 0, depth), -PI / 2, 1.15)
		_prop(room, "coin_stack_large", Vector3(44.8, 0.02, depth - 1), 0, 1.0, false)
		_prop(room, "coin_stack_medium", Vector3(46, 0.02, depth - 1.2), 0, 1.0, false)
	for depth in [51.0, 63.0]:
		_prop(room, "trunk_large_A", Vector3(38, 0, depth), PI / 2)
		_prop(room, "sword_shield_gold", Vector3(37, 2.3, depth), PI / 2, 1.0, false)
	_prop(room, "soul_cage", Vector3(44.5, 0, 47), 0)
	_practical(room, Vector3(42, 2.4, 47), SPECTRAL, 2.8, 6)
	_banner(room, Vector3(42, 0, 67), "yellow", PI)
	_chandelier(room, Vector3(42, 3.4, 56), AMBER)
	_prop(room, "table_small_decorated_B", Vector3(38.5, 0, 47.5), 0)
	_prop(room, "coin_stack_large", Vector3(38.5, 1.02, 63), 0, 0.8, false)
	_prop(room, "keyring", Vector3(44, 0.06, 62.5), 0, 1.0, false)
	_prop(room, "box_small_decorated", Vector3(45.3, 0, 60), 0.2, 0.8)
	_prop(room, "Gold_Bars_Stack_Small", Vector3(38, 1.03, 51), 0, 0.55, false)
	_prop(room, "Silver_Bars", Vector3(38, 1.03, 63), 0, 0.55, false)

func _build_ossuary() -> void:
	var room := _room(15, MOONLIGHT)
	_assembly(room, "res://assets/castle/memorials/ossuary.glb", "BoneKeepersWorkshop")
	for horizontal in [-32.8, -22.65]:
		_sconce(room, Vector3(horizontal, 3.7, 68.7), 0, SPECTRAL)
	for position_value in [Vector3(-31.3, 1.6, 75.6), Vector3(-22.5, 1.6, 76.6), Vector3(-24, 1.7, 89.5)]:
		_practical(room, position_value, AMBER, 1.0, 5)
	_practical(room, Vector3(-27.7, 3.5, 82), MOONLIGHT, 1.2, 8)

func _build_archives() -> void:
	var room := _room(16, AMBER)
	for depth in [73.0, 78.0, 87.0]:
		_bookcase(room, Vector3(-18.9, 0, depth), PI / 2)
		_bookcase(room, Vector3(-9.1, 0, depth), -PI / 2)
	_prop(room, "clock", Vector3(-14, 0, 90.5), PI, 1.1)
	_prop(room, "table_small", Vector3(-16, 0, 70), 0)
	_prop(room, "trunk_large_C", Vector3(-11, 0, 75), 0, 1.2)
	_prop(room, "table_small", Vector3(-13.5, 0, 86), 0)
	_book_stack(room, Vector3(-13.5, 1.02, 86), 4)
	_prop(room, "chair", Vector3(-13.5, 0, 84), 0)
	_prop(room, "lectern", Vector3(-11, 0, 89.5), PI)
	_sconce(room, Vector3(-19, 2.6, 83), PI / 2, AMBER)
	_practical(room, Vector3(-18, 2.5, 70), SPECTRAL, 2, 5)
	_chandelier(room, Vector3(-14, 3.4, 77), AMBER)
	_book_stack(room, Vector3(-16.7, 0.03, 76), 6)
	_book_stack(room, Vector3(-16.1, 0.03, 77), 4)
	_book_stack(room, Vector3(-11, 1.2, 75), 3)
	_prop(room, "spellbook_open", Vector3(-15.1, 0.09, 78.1), -0.3, 0.9, false)
	_prop(room, "skull_candle", Vector3(-13.5, 1.7, 86), 0, 0.7, false)
	_prop(room, "Textiles_Stack_Small", Vector3(-11, 0, 80), 0, 0.6)
	_prop(room, "lantern_standing", Vector3(-16, 1.02, 70), 0, 0.6, false)

func _build_observatory() -> void:
	var room := _room(17, MOONLIGHT)
	_carpet(room, Vector3(2, 0.07, 76), Vector2(7, 10), INK)
	_prop(room, "table_medium_tablecloth", Vector3(2, 0, 76), 0, 1.3)
	_prop(room, "spellbook_open", Vector3(2, 1.32, 76), 0, 1.3, false)
	_prop(room, "candle_triple", Vector3(3, 1.32, 76), 0, 1.0, false)
	for depth in [72.0, 77.0, 87.0]:
		_bookcase(room, Vector3(-6.8, 0, depth), PI / 2)
	_prop(room, "clock", Vector3(8, 0, 70), 0)
	_prop(room, "mirror", Vector3(-3, 0, 90.5), PI, 1.2)
	_prop(room, "trunk_large_A", Vector3(5, 0, 80), 0)
	_rune_circle(room, Vector3(6, 4.07, 87), 2.4, MOONLIGHT)
	_prop(room, "lectern", Vector3(2, 4, 89.5), PI, 1.1)
	_prop(room, "brazier", Vector3(1.5, 4, 85), 0, 0.8)
	_practical(room, Vector3(1.5, 5.5, 85), SPECTRAL, 2.8, 7)
	_practical(room, Vector3(10, 6.5, 89), MOONLIGHT, 2.6, 7)
	_chandelier(room, Vector3(2, 3.5, 75), AMBER)
	_prop(room, "staff", Vector3(-2.5, 0.1, 75), 0, 1.2, false).rotation.z = -0.2
	_book_stack(room, Vector3(1.1, 1.32, 75.4), 3)
	_prop(room, "sword_shield_gold", Vector3(6, 4.1, 88), 0, 0.65, false).rotation.x = -PI / 2
	_prop(room, "spellbook_open", Vector3(2, 5.45, 89.5), PI, 0.7, false)
	_orrery(room, Vector3(5, 0, 72.5))

func _prop(room: Node3D, model_name: String, position_value: Vector3, yaw: float = 0, scale_factor: float = 1, solid: bool = true) -> Node3D:
	if not _models.has(model_name):
		var directory := "res://assets/dungeon/models/"
		var extension := ".gltf"
		if model_name in CUSTOM_MODELS:
			directory = "res://assets/castle/"
			if model_name in ["alembic", "preparation", "herb_rack", "wash_station"] or model_name.begins_with("feast_"):
				extension = ".glb"
		elif model_name in SPOOKY_MODELS:
			directory = "res://assets/spooky/"
		elif model_name in RESOURCE_MODELS:
			directory = "res://assets/resources/"
		elif model_name in SMALL_MODELS:
			directory = "res://assets/models/"
		_models[model_name] = load("res://scenes/chair/scene.tscn") if model_name == "chair" else load(directory + model_name + extension)
	var prop: Node3D = _models[model_name].instantiate()
	prop.name = model_name.to_pascal_case() + str(_prop_count)
	_prop_count += 1
	prop.position = position_value
	prop.rotation.y = yaw
	prop.scale = Vector3.ONE * scale_factor
	room.add_child(prop)
	var bounds := AABB()
	var has_bounds := false
	for mesh_node: MeshInstance3D in prop.find_children("*", "MeshInstance3D", true, false):
		mesh_node.visibility_range_end = 46
		mesh_node.visibility_range_end_margin = 5
		var mesh_bounds: AABB = prop.global_transform.affine_inverse() * mesh_node.global_transform * mesh_node.mesh.get_aabb()
		bounds = bounds.merge(mesh_bounds) if has_bounds else mesh_bounds
		has_bounds = true
	if solid and model_name != "chair":
		if model_name.begins_with("table_"):
			bounds.position.y = 0
			bounds.size.y = 1
		if model_name == "alembic":
			bounds.size.y = minf(bounds.size.y, 3.0)
		_add_collision(prop, bounds.position + bounds.size * 0.5, bounds.size)
	return prop

func _assembly(room: Node3D, scene_path: String, assembly_name: String) -> void:
	var assembly_scene: PackedScene = load(scene_path)
	var assembly: Node3D = assembly_scene.instantiate()
	assembly.name = assembly_name
	room.add_child(assembly)
	for mesh_node: MeshInstance3D in assembly.find_children("*", "MeshInstance3D", true, false):
		mesh_node.visibility_range_end = 54
		mesh_node.visibility_range_end_margin = 6
		_prop_count += 1
	for collision: CollisionShape3D in assembly.find_children("*", "CollisionShape3D", true, false):
		var body: StaticBody3D = collision.get_parent()
		body.collision_layer = 1
		body.collision_mask = 0
		_furniture_bounds.append(collision.global_transform * collision.shape.get_debug_mesh().get_aabb())

func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.86
		_materials[color] = material
	return _materials[color]

func _box(parent: Node3D, position_value: Vector3, size_value: Vector3, color: Color, solid: bool = false) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size_value
	box_mesh.material = _material(color)
	mesh_instance.mesh = box_mesh
	mesh_instance.position = position_value
	mesh_instance.visibility_range_end = 46
	parent.add_child(mesh_instance)
	if solid:
		_add_collision(mesh_instance, Vector3.ZERO, size_value)
	return mesh_instance

func _add_collision(parent: Node3D, center: Vector3, size_value: Vector3) -> void:
	var body := StaticBody3D.new()
	body.name = "FurnitureBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size_value
	collision.shape = shape
	collision.position = center
	body.add_child(collision)
	parent.add_child(body)
	_furniture_bounds.append(parent.global_transform * AABB(center - size_value * 0.5, size_value))

func _carpet(room: Node3D, center: Vector3, size_value: Vector2, color: Color) -> void:
	_box(room, center, Vector3(size_value.x, 0.025, size_value.y), BRASS)
	_box(room, center + Vector3(0, 0.017, 0), Vector3(size_value.x - 0.14, 0.02, size_value.y - 0.14), color)
	for side in [-1.0, 1.0]:
		_box(room, center + Vector3(side * (size_value.x * 0.5 - 0.34), 0.03, 0), Vector3(0.045, 0.01, size_value.y - 0.4), BRASS)

func _banner(room: Node3D, position_value: Vector3, color_name: String, yaw: float = 0) -> void:
	_prop(room, "banner_patternA_" + color_name, position_value, yaw, 0.85, false)

func _bookcase(room: Node3D, position_value: Vector3, yaw: float) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "Bookcase"
	cabinet.position = position_value
	cabinet.rotation.y = yaw
	room.add_child(cabinet)
	_box(cabinet, Vector3(0, 1.4, -0.17), Vector3(3, 2.8, 0.15), TIMBER)
	for side in [-1.43, 1.43]:
		_box(cabinet, Vector3(side, 1.4, 0.15), Vector3(0.14, 2.8, 0.7), TIMBER)
	for height in [0.12, 0.78, 1.44, 2.1, 2.77]:
		_box(cabinet, Vector3(0, height, 0.15), Vector3(3.15, 0.12, 0.78), TIMBER)
	var book_colors: Array[Color] = [CRIMSON, INK, Color("647353"), Color("a28862")]
	for color_index in book_colors.size():
		var books := MultiMeshInstance3D.new()
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		var book_mesh := BoxMesh.new()
		book_mesh.size = Vector3(0.19, 0.47, 0.4)
		book_mesh.material = _material(book_colors[color_index])
		multimesh.mesh = book_mesh
		multimesh.instance_count = 12
		for book_index in 12:
			var shelf_index: int = book_index / 3
			var horizontal: float = -1.15 + (book_index % 3) * 0.86 + color_index * 0.21
			var height: float = 0.41 + shelf_index * 0.66
			var book_basis := Basis.IDENTITY.scaled(Vector3(1, 0.85 + 0.1 * ((book_index + color_index) % 3), 1))
			multimesh.set_instance_transform(book_index, Transform3D(book_basis, Vector3(horizontal, height, 0.21)))
		books.multimesh = multimesh
		books.visibility_range_end = 38
		cabinet.add_child(books)
	_add_collision(cabinet, Vector3(0, 1.4, 0.15), Vector3(3.15, 2.8, 0.78))
	_prop_count += 1

func _potion_shelf(room: Node3D, position_value: Vector3, yaw: float) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "ApothecaryShelf"
	cabinet.position = position_value
	cabinet.rotation.y = yaw
	room.add_child(cabinet)
	_prop(cabinet, "shelves", Vector3.ZERO, 0, 1.25, false)
	for shelf_index in 3:
		for bottle_index in 3:
			var bottle_name := "bottle_A_labeled_green" if (shelf_index + bottle_index) % 2 == 0 else "bottle_B_brown"
			_prop(cabinet, bottle_name, Vector3(-0.75 + bottle_index * 0.7, 1.0 + shelf_index * 0.8, 0.55), 0, 0.85, false)

func _platform(room: Node3D, center: Vector3, size_value: Vector3) -> void:
	var tier_count := roundi(size_value.y / 1.2)
	for tier_index in tier_count:
		for horizontal in [-0.65, 0.65]:
			for depth in [-0.6, 0.6]:
				_prop(room, "box_large", Vector3(center.x + horizontal, tier_index * 1.2, center.z + depth), 0, 0.8)
	for plank_index in 6:
		_box(room, Vector3(center.x - 1.3 + plank_index * 0.52, size_value.y + 0.04, center.z), Vector3(0.5, 0.12, 2.7), Color("76604a"))
	_add_collision(room, Vector3(center.x, size_value.y + 0.04, center.z), Vector3(3.1, 0.12, 2.7))
	_box(room, Vector3(center.x, size_value.y + 0.11, center.z + 1.15), Vector3(2.8, 0.025, 0.1), BRASS)

func _practical(room: Node3D, position_value: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.name = "PracticalLight"
	light.position = position_value
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	light.omni_attenuation = 1.4
	light.distance_fade_enabled = true
	light.distance_fade_begin = 24
	light.distance_fade_length = 8
	room.add_child(light)

func _sconce(room: Node3D, position_value: Vector3, yaw: float, color: Color) -> void:
	_prop(room, "torch_mounted", position_value, yaw, 1.0, false)
	_practical(room, position_value + Vector3(0, 0.5, 0), color, 2.5, 7)

func _chandelier(room: Node3D, position_value: Vector3, color: Color) -> void:
	var chandelier := Node3D.new()
	chandelier.name = "CandleChandelier"
	chandelier.position = position_value
	room.add_child(chandelier)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.85
	torus.outer_radius = 1.02
	torus.rings = 12
	torus.ring_segments = 4
	torus.material = _material(IRON)
	ring.mesh = torus
	ring.visibility_range_end = 40
	chandelier.add_child(ring)
	_box(chandelier, Vector3(0, 0.6, 0), Vector3(0.055, 1.2, 0.055), IRON)
	for candle_index in 6:
		var angle: float = candle_index * TAU / 6
		var candle_position := Vector3(cos(angle) * 0.9, 0, sin(angle) * 0.9)
		_prop(chandelier, "candle_lit", candle_position, 0, 0.8, false)
	_practical(chandelier, Vector3(0, -0.25, 0), color, 2.2, 9)

func _rune_circle(room: Node3D, position_value: Vector3, radius: float, color: Color) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color.darkened(0.3)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.8
	for ring_index in 2:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = radius - ring_index * 0.22 - 0.025
		torus.outer_radius = radius - ring_index * 0.22 + 0.025
		torus.rings = 48
		torus.ring_segments = 4
		torus.material = material
		ring.mesh = torus
		ring.position = position_value
		room.add_child(ring)
	for mark_index in 8:
		var angle: float = mark_index * TAU / 8
		var mark_position := position_value + Vector3(cos(angle) * (radius - 0.43), 0, sin(angle) * (radius - 0.43))
		var mark := _box(room, mark_position, Vector3(0.23, 0.018, 0.1), color)
		mark.rotation.y = -angle

func _cornice(room: Node3D, bounds: Rect2) -> void:
	var center: Vector2 = bounds.get_center()
	for depth in [bounds.position.y + 0.3, bounds.end.y - 0.3]:
		_box(room, Vector3(center.x, 3.86, depth), Vector3(bounds.size.x, 0.2, 0.28), TIMBER)
	for horizontal in [bounds.position.x + 0.3, bounds.end.x - 0.3]:
		_box(room, Vector3(horizontal, 3.86, center.y), Vector3(0.28, 0.2, bounds.size.y), TIMBER)
	for horizontal in [bounds.position.x + 0.7, bounds.end.x - 0.7]:
		for depth in [bounds.position.y + 0.7, bounds.end.y - 0.7]:
			_box(room, Vector3(horizontal, 3.4, depth), Vector3(0.35, 0.8, 0.35), TIMBER)

func _book_stack(room: Node3D, position_value: Vector3, amount: int) -> void:
	var colors: Array[Color] = [CRIMSON, INK, Color("647353"), Color("a28862")]
	for book_index in amount:
		var book := Node3D.new()
		book.position = position_value + Vector3(0, book_index * 0.16, 0)
		book.rotation.y = 0.12 * (book_index % 3 - 1)
		room.add_child(book)
		_box(book, Vector3(0, 0.075, 0), Vector3(0.58, 0.11, 0.42), Color("bcb197"))
		_box(book, Vector3(0, 0.015, 0), Vector3(0.64, 0.025, 0.46), colors[book_index % colors.size()])
		_box(book, Vector3(0, 0.135, 0), Vector3(0.64, 0.025, 0.46), colors[book_index % colors.size()])
		_box(book, Vector3(-0.3, 0.075, 0), Vector3(0.05, 0.12, 0.46), colors[book_index % colors.size()])

func _stain(room: Node3D, position_value: Vector3, size_value: Vector2, color: Color) -> void:
	var stain := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 0.5
	cylinder.bottom_radius = 0.5
	cylinder.height = 0.005
	cylinder.radial_segments = 11
	cylinder.material = _material(color)
	stain.mesh = cylinder
	stain.position = position_value
	stain.scale = Vector3(size_value.x, 1, size_value.y)
	room.add_child(stain)

func _orrery(room: Node3D, position_value: Vector3) -> void:
	var orrery := Node3D.new()
	orrery.name = "AstronomersOrrery"
	orrery.position = position_value
	room.add_child(orrery)
	_prop(orrery, "table_small", Vector3.ZERO, 0, 1.3)
	for ring_index in 3:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.7 + ring_index * 0.13
		torus.outer_radius = 0.74 + ring_index * 0.13
		torus.rings = 24
		torus.ring_segments = 4
		torus.material = _material(BRASS)
		ring.mesh = torus
		ring.position.y = 2.15
		ring.rotation = Vector3(0.45 * ring_index, 0, 0.5 * ring_index)
		orrery.add_child(ring)
	var star := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.24
	sphere.height = 0.48
	sphere.radial_segments = 12
	sphere.rings = 6
	sphere.material = _material(AMBER)
	star.mesh = sphere
	star.position.y = 2.15
	orrery.add_child(star)
	_practical(orrery, Vector3(0, 2.15, 0), MOONLIGHT, 1.4, 5)

func _portrait(room: Node3D, position_value: Vector3, yaw: float, texture_name: String) -> void:
	var portrait := Node3D.new()
	portrait.name = "AncestralPortrait"
	portrait.position = position_value
	portrait.rotation.y = yaw
	room.add_child(portrait)
	_box(portrait, Vector3.ZERO, Vector3(1.95, 2.55, 0.14), TIMBER)
	_box(portrait, Vector3(0, 0, 0.08), Vector3(1.78, 2.38, 0.04), BRASS)
	var painting := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(1.62, 2.2)
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/castle/" + texture_name + ".png")
	material.roughness = 1.0
	plane.material = material
	painting.mesh = plane
	painting.position.z = 0.11
	portrait.add_child(painting)
	_box(portrait, Vector3(0, -1.48, 0), Vector3(0.62, 0.16, 0.06), BRASS)

func _game_board(room: Node3D, position_value: Vector3) -> void:
	_box(room, position_value, Vector3(1.25, 0.05, 1.25), BRASS)
	for row_index in 6:
		for column_index in 6:
			var color: Color = INK if (row_index + column_index) % 2 == 0 else Color("c4b28a")
			_box(room, position_value + Vector3(-0.5 + column_index * 0.2, 0.035, -0.5 + row_index * 0.2), Vector3(0.19, 0.015, 0.19), color)
	for piece_index in 5:
		_prop(room, "coin_stack_small", position_value + Vector3(-0.4 + piece_index * 0.2, 0.05, -0.4), 0, 0.12, false)
		_prop(room, "bottle_C_brown", position_value + Vector3(-0.4 + piece_index * 0.2, 0.05, 0.4), 0, 0.1, false)

func _bones(room: Node3D, position_value: Vector3, yaw: float) -> void:
	var remains := Node3D.new()
	remains.name = "ScatteredRemains"
	remains.position = position_value
	remains.rotation.y = yaw
	room.add_child(remains)
	_prop(remains, "skull", Vector3.ZERO, 0, 0.75, false)
	_prop(remains, "bone_A", Vector3(0.7, 0, 0.3), 0.45, 0.8, false)
	_prop(remains, "bone_B", Vector3(-0.4, 0, 0.6), -0.7, 0.8, false)
	_prop(remains, "bone_C", Vector3(0.4, 0, 1.1), 0.8, 0.8, false)
