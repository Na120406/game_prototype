extends Node

signal dialogue_started(npc_name: String)
signal dialogue_ended()
signal dialogue_line_completed(line_index: int)
signal choice_selected(choice_index: int)

const DIALOGUE_DATA_PATH: String = "res://resources/dialogue/"

var current_dialogue: Dictionary = {}
var current_npc: String = ""
var current_line_index: int = 0
var is_in_dialogue: bool = false
var dialogue_choices: Array = []

var dialogue_box_scene: PackedScene

func start_dialogue(dialogue_id: String, npc_name: String) -> void:
	var path: String = "%s%s.json" % [DIALOGUE_DATA_PATH, dialogue_id]
	if not FileAccess.file_exists(path):
		push_warning("[DialogueManager] Dialogue not found: %s (looked in %s)" % [dialogue_id, path])
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DialogueManager] Cannot read file: %s" % path)
		return

	var json_str: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	if json.parse(json_str) != OK:
		push_error("[DialogueManager] JSON parse error in: %s" % path)
		return

	current_dialogue = json.get_data()
	current_npc = npc_name
	current_line_index = 0
	is_in_dialogue = true
	dialogue_started.emit(npc_name)
	print("[DialogueManager] Dialogue started: %s with %s" % [dialogue_id, npc_name])

func get_current_line() -> Dictionary:
	if not is_in_dialogue:
		return {}

	var lines: Array = current_dialogue.get("lines", [])
	if current_line_index >= lines.size():
		return {}

	return lines[current_line_index]

func advance_line() -> bool:
	if not is_in_dialogue:
		return false

	var lines: Array = current_dialogue.get("lines", [])
	current_line_index += 1
	dialogue_line_completed.emit(current_line_index - 1)

	if current_line_index >= lines.size():
		end_dialogue()
		return false

	return true

func has_choices() -> bool:
	var line: Dictionary = get_current_line()
	var choices: Array = line.get("choices", [])
	return choices.size() > 0

func get_choices() -> Array:
	var line: Dictionary = get_current_line()
	return line.get("choices", [])

func select_choice(index: int) -> void:
	if not is_in_dialogue:
		return
	dialogue_choices.append(index)
	choice_selected.emit(index)
	advance_line()

func end_dialogue() -> void:
	is_in_dialogue = false
	current_dialogue = {}
	current_line_index = 0
	current_npc = ""
	dialogue_choices.clear()
	dialogue_ended.emit()
	print("[DialogueManager] Dialogue ended.")

func is_active() -> bool:
	return is_in_dialogue
