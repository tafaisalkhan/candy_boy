class_name SupportPopup
extends Control

signal closed

var game_title_font: Font = null
var game_body_font: Font = null
var status_label: Label = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
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

func _build_ui() -> void:
	name = "SupportPopup"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.04, 0.08, 0.85)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1e272e")
	style.border_color = Color("#00cec9")
	style.border_width_bottom = 10
	style.border_width_top = 4
	style.border_width_left = 4
	style.border_width_right = 4
	style.set_corner_radius_all(32)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	var ad_mgr = get_tree().root.get_node_or_null("AdManager") if is_inside_tree() else null
	var is_no_ads: bool = ad_mgr != null and "no_fill_this_launch" in ad_mgr and ad_mgr.no_fill_this_launch

	var title := Label.new()
	title.text = "🎉 NO ADS TODAY — AD-FREE!" if is_no_ads else "⭐ ENJOYING THE GAME?"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		title.add_theme_font_override("font", game_title_font)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color("#f1c40f"))
	vbox.add_child(title)

	var msg := Label.new()
	msg.text = "Ads are off for this session. Support Boy Favorite Collection!" if is_no_ads else "Rate us, share with friends, or buy the developer a coffee!"
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if game_body_font != null:
		msg.add_theme_font_override("font", game_body_font)
	msg.add_theme_font_size_override("font_size", 22)
	msg.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(msg)

	var choice := randi() % 3
	var action_btn := Button.new()
	action_btn.custom_minimum_size = Vector2(0, 68)
	if choice == 0:
		action_btn.text = "⭐ RATE GAME"
		_style_btn(action_btn, Color("#2ecc71"), Color("#1e824c"))
		action_btn.pressed.connect(func():
			if ad_mgr != null and ad_mgr.has_method("rate_app"):
				ad_mgr.rate_app()
			closed.emit()
			queue_free()
		)
	elif choice == 1:
		action_btn.text = "📤 SHARE GAME"
		_style_btn(action_btn, Color("#3498db"), Color("#1f618d"))
		action_btn.pressed.connect(func():
			if ad_mgr != null and ad_mgr.has_method("share_game"):
				ad_mgr.share_game()
			if is_instance_valid(status_label):
				status_label.text = "Share link copied to clipboard!"
		)
	else:
		action_btn.text = "☕ BUY COFFEE ($1.99)"
		_style_btn(action_btn, Color("#e67e22"), Color("#d35400"))
		action_btn.pressed.connect(func():
			if ad_mgr != null and ad_mgr.has_method("request_coffee_purchase"):
				ad_mgr.request_coffee_purchase()
		)
	vbox.add_child(action_btn)

	status_label = Label.new()
	status_label.text = ""
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if game_body_font != null:
		status_label.add_theme_font_override("font", game_body_font)
	status_label.add_theme_font_size_override("font_size", 18)
	status_label.add_theme_color_override("font_color", Color("#ffeaa7"))
	vbox.add_child(status_label)

	if ad_mgr != null and ad_mgr.has_signal("coffee_purchased"):
		ad_mgr.coffee_purchased.connect(func(m: String):
			if is_instance_valid(status_label):
				status_label.text = m
		)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(0, 54)
	_style_btn(close_btn, Color("#34495e"), Color("#1a252f"))
	close_btn.pressed.connect(func():
		closed.emit()
		queue_free()
	)
	vbox.add_child(close_btn)

func _style_btn(btn: Button, bg: Color, border: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_bottom = 6
	s.set_corner_radius_all(20)
	btn.add_theme_stylebox_override("normal", s)
	if game_title_font != null:
		btn.add_theme_font_override("font", game_title_font)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color.WHITE)
