extends Control

signal dialogue_started()
signal dialogue_ended()
signal choice_made(choice_index: int)

@export var dialogue_speed: float = 30.0
@export var auto_advance_delay: float = 3.0

var is_visible_panel: bool = false
var current_speaker: String = ""
var current_text: String = ""
var displayed_char_count: int = 0
var is_typing: bool = false
var choices: Array = []
var choice_buttons: Array = []

@onready var panel: PanelContainer = $PanelContainer
@onready var name_label: Label = $PanelContainer/VBox/NameLabel
@onready var text_label: RichTextLabel = $PanelContainer/VBox/TextLabel
@onready var continue_indicator: TextureRect = $PanelContainer/VBox/ContinueIndicator
@onready var choices_container: VBoxContainer = $PanelContainer/VBox/ChoicesContainer

func _ready() -> void:
	visible = false
	panel.custom_minimum_size.y = 60
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	print("[DialogueUI] Ready.")

func _process(delta: float) -> void:
	if is_typing:
		_update_typing(delta)

func _input(event: InputEvent) -> void:
	if not is_visible_panel:
		return

	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		if is_typing:
			_complete_text_instantly()
		else:
			_advance_dialogue()

func show_dialogue(speaker: String, text: String, dialogue_choices: Array = []) -> void:
	current_speaker = speaker
	current_text = text
	choices = dialogue_choices

	name_label.text = speaker
	choices_container.visible = false
	continue_indicator.visible = false

	visible = true
	is_visible_panel = true
	panel.visible = true
	text_label.text = ""

	displayed_char_count = 0
	is_typing = true
	dialogue_started.emit()

func _update_typing(delta: float) -> void:
	var chars_to_add := dialogue_speed * delta
	displayed_char_count = min(displayed_char_count + int(chars_to_add), current_text.length())
	text_label.text = current_text.substr(0, displayed_char_count)

	if displayed_char_count >= current_text.length():
		is_typing = false
		continue_indicator.visible = true

		if choices.size() > 0:
			_show_choices()

func _complete_text_instantly() -> void:
	if choices.size() > 0:
		return

	text_label.text = current_text
	displayed_char_count = current_text.length()
	is_typing = false
	continue_indicator.visible = true

func _advance_dialogue() -> void:
	if choices.size() > 0:
		return

	hide_dialogue()

func _show_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()
	choice_buttons.clear()

	choices_container.visible = true

	for i in range(choices.size()):
		var choice_text: String = choices[i].get("text", "")
		var button := Button.new()
		button.text = choice_text
		button.pressed.connect(_on_choice_selected.bind(i))
		choices_container.add_child(button)
		choice_buttons.append(button)

	continue_indicator.visible = false

func _on_choice_selected(index: int) -> void:
	choice_made.emit(index)
	hide_dialogue()

func hide_dialogue() -> void:
	visible = false
	is_visible_panel = false
	panel.visible = false

	for child in choices_container.get_children():
		child.queue_free()
	choice_buttons.clear()
	choices.clear()
	dialogue_ended.emit()
