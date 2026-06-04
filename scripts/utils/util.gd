class_name Util
extends Node

static func lerp_color(from: Color, to: Color, t: float) -> Color:
	return Color(
		lerp(from.r, to.r, t),
		lerp(from.g, to.g, t),
		lerp(from.b, to.b, t),
		lerp(from.a, to.a, t)
	)

static func world_to_grid(world_pos: Vector2, cell_size: int = 16) -> Vector2i:
	return Vector2i(int(world_pos.x / cell_size), int(world_pos.y / cell_size))

static func grid_to_world(grid_pos: Vector2i, cell_size: int = 16) -> Vector2:
	return Vector2(grid_pos.x * cell_size, grid_pos.y * cell_size)

static func is_inside_rect(pos: Vector2, rect: Rect2) -> bool:
	return rect.has_point(pos)

static func direction_to_vector(dir: Vector2) -> Vector2:
	var length := dir.length()
	if length > 0.001:
		return dir / length
	return Vector2.ZERO

static func direction_from_angle(angle: float) -> Vector2:
	return Vector2(cos(angle), sin(angle))

static func angle_from_direction(dir: Vector2) -> float:
	return atan2(dir.y, dir.x)

static func angle_lerp(from: float, to: float, weight: float) -> float:
	return lerp(from, to, weight)

static func random_element(arr: Array):
	if arr.is_empty():
		return null
	return arr[randi() % arr.size()]

static func shuffle_array(arr: Array) -> Array:
	var shuffled := arr.duplicate()
	for i in range(shuffled.size() - 1, 0, -1):
		var j := randi() % (i + 1)
		var temp = shuffled[i]
		shuffled[i] = shuffled[j]
		shuffled[j] = temp
	return shuffled

static func format_time(time_val: float) -> String:
	var hours := int(time_val)
	var minutes := int((time_val - hours) * 60)
	return "%02d:%02d" % [hours, minutes]

static func format_time_with_ampm(time_val: float) -> String:
	var hours24 := int(time_val)
	var minutes := int((time_val - hours24) * 60)
	var ampm := "AM" if hours24 < 12 else "PM"
	var hours12 := hours24 if hours24 > 0 and hours24 <= 12 else abs(hours24 - 12) if hours24 > 12 else 12
	return "%d:%02d %s" % [hours12, minutes, ampm]

static func ease_in_out(t: float) -> float:
	return t * t * (3.0 - 2.0 * t) if t < 0.5 else 1.0 - pow(-2.0 * t + 2.0, 2.0) / 2.0

static func clamp_angle(angle: float) -> float:
	while angle > PI:
		angle -= TAU
	while angle < -PI:
		angle += TAU
	return angle

static func point_in_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1: float = sign((p.x - b.x) * (a.y - b.y) - (a.x - b.x) * (p.y - b.y))
	var d2: float = sign((p.x - c.x) * (b.y - c.y) - (b.x - c.x) * (p.y - c.y))
	var d3: float = sign((p.x - a.x) * (c.y - a.y) - (c.x - a.x) * (p.y - a.y))
	var has_neg := (d1 < 0) or (d2 < 0) or (d3 < 0)
	var has_pos := (d1 > 0) or (d2 > 0) or (d3 > 0)
	return not (has_neg and has_pos)

static func seeded_random(seed: int) -> float:
	var x := sin(float(seed) * 12.9898 + 78.233) * 43758.5453
	return x - floor(x)
