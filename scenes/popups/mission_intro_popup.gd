class_name MissionIntroPopup
extends Control

signal start_pressed

@export var title_text: String = "🎒 TAKE BACK YOUR ITEMS! 🎒"
@export var button_text: String = "START SNEAKING ▶"

var game_title_font: Font = null
var target_items_data: Array = []
var items_hbox: HBoxContainer = null

func _ready() -> void:
	_init_fonts()
	_build_ui()

func _init_fonts() -> void:
	if ResourceLoader.exists("res://assets/fonts/game_title.ttf"):
		game_title_font = load("res://assets/fonts/game_title.ttf") as Font
	elif ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf"):
		game_title_font = load("res://assets/fonts/LilitaOne-Regular.ttf") as Font

func setup(p_step1: String = "", _p_step2: String = "", _p_step3: String = "") -> void:
	if not p_step1.is_empty():
		title_text = p_step1

func set_target_items(items: Array) -> void:
	target_items_data = items
	_rebuild_item_cards()

func _rebuild_item_cards() -> void:
	if not is_instance_valid(items_hbox):
		return
	for c in items_hbox.get_children():
		c.queue_free()

	if target_items_data.is_empty():
		# Fallback item card if empty
		_add_single_item_card("🍭", "CANDY")
		return

	for it in target_items_data:
		var icon_str: String = it.get("icon", "🎁")
		var name_str: String = it.get("name", "ITEM").to_upper()
		_add_single_item_card(icon_str, name_str)

func _add_single_item_card(icon_str: String, _name_str: String) -> void:
	var item_card := PanelContainer.new()
	item_card.custom_minimum_size = Vector2(110, 110)
	var c_style := StyleBoxFlat.new()
	c_style.bg_color = Color(0.12, 0.17, 0.25, 0.95)
	c_style.border_color = Color("#f1c40f")
	c_style.set_border_width_all(4)
	c_style.set_corner_radius_all(20)
	c_style.shadow_color = Color(0, 0, 0, 0.45)
	c_style.shadow_size = 10
	item_card.add_theme_stylebox_override("panel", c_style)

	var c_vbox := VBoxContainer.new()
	c_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	item_card.add_child(c_vbox)

	var icon_lbl := Label.new()
	icon_lbl.text = icon_str
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	icon_lbl.add_theme_font_size_override("font_size", 60)
	c_vbox.add_child(icon_lbl)

	items_hbox.add_child(item_card)

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card := PanelContainer.new()
	card.name = "MissionCard"
	card.custom_minimum_size = Vector2(640, 360)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.pivot_offset = Vector2(320, 180)
	card.offset_left = -320
	card.offset_top = -240
	card.offset_right = 320
	card.offset_bottom = 120

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.12, 0.20, 0.95)
	card_style.border_color = Color("#f1c40f")
	card_style.set_border_width_all(6)
	card_style.set_corner_radius_all(28)
	card_style.shadow_color = Color(0, 0, 0, 0.6)
	card_style.shadow_size = 20
	card.add_theme_stylebox_override("panel", card_style)
	add_child(card)

	var v_box := VBoxContainer.new()
	v_box.alignment = BoxContainer.ALIGNMENT_CENTER
	v_box.add_theme_constant_override("separation", 16)
	card.add_child(v_box)

	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		title.add_theme_font_override("font", game_title_font)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color("#f1c40f"))
	title.add_theme_color_override("font_outline_color", Color("#2c3e50"))
	title.add_theme_constant_override("outline_size", 10)
	v_box.add_child(title)

	# Container for Target Item Cards (Only shown item image, no text descriptions)
	items_hbox = HBoxContainer.new()
	items_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	items_hbox.add_theme_constant_override("separation", 18)
	v_box.add_child(items_hbox)
	_rebuild_item_cards()

	var start_btn := Button.new()
	start_btn.text = button_text
	start_btn.custom_minimum_size = Vector2(320, 68)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = Color("#2ecc71")
	sb_style.border_color = Color("#1e824c")
	sb_style.border_width_bottom = 6
	sb_style.border_width_left = 3
	sb_style.border_width_right = 3
	sb_style.border_width_top = 2
	sb_style.set_corner_radius_all(20)
	start_btn.add_theme_stylebox_override("normal", sb_style)
	start_btn.add_theme_font_size_override("font_size", 26)
	if game_title_font != null:
		start_btn.add_theme_font_override("font", game_title_font)
	start_btn.pressed.connect(func():
		start_pressed.emit()
	)
	v_box.add_child(start_btn)

	card.scale = Vector2(0.8, 0.8)
	var tw := create_tween()
	tw.tween_property(card, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func dismiss() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(queue_free)
