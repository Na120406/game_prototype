extends SceneTree

# Builds farm_map_v2.tscn using inlined TileSet resources pointing at
# FieldsTileset.png + Plants.png.
#
# Run: godot --headless --path . --script scripts/tools/build_farm_v2.gd

const GROUND_TEX := "res://tilesets/Ground/FieldsTileset.png"
const DECOR_TEX  := "res://tilesets/Plants/Plants.png"

func _init() -> void:
	_build()
	quit()

func _build() -> void:
	var scene := ""

	# Resources
	scene += "[gd_scene load_steps=18 format=3 uid=\"uid://farm_map_v2_01\"]\n\n"
	scene += "[ext_resource type=\"PackedScene\" uid=\"uid://6qa4ukueo81u\" path=\"res://scenes/Player.tscn\" id=\"1_player\"]\n"
	scene += "[ext_resource type=\"Script\" uid=\"uid://c7lrwu5b7a0n\" path=\"res://scripts/world/world_transition.gd\" id=\"2_trans\"]\n"
	scene += "[ext_resource type=\"PackedScene\" uid=\"uid://bxv7h8y2fqk1m\" path=\"res://scenes/world/farm/farm_plot.tscn\" id=\"3_fplot\"]\n"
	scene += "[ext_resource type=\"Script\" uid=\"uid://clt6858203i7x\" path=\"res://scripts/world/world_ui_manager.gd\" id=\"4_uimgr\"]\n"
	scene += "[ext_resource type=\"Script\" uid=\"uid://csfm82tpxbelg\" path=\"res://scripts/world/farm/farm_manager.gd\" id=\"5_fmgr\"]\n"
	scene += "[ext_resource type=\"PackedScene\" path=\"res://scenes/world/farm/crop_visual_manager.tscn\" id=\"6_cropvis\"]\n"
	scene += "[ext_resource type=\"PackedScene\" path=\"res://scenes/ui/inventory_ui.tscn\" id=\"7_inv\"]\n"
	scene += "[ext_resource type=\"Texture2D\" uid=\"uid://o0gkjytys4i4\" path=\"res://tilesets/Ground/FieldsTileset.png\" id=\"8_ground_tex\"]\n"
	scene += "[ext_resource type=\"Texture2D\" uid=\"uid://dm4yxqb4flasm\" path=\"res://tilesets/Plants/Plants.png\" id=\"9_decor_tex\"]\n\n"

	# Inline ground TileSet
	scene += "[sub_resource type=\"TileSetAtlasSource\" id=\"TSA_ground\"]\n"
	scene += "texture = ExtResource(\"8_ground_tex\")\n"
	scene += "texture_region_size = Vector2i(16, 16)\n"
	scene += "use_texture_padding = false\n"
	scene += "0:0/0 = 0\n"
	scene += "0:0/0/custom_data_0 = 0\n"

	scene += "[sub_resource type=\"TileSet\" id=\"TS_ground\"]\n"
	scene += "tile_size = Vector2i(16, 16)\n"
	scene += "sources/0 = SubResource(\"TSA_ground\")\n\n"

	# Inline decor TileSet
	scene += "[sub_resource type=\"TileSetAtlasSource\" id=\"TSA_decor\"]\n"
	scene += "texture = ExtResource(\"9_decor_tex\")\n"
	scene += "texture_region_size = Vector2i(16, 16)\n"
	scene += "use_texture_padding = false\n"
	scene += "0:0/0 = 0\n\n"

	scene += "[sub_resource type=\"TileSet\" id=\"TS_decor\"]\n"
	scene += "tile_size = Vector2i(16, 16)\n"
	scene += "sources/0 = SubResource(\"TSA_decor\")\n\n"

	# Shapes
	scene += "[sub_resource type=\"RectangleShape2D\" id=\"RS_wall_h\"]\nsize = Vector2(800, 4)\n\n"
	scene += "[sub_resource type=\"RectangleShape2D\" id=\"RS_wall_v\"]\nsize = Vector2(4, 600)\n\n"
	scene += "[sub_resource type=\"RectangleShape2D\" id=\"RS_door\"]\nsize = Vector2(20, 30)\n\n"
	scene += "[sub_resource type=\"RectangleShape2D\" id=\"RS_trans\"]\nsize = Vector2(20, 40)\n\n"
	scene += "[sub_resource type=\"RectangleShape2D\" id=\"RS_house_wall_h\"]\nsize = Vector2(160, 6)\n\n"
	scene += "[sub_resource type=\"RectangleShape2D\" id=\"RS_house_wall_v\"]\nsize = Vector2(6, 180)\n\n"

	# Root
	scene += "[node name=\"FarmMap\" type=\"Node2D\"]\n"
	scene += "script = ExtResource(\"4_uimgr\")\n\n"

	# Ground layer
	scene += "[node name=\"Ground\" type=\"TileMapLayer\" parent=\".\"]\n"
	scene += "tile_set = SubResource(\"TS_ground\")\n"
	scene += "format = 2\n"
	scene += "layer_0/tile_data = PackedInt32Array(" + _int_array_to_str(_build_ground_tiles()) + ")\n\n"

	# Decor layer
	scene += "[node name=\"Decor\" type=\"TileMapLayer\" parent=\".\"]\n"
	scene += "tile_set = SubResource(\"TS_decor\")\n"
	scene += "z_index = 2\n"
	scene += "format = 2\n"
	scene += "layer_0/tile_data = PackedInt32Array(" + _int_array_to_str(_build_decor_tiles()) + ")\n\n"

	# Systems
	scene += "[node name=\"CropVisualManager\" parent=\".\" instance=ExtResource(\"6_cropvis\")]\nz_index = 5\n\n"
	scene += "[node name=\"FarmPlot\" parent=\".\" instance=ExtResource(\"3_fplot\")]\ntile_set = SubResource(\"TS_ground\")\n\n"
	scene += "[node name=\"FarmManager\" type=\"Node2D\" parent=\".\"]\nscript = ExtResource(\"5_fmgr\")\n\n"

	# Walls
	scene += "[node name=\"Walls\" type=\"Node2D\" parent=\".\"]\n\n"
	scene += "[node name=\"WallTop\" type=\"StaticBody2D\" parent=\"Walls\"]\nposition = Vector2(400, 2)\n"
	scene += "[node name=\"CollisionShape2D\" type=\"CollisionShape2D\" parent=\"Walls/WallTop\"]\nshape = SubResource(\"RS_wall_h\")\n\n"
	scene += "[node name=\"WallBottom\" type=\"StaticBody2D\" parent=\"Walls\"]\nposition = Vector2(400, 598)\n"
	scene += "[node name=\"CollisionShape2D\" type=\"CollisionShape2D\" parent=\"Walls/WallBottom\"]\nshape = SubResource(\"RS_wall_h\")\n\n"
	scene += "[node name=\"WallLeft\" type=\"StaticBody2D\" parent=\"Walls\"]\nposition = Vector2(2, 300)\n"
	scene += "[node name=\"CollisionShape2D\" type=\"CollisionShape2D\" parent=\"Walls/WallLeft\"]\nshape = SubResource(\"RS_wall_v\")\n\n"
	scene += "[node name=\"WallRight\" type=\"StaticBody2D\" parent=\"Walls\"]\nposition = Vector2(798, 300)\n"
	scene += "[node name=\"CollisionShape2D\" type=\"CollisionShape2D\" parent=\"Walls/WallRight\"]\nshape = SubResource(\"RS_wall_v\")\n\n"

	# House outer walls (block player from walking into walls)
	scene += "[node name=\"HouseWallN\" type=\"StaticBody2D\" parent=\"Walls\"]\nposition = Vector2(104, 152)\n"
	scene += "[node name=\"CollisionShape2D\" type=\"CollisionShape2D\" parent=\"Walls/HouseWallN\"]\nshape = SubResource(\"RS_house_wall_h\")\n\n"
	scene += "[node name=\"HouseWallS\" type=\"StaticBody2D\" parent=\"Walls\"]\nposition = Vector2(104, 248)\n"
	scene += "[node name=\"CollisionShape2D\" type=\"CollisionShape2D\" parent=\"Walls/HouseWallS\"]\nshape = SubResource(\"RS_house_wall_h\")\n\n"
	scene += "[node name=\"HouseWallW\" type=\"StaticBody2D\" parent=\"Walls\"]\nposition = Vector2(22, 200)\n"
	scene += "[node name=\"CollisionShape2D\" type=\"CollisionShape2D\" parent=\"Walls/HouseWallW\"]\nshape = SubResource(\"RS_house_wall_v\")\n\n"
	scene += "[node name=\"HouseWallE\" type=\"StaticBody2D\" parent=\"Walls\"]\nposition = Vector2(186, 200)\n"
	scene += "[node name=\"CollisionShape2D\" type=\"CollisionShape2D\" parent=\"Walls/HouseWallE\"]\nshape = SubResource(\"RS_house_wall_v\")\n\n"

	# Transitions
	scene += "[node name=\"ToTown\" type=\"Area2D\" parent=\".\"]\nposition = Vector2(776, 300)\n"
	scene += "script = ExtResource(\"2_trans\")\nportal_id = \"portal_town\"\ntarget_scene = \"res://scenes/maps/town_map.tscn\"\n"
	scene += "[node name=\"CollisionShape2D\" type=\"CollisionShape2D\" parent=\"ToTown\"]\nshape = SubResource(\"RS_trans\")\n"
	scene += "[node name=\"Prompt\" type=\"Label\" parent=\"ToTown\"]\nanchors_preset = 7\n"
	scene += "offset_left = -10.0\noffset_top = 4.0\noffset_right = 10.0\noffset_bottom = 12.0\n"
	scene += "theme_override_colors/font_color = Color(1, 1, 0.8, 1)\n"
	scene += "theme_override_font_sizes/font_size = 6\ntext = \"[E]\"\nhorizontal_alignment = 1\n\n"

	scene += "[node name=\"ToHouse\" type=\"Area2D\" parent=\".\"]\nposition = Vector2(96, 232)\n"
	scene += "script = ExtResource(\"2_trans\")\nportal_id = \"portal_house_entry\"\ntarget_scene = \"res://scenes/maps/inside_house_map.tscn\"\n"
	scene += "[node name=\"CollisionShape2D\" type=\"CollisionShape2D\" parent=\"ToHouse\"]\nshape = SubResource(\"RS_door\")\n"
	scene += "[node name=\"Prompt\" type=\"Label\" parent=\"ToHouse\"]\nanchors_preset = 7\n"
	scene += "offset_left = -10.0\noffset_top = 4.0\noffset_right = 10.0\noffset_bottom = 12.0\n"
	scene += "theme_override_colors/font_color = Color(1, 1, 0.8, 1)\n"
	scene += "theme_override_font_sizes/font_size = 6\ntext = \"[E]\"\nhorizontal_alignment = 1\n\n"

	# Player
	scene += "[node name=\"Player\" parent=\".\" instance=ExtResource(\"1_player\")]\n"
	scene += "z_index = 10\nposition = Vector2(393, 174)\n\n"
	scene += "[node name=\"Camera2D\" type=\"Camera2D\" parent=\"Player\"]\n"
	scene += "limit_left = 0\nlimit_top = 0\nlimit_right = 800\nlimit_bottom = 600\n\n"

	# UI
	scene += "[node name=\"UI\" type=\"CanvasLayer\" parent=\".\"]\n"
	scene += "[node name=\"InventoryUI\" parent=\"UI\" instance=ExtResource(\"7_inv\")]\n"

	var f := FileAccess.open("res://scenes/maps/farm_map_v2.tscn", FileAccess.WRITE)
	f.store_string(scene)
	f.close()
	print("Wrote scenes/maps/farm_map_v2.tscn (%d bytes)" % scene.length())

# ---------------------------------------------------------------------------
# Ground layer: 50 cols × 37 rows of 16x16 tiles
# Atlas mapping (FieldsTileset.png 16x18 grid):
#   row 0-1 = grass (variants) — atlas (x%16, 0 or 1)
#   row 2-4 = dirt (variants)   — atlas (x%16, 2..4)
# Layout zones:
#   - House zone: rows 0-15, cols 0-13 (grass with house entrance at bottom)
#   - Yard zone: rows 0-15, cols 14-49 (grass with scattered dirt patches)
#   - Farm zone: rows 17-35, cols 1-36 (dirt, except col 17-18 = path grass)
#   - Margins: row 16 (fence), row 36 (fence), col 0, col 49
# ---------------------------------------------------------------------------
func _build_ground_tiles() -> PackedInt32Array:
	var arr := PackedInt32Array()
	for y in 37:
		for x in 50:
			var ax := 0
			var ay := 0
			var is_farm_zone := (y >= 17 and y <= 35 and x >= 1 and x <= 36)
			var is_path_col := (x == 17 or x == 18)
			if is_farm_zone and not is_path_col:
				# Dirt variants: cycle through rows 2, 3, 4
				ay = 2 + (y % 3)
				ax = x % 16
			elif is_farm_zone and is_path_col:
				# Path: use slightly different grass to indicate a walkway
				ay = 1
				ax = x % 16
			else:
				# Grass base everywhere else
				if (x + y) % 6 == 0:
					ay = 1
					ax = x % 16
				else:
					ay = 0
					ax = x % 16
			arr.append(x)
			arr.append(y)
			arr.append(_encode(0, ax, ay))
	return arr

# ---------------------------------------------------------------------------
# Decor layer. Plants.png 42x18 grid.
# Atlas mapping guesses (will refine by visual inspection):
#   - Fence variants: row 2 (top fence), row 3 (bottom fence)
#   - Trees: rows 5-7 (top of trees)
#   - Stones: rows 8-9
#   - Hay bales: row 10
#   - Bushes: row 11
#   - Plants/crops: rows 12-17
# This is placeholder; we will adjust by reading atlas more carefully.
# ---------------------------------------------------------------------------
func _build_decor_tiles() -> PackedInt32Array:
	var arr := PackedInt32Array()
	for y in 37:
		for x in 50:
			var ax := 0
			var ay := 0
			var place := false

			# Fence top (row 16)
			if y == 16 and x >= 1 and x <= 36:
				ax = x % 6
				ay = 2
				place = true
			# Fence bottom (row 36)
			elif y == 36 and x >= 1 and x <= 36:
				ax = x % 6
				ay = 3
				place = true
			# Fence left (col 0, rows 17-35)
			elif x == 0 and y >= 17 and y <= 35:
				ax = y % 6
				ay = 4
				place = true
			# Fence right (col 37, rows 17-35)
			elif x == 37 and y >= 17 and y <= 35:
				ax = y % 6
				ay = 5
				place = true
			# Trees in yard zone (right of house, above farm)
			elif y <= 14 and x >= 38 and x <= 46:
				if (x + y) % 3 == 0:
					ax = (x * 2 + y) % 8
					ay = 5 + (y % 3)
					place = true
			# Stones in yard zone
			elif y in [11, 12, 13] and x in [29, 30, 31]:
				if (x + y) % 2 == 0:
					ax = (x + y) % 5
					ay = 8
					place = true
			# Hay bale near yard
			elif y in [10, 11] and x in [33, 34]:
				ax = (x + y) % 4
				ay = 10
				place = true
			# House roof - skip, handled by tile variants separately

			if place:
				arr.append(x)
				arr.append(y)
				arr.append(_encode(0, ax, ay))
	return arr

func _encode(source_id: int, ax: int, ay: int) -> int:
	return (source_id << 16) | (ax & 0xFFFF) | ((ay & 0xFFFF) << 8)

func _int_array_to_str(arr: PackedInt32Array) -> String:
	var parts := []
	for v in arr:
		parts.append(str(v))
	return ", ".join(parts)
