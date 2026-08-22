extends Node

# Builds FarmGround TileSet + Decor TileSet from FieldsTileset.png + Plants.png.
# Run via /root/ATLAS_BOOT autoload, OR call _build_all() from any node.
# Saves resources to disk so other scenes can reference them via ExtResource.

const GROUND_TEX_PATH := "res://Tile Maps/1 Tiles/FieldsTileset.png"
const DECOR_TEX_PATH  := "res://Tile Maps/Plants/Plants.png"
const GROUND_TS_PATH  := "res://resources/tilesets/farm_ground_tileset.tres"
const DECOR_TS_PATH   := "res://resources/tilesets/decor_tileset.tres"

const TILE_SIZE := Vector2i(16, 16)

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	# Auto-build only when the boot scene is opened directly.
	if get_tree().current_scene.scene_file_path.ends_with("atlas_boot.tscn"):
		_build_all()
		get_tree().quit()

func _build_all() -> void:
	DirAccess.make_dir_recursive_absolute("res://resources/tilesets")
	_build_ground_tileset()
	_build_decor_tileset()
	print("[ATLAS_BOOT] All TileSets built and saved.")

# ---------------------------------------------------------------------------
# Ground: FieldsTileset.png (16x18 grid of 16x16 tiles).
# atlas_coords is GRID coords (not pixel coords).
# ---------------------------------------------------------------------------
func _build_ground_tileset() -> void:
	var tex := load(GROUND_TEX_PATH) as Texture2D
	if tex == null:
		push_error("Cannot load %s" % GROUND_TEX_PATH)
		return

	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE
	ts.name = "FarmGround"

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = TILE_SIZE
	src.use_texture_padding = false
	ts.add_source(src)

	# Custom-data layer for soil_state (matches farm_manager constants)
	var cd_soil := TileSetCustomDataLayer.new()
	cd_soil.name = "soil_state"
	ts.add_custom_data_layer(cd_soil)
	var cd_crop := TileSetCustomDataLayer.new()
	cd_crop.name = "crop_stage"
	ts.add_custom_data_layer(cd_crop)

	# Create every tile in the grid
	for y in 18:
		for x in 16:
			src.create_tile(Vector2i(x, y))

	# Mark soil_state custom data:
	# Row 0 = grass (soil_state=0)
	# Row 1 = grass/dirt corners (soil_state=0)
	# Row 2-4 = dirt variants (soil_state=1)
	for x in 16:
		_set_custom_data(src, Vector2i(x, 0), "soil_state", 0)
	for x in 16:
		_set_custom_data(src, Vector2i(x, 1), "soil_state", 0)
	for y in [2, 3, 4]:
		for x in 16:
			_set_custom_data(src, Vector2i(x, y), "soil_state", 1)

	var save_err := ResourceSaver.save(ts, GROUND_TS_PATH)
	if save_err != OK:
		push_error("Failed to save ground tileset: %d" % save_err)
	else:
		print("[ATLAS_BOOT] Saved %s" % GROUND_TS_PATH)

# ---------------------------------------------------------------------------
# Decor: Plants.png (42x18 grid of 16x16 tiles).
# Provides a physics layer so fences/trees can block the player.
# ---------------------------------------------------------------------------
func _build_decor_tileset() -> void:
	var tex := load(DECOR_TEX_PATH) as Texture2D
	if tex == null:
		push_error("Cannot load %s" % DECOR_TEX_PATH)
		return

	var ts := TileSet.new()
	ts.tile_size = TILE_SIZE
	ts.name = "Decor"

	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = TILE_SIZE
	src.use_texture_padding = false
	ts.add_source(src)

	# Physics layer for fences/trees
	var phys := TileSetPhysicsLayer.new()
	phys.collision_layer = 2
	phys.collision_mask = 2
	ts.add_physics_layer(phys)

	# Custom-data layer for tile kind (0=visual, 1=fence, 2=tree, 3=house, 4=well)
	var cd := TileSetCustomDataLayer.new()
	cd.name = "decor_kind"
	ts.add_custom_data_layer(cd)

	for y in 18:
		for x in 42:
			src.create_tile(Vector2i(x, y))

	var save_err := ResourceSaver.save(ts, DECOR_TS_PATH)
	if save_err != OK:
		push_error("Failed to save decor tileset: %d" % save_err)
	else:
		print("[ATLAS_BOOT] Saved %s" % DECOR_TS_PATH)

func _set_custom_data(src: TileSetAtlasSource, atlas_pos: Vector2i, key: String, value: Variant) -> void:
	var td := src.get_tile_data(atlas_pos, 0)
	if td == null:
		return
	td.set_custom_data(key, value)
