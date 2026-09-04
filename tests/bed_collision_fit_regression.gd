extends Node
## Regression: collision của Bed phải trùng mép hình ảnh, không chừa khe hở
## khi Player áp sát từ phía dưới hoặc phía trên.

var _failures: int = 0


func _ready() -> void:
	call_deferred("_run")


func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] %s" % label)
	else:
		_failures += 1
		print("[FAIL] %s" % label)


func _run() -> void:
	var packed: PackedScene = load("res://scenes/world/bed.tscn") as PackedScene
	var bed: Node2D = packed.instantiate() if packed != null else null
	_check(bed != null, "Bed scene load được")
	if bed == null:
		get_tree().quit(1)
		return
	add_child(bed)

	var frame: ColorRect = bed.get_node_or_null("Frame") as ColorRect
	var top_node: CollisionShape2D = bed.get_node_or_null("CollisionTop") as CollisionShape2D
	var bottom_node: CollisionShape2D = bed.get_node_or_null("CollisionBottom") as CollisionShape2D
	var top_shape: RectangleShape2D = top_node.shape as RectangleShape2D if top_node != null else null
	var bottom_shape: RectangleShape2D = bottom_node.shape as RectangleShape2D if bottom_node != null else null
	_check(frame != null and top_node != null and bottom_node != null, "Bed có đủ hình và hai collision mép")
	_check(top_shape != null and bottom_shape != null and is_equal_approx(top_shape.size.x, 44.0) and is_equal_approx(bottom_shape.size.x, 44.0), "Collision phủ đủ chiều rộng Frame")
	if frame != null and top_node != null and bottom_node != null and top_shape != null and bottom_shape != null:
		_check(is_equal_approx(top_node.position.y - top_shape.size.y * 0.5, frame.offset_top), "CollisionTop trùng mép trên hình")
		_check(is_equal_approx(bottom_node.position.y + bottom_shape.size.y * 0.5, frame.offset_bottom), "CollisionBottom trùng mép dưới hình")
		_check(is_zero_approx(top_node.position.x) and is_zero_approx(bottom_node.position.x), "Hai collision căn giữa theo Frame")

	bed.queue_free()
	print("=== BED COLLISION FIT REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
