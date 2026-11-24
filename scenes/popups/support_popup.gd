class_name SupportPopup
extends Control

signal closed

var game_title_font: Font = null
var game_body_font: Font = null
var status_label: Label = null
var _card: Control = null
## Optional: "rate", "share" or "coffee". Empty = random non-repeating pick.
var forced_kind: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_init_fonts()
	_build_ui()

func _init_fonts() -> void:
	if ResourceLoader.exists("res://assets/fonts/LuckiestGuy-Regular.ttf"):
		game_title_font = load("res://assets/fonts/LuckiestGuy-Regular.ttf") as Font
	elif ResourceLoader.exists("res://assets/fonts/game_title.ttf"):
		game_title_font = load("res://assets/fonts/game_title.ttf") as Font
	game_body_font = game_title_font

func _build_ui() -> void:
	name = "SupportPopup"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.05, 0.08, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card_size := Vector2(680, 480)
	_card = Control.new()
	_card.custom_minimum_size = card_size
	_card.size = card_size
	_card.pivot_offset = card_size * 0.5
	center.add_child(_card)

	var bg_panel := PanelContainer.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#184566")
	style.border_color = Color("#0b1d2c")
	style.set_border_width_all(6)
	style.border_width_bottom = 12
	style.set_corner_radius_all(24)
	style.content_margin_left = 34
	style.content_margin_right = 34
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	bg_panel.add_theme_stylebox_override("panel", style)
	_card.add_child(bg_panel)

	var close_x := Button.new()
	close_x.text = "✖"
	close_x.size = Vector2(54, 54)
	close_x.position = Vector2(card_size.x - 32, -20)
	if game_title_font != null:
		close_x.add_theme_font_override("font", game_title_font)
	close_x.add_theme_font_size_override("font_size", 28)
	close_x.add_theme_color_override("font_color", Color.WHITE)
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color("#e83b3b")
	cs.border_color = Color("#1a0808")
	cs.set_border_width_all(3)
	cs.border_width_bottom = 6
	cs.set_corner_radius_all(12)
	close_x.add_theme_stylebox_override("normal", cs)
	close_x.add_theme_stylebox_override("hover", cs)
	close_x.add_theme_stylebox_override("pressed", cs)
	close_x.pressed.connect(_close_with_anim)
	_card.add_child(close_x)
	_wire_button_juice(close_x)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	bg_panel.add_child(vbox)

	var ad_mgr = get_tree().root.get_node_or_null("AdManager") if is_inside_tree() else null
	var is_no_ads: bool = forced_kind == "" and ad_mgr != null and "no_fill_this_launch" in ad_mgr and ad_mgr.no_fill_this_launch

	var gm = get_tree().root.get_node_or_null("GameManager") if is_inside_tree() else null
	var kind: String = forced_kind
	if kind == "":
		kind = gm.pick_random_support_popup() if gm != null and gm.has_method("pick_random_support_popup") else ["rate", "share", "coffee"][randi() % 3]

	var header_txt := "Rate Boy Favorite Collection!"
	var body_txt := "Love sneaking past Granny? A quick 5-star review on Google Play helps us add new levels & gadgets!"
	var cta_txt := "Rate 5 Stars ★"
	if kind == "share":
		header_txt = "Share With Friends!"
		body_txt = "Challenge your friends to sneak past Granny and beat your highest level!"
		cta_txt = "Share Game"
	elif kind == "coffee":
		header_txt = "Buy Me a Coffee"
		body_txt = "Support the indie developer building new rooms, gadgets, and updates!"
		cta_txt = "Buy Coffee  •  $1.99"

	var title := Label.new()
	title.text = "NO ADS TODAY — AD-FREE!" if is_no_ads else header_txt
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if game_title_font != null:
		title.add_theme_font_override("font", game_title_font)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color("#ffe885"))
	title.add_theme_color_override("font_outline_color", Color("#0a1824"))
	title.add_theme_constant_override("outline_size", 8)
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = ("Ads are off for this session! " + body_txt) if is_no_ads else body_txt
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if game_title_font != null:
		msg.add_theme_font_override("font", game_title_font)
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color("#e9f7ff"))
	msg.add_theme_color_override("font_outline_color", Color("#081520"))
	msg.add_theme_constant_override("outline_size", 5)
	vbox.add_child(msg)

	var action_btn := Button.new()
	action_btn.text = cta_txt
	action_btn.custom_minimum_size = Vector2(420, 74)
	_style_btn(action_btn, Color("#7ed321"), Color("#153309"))
	action_btn.pressed.connect(func():
		var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
		if sm != null and sm.has_method("play_sfx"):
			sm.play_sfx("button")
		if kind == "rate":
			if ad_mgr != null and ad_mgr.has_method("rate_app"):
				ad_mgr.rate_app()
			_close_with_anim()
		elif kind == "share":
			if ad_mgr != null and ad_mgr.has_method("share_game"):
				ad_mgr.share_game()
			if is_instance_valid(status_label):
				status_label.text = "Share link copied to clipboard!"
		else:
			if ad_mgr != null and ad_mgr.has_method("request_coffee_purchase"):
				ad_mgr.request_coffee_purchase()
	)
	var aw := CenterContainer.new()
	aw.add_child(action_btn)
	vbox.add_child(aw)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if game_title_font != null:
		status_label.add_theme_font_override("font", game_title_font)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color("#ffeaa7"))
	vbox.add_child(status_label)

	if ad_mgr != null and ad_mgr.has_signal("coffee_purchased"):
		ad_mgr.coffee_purchased.connect(func(m: String):
			if is_instance_valid(status_label):
				status_label.text = m
		)

	_card.scale = Vector2(0.42, 0.42)
	_card.modulate.a = 0.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_card, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(_card, "scale", Vector2(1.06, 0.95), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "scale", Vector2(0.98, 1.02), 0.09)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.08)

func _close_with_anim() -> void:
	var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
	if sm != null and sm.has_method("play_sfx"):
		sm.play_sfx("button")
	if is_instance_valid(_card):
		var tw := create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(_card, "scale", Vector2(1.05, 1.05), 0.06)
		tw.tween_property(_card, "scale", Vector2(0.35, 0.35), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_card, "modulate:a", 0.0, 0.14)
		tw.tween_callback(func():
			closed.emit()
			queue_free()
		)
	else:
		closed.emit()
		queue_free()

func _style_btn(btn: Button, bg: Color, border: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(3)
	s.border_width_bottom = 7
	s.set_corner_radius_all(18)
	var hv := s.duplicate() as StyleBoxFlat
	hv.bg_color = bg.lightened(0.10)
	btn.add_theme_stylebox_override("normal", s)
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", hv)
	if game_title_font != null:
		btn.add_theme_font_override("font", game_title_font)
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color("#19470b"))
	btn.add_theme_constant_override("outline_size", 6)
	_wire_button_juice(btn)

func _wire_button_juice(btn: Button) -> void:
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2(0.91, 0.91), 0.06)
	)
	btn.button_up.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.09)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08)
	)
