class_name FailPopup
extends Control

signal retry_pressed

@export var reason_text: String = "YOU WERE SPOTTED BY THE GUARD!"
@export var tip_text: String = "💡 TIP: Sneak when guards turn away or use Invisibility!"
@export var boy_crying_image_path: String = "res://assets/ui/boy_crying_fail.png"

var game_title_font: Font = null
var game_body_font: Font = null

func _ready() -> void:
	_init_fonts()
	_build_ui()

func _init_fonts() -> void:
	if ResourceLoader.exists("res://assets/fonts/game_title.ttf"):
		game_title_font = load("res://assets/fonts/game_title.ttf") as Font
	elif ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf"):
		game_title_font = load("res://assets/fonts/LilitaOne-Regular.ttf") as Font

	if ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf"):
		game_body_font = load("res://assets/fonts/LilitaOne-Regular.ttf") as Font
	else:
		game_body_font = game_title_font

func setup(p_reason: String = "", p_tip: String = "", p_image_path: String = "") -> void:
	if not p_reason.is_empty():
		reason_text = p_reason
	if not p_tip.is_empty():
		tip_text = p_tip
	if not p_image_path.is_empty():
		boy_crying_image_path = p_image_path

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _build_ui() -> void:
	name = "FailPopup"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 1. Dark Backdrop Dimmer
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.02, 0.03, 0.82)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# 2. Main Fail Card Dialog
	var card := PanelContainer.new()
	card.name = "FailCard"
	card.custom_minimum_size = Vector2(780, 800)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.pivot_offset = Vector2(390, 400)
	card.offset_left = -390
	card.offset_top = -400
	card.offset_right = 390
	card.offset_bottom = 400

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#231518")
	card_style.set_corner_radius_all(34)
	card_style.border_color = Color("#e74c3c")
	card_style.set_border_width_all(8)
	card_style.shadow_color = Color(0, 0, 0, 0.75)
	card_style.shadow_size = 35
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	var v_box := VBoxContainer.new()
	v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v_box.add_theme_constant_override("separation", 14)
	card.add_child(v_box)

	# 3D Crimson Ribbon Header Banner
	var banner_box := Panel.new()
	banner_box.custom_minimum_size = Vector2(580, 88)
	banner_box.size = Vector2(580, 88)
	var b_trans := StyleBoxEmpty.new()
	banner_box.add_theme_stylebox_override("panel", b_trans)
	v_box.add_child(banner_box)

	var banner_ribbon := TextureRect.new()
	banner_ribbon.texture = _load_texture("res://assets/ui/banner_ribbon_red.svg")
	banner_ribbon.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner_ribbon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	banner_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.add_child(banner_ribbon)

	var title_lbl := Label.new()
	title_lbl.text = "LEVEL FAILED!"
	title_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if game_title_font != null:
		title_lbl.add_theme_font_override("font", game_title_font)
	title_lbl.add_theme_font_size_override("font_size", 42)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.add_theme_color_override("font_outline_color", Color("#4a080c"))
	title_lbl.add_theme_constant_override("outline_size", 12)
	banner_box.add_child(title_lbl)

	# 3D Broken Heart Icon
	var heart_rect := TextureRect.new()
	heart_rect.texture = _load_texture("res://assets/ui/heart_3d_broken.svg")
	heart_rect.custom_minimum_size = Vector2(96, 96)
	heart_rect.size = Vector2(96, 96)
	heart_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	heart_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heart_rect.pivot_offset = Vector2(48, 48)
	heart_rect.scale = Vector2.ZERO
	v_box.add_child(heart_rect)

	var h_tw := create_tween()
	h_tw.tween_property(heart_rect, "scale", Vector2(1.2, 1.2), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	h_tw.tween_property(heart_rect, "scale", Vector2.ONE, 0.15)

	var sub_lbl := Label.new()
	sub_lbl.text = reason_text.to_upper()
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_body_font != null:
		sub_lbl.add_theme_font_override("font", game_body_font)
	sub_lbl.add_theme_font_size_override("font_size", 24)
	sub_lbl.add_theme_color_override("font_color", Color("#fab1a0"))
	sub_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	sub_lbl.add_theme_constant_override("outline_size", 8)
	v_box.add_child(sub_lbl)

	# Boy Picture Frame (Crying boy)
	var img_frame := PanelContainer.new()
	img_frame.custom_minimum_size = Vector2(660, 320)
	var f_style := StyleBoxFlat.new()
	f_style.bg_color = Color("#1a080a")
	f_style.set_corner_radius_all(22)
	f_style.border_color = Color("#e74c3c")
	f_style.set_border_width_all(5)
	img_frame.add_theme_stylebox_override("panel", f_style)
	v_box.add_child(img_frame)

	var boy_img := TextureRect.new()
	var boy_tex := _load_texture(boy_crying_image_path)
	if boy_tex == null:
		boy_tex = _load_texture("res://assets/ui/boy_crying_fail.jpg")
	if boy_tex != null:
		boy_img.texture = boy_tex
	boy_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boy_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	boy_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img_frame.add_child(boy_img)

	# Tip Banner Box Container
	var tip_box := PanelContainer.new()
	tip_box.custom_minimum_size = Vector2(640, 76)
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color("#2d181c")
	t_style.border_color = Color("#962d00")
	t_style.set_border_width_all(3)
	t_style.set_corner_radius_all(20)
	tip_box.add_theme_stylebox_override("panel", t_style)
	v_box.add_child(tip_box)

	var tip_lbl := Label.new()
	tip_lbl.text = tip_text
	tip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if game_body_font != null:
		tip_lbl.add_theme_font_override("font", game_body_font)
	tip_lbl.add_theme_font_size_override("font_size", 22)
	tip_lbl.add_theme_color_override("font_color", Color("#ffeaa7"))
	tip_box.add_child(tip_lbl)

	# Rewarded Video Ad Button (Watch for Bonus Coins)
	var ad_btn := Button.new()
	ad_btn.text = "🎬 WATCH AD (+30 COINS 🪙)"
	ad_btn.custom_minimum_size = Vector2(580, 80)
	var ad_style := StyleBoxFlat.new()
	ad_style.bg_color = Color("#f39c12")
	ad_style.border_color = Color("#d35400")
	ad_style.border_width_bottom = 6
	ad_style.border_width_left = 3
	ad_style.border_width_right = 3
	ad_style.border_width_top = 2
	ad_style.set_corner_radius_all(24)
	ad_style.shadow_color = Color(0, 0, 0, 0.35)
	ad_style.shadow_size = 6

	var ad_hover := ad_style.duplicate() as StyleBoxFlat
	ad_hover.bg_color = Color("#f1c40f")

	var ad_press := ad_style.duplicate() as StyleBoxFlat
	ad_press.bg_color = Color("#e67e22")
	ad_press.border_width_bottom = 2
	ad_press.border_width_top = 6

	ad_btn.add_theme_stylebox_override("normal", ad_style)
	ad_btn.add_theme_stylebox_override("hover", ad_hover)
	ad_btn.add_theme_stylebox_override("pressed", ad_press)
	if game_title_font != null:
		ad_btn.add_theme_font_override("font", game_title_font)
	ad_btn.add_theme_font_size_override("font_size", 30)
	ad_btn.add_theme_color_override("font_color", Color.WHITE)
	ad_btn.add_theme_color_override("font_outline_color", Color("#7f4f00"))
	ad_btn.add_theme_constant_override("outline_size", 8)

	ad_btn.pressed.connect(func():
		var ad_mgr = get_tree().root.get_node_or_null("AdManager")
		if ad_mgr != null and ad_mgr.has_method("show_rewarded"):
			ad_btn.disabled = true
			ad_btn.text = "🎬 LOADING AD..."
			ad_mgr.show_rewarded(func(amt, _type):
				ad_btn.text = "✅ +%d COINS RECEIVED!" % amt
				ad_btn.disabled = true
				if GameManager != null:
					GameManager.coins += amt
					GameManager.save_game_state()
				if SignalHub != null and GameManager != null:
					SignalHub.emit_coins_changed(GameManager.coins)
				if SoundManager != null:
					SoundManager.play_sfx("coin_sound")
			)
	)
	v_box.add_child(ad_btn)

	# Tactile 3D Try Again Button
	var retry_btn := Button.new()
	retry_btn.text = "🔄 TRY AGAIN"
	retry_btn.custom_minimum_size = Vector2(580, 96)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#e74c3c")
	btn_style.border_color = Color("#80151f")
	btn_style.border_width_bottom = 8
	btn_style.border_width_left = 3
	btn_style.border_width_right = 3
	btn_style.border_width_top = 2
	btn_style.set_corner_radius_all(28)
	btn_style.shadow_color = Color(0, 0, 0, 0.45)
	btn_style.shadow_size = 8

	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color("#ff6b6b")

	var btn_press := btn_style.duplicate() as StyleBoxFlat
	btn_press.bg_color = Color("#c0392b")
	btn_press.border_width_bottom = 2
	btn_press.border_width_top = 6

	retry_btn.add_theme_stylebox_override("normal", btn_style)
	retry_btn.add_theme_stylebox_override("hover", btn_hover)
	retry_btn.add_theme_stylebox_override("pressed", btn_press)
	if game_title_font != null:
		retry_btn.add_theme_font_override("font", game_title_font)
	retry_btn.add_theme_font_size_override("font_size", 38)
	retry_btn.add_theme_color_override("font_color", Color.WHITE)
	retry_btn.add_theme_color_override("font_outline_color", Color("#4a080c"))
	retry_btn.add_theme_constant_override("outline_size", 10)
	retry_btn.pressed.connect(func():
		retry_pressed.emit()
	)
	v_box.add_child(retry_btn)

	# Entrance bounce animation
	card.scale = Vector2(0.3, 0.3)
	card.modulate.a = 0.0
	var pop_tw := create_tween()
	pop_tw.tween_property(card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tw.parallel().tween_property(card, "modulate:a", 1.0, 0.3)
