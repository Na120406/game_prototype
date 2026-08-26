extends Resource
class_name PortalData

enum TransitionType { INSTANT, FADE }

@export var portal_id: StringName = &""
@export_file("*.tscn") var target_scene: String = ""
@export var target_portal_id: StringName = &""
@export var transition_type: TransitionType = TransitionType.FADE
@export var prompt: String = "[E]"
@export var interaction_priority: int = 10
@export var spawn_offset: Vector2 = Vector2.ZERO
@export var one_way: bool = false
@export var tags: PackedStringArray = []
@export var version: int = 1

func is_valid() -> bool:
	return not portal_id.is_empty() and not target_scene.is_empty() and interaction_priority >= 0 and _is_finite_value(spawn_offset.x) and _is_finite_value(spawn_offset.y)

func _is_finite_value(value: float) -> bool:
	return not is_nan(value) and not is_inf(value)

func to_dict() -> Dictionary:
	return {
		"version": version,
		"portal_id": String(portal_id),
		"target_scene": target_scene,
		"target_portal_id": String(target_portal_id),
		"transition_type": transition_type,
		"prompt": prompt,
		"interaction_priority": interaction_priority,
		"spawn_offset": {"x": spawn_offset.x, "y": spawn_offset.y},
		"one_way": one_way,
		"tags": Array(tags),
	}

static func from_dict(value: Dictionary) -> PortalData:
	var result := PortalData.new()
	result.version = int(value.get("version", 1))
	result.portal_id = StringName(str(value.get("portal_id", "")))
	result.target_scene = str(value.get("target_scene", ""))
	result.target_portal_id = StringName(str(value.get("target_portal_id", "")))
	result.transition_type = int(value.get("transition_type", TransitionType.FADE)) as TransitionType
	result.prompt = str(value.get("prompt", "[E]"))
	result.interaction_priority = int(value.get("interaction_priority", 10))
	var raw_offset: Variant = value.get("spawn_offset", {})
	if raw_offset is Dictionary:
		result.spawn_offset = Vector2(float(raw_offset.get("x", 0.0)), float(raw_offset.get("y", 0.0)))
	result.one_way = bool(value.get("one_way", false))
	var raw_tags: Variant = value.get("tags", [])
	if raw_tags is Array:
		for tag: Variant in raw_tags:
			result.tags.append(str(tag))
	return result
