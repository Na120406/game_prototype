extends Resource
class_name RouteData

@export var route_id: StringName = &""
@export var waypoints: Array[WaypointData] = []
@export var loop: bool = false
@export var version: int = 1

func is_valid() -> bool:
	if route_id.is_empty() or waypoints.is_empty():
		return false
	var seen: Dictionary = {}
	for waypoint: WaypointData in waypoints:
		if waypoint == null or not waypoint.is_valid() or seen.has(waypoint.id):
			return false
		seen[waypoint.id] = true
	return true

func to_dict() -> Dictionary:
	var serialized: Array[Dictionary] = []
	for waypoint: WaypointData in waypoints:
		if waypoint != null:
			serialized.append(waypoint.to_dict())
	return {"version": version, "route_id": String(route_id), "loop": loop, "waypoints": serialized}

static func from_dict(value: Dictionary) -> RouteData:
	var result := RouteData.new()
	result.version = int(value.get("version", 1))
	result.route_id = StringName(str(value.get("route_id", "")))
	result.loop = bool(value.get("loop", false))
	var raw_waypoints: Variant = value.get("waypoints", [])
	if raw_waypoints is Array:
		for raw: Variant in raw_waypoints:
			if raw is Dictionary:
				result.waypoints.append(WaypointData.from_dict(raw))
	return result
