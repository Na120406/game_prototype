extends Node
# =============================================================================
# AUDIO MANAGER (Quản lý Âm thanh)
# =============================================================================
# Chức năng: Điều khiển tất cả âm thanh trong game
#
# Các loại âm thanh:
#   - SFX (Sound Effects): Âm thanh ngắn - tiếng bước chân, tiếng nhấp chuột
#   - Music: Nhạc nền - nhạc quán rượu, nhạc ban đêm
#   - Ambient: Âm thanh nền - tiếng chim, tiếng gió
#
# Tính năng:
#   - Object pooling cho SFX (tái sử dụng players)
#   - Fade in/out cho music và ambient
#   - Điều chỉnh volume riêng cho từng loại
#
# CÁCH SỬ DỤNG:
#   AudioManager.play_sfx("step_grass") - phát tiếng bước
#   AudioManager.play_music("tavern") - phát nhạc quán
#   AudioManager.play_ambient("forest") - phát âm thanh rừng
# =============================================================================

# =============================================================================
# CÁC BIẾN NGƯỜI CHƠI
# =============================================================================

# Player cho nhạc nền (chỉ có 1)
var current_music: AudioStreamPlayer

# Player cho âm thanh nền (chỉ có 1)
var current_ambient: AudioStreamPlayer

# Pool các player SFX - dùng chung cho tất cả SFX
# Thay vì tạo player mới mỗi lần phát, tái sử dụng từ pool
var sfx_players: Array[AudioStreamPlayer] = []

# Số lượng player trong pool SFX
var max_sfx_players: int = 8


# =============================================================================
# CÁC BIẾN VOLUME
# =============================================================================

# Volume tổng (Master) - ảnh hưởng tất cả âm thanh
var master_volume: float = 1.0

# Volume SFX - 1.0 = toàn volume
var sfx_volume: float = 1.0

# Volume Music - 0.8 = 80% volume (mặc định nhạc nhẹ hơn)
var music_volume: float = 0.8

# Volume Ambient - 0.6 = 60% volume (âm thanh nền nhỏ nhất)
var ambient_volume: float = 0.6


# =============================================================================
# HÀM KHỞI TẠO (_ready)
# =============================================================================

func _ready() -> void:
	_setup_audio_buses()     # Cài đặt audio buses
	_create_sfx_pool()       # Tạo pool cho SFX
	print("[AudioManager] Ready — SFX pool size: %d" % max_sfx_players)


# =============================================================================
# HÀM CÀI ĐẶT AUDIO BUSES (_setup_audio_buses)
# =============================================================================
# Cài đặt volume cho Master bus
# Audio bus là kênh âm thanh trong Godot

func _setup_audio_buses() -> void:
	# linear_to_db() chuyển 0.0-1.0 thành decibel (-∞ đến 0 dB)
	# Master bus luôn có index = 0
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))


# =============================================================================
# HÀM TẠO POOL SFX (_create_sfx_pool)
# =============================================================================
# Tạo sẵn các AudioStreamPlayer để tái sử dụng
# Tránh tạo node mới mỗi lần phát SFX (tốn hiệu năng)

func _create_sfx_pool() -> void:
	for i in max_sfx_players:
		# Tạo player mới
		var player := AudioStreamPlayer.new()
		player.volume_db = 0.0           # Mute ban đầu
		add_child(player)                 # Thêm vào scene
		sfx_players.append(player)       # Lưu vào pool


# =============================================================================
# HÀM PHÁT SFX (play_sfx)
# =============================================================================
# Phát một âm thanh hiệu ứng ngắn
#
# Tham số:
#   sfx_name: String - tên file SFX (không cần đuôi)
#     Ví dụ: "step_grass" sẽ tìm file "step_grass.wav" hoặc "step_grass.ogg"
#   volume_db: float - độ lớn âm thanh (-60 đến 0 dB)
#   pitch_scale: float - tốc độ phát (1.0 = bình thường, 2.0 = nhanh hơn)

func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	# Lấy một player rảnh từ pool
	var player: AudioStreamPlayer = _get_available_sfx_player()
	if player == null:
		return  # Pool đầy, không phát được

	# =================================================================
	# TÌM FILE ÂM THANH
	# =================================================================
	# Thử file .wav trước
	var path := "res://assets/audio/sfx/%s.wav" % sfx_name
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null

	# Nếu không có .wav, thử .ogg
	if stream == null:
		path = "res://assets/audio/sfx/%s.ogg" % sfx_name
		stream = load(path) if ResourceLoader.exists(path) else null

	# Nếu vẫn không tìm thấy file -> bỏ qua
	if stream == null:
		return

	# =================================================================
	# PHÁT ÂM THANH
	# =================================================================
	player.stream = stream          # Gán âm thanh
	player.volume_db = volume_db   # Đặt volume
	player.pitch_scale = pitch_scale  # Đặt tốc độ
	player.play()                  # Phát


# =============================================================================
# HÀM PHÁT NHẠC (play_music)
# =============================================================================
# Phát nhạc nền với hiệu ứng fade
#
# Tham số:
#   music_name: String - tên file nhạc (không cần đuôi)
#     Ví dụ: "tavern" sẽ phát "tavern.ogg"
#   fade_duration: float - thời gian fade (giây)

func play_music(music_name: String, fade_duration: float = 1.0) -> void:
	var path := "res://assets/audio/music/%s.ogg" % music_name
	
	# Kiểm tra file có tồn tại không
	if not ResourceLoader.exists(path):
		return

	var new_stream: AudioStream = load(path)
	if new_stream == null:
		return

	# =================================================================
	# FADE OUT NHẠC CŨ
	# =================================================================
	if current_music != null and current_music.playing:
		_fade_out_and_stop(current_music, fade_duration)

	# =================================================================
	# TẠO VÀ PHÁT NHẠC MỚI
	# =================================================================
	current_music = AudioStreamPlayer.new()
	current_music.stream = new_stream
	current_music.volume_db = -60.0  # Bắt đầu từ mute
	add_child(current_music)
	current_music.play()
	
	# Fade in
	_fade_in(current_music, fade_duration)


# =============================================================================
# HÀM PHÁT AMBIENT (play_ambient)
# =============================================================================
# Phát âm thanh nền (rừng, gió, mưa...)
# Tương tự play_music nhưng cho âm thanh nền
#
# Tham số:
#   ambient_name: String - tên file ambient
#   fade_duration: float - thời gian fade

func play_ambient(ambient_name: String, fade_duration: float = 2.0) -> void:
	var path := "res://assets/audio/ambient/%s.ogg" % ambient_name
	if not ResourceLoader.exists(path):
		return

	var new_stream: AudioStream = load(path)
	if new_stream == null:
		return

	if current_ambient != null and current_ambient.playing:
		_fade_out_and_stop(current_ambient, fade_duration)

	current_ambient = AudioStreamPlayer.new()
	current_ambient.stream = new_stream
	current_ambient.volume_db = -60.0
	current_ambient.stream_paused = false
	add_child(current_ambient)
	current_ambient.play()
	_fade_in(current_ambient, fade_duration)


# =============================================================================
# HÀM DỪNG NHẠC (stop_music)
# =============================================================================

func stop_music(fade_duration: float = 1.0) -> void:
	if current_music != null:
		_fade_out_and_stop(current_music, fade_duration)


# =============================================================================
# HÀM DỪNG AMBIENT (stop_ambient)
# =============================================================================

func stop_ambient(fade_duration: float = 2.0) -> void:
	if current_ambient != null:
		_fade_out_and_stop(current_ambient, fade_duration)


# =============================================================================
# HÀM ĐẶT VOLUME (set_*_volume)
# =============================================================================

# Đặt volume tổng (Master)
func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))

# Đặt volume SFX
func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)

# Đặt volume Music
func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)

# Đặt volume Ambient
func set_ambient_volume(value: float) -> void:
	ambient_volume = clamp(value, 0.0, 1.0)


# =============================================================================
# HÀM LẤY PLAYER SFX RẢNH (_get_available_sfx_player)
# =============================================================================
# Tìm một player trong pool đang rảnh
# Ưu tiên player không đang phát, hoặc đã phát quá nửa

func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		# Player không đang phát -> rảnh
		if not player.playing:
			return player
		# Player đã phát quá 0.5 giây -> có thể tái sử dụng
		if player.get_playback_position() > 0.5:
			return player
	return null


# =============================================================================
# HÀM FADE IN (_fade_in)
# =============================================================================
# Tăng volume từ mute lên bình thường
#
# Tham số:
#   player: AudioStreamPlayer - player cần fade
#   duration: float - thời gian fade (giây)

func _fade_in(player: AudioStreamPlayer, duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	# Tween volume từ -60 dB (mute) lên 0 dB (toàn volume)
	tween.tween_property(player, "volume_db", 0.0, duration)


# =============================================================================
# HÀM FADE OUT VÀ DỪNG (_fade_out_and_stop)
# =============================================================================
# Giảm volume xuống mute rồi dừng
#
# Tham số:
#   player: AudioStreamPlayer - player cần fade out
#   duration: float - thời gian fade

func _fade_out_and_stop(player: AudioStreamPlayer, duration: float) -> void:
	var tween := create_tween()
	# Tween volume từ 0 dB xuống -60 dB (mute)
	tween.tween_property(player, "volume_db", -60.0, duration)
	# Khi fade xong -> dừng và xóa player
	tween.finished.connect(_on_fade_out_complete.bind(player))


# =============================================================================
# HÀM XỬ LÝ FADE OUT HOÀN TẤT (_on_fade_out_complete)
# =============================================================================

func _on_fade_out_complete(player: AudioStreamPlayer) -> void:
	# Kiểm tra player còn hợp lệ (chưa bị xóa)
	if is_instance_valid(player):
		player.stop()      # Dừng phát
		player.queue_free()  # Xóa khỏi scene
