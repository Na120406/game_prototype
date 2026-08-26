extends Resource
class_name RouteCatalog

@export var routes: Array[RouteData] = []

func get_route(route_id: StringName) -> RouteData:
	for route: RouteData in routes:
		if route != null and route.route_id == route_id:
			return route
	return null

func validate() -> bool:
	var seen: Dictionary = {}
	for route: RouteData in routes:
		if route == null or not route.is_valid() or seen.has(route.route_id):
			return false
		seen[route.route_id] = true
	return true
