extends Node

# EnergyManager — quản lý tiêu hao & knock-out khi năng lượng = 0.
#
# Hành động tiêu hao (đào, tưới, gieo, thu hoạch, dọn héo) đều gọi
# `spend_energy()` ở đây. Nếu năng lượng về 0 và người chơi tiếp tục
# hành động, knock-out sẽ được kích hoạt:
#   - Fade đen trong 1.0s
#   - Player NGẤT TẠI CHỖ (không teleport về giường)
#   - Trừ 25% vàng hiện có (làm tròn lên)
#   - Tốc độ di chuyển bị giảm 25% sau khi tỉnh
#
signal knock_out_started
signal knock_out_finished

const FADE_DURATION: float = 1.5
const GOLD_LOSS_RATIO: float = 0.25

# Ngưỡng năng lượng "vùng đỏ" (khớp với energy_bar.gd → RED_COLOR).
# Khi energy ≤ ngưỡng này → move_speed_mult giảm 23% (còn 0.77).
# Khi energy > ngưỡng → khôi phục về 1.0 ngay lập tức.
const LOW_ENERGY_THRESHOLD: float = 5.0
const LOW_ENERGY_SPEED_MULT: float = 0.75

var _knock_out_active: bool = false

func _ready() -> void:
	add_to_group("energy_manager")
	if not GameState.energy_changed.is_connected(_on_energy_changed):
		GameState.energy_changed.connect(_on_energy_changed)
	print("[EnergyManager] Ready.")

func _on_energy_changed(new_value: float) -> void:
	# Energy cập nhật từ GameState (spend_energy, advance_day, food, ...)
	# - Energy > 5 (vùng xanh) → khôi phục speed về 1.0 ngay lập tức
	#   (trừ khi đang bị penalty knock-out -25% thì giữ giá trị hiện tại).
	# - Energy ≤ 5 (vùng đỏ) → giảm 15% (còn 0.85).
	if new_value > LOW_ENERGY_THRESHOLD:
		# Ra khỏi vùng đỏ: chỉ khôi phục khi speed hiện tại bằng LOW_ENERGY_SPEED_MULT
		# (tránh ghi đè penalty knock-out -25% còn lại từ trước).
		if GameState.move_speed_mult == LOW_ENERGY_SPEED_MULT or GameState.move_speed_mult >= 1.0:
			if GameState.move_speed_mult != 1.0:
				GameState.move_speed_mult = 1.0
				print("[EnergyManager] Energy recovered (%.1f > %.1f) → speed mult restored to 1.0" % [
					new_value, LOW_ENERGY_THRESHOLD
				])
	else:
		# Vào vùng đỏ: giảm xuống 0.85, lấy min với giá trị hiện tại để các
		# penalty khác (knock-out -25%) vẫn giữ nguyên nếu đã thấp hơn.
		if GameState.move_speed_mult > LOW_ENERGY_SPEED_MULT:
			GameState.move_speed_mult = LOW_ENERGY_SPEED_MULT
			print("[EnergyManager] Low energy (%.1f ≤ %.1f) → speed mult reduced by 23%% to %.2f" % [
				new_value, LOW_ENERGY_THRESHOLD, LOW_ENERGY_SPEED_MULT
			])

# Gọi từ mỗi action tiêu hao (đào, tưới, plant, harvest, clear wilted).
# amount = 1 (mỗi action tốn 1 energy).
func spend_energy(amount: int = 1) -> bool:
	if _knock_out_active or amount <= 0:
		return false
	if GameState.energy < float(amount):
		# Do not report an action as successful when it cannot be paid for.
		trigger_knock_out()
		return false
	GameState.modify_energy(-float(amount))
	if GameState.energy <= 0.0:
		trigger_knock_out()
	return true

func trigger_knock_out() -> void:
	if _knock_out_active:
		return
	_knock_out_active = true
	knock_out_started.emit()
	GameState.player_movement_locked = true
	print("[EnergyManager] Knock-out triggered!")
	# Ngất tại chỗ (giống AFK) — không teleport về giường.
	_start_fade(false)

# AFK/stand-still knock-out: cùng hiệu ứng nhưng KHÔNG teleport về giường
# (player tỉnh ngay tại chỗ đang đứng). Reset về 1:00 (giữa đêm) — khác với
# kiệt sức giữa ngày (6:00 sáng) và ngủ đúng giờ (cũng 6:00 tại giường).
func trigger_afk_knock_out() -> void:
	if _knock_out_active:
		return
	_knock_out_active = true
	knock_out_started.emit()
	print("[EnergyManager] AFK knock-out triggered!")
	# AFK reset về 6:00 (= "bắt đầu state ngày mới"). TimeManager sẽ tự
	# trigger advance_day(6.0) khi phát hiện boundary 6:00, tăng current_day +
	# emit farm_day_changed.
	_start_fade_with_reset(false, 6.0)

func _start_fade(do_teleport: bool) -> void:
	_start_fade_with_reset(do_teleport, 6.0)

# Cho phép override giờ reset sau khi knock-out xong:
#   - AFK penalty (quá 24:00 chưa ngủ) → 1.0 (giữa đêm)
#   - Kiệt sức (energy = 0 giữa ngày) → 6.0 (sáng sớm, mặc định)
func _start_fade_with_reset(do_teleport: bool, reset_to_hour: float) -> void:
	var tree := get_tree()
	if tree == null:
		_finish_knock_out(do_teleport, reset_to_hour)
		return
	var root := tree.root
	# Dựng overlay đen che toàn màn hình.
	var overlay := ColorRect.new()
	overlay.name = "KnockOutOverlay"
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# KHÔNG set z_index > 4095 (CANVAS_ITEM_Z_MAX) — sẽ push error mỗi lần
	# knock-out. Overlay đã nằm trong CanvasLayer layer 999 nên luôn hiển thị
	# trên mọi thứ; z_index mặc định 0 là đủ.
	var layer := CanvasLayer.new()
	layer.name = "KnockOutLayer"
	layer.layer = 999
	layer.add_child(overlay)
	root.add_child(layer)

	var tween := overlay.create_tween()
	tween.tween_property(overlay, "color:a", 1.0, FADE_DURATION * 0.5)
	# Không tự teleport Player tới Bed. Scene transition/spawn chỉ được quyết định
	# bởi portal hoặc vị trí mặc định hợp lệ của SceneManager.
	tween.tween_interval(FADE_DURATION * 0.2)
	tween.tween_property(overlay, "color:a", 0.0, FADE_DURATION * 0.5)
	tween.tween_callback(_finish_knock_out.bind(do_teleport, reset_to_hour))
	tween.tween_callback(layer.queue_free)

# Legacy knockout bed teleport removed. Player spawn is handled exclusively by
# the active SceneManager portal/default spawn rules.

func _finish_knock_out(do_teleport: bool, reset_to_hour: float = 6.0) -> void:
	# Knock-out = sang ngày mới (giống ngủ) + penalty vàng + penalty tốc độ.
	# Energy hiện tại đặt về 5 (chỉ là "an ủi" - sẽ được reset về max khi
	# người chơi ngủ thật sự qua ngày tiếp theo).
	#
	# Proportional days: nếu time đã trôi qua rất lâu (vd. nhiều giờ thực)
	# mà chưa ai cập nhật, gọi advance_day() nhiều lần để farm/watering
	# vẫn đồng bộ. Reset về reset_to_hour:
	#   - AFK penalty (quá 24:00 chưa ngủ) → 1.0 (giữa đêm)
	#   - Kiệt sức (energy = 0) → 6.0 (sáng sớm, mặc định)
	var days_passed: int = max(1, int(floor(GameState.current_time / 24.0)))
	for i in range(days_passed):
		GameState.advance_day(reset_to_hour)

	# Phạt -25% vàng trong CẢ HAI trường hợp:
	#   - Cày kiệt sức (trigger_knock_out, có teleport về giường)
	#   - Quá giờ đi ngủ / đứng ngoài trời ngủ muộn (trigger_afk_knock_out)
	# Speed penalty (-25%) cũng áp dụng đồng thời; cả hai được reset khi
	# player ngủ đúng giờ qua đêm tiếp theo (gọi từ inside_house_hud).
	_apply_gold_loss_penalty()
	GameState.energy = min(GameState.max_energy, 5.0)
	GameState.move_speed_mult = max(0.1, GameState.move_speed_mult * 0.75)
	GameState.energy_changed.emit(GameState.energy)
	_knock_out_active = false
	GameState.player_movement_locked = false
	knock_out_finished.emit()
	print("[EnergyManager] Knock-out -> day %d, energy %.0f, speed mult %.2f (teleport=%s, days=%d)" % [
		GameState.current_day, GameState.energy, GameState.move_speed_mult,
		str(do_teleport), days_passed
	])


func _apply_gold_loss_penalty() -> void:
	# Trừ 25% vàng hiện có (làm tròn lên). Dùng chung cho cả hai dạng
	# knock-out (cày kiệt sức + quá giờ ngủ ngoài trời).
	var cm: Node = get_node_or_null("/root/ConfigManager")
	var loss_ratio: float = GOLD_LOSS_RATIO
	if cm != null:
		loss_ratio = float(cm.get_value("money.knockout_loss_ratio", GOLD_LOSS_RATIO))
	var loss: int = int(ceil(float(GameState.gold) * loss_ratio))
	if loss > 0:
		GameState.gold = max(0, GameState.gold - loss)
		print("[EnergyManager] Knock-out gold loss: -%d (now %d)" % [loss, GameState.gold])
