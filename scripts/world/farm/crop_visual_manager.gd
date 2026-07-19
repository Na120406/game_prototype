extends Node2D

const CELL_SIZE: Vector2 = Vector2(8, 8)
const FARM_ZONE := Rect2(24, 274, 592, 302)
const SEED_COLOR := Color(0.35, 0.75, 0.3, 1.0)

var _sprites: Dictionary = {}  # cell_key -> Sprite2D
var _farm_manager: Node = null
var _plot: Node = null
var _update_timer: float = 0.0
var _last_day: int = -1
var _plot_world_offset: Vector2 = Vector2.ZERO
var _white_tex: ImageTexture = null

func _ready() -> void:
	add_to_group("crop_visual_manager")
	_white_tex = _make_white_texture()
	# Wait one frame so FarmManager and FarmPlot have entered the scene tree
	call_deferred("_initialize")
	# Also try again on next physics frame in case deferred was too early
	await get_tree().physics_frame
	if _farm_manager == null:
		_initialize()

func _initialize() -> void:
	if _farm_manager == null:
		_farm_manager = get_tree().get_first_node_in_group("farm_manager")
	if _plot == null:
		_plot = get_tree().get_first_node_in_group("farm_plot")
	# farm_plot._cell_to_world returns absolute world coords = FARM_ZONE.position + cell*16.
	# We use the same formula directly, so no offset needed.
	_plot_world_offset = Vector2.ZERO
	if _farm_manager == null:
		push_warning("[CropVisual] No FarmManager found!")
		return
	# Avoid double-connecting
	if not _farm_manager.crop_planted.is_connected(_on_crop_planted):
		_farm_manager.crop_planted.connect(_on_crop_planted)
	if not _farm_manager.crop_growed.is_connected(_on_crop_growed):
		_farm_manager.crop_growed.connect(_on_crop_growed)
	if not _farm_manager.crop_harvested.is_connected(_on_crop_harvested):
		_farm_manager.crop_harvested.connect(_on_crop_harvested)
	print("[CropVisual] Ready, plot_offset=", _plot_world_offset, " farm_mgr=", _farm_manager != null)
	# Rebuild on ready so persisted cells show immediately after scene load
	_refresh_all_visuals()
	if not GameState.day_changed.is_connected(_on_day_changed):
		GameState.day_changed.connect(_on_day_changed)

func _make_white_texture() -> ImageTexture:
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)

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
	print("[CropVisual] crop_planted signal received for cell ", cell)
	if _farm_manager == null:
		push_warning("[CropVisual] crop_planted but no _farm_manager!")
		return
	var cell_data: Dictionary = _farm_manager.get_cell_data(cell)
	print("[CropVisual] cell_data: ", cell_data)
	_spawn_sprite(cell, cell_data)

func _on_crop_growed(_stage: int) -> void:
	pass

func _on_crop_harvested(cell: Vector2i, _item_id: String) -> void:
	_remove_sprite(cell)

func on_farm_data_loaded() -> void:
	# Called by SceneManager after deserialize so cells are visible immediately.
	_refresh_all_visuals()

func _on_day_changed(_new_day: int) -> void:
	# After sleep, crop stages & watered flags may have changed in farm_manager
	_refresh_visuals_for_visible_cells()

func _spawn_sprite(cell: Vector2i, data: Dictionary) -> void:
	var cell_key := _cell_key(cell)

	if _sprites.has(cell_key):
		_update_sprite_body(cell_key, cell, data)
		return

	var sprite := Sprite2D.new()
	sprite.name = "Crop_" + cell_key
	sprite.texture = _white_tex
	sprite.modulate = SEED_COLOR
	sprite.centered = true
	# Use parent CropVisualManager's z (5). Player has z=10 so player always on top.
	sprite.z_index = 0
	sprite.z_as_relative = true
	# Set a guaranteed-visible initial transform BEFORE adding to tree so
	# we can be sure the sprite is on screen even if update_body fails.
	# Size = SEEDED scale (tiny green dot).
	sprite.position = FARM_ZONE.position + Vector2(8, 8)  # cell (0,0) center
	sprite.scale = Vector2(4.2, 4.2)

	# Parent the sprite directly under CropVisualManager (root-level Node2D with z=100).
	add_child(sprite)
	_sprites[cell_key] = sprite
	# Update transform AFTER add_child so transform is applied on a node in tree.
	_update_sprite_body(cell_key, cell, data)
	var actual: Sprite2D = _sprites[cell_key]
	print("[CropVisual] Spawned cell=", cell,
		" state=", data.get("state", 0),
		" plot_offset=", _plot_world_offset,
		" center=", actual.position,
		" scale=", actual.scale,
		" visible=", actual.visible,
		" modulate=", actual.modulate,
		" tex_size=", actual.texture.get_size() if actual.texture else "null",
		" parent=", actual.get_parent().name,
		" z_idx=", actual.z_index,
		" z_rel=", actual.z_as_relative)

func _update_sprite(cell: Vector2i, data: Dictionary) -> void:
	var cell_key := _cell_key(cell)
	if not _sprites.has(cell_key):
		if data.get("state", 0) >= 2:
			_spawn_sprite(cell, data)
		return
	_update_sprite_body(cell_key, cell, data)

func _update_sprite_body(cell_key: String, cell: Vector2i, data: Dictionary) -> void:
	if not _sprites.has(cell_key):
		return
	var sprite: Sprite2D = _sprites[cell_key]
	var state: int = data.get("state", 0)
	var crop_type_val: int = data.get("type", 0)
	var watered: bool = data.get("watered", false)

	var color: Color = _get_state_color(state, crop_type_val, watered)
	sprite.modulate = color

	var scale_val: float
	match state:
		2: scale_val = 0.35  # SEEDED — tiny green dot (just placed seed)
		3: scale_val = 0.6   # SPROUTED — small sprout
		4: scale_val = 0.9   # GROWING — bigger plant
		5: scale_val = 1.3   # MATURE — full plant, fits inside cell
		6: scale_val = 0.7   # WILTED — droops back
		_: scale_val = 0.0

	# Square stays inside the 16x16 cell, centered.
	var display_size: float = 12.0 * scale_val
	sprite.scale = Vector2(display_size, display_size)
	var cell_top_left: Vector2 = _plot_world_offset + FARM_ZONE.position + Vector2(cell) * Vector2(16, 16)
	var cell_center: Vector2 = cell_top_left + Vector2(16, 16) * 0.5
	sprite.position = cell_center
	sprite.visible = scale_val > 0.0
	print("[CropVisual] sprite ", cell_key, " state=", state, " color=", sprite.modulate, " pos=", sprite.position, " scale=", sprite.scale, " visible=", sprite.visible)

func _get_state_color(state: int, crop_type_val: int, watered: bool) -> Color:
	match crop_type_val:
		1: return _wheat_color(state, watered)
		2: return _corn_color(state, watered)
		3: return _tomato_color(state, watered)
		4: return _potato_color(state, watered)
		5: return _turnip_color(state, watered)
		6: return _mystery_color(state, watered)
	return SEED_COLOR

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
	for s in _sprites.values():
		if is_instance_valid(s):
			s.queue_free()
	_sprites.clear()
	_refresh_all_visuals()
