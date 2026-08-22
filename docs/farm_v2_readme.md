# farm_map_v2 prototype

Replaces `farm_map.tscn` (ColorRect-based) with a tile-based version using
the `FieldsTileset.png` (ground) + `Plants.png` (decor) atlases.

## File map

| File | Purpose |
|---|---|
| `scenes/maps/farm_map_v2.tscn` | The new map scene (run this in-game) |
| `docs/farm_v2_layout.txt` | ASCII visualization of the layout |
| `scripts/tools/build_farm_v2.js` | Node script that generates the scene |
| `scripts/tools/layout_preview.js` | Node script that generates the layout ASCII |
| `scripts/world/farm/crop_visual_manager.gd` | v2: AtlasTexture-based crop sprite renderer |
| `scripts/world/farm/farm_plot.gd` | v2: Sprite2D-based soil visual renderer |

## Atlas references

- Ground (TileMapLayer "Ground"): `res://Tile Maps/1 Tiles/FieldsTileset.png`
  (256×288 → 16×18 grid of 16×16 tiles)
- Decor (TileMapLayer "Decor"): `res://Tile Maps/Plants/Plants.png`
  (672×288 → 42×18 grid of 16×16 tiles)

## Layout (50 cols × 37 rows, each tile = 16×16 px → 800×592 px)

```
farm_map_v2 layout (50 cols × 37 rows, each tile = 16×16 px)
   01234567890123456789012345678901234567890123456789
   00000000000000000000000000000000000000000000000000
00                                        T  T  T    
01  ############                         T  T  T     
02  #HHHHHHHHHH#                           T  T  T   
...
15                                                   
16  ════════════════════════════════════             
17 ║################::##################║            
18 ║################::##################║          T 
...
36  ════════════════════════════════════             
```

(See `docs/farm_v2_layout.txt` for the full preview.)

## Atlas-region placeholders

Crop sprites use region coords from `Plants.png`. These are PROVISIONAL and
point at plant-looking tiles in the lower rows of the atlas. Replace the
`CROP_REGIONS` dictionary in `crop_visual_manager.gd` once a dedicated crop
atlas is available.

## How to test

1. Open Godot, load the project.
2. In `Project → Project Settings → Run → Main Scene`, change to
   `res://scenes/maps/farm_map_v2.tscn`.
3. Run the project (F5).
4. Walk around; verify:
   - Ground tiles render
   - Fences block the player
   - House walls block, door is a portal (`E` prompt)
   - Right-click an empty soil cell → plow → plant seed → water → grow → harvest
   - Crop sprite should appear above the cell, scaling per growth stage

## Known limitations

- `Plants.png` is a decor atlas; crop regions are placeholders. Visuals will be
  wrong until a dedicated crop atlas is added.
- Tree/decor positions are placeholder; visual tuning needed.
- House has 4 walls + door, but no roof/door sprite yet (would need a separate
  TileMapLayer or Sprite2D).
- The old `farm_map.tscn` and `farm_tileset.tres` are untouched — leave them
  in place as a fallback until v2 is verified.

## Rebuilding the scene

After changing layout logic in `scripts/tools/build_farm_v2.js`:

```bash
node scripts/tools/build_farm_v2.js
node scripts/tools/layout_preview.js
```
