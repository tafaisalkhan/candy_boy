class_name GameState
extends RefCounted

# Player & Economy State
var current_level: int = 1
var highest_unlocked_level: int = 1
var coins: int = 1577
var is_privacy_policy_accepted: bool = false

# Powerup Unlock Rules
var powerup_unlock_rules: Dictionary = {
	"speed": 1,
	"invisible": 5,
	"bypass_wall": 10
}

# Active Runtime Session State
var session_collected_items: Array[String] = []
var session_target_items: Array[Dictionary] = []
var is_player_invisible: bool = false
var is_player_wall_pass: bool = false
var is_speed_boost_active: bool = false
var speed_boost_time_left: float = 0.0
var invis_time_left: float = 0.0
var wall_pass_time_left: float = 0.0


func to_dict() -> Dictionary:
	return {
		"current_level": current_level,
		"highest_unlocked_level": highest_unlocked_level,
		"coins": coins,
		"powerup_unlock_rules": powerup_unlock_rules
	}


func from_dict(data: Dictionary) -> void:
	current_level = int(data.get("current_level", 1))
	highest_unlocked_level = int(data.get("highest_unlocked_level", 1))
	coins = int(data.get("coins", 1577))
	if data.has("powerup_unlock_rules") and data["powerup_unlock_rules"] is Dictionary:
		powerup_unlock_rules = data["powerup_unlock_rules"]


func to_json_string() -> String:
	return JSON.stringify(to_dict(), "\t")


func from_json_string(json_str: String) -> bool:
	var parsed = JSON.parse_string(json_str)
	if parsed is Dictionary:
		from_dict(parsed)
		return true
	return false


func is_powerup_unlocked(powerup_id: String, check_level: int = -1) -> bool:
	var lvl := current_level if check_level < 0 else check_level
	var req_lvl: int = int(powerup_unlock_rules.get(powerup_id.to_lower(), 1))
	return lvl >= req_lvl


func reset_session() -> void:
	session_collected_items.clear()
	session_target_items.clear()
	is_player_invisible = false
	is_player_wall_pass = false
	is_speed_boost_active = false
	speed_boost_time_left = 0.0
	invis_time_left = 0.0
	wall_pass_time_left = 0.0
