extends Control

signal dialogue_advance()
signal dialogue_close()
signal dialogue_choice(index: int)

@export var text_speed: float = 50.0

## Font sizes
@export_group("Font Settings")
@export var name_font_size: int = 9:
	set(value):
		name_font_size = value
		if _name_lbl != null:
			_name_lbl.add_theme_font_size_override("font_size", value)

@export var text_font_size: int = 9:
	set(value):
		text_font_size = value
		if _text_lbl != null:
			_text_lbl.add_theme_font_size_override("normal_font_size", value)

## Text position offset (from current anchor)
@export_group("Text Position")
@export var text_margin_left: int = 5
@export var text_margin_right: int = 5
@export var text_margin_top: int = 4
@export var text_margin_bottom: int = 4

## Background panel size
@export_group("Panel Size")
@export var panel_min_height: int = 80:
	set(value):
		panel_min_height = value
		if _panel != null:
			_panel.custom_minimum_size.y = value

@export var panel_height_offset: float = 0.0:
	set(value):
		panel_height_offset = value
		_update_panel_position()

## Background panel color
@export_group("Panel Colors")
@export var border_color: Color = Color(0.5, 0.4, 0.3, 1):
	set(value):
		border_color = value
		if _border_rect != null:
			_border_rect.color = value

## Internal references
var _name_lbl: Label
var _text_lbl: RichTextLabel
var _choices_box: VBoxContainer
var _type_timer: Timer
var _panel: PanelContainer
var _border_rect: ColorRect
var _margin: MarginContainer

var _speaker: String = ""
var _full_text: String = ""
var _current_char: int = 0
var _is_typing: bool = false
var _choices: Array = []
var _choice_btns: Array = []
var _is_last_line: bool = false

func _ready() -> void:
	visible = false
	
	_name_lbl = find_child("Name", true, false)
	_text_lbl = find_child("Text", true, false)
	_choices_box = find_child("Choices", true, false)
	_type_timer = find_child("TypeTimer", true, false)
	_panel = find_child("Panel", true, false)
	_border_rect = find_child("Border", true, false)
	_margin = find_child("Margin", true, false)
	
	# Apply exported values
	if _name_lbl != null:
		_name_lbl.add_theme_font_size_override("font_size", name_font_size)
	if _text_lbl != null:
		_text_lbl.add_theme_font_size_override("normal_font_size", text_font_size)
	if _panel != null:
		_panel.custom_minimum_size.y = panel_min_height
	if _border_rect != null:
		_border_rect.color = border_color
	if _margin != null:
		_margin.add_theme_constant_override("margin_left", text_margin_left)
		_margin.add_theme_constant_override("margin_right", text_margin_right)
		_margin.add_theme_constant_override("margin_top", text_margin_top)
		_margin.add_theme_constant_override("margin_bottom", text_margin_bottom)
	
	_update_panel_position()
	
	if _text_lbl != null:
		_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	if _choices_box != null:
		_choices_box.visible = false
	if _type_timer != null:
		_type_timer.timeout.connect(_on_type_timer_timeout)

func _update_panel_position() -> void:
	if _panel != null:
		_panel.offset_top = -panel_min_height + panel_height_offset

func _input(event: InputEvent) -> void:
	if not visible:
		return

	# Nếu đang trong choices - KHÔNG xử lý click để button hoạt động
	if _choices.size() > 0:
		return

	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			get_viewport().set_input_as_handled()
			_click_action()
		return

	if event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_click_action()

func _click_action() -> void:
	if _is_typing:
		_skip_typing()
	elif _choices.size() > 0:
		pass
	elif _is_last_line:
		dialogue_close.emit()
	else:
		dialogue_advance.emit()

func _skip_typing() -> void:
	_is_typing = false
	_current_char = _full_text.length()
	if _type_timer != null:
		_type_timer.stop()
	if _text_lbl != null:
		_text_lbl.text = _full_text
	_on_text_done()

func show_text(speaker: String, text: String, choices: Array = [], is_last: bool = false) -> void:
	_speaker = speaker
	_full_text = text
	_choices = choices
	_is_last_line = is_last
	_current_char = 0
	_is_typing = true

	if _name_lbl != null:
		_name_lbl.text = speaker
	if _text_lbl != null:
		_text_lbl.text = ""
	if _choices_box != null:
		_choices_box.visible = false

	for btn in _choice_btns:
		btn.queue_free()
	_choice_btns.clear()

	visible = true
	if _type_timer != null:
		_type_timer.start(1.0 / text_speed)

func _on_type_timer_timeout() -> void:
	if not _is_typing:
		if _type_timer != null:
			_type_timer.stop()
		return
	_current_char += 1
	if _current_char >= _full_text.length():
		_current_char = _full_text.length()
		_is_typing = false
		if _type_timer != null:
			_type_timer.stop()
		if _text_lbl != null:
			_text_lbl.text = _full_text
		_on_text_done()
	else:
		if _text_lbl != null:
			_text_lbl.text = _full_text.substr(0, _current_char)

func _on_text_done() -> void:
	if _choices.size() > 0:
		_show_choices()

func _show_choices() -> void:
	if _choices_box == null:
		return
	_choices_box.visible = true
	_choices_box.custom_minimum_size.y = 60  # Đảm bảo có không gian hiển thị
	for i in range(_choices.size()):
		var btn := Button.new()
		# Xử lý 2 format: object {text, action} hoặc string đơn
		if _choices[i] is Dictionary:
			btn.text = _choices[i].get("text", "?")
		else:
			btn.text = str(_choices[i])

		# Style button như player response
		btn.add_theme_font_size_override("font_size", 11)
		btn.custom_minimum_size = Vector2(0, 26)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		# Tạo StyleBoxFlat cho button
		var normal_style := StyleBoxFlat.new()
		normal_style.bg_color = Color(0.2, 0.25, 0.2, 0.85)
		normal_style.border_color = Color(0.4, 0.6, 0.4, 0.8)
		normal_style.corner_radius_top_left = 4
		normal_style.corner_radius_top_right = 4
		normal_style.corner_radius_bottom_left = 4
		normal_style.corner_radius_bottom_right = 4
		normal_style.content_margin_left = 10
		normal_style.content_margin_right = 10
		btn.add_theme_stylebox_override("normal", normal_style)

		# Hover style
		var hover_style := StyleBoxFlat.new()
		hover_style.bg_color = Color(0.25, 0.35, 0.25, 0.9)
		hover_style.border_color = Color(0.5, 0.8, 0.5, 1)
		hover_style.corner_radius_top_left = 4
		hover_style.corner_radius_top_right = 4
		hover_style.corner_radius_bottom_left = 4
		hover_style.corner_radius_bottom_right = 4
		hover_style.content_margin_left = 10
		hover_style.content_margin_right = 10
		btn.add_theme_stylebox_override("hover", hover_style)

		btn.pressed.connect(_on_choice_pressed.bind(i))
		_choices_box.add_child(btn)
		_choice_btns.append(btn)

func _on_choice_pressed(idx: int) -> void:
	print("[DialogueUI] Choice pressed: %d" % idx)
	for btn in _choice_btns:
		btn.disabled = true
	dialogue_choice.emit(idx)

func _clear_choices() -> void:
	for btn in _choice_btns:
		btn.queue_free()
	_choice_btns.clear()
	_choices_box.visible = false
	_choices.clear()

func hide_dialogue() -> void:
	visible = false
	_is_typing = false
	if _type_timer != null:
		_type_timer.stop()
	_choices.clear()
	for btn in _choice_btns:
		btn.queue_free()
	_choice_btns.clear()
