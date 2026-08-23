extends Node

var _ui_layer: CanvasLayer
var _day_label: Label
var _map_label: Label
var _dialogue_ui: Node
var _shop_ui: Node
var _hotbar: Node
var _gold_label: Label
var _scene_path: String = ""

func _ready() -> void:
	var tree := get_tree()
	_scene_path = tree.current_scene.scene_file_path if tree and tree.current_scene else ""

	# Script này được attach vào CanvasLayer "UI" trong scene. Bản thân
	# script instance là Node (extends Node), không phải CanvasLayer. Để lấy
	# UI CanvasLayer chứa script, dùng get_parent() — node parent của script.
	# Nếu scene không có UI node, get_parent() sẽ là root scene → null.
	var existing_ui: CanvasLayer = null
	var parent := get_parent()
	if parent is CanvasLayer and parent.name == "UI":
		existing_ui = parent as CanvasLayer
		print("[WorldUIManager] detected existing UI via get_parent()")
	# Fallback: tìm UI qua absolute path trong tree root
	if existing_ui == null:
		var root := tree.root if tree != null else null
		if root != null:
			var found := root.find_child("UI", true, false)
			if found is CanvasLayer and found.name == "UI":
				existing_ui = found as CanvasLayer
				print("[WorldUIManager] detected existing UI via find_child")

	# Đường dẫn root để spawn các UI cần layer riêng (Dialogue, FloatingWarning…)
	# để chúng luôn nằm trên các UI phụ (hotbar/energy/day info) ở UI canvas.
	var root_node: Node = tree.root

	if existing_ui != null:
		_ui_layer = existing_ui
		# DialogueUI được spawn vào root (CanvasLayer riêng layer=50) — KHÔNG
		# thêm vào _ui_layer (layer=1) vì sẽ bị hotbar ở cùng layer che mất.
		for child in existing_ui.get_children():
			if child.name == "ShopUI":
				_shop_ui = child
			elif child.name == "Hotbar":
				_hotbar = child
			elif child.name == "DayInfo":
				_day_label = child.get_node_or_null("DayPanel/DayLabel")
				_gold_label = child.get_node_or_null("GoldPanel/GoldLabel")
			elif child.name == "MapLabel":
				_map_label = child
		# Tìm DialogueUI đã tồn tại trong root (CanvasLayer riêng)
		_dialogue_ui = _find_dialogue_ui_in_tree(root_node)
		if _dialogue_ui == null:
			_dialogue_ui = _spawn_dialogue_ui(root_node)
		if _shop_ui == null:
			_shop_ui = _spawn_shop_ui()
		if _hotbar == null:
			_hotbar = _spawn_hotbar()
		if not _ui_layer.has_node("DayInfo"):
			_create_day_info()
		if not _ui_layer.has_node("MapLabel"):
			_create_map_label()
		# Luôn đảm bảo InventoryUI tồn tại — packed scene reference trong scene
		# gốc có thể fail load, ta spawn bằng code thay thế.
		if not _ui_layer.has_node("InventoryUI"):
			_spawn_inventory_ui()
		_set_map_name_from_scene()
		print("[WorldUIManager] Using existing CanvasLayer — scene: ", _scene_path)
		return

	_ui_layer = CanvasLayer.new()
	_ui_layer.name = "UI"
	add_child(_ui_layer)
	_create_day_info()
	_create_map_label()
	# Spawn các UI vào root để có layer riêng (dialogue, popup), phần còn lại
	# (hotbar, day info, map label) vào _ui_layer.
	_dialogue_ui = _spawn_dialogue_ui(root_node)
	_spawn_shop_ui()
	_spawn_hotbar()
	_spawn_inventory_ui()
	_set_map_name_from_scene()
	print("[WorldUIManager] Built UI from code — scene: ", _scene_path)

func get_ui_layer() -> CanvasLayer:
	return _ui_layer

func _spawn_dialogue_ui(target: Node = null) -> Node:
	if _dialogue_ui != null:
		return _dialogue_ui
	if not ResourceLoader.exists("res://scenes/ui/dialogue_ui.tscn"):
		return null
	var scene_res = load("res://scenes/ui/dialogue_ui.tscn")
	if scene_res == null:
		return null
	_dialogue_ui = scene_res.instantiate()
	_dialogue_ui.name = "DialogueUI"
	# Spawn vào root để dùng CanvasLayer riêng (layer=50) — đảm bảo hộp thoại
	# LUÔN nằm trên các UI phụ (hotbar/energy/day info ở UI canvas layer=1).
	if target == null:
		target = _ui_layer if _ui_layer != null else get_tree().root
	target.add_child(_dialogue_ui)
	return _dialogue_ui

# Tìm DialogueUI đã được spawn bởi WorldUIManager (hoặc bất kỳ code path nào).
# Luôn trả về DialogueUI Control (script-attached), không phải DialogueLayer.
# DialogueLayer có thể đã được rename thành "DialogueUI" khi instance từ scene
# file gốc (ví dụ inside_shop_map.tscn đặt DialogueUI thẳng dưới UI canvas).
func _find_dialogue_ui_in_tree(root_node: Node) -> Node:
	if root_node == null:
		return null
	# Duyệt root: tìm mọi node có script dialogue_ui.gd.
	var found: Node = _find_node_with_script(root_node, "res://scripts/ui/dialogue_ui.gd")
	if found != null:
		return found
	# Fallback: tìm theo tên "DialogueUI" — chỉ chấp nhận nếu node đó là Control
	# (KHÔNG phải CanvasLayer, vì CanvasLayer "DialogueUI" là DialogueLayer).
	var named: Node = root_node.find_child("DialogueUI", true, false)
	if named is Control:
		return named
	# Tìm DialogueLayer riêng (cấu trúc 2 node).
	var layer: Node = root_node.find_child("DialogueLayer", true, false)
	if layer != null:
		var ui: Node = layer.find_child("DialogueUI", true, false)
		if ui != null:
			return ui
	return null

func _find_node_with_script(root_node: Node, script_path: String) -> Node:
	if root_node == null:
		return null
	if root_node.get_script() != null:
		var sp: String = root_node.get_script().resource_path
		if sp == script_path:
			return root_node
	for child in root_node.get_children():
		var r: Node = _find_node_with_script(child, script_path)
		if r != null:
			return r
	return null

func _spawn_shop_ui() -> Node:
	if _shop_ui != null:
		return _shop_ui
	if not ResourceLoader.exists("res://scenes/ui/shop_ui.tscn"):
		push_warning("[WorldUIManager] shop_ui.tscn not found!")
		return null
	var scene_res = load("res://scenes/ui/shop_ui.tscn")
	if scene_res:
		_shop_ui = scene_res.instantiate()
		_shop_ui.name = "ShopUI"
		_ui_layer.add_child(_shop_ui)
		print("[WorldUIManager] ShopUI spawned fresh from: res://scenes/ui/shop_ui.tscn")
	return _shop_ui

func _spawn_hotbar() -> Node:
	if _hotbar != null:
		return _hotbar
	if not ResourceLoader.exists("res://scenes/ui/hotbar.tscn"):
		return null
	var scene_res = load("res://scenes/ui/hotbar.tscn")
	if scene_res:
		_hotbar = scene_res.instantiate()
		_hotbar.name = "Hotbar"
		_hotbar.add_to_group("hotbar")
		_ui_layer.add_child(_hotbar)
		print("[WorldUIManager] Hotbar spawned!")
	return _hotbar

func _spawn_inventory_ui() -> Node:
	# Tạo InventoryUI programmatic để bypass packed scene loading issue.
	# Reference packed scene trong scene file có thể fail khi:
	#   - ext_resource không có uid hợp lệ
	#   - packed scene có lỗi parse hoặc script gặp lỗi khi load
	# Spawn bằng code đảm bảo node luôn có trong tree và group "inventory_ui"
	# được set. InventoryUI script sẽ tự build UI trong _ready.
	print("[WorldUIManager] _spawn_inventory_ui ENTER")
	if not ResourceLoader.exists("res://scenes/ui/inventory_ui.tscn"):
		print("[WorldUIManager] inventory_ui.tscn not found!")
		return null
	print("[WorldUIManager] loading inventory_ui.tscn...")
	var scene_res = load("res://scenes/ui/inventory_ui.tscn")
	print("[WorldUIManager] load result: ", scene_res)
	if scene_res == null:
		print("[WorldUIManager] Failed to load inventory_ui.tscn (null)")
		return null
	print("[WorldUIManager] instantiating...")
	var inv = scene_res.instantiate()
	print("[WorldUIManager] instantiate result: ", inv)
	if inv == null:
		print("[WorldUIManager] Failed to instantiate inventory_ui.tscn")
		return null
	inv.name = "InventoryUI"
	_ui_layer.add_child(inv)
	print("[WorldUIManager] InventoryUI spawned fresh from code, is_in_group=", inv.is_in_group("inventory_ui"))
	return inv

func _create_day_info() -> void:
	if _ui_layer.has_node("DayInfo"):
		return
	var container := VBoxContainer.new()
	container.name = "DayInfo"
	container.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	container.anchor_left = 1.0
	container.anchor_top = 0.0
	container.anchor_right = 1.0
	container.anchor_bottom = 0.0
	container.offset_left = -66.0
	container.offset_top = 4.0
	container.offset_right = -4.0
	container.offset_bottom = 36.0
	container.grow_horizontal = Control.GROW_DIRECTION_END
	container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	container.custom_minimum_size = Vector2(62, 0)

	var panel_day := PanelContainer.new()
	panel_day.name = "DayPanel"
	var style_d := StyleBoxFlat.new()
	style_d.bg_color = Color(0.08, 0.05, 0.1, 0.85)
	style_d.border_width_left = 1
	style_d.border_width_top = 1
	style_d.border_width_right = 1
	style_d.border_width_bottom = 1
	style_d.border_color = Color(0.5, 0.4, 0.3, 0.8)
	style_d.set_corner_radius_all(3)
	panel_day.add_theme_stylebox_override("panel", style_d)

	_day_label = Label.new()
	_day_label.name = "DayLabel"
	_day_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_day_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_day_label.add_theme_color_override("font_color", Color(1, 0.85, 0.5, 1))
	_day_label.add_theme_font_size_override("font_size", 9)
	_day_label.text = "Day %d" % GameState.current_day
	panel_day.add_child(_day_label)
	container.add_child(panel_day)

	var panel_gold := PanelContainer.new()
	panel_gold.name = "GoldPanel"
	var style_g := StyleBoxFlat.new()
	style_g.bg_color = Color(0.08, 0.05, 0.1, 0.85)
	style_g.border_width_left = 1
	style_g.border_width_top = 1
	style_g.border_width_right = 1
	style_g.border_width_bottom = 1
	style_g.border_color = Color(0.5, 0.4, 0.3, 0.8)
	style_g.set_corner_radius_all(3)
	panel_gold.add_theme_stylebox_override("panel", style_g)

	_gold_label = Label.new()
	_gold_label.name = "GoldLabel"
	_gold_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3, 1))
	_gold_label.add_theme_font_size_override("font_size", 9)
	_gold_label.text = "%d G" % GameState.gold
	panel_gold.add_child(_gold_label)
	container.add_child(panel_gold)

	_ui_layer.add_child(container)

func _create_map_label() -> void:
	if _ui_layer.has_node("MapLabel"):
		return
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
	if _map_label == null or _scene_path == "":
		return
	if _scene_path.contains("town_map"):
		_map_label.text = "VILLAGE TOWN"
	elif _scene_path.contains("inside_shop"):
		_map_label.text = "SHOP"
	elif _scene_path.contains("farm_map"):
		_map_label.text = "FARM HOME"
	elif _scene_path.contains("inside_house"):
		_map_label.text = "INSIDE HOUSE"
	else:
		_map_label.text = ""

func set_map_name(name: String) -> void:
	if _map_label != null:
		_map_label.text = name

func update_gold() -> void:
	if _gold_label != null:
		_gold_label.text = "%d G" % GameState.gold

func _process(_delta: float) -> void:
	if _day_label != null:
		var new_text := "Day %d" % GameState.current_day
		if _day_label.text != new_text:
			_day_label.text = new_text
	if _gold_label != null:
		var gold_text := "%d G" % GameState.gold
		if _gold_label.text != gold_text:
			_gold_label.text = gold_text
