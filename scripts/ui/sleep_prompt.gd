@tool
extends Control

signal sleep_chosen()
signal sleep_started()
signal sleep_cancelled()

## Content margin cho Panel (khoảng cách text/nút đến viền box).
@export_group("Panel Margin")
@export var panel_margin_left: int = 8:
	set(value):
		panel_margin_left = value
		_apply_panel_style()
@export var panel_margin_top: int = 6:
	set(value):
		panel_margin_top = value
		_apply_panel_style()
@export var panel_margin_right: int = 8:
	set(value):
		panel_margin_right = value
		_apply_panel_style()
@export var panel_margin_bottom: int = 6:
	set(value):
		panel_margin_bottom = value
		_apply_panel_style()

var _is_open: bool = false

func _ready() -> void:
	visible = false
	_apply_panel_style()  # Áp dụng margin từ export vars
	
	var panel := find_child("Panel", true, false)
	if panel != null:
		panel.visible = false
		var vbox := panel.find_child("VBox", true, false)
		if vbox != null:
			var yes_btn: Button = vbox.find_child("YesBtn", true, false)
			var no_btn: Button = vbox.find_child("NoBtn", true, false)
			if yes_btn != null:
				yes_btn.pressed.connect(_on_yes)
			if no_btn != null:
				no_btn.pressed.connect(_on_no)

func _apply_panel_style() -> void:
	# Áp dụng content margin từ export vars vào Panel.
	var panel: PanelContainer = find_child("Panel", true, false)
	if panel == null:
		return
	
	var base_style: StyleBoxFlat = panel.get_theme_stylebox("panel")
	var style := StyleBoxFlat.new()
	
	if base_style != null:
		# Clone style từ .tscn (bg, border, corner radius).
		style.bg_color = base_style.bg_color
		style.border_color = base_style.border_color
		style.border_width_left = base_style.border_width_left
		style.border_width_top = base_style.border_width_top
		style.border_width_right = base_style.border_width_right
		style.border_width_bottom = base_style.border_width_bottom
		style.corner_radius_top_left = base_style.corner_radius_top_left
		style.corner_radius_top_right = base_style.corner_radius_top_right
		style.corner_radius_bottom_right = base_style.corner_radius_bottom_right
		style.corner_radius_bottom_left = base_style.corner_radius_bottom_left
	else:
		# Fallback: style mặc định nếu chưa gán trong .tscn.
		style.bg_color = Color(0.08, 0.05, 0.1, 0.85)
		style.border_color = Color(0.5, 0.4, 0.3, 0.8)
		style.border_width_left = 1
		style.border_width_top = 1
		style.border_width_right = 1
		style.border_width_bottom = 1
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_right = 3
		style.corner_radius_bottom_left = 3
	
	# Content margin LUÔN từ export vars (live preview trong editor).
	style.content_margin_left = panel_margin_left
	style.content_margin_top = panel_margin_top
	style.content_margin_right = panel_margin_right
	style.content_margin_bottom = panel_margin_bottom
	
	panel.add_theme_stylebox_override("panel", style)

func _find_panel() -> Control:
	return find_child("Panel", true, false)

func _find_vbox() -> Control:
	var panel := _find_panel()
	if panel == null:
		return null
	return panel.find_child("VBox", true, false)

func show_prompt() -> void:
	_is_open = true
	visible = true
	GameState.game_interacting = true
	var uif: Node = get_node_or_null("/root/UIFocusManager")
	if uif != null:
		uif.call("dim_background", true)
	var panel := _find_panel()
	if panel != null:
		panel.visible = true
	var backdrop: Control = null
	if get_parent() != null:
		backdrop = get_parent().get_node_or_null("SleepBackdrop")
	if backdrop != null:
		backdrop.visible = true
	accept_event()

func hide_prompt() -> void:
	_is_open = false
	visible = false
	GameState.game_interacting = false
	var uif: Node = get_node_or_null("/root/UIFocusManager")
	if uif != null:
		uif.call("dim_background", false)
	var panel := _find_panel()
	var vbox := _find_vbox()
	var cm: Node = get_node_or_null("/root/ConfigManager")
	if vbox != null:
		var title: Label = vbox.find_child("Title", true, false)
		var yes_btn: Button = vbox.find_child("YesBtn", true, false)
		var no_btn: Button = vbox.find_child("NoBtn", true, false)
		if cm != null and cm.has_method("translate_text"):
			if title != null: title.text = cm.translate_text("ui.sleep.confirm", "Ngủ đến ngày mai?")
			if yes_btn != null: yes_btn.text = cm.translate_text("ui.sleep.yes", "Có [E]")
			if no_btn != null: no_btn.text = cm.translate_text("ui.sleep.no", "Không [ESC]")
	if panel != null:
		panel.visible = false
	var backdrop: Control = null
	if get_parent() != null:
		backdrop = get_parent().get_node_or_null("SleepBackdrop")
	if backdrop != null:
		backdrop.visible = false

func _input(event: InputEvent) -> void:
	if GameState.player_movement_locked or GameState.cinematic_intro_state != GameState.CINEMATIC_NONE:
		return
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_prompt()
		sleep_cancelled.emit()
		accept_event()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		accept_event()
		_on_yes()

func _on_yes() -> void:
	# Notify the player state before the prompt disappears and the day advances.
	sleep_started.emit()
	hide_prompt()
	sleep_chosen.emit()

func _on_no() -> void:
	hide_prompt()
	sleep_cancelled.emit()
