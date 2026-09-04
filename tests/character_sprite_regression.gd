extends Node
## Regression: Player, Marcus và Vos phải dùng ba sprite prototype khác nhau,
## đúng kích thước 128×128 và vẫn có alpha nền trong suốt.

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
	var fixtures: Array[Dictionary] = [
		{"scene": "res://scenes/Player.tscn", "texture": "res://assets/characters/player.png", "label": "Player", "body_size": 16.5240625, "body_position_y": -1.0655078125, "sprite_scale": 0.217421875},
		{"scene": "res://scenes/npc/neighbor.tscn", "texture": "res://assets/characters/marcus.png", "label": "Marcus", "body_size": 18.392, "body_position_y": -6.299, "sprite_scale": 0.242},
		{"scene": "res://scenes/npc/shopkeeper.tscn", "texture": "res://assets/characters/vos.png", "label": "Vos", "body_size": 18.392, "body_position_y": -6.299, "sprite_scale": 0.242},
	]
	var sampled_colors: Array[Color] = []
	for fixture: Dictionary in fixtures:
		var packed: PackedScene = load(fixture["scene"]) as PackedScene
		var instance: Node = packed.instantiate() if packed != null else null
		_check(instance != null, "%s scene load được" % fixture["label"])
		if instance == null:
			continue
		get_tree().root.add_child(instance)
		await get_tree().process_frame
		var sprite: Sprite2D = instance.get_node_or_null("Sprite2D") as Sprite2D
		var texture: Texture2D = sprite.texture if sprite != null else null
		_check(texture != null and texture.resource_path == fixture["texture"], "%s trỏ đúng texture riêng" % fixture["label"])
		_check(sprite != null and is_equal_approx(sprite.scale.x, fixture["sprite_scale"]) and is_equal_approx(sprite.scale.y, fixture["sprite_scale"]), "%s tăng scale đồng đều 10%%" % fixture["label"])
		_check(texture != null and texture.get_width() == 128 and texture.get_height() == 128, "%s giữ canvas 128×128" % fixture["label"])
		var body_shape_node: CollisionShape2D = instance.get_node_or_null("CollisionShape2D") as CollisionShape2D
		var body_shape: RectangleShape2D = body_shape_node.shape as RectangleShape2D if body_shape_node != null else null
		_check(body_shape != null and is_equal_approx(body_shape.size.x, fixture["body_size"]) and is_equal_approx(body_shape.size.y, fixture["body_size"]), "%s hitbox phủ đúng ô vuông" % fixture["label"])
		_check(body_shape_node != null and is_equal_approx(body_shape_node.position.y, fixture["body_position_y"]), "%s hitbox căn theo tâm hình" % fixture["label"])
		var body: CharacterBody2D = instance as CharacterBody2D
		_check(body != null and is_zero_approx(body.safe_margin), "%s không chừa safe margin giữa hitbox và collision" % fixture["label"])
		if texture != null:
			var image: Image = texture.get_image()
			_check(image != null and image.has_mipmaps() == false, "%s giữ sprite pixel prototype ổn định" % fixture["label"])
			_check(image != null and image.get_pixel(0, 0).a < 0.01, "%s có nền trong suốt" % fixture["label"])
			if image != null:
				sampled_colors.append(image.get_pixel(64, 64))
		instance.queue_free()

	_check(sampled_colors.size() == 3 and sampled_colors[0] != sampled_colors[1] and sampled_colors[1] != sampled_colors[2] and sampled_colors[0] != sampled_colors[2], "Ba sprite có màu nhận diện khác nhau")
	print("=== CHARACTER SPRITE REGRESSION: %s ===" % ("PASS" if _failures == 0 else "%d FAILURES" % _failures))
	get_tree().quit(0 if _failures == 0 else 1)
