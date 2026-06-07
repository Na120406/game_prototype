extends Node

signal tool_equipped(tool_id: String)
signal tool_unequipped(tool_id: String)

var _equipped_tool: String = "none"

func _ready() -> void:
	print("[ToolHandler] Ready")

func equip(tool_id: String) -> void:
	if _equipped_tool == tool_id:
		return
	var prev := _equipped_tool
	_equipped_tool = tool_id
	if prev != "none":
		tool_unequipped.emit(prev)
	if tool_id != "none":
		tool_equipped.emit(tool_id)
	print("[ToolHandler] Equipped: %s" % tool_id)

func unequip() -> void:
	var prev := _equipped_tool
	if prev != "none":
		_equipped_tool = "none"
		tool_unequipped.emit(prev)
		print("[ToolHandler] Unequipped: %s" % prev)

func get_equipped() -> String:
	return _equipped_tool

func is_equipped(tool_id: String) -> bool:
	return _equipped_tool == tool_id

func has_any_tool() -> bool:
	return _equipped_tool != "none"
