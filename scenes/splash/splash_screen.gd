extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const SPLASH_BACKGROUND := "res://assets/ui/game_icon.png"

var play_button: Button
var game_scene: PackedScene
var start_requested: bool = false
var privacy_popup: Control = null


func _ready() -> void:
	var background := TextureRect.new()
	background.texture = _load_ui_texture(SPLASH_BACKGROUND)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	var title_font: Font = null
	if ResourceLoader.exists("res://assets/fonts/LuckiestGuy-Regular.ttf"):
		title_font = load("res://assets/fonts/LuckiestGuy-Regular.ttf") as Font

	var title_shadow := Label.new()
	title_shadow.text = "BOY FAVORITE\nCOLLECTION"
	title_shadow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_shadow.offset_left = 22.0
	title_shadow.offset_right = -22.0
	title_shadow.offset_top = 55.0
	title_shadow.offset_bottom = 270.0
	title_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_shadow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_shadow.add_theme_font_override("font", title_font)
	title_shadow.add_theme_font_size_override("font_size", 68)
	title_shadow.add_theme_color_override("font_color", Color("#5123aa"))
	title_shadow.add_theme_color_override("font_outline_color", Color("#5123aa"))
	title_shadow.add_theme_constant_override("outline_size", 20)
	add_child(title_shadow)

	var title := Label.new()
	title.text = "BOY FAVORITE\nCOLLECTION"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 22.0
	title.offset_right = -22.0
	title.offset_top = 42.0
	title.offset_bottom = 252.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 68)
	title.add_theme_color_override("font_color", Color("#ffb900"))
	title.add_theme_color_override("font_outline_color", Color.WHITE)
	title.add_theme_constant_override("outline_size", 12)
	add_child(title)

	play_button = Button.new()
	play_button.text = "PLAY"
	play_button.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	play_button.offset_left = 120.0
	play_button.offset_right = -120.0
	play_button.offset_top = -175.0
	play_button.offset_bottom = -55.0
	play_button.add_theme_font_override("font", title_font)
	play_button.add_theme_font_size_override("font_size", 44)
	play_button.add_theme_color_override("font_color", Color.WHITE)
	play_button.add_theme_color_override("font_outline_color", Color("#17530b"))
	play_button.add_theme_constant_override("outline_size", 5)
	play_button.add_theme_stylebox_override("normal", _button_style(Color("#44d515"), Color.WHITE))
	play_button.add_theme_stylebox_override("hover", _button_style(Color("#5bea28"), Color.WHITE))
	play_button.add_theme_stylebox_override("pressed", _button_style(Color("#2eaf0b"), Color.WHITE))
	play_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	play_button.focus_mode = Control.FOCUS_ALL
	play_button.pressed.connect(_start_game)
	add_child(play_button)
	play_button.grab_focus()

	game_scene = load(GAME_SCENE) as PackedScene
	play_button.disabled = (game_scene == null)

	var all_args := OS.get_cmdline_user_args() + OS.get_cmdline_args()
	if "--test-privacy" in all_args or FileAccess.file_exists("res://test_privacy.flag"):
		if FileAccess.file_exists("res://test_privacy.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_privacy.flag"))
		_show_privacy_policy_popup()
		_capture_privacy_and_quit()
		return

	for arg in all_args:
		if arg.begins_with("--test") or arg == "--play" or arg.begins_with("--level"):
			call_deferred("_start_game")
			return

	if FileAccess.file_exists("res://test_loop.flag") or FileAccess.file_exists("res://test_powerup.flag") or FileAccess.file_exists("res://test_screenshot.flag") or FileAccess.file_exists("res://test_cupboard.flag") or FileAccess.file_exists("res://test_victory.flag") or FileAccess.file_exists("res://test_fail.flag"):
		call_deferred("_start_game")
		return

	if "--screen-game" in all_args:
		call_deferred("_start_game")
		return

	if "--screenshot" in all_args:
		_capture_and_quit()
		return

	# Show Privacy Policy Popup on first launch if not yet accepted
	if GameManager != null and not GameManager.is_privacy_policy_accepted:
		call_deferred("_show_privacy_policy_popup")


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


func _start_game() -> void:
	if GameManager != null and not GameManager.is_privacy_policy_accepted:
		_show_privacy_policy_popup()
		return
	print("SPLASH: starting game...")
	if SoundManager != null:
		SoundManager.play_sfx("button")
	if game_scene != null:
		get_tree().change_scene_to_packed(game_scene)
	else:
		get_tree().change_scene_to_file(GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_start_game()
			get_viewport().set_input_as_handled()


func _button_style(fill: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(6)
	style.set_corner_radius_all(18)
	return style


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
