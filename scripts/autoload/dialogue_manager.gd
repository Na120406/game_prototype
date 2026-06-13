extends Node

signal dialogue_started(npc_name: String)
signal dialogue_ended()
signal dialogue_closed()

var is_active: bool = false

var _current_dialogue: Dictionary = {}
var _current_npc: String = ""
var _current_line: int = 0
var _pending_action: String = ""

const DIALOGUE_DATA_PATH: String = "res://resources/dialogue/"

func _ready() -> void:
	add_to_group("dialogue_manager")
	get_tree().node_added.connect(_on_node_added)
	_connect_to_dialogue_ui()
	print("[DialogueManager] Ready.")

func _on_node_added(node: Node) -> void:
	if node.name != "DialogueUI":
		return
	var ui: Node = _get_dialogue_ui()
	if ui == null:
		return
	if not ui.dialogue_advance.is_connected(advance):
		ui.dialogue_advance.connect(advance)
	if not ui.dialogue_close.is_connected(close):
		ui.dialogue_close.connect(close)
	if not ui.dialogue_choice.is_connected(select_choice):
		ui.dialogue_choice.connect(select_choice)
	print("[DM] Connected to DialogueUI signals.")

func _connect_to_dialogue_ui() -> void:
	var ui: Node = _get_dialogue_ui()
	if ui == null:
		return
	if not ui.dialogue_advance.is_connected(advance):
		ui.dialogue_advance.connect(advance)
	if not ui.dialogue_close.is_connected(close):
		ui.dialogue_close.connect(close)
	if not ui.dialogue_choice.is_connected(select_choice):
		ui.dialogue_choice.connect(select_choice)
	print("[DM] Connected to DialogueUI signals.")

func start_dialogue(dialogue_id: String, npc_name: String) -> void:
	if is_active:
		print("[DM] Already active, ignoring.")
		return

	_connect_to_dialogue_ui()

	var path := DIALOGUE_DATA_PATH + dialogue_id + ".json"
	if not FileAccess.file_exists(path):
		push_error("[DM] File not found: %s" % path)
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("[DM] Cannot open: %s" % path)
		return

	var json_str := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_str)
	if parse_result != OK:
		push_error("[DM] JSON parse error: %s" % path)
		return

	_current_dialogue = json.get_data()
	_current_npc = npc_name
	_current_line = 0
	_pending_action = ""
	is_active = true
	GameState.game_interacting = true
	dialogue_started.emit(npc_name)
	_show_line()
	print("[DM] Started: '%s'" % dialogue_id)

func _show_line() -> void:
	var lines: Array = _current_dialogue.get("lines", [])
	if _current_line >= lines.size():
		_end()
		return

	var line: Dictionary = lines[_current_line]
	var speaker: String = line.get("speaker", _current_npc)
	var text: String = line.get("text", "")
	var choices: Array = line.get("choices", [])
	var is_last: bool = (_current_line >= lines.size() - 1) and choices.is_empty()

	var ui: Node = _get_dialogue_ui()
	if ui == null:
		push_error("[DM] DialogueUI not found!")
		_end()
		return

	ui.show_text(speaker, text, choices, is_last)

func advance() -> void:
	if not is_active:
		return
	_current_line += 1
	_show_line()

func close() -> void:
	print("[DM] close() called.")
	_end()

func end_dialogue() -> void:
	close()

func select_choice(index: int) -> void:
	if not is_active:
		return
	var lines: Array = _current_dialogue.get("lines", [])
	var choice_data: Array = lines[_current_line].get("choices_data", [])
	if index >= choice_data.size():
		return
	var action: String = choice_data[index].get("action", "")
	_pending_action = action
	_current_line += 1
	_show_line()
	_execute_action(action)

func _execute_action(action: String) -> void:
	match action:
		"close":
			_end()

func _end() -> void:
	is_active = false
	GameState.game_interacting = false
	_pending_action = ""
	var ui: Node = _get_dialogue_ui()
	if ui != null:
		ui.hide_dialogue()
	_current_dialogue = {}
	_current_line = 0
	_current_npc = ""
	dialogue_ended.emit()
	dialogue_closed.emit()
	print("[DM] Dialogue ended.")

func _get_dialogue_ui() -> Node:
	var scene: SceneTree = get_tree()
	if scene == null:
		return null
	var root_scene: Node = scene.current_scene
	if root_scene == null:
		return null
	return _find_child(root_scene, "DialogueUI")

func _find_child(root: Node, name: String) -> Node:
	if root == null:
		return null
	if root.name == name:
		return root
	for child in root.get_children():
		var result: Node = _find_child(child, name)
		if result != null:
			return result
	return null
