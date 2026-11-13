class_name MissionIntroPopup
extends Control

signal start_pressed

@export var title_text: String = "🎯 MISSION OBJECTIVE 🎯"
@export var step1_text: String = "🚪 1. FIND & OPEN THE CABINETS WITH TARGET ITEMS"
@export var step2_text: String = "👵 2. DODGE GRANNY! SNEAK AROUND HER VISION CONE"
@export var step3_text: String = "🚪 3. ESCAPE THROUGH THE SOUTH EXIT DOOR TO WIN!"
@export var button_text: String = "START SNEAKING 🚀"

var game_title_font: Font = null

func _ready() -> void:
	_init_fonts()
	_build_ui()

func _init_fonts() -> void:
	if ResourceLoader.exists("res://assets/fonts/game_title.ttf"):
		game_title_font = load("res://assets/fonts/game_title.ttf") as Font
	elif ResourceLoader.exists("res://assets/fonts/LilitaOne-Regular.ttf"):
		game_title_font = load("res://assets/fonts/LilitaOne-Regular.ttf") as Font

func setup(p_step1: String = "", p_step2: String = "", p_step3: String = "") -> void:
	if not p_step1.is_empty():
		step1_text = p_step1
	if not p_step2.is_empty():
		step2_text = p_step2
	if not p_step3.is_empty():
		step3_text = p_step3

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var card := PanelContainer.new()
	card.name = "MissionCard"
	card.custom_minimum_size = Vector2(760, 370)
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.pivot_offset = Vector2(380, 185)
	card.offset_left = -380
	card.offset_top = -290
	card.offset_right = 380
	card.offset_bottom = 80

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
	v_box.add_theme_constant_override("separation", 12)
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

	var s1 := Label.new()
	s1.text = step1_text
	s1.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		s1.add_theme_font_override("font", game_title_font)
	s1.add_theme_font_size_override("font_size", 19)
	s1.add_theme_color_override("font_color", Color.WHITE)
	s1.add_theme_color_override("font_outline_color", Color.BLACK)
	s1.add_theme_constant_override("outline_size", 5)
	v_box.add_child(s1)

	var s2 := Label.new()
	s2.text = step2_text
	s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		s2.add_theme_font_override("font", game_title_font)
	s2.add_theme_font_size_override("font_size", 19)
	s2.add_theme_color_override("font_color", Color("#fab1a0"))
	s2.add_theme_color_override("font_outline_color", Color.BLACK)
	s2.add_theme_constant_override("outline_size", 5)
	v_box.add_child(s2)

	var s3 := Label.new()
	s3.text = step3_text
	s3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		s3.add_theme_font_override("font", game_title_font)
	s3.add_theme_font_size_override("font_size", 19)
	s3.add_theme_color_override("font_color", Color("#2ecc71"))
	s3.add_theme_color_override("font_outline_color", Color.BLACK)
	s3.add_theme_constant_override("outline_size", 5)
	v_box.add_child(s3)

	var start_btn := Button.new()
	start_btn.text = button_text
	start_btn.custom_minimum_size = Vector2(300, 60)
	start_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	var sb_style := StyleBoxFlat.new()
	sb_style.bg_color = Color("#2ecc71")
	sb_style.border_color = Color("#1e824c")
	sb_style.border_width_bottom = 6
	sb_style.border_width_left = 3
	sb_style.border_width_right = 3
	sb_style.border_width_top = 2
	sb_style.set_corner_radius_all(18)
	start_btn.add_theme_stylebox_override("normal", sb_style)
	start_btn.add_theme_font_size_override("font_size", 22)
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
