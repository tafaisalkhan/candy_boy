extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const SPLASH_BACKGROUND_PORTRAIT := "res://assets/ui/boy_candy_splash_bg.png"
const SPLASH_BACKGROUND_ICON := "res://assets/ui/game_icon.png"

var play_button: Button = null
var settings_button: Button = null
var game_scene: PackedScene = null
var start_requested: bool = false
var privacy_popup: Control = null
var settings_popup: Control = null

# Loader Controls
var loader_container: VBoxContainer = null
var loading_label: Label = null
var loading_bar: ProgressBar = null
var button_container: VBoxContainer = null
var is_loading_complete: bool = false


func _ready() -> void:
	var bg_path := SPLASH_BACKGROUND_PORTRAIT if FileAccess.file_exists(ProjectSettings.globalize_path(SPLASH_BACKGROUND_PORTRAIT)) else SPLASH_BACKGROUND_ICON
	var background := TextureRect.new()
	background.texture = _load_ui_texture(bg_path)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	var title_font: Font = null
	if ResourceLoader.exists("res://assets/fonts/LuckiestGuy-Regular.ttf"):
		title_font = load("res://assets/fonts/LuckiestGuy-Regular.ttf") as Font

	# Title Drop Shadow
	var title_shadow := Label.new()
	title_shadow.text = "BOY FAVORITE\nCOLLECTION"
	title_shadow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_shadow.offset_left = 30.0
	title_shadow.offset_right = -30.0
	title_shadow.offset_top = 120.0
	title_shadow.offset_bottom = 330.0
	title_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_shadow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_shadow.add_theme_font_override("font", title_font)
	title_shadow.add_theme_font_size_override("font_size", 64)
	title_shadow.add_theme_color_override("font_color", Color("#5123aa"))
	title_shadow.add_theme_color_override("font_outline_color", Color("#5123aa"))
	title_shadow.add_theme_constant_override("outline_size", 20)
	add_child(title_shadow)

	# Main Title
	var title := Label.new()
	title.text = "BOY FAVORITE\nCOLLECTION"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 30.0
	title.offset_right = -30.0
	title.offset_top = 107.0
	title.offset_bottom = 312.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color("#ffb900"))
	title.add_theme_color_override("font_outline_color", Color.WHITE)
	title.add_theme_constant_override("outline_size", 12)
	add_child(title)

	# 1. Loader Container (Shows immediately upon launch)
	_build_loader_ui(title_font)

	# 2. Action Buttons Container (Hidden initially, appears after loading)
	_build_action_buttons_ui(title_font)

	ResourceLoader.load_threaded_request(GAME_SCENE)

	var ad_mgr = AdManager if AdManager != null else get_tree().root.get_node_or_null("AdManager")
	if ad_mgr != null and ad_mgr.has_method("show_banner"):
		ad_mgr.show_banner()

	var all_args := OS.get_cmdline_user_args() + OS.get_cmdline_args()

	# Test Flag Handlers
	if "--test-privacy" in all_args or FileAccess.file_exists("res://test_privacy.flag"):
		if FileAccess.file_exists("res://test_privacy.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_privacy.flag"))
		_show_privacy_policy_popup()
		_capture_privacy_and_quit()
		return

	if "--test-splash-settings" in all_args or FileAccess.file_exists("res://test_splash_settings.flag"):
		if FileAccess.file_exists("res://test_splash_settings.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_splash_settings.flag"))
		_on_loading_finished()
		_show_settings_popup()
		_capture_screenshot_and_quit("screenshot_splash_settings.png")
		return

	if "--test-splash-buttons" in all_args or FileAccess.file_exists("res://test_splash_buttons.flag"):
		if FileAccess.file_exists("res://test_splash_buttons.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_splash_buttons.flag"))
		_on_loading_finished()
		_capture_screenshot_and_quit("screenshot_splash_buttons.png")
		return

	if "--test-splash-loading" in all_args or FileAccess.file_exists("res://test_splash_loading.flag"):
		if FileAccess.file_exists("res://test_splash_loading.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_splash_loading.flag"))
		if is_instance_valid(loading_bar):
			loading_bar.value = 54.0
		if is_instance_valid(loading_label):
			loading_label.text = "LOADING MISSIONS... 54%"
		_capture_screenshot_and_quit("screenshot_splash_loading.png")
		return

	for arg in all_args:
		if arg.begins_with("--test") or arg == "--play" or arg.begins_with("--level"):
			call_deferred("_start_game", true)
			return

	if FileAccess.file_exists("res://test_loop.flag") or FileAccess.file_exists("res://test_powerup.flag") or FileAccess.file_exists("res://test_screenshot.flag") or FileAccess.file_exists("res://test_cupboard.flag") or FileAccess.file_exists("res://test_victory.flag") or FileAccess.file_exists("res://test_fail.flag") or FileAccess.file_exists("res://test_rewarded_powerup.flag") or FileAccess.file_exists("res://test_mission_intro.flag"):
		call_deferred("_start_game", true)
		return

	if "--screen-game" in all_args:
		call_deferred("_start_game")
		return

	if "--screenshot" in all_args:
		_capture_and_quit()
		return

	# Start smooth loading progression
	_start_loading_animation()


func _build_loader_ui(p_font: Font) -> void:
	loader_container = VBoxContainer.new()
	loader_container.name = "LoaderContainer"
	loader_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	loader_container.offset_left = 140.0
	loader_container.offset_right = -140.0
	loader_container.offset_top = -270.0
	loader_container.offset_bottom = -145.0
	loader_container.alignment = BoxContainer.ALIGNMENT_CENTER
	loader_container.add_theme_constant_override("separation", 14)
	add_child(loader_container)

	# Loading Text Label
	loading_label = Label.new()
	loading_label.text = "LOADING MISSIONS... 0%"
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if p_font != null:
		loading_label.add_theme_font_override("font", p_font)
	loading_label.add_theme_font_size_override("font_size", 28)
	loading_label.add_theme_color_override("font_color", Color("#ffeaa7"))
	loading_label.add_theme_color_override("font_outline_color", Color("#2d3436"))
	loading_label.add_theme_constant_override("outline_size", 8)
	loader_container.add_child(loading_label)

	# Progress Bar Container
	loading_bar = ProgressBar.new()
	loading_bar.min_value = 0.0
	loading_bar.max_value = 100.0
	loading_bar.value = 0.0
	loading_bar.show_percentage = false
	loading_bar.custom_minimum_size = Vector2(0, 26)

	# Progress Bar Background Style
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("#1e272e")
	bg_style.border_color = Color("#00cec9")
	bg_style.border_width_bottom = 3
	bg_style.border_width_top = 2
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.set_corner_radius_all(13)
	loading_bar.add_theme_stylebox_override("background", bg_style)

	# Progress Bar Fill Style
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("#00cec9")
	fill_style.set_corner_radius_all(13)
	loading_bar.add_theme_stylebox_override("fill", fill_style)

	loader_container.add_child(loading_bar)


func _build_action_buttons_ui(p_font: Font) -> void:
	button_container = VBoxContainer.new()
	button_container.name = "ButtonContainer"
	button_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	button_container.offset_left = 130.0
	button_container.offset_right = -130.0
	button_container.offset_top = -345.0
	button_container.offset_bottom = -145.0
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.add_theme_constant_override("separation", 14)
	button_container.visible = false
	button_container.modulate.a = 0.0
	add_child(button_container)

	# 1. PLAY Button
	play_button = Button.new()
	play_button.text = "▶ PLAY"
	play_button.custom_minimum_size = Vector2(0, 88)
	if p_font != null:
		play_button.add_theme_font_override("font", p_font)
	play_button.add_theme_font_size_override("font_size", 42)
	play_button.add_theme_color_override("font_color", Color.WHITE)
	play_button.add_theme_color_override("font_outline_color", Color("#1b4d3e"))
	play_button.add_theme_constant_override("outline_size", 10)
	play_button.add_theme_stylebox_override("normal", _create_3d_btn_style(Color("#2ecc71"), Color("#1e824c"), 8))
	play_button.add_theme_stylebox_override("hover", _create_3d_btn_style(Color("#40d47e"), Color("#1e824c"), 8))
	play_button.add_theme_stylebox_override("pressed", _create_3d_btn_style(Color("#27ae60"), Color("#1e824c"), 2, 6))
	play_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	play_button.pressed.connect(_start_game)
	button_container.add_child(play_button)

	# 2. SETTINGS Button
	settings_button = Button.new()
	settings_button.text = "⚙️ SETTINGS"
	settings_button.custom_minimum_size = Vector2(0, 70)
	if p_font != null:
		settings_button.add_theme_font_override("font", p_font)
	settings_button.add_theme_font_size_override("font_size", 30)
	settings_button.add_theme_color_override("font_color", Color.WHITE)
	settings_button.add_theme_color_override("font_outline_color", Color("#111936"))
	settings_button.add_theme_constant_override("outline_size", 8)
	settings_button.add_theme_stylebox_override("normal", _create_3d_btn_style(Color("#2c3e50"), Color("#1a252f"), 6))
	settings_button.add_theme_stylebox_override("hover", _create_3d_btn_style(Color("#34495e"), Color("#1a252f"), 6))
	settings_button.add_theme_stylebox_override("pressed", _create_3d_btn_style(Color("#1e272e"), Color("#1a252f"), 2, 5))
	settings_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	settings_button.pressed.connect(_show_settings_popup)
	button_container.add_child(settings_button)


var _polling_threaded_load: bool = false

func _start_loading_animation() -> void:
	_polling_threaded_load = true

func _process(_delta: float) -> void:
	if not _polling_threaded_load:
		return
	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(GAME_SCENE, progress)
	var pct := float(progress[0]) * 100.0 if not progress.is_empty() else 0.0
	if status == ResourceLoader.THREAD_LOAD_LOADED:
		pct = 100.0
		_polling_threaded_load = false
		game_scene = ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
		if is_instance_valid(loading_bar):
			loading_bar.value = 100.0
		if is_instance_valid(loading_label):
			loading_label.text = "LOADING MISSIONS... 100%"
		_on_loading_finished()
		return
	if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_polling_threaded_load = false
		_on_loading_finished()
		return
	if is_instance_valid(loading_bar):
		loading_bar.value = maxf(loading_bar.value, pct)
	if is_instance_valid(loading_label):
		loading_label.text = "LOADING MISSIONS... %d%%" % int(loading_bar.value)


func _on_loading_finished() -> void:
	is_loading_complete = true
	var tw := create_tween()

	# Fade out loader
	if is_instance_valid(loader_container):
		tw.tween_property(loader_container, "modulate:a", 0.0, 0.2)
		tw.tween_callback(func():
			if is_instance_valid(loader_container):
				loader_container.visible = false
		)

	# Spring in Play & Settings buttons
	tw.tween_callback(func():
		if is_instance_valid(button_container):
			button_container.visible = true
			button_container.scale = Vector2(0.85, 0.85)
			button_container.pivot_offset = button_container.size * 0.5
	)
	tw.parallel().tween_property(button_container, "modulate:a", 1.0, 0.3)
	tw.parallel().tween_property(button_container, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tw.tween_callback(func():
		if is_instance_valid(play_button):
			play_button.grab_focus()
		if GameManager != null and not GameManager.is_privacy_policy_accepted:
			_show_privacy_policy_popup()
	)


func _show_settings_popup() -> void:
	if is_instance_valid(settings_popup):
		return
	if SoundManager != null:
		SoundManager.play_sfx("button")
	var scene := load("res://scenes/popups/settings_popup.tscn") as PackedScene
	if scene != null:
		settings_popup = scene.instantiate()
		settings_popup.privacy_policy_requested.connect(func():
			_show_privacy_policy_popup()
		)
		settings_popup.closed.connect(func():
			settings_popup = null
		)
		add_child(settings_popup)


func _show_privacy_policy_popup() -> void:
	if is_instance_valid(privacy_popup):
		return
	var scene := load("res://scenes/popups/privacy_policy_popup.tscn") as PackedScene
	if scene != null:
		privacy_popup = scene.instantiate()
		privacy_popup.accepted.connect(func():
			if GameManager != null:
				GameManager.set_privacy_policy_accepted(true)
			privacy_popup = null
		)
		add_child(privacy_popup)


func _capture_privacy_and_quit() -> void:
	await get_tree().create_timer(0.8).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_privacy_policy.png")
			img.save_png(path)
			print("PRIVACY_POLICY_SCREENSHOT_SAVED")
	get_tree().quit()


func _start_game(force_start: bool = false) -> void:
	var all_args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	var is_test_run := force_start
	for a in all_args:
		if a.begins_with("--test-") or a == "--play" or a.begins_with("--level"):
			is_test_run = true
			break
	if not is_test_run and GameManager != null and not GameManager.is_privacy_policy_accepted:
		_show_privacy_policy_popup()
		return
	print("SPLASH: starting game...")
	if SoundManager != null:
		SoundManager.play_sfx("button")
	if game_scene == null and ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_LOADED:
		game_scene = ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	if game_scene != null:
		get_tree().change_scene_to_packed(game_scene)
	else:
		get_tree().change_scene_to_file(GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_start_game()
			get_viewport().set_input_as_handled()


func _create_3d_btn_style(bg_col: Color, border_bottom_col: Color, bottom_w: int = 8, top_w: int = 2) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_col
	style.border_color = border_bottom_col
	style.border_width_bottom = bottom_w
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = top_w
	style.set_corner_radius_all(24)
	style.shadow_color = Color(0, 0, 0, 0.45)
	style.shadow_size = 8
	return style


func _capture_screenshot_and_quit(filename: String) -> void:
	await get_tree().create_timer(0.6).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://" + filename)
			img.save_png(path)
			print("SCREENSHOT_SAVED: ", filename)
	get_tree().quit()


func _capture_and_quit() -> void:
	await get_tree().create_timer(1.2).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_splash.png")
			img.save_png(path)
			print("SPLASH_SCREENSHOT_SAVED")
	get_tree().quit()


func _load_ui_texture(res_path: String) -> Texture2D:
	var global_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	return null
