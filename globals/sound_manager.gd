extends Node

const POOL_SIZE: int = 10

var _players_3d: Array[AudioStreamPlayer3D] = []
var _players_2d: Array[AudioStreamPlayer] = []
var _bgm_player: AudioStreamPlayer = null
var _footstep_player: AudioStreamPlayer = null
var _streams: Dictionary = {}
var _last_footstep_ms: int = 0
var _last_locked_sfx_ms: int = 0

var sfx_enabled: bool = true
var music_enabled: bool = true

func set_music_enabled(val: bool) -> void:
	music_enabled = val
	if not music_enabled:
		stop_or_duck_bgm(true)
	else:
		start_bgm()

func set_sfx_enabled(val: bool) -> void:
	sfx_enabled = val

func _ready() -> void:
	for i in POOL_SIZE:
		add_player_3d()
		add_player_2d()
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGMPlayer"
	_bgm_player.volume_db = -9.0
	add_child(_bgm_player)

	_footstep_player = AudioStreamPlayer.new()
	_footstep_player.name = "FootstepPlayer"
	_footstep_player.volume_db = -8.0
	add_child(_footstep_player)

	_load_all_sounds()
	start_bgm()

func _load_audio(res_path: String, make_loop: bool = false) -> AudioStream:
	var global_path := ProjectSettings.globalize_path(res_path)
	var ext := res_path.get_extension().to_lower()
	if FileAccess.file_exists(global_path):
		if ext == "mp3":
			var mp3 := AudioStreamMP3.load_from_file(global_path)
			if mp3 == null:
				var bytes := FileAccess.get_file_as_bytes(global_path)
				if not bytes.is_empty():
					mp3 = AudioStreamMP3.new()
					mp3.data = bytes
			if mp3 != null:
				mp3.loop = make_loop
				return mp3
		elif ext == "wav":
			var wav := AudioStreamWAV.load_from_file(global_path)
			if wav != null:
				if make_loop:
					wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
				return wav
	if ResourceLoader.exists(res_path):
		var s := load(res_path) as AudioStream
		if s is AudioStreamMP3 and make_loop:
			(s as AudioStreamMP3).loop = true
		return s
	return null

func _load_all_sounds() -> void:
	# Game sounds from assets/sounds/game/
	_streams["bgm"] = _load_audio("res://assets/sounds/game/backgroudmusic.mp3", true)
	_streams["boy_catch"] = _load_audio("res://assets/sounds/game/boy_catch.mp3")
	_streams["boy_complete_level"] = _load_audio("res://assets/sounds/game/boy_complete_level.mp3")
	_streams["coin_sound"] = _load_audio("res://assets/sounds/game/coin_sound.wav")
	_streams["level_fail"] = _load_audio("res://assets/sounds/game/level_fail.mp3")
	_streams["star_sound"] = _load_audio("res://assets/sounds/game/star_sound.mp3")
	_streams["wrong_answer"] = _load_audio("res://assets/sounds/game/wrong_answer.mp3")

	# Movement & environment sounds from assets/sounds/
	_streams["footsteps"] = _load_audio("res://assets/sounds/granny/player_footsteps.wav")
	_streams["jump"] = _load_audio("res://assets/sounds/granny/player_jump.wav")
	_streams["land"] = _load_audio("res://assets/sounds/granny/player_land.wav")
	_streams["shoot"] = _load_audio("res://assets/sounds/granny/player_shoot.wav")
	_streams["spin"] = _load_audio("res://assets/sounds/projectiles/361222__rollin_pin_spin.wav")

func start_bgm() -> void:
	if not music_enabled or not is_instance_valid(_bgm_player):
		return
	var bgm_stream: AudioStream = _streams.get("bgm")
	if bgm_stream == null:
		return
	_bgm_player.volume_db = -9.0
	_bgm_player.stream_paused = false
	if _bgm_player.stream != bgm_stream or not _bgm_player.playing:
		_bgm_player.stream = bgm_stream
		_bgm_player.play()

func stop_or_duck_bgm(pause_bgm: bool = true) -> void:
	if not is_instance_valid(_bgm_player):
		return
	if pause_bgm:
		_bgm_player.stream_paused = true
	else:
		_bgm_player.volume_db = -22.0

func add_player_3d() -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	add_child(player)
	_players_3d.append(player)
	return player

func add_player_2d() -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	add_child(player)
	_players_2d.append(player)
	return player

func get_available_3d() -> AudioStreamPlayer3D:
	for player in _players_3d:
		if not player.playing:
			return player
	return add_player_3d()

func get_available_2d() -> AudioStreamPlayer:
	for player in _players_2d:
		if not player.playing:
			return player
	return add_player_2d()

func play_3d(stream: AudioStream, pos: Vector3) -> void:
	if stream == null:
		return
	var player := get_available_3d()
	player.stream = stream
	player.global_position = pos
	player.play()

func _play_stream_2d(stream: AudioStream, pitch: float = 1.0, vol_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := get_available_2d()
	player.stream = stream
	player.pitch_scale = pitch
	player.volume_db = vol_db
	player.play()

func play_sfx(event_name: String, pitch: float = 1.0, vol_db: float = -1.5) -> void:
	if not sfx_enabled:
		return
	match event_name:
		"start":
			start_bgm()
			_play_stream_2d(_streams.get("star_sound"), 1.0, -2.0)
		"button":
			_play_stream_2d(_streams.get("star_sound"), 1.15, -2.0)
		"collect":
			_play_stream_2d(_streams.get("star_sound"), 1.0, 0.0)
		"key":
			_play_stream_2d(_streams.get("star_sound"), 1.12, 0.0)
		"coin":
			_play_stream_2d(_streams.get("coin_sound"), randf_range(0.96, 1.08), -1.0)
		"locked", "wrong":
			var now := Time.get_ticks_msec()
			if now - _last_locked_sfx_ms >= 900:
				_last_locked_sfx_ms = now
				_play_stream_2d(_streams.get("wrong_answer"), 1.0, -1.0)
		"powerup_speed":
			_play_stream_2d(_streams.get("star_sound"), 1.2, -1.0)
		"powerup_invisible":
			_play_stream_2d(_streams.get("star_sound"), 0.95, -1.0)
		"powerup_wall":
			_play_stream_2d(_streams.get("star_sound"), 1.08, -1.0)
		"powerup":
			_play_stream_2d(_streams.get("star_sound"), 1.1, -1.0)
		"cabinet", "door":
			_play_stream_2d(_streams.get("land"), 1.1, -4.0)
		"victory", "level_complete":
			# Instantly pause BGM and play boy_complete_level.mp3!
			stop_or_duck_bgm(true)
			_play_stream_2d(_streams.get("boy_complete_level"), 1.0, 0.0)
			_play_stream_2d(_streams.get("star_sound"), 1.05, -2.0)
		"fail", "level_fail", "catch":
			# Instantly pause BGM and play both boy_catch.mp3 and level_fail.mp3!
			stop_or_duck_bgm(true)
			_play_stream_2d(_streams.get("boy_catch"), 1.0, 0.0)
			_play_stream_2d(_streams.get("level_fail"), 1.0, 0.0)
		_:
			_play_stream_2d(_streams.get(event_name), pitch, vol_db)

func play_footstep() -> void:
	if not sfx_enabled:
		return
	var now := Time.get_ticks_msec()
	if now - _last_footstep_ms < 320:
		return
	_last_footstep_ms = now
	var stream: AudioStream = _streams.get("footsteps")
	if stream == null or not is_instance_valid(_footstep_player):
		return
	if not _footstep_player.playing:
		_footstep_player.stream = stream
		_footstep_player.pitch_scale = randf_range(0.92, 1.12)
		_footstep_player.play()
