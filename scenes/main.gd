extends Node3D

const FootstepManager = preload("res://components/footstep_manager.gd")
const DoorController = preload("res://components/door_controller.gd")
const LaserBarrier = preload("res://components/laser_barrier.gd")
const FloorButton = preload("res://components/floor_button.gd")
const KeyPickup = preload("res://components/key_pickup.gd")
const PushableProp = preload("res://components/pushable_prop.gd")
const SecurityCamera = preload("res://components/security_camera.gd")
const GuardController = preload("res://components/guard_controller.gd")
const StationProps = preload("res://components/station_props.gd")
const HomeFurniture = preload("res://components/home_furniture.gd")
const OutdoorScenery = preload("res://components/outdoor_scenery.gd")
const CollectibleItem = preload("res://components/collectible_item.gd")
const RoomCompartmentBuilder = preload("res://components/room_compartment_builder.gd")
const LevelGenerator = preload("res://components/level_generator.gd")
const SubwayScenery = preload("res://components/subway_scenery.gd")

@export var current_level: int = 1

var floor_tile_texture: ImageTexture = null
var level_exit_pos: Vector3 = Vector3(999.0, 0.0, 999.0)

# Core References
var level_root: Node3D = null
var main_camera: Camera3D = null
var hud_root: CanvasLayer = null
var player_root: Node3D = null
var player_mesh: Node3D = null
var player_anim: AnimationPlayer = null
var player_ring: Node3D = null
var footstep_mgr: FootstepManager = null

# Active Entities & Colliders
var wall_colliders: Array[AABB] = []
var active_lasers: Dictionary = {} # id -> LaserBarrier
var active_buttons: Array[FloorButton] = []
var active_doors: Array[DoorController] = []
var active_guards: Array[GuardController] = []
var active_cameras: Array[SecurityCamera] = []
var active_keys: Array[KeyPickup] = []
var active_props: Array[PushableProp] = []
var candy_node: Node3D = null
var candy_pos: Vector3 = Vector3.ZERO
var candy_spawn_pos: Vector3 = Vector3.ZERO
var cupboard_root: Node3D = null
var cupboard_door_left: Node3D = null
var cupboard_door_right: Node3D = null
var cupboard_prompt: Label3D = null
var is_cupboard_open: bool = false

# Item Collection System
var target_items: Array[Dictionary] = []
var collected_items_count: int = 0
var target_items_total: int = 0
var all_items_collected: bool = false
var active_containers: Array[Dictionary] = []
var active_open_items: Array[Dictionary] = []
var item_collector_panel: PanelContainer = null
var item_collector_label: Label = null

# Granny Intelligence Streak Tracker
var levels_completed_streak: int = 0
var is_intelligent_granny_active: bool = false

# Mobile Virtual Joystick & Touch Movement
var is_touch_active: bool = false
var touch_start_pos: Vector2 = Vector2.ZERO
var touch_move_dir: Vector3 = Vector3.ZERO
var joystick_base: Panel = null
var joystick_knob: Panel = null
var item_slot_panels: Array[Panel] = []
var item_slot_badges: Array[Label] = []

# State
var is_game_active: bool = false
var is_level_cleared: bool = false
var is_spotted: bool = false
var player_has_key: bool = false
var candy_collected: bool = false
var auto_walk_forward: bool = false
var auto_walk_loop: bool = false
var coins: int = 1577
var player_target_rotation: float = 0.0
var player_spawn_pos: Vector3 = Vector3.ZERO
var entrance_door_pos: Vector3 = Vector3(0.0, 0.0, 8.0)
var entrance_outside_pos: Vector3 = Vector3(0.0, 0.0, 11.2)
var is_entering_level: bool = false
var spawn_marker_label: Label3D = null
var spawn_marker_border_mat: StandardMaterial3D = null
var spawn_marker_pos: Vector3 = Vector3.ZERO
var active_level_data: Dictionary = {}

# Powerups State (Speed, Invisibility, and Wall Pass)
var speed_boost_time: float = 0.0
var speed_boost_cooldown: float = 0.0
var invisibility_time: float = 0.0
var invisibility_cooldown: float = 0.0
var is_player_invisible: bool = false
var wall_pass_time: float = 0.0
var is_wall_pass_active: bool = false
var active_powerups: Array[Dictionary] = []

# UI References
var victory_popup: Control = null
var fail_popup: Control = null
var privacy_popup: Control = null
var coin_lbl: Label = null
var coin_panel: PanelContainer = null
var speed_badge_lbl: Label = null
var ghost_badge_lbl: Label = null
var shield_badge_lbl: Label = null
var speed_btn_refs: Dictionary = {}
var shield_btn_refs: Dictionary = {}
var ghost_btn_refs: Dictionary = {}
var game_title_font: Font = null
var game_body_font: Font = null

# Cinematic Camera Intro Sequence & Mission Popup
var is_intro_cinematic_active: bool = false
var intro_cinematic_tween: Tween = null
var mission_intro_popup: Control = null

# Cinematic Catch Sequence
var is_catch_cinematic_active: bool = false
var catch_letterbox_layer: CanvasLayer = null
var catch_cinematic_tween: Tween = null

# Constants
const PLAYER_SPEED: float = 4.0
const WALL_H: float = 2.6
const WALL_T: float = 0.35
const POWERUP_COIN_COST: int = 10
const SPEED_UNLOCK_LEVEL: int = 1
const INVIS_UNLOCK_LEVEL: int = 5
const BYPASS_WALL_UNLOCK_LEVEL: int = 10
const BOY_MODEL_PATH: String = "res://assets/models/boys/Model/characterMedium.fbx"

func _init_game_fonts() -> void:
	var tf := FontFile.new()
	if tf.load_dynamic_font(ProjectSettings.globalize_path("res://assets/fonts/LuckiestGuy-Regular.ttf")) == OK:
		game_title_font = tf
	game_body_font = game_title_font

func _ready() -> void:
	_init_game_fonts()
	var all_args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	for arg in all_args:
		if arg.begins_with("--level="):
			current_level = int(arg.trim_prefix("--level="))

	footstep_mgr = FootstepManager.new()
	add_child(footstep_mgr)
	_setup_environment()
	_setup_hud()

	if GameManager != null:
		GameManager.has_entered_gameplay = true
		coins = GameManager.coins
		if SignalHub != null:
			SignalHub.coins_changed.connect(_on_coins_changed)

	load_level(current_level)

	# Show both top and bottom banners during intro/menu overlay
	_set_ad_banner_mode(false)

	if "--screen-game" in all_args or "--screenshot" in all_args or FileAccess.file_exists("res://test_screenshot.flag"):
		if FileAccess.file_exists("res://test_screenshot.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_screenshot.flag"))
		_capture_and_quit()
	elif "--test-door" in all_args:
		auto_walk_forward = true
		_test_door_passage()
	elif "--test-loop" in all_args or FileAccess.file_exists("res://test_loop.flag"):
		if FileAccess.file_exists("res://test_loop.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_loop.flag"))
		auto_walk_loop = true
		_test_candy_loop()
	elif "--test-victory" in all_args or FileAccess.file_exists("res://test_victory.flag"):
		if FileAccess.file_exists("res://test_victory.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_victory.flag"))
		_test_victory_popup()
	elif "--test-powerup" in all_args or FileAccess.file_exists("res://test_powerup.flag"):
		if FileAccess.file_exists("res://test_powerup.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_powerup.flag"))
		_test_powerups()
	elif "--test-fail" in all_args or FileAccess.file_exists("res://test_fail.flag"):
		if FileAccess.file_exists("res://test_fail.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_fail.flag"))
		_test_fail_popup()
	elif "--test-cupboard" in all_args or FileAccess.file_exists("res://test_cupboard.flag"):
		if FileAccess.file_exists("res://test_cupboard.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_cupboard.flag"))
		_test_cupboard_opening()
	elif "--view-room1" in all_args:
		_test_view_room1()
	elif "--test-rewarded-powerup" in all_args or FileAccess.file_exists("res://test_rewarded_powerup.flag"):
		if FileAccess.file_exists("res://test_rewarded_powerup.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_rewarded_powerup.flag"))
		_test_rewarded_powerup_prompt()
	elif "--test-mission-intro" in all_args or FileAccess.file_exists("res://test_mission_intro.flag"):
		if FileAccess.file_exists("res://test_mission_intro.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_mission_intro.flag"))
		_test_mission_intro_screenshot()
	elif "--test-touch" in all_args:
		_test_mobile_touch_movement()
	elif "--test-granny-hud" in all_args:
		_run_granny_hud_test()
	elif GameManager != null and not GameManager.is_privacy_policy_accepted:
		call_deferred("_show_privacy_policy_popup")

func _show_privacy_policy_popup() -> void:
	if is_instance_valid(privacy_popup) or not is_instance_valid(hud_root):
		return
	var scene := load("res://scenes/popups/privacy_policy_popup.tscn") as PackedScene
	if scene != null:
		privacy_popup = scene.instantiate()
		privacy_popup.accepted.connect(func():
			if GameManager != null:
				GameManager.set_privacy_policy_accepted(true)
			privacy_popup = null
		)
		hud_root.add_child(privacy_popup)

func _run_granny_hud_test() -> void:
	print("--- BEGIN GRANNY & HUD VERIFICATION ---")
	# 1. Test HUD visibility
	print("1. Checking HUD elements...")
	assert(item_collector_label != null, "item_collector_label must exist")
	assert(item_collector_label.visible == true, "item_collector_label must be visible in find item pill")
	assert(item_collector_panel != null, "item_collector_panel must exist")
	var obj_lbl = hud_root.get_node_or_null("ObjectiveLabel")
	if obj_lbl != null:
		assert(obj_lbl.visible == false, "ObjectiveLabel must be hidden")
	print("   HUD elements check: PASSED (Top-Center Find Item Pill is active)")

	# 2. Test Granny Intelligence Progression
	print("2. Checking Granny Intelligence Cycle...")
	assert(levels_completed_streak == 0, "Initial streak should be 0")
	assert(is_intelligent_granny_active == false, "Granny should be normal on level 1")

	# Win level 1
	_on_continue_pressed()
	assert(levels_completed_streak == 1, "Streak should be 1 after 1 win")
	assert(is_intelligent_granny_active == false, "Granny should be normal on level 2")

	# Win level 2
	_on_continue_pressed()
	assert(levels_completed_streak == 2, "Streak should be 2 after 2 wins")
	assert(is_intelligent_granny_active == true, "Granny MUST be intelligent on level 3!")
	print("   Level 3 Granny Intelligence: ACTIVE! (Streak: %d)" % levels_completed_streak)

	# Verify guard in level 3 is intelligent
	var has_intelligent_guard := false
	for g in active_guards:
		if is_instance_valid(g) and g.is_intelligent:
			has_intelligent_guard = true
			break
	assert(has_intelligent_guard, "Active guards on level 3 must be intelligent")
	print("   Guard controller intelligent mode: PASSED")

	# 3. Test Retry Reset
	print("3. Checking Retry Reset behavior...")
	_on_retry_pressed()
	assert(levels_completed_streak == 0, "Streak MUST reset to 0 on retry/restart")
	assert(is_intelligent_granny_active == false, "Granny MUST NOT be intelligent on retry")
	for g in active_guards:
		if is_instance_valid(g):
			assert(g.is_intelligent == false, "Guard must be back to normal on retry")
	print("   Retry reset check: PASSED (Granny normal after restart)")

	# 4. Test Complete After Intelligent Granny
	print("4. Checking Cycle Repeat after beating intelligent level...")
	levels_completed_streak = 2
	load_level(current_level)
	assert(is_intelligent_granny_active == true, "Granny is intelligent")
	_on_continue_pressed()
	assert(levels_completed_streak == 0, "Streak must reset after intelligent level is won")
	assert(is_intelligent_granny_active == false, "Granny must return to normal after beating smart granny")
	print("   Cycle repeat check: PASSED")

	# 5. Test Mission Intro Popup
	print("5. Checking Mission Intro Popup item cards...")
	var popup_scene := load("res://scenes/popups/mission_intro_popup.tscn") as PackedScene
	var popup = popup_scene.instantiate()
	hud_root.add_child(popup)
	popup.set_target_items([{"icon": "🍭", "name": "candy"}, {"icon": "🧸", "name": "teddy"}])
	for card in popup.items_hbox.get_children():
		var vbox = card.get_child(0)
		assert(vbox.get_child_count() == 1, "Only 1 child (icon_lbl) should exist in card vbox, no name description!")
	print("   Mission Intro Popup check: PASSED (Only item icons shown, no descriptions)")
	popup.queue_free()

	# 6. Test Smart Granny Hunting in Section & Power-up Evasion
	print("6. Checking Smart Granny Hunting & Power-up Evasion...")
	levels_completed_streak = 2
	load_level(1)
	assert(active_guards.size() > 0, "Must have guards")
	var smart_guard = active_guards[0]
	assert(smart_guard.is_intelligent, "Guard must be intelligent")
	
	var test_player_pos = smart_guard.position + Vector3(2.0, 0.0, 0.0)
	var test_colliders: Array[AABB] = []
	
	# Player in section (visible) -> Hunts!
	smart_guard.update_guard(0.016, test_player_pos, test_colliders, false)
	assert(smart_guard.is_hunting_player == true, "Smart Granny must hunt player when inside her section!")
	print("   Section hunt activation: PASSED")
	
	# Player activates Invisibility -> Stops hunting!
	smart_guard.update_guard(0.016, test_player_pos, test_colliders, true)
	assert(smart_guard.is_hunting_player == false, "Smart Granny must stop hunting when player is invisible!")
	print("   Invisibility power-up evasion: PASSED")

	print("--- ALL GRANNY & HUD TESTS PASSED SUCCESSFULLY! ---")
	get_tree().quit(0)

func _test_mobile_touch_movement() -> void:
	await get_tree().create_timer(0.4).timeout
	var initial_pos := player_root.position
	print("TOUCH_TEST_START: player_pos=", initial_pos)
	_start_mobile_touch(Vector2(270, 600))
	_update_mobile_drag(Vector2(200, 480))
	await get_tree().create_timer(0.8).timeout
	var moved_pos := player_root.position
	print("TOUCH_TEST_MID: player_pos=", moved_pos, " moved_dist=", moved_pos.distance_to(initial_pos))
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_touch_movement.png")
			img.save_png(path)
			print("TOUCH_SCREENSHOT_SAVED")
	_reset_mobile_touch()
	await get_tree().create_timer(0.2).timeout
	if moved_pos.distance_to(initial_pos) > 0.5:
		print("TOUCH_TEST_SUCCESSFUL: Mobile touch successfully moved player in 3D world!")
	else:
		print("TOUCH_TEST_FAILED: Player did not move with touch!")
	get_tree().quit()

func _test_view_room1() -> void:
	await get_tree().create_timer(0.4).timeout
	if is_instance_valid(player_root):
		player_root.position = Vector3(0.0, 0.0, -16.0)
	main_camera.position = Vector3(0.0, 27.5, -12.5)
	main_camera.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	await get_tree().create_timer(0.4).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_room1_view.png")
			img.save_png(path)
			print("ROOM1_VIEW_SCREENSHOT_SAVED")
	get_tree().quit()

func _test_rewarded_powerup_prompt() -> void:
	await get_tree().create_timer(0.4).timeout
	# Temporarily set coins to 0 to simulate player having no coins
	if GameManager != null:
		GameManager.coins = 0
	coins = 0
	if is_instance_valid(coin_lbl):
		coin_lbl.text = " 0"
	_activate_speed_powerup()
	await get_tree().create_timer(0.5, true, false, true).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_rewarded_powerup_prompt.png")
			img.save_png(path)
			print("REWARDED_POWERUP_PROMPT_SCREENSHOT_SAVED")
	get_tree().quit()

func _test_mission_intro_screenshot() -> void:
	await get_tree().create_timer(0.4).timeout
	_show_mission_start_popup()
	await get_tree().create_timer(0.45).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_mission_intro.png")
			img.save_png(path)
			print("MISSION_INTRO_SCREENSHOT_SAVED")
	get_tree().quit()

func _test_cupboard_opening() -> void:
	await get_tree().create_timer(0.4).timeout
	player_root.position = candy_pos + Vector3(0.0, 0.0, 1.4)
	main_camera.position.z = candy_pos.z + 4.5
	_open_cupboard_and_collect()
	await get_tree().create_timer(0.35).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_cupboard_open.png")
			img.save_png(path)
			print("CUPBOARD_OPEN_SCREENSHOT_SAVED")
	get_tree().quit()

func _test_fail_popup() -> void:
	await get_tree().create_timer(0.3).timeout
	_trigger_fail("Caught by Granny! Sneak Failed!")
	await get_tree().create_timer(1.8).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_fail_popup.png")
			img.save_png(path)
			print("FAIL_POPUP_SCREENSHOT_SAVED")
	get_tree().quit()

func _test_candy_loop() -> void:
	print("T_LOOP start: ", Time.get_ticks_msec())
	await get_tree().create_timer(0.4).timeout
	print("T_LOOP after 0.4s: ", Time.get_ticks_msec())
	is_entering_level = false
	for key in active_keys:
		if is_instance_valid(key) and is_instance_valid(player_root):
			player_root.position = Vector3(key.position.x, 0.0, key.position.z)
			await get_tree().create_timer(0.35).timeout
	for c in active_containers:
		if is_instance_valid(player_root):
			player_root.position = c["pos"] + Vector3(0.0, 0.0, 1.2)
		print("T_LOOP moved to container: ", Time.get_ticks_msec())
		await get_tree().create_timer(0.8).timeout
		print("T_LOOP after container 0.8s: ", Time.get_ticks_msec())
	print("LOOP_TEST_MID: collected_count=", collected_items_count, " target_total=", target_items_total, " has_key=", player_has_key, " player_pos=", player_root.position)
	if is_instance_valid(player_root):
		player_root.position = entrance_outside_pos
	await get_tree().create_timer(0.8).timeout
	print("T_LOOP after exit 0.8s: ", Time.get_ticks_msec())
	print("LOOP_TEST_END: is_level_cleared=", is_level_cleared, " player_pos=", player_root.position)
	if is_level_cleared:
		print("LOOP_TEST_SUCCESSFUL: Player collected all items and went outside to win!")
	else:
		print("LOOP_TEST_STATUS: cleared=", is_level_cleared, " collected=", collected_items_count)
	await get_tree().create_timer(0.5).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_candy_win.png")
			img.save_png(path)
	get_tree().quit()

func _test_victory_popup() -> void:
	await get_tree().create_timer(0.3).timeout
	_trigger_win()
	await get_tree().create_timer(1.6).timeout
	print("VICTORY_TEST_COINS: coins=", coins)
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_victory_popup.png")
			img.save_png(path)
			print("VICTORY_POPUP_SCREENSHOT_SAVED")
	get_tree().quit()

func _test_powerups() -> void:
	_skip_intro_sequence()
	await get_tree().create_timer(0.6).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_powerup.png")
			img.save_png(path)
			print("POWERUP_SCREENSHOT_SAVED: is_invisible=", is_player_invisible, " speed_boost=", speed_boost_time)
	get_tree().quit()

func _test_door_passage() -> void:
	await get_tree().create_timer(1.8).timeout
	print("TEST_DOOR_CHECK: player_pos=", player_root.position)
	if player_root.position.z < -5.0:
		print("DOOR_PASSAGE_SUCCESSFUL: Player successfully passed through opened door into next room!")
	else:
		print("DOOR_PASSAGE_FAILED: Player stopped at z=", player_root.position.z)
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_door_pass.png")
			img.save_png(path)
	get_tree().quit()

func _capture_and_quit() -> void:
	print("CAPTURE_AND_QUIT_STARTED: waiting 2.0s for intro cinematic & hud...")
	await get_tree().create_timer(2.0).timeout
	print("CAPTURE_AND_QUIT_TIMER_DONE")
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_candyboy.png")
			img.save_png(path)
			print("CANDYBOY_SCREENSHOT_SAVED: path=", path)
	get_tree().quit()

func _setup_environment() -> void:
	RenderingServer.set_default_clear_color(Color("#48dbfb"))
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#48dbfb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#ffffff")
	env.ambient_light_energy = 0.65
	world_env.environment = env
	add_child(world_env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -32.0, 0.0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	add_child(sun)

	main_camera = Camera3D.new()
	main_camera.name = "MainCamera"
	main_camera.fov = 46.0
	main_camera.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	main_camera.current = true
	add_child(main_camera)

	# Lush outdoor garden lawn ground void
	var bg_floor := MeshInstance3D.new()
	var bf_mesh := BoxMesh.new()
	bf_mesh.size = Vector3(160.0, 0.4, 160.0)
	bg_floor.mesh = bf_mesh
	bg_floor.position = Vector3(0.0, -0.2, 0.0)
	var bg_mat := StandardMaterial3D.new()
	bg_mat.albedo_color = Color("#38ada9")
	bg_floor.material_override = bg_mat
	add_child(bg_floor)

func load_level(lvl: int) -> void:
	current_level = lvl
	if SoundManager != null:
		SoundManager.start_bgm()
	is_game_active = false
	is_level_cleared = false
	is_spotted = false
	player_has_key = false
	candy_collected = false
	candy_node = null
	cupboard_root = null
	cupboard_door_left = null
	cupboard_door_right = null
	cupboard_prompt = null
	is_cupboard_open = false

	# Intelligent Granny cycle: activates every 2-3 completed levels
	is_intelligent_granny_active = (levels_completed_streak >= 2)
	if is_intelligent_granny_active:
		print("SMART_GRANNY: Active on level %d! (Streak: %d)" % [lvl, levels_completed_streak])

	# Multi-Item Collection State Reset
	target_items.clear()
	collected_items_count = 0
	target_items_total = 0
	all_items_collected = false
	active_containers.clear()
	active_open_items.clear()

	# Clean previous level
	if is_instance_valid(level_root):
		level_root.queue_free()
	if is_instance_valid(fail_popup):
		fail_popup.queue_free()
		fail_popup = null
	if is_instance_valid(victory_popup):
		victory_popup.queue_free()
		victory_popup = null
	if is_instance_valid(catch_letterbox_layer):
		catch_letterbox_layer.queue_free()
		catch_letterbox_layer = null
	if is_instance_valid(catch_cinematic_tween):
		catch_cinematic_tween.kill()
		catch_cinematic_tween = null
	var b_bubble := get_node_or_null("BoyCatchBubble")
	if is_instance_valid(b_bubble):
		b_bubble.queue_free()
	is_catch_cinematic_active = false
	wall_colliders.clear()
	active_lasers.clear()
	active_buttons.clear()
	active_doors.clear()
	active_guards.clear()
	active_cameras.clear()
	active_keys.clear()
	active_props.clear()
	active_powerups.clear()

	level_root = Node3D.new()
	level_root.name = "LevelRoot"
	add_child(level_root)

	# Read level JSON (or generate procedurally for infinite levels!)
	var json_path := "res://levels/level_%d.json" % lvl
	if FileAccess.file_exists(json_path):
		var f := FileAccess.open(json_path, FileAccess.READ)
		active_level_data = JSON.parse_string(f.get_as_text())
		f.close()
	else:
		# Deterministic procedurally generated levels for unlimited replayability!
		active_level_data = LevelGenerator.generate_level(lvl)

	var p_info: Dictionary = active_level_data.get("characters", {}).get("player", {})
	var p_pos_arr: Array = p_info.get("pos", [0.0, 0.0, 3.6])
	player_spawn_pos = Vector3(float(p_pos_arr[0]), 0.0, float(p_pos_arr[2]))

	var cam_info: Dictionary = active_level_data.get("camera", {})
	if not cam_info.is_empty() and is_instance_valid(main_camera):
		var cam_pos_arr: Array = cam_info.get("position", [0.0, 26.5, player_spawn_pos.z + 4.5])
		main_camera.position = Vector3(float(cam_pos_arr[0]), float(cam_pos_arr[1]), float(cam_pos_arr[2]))
		var cam_rot_arr: Array = cam_info.get("rotation_degrees", [-66.0, 0.0, 0.0])
		main_camera.rotation_degrees = Vector3(float(cam_rot_arr[0]), float(cam_rot_arr[1]), float(cam_rot_arr[2]))
		main_camera.fov = float(cam_info.get("fov", 48.0))
	else:
		_reset_camera_to_origin()

	_build_level_geometry()
	_build_player()
	_update_hud()
	_populate_item_collector_hud()
	if SignalHub != null:
		SignalHub.emit_level_started(lvl)
	if SoundManager != null:
		SoundManager.play_sfx("start")
	call_deferred("_start_intro_sequence")

func _start_intro_sequence() -> void:
	var all_args := OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for arg in all_args:
		if arg.begins_with("--test"):
			return
	if FileAccess.file_exists("res://test_loop.flag") or FileAccess.file_exists("res://test_door.flag"):
		return

	# Collect all target items & cupboards to focus camera on item locations
	var focus_targets: Array[Dictionary] = []
	for c in active_containers:
		if is_instance_valid(c.get("root")):
			focus_targets.append({
				"pos": c["pos"],
				"beacon": c.get("beacon"),
				"prompt": c.get("prompt"),
				"name": c.get("name", "ITEM")
			})
	for it in active_open_items:
		if is_instance_valid(it.get("node")) and not it.get("collected", false):
			focus_targets.append({
				"pos": it["pos"],
				"beacon": it.get("node"),
				"prompt": null,
				"name": it.get("name", "ITEM")
			})

	var entrance_cam := Vector3(player_spawn_pos.x * 0.75, 27.5, player_spawn_pos.z + 4.5)
	if focus_targets.is_empty():
		main_camera.position = entrance_cam
		is_intro_cinematic_active = false
		_set_ad_banner_mode(true)
		return

	is_intro_cinematic_active = true
	intro_cinematic_tween = create_tween()

	# Focus camera briefly on the primary target item while the player enters through the door
	var max_targets := mini(focus_targets.size(), 1)
	for i in range(max_targets):
		var target: Dictionary = focus_targets[i]
		var t_pos: Vector3 = target["pos"]
		var target_cam := Vector3(t_pos.x * 0.85, 20.0, t_pos.z + 4.2)

		# Smooth, readable glide to target item location
		intro_cinematic_tween.tween_property(main_camera, "position", target_cam, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)

		# Highlight & pulse beacon so player sees exactly where the item is
		intro_cinematic_tween.chain().tween_callback(func():
			if is_instance_valid(target.get("beacon")):
				var b_tw := create_tween()
				b_tw.tween_property(target["beacon"], "scale", Vector3.ONE * 1.5, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				b_tw.tween_property(target["beacon"], "scale", Vector3.ONE, 0.25)
			if is_instance_valid(target.get("prompt")):
				target["prompt"].visible = true
			if SoundManager != null:
				SoundManager.play_sfx("cabinet")
		)
		intro_cinematic_tween.chain().tween_interval(0.90)
		intro_cinematic_tween.chain().tween_callback(func():
			if is_instance_valid(target.get("prompt")):
				target["prompt"].visible = false
		)

	# Smoothly return camera to player spawn ready to play
	intro_cinematic_tween.chain().tween_property(main_camera, "position", entrance_cam, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	intro_cinematic_tween.chain().tween_callback(func():
		_end_intro_sequence()
	)

func _show_mission_start_popup() -> void:
	if not is_instance_valid(hud_root) or is_instance_valid(mission_intro_popup):
		return
	var scene := load("res://scenes/popups/mission_intro_popup.tscn") as PackedScene
	if scene != null:
		mission_intro_popup = scene.instantiate()
		if mission_intro_popup.has_method("set_target_items"):
			mission_intro_popup.set_target_items(target_items)
		mission_intro_popup.start_pressed.connect(_skip_intro_sequence)
		hud_root.add_child(mission_intro_popup)

func _skip_intro_sequence() -> void:
	if intro_cinematic_tween != null and intro_cinematic_tween.is_valid():
		intro_cinematic_tween.kill()
	var entrance_cam := Vector3(player_spawn_pos.x * 0.75, 27.5, player_spawn_pos.z + 4.5)
	main_camera.position = entrance_cam
	_end_intro_sequence()

func _end_intro_sequence() -> void:
	if is_instance_valid(mission_intro_popup):
		var tw := create_tween()
		tw.tween_property(mission_intro_popup, "modulate:a", 0.0, 0.25)
		tw.chain().tween_callback(mission_intro_popup.queue_free)
	is_intro_cinematic_active = false
	_set_ad_banner_mode(true)

func _build_level_geometry() -> void:
	var rooms: Array = active_level_data.get("rooms", [])
	var room_depth: float = float(active_level_data.get("room_depth", 10.0))
	var house_w: float = float(active_level_data.get("house_width", 14.0))
	var half_w := house_w * 0.5

	for r_idx in range(rooms.size()):
		var r_data: Dictionary = rooms[r_idx]
		var is_positioned_room: bool = r_data.has("center")
		var r_center := Vector3(0.0, 0.0, -float(r_idx) * room_depth)
		var cur_w := house_w
		var cur_d := room_depth

		if is_positioned_room:
			var raw_c: Array = r_data["center"]
			r_center = Vector3(float(raw_c[0]), 0.0, float(raw_c[2]))
			cur_w = float(r_data.get("width", house_w))
			cur_d = float(r_data.get("depth", room_depth))

		var cur_half_w := cur_w * 0.5
		var cur_half_d := cur_d * 0.5

		var r_node := Node3D.new()
		r_node.name = "Room_%d" % r_idx
		level_root.add_child(r_node)

		# 1. Floor
		_create_room_floor(r_center, cur_w, cur_d, r_node)

		if not is_positioned_room:
			# Legacy linear 1D room building (Levels 1-6)
			var r_z_mid: float = r_center.z
			_create_wall(Vector3(-half_w, WALL_H * 0.5, r_z_mid), Vector3(WALL_T, WALL_H, room_depth), r_node)
			_create_wall(Vector3(half_w, WALL_H * 0.5, r_z_mid), Vector3(WALL_T, WALL_H, room_depth), r_node)

			if r_data.has("compartment_archetype"):
				var arch_name: String = String(r_data.get("compartment_archetype", ""))
				RoomCompartmentBuilder.build_archetype(
					arch_name,
					Vector3(0.0, 0.0, r_z_mid),
					half_w,
					room_depth,
					r_node,
					Callable(self, "_create_wall"),
					Callable(self, "_create_interior_door")
				)

			for comp in r_data.get("compartments", []):
				var c_raw: Array = comp.get("pos", [0.0, 0.0, 0.0])
				var c_size_raw: Array = comp.get("size", [0.35, WALL_H, 3.5])
				var c_pos := Vector3(float(c_raw[0]), float(c_size_raw[1]) * 0.5, r_z_mid + float(c_raw[2]))
				var c_size := Vector3(float(c_size_raw[0]), float(c_size_raw[1]), float(c_size_raw[2]))
				_create_wall(c_pos, c_size, r_node)

			if r_idx < rooms.size() - 1:
				var div_z := r_z_mid - room_depth * 0.5
				var doors_arr: Array = r_data.get("doors", [])
				if doors_arr.is_empty():
					doors_arr.append({ "x": 0.0, "width": 2.4, "color": "#f1be28" })

				var door_info: Dictionary = doors_arr[0]
				var dw: float = float(door_info.get("width", 2.4))
				var dx: float = float(door_info.get("x", 0.0))
				var d_color := Color("#27ae60")
				var req_key: bool = bool(door_info.get("requires_key", false))

				var left_w := (dx - dw * 0.5) - (-half_w)
				if left_w > 0.05:
					_create_wall(Vector3(-half_w + left_w * 0.5, WALL_H * 0.5, div_z), Vector3(left_w, WALL_H, WALL_T), r_node)
				var right_w := half_w - (dx + dw * 0.5)
				if right_w > 0.05:
					_create_wall(Vector3(half_w - right_w * 0.5, WALL_H * 0.5, div_z), Vector3(right_w, WALL_H, WALL_T), r_node)

				var door := DoorController.new()
				door.position = Vector3(dx, 0.0, div_z)
				door.setup(dw, d_color, req_key)
				r_node.add_child(door)
				active_doors.append(door)
			elif r_idx == rooms.size() - 1:
				var north_z := r_z_mid - room_depth * 0.5
				_create_wall(Vector3(0.0, WALL_H * 0.5, north_z), Vector3(house_w, WALL_H, WALL_T), r_node)

			if r_idx == 0:
				var south_z := r_z_mid + room_depth * 0.5
				var entry_x: float = player_spawn_pos.x
				var dw_s: float = 3.0
				var left_sw := (entry_x - dw_s * 0.5) - (-half_w)
				if left_sw > 0.05:
					_create_wall(Vector3(-half_w + left_sw * 0.5, WALL_H * 0.5, south_z), Vector3(left_sw, WALL_H, WALL_T), r_node)
				var right_sw := half_w - (entry_x + dw_s * 0.5)
				if right_sw > 0.05:
					_create_wall(Vector3(half_w - right_sw * 0.5, WALL_H * 0.5, south_z), Vector3(right_sw, WALL_H, WALL_T), r_node)
				var s_door := DoorController.new()
				s_door.position = Vector3(entry_x, 0.0, south_z)
				s_door.setup(dw_s, Color("#27ae60"), false)
				r_node.add_child(s_door)
				active_doors.append(s_door)
				entrance_door_pos = Vector3(entry_x, 0.0, south_z)
				entrance_outside_pos = Vector3(entry_x, 0.0, south_z + 3.2)
				_create_room_floor(Vector3(entry_x, 0.0, south_z + 2.1), 3.4, 4.2, r_node)
		else:
			# Multi-Directional 2D Room Builder (Rooms above, left side, right side!)
			for comp in r_data.get("compartments", []):
				var c_raw: Array = comp.get("pos", [0.0, 0.0, 0.0])
				var c_size_raw: Array = comp.get("size", [0.35, WALL_H, 3.5])
				var c_pos := r_center + Vector3(float(c_raw[0]), float(c_size_raw[1]) * 0.5, float(c_raw[2]))
				var c_size := Vector3(float(c_size_raw[0]), float(c_size_raw[1]), float(c_size_raw[2]))
				_create_wall(c_pos, c_size, r_node)

			var doors_north: Array[Dictionary] = []
			var doors_south: Array[Dictionary] = []
			var doors_west: Array[Dictionary] = []
			var doors_east: Array[Dictionary] = []

			for d_info in r_data.get("doors", []):
				var w_name: String = String(d_info.get("wall", "north")).to_lower()
				match w_name:
					"north": doors_north.append(d_info)
					"south": doors_south.append(d_info)
					"west", "left": doors_west.append(d_info)
					"east", "right": doors_east.append(d_info)
					_: doors_north.append(d_info)

			# North Wall
			if doors_north.is_empty():
				if not bool(r_data.get("open_north", false)):
					_create_wall(Vector3(r_center.x, WALL_H * 0.5, r_center.z - cur_half_d), Vector3(cur_w, WALL_H, WALL_T), r_node)
			else:
				for d in doors_north:
					var dw: float = float(d.get("width", 2.8))
					var dx: float = float(d.get("x", r_center.x))
					var left_l := (dx - dw * 0.5) - (r_center.x - cur_half_w)
					if left_l > 0.05:
						_create_wall(Vector3(r_center.x - cur_half_w + left_l * 0.5, WALL_H * 0.5, r_center.z - cur_half_d), Vector3(left_l, WALL_H, WALL_T), r_node)
					var right_l := (r_center.x + cur_half_w) - (dx + dw * 0.5)
					if right_l > 0.05:
						_create_wall(Vector3(r_center.x + cur_half_w - right_l * 0.5, WALL_H * 0.5, r_center.z - cur_half_d), Vector3(right_l, WALL_H, WALL_T), r_node)
					var door := DoorController.new()
					door.position = Vector3(dx, 0.0, r_center.z - cur_half_d)
					door.setup(dw, Color("#27ae60"), false)
					r_node.add_child(door)
					active_doors.append(door)

			# South Wall (Room 0 always has a Main Entrance / Exit Door so player walks IN at start and goes OUT to complete!)
			if r_idx == 0 and doors_south.is_empty() and not bool(r_data.get("open_south", false)):
				var p_raw: Array = active_level_data.get("characters", {}).get("player", {}).get("pos", [r_center.x, 0.0, r_center.z + cur_half_d - 2.5])
				var entry_x: float = float(p_raw[0])
				doors_south.append({ "wall": "south", "x": entry_x, "width": 3.0 })
				entrance_door_pos = Vector3(entry_x, 0.0, r_center.z + cur_half_d)
				entrance_outside_pos = Vector3(entry_x, 0.0, r_center.z + cur_half_d + 3.2)
				_create_room_floor(Vector3(entry_x, 0.0, r_center.z + cur_half_d + 2.1), 3.4, 4.2, r_node)

			if doors_south.is_empty():
				if not bool(r_data.get("open_south", false)):
					_create_wall(Vector3(r_center.x, WALL_H * 0.5, r_center.z + cur_half_d), Vector3(cur_w, WALL_H, WALL_T), r_node)
			else:
				for d in doors_south:
					var dw: float = float(d.get("width", 2.8))
					var dx: float = float(d.get("x", r_center.x))
					var left_l := (dx - dw * 0.5) - (r_center.x - cur_half_w)
					if left_l > 0.05:
						_create_wall(Vector3(r_center.x - cur_half_w + left_l * 0.5, WALL_H * 0.5, r_center.z + cur_half_d), Vector3(left_l, WALL_H, WALL_T), r_node)
					var right_l := (r_center.x + cur_half_w) - (dx + dw * 0.5)
					if right_l > 0.05:
						_create_wall(Vector3(r_center.x + cur_half_w - right_l * 0.5, WALL_H * 0.5, r_center.z + cur_half_d), Vector3(right_l, WALL_H, WALL_T), r_node)
					var door := DoorController.new()
					door.position = Vector3(dx, 0.0, r_center.z + cur_half_d)
					door.setup(dw, Color("#27ae60"), false)
					r_node.add_child(door)
					active_doors.append(door)

			# West Wall (Left side)
			if doors_west.is_empty():
				if not bool(r_data.get("open_west", false)):
					_create_wall(Vector3(r_center.x - cur_half_w, WALL_H * 0.5, r_center.z), Vector3(WALL_T, WALL_H, cur_d), r_node)
			else:
				for d in doors_west:
					var dw: float = float(d.get("width", 2.8))
					var dz: float = float(d.get("z", r_center.z))
					var north_l := (dz - dw * 0.5) - (r_center.z - cur_half_d)
					if north_l > 0.05:
						_create_wall(Vector3(r_center.x - cur_half_w, WALL_H * 0.5, r_center.z - cur_half_d + north_l * 0.5), Vector3(WALL_T, WALL_H, north_l), r_node)
					var south_l := (r_center.z + cur_half_d) - (dz + dw * 0.5)
					if south_l > 0.05:
						_create_wall(Vector3(r_center.x - cur_half_w, WALL_H * 0.5, r_center.z + cur_half_d - south_l * 0.5), Vector3(WALL_T, WALL_H, south_l), r_node)
					var door := DoorController.new()
					door.position = Vector3(r_center.x - cur_half_w, 0.0, dz)
					door.rotation_degrees.y = 90.0
					door.setup(dw, Color("#27ae60"), false)
					r_node.add_child(door)
					active_doors.append(door)

			# East Wall (Right side)
			if doors_east.is_empty():
				if not bool(r_data.get("open_east", false)):
					_create_wall(Vector3(r_center.x + cur_half_w, WALL_H * 0.5, r_center.z), Vector3(WALL_T, WALL_H, cur_d), r_node)
			else:
				for d in doors_east:
					var dw: float = float(d.get("width", 2.8))
					var dz: float = float(d.get("z", r_center.z))
					var north_l := (dz - dw * 0.5) - (r_center.z - cur_half_d)
					if north_l > 0.05:
						_create_wall(Vector3(r_center.x + cur_half_w, WALL_H * 0.5, r_center.z - cur_half_d + north_l * 0.5), Vector3(WALL_T, WALL_H, north_l), r_node)
					var south_l := (r_center.z + cur_half_d) - (dz + dw * 0.5)
					if south_l > 0.05:
						_create_wall(Vector3(r_center.x + cur_half_w, WALL_H * 0.5, r_center.z + cur_half_d - south_l * 0.5), Vector3(WALL_T, WALL_H, south_l), r_node)
					var door := DoorController.new()
					door.position = Vector3(r_center.x + cur_half_w, 0.0, dz)
					door.rotation_degrees.y = 90.0
					door.setup(dw, Color("#27ae60"), false)
					r_node.add_child(door)
					active_doors.append(door)

		# 6. Target Items (Multi-Item Collectibles in Cabinets only - no clutter items per user instruction)
		for it in r_data.get("items", []):
			var it_id: String = String(it.get("id", ""))
			var it_raw: Array = it.get("pos", [0.0, 0.0, 0.0])
			var it_pos := r_center + Vector3(float(it_raw[0]), float(it_raw[1]), float(it_raw[2]))

			var is_target_item: bool = (it_id in ["candy", "ball", "bat", "game", "bear", "trophy", "gem", "robot", "dice"]) or bool(it.get("is_target", false)) or bool(it.get("is_main_candy", false)) or it.has("container")
			if it_id == "key" or (bool(it.get("collectible", false)) and it_id == "key"):
				var key := KeyPickup.new()
				key.setup(it_pos)
				key.key_collected.connect(_on_key_collected)
				r_node.add_child(key)
				active_keys.append(key)
			elif is_target_item:
				# Target Item to find - ALWAYS placed inside a distinct 3D cabinet (no ATM!)
				var it_type: String = String(it.get("type", it_id))
				var it_col := Color(it.get("color", "#e84393"))
				var cabinet_palette := ["#2980b9", "#8e44ad", "#d35400", "#16a085", "#c0392b", "#27ae60", "#2c3e50", "#b9770e"]
				var cabinet_models := ["bookcaseClosedDoors", "bookcaseClosedWide", "cabinetTelevisionDoors", "kitchenCabinet", "kitchenCabinetDrawer"]
				var idx_c: int = target_items.size()
				var default_c_col: String = cabinet_palette[idx_c % cabinet_palette.size()]
				var default_c_mod: String = cabinet_models[idx_c % cabinet_models.size()]
				var raw_c_col: String = String(it.get("container_color", ""))
				if raw_c_col.is_empty():
					raw_c_col = default_c_col
				var raw_c_mod: String = String(it.get("container_model", ""))
				if raw_c_mod.is_empty():
					raw_c_mod = default_c_mod
				var item_entry := {
					"id": "%s_%d" % [it_type, target_items.size()],
					"type": it_type,
					"pos": it_pos,
					"rot_y": float(it.get("rot_y", 180.0)),
					"color": it_col,
					"container": "cupboard",
					"container_model": raw_c_mod,
					"container_scale": float(it.get("container_scale", 2.6)),
					"container_color": raw_c_col,
					"requires_key": bool(it.get("requires_key", false))
				}
				var info := CollectibleItem.get_item_info(it_type)
				item_entry["name"] = String(it.get("name", info.get("name", "Toy")))
				item_entry["icon"] = String(it.get("icon", info.get("icon", "🎁")))
				target_items.append(item_entry)
				_build_item_cupboard(item_entry, r_node)

		# 7. Security Cameras
		for c_info in r_data.get("cameras", []):
			var raw_c_pos: Array = c_info.get("pos", [-6.8, 2.35, 0.0])
			var raw_dir: Array = c_info.get("inward_dir", [1.0, 0.0, 0.0])
			var c_pos := r_center + Vector3(float(raw_c_pos[0]), float(raw_c_pos[1]), float(raw_c_pos[2]))
			var wall_yaw := atan2(float(raw_dir[0]), float(raw_dir[2]))
			var c_range: float = float(c_info.get("vision_range", 7.8))
			var c_angle: float = float(c_info.get("vision_angle", 38.0))
			var cam := SecurityCamera.new()
			cam.position = c_pos
			cam.setup(wall_yaw, c_range, c_angle)
			cam.player_spotted.connect(_trigger_fail)
			r_node.add_child(cam)
			active_cameras.append(cam)

		# 8. Granny Guards
		for g_info in r_data.get("guards", []):
			var waypoints: Array[Vector3] = []
			var raw_wps: Array = g_info.get("waypoints", [])
			if raw_wps.size() >= 2:
				for wp_raw in raw_wps:
					waypoints.append(r_center + Vector3(float(wp_raw[0]), float(wp_raw[1]), float(wp_raw[2])))
			else:
				waypoints = [r_center + Vector3(-3.5, 0.0, 0.0), r_center + Vector3(3.5, 0.0, 0.0)]

			var g_range: float = float(g_info.get("vision_range", 3.8))
			var g_angle: float = float(g_info.get("vision_angle", 32.0))
			var g_speed: float = float(g_info.get("speed", 3.0))
			var tint := Color(g_info.get("tint", "#d63031"))

			var guard := GuardController.new()
			guard.setup(waypoints, g_range, g_angle, g_speed, tint)
			guard.set_intelligent(is_intelligent_granny_active)
			var room_bounds := AABB(Vector3(r_center.x - cur_half_w, -1.0, r_center.z - cur_half_d), Vector3(cur_w, 10.0, cur_d))
			guard.set_room_bounds(room_bounds)
			guard.player_spotted.connect(_trigger_fail)
			r_node.add_child(guard)
			active_guards.append(guard)

		# Clean Room Layout: place entrance/exit pad OUTSIDE the south entrance door where the player comes from and exits to!
		if r_idx == 0:
			_create_spawn_marker(entrance_door_pos + Vector3(0.0, 0.0, 1.8), r_node)

	# Outdoor Scenery: Lush lawn and 3D trees surrounding the house/hall on all 4 perimeter sides
	var min_x := -house_w * 0.5
	var max_x := house_w * 0.5
	var min_z := -float(rooms.size() - 1) * room_depth - room_depth * 0.5
	var max_z := room_depth * 0.5

	for r_data in rooms:
		var c := Vector3.ZERO
		if r_data.has("center"):
			var raw_c: Array = r_data["center"]
			c = Vector3(float(raw_c[0]), 0.0, float(raw_c[2]))
		var w: float = float(r_data.get("width", house_w))
		var d: float = float(r_data.get("depth", room_depth))
		min_x = minf(min_x, c.x - w * 0.5)
		max_x = maxf(max_x, c.x + w * 0.5)
		min_z = minf(min_z, c.z - d * 0.5)
		max_z = maxf(max_z, c.z + d * 0.5)

	var total_w := max_x - min_x
	var total_d := max_z - min_z
	OutdoorScenery.build_outdoor_trees(level_root, total_w, total_d, min_z, max_z, wall_colliders, entrance_door_pos.x)

	# Level Safety Validation: Ensure player spawn, cabinets, and guard waypoints never clip into walls!
	_validate_level_safety()

func _spawn_level_powerups() -> void:
	# Powerups are only available in the bottom HUD bar by spending coins (not spawned on levels)
	pass

func _validate_level_safety() -> void:
	# 1. Validate Player Spawn Position: Must never be inside or clipping any wall
	if is_instance_valid(player_root):
		var safe_pos := _find_nearest_safe_floor(player_spawn_pos, 0.55)
		if safe_pos.distance_to(player_spawn_pos) > 0.05:
			print("SAFETY_VALIDATOR: Player spawn at ", player_spawn_pos, " was clipping wall! Auto-adjusted to safe pos: ", safe_pos)
			player_spawn_pos = safe_pos
			player_root.position = safe_pos
			var marker := level_root.get_node_or_null("SpawnMarker")
			if is_instance_valid(marker):
				marker.position = safe_pos

	# 2. Validate Cabinet Positions: Must not be embedded inside walls (skip cabinet's own AABB)
	for c_entry in active_containers:
		var c_pos: Vector3 = c_entry.get("pos", Vector3.ZERO)
		var own_aabb: AABB = c_entry.get("collider_aabb", AABB())
		for aabb in wall_colliders:
			if aabb == own_aabb:
				continue
			if aabb.grow(0.15).has_point(c_pos):
				var c := aabb.get_center()
				var diff := c_pos - c
				if absf(diff.x) > absf(diff.z):
					c_pos.x = c.x + signf(diff.x) * (aabb.size.x * 0.5 + 0.45)
				else:
					c_pos.z = c.z + signf(diff.z) * (aabb.size.z * 0.5 + 0.45)
				c_entry["pos"] = c_pos
				c_entry["collider_aabb"] = AABB(c_pos - own_aabb.size * 0.5 + Vector3(0.0, own_aabb.size.y * 0.5, 0.0), own_aabb.size)
				if is_instance_valid(c_entry.get("root")):
					c_entry["root"].position = c_pos
				if is_instance_valid(c_entry.get("item_node")):
					c_entry["item_node"].position.x = c_pos.x
					c_entry["item_node"].position.z = c_pos.z
				print("SAFETY_VALIDATOR: Cabinet for ", c_entry.get("id"), " adjusted to ", c_pos)

	# 2b. Validate Key Positions: Must not be inside partition walls
	for key in active_keys:
		if is_instance_valid(key):
			var safe_k := _find_nearest_safe_floor(key.position, 0.55)
			if safe_k.distance_to(key.position) > 0.05:
				key.position = safe_k

	# 3. Validate Guard Waypoints: Must not be inside walls
	for guard in active_guards:
		if is_instance_valid(guard):
			for w_i in range(guard.waypoints.size()):
				var wp := guard.waypoints[w_i]
				var safe_wp := _find_nearest_safe_floor(wp, 0.45)
				if safe_wp.distance_to(wp) > 0.05:
					print("SAFETY_VALIDATOR: Guard waypoint ", wp, " adjusted to ", safe_wp)
					guard.waypoints[w_i] = safe_wp

	# 4. Validate Item Distance from Player Starting Position:
	# Ensure no item cabinet is ever placed near the player's starting spawn point (must be at least 7.0m away!)
	for it_data in target_items:
		var c_pos: Vector3 = it_data.get("pos", Vector3.ZERO)
		if c_pos.distance_to(player_spawn_pos) < 7.0:
			var far_z := -absf(c_pos.z) if c_pos.z > 0.0 else c_pos.z - 4.0
			var safe_pos := Vector3(c_pos.x, 0.0, far_z)
			safe_pos = _find_nearest_safe_floor(safe_pos, 0.6)
			it_data["pos"] = safe_pos
			if is_instance_valid(it_data.get("root")):
				it_data["root"].position = safe_pos
			print("SAFETY_VALIDATOR: Item ", it_data.get("id"), " was too close to starting spawn! Relocated to safe pos: ", safe_pos)

func _find_nearest_safe_floor(origin: Vector3, min_clearance: float = 0.5) -> Vector3:
	var is_blocked := false
	for aabb in wall_colliders:
		if aabb.grow(min_clearance).has_point(origin):
			is_blocked = true
			break
	if not is_blocked:
		return origin

	# Spiral search in X/Z to find nearest safe open floor point
	for radius_step in range(1, 25):
		var r := float(radius_step) * 0.35
		for angle_deg in range(0, 360, 30):
			var rad := deg_to_rad(float(angle_deg))
			var candidate := origin + Vector3(cos(rad) * r, 0.0, sin(rad) * r)
			var cand_blocked := false
			for aabb in wall_colliders:
				if aabb.grow(min_clearance).has_point(candidate):
					cand_blocked = true
					break
			if not cand_blocked:
				return candidate
	return origin

func _create_floor_pad(pos: Vector3, parent: Node3D) -> Node3D:
	var pad := Node3D.new()
	pad.name = "FloorButtonPad"
	pad.position = pos

	var ring := MeshInstance3D.new()
	var r_mesh := CylinderMesh.new()
	r_mesh.top_radius = 0.55
	r_mesh.bottom_radius = 0.55
	r_mesh.height = 0.02
	ring.mesh = r_mesh
	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = Color("#e84393")
	ring.material_override = r_mat
	pad.add_child(ring)

	var core := MeshInstance3D.new()
	var c_mesh := CylinderMesh.new()
	c_mesh.top_radius = 0.44
	c_mesh.bottom_radius = 0.44
	c_mesh.height = 0.025
	core.mesh = c_mesh
	core.position = Vector3(0.0, 0.005, 0.0)
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = Color.WHITE
	c_mat.emission_enabled = true
	c_mat.emission = Color.WHITE
	c_mat.emission_energy_multiplier = 0.3
	core.material_override = c_mat
	pad.add_child(core)

	parent.add_child(pad)
	return pad

func _build_item_cupboard(item_dict: Dictionary, parent: Node3D) -> void:
	var pos: Vector3 = item_dict["pos"]
	var rot_y: float = float(item_dict.get("rot_y", 180.0))
	var container_model: String = String(item_dict.get("container_model", "bookcaseClosedDoors"))
	var container_scale: float = float(item_dict.get("container_scale", 2.5))
	var container_color_str: String = String(item_dict.get("container_color", "#2980b9"))
	if container_color_str.is_empty():
		container_color_str = "#2980b9"
	var base_cab_col := Color(container_color_str)
	var req_key: bool = bool(item_dict.get("requires_key", false))
	candy_pos = pos
	candy_spawn_pos = pos
	is_cupboard_open = false

	# 1. 3D Cabinet Container (Always a real 3D Cabinet with Doors, Shelves & Handles - NO ATM!)
	var c_root := Node3D.new()
	c_root.name = "Container_%s" % item_dict["id"]
	c_root.position = pos
	parent.add_child(c_root)

	var scale_factor: float = container_scale / 2.1
	var cup_h: float = 2.2 * scale_factor
	var cup_w: float = 1.65 * scale_factor
	var cup_d: float = 0.88 * scale_factor
	if container_model == "bookcaseClosedWide" or container_model == "cabinetTelevisionDoors":
		cup_w = 1.95 * scale_factor
	elif container_model == "kitchenCabinet" or container_model == "kitchenCabinetDrawer":
		cup_w = 1.50 * scale_factor
		cup_h = 1.95 * scale_factor

	var cup_size := Vector3(cup_w, cup_h, cup_d)
	if absf(rot_y - 90.0) < 15.0 or absf(rot_y + 90.0) < 15.0 or absf(rot_y - 270.0) < 15.0:
		cup_size = Vector3(cup_d, cup_h, cup_w)
	var cab_aabb := AABB(pos - cup_size * 0.5 + Vector3(0.0, cup_h * 0.5, 0.0), cup_size)

	var door_left: Node3D = null
	var door_right: Node3D = null

	# Rich 3D Architectural Cabinet (Crown Molding, Two-Tone Doors, Recessed Panels & Brass Handles)
	# Distinct 3D cabinet geometry per container_model so every cabinet looks like a real 3D cabinet!
	var cab_facade := Node3D.new()
	cab_facade.name = "CabinetFacade"
	var facade_yaw := 0.0
	if absf(rot_y - 90.0) < 20.0:
		facade_yaw = 90.0
	elif absf(rot_y + 90.0) < 20.0 or absf(rot_y - 270.0) < 20.0:
		facade_yaw = -90.0
	cab_facade.rotation_degrees.y = facade_yaw
	c_root.add_child(cab_facade)

	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = base_cab_col.darkened(0.32)
	frame_mat.roughness = 0.42
	frame_mat.metallic = 0.1

	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = base_cab_col.lightened(0.16)
	door_mat.roughness = 0.32
	door_mat.metallic = 0.12

	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = base_cab_col.lightened(0.32)
	panel_mat.roughness = 0.35

	var seam_mat := StandardMaterial3D.new()
	seam_mat.albedo_color = base_cab_col.darkened(0.58)
	seam_mat.roughness = 0.6

	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color("#f1c40f")
	brass_mat.metallic = 0.88
	brass_mat.roughness = 0.18
	brass_mat.emission_enabled = true
	brass_mat.emission = Color("#f39c12")
	brass_mat.emission_energy_multiplier = 0.25

	# Cabinet Outer Body Box & Top Crown Cornice
	var body_mesh := MeshInstance3D.new()
	var body_box := BoxMesh.new()
	body_box.size = Vector3(cup_w, cup_h, cup_d * 0.82)
	body_mesh.mesh = body_box
	body_mesh.position = Vector3(0.0, cup_h * 0.5, -0.04)
	body_mesh.material_override = frame_mat
	cab_facade.add_child(body_mesh)

	var crown_mesh := MeshInstance3D.new()
	var crown_box := BoxMesh.new()
	crown_box.size = Vector3(cup_w + 0.18, 0.16, cup_d + 0.16)
	crown_mesh.mesh = crown_box
	crown_mesh.position = Vector3(0.0, cup_h + 0.06, 0.0)
	crown_mesh.material_override = frame_mat
	cab_facade.add_child(crown_mesh)

	# Model-specific top accent (e.g. top drawer for kitchenCabinetDrawer or raised pediment for bookcaseClosedWide)
	if container_model == "kitchenCabinetDrawer" or container_model == "cabinetTelevisionDoors":
		var top_drawer := MeshInstance3D.new()
		var td_box := BoxMesh.new()
		td_box.size = Vector3(cup_w - 0.18, 0.32, 0.10)
		top_drawer.mesh = td_box
		top_drawer.position = Vector3(0.0, cup_h - 0.22, cup_d * 0.39)
		top_drawer.material_override = panel_mat
		cab_facade.add_child(top_drawer)

		var td_knob := MeshInstance3D.new()
		var td_kbox := BoxMesh.new()
		td_kbox.size = Vector3(0.28, 0.06, 0.10)
		td_knob.mesh = td_kbox
		td_knob.position = Vector3(0.0, cup_h - 0.22, cup_d * 0.45)
		td_knob.material_override = brass_mat
		cab_facade.add_child(td_knob)
	elif container_model == "bookcaseClosedWide":
		var pediment := MeshInstance3D.new()
		var ped_box := BoxMesh.new()
		ped_box.size = Vector3(cup_w * 0.72, 0.18, cup_d * 0.85)
		pediment.mesh = ped_box
		pediment.position = Vector3(0.0, cup_h + 0.18, 0.0)
		pediment.material_override = door_mat
		cab_facade.add_child(pediment)

	var plinth_mesh := MeshInstance3D.new()
	var plinth_box := BoxMesh.new()
	plinth_box.size = Vector3(cup_w + 0.12, 0.14, cup_d + 0.10)
	plinth_mesh.mesh = plinth_box
	plinth_mesh.position = Vector3(0.0, 0.07, 0.0)
	plinth_mesh.material_override = frame_mat
	cab_facade.add_child(plinth_mesh)

	var front_z: float = cup_d * 0.38
	var door_w: float = (cup_w - 0.22) * 0.48
	var has_top_drawer: bool = (container_model == "kitchenCabinetDrawer" or container_model == "cabinetTelevisionDoors")
	var door_h: float = (cup_h - 0.64) if has_top_drawer else (cup_h - 0.28)
	var door_center_y: float = (cup_h * 0.5 - 0.16) if has_top_drawer else (cup_h * 0.5)

	# Left Hinged Cabinet Door
	var left_hinge := Node3D.new()
	left_hinge.name = "FacadeDoorLeft"
	left_hinge.position = Vector3(-cup_w * 0.5 + 0.10, door_center_y, front_z)
	cab_facade.add_child(left_hinge)

	var l_door_mesh := MeshInstance3D.new()
	var l_door_box := BoxMesh.new()
	l_door_box.size = Vector3(door_w, door_h, 0.08)
	l_door_mesh.mesh = l_door_box
	l_door_mesh.position = Vector3(door_w * 0.5, 0.0, 0.04)
	l_door_mesh.material_override = door_mat
	left_hinge.add_child(l_door_mesh)

	var l_panel_mesh := MeshInstance3D.new()
	var l_panel_box := BoxMesh.new()
	l_panel_box.size = Vector3(door_w * 0.72, door_h * 0.76, 0.04)
	l_panel_mesh.mesh = l_panel_box
	l_panel_mesh.position = Vector3(door_w * 0.5, 0.0, 0.08)
	l_panel_mesh.material_override = panel_mat
	left_hinge.add_child(l_panel_mesh)

	var l_handle := MeshInstance3D.new()
	var handle_box := BoxMesh.new()
	handle_box.size = Vector3(0.08, 0.42, 0.12)
	l_handle.mesh = handle_box
	l_handle.position = Vector3(door_w - 0.12, 0.0, 0.12)
	l_handle.material_override = brass_mat
	left_hinge.add_child(l_handle)

	# Right Hinged Cabinet Door
	var right_hinge := Node3D.new()
	right_hinge.name = "FacadeDoorRight"
	right_hinge.position = Vector3(cup_w * 0.5 - 0.10, door_center_y, front_z)
	cab_facade.add_child(right_hinge)

	var r_door_mesh := MeshInstance3D.new()
	r_door_mesh.mesh = l_door_box
	r_door_mesh.position = Vector3(-door_w * 0.5, 0.0, 0.04)
	r_door_mesh.material_override = door_mat
	right_hinge.add_child(r_door_mesh)

	var r_panel_mesh := MeshInstance3D.new()
	r_panel_mesh.mesh = l_panel_box
	r_panel_mesh.position = Vector3(-door_w * 0.5, 0.0, 0.08)
	r_panel_mesh.material_override = panel_mat
	right_hinge.add_child(r_panel_mesh)

	var r_handle := MeshInstance3D.new()
	r_handle.mesh = handle_box
	r_handle.position = Vector3(-door_w + 0.12, 0.0, 0.12)
	r_handle.material_override = brass_mat
	right_hinge.add_child(r_handle)

	# Dark vertical center door seam strip
	var seam_mesh := MeshInstance3D.new()
	var seam_box := BoxMesh.new()
	seam_box.size = Vector3(0.05, door_h, 0.09)
	seam_mesh.mesh = seam_box
	seam_mesh.position = Vector3(0.0, door_center_y, front_z + 0.045)
	seam_mesh.material_override = seam_mat
	cab_facade.add_child(seam_mesh)

	door_left = left_hinge
	door_right = right_hinge

	# 3D Golden Padlock & Floating "🔒 KEY REQUIRED" Badge when requires_key is true!
	var lock_badge: Label3D = null
	var padlock_node: Node3D = null
	if req_key:
		padlock_node = Node3D.new()
		padlock_node.name = "CabinetPadlock"
		padlock_node.position = Vector3(0.0, door_center_y, front_z + 0.18)
		cab_facade.add_child(padlock_node)

		var lock_body := MeshInstance3D.new()
		var lb_box := BoxMesh.new()
		lb_box.size = Vector3(0.38, 0.40, 0.16)
		lock_body.mesh = lb_box
		lock_body.material_override = brass_mat
		padlock_node.add_child(lock_body)

		var shackle := MeshInstance3D.new()
		var sh_torus := TorusMesh.new()
		sh_torus.inner_radius = 0.09
		sh_torus.outer_radius = 0.16
		shackle.mesh = sh_torus
		shackle.position = Vector3(0.0, 0.24, 0.0)
		shackle.rotation_degrees.x = 90.0
		shackle.material_override = brass_mat
		padlock_node.add_child(shackle)

		lock_badge = Label3D.new()
		lock_badge.text = "🔒 KEY REQUIRED"
		lock_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		if game_title_font != null:
			lock_badge.font = game_title_font
		lock_badge.font_size = 46
		lock_badge.outline_size = 14
		lock_badge.outline_modulate = Color.BLACK
		lock_badge.modulate = Color("#ff7675")
		lock_badge.position = Vector3(0.0, cup_h + 0.45, 0.65)
		c_root.add_child(lock_badge)

	# 2. 3D Floating Target Item Beacon & Interaction Prompt above Cabinet
	var beacon := Node3D.new()
	beacon.name = "ItemBeacon"
	beacon.position = Vector3(0.0, cup_h + 1.05, 0.45)
	c_root.add_child(beacon)

	var icon_label := Label3D.new()
	icon_label.text = "%s" % item_dict.get("icon", "🎁")
	icon_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon_label.font_size = 46
	icon_label.outline_size = 12
	icon_label.outline_modulate = Color.BLACK
	beacon.add_child(icon_label)

	var prompt := Label3D.new()
	prompt.text = "🔒 KEY REQUIRED! FIND 🔑 KEY!" if req_key else "🚪 [ OPEN CABINET ]"
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if game_title_font != null:
		prompt.font = game_title_font
	prompt.font_size = 52
	prompt.outline_size = 16
	prompt.outline_modulate = Color.BLACK
	prompt.modulate = Color("#ff7675") if req_key else Color("#ffeaa7")
	prompt.position = Vector3(0.0, cup_h + 1.60, 0.55)
	prompt.visible = false
	c_root.add_child(prompt)

	# 3. Miniature Item placed INSIDE the cupboard (small cute size!)
	var mini_item := CollectibleItem.create_item_visual(item_dict["type"], item_dict["color"])
	mini_item.position = pos + Vector3(0.0, cup_h * 0.42, 0.0)
	mini_item.scale = Vector3(0.1, 0.1, 0.1)
	mini_item.visible = false
	parent.add_child(mini_item)

	# Backwards-compatibility references
	cupboard_root = c_root
	cupboard_door_left = door_left
	cupboard_door_right = door_right
	cupboard_prompt = prompt
	candy_node = mini_item

	var entry := {
		"id": item_dict["id"],
		"name": item_dict["name"],
		"icon": item_dict["icon"],
		"pos": pos,
		"root": c_root,
		"collider_aabb": cab_aabb,
		"door_left": door_left,
		"door_right": door_right,
		"beacon": beacon,
		"prompt": prompt,
		"lock_badge": lock_badge,
		"padlock": padlock_node,
		"requires_key": req_key,
		"item_node": mini_item,
		"is_open": false,
		"collected": false
	}
	active_containers.append(entry)

func _apply_custom_container_color(inst: Node3D, custom_color: Color) -> void:
	for found in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var orig = mi.get_active_material(s)
			if orig == null:
				orig = mi.mesh.surface_get_material(s)
			var mname: String = (orig as Resource).resource_name.to_lower() if (orig is Resource) else ""
			var mi_name: String = mi.name.to_lower()
			var mat := StandardMaterial3D.new()
			if mname.contains("metal") or mi_name.contains("handle") or mname.contains("gold"):
				mat.albedo_color = Color("#f1c40f") # Polished golden brass hardware
				mat.metallic = 0.85
				mat.roughness = 0.22
			elif mi_name.contains("door") or mi_name.contains("drawer"):
				mat.albedo_color = custom_color.lightened(0.18) # Lighter contrasting cabinet doors
				mat.metallic = 0.12
				mat.roughness = 0.32
			elif s > 0:
				mat.albedo_color = custom_color.lightened(0.28) # Shelves & inner trim
				mat.roughness = 0.38
			else:
				mat.albedo_color = custom_color.darkened(0.28) # Rich darker outer cabinet frame
				mat.metallic = 0.12
				mat.roughness = 0.40
			mi.set_surface_override_material(s, mat)

func _build_open_item(item_dict: Dictionary, parent: Node3D) -> void:
	var pos: Vector3 = item_dict["pos"]
	var mini_item := CollectibleItem.create_item_visual(item_dict["type"], item_dict["color"])
	mini_item.position = pos + Vector3(0.0, 0.35, 0.0)
	parent.add_child(mini_item)

	var entry := {
		"id": item_dict["id"],
		"name": item_dict["name"],
		"icon": item_dict["icon"],
		"pos": pos,
		"base_y": pos.y + 0.35,
		"node": mini_item,
		"rot_speed": 2.2,
		"collected": false
	}
	active_open_items.append(entry)

func _build_candy(pos: Vector3, color: Color, parent: Node3D) -> void:
	var item_entry := {
		"id": "candy_%d" % target_items.size(),
		"type": "candy",
		"name": "Candy",
		"icon": "🍭",
		"pos": pos,
		"color": color,
		"container": "cupboard"
	}
	target_items.append(item_entry)
	_build_item_cupboard(item_entry, parent)

func _on_key_collected() -> void:
	player_has_key = true
	if SoundManager != null:
		SoundManager.play_sfx("key")
	if SignalHub != null:
		SignalHub.emit_key_collected()
	_show_powerup_toast("KEY COLLECTED! LOCKED CABINET UNLOCKED!", Color("#f1c40f"))

	for c in active_containers:
		if bool(c.get("requires_key", false)) and not c["is_open"]:
			if is_instance_valid(c.get("lock_badge")):
				c["lock_badge"].text = "UNLOCKED!"
				c["lock_badge"].modulate = Color("#2ecc71")
			if is_instance_valid(c.get("padlock")):
				c["padlock"].queue_free()
			if is_instance_valid(c.get("prompt")):
				c["prompt"].text = "[ OPEN CABINET ]"
				c["prompt"].modulate = Color("#2ecc71")

func _open_container_and_collect(c: Dictionary) -> void:
	if c["is_open"]:
		return
	if bool(c.get("requires_key", false)) and not player_has_key:
		return
	c["is_open"] = true
	c["collected"] = true
	is_cupboard_open = true
	if SoundManager != null:
		SoundManager.play_sfx("cabinet")
	if SignalHub != null:
		SignalHub.emit_cabinet_opened(c.get("id", ""))

	# Hide floating item beacon, prompt, and lock badge cleanly without zero-scale matrix errors
	if is_instance_valid(c.get("beacon")):
		c["beacon"].visible = false
		c["beacon"].queue_free()
	if is_instance_valid(c.get("lock_badge")):
		c["lock_badge"].visible = false
		c["lock_badge"].queue_free()
	if is_instance_valid(c.get("padlock")):
		c["padlock"].visible = false
		c["padlock"].queue_free()
	if is_instance_valid(c.get("prompt")):
		c["prompt"].visible = false
		c["prompt"].queue_free()

	# Animate Cupboard Doors Swinging Open!
	var tw := create_tween()
	tw.set_parallel(true)
	if is_instance_valid(c["door_left"]):
		tw.tween_property(c["door_left"], "rotation:y", deg_to_rad(-110.0), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(c["door_right"]):
		tw.tween_property(c["door_right"], "rotation:y", deg_to_rad(110.0), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Immediately register item collection so there is zero delay or hang!
	var item_node: Node3D = c["item_node"]
	_on_item_collected(c["id"], c["name"], c["icon"], item_node)

func _open_cupboard_and_collect() -> void:
	if active_containers.size() > 0:
		_open_container_and_collect(active_containers[0])

func _create_spawn_marker(pos: Vector3, parent: Node3D) -> void:
	spawn_marker_pos = pos
	var pad := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.4, 0.015, 1.6)
	pad.mesh = box
	pad.position = pos + Vector3(0.0, 0.01, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#2c3e50")
	pad.material_override = mat
	parent.add_child(pad)

	var border := MeshInstance3D.new()
	var b_box := BoxMesh.new()
	b_box.size = Vector3(2.55, 0.014, 1.75)
	border.mesh = b_box
	border.position = pos + Vector3(0.0, 0.008, 0.0)
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = Color("#f1c40f")
	border.material_override = b_mat
	spawn_marker_border_mat = b_mat
	parent.add_child(border)

	var label := Label3D.new()
	label.text = "🚪 ENTRANCE / EXIT"
	label.position = pos + Vector3(0.0, 0.02, 0.0)
	label.rotation_degrees.x = -90.0
	if game_title_font != null:
		label.font = game_title_font
	label.font_size = 28
	label.modulate = Color("#ffeaa7")
	label.outline_size = 8
	label.outline_modulate = Color("#2d3436")
	spawn_marker_label = label
	parent.add_child(label)

func _get_floor_tile_texture() -> ImageTexture:
	if floor_tile_texture != null:
		return floor_tile_texture

	var size := 256
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var base_col := Color("#5a7a94") # Crisp stylish slate-blue ceramic tile matching reference image
	var grout_col := Color("#2c3e50") # Deep slate blue grout seam
	var bevel_light := Color("#7d9cb6") # Soft top-left light highlight
	var bevel_dark := Color("#41596e") # Soft bottom-right bevel shade

	# Fill with base ceramic color with subtle natural texture grain
	for y in range(size):
		for x in range(size):
			var noise_val := (sin(float(x) * 0.35) * cos(float(y) * 0.35)) * 0.025
			var grain := (float((x * 37 + y * 17) % 19) / 19.0 - 0.5) * 0.02
			var c := base_col
			c.r = clampf(c.r + noise_val + grain, 0.0, 1.0)
			c.g = clampf(c.g + noise_val + grain, 0.0, 1.0)
			c.b = clampf(c.b + noise_val + grain, 0.0, 1.0)
			img.set_pixel(x, y, c)

	# Grout seams (outer 4 pixels on each border)
	var border := 4
	for x in range(size):
		for b in range(border):
			img.set_pixel(x, b, grout_col)
			img.set_pixel(x, size - 1 - b, grout_col)
	for y in range(size):
		for b in range(border):
			img.set_pixel(b, y, grout_col)
			img.set_pixel(size - 1 - b, y, grout_col)

	# 3D Bevel highlight (top and left inner border)
	for x in range(border, size - border):
		for b in range(border, border + 3):
			img.set_pixel(x, b, bevel_light)
	for y in range(border, size - border):
		for b in range(border, border + 3):
			img.set_pixel(b, y, bevel_light)

	# 3D Bevel shade (bottom and right inner border)
	for x in range(border, size - border):
		for b in range(size - border - 3, size - border):
			img.set_pixel(x, b, bevel_dark)
	for y in range(border, size - border):
		for b in range(size - border - 3, size - border):
			img.set_pixel(b, y, bevel_dark)

	img.generate_mipmaps()
	floor_tile_texture = ImageTexture.create_from_image(img)
	return floor_tile_texture

var floor_tile_normal_tex: ImageTexture = null

func _get_floor_tile_normal() -> ImageTexture:
	if floor_tile_normal_tex != null:
		return floor_tile_normal_tex

	var size := 256
	var img := Image.create(size, size, true, Image.FORMAT_RGBA8)
	var flat_norm := Color(0.5, 0.5, 1.0)
	var light_norm := Color(0.35, 0.35, 0.87)
	var dark_norm := Color(0.65, 0.65, 0.87)
	var grout_norm := Color(0.5, 0.5, 0.5)

	img.fill(flat_norm)
	var border := 4
	for x in range(size):
		for b in range(border):
			img.set_pixel(x, b, grout_norm)
			img.set_pixel(x, size - 1 - b, grout_norm)
	for y in range(size):
		for b in range(border):
			img.set_pixel(b, y, grout_norm)
			img.set_pixel(size - 1 - b, y, grout_norm)

	for x in range(border, size - border):
		for b in range(border, border + 3):
			img.set_pixel(x, b, light_norm)
	for y in range(border, size - border):
		for b in range(border, border + 3):
			img.set_pixel(b, y, light_norm)

	for x in range(border, size - border):
		for b in range(size - border - 3, size - border):
			img.set_pixel(x, b, dark_norm)
	for y in range(border, size - border):
		for b in range(size - border - 3, size - border):
			img.set_pixel(b, y, dark_norm)

	img.generate_mipmaps()
	floor_tile_normal_tex = ImageTexture.create_from_image(img)
	return floor_tile_normal_tex

var wall_mat: StandardMaterial3D = null
var floor_tile_tex: Texture2D = null
var floor_tile_norm: Texture2D = null

func _get_wall_material() -> StandardMaterial3D:
	if wall_mat != null:
		return wall_mat
	wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color("#E8E2D2") # Restored previous clean architectural cream/beige
	wall_mat.roughness = 0.55
	return wall_mat

func _get_floor_material(width: float, depth: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = _get_floor_tile_texture()
	mat.normal_enabled = true
	mat.normal_texture = _get_floor_tile_normal()
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.85, 0.85, 0.85) # ~1.18m square tiles matching reference
	mat.roughness = 0.28
	return mat

func _create_room_floor(center: Vector3, width: float, depth: float, parent: Node3D) -> void:
	var floor_mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, 0.05, depth)
	floor_mesh.mesh = box
	floor_mesh.position = center + Vector3(0.0, -0.02, 0.0)
	floor_mesh.material_override = _get_floor_material(width, depth)
	parent.add_child(floor_mesh)

func _create_wall(pos: Vector3, size: Vector3, parent: Node3D) -> void:
	var wall := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	wall.mesh = box
	wall.position = pos
	wall.material_override = _get_wall_material()
	parent.add_child(wall)

	var aabb := AABB(pos - size * 0.5, size)
	wall_colliders.append(aabb)

func _create_interior_door(pos: Vector3, dw: float, col: Color, req_key: bool, parent: Node3D) -> DoorController:
	var door := DoorController.new()
	door.position = pos
	door.setup(dw, col, req_key)
	parent.add_child(door)
	active_doors.append(door)
	return door

func _create_coin_pickup(pos: Vector3, reward: int, parent: Node3D) -> Node3D:
	var coin := Node3D.new()
	coin.name = "CoinPickup"
	coin.position = pos + Vector3(0.0, 0.45, 0.0)

	var mesh_inst := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.22
	cyl.bottom_radius = 0.22
	cyl.height = 0.06
	mesh_inst.mesh = cyl
	mesh_inst.rotation_degrees.x = 90.0

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#f1c40f")
	mat.metallic = 0.8
	mat.roughness = 0.2
	mat.emission_enabled = true
	mat.emission = Color("#f39c12")
	mat.emission_energy_multiplier = 0.4
	mesh_inst.material_override = mat
	coin.add_child(mesh_inst)

	parent.add_child(coin)
	return coin

func _build_player() -> void:
	var p_info: Dictionary = active_level_data.get("characters", {}).get("player", {})
	var p_pos_arr: Array = p_info.get("pos", [0.0, 0.0, 3.8])
	player_spawn_pos = Vector3(float(p_pos_arr[0]), 0.0, float(p_pos_arr[2]))

	player_root = Node3D.new()
	player_root.name = "Player"
	# Spawn player outside the entrance door so they walk in through the door at level start.
	player_root.position = entrance_outside_pos
	is_entering_level = true
	level_root.add_child(player_root)

	var boy_scene: PackedScene = load(BOY_MODEL_PATH) as PackedScene if ResourceLoader.exists(BOY_MODEL_PATH) else null
	var boy_inst: Node3D = boy_scene.instantiate() as Node3D if boy_scene != null else Node3D.new()
	player_mesh = boy_inst
	player_mesh.scale = Vector3.ONE * 0.55
	player_mesh.rotation.y = PI
	player_target_rotation = PI
	player_root.add_child(player_mesh)

	# Apply authentic skater texture to Player model (matching pink outfit in reference)
	var skin_texture := load("res://assets/models/boys/Skins/skaterFemaleA.png") as Texture2D
	if skin_texture != null:
		for found in player_mesh.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := found as MeshInstance3D
			if mesh_instance.mesh == null:
				continue
			for surface in mesh_instance.mesh.get_surface_count():
				var material := mesh_instance.get_active_material(surface)
				var textured_material := StandardMaterial3D.new()
				if material is StandardMaterial3D:
					textured_material = (material as StandardMaterial3D).duplicate() as StandardMaterial3D
				textured_material.albedo_texture = skin_texture
				textured_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				textured_material.albedo_color.a = 1.0
				textured_material.emission_enabled = true
				textured_material.emission = Color.BLACK
				textured_material.emission_energy_multiplier = 0.0
				mesh_instance.set_surface_override_material(surface, textured_material)

	# Load Boy animation clips
	player_anim = player_mesh.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player_anim == null:
		player_anim = AnimationPlayer.new()
		player_anim.name = "AnimationPlayer"
		player_anim.root_node = NodePath("..")
		player_mesh.add_child(player_anim)

	_add_boy_animation("Idle", "res://assets/models/boys/Animations/idle.fbx", "Root|Idle")
	_add_boy_animation("Run", "res://assets/models/boys/Animations/run.fbx", "Root|Run")
	if player_anim.has_animation("Idle"):
		player_anim.play("Idle")

func _add_boy_animation(animation_name: String, scene_path: String, source_animation_name: String) -> void:
	var animation_scene := load(scene_path) as PackedScene
	if animation_scene == null or not is_instance_valid(player_anim):
		return
	var animation_root := animation_scene.instantiate()
	var source_player := animation_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if source_player == null or not source_player.has_animation(source_animation_name):
		animation_root.free()
		return
	var library: AnimationLibrary
	if player_anim.has_animation_library(""):
		library = player_anim.get_animation_library("")
	else:
		library = AnimationLibrary.new()
		player_anim.add_animation_library("", library)
	var animation := source_player.get_animation(source_animation_name).duplicate(true) as Animation
	animation.loop_mode = Animation.LOOP_LINEAR
	if library.has_animation(animation_name):
		library.remove_animation(animation_name)
	library.add_animation(animation_name, animation)
	animation_root.free()

	var cam_y: float = 27.5
	var init_cam_x := player_spawn_pos.x * 0.75
	if not active_level_data.is_empty():
		var cam_p: Array = active_level_data.get("camera", {}).get("position", [init_cam_x, 27.5, player_spawn_pos.z + 4.5])
		cam_y = float(cam_p[1])
		init_cam_x = float(cam_p[0])
	main_camera.position = Vector3(init_cam_x, cam_y, player_spawn_pos.z + 4.5)

func _process(delta: float) -> void:
	_update_powerups(delta)

	if is_spotted or is_level_cleared:
		return

	# 1. Update Keys
	for key in active_keys:
		if is_instance_valid(key) and is_instance_valid(player_root):
			key.update_animation(delta, player_root.position)

	# 2. Update Floor Buttons & Props
	var props_positions: Array[Vector3] = []
	for prop in active_props:
		if is_instance_valid(prop):
			props_positions.append(prop.position)
			if is_instance_valid(player_root):
				prop.apply_push(player_root.position, PLAYER_SPEED, delta, wall_colliders)

	for btn in active_buttons:
		if is_instance_valid(btn) and is_instance_valid(player_root):
			btn.check_activation(player_root.position, props_positions)

	# 3. Laser Barriers eliminated (Guards are sole threat)

	# 4. Update Doors
	for door in active_doors:
		if is_instance_valid(door) and is_instance_valid(player_root):
			door.update_door(delta, player_root.position, player_has_key)

	# 5. Update Security Cameras & Guards (Guards & Cameras cannot see invisible or entering player!)
	var guard_colliders: Array[AABB] = wall_colliders.duplicate()
	for d in active_doors:
		if is_instance_valid(d) and not d.is_open:
			guard_colliders.append(d.collider_aabb)

	var hidden_from_enemies := is_player_invisible or is_entering_level or is_intro_cinematic_active
	for cam in active_cameras:
		if is_instance_valid(cam) and is_instance_valid(player_root):
			cam.update_camera(delta, player_root.position, guard_colliders, hidden_from_enemies)

	for guard in active_guards:
		if is_instance_valid(guard) and is_instance_valid(player_root):
			guard.update_guard(delta, player_root.position, guard_colliders, hidden_from_enemies)

	# 6. Multi-Item Containers (Cupboards) & Open Pickups Interaction
	for c in active_containers:
		if not c["is_open"]:
			var dist := player_root.position.distance_to(c["pos"]) if is_instance_valid(player_root) else 999.0
			var needs_key: bool = bool(c.get("requires_key", false)) and not player_has_key
			if is_instance_valid(c.get("beacon")):
				c["beacon"].position.y = 2.95 + sin(Time.get_ticks_msec() * 0.005) * 0.10
			if is_instance_valid(c.get("lock_badge")):
				c["lock_badge"].position.y = 2.35 + sin(Time.get_ticks_msec() * 0.006) * 0.08
			if is_instance_valid(c["prompt"]):
				c["prompt"].visible = (dist < 4.5)
				var pulse := sin(Time.get_ticks_msec() * 0.006) * 0.08
				c["prompt"].position.y = 3.85 + pulse
				if needs_key:
					c["prompt"].text = "KEY REQUIRED! COLLECT KEY!"
					c["prompt"].modulate = Color("#ff7675")
			if is_instance_valid(player_root) and dist < 2.15:
				if not needs_key:
					_open_container_and_collect(c)
				elif SoundManager != null:
					SoundManager.play_sfx("locked")

	for it_data in active_open_items:
		if not it_data["collected"] and is_instance_valid(it_data["node"]):
			it_data["node"].rotation.y += delta * float(it_data.get("rot_speed", 2.2))
			it_data["node"].position.y = float(it_data["base_y"]) + sin(Time.get_ticks_msec() * 0.005) * 0.05
			if is_instance_valid(player_root) and player_root.position.distance_to(it_data["pos"]) < 1.35:
				it_data["collected"] = true
				_on_item_collected(it_data["id"], it_data["name"], it_data["icon"], it_data["node"])

	# 7. Player Movement & Dynamic Camera Follow (X and Z)
	if is_instance_valid(player_root):
		if not is_intro_cinematic_active:
			_handle_player_movement(delta)
			var target_cam_x := player_root.position.x * 0.75
			var target_cam_z := player_root.position.z + 4.5
			main_camera.position.x = lerpf(main_camera.position.x, target_cam_x, delta * 6.0)
			main_camera.position.y = lerpf(main_camera.position.y, 27.5, delta * 6.0)
			main_camera.position.z = lerpf(main_camera.position.z, target_cam_z, delta * 6.0)

		# Victory check: level completes ONLY when player collects all required items AND walks outside through the entrance door!
		var all_collected := (collected_items_count >= target_items_total and target_items_total > 0) or candy_collected
		if all_collected and not is_entering_level and not is_level_cleared:
			var at_outside_exit := (player_root.position.z >= entrance_door_pos.z + 1.0 and absf(player_root.position.x - entrance_door_pos.x) < 2.6) or player_root.position.distance_to(entrance_outside_pos) < 2.2
			if at_outside_exit:
				_trigger_win()

func _on_item_collected(item_id: String, item_name: String, _icon: String, item_node: Node3D) -> void:
	collected_items_count += 1
	if SoundManager != null:
		SoundManager.play_sfx("collect")
	if is_instance_valid(item_node):
		item_node.visible = true
		item_node.scale = Vector3(0.25, 0.25, 0.25)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(item_node, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(item_node, "position:y", item_node.position.y + 0.9, 0.22)
		tw.chain().tween_interval(0.18)
		tw.chain().tween_callback(func():
			if is_instance_valid(item_node):
				item_node.visible = false
				item_node.queue_free()
		)

	_show_powerup_toast("%s RETRIEVED! (%d/%d ITEMS RECOVERED)" % [item_name.to_upper(), collected_items_count, target_items_total], Color("#ffeaa7"))
	_update_item_collector_hud(item_id)
	if SignalHub != null:
		SignalHub.emit_item_collected(item_id, item_name, collected_items_count, target_items_total)

	if collected_items_count >= target_items_total:
		all_items_collected = true
		candy_collected = true
		_update_hud_objective("🏃 ALL ITEMS RECOVERED! RETURN TO START TO ESCAPE!")
		_show_powerup_toast("🎉 ALL ITEMS RETRIEVED! RETURN TO START TO ESCAPE!", Color("#2ecc71"))
		if is_instance_valid(spawn_marker_label):
			spawn_marker_label.text = "🚪 ESCAPE HERE!"
			spawn_marker_label.modulate = Color("#2ecc71")
		if is_instance_valid(spawn_marker_border_mat):
			spawn_marker_border_mat.albedo_color = Color("#2ecc71")
		if SoundManager != null:
			SoundManager.play_sfx("door")
	else:
		_update_hud_objective("FIND REMAINING ITEMS! (%d/%d)" % [collected_items_count, target_items_total])

func _on_candy_collected() -> void:
	if active_containers.size() > 0:
		var c: Dictionary = active_containers[0]
		_on_item_collected(c["id"], c["name"], c["icon"], candy_node)
	else:
		_on_item_collected("candy_0", "Candy", "🍭", candy_node)

func _update_hud_objective(text: String) -> void:
	if is_instance_valid(hud_root):
		var lbl := hud_root.get_node_or_null("ObjectiveLabel") as Label
		if is_instance_valid(lbl):
			lbl.text = text

func _trigger_win() -> void:
	if is_level_cleared or is_spotted:
		return
	is_level_cleared = true
	if SoundManager != null:
		SoundManager.stop_footstep()
		SoundManager.play_sfx("victory")
	if SignalHub != null:
		SignalHub.emit_level_victory(current_level, 20)
	_update_hud_objective("🎉 LEVEL COMPLETED!")
	# Make player run OUT the exit door upon completing the level!
	if is_instance_valid(player_root):
		player_target_rotation = 0.0
		if is_instance_valid(player_mesh):
			player_mesh.rotation.y = 0.0
		if is_instance_valid(player_anim) and player_anim.has_animation("Run"):
			player_anim.play("Run")
		var exit_tw := create_tween()
		exit_tw.tween_property(player_root, "position", entrance_outside_pos, 0.55).set_trans(Tween.TRANS_SINE)
	_show_victory_popup()

func _handle_player_movement(delta: float) -> void:
	var move_dir := Vector3.ZERO
	if is_entering_level:
		var entry_diff := player_spawn_pos - player_root.position
		entry_diff.y = 0.0
		if entry_diff.length() > 0.35:
			move_dir = entry_diff.normalized()
		else:
			player_root.position = player_spawn_pos
			is_entering_level = false

	if not is_entering_level:
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move_dir.x -= 1.0
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move_dir.x += 1.0
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move_dir.z -= 1.0
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move_dir.z += 1.0
		# Mobile Virtual Joystick & Touch Drag Movement
		if is_touch_active and touch_move_dir.length_squared() > 0.01:
			move_dir = touch_move_dir
		elif not is_touch_active:
			touch_move_dir = Vector3.ZERO
		if auto_walk_forward:
			move_dir.z -= 1.0
		if auto_walk_loop:
			var all_collected := (collected_items_count >= target_items_total and target_items_total > 0) or candy_collected
			if not all_collected:
				var target_pos := Vector3(0.0, 0.0, -5.0)
				var seek_key := false
				if not player_has_key and active_keys.size() > 0:
					for k in active_keys:
						if is_instance_valid(k) and not k.is_collected:
							target_pos = k.position
							seek_key = true
							break
				if not seek_key:
					for c in active_containers:
						if not c["is_open"]:
							target_pos = c["pos"]
							break
				var diff := target_pos - player_root.position
				diff.y = 0.0
				if diff.length() > 0.2:
					move_dir = diff.normalized()
			elif not is_level_cleared:
				var diff := entrance_outside_pos - player_root.position
				diff.y = 0.0
				if diff.length() > 0.2:
					move_dir = diff.normalized()

	if move_dir.length_squared() > 0.01:
		var prev_player_pos := player_root.position
		move_dir = move_dir.normalized()
		player_target_rotation = atan2(move_dir.x, move_dir.z)

		var current_speed := PLAYER_SPEED * (1.55 if speed_boost_time > 0.0 else 1.0)
		var move_step := move_dir * current_speed * delta

		# Move along X with pushable prop interaction
		var step_x := Vector3(move_step.x, 0.0, 0.0)
		var next_x := player_root.position + step_x
		var pushed_x := false
		for prop in active_props:
			if is_instance_valid(prop) and next_x.distance_to(prop.position) < (prop.prop_radius + 0.35):
				if prop.try_push(step_x * 1.15, wall_colliders, active_props):
					pushed_x = true
		if not _is_player_colliding_walls(next_x):
			if not _is_player_colliding_props(next_x) or pushed_x:
				player_root.position.x = next_x.x

		# Move along Z with pushable prop interaction
		var step_z := Vector3(0.0, 0.0, move_step.z)
		var next_z := player_root.position + step_z
		var pushed_z := false
		for prop in active_props:
			if is_instance_valid(prop) and next_z.distance_to(prop.position) < (prop.prop_radius + 0.35):
				if prop.try_push(step_z * 1.15, wall_colliders, active_props):
					pushed_z = true
		if not _is_player_colliding_walls(next_z):
			if not _is_player_colliding_props(next_z) or pushed_z:
				player_root.position.z = next_z.z

		# Prevent player from leaving through the south entrance door before collecting all items!
		var all_done := (collected_items_count >= target_items_total and target_items_total > 0) or candy_collected
		if not is_entering_level and not all_done:
			player_root.position.z = minf(player_root.position.z, entrance_door_pos.z - 0.55)

		# Solid cabinet push-out: Prevent player from ever walking inside any item cabinet!
		for c_entry in active_containers:
			var cab_aabb: AABB = c_entry.get("collider_aabb", AABB())
			if cab_aabb.size.length_squared() > 0.01:
				var exp_cab := cab_aabb.grow(0.26)
				if exp_cab.has_point(player_root.position):
					var cc := cab_aabb.get_center()
					var c_diff := player_root.position - cc
					var c_half := cab_aabb.size * 0.5 + Vector3(0.26, 0.0, 0.26)
					var ox := c_half.x - absf(c_diff.x)
					var oz := c_half.z - absf(c_diff.z)
					if ox > 0.0 and oz > 0.0:
						if ox < oz:
							var s_x := 1.0 if c_diff.x >= 0.0 else -1.0
							player_root.position.x = cc.x + s_x * (cab_aabb.size.x * 0.5 + 0.28)
						else:
							var s_z := 1.0 if c_diff.z >= 0.0 else -1.0
							player_root.position.z = cc.z + s_z * (cab_aabb.size.z * 0.5 + 0.28)

		# Strict push-out: Repel player if penetrating any wall collider (unless Wall Pass powerup or entering level!)
		if not is_wall_pass_active and not is_entering_level:
			for aabb in wall_colliders:
				var expanded := aabb.grow(0.32)
				if expanded.has_point(player_root.position):
					var c := aabb.get_center()
					var diff := player_root.position - c
					var half_size := aabb.size * 0.5 + Vector3(0.32, 0.0, 0.32)
					var overlap_x := half_size.x - absf(diff.x)
					var overlap_z := half_size.z - absf(diff.z)
					if overlap_x > 0.0 and overlap_z > 0.0:
						if overlap_x < overlap_z:
							player_root.position.x = c.x + signf(diff.x) * (aabb.size.x * 0.5 + 0.35)
						else:
							player_root.position.z = c.z + signf(diff.z) * (aabb.size.z * 0.5 + 0.35)

		if is_instance_valid(player_mesh):
			player_mesh.rotation.y = lerp_angle(player_mesh.rotation.y, player_target_rotation, delta * 14.0)
		if is_instance_valid(player_anim) and player_anim.has_animation("Run"):
			if player_anim.current_animation != "Run":
				player_anim.play("Run")

		# Spawn fading footstep decals and sound only when actually moving
		if player_root.position.distance_to(prev_player_pos) > 0.005:
			footstep_mgr.spawn_footstep_if_needed(level_root, player_root.position, player_target_rotation)
		elif SoundManager != null:
			SoundManager.stop_footstep()
	else:
		if SoundManager != null:
			SoundManager.stop_footstep()
		if is_instance_valid(player_anim) and player_anim.has_animation("Idle"):
			if player_anim.current_animation != "Idle":
				player_anim.play("Idle")

func _is_player_colliding_walls(test_pos: Vector3) -> bool:
	if is_wall_pass_active or is_entering_level:
		return false
	for aabb in wall_colliders:
		if aabb.grow(0.32).has_point(test_pos):
			return true
	for door in active_doors:
		if is_instance_valid(door) and not door.is_open:
			if door.collider_aabb.grow(0.30).has_point(test_pos):
				return true
	return false

func _is_player_colliding_props(test_pos: Vector3) -> bool:
	for c in active_containers:
		var cab_aabb: AABB = c.get("collider_aabb", AABB())
		if cab_aabb.size.length_squared() > 0.01 and cab_aabb.grow(0.26).has_point(test_pos):
			return true
	for prop in active_props:
		if is_instance_valid(prop):
			if test_pos.distance_to(prop.position) < (prop.prop_radius + 0.28):
				return true
	return false

func _is_player_colliding(test_pos: Vector3) -> bool:
	return _is_player_colliding_walls(test_pos) or _is_player_colliding_props(test_pos)

func _on_button_pressed(target_laser_id: String) -> void:
	if active_lasers.has(target_laser_id):
		active_lasers[target_laser_id].deactivate()

func _trigger_fail(reason: String) -> void:
	if auto_walk_loop or is_catch_cinematic_active:
		return
	if is_spotted or is_level_cleared:
		return
	is_spotted = true
	is_catch_cinematic_active = true
	_reset_mobile_touch()

	if SoundManager != null:
		SoundManager.stop_footstep()
		SoundManager.play_sfx("catch")
	if SignalHub != null:
		SignalHub.emit_level_failed(current_level, reason)
	_update_hud_objective("🚨 CAUGHT BY GRANNY!")

	# 1. Locate the catching Granny/guard nearest to the player
	var closest_guard: GuardController = null
	var min_g_dist := 9999.0
	if is_instance_valid(player_root):
		for g in active_guards:
			if is_instance_valid(g):
				var d := g.position.distance_to(player_root.position)
				if d < min_g_dist:
					min_g_dist = d
					closest_guard = g

	# 2. Granny confrontation behavior: steps forward, confronts boy, exclaims
	if closest_guard != null and is_instance_valid(player_root):
		closest_guard.play_catch_confrontation(player_root.position)

	# 3. Boy startled / caught reaction: turns to face Granny, startled jump, exclamation bubble
	if is_instance_valid(player_root):
		if closest_guard != null:
			var to_g := closest_guard.position - player_root.position
			to_g.y = 0.0
			if to_g.length() > 0.01 and is_instance_valid(player_mesh):
				player_mesh.rotation.y = atan2(to_g.x, to_g.z)
		if is_instance_valid(player_anim) and player_anim.has_animation("Idle"):
			player_anim.play("Idle")

		# Startled hop
		var hop_tw := create_tween()
		hop_tw.tween_property(player_root, "position:y", 0.42, 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		hop_tw.tween_property(player_root, "position:y", 0.0, 0.22).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)

		# Floating comic bubble above Boy
		var bubble := Label3D.new()
		bubble.name = "BoyCatchBubble"
		bubble.text = "😱 OH NO!"
		bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		bubble.position = player_root.position + Vector3(0.0, 1.85, 0.0)
		if game_title_font != null:
			bubble.font = game_title_font
		bubble.font_size = 42
		bubble.outline_size = 12
		bubble.outline_modulate = Color("#2c0b0e")
		bubble.modulate = Color("#ffeaa7")
		bubble.scale = Vector3.ZERO
		add_child(bubble)
		var bubble_tw := create_tween()
		bubble_tw.tween_property(bubble, "scale", Vector3.ONE * 1.35, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		bubble_tw.tween_property(bubble, "scale", Vector3.ONE, 0.12)

	# 4. Cinematic Letterbox & "BUSTED BY GRANNY" Banner
	_create_catch_letterbox()

	# 5. Dramatic Movie Camera Glide Framing Both Characters
	if is_instance_valid(main_camera) and is_instance_valid(player_root):
		var focus_target: Vector3 = player_root.position
		var face_offset := Vector3.ZERO
		if closest_guard != null:
			focus_target = (player_root.position + closest_guard.position) * 0.5
			var diff := closest_guard.position - player_root.position
			var side := Vector3(-diff.z, 0.0, diff.x).normalized()
			face_offset = side * 0.75

		var target_cam_pos := focus_target + Vector3(0.0, 7.2, 4.4) + face_offset * 0.5
		var target_cam_rot := Vector3(-58.0, 0.0, 0.0)

		if is_instance_valid(catch_cinematic_tween):
			catch_cinematic_tween.kill()
		catch_cinematic_tween = create_tween().set_parallel(true)
		catch_cinematic_tween.tween_property(main_camera, "position", target_cam_pos, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		catch_cinematic_tween.tween_property(main_camera, "rotation_degrees", target_cam_rot, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		catch_cinematic_tween.tween_property(main_camera, "fov", 40.0, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

		# Impact camera punch
		get_tree().create_timer(0.26).timeout.connect(func():
			if is_instance_valid(main_camera):
				var shake_tw := create_tween()
				shake_tw.tween_property(main_camera, "h_offset", 0.07, 0.04)
				shake_tw.tween_property(main_camera, "h_offset", -0.06, 0.04)
				shake_tw.tween_property(main_camera, "h_offset", 0.0, 0.04)
		)

	# 6. Dramatic Pause: let the player witness Granny catching the boy unfold like a movie!
	await get_tree().create_timer(1.45).timeout

	# 7. Clean up cinematic overlay before presenting fail popup
	if is_instance_valid(catch_letterbox_layer):
		catch_letterbox_layer.queue_free()
		catch_letterbox_layer = null
	var b_node := get_node_or_null("BoyCatchBubble")
	if is_instance_valid(b_node):
		b_node.queue_free()

	_show_fail_popup(reason)

func _create_catch_letterbox() -> void:
	if is_instance_valid(catch_letterbox_layer):
		catch_letterbox_layer.queue_free()

	catch_letterbox_layer = CanvasLayer.new()
	catch_letterbox_layer.layer = 110
	add_child(catch_letterbox_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	catch_letterbox_layer.add_child(root)

	# Top Cinema Bar (slides down)
	var top_bar := ColorRect.new()
	top_bar.color = Color.BLACK
	top_bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_bar.offset_top = -120.0
	top_bar.offset_bottom = 0.0
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_bar)

	# Bottom Cinema Bar (slides up)
	var bottom_bar := ColorRect.new()
	bottom_bar.color = Color.BLACK
	bottom_bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom_bar.offset_top = 0.0
	bottom_bar.offset_bottom = 120.0
	bottom_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bottom_bar)

	# Subtle red dramatic vignette
	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.9, 0.1, 0.1, 0.28)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(vignette)

	# Comic Center Banner: "🚨 BUSTED BY GRANNY! 🚨"
	var banner_box := PanelContainer.new()
	banner_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner_box.offset_top = 100.0
	banner_box.offset_left = -280.0
	banner_box.offset_right = 280.0
	banner_box.offset_bottom = 180.0
	banner_box.pivot_offset = Vector2(280.0, 40.0)
	banner_box.scale = Vector2.ZERO

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.88, 0.12, 0.18, 0.95)
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4
	sb.border_color = Color("#f1c40f")
	sb.corner_radius_top_left = 16
	sb.corner_radius_top_right = 16
	sb.corner_radius_bottom_left = 16
	sb.corner_radius_bottom_right = 16
	sb.shadow_size = 12
	sb.shadow_color = Color(0, 0, 0, 0.6)
	banner_box.add_theme_stylebox_override("panel", sb)
	root.add_child(banner_box)

	var lbl := Label.new()
	lbl.text = "🚨 BUSTED BY GRANNY! 🚨"
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if game_title_font != null:
		lbl.add_theme_font_override("font", game_title_font)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 8)
	banner_box.add_child(lbl)

	# Animate bars & banner
	var tw := create_tween().set_parallel(true)
	tw.tween_property(top_bar, "offset_bottom", 85.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(bottom_bar, "offset_top", -85.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(vignette, "color:a", 0.08, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(banner_box, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _setup_hud() -> void:
	hud_root = CanvasLayer.new()
	add_child(hud_root)

	# 1. Bold Cartoon Level Label at Top Center (Consistent, Compact Scale)
	var lvl_lbl := Label.new()
	lvl_lbl.name = "LevelLabel"
	lvl_lbl.text = "LEVEL\n%d" % current_level
	lvl_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lvl_lbl.offset_top = 18.0
	lvl_lbl.offset_bottom = 85.0
	lvl_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		lvl_lbl.add_theme_font_override("font", game_title_font)
	lvl_lbl.add_theme_font_size_override("font_size", 32)
	lvl_lbl.add_theme_color_override("font_color", Color.WHITE)
	lvl_lbl.add_theme_color_override("font_outline_color", Color("#2c3e50"))
	lvl_lbl.add_theme_constant_override("outline_size", 9)
	hud_root.add_child(lvl_lbl)

	# Objective Sub-Label (Hidden - only items and icons shown)
	var obj_lbl := Label.new()
	obj_lbl.name = "ObjectiveLabel"
	obj_lbl.text = ""
	obj_lbl.visible = false
	obj_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	obj_lbl.offset_top = 80.0
	obj_lbl.offset_bottom = 118.0
	obj_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		obj_lbl.add_theme_font_override("font", game_title_font)
	obj_lbl.add_theme_font_size_override("font_size", 22)
	obj_lbl.add_theme_color_override("font_color", Color("#ffeaa7"))
	obj_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	obj_lbl.add_theme_constant_override("outline_size", 8)
	hud_root.add_child(obj_lbl)

	# 1b. Settings / Pause Icon Button at Top Left (Crisp 64x64 Gear Icon)
	var pause_btn := TextureButton.new()
	pause_btn.name = "PauseButton"
	pause_btn.texture_normal = _load_ui_texture("res://assets/ui/icons/icon-settings.png")
	pause_btn.ignore_texture_size = true
	pause_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	pause_btn.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pause_btn.offset_left = 24.0
	pause_btn.offset_top = 22.0
	pause_btn.offset_right = 80.0
	pause_btn.offset_bottom = 78.0
	pause_btn.pivot_offset = Vector2(28, 28)
	pause_btn.pressed.connect(_on_pause_pressed)
	pause_btn.button_down.connect(func():
		var tw := pause_btn.create_tween()
		tw.tween_property(pause_btn, "scale", Vector2(0.9, 0.9), 0.06)
	)
	pause_btn.button_up.connect(func():
		var tw := pause_btn.create_tween()
		tw.tween_property(pause_btn, "scale", Vector2(1.08, 1.08), 0.09)
		tw.tween_property(pause_btn, "scale", Vector2.ONE, 0.08)
	)
	hud_root.add_child(pause_btn)

	# 2. Coin Pill Badge at Top Right (Compact & Consistent)
	coin_panel = PanelContainer.new()
	coin_panel.name = "CoinPanel"
	coin_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coin_panel.offset_left = -175.0
	coin_panel.offset_top = 22.0
	coin_panel.offset_right = -25.0
	coin_panel.offset_bottom = 70.0
	coin_panel.pivot_offset = Vector2(75.0, 24.0)

	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color.WHITE
	pill_style.set_corner_radius_all(24)
	pill_style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	pill_style.shadow_size = 4
	coin_panel.add_theme_stylebox_override("panel", pill_style)
	hud_root.add_child(coin_panel)

	var coin_box := HBoxContainer.new()
	coin_box.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_panel.add_child(coin_box)

	var coin_icon := TextureRect.new()
	coin_icon.texture = _load_ui_texture("res://assets/ui/reward-coin.png")
	coin_icon.custom_minimum_size = Vector2(26, 26)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_box.add_child(coin_icon)

	coin_lbl = Label.new()
	coin_lbl.text = " %d" % coins
	if game_title_font != null:
		coin_lbl.add_theme_font_override("font", game_title_font)
	coin_lbl.add_theme_font_size_override("font_size", 20)
	coin_lbl.add_theme_color_override("font_color", Color("#2d3436"))
	coin_box.add_child(coin_lbl)

	# 2b. Compact "Get Coins" Rewarded Ad Button right under Coin Pill
	var get_coins_btn := Button.new()
	get_coins_btn.name = "GetCoinsAdButton"
	get_coins_btn.text = "🎬 +30 COINS"
	get_coins_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	get_coins_btn.offset_left = -175.0
	get_coins_btn.offset_top = 76.0
	get_coins_btn.offset_right = -25.0
	get_coins_btn.offset_bottom = 110.0
	var gc_style := StyleBoxFlat.new()
	gc_style.bg_color = Color("#f39c12")
	gc_style.border_color = Color("#d35400")
	gc_style.border_width_bottom = 3
	gc_style.set_corner_radius_all(16)
	get_coins_btn.add_theme_stylebox_override("normal", gc_style)
	var gc_hover := gc_style.duplicate() as StyleBoxFlat
	gc_hover.bg_color = Color("#f1c40f")
	get_coins_btn.add_theme_stylebox_override("hover", gc_hover)
	get_coins_btn.add_theme_stylebox_override("pressed", gc_hover)
	if game_title_font != null:
		get_coins_btn.add_theme_font_override("font", game_title_font)
	get_coins_btn.add_theme_font_size_override("font_size", 15)
	get_coins_btn.add_theme_color_override("font_color", Color.WHITE)
	get_coins_btn.add_theme_color_override("font_outline_color", Color("#7f4f00"))
	get_coins_btn.add_theme_constant_override("outline_size", 4)
	get_coins_btn.pressed.connect(func():
		var ad_mgr = AdManager if AdManager != null else get_tree().root.get_node_or_null("AdManager")
		if ad_mgr != null and ad_mgr.has_method("show_rewarded"):
			get_coins_btn.disabled = true
			get_coins_btn.text = "🎬 LOADING..."
			ad_mgr.show_rewarded(func(amt, _type):
				if GameManager != null:
					GameManager.coins += amt
					GameManager.save_game_state()
					coins = GameManager.coins
				else:
					coins += amt
				if is_instance_valid(coin_lbl):
					coin_lbl.text = " %d" % coins
				if SignalHub != null:
					SignalHub.emit_coins_changed(coins)
				if SoundManager != null:
					SoundManager.play_sfx("coin")
				get_coins_btn.text = "🎬 +30 COINS"
				get_coins_btn.disabled = false
			)
	)
	hud_root.add_child(get_coins_btn)
	var ad_mgr_hud = AdManager if AdManager != null else get_tree().root.get_node_or_null("AdManager")
	get_coins_btn.visible = ad_mgr_hud != null and ad_mgr_hud.has_method("is_rewarded_ready") and ad_mgr_hud.is_rewarded_ready()
	if ad_mgr_hud != null and ad_mgr_hud.has_signal("rewarded_ready_changed"):
		ad_mgr_hud.rewarded_ready_changed.connect(func(ready: bool):
			if is_instance_valid(get_coins_btn):
				get_coins_btn.visible = ready
		)

	# 4. Item Collector Widget at Top Center directly under Level (Clean, Stylish Capsule Pill)
	item_collector_panel = PanelContainer.new()
	item_collector_panel.name = "ItemCollectorPanel"
	item_collector_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	item_collector_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	item_collector_panel.offset_top = 88.0
	item_collector_panel.offset_bottom = 144.0
	item_collector_panel.offset_left = -90.0
	item_collector_panel.offset_right = 90.0

	var ic_style := StyleBoxFlat.new()
	ic_style.bg_color = Color(0.10, 0.14, 0.22, 0.88)
	ic_style.border_color = Color("#f1c40f")
	ic_style.set_border_width_all(2)
	ic_style.set_corner_radius_all(24)
	ic_style.shadow_color = Color(0, 0, 0, 0.35)
	ic_style.shadow_size = 6
	item_collector_panel.add_theme_stylebox_override("panel", ic_style)
	hud_root.add_child(item_collector_panel)

	var ic_margin := MarginContainer.new()
	ic_margin.add_theme_constant_override("margin_left", 14)
	ic_margin.add_theme_constant_override("margin_top", 4)
	ic_margin.add_theme_constant_override("margin_right", 14)
	ic_margin.add_theme_constant_override("margin_bottom", 4)
	item_collector_panel.add_child(ic_margin)

	var ic_hbox := HBoxContainer.new()
	ic_hbox.name = "ItemCollectorHBox"
	ic_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ic_hbox.add_theme_constant_override("separation", 10)
	ic_margin.add_child(ic_hbox)

	item_collector_label = Label.new()
	item_collector_label.name = "FindPrefixLabel"
	item_collector_label.text = "FIND:"
	if game_title_font != null:
		item_collector_label.add_theme_font_override("font", game_title_font)
	item_collector_label.add_theme_font_size_override("font_size", 18)
	item_collector_label.add_theme_color_override("font_color", Color("#f1c40f"))
	item_collector_label.add_theme_color_override("font_outline_color", Color.BLACK)
	item_collector_label.add_theme_constant_override("outline_size", 4)
	ic_hbox.add_child(item_collector_label)

	var ic_slots_hbox := HBoxContainer.new()
	ic_slots_hbox.name = "SlotsHBox"
	ic_slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ic_slots_hbox.add_theme_constant_override("separation", 8)
	ic_hbox.add_child(ic_slots_hbox)

	# 3. Bottom Powerup Tray - Clean Minimalist Transparent Dock
	var tray := PanelContainer.new()
	tray.name = "PowerupTray"
	tray.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tray.offset_left = -220.0
	tray.offset_right = 220.0
	tray.offset_top = -135.0
	tray.offset_bottom = -35.0

	var tray_style := StyleBoxEmpty.new()
	tray.add_theme_stylebox_override("panel", tray_style)
	hud_root.add_child(tray)

	var tray_box := HBoxContainer.new()
	tray_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tray_box.add_theme_constant_override("separation", 24)
	tray.add_child(tray_box)

	speed_badge_lbl = _add_interactive_powerup_item(tray_box, "res://assets/ui/powerup_speed_lightning.svg", "", "%d" % POWERUP_COIN_COST, Color("#f39c12"), _activate_speed_powerup, speed_btn_refs)
	shield_badge_lbl = _add_interactive_powerup_item(tray_box, "res://assets/ui/powerup_invis_white_ball.svg", "", "%d" % POWERUP_COIN_COST, Color("#00cec9"), _activate_invisibility_powerup, shield_btn_refs)
	ghost_badge_lbl = _add_interactive_powerup_item(tray_box, "res://assets/ui/powerup_bypass_wall.svg", "", "%d" % POWERUP_COIN_COST, Color("#e67e22"), _activate_wall_pass_powerup, ghost_btn_refs)
	_update_powerup_locks()

	# 4. Floating Mobile Virtual Joystick
	joystick_base = Panel.new()
	joystick_base.name = "MobileJoystickBase"
	joystick_base.custom_minimum_size = Vector2(130, 130)
	joystick_base.size = Vector2(130, 130)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var jb_style := StyleBoxFlat.new()
	jb_style.bg_color = Color(0.12, 0.16, 0.24, 0.45)
	jb_style.border_color = Color(1.0, 1.0, 1.0, 0.6)
	jb_style.set_border_width_all(3)
	jb_style.set_corner_radius_all(65)
	joystick_base.add_theme_stylebox_override("panel", jb_style)
	joystick_base.visible = false
	hud_root.add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.name = "MobileJoystickKnob"
	joystick_knob.custom_minimum_size = Vector2(58, 58)
	joystick_knob.size = Vector2(58, 58)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var jk_style := StyleBoxFlat.new()
	jk_style.bg_color = Color("#00cec9")
	jk_style.border_color = Color.WHITE
	jk_style.set_border_width_all(3)
	jk_style.set_corner_radius_all(29)
	jk_style.shadow_color = Color(0, 0, 0, 0.3)
	jk_style.shadow_size = 6
	joystick_knob.add_theme_stylebox_override("panel", jk_style)
	joystick_knob.position = Vector2(36, 36)
	joystick_base.add_child(joystick_knob)

func _add_interactive_powerup_item(parent: HBoxContainer, svg_path: String, _powerup_title: String, badge_text: String, badge_col: Color, on_click: Callable, out_refs: Dictionary = {}) -> Label:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(92, 92)
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(btn)

	# Transparent round background with subtle border
	var btn_bg := Panel.new()
	btn_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.10, 0.14, 0.22, 0.55)
	bg_style.border_color = badge_col
	bg_style.set_border_width_all(2)
	bg_style.set_corner_radius_all(24)
	btn_bg.add_theme_stylebox_override("panel", bg_style)
	btn.add_child(btn_bg)

	var icon := TextureRect.new()
	icon.texture = _load_ui_texture(svg_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 16.0
	icon.offset_top = 8.0
	icon.offset_right = -16.0
	icon.offset_bottom = -26.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	var lock_overlay := TextureRect.new()
	lock_overlay.texture = _load_ui_texture("res://assets/ui/powerup_lock_overlay.svg")
	lock_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_overlay.custom_minimum_size = Vector2(36, 36)
	lock_overlay.size = Vector2(36, 36)
	lock_overlay.position = Vector2(28, 14)
	lock_overlay.visible = false
	lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lock_overlay)

	# Bottom count or lock badge (crisp number/status, no unsupported emoji glyphs)
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(84, 26)
	badge.size = Vector2(84, 26)
	badge.position = Vector2(4, 62)
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = badge_col
	b_style.set_corner_radius_all(12)
	b_style.border_color = Color.WHITE
	b_style.set_border_width_all(2)
	badge.add_theme_stylebox_override("panel", b_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)

	var b_lbl := Label.new()
	b_lbl.text = badge_text
	b_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if game_title_font != null:
		b_lbl.add_theme_font_override("font", game_title_font)
	b_lbl.add_theme_font_size_override("font_size", 16)
	b_lbl.add_theme_color_override("font_color", Color.WHITE)
	b_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	b_lbl.add_theme_constant_override("outline_size", 4)
	b_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(b_lbl)

	out_refs["icon"] = icon
	out_refs["lock"] = lock_overlay
	out_refs["badge_style"] = b_style
	out_refs["badge_lbl"] = b_lbl
	out_refs["btn_bg_style"] = bg_style
	out_refs["unlocked_col"] = badge_col

	btn.pressed.connect(on_click)
	btn.pivot_offset = Vector2(46, 46)
	btn.button_down.connect(func():
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.91, 0.91), 0.06)
	)
	btn.button_up.connect(func():
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.09)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08)
	)
	var p_idx := parent.get_child_count() - 1
	btn.scale = Vector2.ZERO
	var etw := btn.create_tween()
	etw.tween_interval(0.12 + p_idx * 0.07)
	etw.tween_property(btn, "scale", Vector2.ONE, 0.30).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return b_lbl

func _apply_powerup_lock_visual(refs: Dictionary, is_locked: bool, unlock_lvl: int) -> void:
	if refs.is_empty():
		return
	var icon_rect: TextureRect = refs.get("icon")
	var lock_rect: TextureRect = refs.get("lock")
	var b_style: StyleBoxFlat = refs.get("badge_style")
	var bg_style: StyleBoxFlat = refs.get("btn_bg_style")
	var b_lbl: Label = refs.get("badge_lbl")
	var unlocked_col: Color = refs.get("unlocked_col", Color("#f39c12"))
	if is_instance_valid(icon_rect):
		icon_rect.modulate = Color(0.4, 0.45, 0.5, 0.6) if is_locked else Color.WHITE
	if is_instance_valid(lock_rect):
		lock_rect.visible = is_locked
	if bg_style != null:
		bg_style.border_color = Color("#576574") if is_locked else unlocked_col
	if b_style != null:
		b_style.bg_color = Color("#576574") if is_locked else unlocked_col
	if is_instance_valid(b_lbl):
		b_lbl.text = ("LV %d" % unlock_lvl) if is_locked else ("%d" % POWERUP_COIN_COST)

func _update_powerup_locks() -> void:
	var speed_locked := not GameManager.is_powerup_unlocked("speed", current_level) if GameManager != null else (current_level < SPEED_UNLOCK_LEVEL)
	var invis_locked := not GameManager.is_powerup_unlocked("invisible", current_level) if GameManager != null else (current_level < INVIS_UNLOCK_LEVEL)
	var wall_locked := not GameManager.is_powerup_unlocked("bypass_wall", current_level) if GameManager != null else (current_level < BYPASS_WALL_UNLOCK_LEVEL)
	_apply_powerup_lock_visual(speed_btn_refs, speed_locked, SPEED_UNLOCK_LEVEL)
	_apply_powerup_lock_visual(shield_btn_refs, invis_locked, INVIS_UNLOCK_LEVEL)
	_apply_powerup_lock_visual(ghost_btn_refs, wall_locked, BYPASS_WALL_UNLOCK_LEVEL)

func _populate_item_collector_hud() -> void:
	if not is_instance_valid(hud_root) or not is_instance_valid(item_collector_panel):
		return
	var slots_hbox := item_collector_panel.find_child("SlotsHBox", true, false) as HBoxContainer
	if not slots_hbox:
		return
	for child in slots_hbox.get_children():
		child.queue_free()
	item_slot_panels.clear()
	item_slot_badges.clear()

	target_items_total = target_items.size()
	collected_items_count = 0
	all_items_collected = false
	if is_instance_valid(item_collector_label):
		item_collector_label.text = "FIND:"
		item_collector_label.add_theme_color_override("font_color", Color("#f1c40f"))
		item_collector_label.visible = true

	if is_instance_valid(hud_root):
		var obj_lbl := hud_root.get_node_or_null("ObjectiveLabel") as Label
		if is_instance_valid(obj_lbl):
			obj_lbl.visible = false

	for i in range(target_items.size()):
		var it: Dictionary = target_items[i]
		var slot := Panel.new()
		slot.name = "Slot_%s" % it["id"]
		slot.custom_minimum_size = Vector2(46, 46)

		var s_style := StyleBoxFlat.new()
		s_style.bg_color = Color(0.14, 0.18, 0.26, 0.95)
		s_style.set_corner_radius_all(14)
		s_style.border_color = Color("#f39c12")
		s_style.set_border_width_all(2)
		slot.add_theme_stylebox_override("panel", s_style)
		slots_hbox.add_child(slot)
		item_slot_panels.append(slot)

		var icon_lbl := Label.new()
		icon_lbl.text = it.get("icon", "🎁")
		icon_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 28)
		slot.add_child(icon_lbl)

		# Checkmark Badge in top-right of slot
		var check_badge := Label.new()
		check_badge.text = "✓"
		check_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		check_badge.offset_left = -20.0
		check_badge.offset_top = 0.0
		check_badge.offset_right = 0.0
		check_badge.offset_bottom = 22.0
		check_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		check_badge.add_theme_font_size_override("font_size", 18)
		check_badge.add_theme_color_override("font_color", Color("#2ecc71"))
		check_badge.add_theme_color_override("font_outline_color", Color.BLACK)
		check_badge.add_theme_constant_override("outline_size", 6)
		check_badge.visible = false
		slot.add_child(check_badge)
		item_slot_badges.append(check_badge)

func _update_item_collector_hud(collected_id: String) -> void:
	if is_instance_valid(item_collector_label):
		if collected_items_count >= target_items_total:
			item_collector_label.text = "ESCAPE! 🚪"
			item_collector_label.add_theme_color_override("font_color", Color("#2ecc71"))
		else:
			item_collector_label.text = "FIND:"
			item_collector_label.add_theme_color_override("font_color", Color("#f1c40f"))

	for i in range(target_items.size()):
		var it: Dictionary = target_items[i]
		if it["id"] == collected_id:
			if i < item_slot_panels.size():
				var slot: Panel = item_slot_panels[i]
				var s_style := StyleBoxFlat.new()
				s_style.bg_color = Color("#1e824c")
				s_style.set_corner_radius_all(14)
				s_style.border_color = Color("#2ecc71")
				s_style.set_border_width_all(2)
				slot.add_theme_stylebox_override("panel", s_style)

				# Bouncy punch tween
				var tw := create_tween()
				tw.tween_property(slot, "scale", Vector2(1.22, 1.22), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(slot, "scale", Vector2.ONE, 0.15)
			if i < item_slot_badges.size():
				item_slot_badges[i].visible = true

func _input(event: InputEvent) -> void:
	if is_intro_cinematic_active:
		if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
			_skip_intro_sequence()
			return

	if is_spotted or is_level_cleared:
		if is_touch_active:
			_reset_mobile_touch()
		return

	# Mobile Screen Touch & Drag / Mouse Drag for Virtual Joystick
	if event is InputEventScreenTouch:
		if event.pressed:
			var tray_ctrl = hud_root.get_node_or_null("PowerupTray") as Control
			if is_instance_valid(tray_ctrl) and tray_ctrl.get_global_rect().has_point(event.position):
				return
			if is_instance_valid(victory_popup) or is_instance_valid(fail_popup):
				return
			_start_mobile_touch(event.position)
		else:
			_reset_mobile_touch()
	elif event is InputEventScreenDrag:
		if is_touch_active:
			_update_mobile_drag(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				var tray_ctrl = hud_root.get_node_or_null("PowerupTray") as Control
				if is_instance_valid(tray_ctrl) and tray_ctrl.get_global_rect().has_point(event.position):
					return
				if is_instance_valid(victory_popup) or is_instance_valid(fail_popup):
					return
				_start_mobile_touch(event.position)
			else:
				_reset_mobile_touch()
	elif event is InputEventMouseMotion:
		if is_touch_active:
			_update_mobile_drag(event.position)

	# Hotkeys for desktop testing (1=Speed, 2=Invisibility, 3=Pass Wall Without Door)
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		if event.keycode == KEY_1 or event.keycode == KEY_Q:
			_activate_speed_powerup()
		elif event.keycode == KEY_2 or event.keycode == KEY_SPACE:
			_activate_invisibility_powerup()
		elif event.keycode == KEY_3 or event.keycode == KEY_E:
			_activate_wall_pass_powerup()

func _start_mobile_touch(screen_pos: Vector2) -> void:
	is_touch_active = true
	touch_start_pos = screen_pos
	touch_move_dir = Vector3.ZERO
	if is_instance_valid(joystick_base):
		joystick_base.position = screen_pos - Vector2(65, 65)
		joystick_base.visible = true
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(36, 36)

func _update_mobile_drag(screen_pos: Vector2) -> void:
	if not is_touch_active:
		return
	var diff := screen_pos - touch_start_pos
	var dist := diff.length()
	var max_radius: float = 48.0
	var knob_offset := diff
	if dist > max_radius:
		knob_offset = diff.normalized() * max_radius
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(36, 36) + knob_offset

	# Responsive deadzone
	if dist > 8.0:
		var norm := diff.normalized()
		# Touch Screen X -> 3D World X, Touch Screen Y -> 3D World Z
		touch_move_dir = Vector3(norm.x, 0.0, norm.y)
	else:
		touch_move_dir = Vector3.ZERO

func _reset_mobile_touch() -> void:
	is_touch_active = false
	touch_move_dir = Vector3.ZERO
	if is_instance_valid(joystick_base):
		joystick_base.visible = false
	if is_instance_valid(joystick_knob):
		joystick_knob.position = Vector2(36, 36)

func _on_coins_changed(total: int) -> void:
	coins = total
	if is_instance_valid(coin_lbl):
		coin_lbl.text = " %d" % coins

func _has_enough_powerup_coins() -> bool:
	var current_coins := GameManager.coins if GameManager != null else coins
	return current_coins >= POWERUP_COIN_COST

func _spend_powerup_coins() -> bool:
	return _spend_coins(POWERUP_COIN_COST)

func _spend_coins(amount: int) -> bool:
	if GameManager != null:
		if not GameManager.try_spend_coins(amount):
			return false
		coins = GameManager.coins
	else:
		if coins < amount:
			return false
		coins -= amount

	if is_instance_valid(coin_lbl):
		coin_lbl.text = " %d" % coins
	if is_instance_valid(coin_panel):
		var p_tw := create_tween()
		p_tw.tween_property(coin_panel, "scale", Vector2(1.15, 1.15), 0.08)
		p_tw.tween_property(coin_panel, "scale", Vector2.ONE, 0.1)
	return true

func _show_rewarded_powerup_dialog(powerup_title: String, on_success_activate: Callable) -> void:
	if SoundManager != null:
		SoundManager.play_sfx("wrong")

	# Pause gameplay while prompt is showing
	var was_paused := get_tree().paused
	get_tree().paused = true

	var dialog := PanelContainer.new()
	dialog.name = "RewardedPowerupDialog"
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog.set_anchors_preset(Control.PRESET_CENTER)
	dialog.custom_minimum_size = Vector2(620, 480)
	dialog.pivot_offset = Vector2(310, 240)
	dialog.offset_left = -310
	dialog.offset_top = -240
	dialog.offset_right = 310
	dialog.offset_bottom = 240

	var d_style := StyleBoxFlat.new()
	d_style.bg_color = Color("#15212d")
	d_style.border_color = Color("#f1c40f")
	d_style.set_border_width_all(6)
	d_style.set_corner_radius_all(28)
	d_style.shadow_color = Color(0, 0, 0, 0.75)
	d_style.shadow_size = 28
	dialog.add_theme_stylebox_override("panel", d_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	dialog.add_child(margin)

	var v_box := VBoxContainer.new()
	v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v_box.add_theme_constant_override("separation", 18)
	margin.add_child(v_box)

	var t_lbl := Label.new()
	t_lbl.text = "🪙 NOT ENOUGH COINS!"
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		t_lbl.add_theme_font_override("font", game_title_font)
	t_lbl.add_theme_font_size_override("font_size", 34)
	t_lbl.add_theme_color_override("font_color", Color("#f1c40f"))
	t_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	t_lbl.add_theme_constant_override("outline_size", 8)
	v_box.add_child(t_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = "Powerups cost %d coins.\nWatch a short video ad to earn 10 Coins and activate %s!" % [POWERUP_COIN_COST, powerup_title]
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if game_title_font != null:
		desc_lbl.add_theme_font_override("font", game_title_font)
	desc_lbl.add_theme_font_size_override("font_size", 22)
	desc_lbl.add_theme_color_override("font_color", Color.WHITE)
	desc_lbl.add_theme_color_override("font_outline_color", Color("#2c3e50"))
	desc_lbl.add_theme_constant_override("outline_size", 6)
	v_box.add_child(desc_lbl)

	# Watch Ad Button
	var watch_btn := Button.new()
	watch_btn.text = "🎬 WATCH AD (+10 COINS)"
	watch_btn.custom_minimum_size = Vector2(480, 80)
	var wb_style := StyleBoxFlat.new()
	wb_style.bg_color = Color("#2ecc71")
	wb_style.border_color = Color("#1e824c")
	wb_style.border_width_bottom = 6
	wb_style.set_corner_radius_all(22)
	watch_btn.add_theme_stylebox_override("normal", wb_style)
	if game_title_font != null:
		watch_btn.add_theme_font_override("font", game_title_font)
	watch_btn.add_theme_font_size_override("font_size", 28)
	watch_btn.add_theme_color_override("font_color", Color.WHITE)
	watch_btn.add_theme_color_override("font_outline_color", Color("#1b4d3e"))
	watch_btn.add_theme_constant_override("outline_size", 8)

	# Cancel Button
	var cancel_btn := Button.new()
	cancel_btn.text = "✖ CANCEL"
	cancel_btn.custom_minimum_size = Vector2(480, 68)
	var cb_style := StyleBoxFlat.new()
	cb_style.bg_color = Color("#7f8c8d")
	cb_style.border_color = Color("#576574")
	cb_style.border_width_bottom = 5
	cb_style.set_corner_radius_all(20)
	cancel_btn.add_theme_stylebox_override("normal", cb_style)
	if game_title_font != null:
		cancel_btn.add_theme_font_override("font", game_title_font)
	cancel_btn.add_theme_font_size_override("font_size", 24)
	cancel_btn.add_theme_color_override("font_color", Color.WHITE)
	cancel_btn.add_theme_color_override("font_outline_color", Color.BLACK)
	cancel_btn.add_theme_constant_override("outline_size", 6)

	v_box.add_child(watch_btn)
	v_box.add_child(cancel_btn)
	hud_root.add_child(dialog)

	cancel_btn.pressed.connect(func():
		get_tree().paused = was_paused
		dialog.queue_free()
	)

	var ad_mgr_pw = AdManager if AdManager != null else get_tree().root.get_node_or_null("AdManager")
	var pw_ad_ready: bool = ad_mgr_pw != null and ad_mgr_pw.has_method("is_rewarded_ready") and ad_mgr_pw.is_rewarded_ready()
	watch_btn.visible = pw_ad_ready
	watch_btn.pressed.connect(func():
		dialog.queue_free()
		if ad_mgr_pw != null and ad_mgr_pw.has_method("show_rewarded"):
			ad_mgr_pw.show_rewarded(func(amount: int, _type: String):
				get_tree().paused = was_paused
				if GameManager != null:
					GameManager.add_coins(amount)
					coins = GameManager.coins
				else:
					coins += amount
				if is_instance_valid(coin_lbl):
					coin_lbl.text = " %d" % coins
				_show_powerup_toast("🎉 +%d COINS! %s ACTIVATED!" % [amount, powerup_title], Color("#2ecc71"))
				if on_success_activate.is_valid():
					on_success_activate.call()
			)
	)

func _activate_speed_powerup() -> void:
	if speed_boost_time > 0.0 or is_level_cleared or is_spotted:
		return
	if _has_enough_powerup_coins():
		_spend_powerup_coins()
		_apply_speed_powerup()
	else:
		_show_rewarded_powerup_dialog("SPEED BOOST", _apply_speed_powerup)

func _apply_speed_powerup() -> void:
	var upg_lvl := GameManager.upgrade_level("sneakers") if GameManager != null and GameManager.has_method("upgrade_level") else 0
	speed_boost_time = 5.0 + float(upg_lvl) * 0.5
	if SoundManager != null:
		SoundManager.play_sfx("powerup_speed")
	if SignalHub != null:
		SignalHub.emit_powerup_activated("speed", speed_boost_time)
	_show_powerup_toast("SPEED BOOST ACTIVE! (-%d COINS)" % POWERUP_COIN_COST, Color("#f1c40f"))
	_flash_powerup_screen(Color(1.0, 0.85, 0.2, 0.24))
	if is_instance_valid(player_root):
		_spawn_powerup_shockwave(player_root.global_position + Vector3(0, 0.12, 0), Color("#f1c40f"), 4.2)
		_spawn_powerup_light_pillar(player_root.global_position, Color("#f1c40f"))
	if is_instance_valid(player_ring):
		var tw := create_tween()
		tw.tween_property(player_ring, "scale", Vector3(1.35, 1.35, 1.35), 0.2)
		tw.tween_property(player_ring, "scale", Vector3.ONE, 0.2)

func _activate_invisibility_powerup() -> void:
	if is_level_cleared or is_spotted:
		return
	var is_unlocked := GameManager.is_powerup_unlocked("invisible", current_level) if GameManager != null else (current_level >= INVIS_UNLOCK_LEVEL)
	if not is_unlocked:
		if SoundManager != null:
			SoundManager.play_sfx("locked")
		_show_powerup_toast("LOCKED! INVISIBLE UNLOCKS AT LEVEL %d!" % INVIS_UNLOCK_LEVEL, Color("#e74c3c"))
		return
	if invisibility_time > 0.0:
		return
	if _has_enough_powerup_coins():
		_spend_powerup_coins()
		_apply_invisibility_powerup()
	else:
		_show_rewarded_powerup_dialog("INVISIBILITY", _apply_invisibility_powerup)

func _apply_invisibility_powerup() -> void:
	var upg_lvl := GameManager.upgrade_level("cloak") if GameManager != null and GameManager.has_method("upgrade_level") else 0
	invisibility_time = 5.0 + float(upg_lvl) * 1.5
	is_player_invisible = true
	if SoundManager != null:
		SoundManager.play_sfx("powerup_invisible")
	if SignalHub != null:
		SignalHub.emit_powerup_activated("invisible", invisibility_time)
	_set_player_transparency(0.35, Color("#ffffff"))
	_show_powerup_toast("INVISIBLE! GUARDS CANNOT SEE YOU! (-%d COINS)" % POWERUP_COIN_COST, Color("#00cec9"))
	_flash_powerup_screen(Color(0.0, 0.85, 0.9, 0.24))
	if is_instance_valid(player_root):
		_spawn_powerup_shockwave(player_root.global_position + Vector3(0, 0.12, 0), Color("#00cec9"), 4.2)
		_spawn_powerup_light_pillar(player_root.global_position, Color("#00cec9"))

func _activate_wall_pass_powerup() -> void:
	if is_level_cleared or is_spotted:
		return
	var is_unlocked := GameManager.is_powerup_unlocked("bypass_wall", current_level) if GameManager != null else (current_level >= BYPASS_WALL_UNLOCK_LEVEL)
	if not is_unlocked:
		if SoundManager != null:
			SoundManager.play_sfx("locked")
		_show_powerup_toast("LOCKED! BYPASS WALL UNLOCKS AT LEVEL %d!" % BYPASS_WALL_UNLOCK_LEVEL, Color("#e74c3c"))
		return
	if wall_pass_time > 0.0:
		return
	if _has_enough_powerup_coins():
		_spend_powerup_coins()
		_apply_wall_pass_powerup()
	else:
		_show_rewarded_powerup_dialog("BYPASS WALL", _apply_wall_pass_powerup)

func _apply_wall_pass_powerup() -> void:
	var upg_lvl := GameManager.upgrade_level("wall_battery") if GameManager != null and GameManager.has_method("upgrade_level") else 0
	wall_pass_time = 5.0 + float(upg_lvl) * 1.5
	is_wall_pass_active = true
	if SoundManager != null:
		SoundManager.play_sfx("powerup_wall")
	if SignalHub != null:
		SignalHub.emit_powerup_activated("bypass_wall", wall_pass_time)
	_set_player_transparency(0.45, Color("#9b59b6"))
	_show_powerup_toast("BYPASS WALL ACTIVE! WALK THROUGH WALLS! (-%d COINS)" % POWERUP_COIN_COST, Color("#9b59b6"))
	_flash_powerup_screen(Color(0.68, 0.35, 0.85, 0.24))
	if is_instance_valid(player_root):
		_spawn_powerup_shockwave(player_root.global_position + Vector3(0, 0.12, 0), Color("#9b59b6"), 4.2)
		_spawn_powerup_light_pillar(player_root.global_position, Color("#9b59b6"))

func _spawn_powerup_shockwave(pos: Vector3, color: Color, target_scale: float = 4.0) -> void:
	if not is_instance_valid(level_root):
		return
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.65
	torus.outer_radius = 0.88
	ring.mesh = torus
	ring.position = pos
	ring.scale = Vector3.ONE * 0.35
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(color.r, color.g, color.b, 0.92)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.4
	ring.material_override = mat
	level_root.add_child(ring)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(target_scale, 0.45, target_scale), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(ring.queue_free)

func _spawn_powerup_light_pillar(pos: Vector3, color: Color) -> void:
	if not is_instance_valid(level_root):
		return
	var beam := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.05
	cyl.bottom_radius = 1.35
	cyl.height = 5.5
	beam.mesh = cyl
	beam.position = pos + Vector3.UP * 2.75
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(color.r, color.g, color.b, 0.55)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	beam.material_override = mat
	level_root.add_child(beam)
	var tw := beam.create_tween().set_parallel(true)
	tw.tween_property(beam, "scale", Vector3(0.15, 1.35, 0.15), 0.62).set_trans(Tween.TRANS_QUAD)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.62)
	tw.chain().tween_callback(beam.queue_free)

func _flash_powerup_screen(color: Color) -> void:
	if not is_instance_valid(hud_root):
		return
	var flash := ColorRect.new()
	flash.color = color
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_root.add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.36)
	tw.tween_callback(flash.queue_free)

func _set_player_transparency(alpha: float, rim_col: Color = Color.TRANSPARENT) -> void:
	if not is_instance_valid(player_mesh):
		return
	for found in player_mesh.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := found as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var mat := mesh_instance.get_surface_override_material(surface) as StandardMaterial3D
			if mat != null:
				if alpha < 0.99:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.albedo_color.a = alpha
					mat.emission_enabled = true
					mat.emission = rim_col
					mat.emission_energy_multiplier = 0.9
				else:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.albedo_color.a = 1.0
					mat.emission_enabled = true
					mat.emission = Color.BLACK
					mat.emission_energy_multiplier = 0.0
	if is_instance_valid(player_ring):
		var r_mat := player_ring.material_override as StandardMaterial3D
		if r_mat:
			if alpha < 0.99:
				r_mat.albedo_color = Color(0.0, 0.9, 1.0, 0.4)
				r_mat.emission = Color(0.0, 0.9, 1.0)
			else:
				r_mat.albedo_color = Color("#00cec9")
				r_mat.emission = Color("#00cec9")

func _show_powerup_toast(text: String, col: Color) -> void:
	if not is_instance_valid(hud_root):
		return
	var toast := PanelContainer.new()
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.1, 0.15, 0.22, 0.92)
	t_style.border_color = col
	t_style.set_border_width_all(3)
	t_style.set_corner_radius_all(18)
	toast.add_theme_stylebox_override("panel", t_style)
	toast.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast.offset_left = 35.0
	toast.offset_right = -35.0
	toast.offset_top = 180.0
	toast.offset_bottom = 245.0

	var t_lbl := Label.new()
	t_lbl.text = text
	t_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if game_title_font != null:
		t_lbl.add_theme_font_override("font", game_title_font)
	t_lbl.add_theme_font_size_override("font_size", 24)
	t_lbl.add_theme_color_override("font_color", col)
	t_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	t_lbl.add_theme_constant_override("outline_size", 8)
	toast.add_child(t_lbl)
	hud_root.add_child(toast)

	var tw := create_tween()
	toast.modulate.a = 0.0
	tw.tween_property(toast, "modulate:a", 1.0, 0.2)
	tw.tween_interval(1.8)
	tw.tween_property(toast, "modulate:a", 0.0, 0.4)
	tw.tween_callback(toast.queue_free)

func _set_powerup_active_visual(refs: Dictionary, is_active: bool, time_left: float, idle_text: String, is_locked: bool = false) -> void:
	var b_lbl: Label = refs.get("badge_lbl")
	var b_style: StyleBoxFlat = refs.get("badge_style")
	var bg_style: StyleBoxFlat = refs.get("btn_bg_style")
	var unlocked_col: Color = refs.get("unlocked_col", Color("#f39c12"))
	if is_instance_valid(b_lbl):
		var target_txt := ("%.1fs" % time_left) if is_active else idle_text
		if b_lbl.text != target_txt:
			b_lbl.text = target_txt
	if b_style != null:
		b_style.bg_color = Color("#2ecc71") if is_active else (Color("#576574") if is_locked else unlocked_col)
	if bg_style != null:
		bg_style.border_color = Color("#2ecc71") if is_active else (Color("#576574") if is_locked else unlocked_col)
		bg_style.set_border_width_all(4 if is_active else 2)
		bg_style.bg_color = Color(0.14, 0.34, 0.22, 0.78) if is_active else Color(0.10, 0.14, 0.22, 0.55)

func _update_powerups(delta: float) -> void:
	var cost_txt := "%d" % POWERUP_COIN_COST
	var invis_locked := not GameManager.is_powerup_unlocked("invisible", current_level) if GameManager != null else (current_level < INVIS_UNLOCK_LEVEL)
	var wall_locked := not GameManager.is_powerup_unlocked("bypass_wall", current_level) if GameManager != null else (current_level < BYPASS_WALL_UNLOCK_LEVEL)
	var invis_idle_txt := ("LV %d" % INVIS_UNLOCK_LEVEL) if invis_locked else cost_txt
	var wall_idle_txt := ("LV %d" % BYPASS_WALL_UNLOCK_LEVEL) if wall_locked else cost_txt

	if speed_boost_time > 0.0:
		speed_boost_time = maxf(0.0, speed_boost_time - delta)
	_set_powerup_active_visual(speed_btn_refs, speed_boost_time > 0.0, speed_boost_time, cost_txt, false)

	if invisibility_time > 0.0:
		invisibility_time = maxf(0.0, invisibility_time - delta)
		if invisibility_time == 0.0:
			is_player_invisible = false
			if not is_wall_pass_active:
				_set_player_transparency(1.0)
			_show_powerup_toast("VISIBLE AGAIN!", Color("#e74c3c"))
	_set_powerup_active_visual(shield_btn_refs, invisibility_time > 0.0, invisibility_time, invis_idle_txt, invis_locked)

	if wall_pass_time > 0.0:
		wall_pass_time = maxf(0.0, wall_pass_time - delta)
		if wall_pass_time == 0.0:
			is_wall_pass_active = false
			if is_instance_valid(player_root):
				player_root.position = _find_nearest_safe_floor(player_root.position, 0.35)
			if not is_player_invisible:
				_set_player_transparency(1.0)
			_show_powerup_toast("BYPASS WALL ENDED!", Color("#e67e22"))
	_set_powerup_active_visual(ghost_btn_refs, wall_pass_time > 0.0, wall_pass_time, wall_idle_txt, wall_locked)

func _show_victory_popup() -> void:
	if is_instance_valid(victory_popup) or not is_instance_valid(hud_root):
		return
	_set_ad_banner_mode(false)

	var scene := load("res://scenes/popups/victory_popup.tscn") as PackedScene
	if scene != null:
		victory_popup = scene.instantiate()
		victory_popup.setup(current_level, 20, "res://assets/ui/boy_candy_splash_bg.png")
		victory_popup.continue_pressed.connect(_on_continue_pressed)
		victory_popup.replay_pressed.connect(_on_victory_replay_pressed)
		victory_popup.reward_coins_ready.connect(func(from_pos: Vector2, amount: int):
			var to_pos := coin_panel.get_global_rect().get_center() if is_instance_valid(coin_panel) else Vector2(430.0, 70.0)
			_animate_flying_coins(from_pos, to_pos, amount)
		)
		hud_root.add_child(victory_popup)

func _animate_flying_coins(from_pos: Vector2, to_pos: Vector2, total_amount: int) -> void:
	var coin_count: int = 10
	var per_coin: int = total_amount / coin_count

	for i in range(coin_count):
		var delay := i * 0.08
		get_tree().create_timer(delay).timeout.connect(func():
			if not is_instance_valid(hud_root):
				return
			var coin_item := TextureRect.new()
			coin_item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			coin_item.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			coin_item.texture = _load_ui_texture("res://assets/ui/reward-coin.png")
			coin_item.custom_minimum_size = Vector2(38, 38)
			coin_item.size = Vector2(38, 38)
			coin_item.mouse_filter = Control.MOUSE_FILTER_IGNORE

			var start_p := from_pos + Vector2(randf_range(-20, 20), randf_range(-10, 10))
			coin_item.position = start_p - Vector2(19, 19)
			coin_item.pivot_offset = Vector2(19, 19)
			hud_root.add_child(coin_item)
			coin_item.size = Vector2(38, 38)

			# Curved trajectory arc staying cleanly inside screen view
			var mid_x := lerpf(start_p.x, to_pos.x, randf_range(0.35, 0.65)) + randf_range(-40, 40)
			var mid_y := clampf(minf(start_p.y, to_pos.y) - randf_range(30, 80), 45.0, 450.0)
			var mid_p := Vector2(mid_x, mid_y)

			var tw := create_tween()
			tw.tween_property(coin_item, "scale", Vector2(1.08, 1.08), 0.1).set_trans(Tween.TRANS_QUAD)
			tw.tween_property(coin_item, "position", mid_p - Vector2(19, 19), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			tw.tween_property(coin_item, "position", to_pos - Vector2(19, 19), 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			tw.parallel().tween_property(coin_item, "scale", Vector2(0.85, 0.85), 0.32)

			tw.tween_callback(func():
				if GameManager != null:
					GameManager.add_coins(per_coin)
				else:
					coins += per_coin
				if SoundManager != null:
					SoundManager.play_sfx("coin")
				if is_instance_valid(coin_lbl):
					coin_lbl.text = " %d" % coins
				if is_instance_valid(coin_panel):
					var p_tw := create_tween()
					p_tw.tween_property(coin_panel, "scale", Vector2(1.18, 1.18), 0.06)
					p_tw.tween_property(coin_panel, "scale", Vector2.ONE, 0.1)
				coin_item.queue_free()
			)
		)

func _on_victory_replay_pressed() -> void:
	if SoundManager != null:
		SoundManager.play_sfx("button")
	if is_instance_valid(victory_popup):
		victory_popup.queue_free()
		victory_popup = null
	_show_level_end_interstitial()
	load_level(current_level)

func _on_continue_pressed() -> void:
	if SoundManager != null:
		SoundManager.play_sfx("button")
	if is_instance_valid(victory_popup):
		victory_popup.queue_free()
		victory_popup = null

	# Granny Intelligence Streak: if intelligent granny was beaten, reset cycle
	if is_intelligent_granny_active:
		levels_completed_streak = 0
		is_intelligent_granny_active = false
	else:
		levels_completed_streak += 1

	# Show Interstitial Ad at level end
	_show_level_end_interstitial()

	current_level += 1
	# Unlimited levels progression: loads static JSONs (1..5) then seamlessly shifts into procedural generation (6, 7, 8... 100+)
	load_level(current_level)

const CONTINUE_COIN_COST := 20
const CONTINUE_INVISIBILITY_DURATION := 5.0

func _set_ad_banner_mode(gameplay_only: bool) -> void:
	var ad_mgr = AdManager if AdManager != null else get_tree().root.get_node_or_null("AdManager")
	if ad_mgr == null:
		return
	if gameplay_only:
		if ad_mgr.has_method("show_gameplay_banner"):
			ad_mgr.show_gameplay_banner()
	elif ad_mgr.has_method("show_banner"):
		ad_mgr.show_banner()

func _show_fail_popup(reason: String) -> void:
	if is_instance_valid(fail_popup) or not is_instance_valid(hud_root):
		return
	if SoundManager != null:
		SoundManager.stop_footstep()
	_set_ad_banner_mode(false)

	var scene := load("res://scenes/popups/fail_popup.tscn") as PackedScene
	if scene != null:
		fail_popup = scene.instantiate()
		var available_coins := GameManager.coins if GameManager != null else coins
		fail_popup.setup(reason if not reason.is_empty() else "YOU WERE CAUGHT BY GRANNY!", "💡 TIP: Sneak past Granny when she looks away, or use Invisibility to recover your items!", "res://assets/ui/boy_crying_fail.png", CONTINUE_COIN_COST, available_coins)
		fail_popup.retry_pressed.connect(_on_retry_pressed)
		fail_popup.continue_pressed.connect(_on_fail_continue_pressed)
		fail_popup.home_pressed.connect(_on_fail_home_pressed)
		hud_root.add_child(fail_popup)

func _cleanup_fail_overlay() -> void:
	if is_instance_valid(fail_popup):
		fail_popup.queue_free()
		fail_popup = null
	if is_instance_valid(catch_letterbox_layer):
		catch_letterbox_layer.queue_free()
		catch_letterbox_layer = null
	if is_instance_valid(catch_cinematic_tween):
		catch_cinematic_tween.kill()
		catch_cinematic_tween = null
	var b_node := get_node_or_null("BoyCatchBubble")
	if is_instance_valid(b_node):
		b_node.queue_free()
	is_catch_cinematic_active = false
	is_spotted = false
	is_level_cleared = false

func _reset_camera_to_origin(reset_position: bool = true) -> void:
	if not is_instance_valid(main_camera):
		return
	if reset_position:
		main_camera.position = Vector3(player_spawn_pos.x * 0.75, 27.5, player_spawn_pos.z + 4.5)
	main_camera.rotation_degrees = Vector3(-68.0, 0.0, 0.0)
	main_camera.fov = 46.0

func _on_fail_continue_pressed() -> void:
	if not _spend_coins(CONTINUE_COIN_COST):
		return
	if SoundManager != null:
		SoundManager.play_sfx("powerup")
		SoundManager.start_bgm()
	_cleanup_fail_overlay()
	_set_ad_banner_mode(true)
	if is_instance_valid(main_camera):
		var target_pos := Vector3(
			(player_root.position.x if is_instance_valid(player_root) else player_spawn_pos.x) * 0.75,
			27.5,
			(player_root.position.z if is_instance_valid(player_root) else player_spawn_pos.z) + 4.5
		)
		var resume_tw := create_tween().set_parallel(true)
		resume_tw.tween_property(main_camera, "position", target_pos, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		resume_tw.tween_property(main_camera, "rotation_degrees", Vector3(-68.0, 0.0, 0.0), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		resume_tw.tween_property(main_camera, "fov", 46.0, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	for g in active_guards:
		if is_instance_valid(g) and g.has_method("resume_after_continue"):
			g.resume_after_continue()

	is_player_invisible = true
	invisibility_time = maxf(invisibility_time, CONTINUE_INVISIBILITY_DURATION)
	_set_player_transparency(0.42)
	_update_hud_objective("👻 REVIVED! INVISIBLE FOR 5s!")

func _show_level_end_interstitial() -> void:
	var ad_mgr = AdManager if AdManager != null else get_tree().root.get_node_or_null("AdManager")
	if ad_mgr != null and ad_mgr.has_method("on_level_finished_check_interstitial"):
		ad_mgr.on_level_finished_check_interstitial(false, current_level)

func _on_pause_pressed() -> void:
	if not is_instance_valid(hud_root):
		return
	if SoundManager != null:
		SoundManager.play_sfx("button")
	var was_paused := get_tree().paused
	get_tree().paused = true
	var scene := load("res://scenes/popups/settings_popup.tscn") as PackedScene
	if scene != null:
		var popup := scene.instantiate()
		popup.show_main_menu_button = true
		popup.closed.connect(func():
			get_tree().paused = was_paused
		)
		popup.main_menu_requested.connect(func():
			get_tree().paused = false
			get_tree().change_scene_to_file("res://scenes/splash/splash_screen.tscn")
		)
		popup.privacy_policy_requested.connect(func():
			var pp_scene := load("res://scenes/popups/privacy_policy_popup.tscn") as PackedScene
			if pp_scene != null:
				popup.add_child(pp_scene.instantiate())
		)
		hud_root.add_child(popup)
	else:
		get_tree().paused = was_paused

func _on_fail_home_pressed() -> void:
	if SoundManager != null:
		SoundManager.play_sfx("button")
	_cleanup_fail_overlay()
	get_tree().change_scene_to_file("res://scenes/splash/splash_screen.tscn")

func _on_retry_pressed() -> void:
	if is_instance_valid(fail_popup) and not _spend_coins(CONTINUE_COIN_COST):
		return
	if SoundManager != null:
		SoundManager.play_sfx("button")
	_cleanup_fail_overlay()
	if is_instance_valid(intro_cinematic_tween):
		intro_cinematic_tween.kill()
	_reset_camera_to_origin(true)
	candy_collected = false
	# If level restarted, Granny is NOT intelligent and streak resets to 0
	is_intelligent_granny_active = false
	levels_completed_streak = 0
	load_level(current_level)

func _update_hud() -> void:
	var lbl: Label = hud_root.get_node_or_null("LevelLabel")
	if lbl:
		lbl.text = "LEVEL\n%d" % current_level
	_update_powerup_locks()

func _load_ui_texture(res_path: String) -> Texture2D:
	var global_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	return null
