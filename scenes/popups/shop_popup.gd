class_name ShopPopup
extends Control

signal closed

const PACK_ORDER := ["coins_1000", "coins_2000", "coins_3000"]

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
	name = "ShopPopup"
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
	card.custom_minimum_size = Vector2(640, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#1e272e")
	style.border_color = Color("#f39c12")
	style.border_width_bottom = 10
	style.border_width_top = 4
	style.border_width_left = 4
	style.border_width_right = 4
	style.set_corner_radius_all(32)
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 36)
	margin.add_theme_constant_override("margin_right", 36)
	margin.add_theme_constant_override("margin_top", 32)
	margin.add_theme_constant_override("margin_bottom", 32)
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "🛍️ COIN SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		title.add_theme_font_override("font", game_title_font)
	title.add_theme_font_size_override("font_size", 42)
	title.add_theme_color_override("font_color", Color("#f1c40f"))
	vbox.add_child(title)

	var ad_mgr = get_tree().root.get_node_or_null("AdManager") if is_inside_tree() else null
	for pack_id in PACK_ORDER:
		var info: Dictionary = ad_mgr.SHOP_PACKS[pack_id] if ad_mgr != null and "SHOP_PACKS" in ad_mgr else {"coins": 1000, "price": "$0.99", "title": pack_id}
		var btn := Button.new()
		btn.text = "🪙 %s  •  %s" % [str(info.get("title", pack_id)), str(info.get("price", ""))]
		btn.custom_minimum_size = Vector2(0, 72)
		_style_btn(btn, Color("#27ae60"), Color("#1e824c"))
		btn.pressed.connect(func():
			if ad_mgr != null and ad_mgr.has_method("request_pack_purchase"):
				ad_mgr.request_pack_purchase(pack_id)
		)
		vbox.add_child(btn)

	status_label = Label.new()
	status_label.text = "Google Play handles coin pack purchases."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if game_body_font != null:
		status_label.add_theme_font_override("font", game_body_font)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("#dfe6e9"))
	vbox.add_child(status_label)

	if ad_mgr != null and ad_mgr.has_signal("pack_purchase_verified"):
		ad_mgr.pack_purchase_verified.connect(func(_coins: int, msg: String):
			if is_instance_valid(status_label):
				status_label.text = msg
		)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(0, 62)
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
	btn.add_theme_font_size_override("font_size", 26)
	btn.add_theme_color_override("font_color", Color.WHITE)
