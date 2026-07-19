# UID Fix Script for Godot Editor

> **IMPORTANT:** UID regeneration MUST be done manually in Godot Editor.
> Godot does not allow external scripts to modify UIDs for safety reasons.

## Files with Invalid/Placeholder UIDs

The following files need UID regeneration:

| File | Current UID | Type |
|------|-------------|------|
| `scenes/ui/inventory_ui.tscn` | `uid://inv_ui_01` | Placeholder |
| `scenes/ui/hotbar.tscn` | `uid://hotbar_scene` | Placeholder |
| `scenes/ui/tooltip_panel.tscn` | `uid://tooltip_panel_scene` | Placeholder |
| `scenes/ui/dialogue_ui.tscn` | `uid://dlg_ui_fixed` | Non-standard |
| `scenes/world/bed.tscn` | `uid://cbed01` | Non-standard |
| `scenes/ui/shop_ui.tscn` | `uid://smg6d4a464ac` | Non-standard |
| `scenes/world/items/apple.tscn` | `uid://apple_item_scene` | Placeholder |
| `scenes/npc/shopkeeper.tscn` | `uid://shopkeeper_scene` | Placeholder |
| `scenes/maps/inside_shop_map.tscn` | `uid://bwakjyivdpisv` | Non-standard |
| `scenes/maps/inside_house_map.tscn` | `uid://bwakjhouse01` | Non-standard |
| `scenes/maps/town_map.tscn` | `uid://de5kc56thmwpd` | Non-standard |

## How to Regenerate UIDs in Godot Editor

### Method 1: Right-click Regenerate (Recommended)

1. Open Godot Editor and load the project
2. In the **FileSystem** panel (left sidebar), locate each file listed above
3. Right-click on the file → Select **"Regenerate UID"**
4. Godot will generate a new valid UID automatically
5. Press `Ctrl+S` to save the scene/resource
6. Repeat for all files listed above

### Method 2: Via Scene Inspector

1. Open a scene file (.tscn) in the editor
2. In the **Inspector** panel, find the **uid** property at the top
3. Click the UID field and select **"Regenerate"** or click the refresh icon
4. Save the scene

### Method 3: Batch Fix Script

Create a new file `regenerate_uids.gd` in an `editor_scripts/` folder:

```gdscript
@tool
extends EditorScript

func _run() -> void:
    var files_to_fix = [
        "res://scenes/ui/inventory_ui.tscn",
        "res://scenes/ui/hotbar.tscn",
        "res://scenes/ui/tooltip_panel.tscn",
        "res://scenes/ui/dialogue_ui.tscn",
        "res://scenes/world/bed.tscn",
        "res://scenes/ui/shop_ui.tscn",
        "res://scenes/world/items/apple.tscn",
        "res://scenes/npc/shopkeeper.tscn",
        "res://scenes/maps/inside_shop_map.tscn",
        "res://scenes/maps/inside_house_map.tscn",
        "res://scenes/maps/town_map.tscn",
    ]
    
    for file_path in files_to_fix:
        var file = FileAccess.open(file_path, FileAccess.READ_WRITE)
        if file:
            print("Processing: ", file_path)
            # Note: Direct UID modification not recommended
            file.close()
```

> **Note:** Godot 4.3+ has a built-in "Regenerate UIDs" option in the FileSystem context menu.

## After Regenerating UIDs

1. **Close and reopen the project** to ensure all references are updated
2. **Run the project** to verify no UID-related errors
3. **Check console** for any "Invalid UID" warnings

## Verification

After regeneration, check `project.godot` to ensure:
- `run/main_scene` points to a valid UID
- All ext_resource references use valid UIDs

Run this in Godot console to check for errors:
```
godot --headless --quit --check-only
```

## Common Issues

### "UID mismatch" errors
- A resource file references another resource by UID, but the target has a different UID
- **Fix:** Regenerate UID on both files, then re-save

### "Can't open external resource" errors
- A scene references a resource that doesn't exist or has invalid UID
- **Fix:** Check if the referenced file exists, then regenerate its UID

### Circular dependency warnings
- Two files reference each other by UIDs
- **Fix:** Regenerate UID on one of the files, save, then regenerate the other

---

*Generated: 2026-07-17*
