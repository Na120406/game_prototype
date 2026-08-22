// Node.js script that builds farm_map_v2.tscn without needing Godot binary.
// Run: node scripts/tools/build_farm_v2.js

const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..', '..');

// Build ground tile data array (50 cols × 37 rows)
function buildGroundTiles() {
  const arr = [];
  for (let y = 0; y < 37; y++) {
    for (let x = 0; x < 50; x++) {
      let ax = 0, ay = 0;
      const isFarmZone = (y >= 17 && y <= 35 && x >= 1 && x <= 36);
      const isPathCol = (x === 17 || x === 18);
      if (isFarmZone && !isPathCol) {
        ay = 2 + (y % 3);
        ax = x % 16;
      } else if (isFarmZone && isPathCol) {
        ay = 1;
        ax = x % 16;
      } else {
        if ((x + y) % 6 === 0) {
          ay = 1;
          ax = x % 16;
        } else {
          ay = 0;
          ax = x % 16;
        }
      }
      arr.push(x, y, encode(0, ax, ay));
    }
  }
  return arr;
}

// Build decor tile data array
function buildDecorTiles() {
  const arr = [];
  for (let y = 0; y < 37; y++) {
    for (let x = 0; x < 50; x++) {
      let ax = 0, ay = 0;
      let place = false;
      if (y === 16 && x >= 1 && x <= 36) {
        ax = x % 6; ay = 2; place = true;
      } else if (y === 36 && x >= 1 && x <= 36) {
        ax = x % 6; ay = 3; place = true;
      } else if (x === 0 && y >= 17 && y <= 35) {
        ax = y % 6; ay = 4; place = true;
      } else if (x === 37 && y >= 17 && y <= 35) {
        ax = y % 6; ay = 5; place = true;
      } else if (y <= 14 && x >= 38 && x <= 46) {
        if ((x + y) % 3 === 0) {
          ax = (x * 2 + y) % 8;
          ay = 5 + (y % 3);
          place = true;
        }
      } else if ([11, 12, 13].includes(y) && [29, 30, 31].includes(x)) {
        if ((x + y) % 2 === 0) {
          ax = (x + y) % 5;
          ay = 8;
          place = true;
        }
      } else if ([10, 11].includes(y) && [33, 34].includes(x)) {
        ax = (x + y) % 4;
        ay = 10;
        place = true;
      }
      if (place) {
        arr.push(x, y, encode(0, ax, ay));
      }
    }
  }
  return arr;
}

function encode(sourceId, ax, ay) {
  return ((sourceId & 0xFFFF) << 16) | ((ax & 0xFFFF)) | ((ay & 0xFFFF) << 8);
}

function intArrToStr(arr) {
  return arr.join(', ');
}

function buildScene() {
  const groundTiles = buildGroundTiles();
  const decorTiles = buildDecorTiles();

  let s = '';
  s += '[gd_scene load_steps=18 format=3 uid="uid://farm_map_v2_01"]\n\n';
  s += '[ext_resource type="PackedScene" uid="uid://6qa4ukueo81u" path="res://scenes/Player.tscn" id="1_player"]\n';
  s += '[ext_resource type="Script" uid="uid://c7lrwu5b7a0n" path="res://scripts/world/world_transition.gd" id="2_trans"]\n';
  s += '[ext_resource type="PackedScene" uid="uid://bxv7h8y2fqk1m" path="res://scenes/world/farm/farm_plot.tscn" id="3_fplot"]\n';
  s += '[ext_resource type="Script" uid="uid://clt6858203i7x" path="res://scripts/world/world_ui_manager.gd" id="4_uimgr"]\n';
  s += '[ext_resource type="Script" uid="uid://csfm82tpxbelg" path="res://scripts/world/farm/farm_manager.gd" id="5_fmgr"]\n';
  s += '[ext_resource type="PackedScene" path="res://scenes/world/farm/crop_visual_manager.tscn" id="6_cropvis"]\n';
  s += '[ext_resource type="PackedScene" path="res://scenes/ui/inventory_ui.tscn" id="7_inv"]\n';
  s += '[ext_resource type="Texture2D" uid="uid://dsp2nmi2lwybi" path="res://Tile Maps/1 Tiles/FieldsTileset.png" id="8_ground_tex"]\n';
  s += '[ext_resource type="Texture2D" uid="uid://dts3t86iptmjl" path="res://Tile Maps/Plants/Plants.png" id="9_decor_tex"]\n\n';

  // Inline ground TileSet
  s += '[sub_resource type="TileSetAtlasSource" id="TSA_ground"]\n';
  s += 'texture = ExtResource("8_ground_tex")\n';
  s += 'texture_region_size = Vector2i(16, 16)\n';
  s += 'use_texture_padding = false\n';
  s += '0:0/0 = 0\n\n';

  s += '[sub_resource type="TileSet" id="TS_ground"]\n';
  s += 'tile_size = Vector2i(16, 16)\n';
  s += 'sources/0 = SubResource("TSA_ground")\n\n';

  // Inline decor TileSet
  s += '[sub_resource type="TileSetAtlasSource" id="TSA_decor"]\n';
  s += 'texture = ExtResource("9_decor_tex")\n';
  s += 'texture_region_size = Vector2i(16, 16)\n';
  s += 'use_texture_padding = false\n';
  s += '0:0/0 = 0\n\n';

  s += '[sub_resource type="TileSet" id="TS_decor"]\n';
  s += 'tile_size = Vector2i(16, 16)\n';
  s += 'sources/0 = SubResource("TSA_decor")\n\n';

  // Shapes
  s += '[sub_resource type="RectangleShape2D" id="RS_wall_h"]\nsize = Vector2(800, 4)\n\n';
  s += '[sub_resource type="RectangleShape2D" id="RS_wall_v"]\nsize = Vector2(4, 600)\n\n';
  s += '[sub_resource type="RectangleShape2D" id="RS_door"]\nsize = Vector2(20, 30)\n\n';
  s += '[sub_resource type="RectangleShape2D" id="RS_trans"]\nsize = Vector2(20, 40)\n\n';
  s += '[sub_resource type="RectangleShape2D" id="RS_house_wall_h"]\nsize = Vector2(160, 6)\n\n';
  s += '[sub_resource type="RectangleShape2D" id="RS_house_wall_v"]\nsize = Vector2(6, 180)\n\n';

  // Root
  s += '[node name="FarmMap" type="Node2D"]\n';
  s += 'script = ExtResource("4_uimgr")\n\n';

  // Ground layer
  s += '[node name="Ground" type="TileMapLayer" parent="."]\n';
  s += 'tile_set = SubResource("TS_ground")\n';
  s += 'format = 2\n';
  s += 'layer_0/tile_data = PackedInt32Array(' + intArrToStr(groundTiles) + ')\n\n';

  // Decor layer
  s += '[node name="Decor" type="TileMapLayer" parent="."]\n';
  s += 'tile_set = SubResource("TS_decor")\n';
  s += 'z_index = 2\n';
  s += 'format = 2\n';
  s += 'layer_0/tile_data = PackedInt32Array(' + intArrToStr(decorTiles) + ')\n\n';

  // Systems
  s += '[node name="CropVisualManager" parent="." instance=ExtResource("6_cropvis")]\nz_index = 5\n\n';
  s += '[node name="FarmPlot" parent="." instance=ExtResource("3_fplot")]\ntile_set = SubResource("TS_ground")\n\n';
  s += '[node name="FarmManager" type="Node2D" parent="."]\nscript = ExtResource("5_fmgr")\n\n';

  // Walls
  s += '[node name="Walls" type="Node2D" parent="."]\n\n';
  s += '[node name="WallTop" type="StaticBody2D" parent="Walls"]\nposition = Vector2(400, 2)\n';
  s += '[node name="CollisionShape2D" type="CollisionShape2D" parent="Walls/WallTop"]\nshape = SubResource("RS_wall_h")\n\n';
  s += '[node name="WallBottom" type="StaticBody2D" parent="Walls"]\nposition = Vector2(400, 598)\n';
  s += '[node name="CollisionShape2D" type="CollisionShape2D" parent="Walls/WallBottom"]\nshape = SubResource("RS_wall_h")\n\n';
  s += '[node name="WallLeft" type="StaticBody2D" parent="Walls"]\nposition = Vector2(2, 300)\n';
  s += '[node name="CollisionShape2D" type="CollisionShape2D" parent="Walls/WallLeft"]\nshape = SubResource("RS_wall_v")\n\n';
  s += '[node name="WallRight" type="StaticBody2D" parent="Walls"]\nposition = Vector2(798, 300)\n';
  s += '[node name="CollisionShape2D" type="CollisionShape2D" parent="Walls/WallRight"]\nshape = SubResource("RS_wall_v")\n\n';

  // House walls
  s += '[node name="HouseWallN" type="StaticBody2D" parent="Walls"]\nposition = Vector2(104, 152)\n';
  s += '[node name="CollisionShape2D" type="CollisionShape2D" parent="Walls/HouseWallN"]\nshape = SubResource("RS_house_wall_h")\n\n';
  s += '[node name="HouseWallS" type="StaticBody2D" parent="Walls"]\nposition = Vector2(104, 248)\n';
  s += '[node name="CollisionShape2D" type="CollisionShape2D" parent="Walls/HouseWallS"]\nshape = SubResource("RS_house_wall_h")\n\n';
  s += '[node name="HouseWallW" type="StaticBody2D" parent="Walls"]\nposition = Vector2(22, 200)\n';
  s += '[node name="CollisionShape2D" type="CollisionShape2D" parent="Walls/HouseWallW"]\nshape = SubResource("RS_house_wall_v")\n\n';
  s += '[node name="HouseWallE" type="StaticBody2D" parent="Walls"]\nposition = Vector2(186, 200)\n';
  s += '[node name="CollisionShape2D" type="CollisionShape2D" parent="Walls/HouseWallE"]\nshape = SubResource("RS_house_wall_v")\n\n';

  // Transitions
  s += '[node name="ToTown" type="Area2D" parent="."]\nposition = Vector2(776, 300)\n';
  s += 'script = ExtResource("2_trans")\nportal_id = "portal_town"\ntarget_scene = "res://scenes/maps/town_map.tscn"\n';
  s += '[node name="CollisionShape2D" type="CollisionShape2D" parent="ToTown"]\nshape = SubResource("RS_trans")\n';
  s += '[node name="Prompt" type="Label" parent="ToTown"]\nanchors_preset = 7\n';
  s += 'offset_left = -10.0\noffset_top = 4.0\noffset_right = 10.0\noffset_bottom = 12.0\n';
  s += 'theme_override_colors/font_color = Color(1, 1, 0.8, 1)\n';
  s += 'theme_override_font_sizes/font_size = 6\ntext = "[E]"\nhorizontal_alignment = 1\n\n';

  s += '[node name="ToHouse" type="Area2D" parent="."]\nposition = Vector2(96, 232)\n';
  s += 'script = ExtResource("2_trans")\nportal_id = "portal_house_entry"\ntarget_scene = "res://scenes/maps/inside_house_map.tscn"\n';
  s += '[node name="CollisionShape2D" type="CollisionShape2D" parent="ToHouse"]\nshape = SubResource("RS_door")\n';
  s += '[node name="Prompt" type="Label" parent="ToHouse"]\nanchors_preset = 7\n';
  s += 'offset_left = -10.0\noffset_top = 4.0\noffset_right = 10.0\noffset_bottom = 12.0\n';
  s += 'theme_override_colors/font_color = Color(1, 1, 0.8, 1)\n';
  s += 'theme_override_font_sizes/font_size = 6\ntext = "[E]"\nhorizontal_alignment = 1\n\n';

  // Player
  s += '[node name="Player" parent="." instance=ExtResource("1_player")]\n';
  s += 'z_index = 10\nposition = Vector2(393, 174)\n\n';
  s += '[node name="Camera2D" type="Camera2D" parent="Player"]\n';
  s += 'limit_left = 0\nlimit_top = 0\nlimit_right = 800\nlimit_bottom = 600\n\n';

  // UI
  s += '[node name="UI" type="CanvasLayer" parent="."]\n';
  s += '[node name="InventoryUI" parent="UI" instance=ExtResource("7_inv")]\n';

  return s;
}

const outDir = path.join(PROJECT_ROOT, 'scenes', 'maps');
if (!fs.existsSync(outDir)) {
  fs.mkdirSync(outDir, { recursive: true });
}
const outPath = path.join(outDir, 'farm_map_v2.tscn');
const content = buildScene();
fs.writeFileSync(outPath, content);
console.log(`Wrote ${outPath} (${content.length} bytes, ${buildGroundTiles().length} ground tiles, ${buildDecorTiles().length} decor tiles)`);
