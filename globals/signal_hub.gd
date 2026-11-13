extends Node

# Core Boy Favorite Collection Signals
signal level_started(level: int)
signal item_collected(item_id: String, item_name: String, collected_count: int, total_count: int)
signal key_collected
signal cabinet_opened(item_id: String)
signal powerup_activated(powerup_type: String, duration: float)
signal coins_changed(total_coins: int)
signal level_victory(level: int, reward_coins: int)
signal level_failed(level: int, reason: String)

# Legacy / Shared Signals
signal add_scene_at_transform(at_transform: Transform3D, scene: PackedScene)
signal collected(type: GameDefs.PickUpType)
signal update_ui(scores: Dictionary[GameDefs.PickUpType, CollectibleScore])
signal show_key
signal level_completed
signal points(amount: int, at: Vector3)
signal score_changed(total: int)
signal player_health_changed(current: int)
signal player_hit


func emit_level_started(level: int) -> void:
	level_started.emit(level)


func emit_item_collected(item_id: String, item_name: String, collected_count: int, total_count: int) -> void:
	item_collected.emit(item_id, item_name, collected_count, total_count)


func emit_key_collected() -> void:
	key_collected.emit()
	show_key.emit()


func emit_cabinet_opened(item_id: String) -> void:
	cabinet_opened.emit(item_id)


func emit_powerup_activated(powerup_type: String, duration: float) -> void:
	powerup_activated.emit(powerup_type, duration)


func emit_coins_changed(total_coins: int) -> void:
	coins_changed.emit(total_coins)
	score_changed.emit(total_coins)


func emit_level_victory(level: int, reward_coins: int) -> void:
	level_victory.emit(level, reward_coins)
	level_completed.emit()


func emit_level_failed(level: int, reason: String) -> void:
	level_failed.emit(level, reason)
	player_hit.emit()


func emit_player_hit() -> void:
	player_hit.emit()


func emit_player_health_changed(current: int) -> void:
	player_health_changed.emit(current)


func emit_score_changed(total: int) -> void:
	score_changed.emit(total)


func emit_points(amount: int, at: Vector3) -> void:
	points.emit(amount, at)


func emit_level_completed() -> void:
	level_completed.emit()


func emit_show_key() -> void:
	show_key.emit()


func emit_update_ui(scores: Dictionary[GameDefs.PickUpType, CollectibleScore]) -> void:
	update_ui.emit(scores)


func emit_add_scene_at_transform(at_transform: Transform3D, scene: PackedScene) -> void:
	add_scene_at_transform.emit(at_transform, scene)


func emit_collected(type: GameDefs.PickUpType) -> void:
	collected.emit(type)
