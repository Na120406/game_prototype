extends Node

var current_music: AudioStreamPlayer
var current_ambient: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var max_sfx_players: int = 8

var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 0.8
var ambient_volume: float = 0.6

func _ready() -> void:
	_setup_audio_buses()
	_create_sfx_pool()
	print("[AudioManager] Ready — SFX pool size: %d" % max_sfx_players)

func _setup_audio_buses() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear_to_db(master_volume))

func _create_sfx_pool() -> void:
	for i in max_sfx_players:
		var player := AudioStreamPlayer.new()
		player.volume_db = 0.0
		add_child(player)
		sfx_players.append(player)

func play_sfx(sfx_name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	var player: AudioStreamPlayer = _get_available_sfx_player()
	if player == null:
		return

	var path := "res://assets/audio/sfx/%s.wav" % sfx_name
	var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null

	if stream == null:
		path = "res://assets/audio/sfx/%s.ogg" % sfx_name
		stream = load(path) if ResourceLoader.exists(path) else null

	if stream == null:
		return

	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

func play_music(music_name: String, fade_duration: float = 1.0) -> void:
	var path := "res://assets/audio/music/%s.ogg" % music_name
	if not ResourceLoader.exists(path):
		return

	var new_stream: AudioStream = load(path)
	if new_stream == null:
		return

	if current_music != null and current_music.playing:
		_fade_out_and_stop(current_music, fade_duration)

	current_music = AudioStreamPlayer.new()
	current_music.stream = new_stream
	current_music.volume_db = -60.0
	add_child(current_music)
	current_music.play()
	_fade_in(current_music, fade_duration)

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

func stop_music(fade_duration: float = 1.0) -> void:
	if current_music != null:
		_fade_out_and_stop(current_music, fade_duration)

func stop_ambient(fade_duration: float = 2.0) -> void:
	if current_ambient != null:
		_fade_out_and_stop(current_ambient, fade_duration)

func set_master_volume(value: float) -> void:
	master_volume = clamp(value, 0.0, 1.0)
	AudioServer.set_bus_volume_db(0, linear_to_db(master_volume))

func set_sfx_volume(value: float) -> void:
	sfx_volume = clamp(value, 0.0, 1.0)

func set_music_volume(value: float) -> void:
	music_volume = clamp(value, 0.0, 1.0)

func set_ambient_volume(value: float) -> void:
	ambient_volume = clamp(value, 0.0, 1.0)

func _get_available_sfx_player() -> AudioStreamPlayer:
	for player in sfx_players:
		if not player.playing:
			return player
		if player.get_playback_position() > 0.5:
			return player
	return null

func _fade_in(player: AudioStreamPlayer, duration: float) -> void:
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(player, "volume_db", 0.0, duration)

func _fade_out_and_stop(player: AudioStreamPlayer, duration: float) -> void:
	var tween := create_tween()
	tween.tween_property(player, "volume_db", -60.0, duration)
	tween.finished.connect(_on_fade_out_complete.bind(player))

func _on_fade_out_complete(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player):
		player.stop()
		player.queue_free()
