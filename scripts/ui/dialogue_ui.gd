extends Control

signal dialogue_advance()
signal dialogue_close()
signal dialogue_choice(index: int)

@export var text_speed: float = 50.0

var _speaker: String = ""
var _full_text: String = ""
var _current_char: int = 0
var _is_typing: bool = false
var _choices: Array = []
var _choice_btns: Array = []
var _is_last_line: bool = false

var _name_lbl: Label
var _text_lbl: RichTextLabel
var _choices_box: VBoxContainer
var _type_timer: Timer

func _ready() -> void:
	visible = false
	_name_lbl = find_child("Name", true, false)
	_text_lbl = find_child("Text", true, false)
	_choices_box = find_child("Choices", true, false)
	_type_timer = find_child("TypeTimer", true, false)

	if _text_lbl != null:
		_text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	if _choices_box != null:
		_choices_box.visible = false
	if _type_timer != null:
		_type_timer.timeout.connect(_on_type_timer_timeout)

func _input(event: InputEvent) -> void:
	if not visible:
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
	for i in range(_choices.size()):
		var btn := Button.new()
		btn.text = _choices[i].get("text", "?")
		btn.pressed.connect(_on_choice_pressed.bind(i))
		_choices_box.add_child(btn)
		_choice_btns.append(btn)

func _on_choice_pressed(idx: int) -> void:
	for btn in _choice_btns:
		btn.disabled = true
	dialogue_choice.emit(idx)
	visible = false

func hide_dialogue() -> void:
	visible = false
	_is_typing = false
	if _type_timer != null:
		_type_timer.stop()
	_choices.clear()
	for btn in _choice_btns:
		btn.queue_free()
	_choice_btns.clear()
