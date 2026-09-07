extends CanvasLayer

var _sleep_prompt: Node
var _bed: Node

func _ready() -> void:
	_sleep_prompt = $SleepPrompt
	if _sleep_prompt != null:
		_sleep_prompt.sleep_chosen.connect(_on_sleep_chosen)
	call_deferred("_setup_bed")
func _setup_bed() -> void:
	var world: Node = get_parent()
	if world == null:
		return
	var bed_node: Node = world.find_child("Bed", true, false)
	var player_node: Node = world.find_child("Player", true, false)
	if bed_node != null:
		_bed = bed_node
		if _bed.has_signal("sleep_requested"):
			_bed.sleep_requested.connect(_on_bed_sleep_requested)
	if _sleep_prompt != null and player_node != null:
		if _sleep_prompt.has_signal("sleep_started"):
			_sleep_prompt.sleep_started.connect(_on_sleep_started.bind(player_node))
		if _sleep_prompt.has_signal("sleep_cancelled"):
			_sleep_prompt.sleep_cancelled.connect(_on_sleep_cancelled.bind(player_node))

func _on_sleep_started(player: Node) -> void:
	if player != null and player.has_method("on_sleep_prompt_shown"):
		player.on_sleep_prompt_shown()

func _on_sleep_cancelled(player: Node) -> void:
	if player != null and player.has_method("on_sleep_prompt_closed"):
		player.on_sleep_prompt_closed()

func _on_bed_sleep_requested() -> void:
	if _sleep_prompt != null and _sleep_prompt.has_method("show_prompt"):
		_sleep_prompt.show_prompt()

func _on_sleep_chosen() -> void:
	var world: Node = get_parent()
	var player: Node = null
	if world != null:
		player = world.find_child("Player", true, false)
	if player != null and player.has_method("set_sleeping"):
		player.set_sleeping(true)

	# Đánh dấu đã ngủ sau 23:30 nếu thời gian hiện tại >= 23.5
	# Lưu ý: current_time được wrap về 0-24 trong TimeManager._process, nên nếu
	# đã qua nửa đêm (00:00-05:59) thì current_time sẽ là 0.0-5.9, không khớp
	# điều kiện >= 23.5. Cần check cả 2 range.
	var sleep_time_raw: float = GameState.current_time
	var wrapped_hour: float = fposmod(sleep_time_raw, 24.0)
	var slept_late: bool = (wrapped_hour >= 23.5) or (wrapped_hour < 6.0)
	if slept_late:
		GameState.slept_after_2330 = true
		print("[InsideHouseHUD] Slept at %.2f (raw=%.2f) — flagged slept_after_2330" % [wrapped_hour, sleep_time_raw])

	TimeManager.pause()
	var transition := get_node_or_null("/root/DayTransitionManager")
	if transition != null and transition.has_method("play_day_transition"):
		await transition.call("play_day_transition", _advance_day_while_black)
	else:
		# Fallback cho scene/test tối giản chưa có autoload hiệu ứng.
		await get_tree().create_timer(0.8).timeout
		_advance_day_while_black()
	if player != null and player.has_method("set_sleeping"):
		player.set_sleeping(false)

func _advance_day_while_black() -> void:
	var npc_manager: Node = get_node_or_null("/root/NPCManager")
	if npc_manager != null and npc_manager.has_method("fast_forward_npcs_to_day_end"):
		npc_manager.call("fast_forward_npcs_to_day_end", GameState.current_time)
	GameState.advance_day()
	TimeManager.set_time(6.0)
	TimeManager.resume()
	# Ngủ đúng giờ → reset speed penalty. Ngủ muộn/kiệt sức đã bị phạt ở
	# call-site tương ứng (EnergyManager._finish_knock_out) — speed mult vẫn giữ.
	GameState.move_speed_mult = 1.0
