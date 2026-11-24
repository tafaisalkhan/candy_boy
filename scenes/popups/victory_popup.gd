class_name VictoryPopup
extends Control

signal continue_pressed
signal replay_pressed
signal reward_coins_ready(from_pos: Vector2, amount: int)

@export var level_number: int = 1
@export var reward_coins: int = 20
@export var boy_image_path: String = "res://assets/ui/boy_candy_splash_bg.png"

var game_title_font: Font = null
var game_body_font: Font = null
var reward_box: PanelContainer = null

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

func setup(p_level: int, p_reward: int = 20, p_image_path: String = "") -> void:
	level_number = p_level
	reward_coins = p_reward
	if not p_image_path.is_empty():
		boy_image_path = p_image_path

func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

func _build_ui() -> void:
	name = "VictoryPopup"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 1. Dark Backdrop Dimmer
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.04, 0.08, 0.82)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	# 2. Centered Container so the victory card never overflows off-screen
	var center_wrap := CenterContainer.new()
	center_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center_wrap)

	var card := PanelContainer.new()
	card.name = "VictoryCard"
	card.custom_minimum_size = Vector2(680, 0)
	card.pivot_offset = Vector2(340, 380)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#184566")
	card_style.set_corner_radius_all(34)
	card_style.border_color = Color("#0b1d2c")
	card_style.set_border_width_all(8)
	card_style.border_width_bottom = 12
	card_style.shadow_color = Color(0, 0, 0, 0.7)
	card_style.shadow_size = 35
	card.add_theme_stylebox_override("panel", card_style)
	center_wrap.add_child(card)

	var card_margin := MarginContainer.new()
	card_margin.add_theme_constant_override("margin_left", 24)
	card_margin.add_theme_constant_override("margin_top", 22)
	card_margin.add_theme_constant_override("margin_right", 24)
	card_margin.add_theme_constant_override("margin_bottom", 24)
	card.add_child(card_margin)

	var v_box := VBoxContainer.new()
	v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v_box.add_theme_constant_override("separation", 12)
	card_margin.add_child(v_box)

	# 3D Golden Curved Ribbon Banner
	var banner_box := Panel.new()
	banner_box.custom_minimum_size = Vector2(520, 78)
	banner_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	title_lbl.text = "LEVEL %d COMPLETED!" % level_number
	title_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if game_title_font != null:
		title_lbl.add_theme_font_override("font", game_title_font)
	title_lbl.add_theme_font_size_override("font_size", 40)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.add_theme_color_override("font_outline_color", Color("#7f5809"))
	title_lbl.add_theme_constant_override("outline_size", 12)
	banner_box.add_child(title_lbl)

	# 3D Golden Rating Stars Row
	var stars_row := HBoxContainer.new()
	stars_row.name = "StarsRatingRow"
	stars_row.alignment = BoxContainer.ALIGNMENT_CENTER
	stars_row.add_theme_constant_override("separation", 24)
	v_box.add_child(stars_row)

	var star_tex := _load_texture("res://assets/ui/victory-star.png")
	var star_nodes: Array[TextureRect] = []

	var star_configs := [
		{"size": Vector2(86, 86), "rot": -10.0},
		{"size": Vector2(110, 110), "rot": 0.0},
		{"size": Vector2(86, 86), "rot": 10.0}
	]

	for cfg in star_configs:
		var s_rect := TextureRect.new()
		s_rect.texture = star_tex
		s_rect.custom_minimum_size = cfg["size"]
		s_rect.size = cfg["size"]
		s_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		s_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		s_rect.pivot_offset = cfg["size"] * 0.5
		s_rect.rotation_degrees = cfg["rot"]
		s_rect.scale = Vector2.ZERO
		stars_row.add_child(s_rect)
		star_nodes.append(s_rect)

	# Sequentially animate 3D golden stars with bounce overshoot and sound
	for i in range(star_nodes.size()):
		var s_node := star_nodes[i]
		var delay := 0.28 + float(i) * 0.22
		get_tree().create_timer(delay).timeout.connect(func():
			if is_instance_valid(s_node):
				var s_tw := create_tween()
				s_tw.tween_property(s_node, "scale", Vector2(1.25, 1.25), 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				s_tw.tween_property(s_node, "scale", Vector2.ONE, 0.14)
				var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
				if sm != null:
					sm.play_sfx("star_sound")
		)

	var sub_lbl := Label.new()
	sub_lbl.text = "ALL ITEMS SECURED & SAFELY ESCAPED!"
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.custom_minimum_size = Vector2(580, 0)
	if game_body_font != null:
		sub_lbl.add_theme_font_override("font", game_body_font)
	sub_lbl.add_theme_font_size_override("font_size", 22)
	sub_lbl.add_theme_color_override("font_color", Color("#00cec9"))
	sub_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	sub_lbl.add_theme_constant_override("outline_size", 8)
	v_box.add_child(sub_lbl)

	# Boy Picture Frame
	var img_frame := PanelContainer.new()
	img_frame.custom_minimum_size = Vector2(580, 260)
	img_frame.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var f_style := StyleBoxFlat.new()
	f_style.bg_color = Color("#0984e3")
	f_style.set_corner_radius_all(22)
	f_style.border_color = Color("#74b9ff")
	f_style.set_border_width_all(5)
	img_frame.add_theme_stylebox_override("panel", f_style)
	v_box.add_child(img_frame)

	var boy_img := TextureRect.new()
	var boy_tex := _load_texture(boy_image_path)
	if boy_tex != null:
		boy_img.texture = boy_tex
	boy_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	boy_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	boy_img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img_frame.add_child(boy_img)

	# Radiating Flying Sparkles
	var sparkles := CPUParticles2D.new()
	sparkles.position = Vector2(340, 290)
	sparkles.amount = 38
	sparkles.lifetime = 1.4
	sparkles.speed_scale = 1.0
	sparkles.explosiveness = 0.2
	sparkles.randomness = 0.5
	sparkles.direction = Vector2(0, -1)
	sparkles.spread = 180.0
	sparkles.gravity = Vector2(0, 35)
	sparkles.initial_velocity_min = 90.0
	sparkles.initial_velocity_max = 220.0
	sparkles.scale_amount_min = 5.0
	sparkles.scale_amount_max = 10.0
	sparkles.color = Color("#f6e58d")
	card.add_child(sparkles)

	# Additional Floating Sparkling Emoji Stars around the corners
	for offset_pos in [Vector2(40, 145), Vector2(600, 145), Vector2(40, 445), Vector2(600, 445)]:
		var star_lbl := Label.new()
		star_lbl.text = "✨"
		star_lbl.position = offset_pos
		star_lbl.add_theme_font_size_override("font_size", 36)
		card.add_child(star_lbl)
		var star_tw := create_tween().set_loops()
		star_tw.tween_property(star_lbl, "scale", Vector2(1.25, 1.25), randf_range(0.4, 0.7)).set_trans(Tween.TRANS_SINE)
		star_tw.tween_property(star_lbl, "scale", Vector2(0.8, 0.8), randf_range(0.4, 0.7)).set_trans(Tween.TRANS_SINE)

	# Reward Box Container
	reward_box = PanelContainer.new()
	reward_box.custom_minimum_size = Vector2(560, 74)
	reward_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color("#2d3436")
	r_style.border_color = Color("#f39c12")
	r_style.set_border_width_all(4)
	r_style.set_corner_radius_all(24)
	reward_box.add_theme_stylebox_override("panel", r_style)
	v_box.add_child(reward_box)

	var r_hbox := HBoxContainer.new()
	r_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	reward_box.add_child(r_hbox)

	var r_icon := TextureRect.new()
	r_icon.texture = _load_texture("res://assets/ui/reward-coin.png")
	r_icon.custom_minimum_size = Vector2(44, 44)
	r_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r_hbox.add_child(r_icon)

	var r_text := Label.new()
	r_text.text = " REWARD: +%d COINS" % reward_coins
	if game_title_font != null:
		r_text.add_theme_font_override("font", game_title_font)
	r_text.add_theme_font_size_override("font_size", 32)
	r_text.add_theme_color_override("font_color", Color("#f1c40f"))
	r_text.add_theme_color_override("font_outline_color", Color.BLACK)
	r_text.add_theme_constant_override("outline_size", 8)
	r_hbox.add_child(r_text)

	# Rewarded Video Ad Button (2X Double Coins)
	var ad_btn := Button.new()
	ad_btn.text = "🎬 2X REWARD (+%d COINS)" % reward_coins
	ad_btn.custom_minimum_size = Vector2(520, 72)
	ad_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
				var bonus_amt: int = reward_coins
				reward_coins += bonus_amt
				r_text.text = " REWARD: +%d COINS (DOUBLED!)" % reward_coins
				ad_btn.text = "✅ 2X REWARD CLAIMED!"
				ad_btn.disabled = true
				var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
				if sm != null:
					sm.play_sfx("coin_sound")
				reward_coins_ready.emit(ad_btn.get_global_rect().get_center(), bonus_amt)
			)
	)
	v_box.add_child(ad_btn)
	var ad_mgr_vic = get_tree().root.get_node_or_null("AdManager") if is_inside_tree() else null
	ad_btn.visible = ad_mgr_vic != null and ad_mgr_vic.has_method("is_rewarded_ready") and ad_mgr_vic.is_rewarded_ready()

	# Tactile 3D Continue Button
	var cont_btn := Button.new()
	cont_btn.text = "CONTINUE ➔"
	cont_btn.custom_minimum_size = Vector2(520, 84)
	cont_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color = Color("#2ecc71")
	btn_style.border_color = Color("#1e824c")
	btn_style.border_width_bottom = 8
	btn_style.border_width_left = 3
	btn_style.border_width_right = 3
	btn_style.border_width_top = 2
	btn_style.set_corner_radius_all(28)
	btn_style.shadow_color = Color(0, 0, 0, 0.4)
	btn_style.shadow_size = 8

	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color("#40d47e")

	var btn_press := btn_style.duplicate() as StyleBoxFlat
	btn_press.bg_color = Color("#27ae60")
	btn_press.border_width_bottom = 2
	btn_press.border_width_top = 6

	cont_btn.add_theme_stylebox_override("normal", btn_style)
	cont_btn.add_theme_stylebox_override("hover", btn_hover)
	cont_btn.add_theme_stylebox_override("pressed", btn_press)
	if game_title_font != null:
		cont_btn.add_theme_font_override("font", game_title_font)
	cont_btn.add_theme_font_size_override("font_size", 38)
	cont_btn.add_theme_color_override("font_color", Color.WHITE)
	cont_btn.add_theme_color_override("font_outline_color", Color("#1b4d3e"))
	cont_btn.add_theme_constant_override("outline_size", 10)
	cont_btn.pressed.connect(func():
		continue_pressed.emit()
	)
	v_box.add_child(cont_btn)

	# Tactile 3D Replay Button (shown alongside Continue on level complete)
	var replay_btn := Button.new()
	replay_btn.text = "🔄 REPLAY"
	replay_btn.custom_minimum_size = Vector2(520, 66)
	replay_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var rep_style := StyleBoxFlat.new()
	rep_style.bg_color = Color("#3498db")
	rep_style.border_color = Color("#1f618d")
	rep_style.border_width_bottom = 6
	rep_style.border_width_left = 3
	rep_style.border_width_right = 3
	rep_style.border_width_top = 2
	rep_style.set_corner_radius_all(24)
	replay_btn.add_theme_stylebox_override("normal", rep_style)
	if game_title_font != null:
		replay_btn.add_theme_font_override("font", game_title_font)
	replay_btn.add_theme_font_size_override("font_size", 32)
	replay_btn.add_theme_color_override("font_color", Color.WHITE)
	replay_btn.add_theme_color_override("font_outline_color", Color("#154360"))
	replay_btn.add_theme_constant_override("outline_size", 8)
	replay_btn.pressed.connect(func():
		replay_pressed.emit()
	)
	v_box.add_child(replay_btn)

	# Squash-and-stretch entrance animation (pause-safe)
	card.scale = Vector2(0.42, 0.42)
	card.modulate.a = 0.0
	var pop_tw := create_tween()
	pop_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pop_tw.tween_property(card, "modulate:a", 1.0, 0.12)
	pop_tw.parallel().tween_property(card, "scale", Vector2(1.06, 0.95), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(card, "scale", Vector2(0.98, 1.02), 0.09)
	pop_tw.tween_property(card, "scale", Vector2.ONE, 0.08)

	pop_tw.tween_interval(0.2)
	pop_tw.tween_callback(func():
		if is_instance_valid(reward_box):
			var from_pos := reward_box.global_position + reward_box.size * 0.5
			reward_coins_ready.emit(from_pos, reward_coins)
	)
