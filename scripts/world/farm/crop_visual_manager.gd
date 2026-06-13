extends Node2D

const CELL_SIZE: Vector2 = Vector2(16, 16)
const FARM_ZONE := Rect2(20, 270, 600, 310)

var _sprites: Dictionary = {}  # cell_key -> Sprite2D
var _farm_manager: Node = null
var _plot: Node = null
var _update_timer: float = 0.0
var _last_day: int = -1
var _plot_world_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	add_to_group("crop_visual_manager")
	_farm_manager = get_tree().get_first_node_in_group("farm_manager")
	_plot = get_tree().get_first_node_in_group("farm_plot")
	if _farm_manager == null:
		push_warning("[CropVisual] No FarmManager found!")
	else:
		_farm_manager.crop_planted.connect(_on_crop_planted)
		_farm_manager.crop_growed.connect(_on_crop_growed)
		_farm_manager.crop_harvested.connect(_on_crop_harvested)
	print("[CropVisual] Ready.")

func _process(delta: float) -> void:
	_update_timer += delta
	if _update_timer < 0.5:
		return
	_update_timer = 0.0

	var current_day := GameState.current_day
	if current_day != _last_day:
		_last_day = current_day
		_refresh_all_visuals()

	_refresh_visuals_for_visible_cells()

func _refresh_all_visuals() -> void:
	if _farm_manager == null:
		return
	if not _farm_manager.has_method("serialize"):
		return
	var data: Dictionary = _farm_manager.serialize()
	if not data.has("cells"):
		return
	for entry: Dictionary in data["cells"]:
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		var cell_data: Dictionary = entry["data"]
		_spawn_sprite(cell, cell_data)

func _refresh_visuals_for_visible_cells() -> void:
	if _farm_manager == null:
		return
	if not _farm_manager.has_method("serialize"):
		return
	var data: Dictionary = _farm_manager.serialize()
	if not data.has("cells"):
		return
	for entry: Dictionary in data["cells"]:
		var cell := Vector2i(int(entry["x"]), int(entry["y"]))
		var cell_data: Dictionary = entry["data"]
		_update_sprite(cell, cell_data)

func _on_crop_planted(cell: Vector2i) -> void:
	if _farm_manager == null:
		return
	var cell_data: Dictionary = _farm_manager.get_cell_data(cell)
	_spawn_sprite(cell, cell_data)

func _on_crop_growed(_stage: int) -> void:
	pass

func _on_crop_harvested(cell: Vector2i, _item_id: String) -> void:
	_remove_sprite(cell)

func _spawn_sprite(cell: Vector2i, data: Dictionary) -> void:
	var cell_key := _cell_key(cell)

	if _sprites.has(cell_key):
		_update_sprite_body(_sprites[cell_key], data)
		return

	var sprite := Sprite2D.new()
	sprite.name = "Crop_" + cell_key
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var plot := _plot as TileMapLayer
	var world_pos: Vector2
	if plot != null:
		world_pos = plot.map_to_local(cell) + CELL_SIZE * 0.5
	else:
		world_pos = Vector2(cell) * CELL_SIZE + CELL_SIZE * 0.5

	sprite.position = world_pos
	sprite.z_index = 5

	_update_sprite_body(sprite, data)
	add_child(sprite)
	_sprites[cell_key] = sprite

func _update_sprite(cell: Vector2i, data: Dictionary) -> void:
	var cell_key := _cell_key(cell)
	if not _sprites.has(cell_key):
		if data.get("state", 0) >= 2:
			_spawn_sprite(cell, data)
		return
	_update_sprite_body(_sprites[cell_key], data)

func _update_sprite_body(sprite: Sprite2D, data: Dictionary) -> void:
	var state: int = data.get("state", 0)
	var crop_type_val: int = data.get("type", 0)
	var watered: bool = data.get("watered", false)

	# Determine color based on crop type and state
	var color: Color
	match crop_type_val:
		1: color = _wheat_color(state, watered)   # WHEAT
		2: color = _corn_color(state, watered)    # CORN
		3: color = _tomato_color(state, watered)  # TOMATO
		4: color = _potato_color(state, watered) # POTATO
		5: color = _turnip_color(state, watered)  # TURNIP
		6: color = _mystery_color(state, watered) # MYSTERY
		_: color = Color.GRAY

	sprite.modulate = color

	# Scale based on growth stage
	var scale_val: float
	match state:
		2: scale_val = 0.3   # SEEDED
		3: scale_val = 0.55  # SPROUTED
		4: scale_val = 0.8   # GROWING
		5: scale_val = 1.0   # MATURE
		6: scale_val = 0.5   # WILTED
		_: scale_val = 0.0

	sprite.scale = Vector2.ONE * scale_val
	sprite.visible = scale_val > 0.0

func _wheat_color(state: int, _watered: bool) -> Color:
	match state:
		2: return Color(0.6, 0.5, 0.2, 1.0)
		3: return Color(0.5, 0.7, 0.2, 1.0)
		4: return Color(0.7, 0.8, 0.3, 1.0)
		5: return Color(1.0, 0.85, 0.3, 1.0)
		6: return Color(0.5, 0.3, 0.1, 1.0)
	return Color(0.6, 0.5, 0.2, 1.0)

func _corn_color(state: int, watered: bool) -> Color:
	match state:
		2: return Color(0.5, 0.6, 0.2, 1.0)
		3: return Color(0.4, 0.7, 0.25, 1.0)
		4: return Color(0.5, 0.8, 0.3, 1.0)
		5: return Color(0.9, 0.75, 0.2, 1.0)
		6: return Color(0.5, 0.3, 0.1, 1.0)
	return Color(0.5, 0.6, 0.2, 1.0)

func _tomato_color(state: int, watered: bool) -> Color:
	match state:
		2: return Color(0.4, 0.6, 0.2, 1.0)
		3: return Color(0.4, 0.7, 0.3, 1.0)
		4: return Color(0.5, 0.8, 0.35, 1.0)
		5: return Color(0.85, 0.15, 0.1, 1.0)
		6: return Color(0.4, 0.2, 0.1, 1.0)
	return Color(0.4, 0.6, 0.2, 1.0)

func _potato_color(state: int, watered: bool) -> Color:
	match state:
		2: return Color(0.5, 0.6, 0.2, 1.0)
		3: return Color(0.45, 0.65, 0.3, 1.0)
		4: return Color(0.55, 0.7, 0.35, 1.0)
		5: return Color(0.75, 0.55, 0.3, 1.0)
		6: return Color(0.4, 0.25, 0.1, 1.0)
	return Color(0.5, 0.6, 0.2, 1.0)

func _turnip_color(state: int, watered: bool) -> Color:
	match state:
		2: return Color(0.5, 0.7, 0.3, 1.0)
		3: return Color(0.5, 0.75, 0.35, 1.0)
		4: return Color(0.55, 0.8, 0.4, 1.0)
		5: return Color(0.75, 0.9, 0.5, 1.0)
		6: return Color(0.4, 0.3, 0.2, 1.0)
	return Color(0.5, 0.7, 0.3, 1.0)

func _mystery_color(state: int, watered: bool) -> Color:
	match state:
		2: return Color(0.5, 0.3, 0.7, 1.0)
		3: return Color(0.6, 0.4, 0.8, 1.0)
		4: return Color(0.7, 0.5, 0.9, 1.0)
		5: return Color(0.9, 0.3, 0.8, 1.0)
		6: return Color(0.3, 0.2, 0.4, 1.0)
	return Color(0.5, 0.3, 0.7, 1.0)

func _remove_sprite(cell: Vector2i) -> void:
	var cell_key := _cell_key(cell)
	if _sprites.has(cell_key):
		_sprites[cell_key].queue_free()
		_sprites.erase(cell_key)

func _cell_key(cell: Vector2i) -> String:
	return "%d,%d" % [cell.x, cell.y]

func rebuild_all() -> void:
	for s: Sprite2D in _sprites.values():
		s.queue_free()
	_sprites.clear()
	_refresh_all_visuals()
