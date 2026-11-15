class_name GameHUD
extends CanvasLayer

signal powerup_clicked(powerup_id: String)
signal joystick_moved(direction: Vector2)
signal joystick_released()
signal replay_requested()
signal next_level_requested()
signal retry_requested()

const POWERUP_COIN_COST: int = 10
const SPEED_UNLOCK_LEVEL: int = 1
const INVIS_UNLOCK_LEVEL: int = 5
const BYPASS_WALL_UNLOCK_LEVEL: int = 10

var game_title_font: Font = null
var game_body_font: Font = null

var level_lbl: Label = null
var obj_lbl: Label = null
var coin_panel: PanelContainer = null
var coin_lbl: Label = null
var item_collector_panel: PanelContainer = null
var item_collector_label: Label = null
var item_slot_panels: Array[Panel] = []
var item_slot_badges: Array[Label] = []

var speed_btn_refs: Dictionary = {}
var shield_btn_refs: Dictionary = {}
var ghost_btn_refs: Dictionary = {}

var joystick_base: Panel = null
var joystick_knob: Panel = null
var joystick_touch_id: int = -1
var joystick_center: Vector2 = Vector2.ZERO
const JOYSTICK_MAX_DIST: float = 60.0

var victory_popup: Control = null
var fail_popup: Control = null


func _ready() -> void:
	if SignalHub != null:
		SignalHub.coins_changed.connect(_on_coins_changed)
		SignalHub.level_failed.connect(func(lvl, reason): show_fail_popup(reason))


func setup(level_num: int, target_items: Array, current_coins: int, title_font: Font = null, body_font: Font = null) -> void:
	game_title_font = title_font
	game_body_font = body_font

	# Clean any existing elements
	for c in get_children():
		c.queue_free()

	# 1. Level label (Consistent, Compact Scale)
	level_lbl = Label.new()
	level_lbl.name = "LevelLabel"
	level_lbl.text = "LEVEL\n%d" % level_num
	level_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	level_lbl.offset_top = 18.0
	level_lbl.offset_bottom = 85.0
	level_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		level_lbl.add_theme_font_override("font", game_title_font)
	level_lbl.add_theme_font_size_override("font_size", 32)
	level_lbl.add_theme_color_override("font_color", Color.WHITE)
	level_lbl.add_theme_color_override("font_outline_color", Color("#2c3e50"))
	level_lbl.add_theme_constant_override("outline_size", 9)
	add_child(level_lbl)

	# Objective Sub-Label
	obj_lbl = Label.new()
	obj_lbl.name = "ObjectiveLabel"
	obj_lbl.text = "SNEAK IN & GET THE CANDY!"
	obj_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	obj_lbl.offset_top = 82.0
	obj_lbl.offset_bottom = 110.0
	obj_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		obj_lbl.add_theme_font_override("font", game_title_font)
	obj_lbl.add_theme_font_size_override("font_size", 15)
	obj_lbl.add_theme_color_override("font_color", Color("#ffeaa7"))
	obj_lbl.add_theme_color_override("font_outline_color", Color("#2d3436"))
	obj_lbl.add_theme_constant_override("outline_size", 5)
	add_child(obj_lbl)

	# 2. Coin Pill (Compact & Consistent)
	coin_panel = PanelContainer.new()
	coin_panel.name = "CoinPanel"
	coin_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	coin_panel.offset_left = -175.0
	coin_panel.offset_top = 22.0
	coin_panel.offset_right = -25.0
	coin_panel.offset_bottom = 70.0
	coin_panel.pivot_offset = Vector2(75.0, 24.0)

	var pill_style := StyleBoxFlat.new()
	pill_style.bg_color = Color.WHITE
	pill_style.set_corner_radius_all(24)
	pill_style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	pill_style.shadow_size = 4
	coin_panel.add_theme_stylebox_override("panel", pill_style)
	add_child(coin_panel)

	var coin_box := HBoxContainer.new()
	coin_box.alignment = BoxContainer.ALIGNMENT_CENTER
	coin_panel.add_child(coin_box)

	var coin_icon := TextureRect.new()
	coin_icon.texture = load("res://assets/ui/reward-coin.png") as Texture2D
	coin_icon.custom_minimum_size = Vector2(26, 26)
	coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin_box.add_child(coin_icon)

	coin_lbl = Label.new()
	coin_lbl.text = " %d" % current_coins
	if game_title_font != null:
		coin_lbl.add_theme_font_override("font", game_title_font)
	coin_lbl.add_theme_font_size_override("font_size", 20)
	coin_lbl.add_theme_color_override("font_color", Color("#2d3436"))
	coin_box.add_child(coin_lbl)

	# 3. Item Collector Panel (Compact & Consistent)
	item_collector_panel = PanelContainer.new()
	item_collector_panel.name = "ItemCollectorPanel"
	item_collector_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	item_collector_panel.offset_left = 25.0
	item_collector_panel.offset_top = 22.0
	item_collector_panel.offset_right = 210.0
	item_collector_panel.offset_bottom = 90.0

	var ic_style := StyleBoxFlat.new()
	ic_style.bg_color = Color(0.12, 0.16, 0.24, 0.92)
	ic_style.set_corner_radius_all(16)
	ic_style.border_color = Color("#0984e3")
	ic_style.set_border_width_all(2)
	ic_style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
	ic_style.shadow_size = 5
	item_collector_panel.add_theme_stylebox_override("panel", ic_style)
	add_child(item_collector_panel)

	var ic_margin := MarginContainer.new()
	ic_margin.add_theme_constant_override("margin_left", 10)
	ic_margin.add_theme_constant_override("margin_top", 6)
	ic_margin.add_theme_constant_override("margin_right", 10)
	ic_margin.add_theme_constant_override("margin_bottom", 6)
	item_collector_panel.add_child(ic_margin)

	var ic_vbox := VBoxContainer.new()
	ic_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ic_vbox.add_theme_constant_override("separation", 4)
	ic_margin.add_child(ic_vbox)

	item_collector_label = Label.new()
	item_collector_label.text = "🎒 ITEMS TO FIND: 0 / %d" % target_items.size()
	item_collector_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		item_collector_label.add_theme_font_override("font", game_title_font)
	item_collector_label.add_theme_font_size_override("font_size", 13)
	item_collector_label.add_theme_color_override("font_color", Color("#ffeaa7"))
	item_collector_label.add_theme_color_override("font_outline_color", Color("#2d3436"))
	item_collector_label.add_theme_constant_override("outline_size", 4)
	ic_vbox.add_child(item_collector_label)

	var ic_slots_hbox := HBoxContainer.new()
	ic_slots_hbox.name = "SlotsHBox"
	ic_slots_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	ic_slots_hbox.add_theme_constant_override("separation", 8)
	ic_vbox.add_child(ic_slots_hbox)

	item_slot_panels.clear()
	item_slot_badges.clear()
	for i in range(target_items.size()):
		var it = target_items[i]
		var slot_p := Panel.new()
		slot_p.custom_minimum_size = Vector2(36, 36)
		slot_p.size = Vector2(36, 36)
		var sp_style := StyleBoxFlat.new()
		sp_style.bg_color = Color(0.18, 0.22, 0.32, 0.85)
		sp_style.border_color = Color("#74b9ff")
		sp_style.set_border_width_all(2)
		sp_style.set_corner_radius_all(10)
		slot_p.add_theme_stylebox_override("panel", sp_style)
		ic_slots_hbox.add_child(slot_p)
		item_slot_panels.append(slot_p)

		var slot_icon := Label.new()
		slot_icon.text = str(it.get("icon", "🎁"))
		slot_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
		slot_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_icon.add_theme_font_size_override("font_size", 18)
		slot_p.add_child(slot_icon)

		var check_badge := Label.new()
		check_badge.text = "✓"
		check_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		check_badge.offset_left = -16.0
		check_badge.offset_top = -6.0
		check_badge.offset_right = 6.0
		check_badge.offset_bottom = 16.0
		check_badge.add_theme_font_size_override("font_size", 12)
		check_badge.add_theme_color_override("font_color", Color("#2ecc71"))
		check_badge.visible = false
		slot_p.add_child(check_badge)
		item_slot_badges.append(check_badge)

	# 4. Powerup Tray (Consistent, Proportionate Dock)
	var tray := PanelContainer.new()
	tray.name = "PowerupTray"
	tray.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	tray.offset_left = -260.0
	tray.offset_right = 260.0
	tray.offset_top = -118.0
	tray.offset_bottom = -20.0

	var tray_style := StyleBoxFlat.new()
	tray_style.bg_color = Color(0.04, 0.45, 0.78, 0.90)
	tray_style.set_corner_radius_all(22)
	tray_style.border_color = Color("#74b9ff")
	tray_style.set_border_width_all(3)
	tray_style.shadow_color = Color(0, 0, 0, 0.25)
	tray_style.shadow_size = 6
	tray.add_theme_stylebox_override("panel", tray_style)
	add_child(tray)

	var tray_box := HBoxContainer.new()
	tray_box.alignment = BoxContainer.ALIGNMENT_CENTER
	tray_box.add_theme_constant_override("separation", 14)
	tray.add_child(tray_box)

	_add_powerup_button(tray_box, "speed", "res://assets/ui/powerup_speed_lightning.svg", "SPEED", "🪙 %d" % POWERUP_COIN_COST, Color("#f39c12"), speed_btn_refs)
	_add_powerup_button(tray_box, "invisible", "res://assets/ui/powerup_invis_white_ball.svg", "INVISIBLE", "🪙 %d" % POWERUP_COIN_COST, Color("#3498db"), shield_btn_refs)
	_add_powerup_button(tray_box, "bypass_wall", "res://assets/ui/powerup_bypass_wall.svg", "BYPASS WALL", "🪙 %d" % POWERUP_COIN_COST, Color("#9b59b6"), ghost_btn_refs)

	update_powerup_locks(level_num)

	# 5. Mobile Virtual Joystick
	joystick_base = Panel.new()
	joystick_base.name = "MobileJoystickBase"
	joystick_base.custom_minimum_size = Vector2(130, 130)
	joystick_base.size = Vector2(130, 130)
	joystick_base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var jb_style := StyleBoxFlat.new()
	jb_style.bg_color = Color(0.12, 0.16, 0.24, 0.45)
	jb_style.border_color = Color(1.0, 1.0, 1.0, 0.6)
	jb_style.set_border_width_all(3)
	jb_style.set_corner_radius_all(65)
	joystick_base.add_theme_stylebox_override("panel", jb_style)
	joystick_base.visible = false
	add_child(joystick_base)

	joystick_knob = Panel.new()
	joystick_knob.name = "MobileJoystickKnob"
	joystick_knob.custom_minimum_size = Vector2(58, 58)
	joystick_knob.size = Vector2(58, 58)
	joystick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var jk_style := StyleBoxFlat.new()
	jk_style.bg_color = Color("#00cec9")
	jk_style.border_color = Color.WHITE
	jk_style.set_border_width_all(3)
	jk_style.set_corner_radius_all(29)
	jk_style.shadow_color = Color(0, 0, 0, 0.3)
	jk_style.shadow_size = 6
	joystick_knob.add_theme_stylebox_override("panel", jk_style)
	joystick_knob.position = Vector2(36, 36)
	joystick_base.add_child(joystick_knob)


func _add_powerup_button(parent: HBoxContainer, powerup_id: String, svg_path: String, powerup_title: String, badge_text: String, badge_col: Color, out_refs: Dictionary) -> void:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(150, 86)
	btn.flat = true
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	parent.add_child(btn)

	var icon := TextureRect.new()
	icon.texture = _load_texture(svg_path)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 12.0
	icon.offset_top = 2.0
	icon.offset_right = -12.0
	icon.offset_bottom = -24.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(icon)

	var lock_overlay := TextureRect.new()
	lock_overlay.texture = _load_texture("res://assets/ui/powerup_lock_overlay.svg")
	lock_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lock_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lock_overlay.custom_minimum_size = Vector2(34, 34)
	lock_overlay.size = Vector2(34, 34)
	lock_overlay.position = Vector2(58, 8)
	lock_overlay.visible = false
	lock_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lock_overlay)

	var title_lbl := Label.new()
	title_lbl.text = powerup_title
	title_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	title_lbl.offset_top = -22.0
	title_lbl.offset_bottom = 0.0
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		title_lbl.add_theme_font_override("font", game_title_font)
	title_lbl.add_theme_font_size_override("font_size", 13)
	title_lbl.add_theme_color_override("font_color", Color("#ffeaa7"))
	title_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	title_lbl.add_theme_constant_override("outline_size", 3)
	title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(title_lbl)

	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(48, 18)
	badge.size = Vector2(48, 18)
	badge.position = Vector2(96, 4)
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = badge_col
	b_style.set_corner_radius_all(9)
	b_style.border_color = Color.WHITE
	b_style.set_border_width_all(1)
	badge.add_theme_stylebox_override("panel", b_style)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(badge)

	var b_lbl := Label.new()
	b_lbl.text = badge_text
	b_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	b_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if game_title_font != null:
		b_lbl.add_theme_font_override("font", game_title_font)
	b_lbl.add_theme_font_size_override("font_size", 11)
	b_lbl.add_theme_color_override("font_color", Color.WHITE)
	b_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	b_lbl.add_theme_constant_override("outline_size", 2)
	b_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(b_lbl)
	badge.add_child(b_lbl)

	out_refs["icon"] = icon
	out_refs["lock"] = lock_overlay
	out_refs["title"] = title_lbl
	out_refs["badge_style"] = b_style
	out_refs["badge_lbl"] = b_lbl
	out_refs["unlocked_col"] = badge_col

	btn.pressed.connect(func():
		powerup_clicked.emit(powerup_id)
		if SignalHub != null:
			SignalHub.emit_powerup_activated(powerup_id, 5.0)
	)


func update_powerup_locks(current_level: int) -> void:
	var speed_locked := not GameManager.is_powerup_unlocked("speed", current_level) if GameManager != null else (current_level < SPEED_UNLOCK_LEVEL)
	var invis_locked := not GameManager.is_powerup_unlocked("invisible", current_level) if GameManager != null else (current_level < INVIS_UNLOCK_LEVEL)
	var wall_locked := not GameManager.is_powerup_unlocked("bypass_wall", current_level) if GameManager != null else (current_level < BYPASS_WALL_UNLOCK_LEVEL)

	_apply_lock(speed_btn_refs, speed_locked, SPEED_UNLOCK_LEVEL)
	_apply_lock(shield_btn_refs, invis_locked, INVIS_UNLOCK_LEVEL)
	_apply_lock(ghost_btn_refs, wall_locked, BYPASS_WALL_UNLOCK_LEVEL)


func _apply_lock(refs: Dictionary, is_locked: bool, unlock_lvl: int) -> void:
	if refs.is_empty():
		return
	var icon_rect: TextureRect = refs.get("icon")
	var lock_rect: TextureRect = refs.get("lock")
	var title_lbl: Label = refs.get("title")
	var b_style: StyleBoxFlat = refs.get("badge_style")
	var b_lbl: Label = refs.get("badge_lbl")
	var unlocked_col: Color = refs.get("unlocked_col", Color("#f39c12"))

	if is_instance_valid(icon_rect):
		icon_rect.modulate = Color(0.38, 0.42, 0.48, 0.68) if is_locked else Color.WHITE
	if is_instance_valid(lock_rect):
		lock_rect.visible = is_locked
	if is_instance_valid(title_lbl):
		title_lbl.add_theme_color_override("font_color", Color("#b2bec3") if is_locked else Color("#ffeaa7"))
	if b_style != null:
		b_style.bg_color = Color("#636e72") if is_locked else unlocked_col
	if is_instance_valid(b_lbl):
		b_lbl.text = ("🔒 LV %d" % unlock_lvl) if is_locked else ("🪙 %d" % POWERUP_COIN_COST)


func update_objective(text: String) -> void:
	if is_instance_valid(obj_lbl):
		obj_lbl.text = text


func update_coins(new_coins: int) -> void:
	if is_instance_valid(coin_lbl):
		coin_lbl.text = " %d" % new_coins
	if is_instance_valid(coin_panel):
		var tw := create_tween()
		tw.tween_property(coin_panel, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(coin_panel, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)


func _on_coins_changed(new_coins: int) -> void:
	update_coins(new_coins)


func mark_item_collected(slot_index: int, collected_count: int, total_count: int) -> void:
	if slot_index >= 0 and slot_index < item_slot_badges.size():
		var b := item_slot_badges[slot_index]
		if is_instance_valid(b):
			b.visible = true
	if is_instance_valid(item_collector_label):
		item_collector_label.text = "🎒 ITEMS TO FIND: %d / %d" % [collected_count, total_count]
		if collected_count >= total_count:
			item_collector_label.text = "🎒 ALL ITEMS COLLECTED! 🚪 ESCAPE!"
			item_collector_label.add_theme_color_override("font_color", Color("#2ecc71"))


func show_toast(text: String) -> void:
	var toast := Label.new()
	toast.text = text
	toast.set_anchors_preset(Control.PRESET_CENTER)
	toast.offset_left = -300
	toast.offset_top = -260
	toast.offset_right = 300
	toast.offset_bottom = -200
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		toast.add_theme_font_override("font", game_title_font)
	toast.add_theme_font_size_override("font_size", 34)
	toast.add_theme_color_override("font_color", Color("#f1c40f"))
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.add_theme_constant_override("outline_size", 10)
	toast.pivot_offset = Vector2(300, 30)
	add_child(toast)

	var tw := create_tween()
	tw.tween_property(toast, "scale", Vector2(1.2, 1.2), 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(toast, "position:y", toast.position.y - 45.0, 0.7)
	tw.chain().tween_property(toast, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(toast.queue_free)


func show_victory_popup(level_num: int) -> void:
	if is_instance_valid(victory_popup):
		return
	var scene := load("res://scenes/popups/victory_popup.tscn") as PackedScene
	if scene != null:
		victory_popup = scene.instantiate()
		victory_popup.setup(level_num, 20)
		victory_popup.continue_pressed.connect(func():
			next_level_requested.emit()
		)
		add_child(victory_popup)


func show_fail_popup(reason: String) -> void:
	if is_instance_valid(fail_popup):
		return
	var scene := load("res://scenes/popups/fail_popup.tscn") as PackedScene
	if scene != null:
		fail_popup = scene.instantiate()
		fail_popup.setup(reason)
		fail_popup.retry_pressed.connect(func():
			retry_requested.emit()
		)
		add_child(fail_popup)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and joystick_touch_id == -1:
			var vp_size := get_viewport().get_visible_rect().size
			if st.position.y > vp_size.y * 0.45:
				joystick_touch_id = st.index
				joystick_center = st.position
				if is_instance_valid(joystick_base):
					joystick_base.position = joystick_center - joystick_base.size * 0.5
					joystick_base.visible = true
				if is_instance_valid(joystick_knob):
					joystick_knob.position = (joystick_base.size - joystick_knob.size) * 0.5
		elif not st.pressed and st.index == joystick_touch_id:
			_release_joystick()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == joystick_touch_id:
			_update_joystick(sd.position)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and joystick_touch_id == -1:
				var vp_size := get_viewport().get_visible_rect().size
				if mb.position.y > vp_size.y * 0.45:
					joystick_touch_id = 999
					joystick_center = mb.position
					if is_instance_valid(joystick_base):
						joystick_base.position = joystick_center - joystick_base.size * 0.5
						joystick_base.visible = true
					if is_instance_valid(joystick_knob):
						joystick_knob.position = (joystick_base.size - joystick_knob.size) * 0.5
			elif not mb.pressed and joystick_touch_id == 999:
				_release_joystick()
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if joystick_touch_id == 999:
			_update_joystick(mm.position)


func _update_joystick(touch_pos: Vector2) -> void:
	var delta := touch_pos - joystick_center
	var dist := delta.length()
	if dist > JOYSTICK_MAX_DIST:
		delta = delta.normalized() * JOYSTICK_MAX_DIST
	if is_instance_valid(joystick_knob) and is_instance_valid(joystick_base):
		joystick_knob.position = (joystick_base.size - joystick_knob.size) * 0.5 + delta
	var norm_dir := delta / JOYSTICK_MAX_DIST
	joystick_moved.emit(norm_dir)


func _release_joystick() -> void:
	joystick_touch_id = -1
	if is_instance_valid(joystick_base):
		joystick_base.visible = false
	if is_instance_valid(joystick_knob):
		joystick_knob.position = (joystick_base.size - joystick_knob.size) * 0.5
	joystick_released.emit()


func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null
