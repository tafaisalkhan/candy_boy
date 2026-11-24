class_name PrivacyPolicyPopup
extends Control

signal accepted

var game_title_font: Font = null
var game_body_font: Font = null

func _ready() -> void:
	_init_fonts()
	_build_ui()

func _init_fonts() -> void:
	if ResourceLoader.exists("res://assets/fonts/LuckiestGuy-Regular.ttf"):
		game_title_font = load("res://assets/fonts/LuckiestGuy-Regular.ttf") as Font
	elif ResourceLoader.exists("res://assets/fonts/game_title.ttf"):
		game_title_font = load("res://assets/fonts/game_title.ttf") as Font
	elif ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf"):
		game_title_font = load("res://assets/fonts/LilitaOne-Regular.ttf") as Font
	game_body_font = game_title_font

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _build_ui() -> void:
	name = "PrivacyPolicyPopup"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 1. Dark Backdrop Dimmer
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.04, 0.08, 0.85)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# 2. Main Dialog Card - Increased side space (640px width for generous 130px side margins)
	var card := PanelContainer.new()
	card.name = "PrivacyCard"
	card.custom_minimum_size = Vector2(640, 880)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.pivot_offset = Vector2(320, 440)
	card.offset_left = -320
	card.offset_top = -440
	card.offset_right = 320
	card.offset_bottom = 440

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#15212d")
	card_style.set_corner_radius_all(32)
	card_style.border_color = Color("#f1c40f")
	card_style.set_border_width_all(7)
	card_style.shadow_color = Color(0, 0, 0, 0.75)
	card_style.shadow_size = 35
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	var v_box := VBoxContainer.new()
	v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v_box.add_theme_constant_override("separation", 12)
	card.add_child(v_box)

	# 3D Golden Curved Ribbon Banner
	var banner_box := Panel.new()
	banner_box.custom_minimum_size = Vector2(500, 80)
	banner_box.size = Vector2(500, 80)
	var b_trans := StyleBoxEmpty.new()
	banner_box.add_theme_stylebox_override("panel", b_trans)
	v_box.add_child(banner_box)

	var banner_ribbon := TextureRect.new()
	banner_ribbon.texture = _load_texture("res://assets/ui/banner_ribbon_gold.svg")
	banner_ribbon.set_anchors_preset(Control.PRESET_FULL_RECT)
	banner_ribbon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	banner_ribbon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	banner_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner_box.add_child(banner_ribbon)

	var title_lbl := Label.new()
	title_lbl.text = "PRIVACY & SAFETY"
	title_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if game_title_font != null:
		title_lbl.add_theme_font_override("font", game_title_font)
	title_lbl.add_theme_font_size_override("font_size", 34)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.add_theme_color_override("font_outline_color", Color("#7f5809"))
	title_lbl.add_theme_constant_override("outline_size", 10)
	banner_box.add_child(title_lbl)

	# 3D Security Shield Centerpiece Icon
	var shield_rect := TextureRect.new()
	shield_rect.texture = _load_texture("res://assets/ui/icon_3d_privacy.svg")
	shield_rect.custom_minimum_size = Vector2(90, 90)
	shield_rect.size = Vector2(90, 90)
	shield_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shield_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	shield_rect.pivot_offset = Vector2(45, 45)
	shield_rect.scale = Vector2.ZERO
	v_box.add_child(shield_rect)

	var s_tw := create_tween()
	s_tw.tween_property(shield_rect, "scale", Vector2(1.15, 1.15), 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	s_tw.tween_property(shield_rect, "scale", Vector2.ONE, 0.15)

	var sub_lbl := Label.new()
	sub_lbl.text = "YOUR PRIVACY & SAFETY ARE PROTECTED"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_body_font != null:
		sub_lbl.add_theme_font_override("font", game_body_font)
	sub_lbl.add_theme_font_size_override("font_size", 19)
	sub_lbl.add_theme_color_override("font_color", Color("#00cec9"))
	sub_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	sub_lbl.add_theme_constant_override("outline_size", 7)
	v_box.add_child(sub_lbl)

	# Privacy Terms Box Container - Cleanly proportioned inside 640px card
	var terms_box := PanelContainer.new()
	terms_box.custom_minimum_size = Vector2(580, 420)
	var t_style := StyleBoxFlat.new()
	t_style.bg_color = Color(0.08, 0.12, 0.18, 0.95)
	t_style.border_color = Color("#34495e")
	t_style.set_border_width_all(3)
	t_style.set_corner_radius_all(18)
	terms_box.add_theme_stylebox_override("panel", t_style)
	v_box.add_child(terms_box)

	var terms_margin := MarginContainer.new()
	terms_margin.add_theme_constant_override("margin_left", 20)
	terms_margin.add_theme_constant_override("margin_top", 16)
	terms_margin.add_theme_constant_override("margin_right", 20)
	terms_margin.add_theme_constant_override("margin_bottom", 16)
	terms_box.add_child(terms_margin)

	var terms_vbox := VBoxContainer.new()
	terms_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	terms_vbox.add_theme_constant_override("separation", 12)
	terms_margin.add_child(terms_vbox)

	_add_term_bullet(terms_vbox, "🛡️ COPPA & CHILD SAFE", "We never collect personal identity details or contact info. Suitable for all ages.")
	_add_term_bullet(terms_vbox, "💾 LOCAL GAMEPLAY SAVES", "Level progress and coins are stored securely directly on your device only.")
	_add_term_bullet(terms_vbox, "🚫 NO 3RD-PARTY TRACKING", "We do not sell, rent, or trade your data with external advertisers or brokers.")
	_add_term_bullet(terms_vbox, "🤝 USER CONSENT", "By tapping Accept below, you agree to our Terms of Use and Privacy Policy.")

	# Tactile 3D Accept Button
	var accept_btn := Button.new()
	accept_btn.text = "ACCEPT & CONTINUE ➔"
	accept_btn.custom_minimum_size = Vector2(520, 88)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#2ecc71")
	btn_style.border_color = Color("#1e824c")
	btn_style.border_width_bottom = 8
	btn_style.border_width_left = 3
	btn_style.border_width_right = 3
	btn_style.border_width_top = 2
	btn_style.set_corner_radius_all(26)
	btn_style.shadow_color = Color(0, 0, 0, 0.4)
	btn_style.shadow_size = 8

	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color("#40d47e")

	var btn_press := btn_style.duplicate() as StyleBoxFlat
	btn_press.bg_color = Color("#27ae60")
	btn_press.border_width_bottom = 2
	btn_press.border_width_top = 6

	accept_btn.add_theme_stylebox_override("normal", btn_style)
	accept_btn.add_theme_stylebox_override("hover", btn_hover)
	accept_btn.add_theme_stylebox_override("pressed", btn_press)
	if game_title_font != null:
		accept_btn.add_theme_font_override("font", game_title_font)
	accept_btn.add_theme_font_size_override("font_size", 30)
	accept_btn.add_theme_color_override("font_color", Color.WHITE)
	accept_btn.add_theme_color_override("font_outline_color", Color("#1b4d3e"))
	accept_btn.add_theme_constant_override("outline_size", 8)
	accept_btn.pressed.connect(_on_accept_pressed)
	v_box.add_child(accept_btn)

	# Squash-and-stretch pop-in entrance animation (pause-safe)
	card.scale = Vector2(0.42, 0.42)
	card.modulate.a = 0.0
	var pop_tw := create_tween()
	pop_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pop_tw.tween_property(card, "modulate:a", 1.0, 0.12)
	pop_tw.parallel().tween_property(card, "scale", Vector2(1.06, 0.95), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(card, "scale", Vector2(0.98, 1.02), 0.09)
	pop_tw.tween_property(card, "scale", Vector2.ONE, 0.08)

func _add_term_bullet(parent: Control, header: String, desc: String) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	parent.add_child(box)

	var h_lbl := Label.new()
	h_lbl.text = header
	if game_title_font != null:
		h_lbl.add_theme_font_override("font", game_title_font)
	h_lbl.add_theme_font_size_override("font_size", 18)
	h_lbl.add_theme_color_override("font_color", Color("#f1c40f"))
	box.add_child(h_lbl)

	var d_lbl := Label.new()
	d_lbl.text = desc
	d_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if game_body_font != null:
		d_lbl.add_theme_font_override("font", game_body_font)
	d_lbl.add_theme_font_size_override("font_size", 15)
	d_lbl.add_theme_color_override("font_color", Color("#dfe6e9"))
	box.add_child(d_lbl)

func _on_accept_pressed() -> void:
	var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
	if sm != null:
		sm.play_sfx("button")
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.22)
	tw.chain().tween_callback(func():
		accepted.emit()
		queue_free()
	)
