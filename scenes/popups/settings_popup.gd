class_name SettingsPopup
extends Control

signal closed
signal privacy_policy_requested

var game_title_font: Font = null
var game_body_font: Font = null
var sfx_btn: Button = null
var music_btn: Button = null
var remove_ads_btn: Button = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_fonts()
	_build_ui()

func _init_fonts() -> void:
	if ResourceLoader.exists("res://assets/fonts/game_title.ttf"):
		game_title_font = load("res://assets/fonts/game_title.ttf") as Font
	elif ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf"):
		game_title_font = load("res://assets/fonts/LilitaOne-Regular.ttf") as Font
	elif ResourceLoader.exists("res://assets/fonts/LuckiestGuy-Regular.ttf"):
		game_title_font = load("res://assets/fonts/LuckiestGuy-Regular.ttf") as Font

	if ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf"):
		game_body_font = load("res://assets/fonts/LilitaOne-Regular.ttf") as Font
	elif ResourceLoader.exists("res://assets/fonts/Fredoka-Variable.ttf"):
		game_body_font = load("res://assets/fonts/Fredoka-Variable.ttf") as Font
	else:
		game_body_font = game_title_font

func _build_ui() -> void:
	name = "SettingsPopup"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 1. Dark Backdrop Dimmer
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.04, 0.08, 0.85)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# 2. Main Dialog Card (640 width for generous 130px side margins)
	var card := PanelContainer.new()
	card.name = "SettingsCard"
	card.custom_minimum_size = Vector2(640, 780)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.pivot_offset = Vector2(320, 390)
	card.offset_left = -320
	card.offset_top = -390
	card.offset_right = 320
	card.offset_bottom = 390

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#1e272e")
	card_style.border_color = Color("#00cec9")
	card_style.border_width_bottom = 12
	card_style.border_width_top = 4
	card_style.border_width_left = 4
	card_style.border_width_right = 4
	card_style.set_corner_radius_all(32)
	card_style.shadow_color = Color(0, 0, 0, 0.65)
	card_style.shadow_size = 24
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	card.add_child(margin)

	var v_box := VBoxContainer.new()
	v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v_box.add_theme_constant_override("separation", 18)
	margin.add_child(v_box)

	# Title Banner
	var title_lbl := Label.new()
	title_lbl.text = "⚙️ GAME SETTINGS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		title_lbl.add_theme_font_override("font", game_title_font)
	title_lbl.add_theme_font_size_override("font_size", 40)
	title_lbl.add_theme_color_override("font_color", Color("#00cec9"))
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 10)
	v_box.add_child(title_lbl)

	# Sound Effects (SFX) Button
	sfx_btn = Button.new()
	_update_sfx_button()
	sfx_btn.custom_minimum_size = Vector2(520, 78)
	sfx_btn.pressed.connect(_toggle_sfx)
	v_box.add_child(sfx_btn)

	# Background Music (BGM) Button
	music_btn = Button.new()
	_update_music_button()
	music_btn.custom_minimum_size = Vector2(520, 78)
	music_btn.pressed.connect(_toggle_music)
	v_box.add_child(music_btn)

	# Remove Ads ($4.99) Button
	remove_ads_btn = Button.new()
	_update_remove_ads_button()
	remove_ads_btn.custom_minimum_size = Vector2(520, 78)
	remove_ads_btn.pressed.connect(_on_remove_ads_pressed)
	v_box.add_child(remove_ads_btn)

	# Privacy Policy Button
	var privacy_btn := Button.new()
	privacy_btn.text = "📜 PRIVACY POLICY"
	privacy_btn.custom_minimum_size = Vector2(520, 74)
	_apply_btn_style(privacy_btn, Color("#34495e"), Color("#2c3e50"), Color("#4b6584"))
	privacy_btn.pressed.connect(func():
		privacy_policy_requested.emit()
	)
	v_box.add_child(privacy_btn)

	# Close Button
	var close_btn := Button.new()
	close_btn.text = "✖ CLOSE"
	close_btn.custom_minimum_size = Vector2(520, 82)
	_apply_btn_style(close_btn, Color("#e74c3c"), Color("#c0392b"), Color("#ff6b6b"))
	close_btn.pressed.connect(func():
		if SoundManager != null:
			SoundManager.play_sfx("button")
		var close_tw := create_tween()
		close_tw.tween_property(card, "scale", Vector2(0.5, 0.5), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		close_tw.parallel().tween_property(card, "modulate:a", 0.0, 0.18)
		close_tw.tween_callback(func():
			closed.emit()
			queue_free()
		)
	)
	v_box.add_child(close_btn)

	# Bouncy entrance animation
	card.scale = Vector2(0.3, 0.3)
	card.modulate.a = 0.0
	var pop_tw := create_tween()
	pop_tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tw.parallel().tween_property(card, "modulate:a", 1.0, 0.25)

func _toggle_sfx() -> void:
	var new_sfx := not (SoundManager.sfx_enabled if SoundManager != null else true)
	if SoundManager != null:
		SoundManager.set_sfx_enabled(new_sfx)
		SoundManager.play_sfx("button")
	if GameManager != null:
		GameManager.set_audio_settings(SoundManager.music_enabled if SoundManager != null else true, new_sfx)
	_update_sfx_button()

func _toggle_music() -> void:
	var new_music := not (SoundManager.music_enabled if SoundManager != null else true)
	if SoundManager != null:
		SoundManager.set_music_enabled(new_music)
		SoundManager.play_sfx("button")
	if GameManager != null:
		GameManager.set_audio_settings(new_music, SoundManager.sfx_enabled if SoundManager != null else true)
	_update_music_button()

func _on_remove_ads_pressed() -> void:
	if GameManager != null and GameManager.is_ads_removed:
		return
	if GameManager != null:
		GameManager.set_ads_removed(true)
	var ad_mgr = get_tree().root.get_node_or_null("AdManager")
	if ad_mgr != null and ad_mgr.has_method("remove_all_ads"):
		ad_mgr.remove_all_ads()
	if SoundManager != null:
		SoundManager.play_sfx("coin_sound")
	_update_remove_ads_button()

func _update_remove_ads_button() -> void:
	if not is_instance_valid(remove_ads_btn):
		return
	var is_removed := GameManager.is_ads_removed if GameManager != null else false
	if is_removed:
		remove_ads_btn.text = "✅ ADS REMOVED"
		remove_ads_btn.disabled = true
		_apply_btn_style(remove_ads_btn, Color("#27ae60"), Color("#1e824c"), Color("#2ecc71"))
	else:
		remove_ads_btn.text = "🚫 REMOVE ADS ($4.99)"
		remove_ads_btn.disabled = false
		_apply_btn_style(remove_ads_btn, Color("#e67e22"), Color("#d35400"), Color("#f39c12"))

func _update_sfx_button() -> void:
	if not is_instance_valid(sfx_btn):
		return
	var is_on := SoundManager.sfx_enabled if SoundManager != null else true
	sfx_btn.text = "🔊 SOUND EFFECTS: " + ("ON" if is_on else "OFF")
	var bg_col := Color("#27ae60") if is_on else Color("#7f8c8d")
	var border_col := Color("#1e824c") if is_on else Color("#576574")
	var hover_col := Color("#2ecc71") if is_on else Color("#95a5a6")
	_apply_btn_style(sfx_btn, bg_col, border_col, hover_col)

func _update_music_button() -> void:
	if not is_instance_valid(music_btn):
		return
	var is_on := SoundManager.music_enabled if SoundManager != null else true
	music_btn.text = "🎵 MUSIC: " + ("ON" if is_on else "OFF")
	var bg_col := Color("#2980b9") if is_on else Color("#7f8c8d")
	var border_col := Color("#1f618d") if is_on else Color("#576574")
	var hover_col := Color("#3498db") if is_on else Color("#95a5a6")
	_apply_btn_style(music_btn, bg_col, border_col, hover_col)

func _apply_btn_style(btn: Button, bg_col: Color, border_col: Color, hover_col: Color) -> void:
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = bg_col
	b_style.border_color = border_col
	b_style.border_width_bottom = 6
	b_style.border_width_left = 3
	b_style.border_width_right = 3
	b_style.border_width_top = 2
	b_style.set_corner_radius_all(22)
	b_style.shadow_color = Color(0, 0, 0, 0.4)
	b_style.shadow_size = 6

	var h_style := b_style.duplicate() as StyleBoxFlat
	h_style.bg_color = hover_col

	var p_style := b_style.duplicate() as StyleBoxFlat
	p_style.bg_color = border_col
	p_style.border_width_bottom = 2
	p_style.border_width_top = 6

	btn.add_theme_stylebox_override("normal", b_style)
	btn.add_theme_stylebox_override("hover", h_style)
	btn.add_theme_stylebox_override("pressed", p_style)
	if game_title_font != null:
		btn.add_theme_font_override("font", game_title_font)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color.BLACK)
	btn.add_theme_constant_override("outline_size", 6)
