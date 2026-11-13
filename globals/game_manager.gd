extends Node

const SAVE_PATH: String = "user://boy_favorite_save.cfg"

const POWERUP_COIN_COST: int = 10
const SPEED_UNLOCK_LEVEL: int = 1
const INVIS_UNLOCK_LEVEL: int = 5
const BYPASS_WALL_UNLOCK_LEVEL: int = 10

var current_level: int = 1
var highest_unlocked_level: int = 1
var coins: int = 1577
var is_privacy_policy_accepted: bool = false
var is_ads_removed: bool = false
var music_enabled: bool = true
var sfx_enabled: bool = true
var state: GameState = null
var ad_manager: Node = null


func _ready() -> void:
	state = GameState.new()
	load_game_state()
	_init_ad_manager()
	if SignalHub != null:
		SignalHub.level_started.connect(_on_level_started)
		SignalHub.level_victory.connect(_on_level_victory)


func _init_ad_manager() -> void:
	if not get_tree().root.has_node("AdManager"):
		var ad_mgr_script := load("res://globals/ad_manager.gd") as Script
		if ad_mgr_script != null:
			ad_manager = ad_mgr_script.new()
			ad_manager.name = "AdManager"
			get_tree().root.add_child.call_deferred(ad_manager)
			if is_ads_removed and ad_manager.has_method("remove_all_ads"):
				ad_manager.call_deferred("remove_all_ads")


func get_powerup_unlock_level(powerup_type: String) -> int:
	match powerup_type.to_lower():
		"speed":
			return SPEED_UNLOCK_LEVEL
		"invisible", "invis":
			return INVIS_UNLOCK_LEVEL
		"bypass_wall", "wall_pass", "pass_wall":
			return BYPASS_WALL_UNLOCK_LEVEL
		_:
			return 1


func is_powerup_unlocked(powerup_type: String, lvl: int = -1) -> bool:
	var check_lvl := current_level if lvl < 0 else lvl
	return check_lvl >= get_powerup_unlock_level(powerup_type)


func try_spend_coins(amount: int = POWERUP_COIN_COST) -> bool:
	if coins < amount:
		return false
	coins -= amount
	save_game_state()
	if SignalHub != null:
		SignalHub.emit_coins_changed(coins)
	return true


func add_coins(amount: int) -> void:
	coins += amount
	save_game_state()
	if SignalHub != null:
		SignalHub.emit_coins_changed(coins)


func _on_level_started(level: int) -> void:
	current_level = level
	if level > highest_unlocked_level:
		highest_unlocked_level = level
	save_game_state()


func _on_level_victory(level: int, _reward_coins: int) -> void:
	if level + 1 > highest_unlocked_level:
		highest_unlocked_level = level + 1
	save_game_state()


func set_privacy_policy_accepted(accepted: bool = true) -> void:
	is_privacy_policy_accepted = accepted
	if state != null:
		state.is_privacy_policy_accepted = accepted
	save_game_state()


func set_ads_removed(removed: bool = true) -> void:
	is_ads_removed = removed
	save_game_state()
	var ad_mgr = get_tree().root.get_node_or_null("AdManager")
	if ad_mgr != null and ad_mgr.has_method("remove_all_ads"):
		ad_mgr.remove_all_ads()


func set_audio_settings(p_music: bool, p_sfx: bool) -> void:
	music_enabled = p_music
	sfx_enabled = p_sfx
	save_game_state()
	if SoundManager != null:
		SoundManager.set_music_enabled(music_enabled)
		SoundManager.set_sfx_enabled(sfx_enabled)


func save_game_state() -> void:
	if state != null:
		state.current_level = current_level
		state.highest_unlocked_level = highest_unlocked_level
		state.coins = coins
		state.is_privacy_policy_accepted = is_privacy_policy_accepted
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "current_level", current_level)
	cfg.set_value("progress", "highest_unlocked_level", highest_unlocked_level)
	cfg.set_value("economy", "coins", coins)
	cfg.set_value("settings", "privacy_policy_accepted", is_privacy_policy_accepted)
	cfg.set_value("settings", "is_ads_removed", is_ads_removed)
	cfg.set_value("settings", "music_enabled", music_enabled)
	cfg.set_value("settings", "sfx_enabled", sfx_enabled)
	cfg.save(SAVE_PATH)


func load_game_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		highest_unlocked_level = int(cfg.get_value("progress", "highest_unlocked_level", 1))
		coins = int(cfg.get_value("economy", "coins", 1577))
		current_level = int(cfg.get_value("progress", "current_level", 1))
		is_privacy_policy_accepted = bool(cfg.get_value("settings", "privacy_policy_accepted", false))
		is_ads_removed = bool(cfg.get_value("settings", "is_ads_removed", false))
		music_enabled = bool(cfg.get_value("settings", "music_enabled", true))
		sfx_enabled = bool(cfg.get_value("settings", "sfx_enabled", true))
	if state != null:
		state.current_level = current_level
		state.highest_unlocked_level = highest_unlocked_level
		state.coins = coins
		state.is_privacy_policy_accepted = is_privacy_policy_accepted
	if SoundManager != null:
		SoundManager.set_music_enabled(music_enabled)
		SoundManager.set_sfx_enabled(sfx_enabled)
