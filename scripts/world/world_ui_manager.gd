extends Node

var _ui_layer: CanvasLayer
var _day_label: Label
var _map_label: Label
var _dialogue_ui: Node
var _shop_ui: Node
var _scene_path: String = ""

func _ready() -> void:
	_scene_path = get_tree().current_scene.scene_file_path if get_tree() and get_tree().current_scene else ""

	var existing_ui = get_node_or_null("UI")
	if existing_ui != null and existing_ui is CanvasLayer:
		_ui_layer = existing_ui
		_ui_layer.name = "UI"
		_day_label = _ui_layer.get_node_or_null("DayInfo/DayLabel")
		_map_label = _ui_layer.get_node_or_null("MapLabel")
		_dialogue_ui = _ui_layer.get_node_or_null("DialogueUI")
		_shop_ui = _ui_layer.get_node_or_null("ShopUI")
		_set_map_name_from_scene()
		print("[WorldUIManager] External UI found, using existing — scene: ", _scene_path)
		return

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	add_child(_ui_layer)
	_create_day_info()
	_create_map_label()
	_spawn_map_ui()
	_set_map_name_from_scene()
	print("[WorldUIManager] Built UI from code — scene: ", _scene_path)

func get_ui_layer() -> CanvasLayer:
	return _ui_layer

func _spawn_map_ui() -> void:
	if _scene_path == "":
		return
	if _scene_path.contains("farm_map") or _scene_path.contains("town_map"):
		_spawn_dialogue_ui()
		_spawn_shop_ui()
	elif _scene_path.contains("inside_shop"):
		_spawn_dialogue_ui()

func _spawn_dialogue_ui() -> void:
	if not ResourceLoader.exists("res://scenes/ui/dialogue_ui.tscn"):
		return
	var scene_res = load("res://scenes/ui/dialogue_ui.tscn")
	if scene_res:
		_dialogue_ui = scene_res.instantiate()
		_dialogue_ui.name = "DialogueUI"
		_ui_layer.add_child(_dialogue_ui)

func _spawn_shop_ui() -> void:
	if not ResourceLoader.exists("res://scenes/ui/shop_ui.tscn"):
		return
	var scene_res = load("res://scenes/ui/shop_ui.tscn")
	if scene_res:
		_shop_ui = scene_res.instantiate()
		_shop_ui.name = "ShopUI"
		_ui_layer.add_child(_shop_ui)

func _create_day_info() -> void:
	var panel := PanelContainer.new()
	panel.name = "DayInfo"
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.anchor_left = 1.0
	panel.anchor_top = 0.0
	panel.anchor_right = 1.0
	panel.anchor_bottom = 0.0
	panel.offset_left = -66.0
	panel.offset_top = 4.0
	panel.offset_right = -4.0
	panel.offset_bottom = 22.0
	panel.grow_horizontal = Control.GROW_DIRECTION_END
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.05, 0.1, 0.85)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.5, 0.4, 0.3, 0.8)
	style.set_corner_radius_all(3)
	panel.add_theme_stylebox_override("panel", style)

	_day_label = Label.new()
	_day_label.name = "DayLabel"
	_day_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_day_label.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
	_day_label.add_theme_font_size_override("font_size", 9)
	_day_label.text = "Day %d" % GameState.current_day

	panel.add_child(_day_label)
	_ui_layer.add_child(panel)

func _create_map_label() -> void:
	_map_label = Label.new()
	_map_label.name = "MapLabel"
	_map_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_map_label.anchor_left = 0.0
	_map_label.anchor_top = 0.0
	_map_label.anchor_right = 0.0
	_map_label.anchor_bottom = 0.0
	_map_label.offset_left = 4.0
	_map_label.offset_top = 2.0
	_map_label.offset_right = 70.0
	_map_label.offset_bottom = 12.0
	_map_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_map_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_map_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_map_label.add_theme_font_size_override("font_size", 6)
	_ui_layer.add_child(_map_label)

func _set_map_name_from_scene() -> void:
	if _scene_path == "":
		return
	if _scene_path.contains("town_map"):
		_map_label.text = "VILLAGE TOWN"
	elif _scene_path.contains("inside_shop"):
		_map_label.text = "SHOP"
	elif _scene_path.contains("farm_map"):
		_map_label.text = "FARM HOME"
	else:
		_map_label.text = ""

func set_map_name(name: String) -> void:
	if _map_label != null:
		_map_label.text = name

func _process(_delta: float) -> void:
	if _day_label != null:
		var new_text := "Day %d" % GameState.current_day
		if _day_label.text != new_text:
			_day_label.text = new_text
