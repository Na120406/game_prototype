extends Resource
class_name WaypointData

@export var id: StringName = &""
@export_file("*.tscn") var scene_path: String = ""
@export var position: Vector2 = Vector2.ZERO
@export var facing: Vector2 = Vector2.DOWN
@export var tags: PackedStringArray = []

func is_valid() -> bool:
	return not id.is_empty() and not scene_path.is_empty() and _is_finite_value(position.x) and _is_finite_value(position.y)

func _is_finite_value(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)

func to_dict() -> Dictionary:
	return {
		"id": String(id),
		"scene_path": scene_path,
		"position": {"x": position.x, "y": position.y},
		"facing": {"x": facing.x, "y": facing.y},
		"tags": Array(tags),
	}

static func from_dict(value: Dictionary) -> WaypointData:
	var result := WaypointData.new()
	result.id = StringName(str(value.get("id", "")))
	result.scene_path = str(value.get("scene_path", ""))
	var raw_position: Variant = value.get("position", {})
	if raw_position is Dictionary:
		result.position = Vector2(float(raw_position.get("x", 0.0)), float(raw_position.get("y", 0.0)))
	var raw_facing: Variant = value.get("facing", {})
	if raw_facing is Dictionary:
		result.facing = Vector2(float(raw_facing.get("x", 0.0)), float(raw_facing.get("y", 1.0)))
	var raw_tags: Variant = value.get("tags", [])
	if raw_tags is Array:
		for tag: Variant in raw_tags:
			result.tags.append(str(tag))
	return result
