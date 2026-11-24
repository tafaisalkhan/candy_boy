extends Node

const SAVE_PATH: String = "user://boy_favorite_save.cfg"

const POWERUP_COIN_COST: int = 10
const SPEED_UNLOCK_LEVEL: int = 1
const INVIS_UNLOCK_LEVEL: int = 5
const BYPASS_WALL_UNLOCK_LEVEL: int = 10

const DAILY_STEP_COINS: int = 20
const DAILY_MAX_DAYS: int = 7
const MAX_UPGRADE_LEVEL: int = 5
const DAILY_CHALLENGE_BONUS_COINS: int = 150

var current_level: int = 1
var highest_unlocked_level: int = 1
var coins: int = 1577
var is_privacy_policy_accepted: bool = false
var is_ads_removed: bool = false
var has_entered_gameplay: bool = false
var home_support_shown_this_launch: bool = false
var last_support_popup: String = ""
var last_daily_claim: String = ""
var daily_streak_day: int = 0
var last_daily_challenge_date: String = ""
var playing_daily_challenge: bool = false
var upgrades: Dictionary = {
	"sneakers": 0,
	"cloak": 0,
	"wall_battery": 0,
	"piggy_bank": 0,
}
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


func upgrade_level(key: String) -> int:
	return int(upgrades.get(key, 0))


func upgrade_cost(key: String) -> int:
	return 40 * (upgrade_level(key) + 1)


func buy_upgrade(key: String) -> bool:
	var lvl := upgrade_level(key)
	if lvl >= MAX_UPGRADE_LEVEL:
		return false
	var cost := upgrade_cost(key)
	if not try_spend_coins(cost):
		return false
	upgrades[key] = lvl + 1
	save_game_state()
	return true


func current_daily_day_number() -> int:
	return (daily_streak_day % DAILY_MAX_DAYS) + 1


func next_daily_reward_coins() -> int:
	return current_daily_day_number() * DAILY_STEP_COINS


func can_claim_daily_bonus() -> bool:
	var today := Time.get_date_string_from_system()
	return last_daily_claim != today


func claim_daily_bonus() -> int:
	if not can_claim_daily_bonus():
		return 0
	var reward := next_daily_reward_coins()
	last_daily_claim = Time.get_date_string_from_system()
	daily_streak_day = (daily_streak_day + 1) % DAILY_MAX_DAYS
	add_coins(reward)
	return reward


func is_daily_challenge_done_today() -> bool:
	return last_daily_challenge_date == Time.get_date_string_from_system()


func daily_challenge_level_number() -> int:
	var d := Time.get_date_dict_from_system()
	return 5 + ((int(d.year) * 372 + int(d.month) * 31 + int(d.day)) % 25)


func mark_daily_challenge_completed() -> void:
	last_daily_challenge_date = Time.get_date_string_from_system()
	save_game_state()


func pick_random_support_popup() -> String:
	randomize()
	var choices: Array[String] = ["rate", "share", "coffee"]
	if last_support_popup != "" and choices.size() > 1:
		choices.erase(last_support_popup)
	var picked: String = choices[randi() % choices.size()]
	last_support_popup = picked
	save_game_state()
	return picked


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
	if playing_daily_challenge:
		playing_daily_challenge = false
		if not is_daily_challenge_done_today():
			mark_daily_challenge_completed()
			add_coins(DAILY_CHALLENGE_BONUS_COINS)
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
	cfg.set_value("progress", "last_daily_claim", last_daily_claim)
	cfg.set_value("progress", "daily_streak_day", daily_streak_day)
	cfg.set_value("progress", "last_daily_challenge_date", last_daily_challenge_date)
	cfg.set_value("economy", "coins", coins)
	cfg.set_value("settings", "privacy_policy_accepted", is_privacy_policy_accepted)
	cfg.set_value("settings", "is_ads_removed", is_ads_removed)
	cfg.set_value("settings", "music_enabled", music_enabled)
	cfg.set_value("settings", "sfx_enabled", sfx_enabled)
	cfg.set_value("settings", "last_support_popup", last_support_popup)
	for k in upgrades.keys():
		cfg.set_value("upgrades", k, int(upgrades[k]))
	cfg.save(SAVE_PATH)


func load_game_state() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		highest_unlocked_level = int(cfg.get_value("progress", "highest_unlocked_level", 1))
		coins = int(cfg.get_value("economy", "coins", 1577))
		current_level = int(cfg.get_value("progress", "current_level", 1))
		last_daily_claim = str(cfg.get_value("progress", "last_daily_claim", ""))
		daily_streak_day = clampi(int(cfg.get_value("progress", "daily_streak_day", 0)), 0, 6)
		last_daily_challenge_date = str(cfg.get_value("progress", "last_daily_challenge_date", ""))
		is_privacy_policy_accepted = bool(cfg.get_value("settings", "privacy_policy_accepted", false))
		is_ads_removed = bool(cfg.get_value("settings", "is_ads_removed", false))
		music_enabled = bool(cfg.get_value("settings", "music_enabled", true))
		sfx_enabled = bool(cfg.get_value("settings", "sfx_enabled", true))
		last_support_popup = str(cfg.get_value("settings", "last_support_popup", ""))
		for k in upgrades.keys():
			upgrades[k] = clampi(int(cfg.get_value("upgrades", k, 0)), 0, MAX_UPGRADE_LEVEL)
	if state != null:
		state.current_level = current_level
		state.highest_unlocked_level = highest_unlocked_level
		state.coins = coins
		state.is_privacy_policy_accepted = is_privacy_policy_accepted
	if SoundManager != null:
		SoundManager.set_music_enabled(music_enabled)
		SoundManager.set_sfx_enabled(sfx_enabled)
