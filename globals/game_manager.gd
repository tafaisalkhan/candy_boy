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
	cfg.save(SAVE_PATH)


func load_game_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		highest_unlocked_level = int(cfg.get_value("progress", "highest_unlocked_level", 1))
		coins = int(cfg.get_value("economy", "coins", 1577))
		current_level = int(cfg.get_value("progress", "current_level", 1))
		is_privacy_policy_accepted = bool(cfg.get_value("settings", "privacy_policy_accepted", false))
	if state != null:
		state.current_level = current_level
		state.highest_unlocked_level = highest_unlocked_level
		state.coins = coins
		state.is_privacy_policy_accepted = is_privacy_policy_accepted
