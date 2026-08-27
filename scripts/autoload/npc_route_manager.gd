extends Node
## Registry route waypoint dùng chung cho NPC và portal.
## Route chỉ mô tả trình tự; NPC tự chịu trách nhiệm di chuyển tới waypoint.


const ROUTES: Dictionary = {
	"shop_to_town": [
		{"scene": "res://scenes/maps/inside_shop_map.tscn", "point": "portal_shop_to_town", "position": Vector2(20, 135), "portal_id": "portal_shop_to_town"},
		{"scene": "res://scenes/maps/town_map.tscn", "point": "shop_exit", "position": Vector2(95, 105), "portal_id": "portal_town_to_shop"}
	],
	"town_to_farm": [
		{"scene": "res://scenes/maps/town_map.tscn", "point": "farm_exit", "position": Vector2(20, 135), "portal_id": "portal_town"},
		{"scene": "res://scenes/maps/farm_map.tscn", "point": "farm_entry", "position": Vector2(20, 135), "portal_id": "portal_town"}
	],
	"town_to_marcus_farm": [
		{"scene": "res://scenes/maps/town_map.tscn", "point": "marcus_farm_exit", "position": Vector2(460, 135), "portal_id": "portal_marcus_farm_from_town"},
		{"scene": "res://scenes/maps/marcus_farm_map.tscn", "point": "town_entry", "position": Vector2(20, 135), "portal_id": "portal_marcus_farm_from_town"}
	],
	"farm_to_town": [
		{"scene": "res://scenes/maps/farm_map.tscn", "point": "town_exit", "position": Vector2(790, 300), "portal_id": "portal_town"},
		{"scene": "res://scenes/maps/town_map.tscn", "point": "farm_entry", "position": Vector2(20, 135), "portal_id": "portal_town"}
	],
	"marcus_farm_to_house": [
		{"scene": "res://scenes/maps/marcus_farm_map.tscn", "point": "house_exit", "position": Vector2(375, 135), "portal_id": "portal_marcus_farm_from_house"},
		{"scene": "res://scenes/maps/marcus_house_map.tscn", "point": "farm_entry", "position": Vector2(420, 146), "portal_id": "portal_marcus_farm_from_house"}
	],
	"marcus_farm_to_town": [
		{"scene": "res://scenes/maps/marcus_farm_map.tscn", "point": "town_exit", "position": Vector2(20, 135), "portal_id": "portal_marcus_farm_from_town"},
		{"scene": "res://scenes/maps/town_map.tscn", "point": "farm_entry", "position": Vector2(460, 135), "portal_id": "portal_marcus_farm_from_town"}
	],
	"town_to_shop": [
		{"scene": "res://scenes/maps/town_map.tscn", "point": "shop_exit", "position": Vector2(95, 105), "portal_id": "portal_town_to_shop"},
		{"scene": "res://scenes/maps/inside_shop_map.tscn", "point": "shop_entry", "position": Vector2(20, 135), "portal_id": "portal_shop_to_town"}
	],
	"marcus_house_to_farm": [
		{"scene": "res://scenes/maps/marcus_house_map.tscn", "point": "farm_exit", "position": Vector2(420, 146), "portal_id": "portal_marcus_farm_from_house"},
		{"scene": "res://scenes/maps/marcus_farm_map.tscn", "point": "house_entry", "position": Vector2(375, 135), "portal_id": "portal_marcus_farm_from_house"}
	]
}

func get_route(route_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for waypoint: Dictionary in ROUTES.get(route_id, []):
		result.append(waypoint.duplicate(true))
	return result

func get_waypoint(route_id: String, index: int) -> Dictionary:
	var route: Array[Dictionary] = get_route(route_id)
	return route[index] if index >= 0 and index < route.size() else {}

func validate_route(route_id: String) -> bool:
	var route: Array[Dictionary] = get_route(route_id)
	if route.is_empty():
		return false
	var previous_scene: String = ""
	for waypoint: Dictionary in route:
		var scene_path: String = str(waypoint.get("scene", ""))
		var position_value: Variant = waypoint.get("position", null)
		if scene_path == "" or not (position_value is Vector2):
			return false
		if previous_scene != "" and scene_path != previous_scene and str(waypoint.get("portal_id", "")) == "":
			return false
		previous_scene = scene_path
	return true
