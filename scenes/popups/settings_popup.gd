class_name SettingsPopup
extends Control

signal closed
signal privacy_policy_requested
signal main_menu_requested

var show_main_menu_button: bool = false

var game_title_font: Font = null
var game_body_font: Font = null
var sfx_btn: Button = null
var music_btn: Button = null
var remove_ads_btn: Button = null

var switch_music_knob: PanelContainer = null
var switch_music_bg: StyleBoxFlat = null
var switch_sfx_knob: PanelContainer = null
var switch_sfx_bg: StyleBoxFlat = null
var vip_status_lbl: Label = null
var tab_main_box: VBoxContainer = null
var tab_guide_box: VBoxContainer = null
var _card: Control = null

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

func _load_tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	var gp := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(gp):
		var im := Image.load_from_file(gp)
		if im != null and not im.is_empty():
			return ImageTexture.create_from_image(im)
	return null

func _build_ui() -> void:
	name = "SettingsPopup"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	# 1. Dark Backdrop Dimmer
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.05, 0.08, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card_size := Vector2(740, 820 if show_main_menu_button else 740)
	_card = Control.new()
	_card.name = "SettingsCard"
	_card.custom_minimum_size = card_size
	_card.size = card_size
	_card.pivot_offset = card_size * 0.5
	center.add_child(_card)

	var bg_panel := PanelContainer.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color("#184566")
	card_style.border_color = Color("#0b1d2c")
	card_style.set_border_width_all(6)
	card_style.border_width_bottom = 12
	card_style.set_corner_radius_all(24)
	card_style.content_margin_left = 32
	card_style.content_margin_right = 32
	card_style.content_margin_top = 28
	card_style.content_margin_bottom = 28
	bg_panel.add_theme_stylebox_override("panel", card_style)
	_card.add_child(bg_panel)

	# Left Side Tabs sticking out of the frame (⚙ Settings / 🎮 Controls)
	var side_tabs := VBoxContainer.new()
	side_tabs.position = Vector2(-64, 68)
	side_tabs.add_theme_constant_override("separation", 12)
	_card.add_child(side_tabs)

	var tab_gear := _side_tab_button(_load_tex("res://assets/ui/icons/icon-settings.png"), true, func():
		var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
		if sm != null and sm.has_method("play_sfx"):
			sm.play_sfx("button")
		tab_main_box.visible = true
		tab_guide_box.visible = false
	)
	side_tabs.add_child(tab_gear)

	var tab_pad := _side_tab_button(_load_tex("res://assets/ui/icons/icon-guide.png"), false, func():
		var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
		if sm != null and sm.has_method("play_sfx"):
			sm.play_sfx("button")
		tab_main_box.visible = false
		tab_guide_box.visible = true
	)
	side_tabs.add_child(tab_pad)

	# Red Square [✖] Close Button overlapping top-right corner
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

	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 18)
	bg_panel.add_child(body)

	var title_lbl := Label.new()
	title_lbl.text = "SETTINGS"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		title_lbl.add_theme_font_override("font", game_title_font)
	title_lbl.add_theme_font_size_override("font_size", 46)
	title_lbl.add_theme_color_override("font_color", Color.WHITE)
	title_lbl.add_theme_color_override("font_outline_color", Color("#0a1824"))
	title_lbl.add_theme_constant_override("outline_size", 10)
	body.add_child(title_lbl)

	# --- Main Settings Tab ---
	tab_main_box = VBoxContainer.new()
	tab_main_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_main_box.add_theme_constant_override("separation", 18)
	body.add_child(tab_main_box)

	var m_row := _toggle_switch_row("Music", _toggle_music)
	switch_music_knob = m_row.knob
	switch_music_bg = m_row.bg
	music_btn = m_row.track
	tab_main_box.add_child(m_row.row)

	var s_row := _toggle_switch_row("Sound FX", _toggle_sfx)
	switch_sfx_knob = s_row.knob
	switch_sfx_bg = s_row.bg
	sfx_btn = s_row.track
	tab_main_box.add_child(s_row.row)

	var btn_guide := _glossy_action_button("How to Play", _load_tex("res://assets/ui/icons/icon-guide.png"), Color("#19b5cc"), Vector2(0, 64))
	btn_guide.pressed.connect(func():
		var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
		if sm != null and sm.has_method("play_sfx"):
			sm.play_sfx("button")
		tab_main_box.visible = false
		tab_guide_box.visible = true
	)
	tab_main_box.add_child(btn_guide)

	var btn_privacy := _glossy_action_button("Privacy Policy", _load_tex("res://assets/ui/icons/icon-levels.png"), Color("#19b5cc"), Vector2(0, 64))
	btn_privacy.pressed.connect(func():
		var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
		if sm != null and sm.has_method("play_sfx"):
			sm.play_sfx("button")
		privacy_policy_requested.emit()
	)
	tab_main_box.add_child(btn_privacy)

	# Rate, Share & Coffee Row
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 14)
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_main_box.add_child(action_row)

	var rate_btn := _glossy_action_button("Rate ★", _load_tex("res://assets/ui/icons/icon-star.png"), Color("#22c55e"), Vector2(210, 62))
	rate_btn.pressed.connect(func():
		var ad_mgr = get_tree().root.get_node_or_null("AdManager")
		if ad_mgr != null and ad_mgr.has_method("rate_app"):
			ad_mgr.rate_app()
	)
	action_row.add_child(rate_btn)

	var share_btn := _glossy_action_button("Share", null, Color("#19b5cc"), Vector2(210, 62))
	share_btn.pressed.connect(func():
		var ad_mgr = get_tree().root.get_node_or_null("AdManager")
		if ad_mgr != null and ad_mgr.has_method("share_game"):
			ad_mgr.share_game()
	)
	action_row.add_child(share_btn)

	var coffee_btn := _glossy_action_button("Coffee $1.99", _load_tex("res://assets/ui/icons/icon-store.png"), Color("#f39c12"), Vector2(210, 62))
	coffee_btn.pressed.connect(func():
		var ad_mgr = get_tree().root.get_node_or_null("AdManager")
		if ad_mgr != null and ad_mgr.has_method("request_coffee_purchase"):
			ad_mgr.request_coffee_purchase()
	)
	action_row.add_child(coffee_btn)

	# Bottom Row: [ No Ads • $4.99 ] + [ VIP Status ]
	var bot_row := HBoxContainer.new()
	bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	bot_row.add_theme_constant_override("separation", 18)
	tab_main_box.add_child(bot_row)

	remove_ads_btn = _glossy_action_button("No Ads  •  $4.99", _load_tex("res://assets/ui/icons/icon-store.png"), Color("#e8edf2"), Vector2(320, 64), Color("#162936"))
	remove_ads_btn.pressed.connect(_on_remove_ads_pressed)
	bot_row.add_child(remove_ads_btn)

	var vip_pill := PanelContainer.new()
	vip_pill.custom_minimum_size = Vector2(310, 64)
	var vs := StyleBoxFlat.new()
	vs.bg_color = Color("#d8e3ec")
	vs.border_color = Color("#162936")
	vs.set_border_width_all(3)
	vs.set_corner_radius_all(14)
	vs.content_margin_left = 14
	vs.content_margin_right = 14
	vip_pill.add_theme_stylebox_override("panel", vs)
	vip_status_lbl = Label.new()
	vip_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vip_status_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if game_title_font != null:
		vip_status_lbl.add_theme_font_override("font", game_title_font)
	vip_status_lbl.add_theme_font_size_override("font_size", 20)
	vip_status_lbl.add_theme_color_override("font_color", Color("#162936"))
	vip_pill.add_child(vip_status_lbl)
	bot_row.add_child(vip_pill)

	if show_main_menu_button:
		var menu_row := HBoxContainer.new()
		menu_row.alignment = BoxContainer.ALIGNMENT_CENTER
		menu_row.add_theme_constant_override("separation", 16)
		tab_main_box.add_child(menu_row)

		var resume_btn := _glossy_action_button("▶  RESUME", null, Color("#7ed321"), Vector2(320, 68))
		resume_btn.pressed.connect(_close_with_anim)
		menu_row.add_child(resume_btn)

		var menu_btn := _glossy_action_button("MAIN MENU", null, Color("#19b5cc"), Vector2(320, 68))
		menu_btn.pressed.connect(func():
			var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
			if sm != null and sm.has_method("play_sfx"):
				sm.play_sfx("button")
			main_menu_requested.emit()
			queue_free()
		)
		menu_row.add_child(menu_btn)

	# --- Controls / How to Play Tab ---
	tab_guide_box = VBoxContainer.new()
	tab_guide_box.visible = false
	tab_guide_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tab_guide_box.add_theme_constant_override("separation", 18)
	body.add_child(tab_guide_box)

	for tip in [
		"• DRAG anywhere on the lower screen to sneak around Granny's house.",
		"• OPEN cabinets & collect all target items shown in the top FIND bar.",
		"• Grab the GOLDEN KEY to unlock locked cabinets and doors.",
		"• Use SPEED, INVISIBILITY, and BYPASS WALL power-ups to escape Granny!",
		"• Reach the EXIT DOOR once all items are collected to win +20 Coins!",
	]:
		var tl := Label.new()
		tl.text = tip
		tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if game_title_font != null:
			tl.add_theme_font_override("font", game_title_font)
		tl.add_theme_font_size_override("font_size", 24)
		tl.add_theme_color_override("font_color", Color("#e9f7ff"))
		tl.add_theme_color_override("font_outline_color", Color("#0a1824"))
		tl.add_theme_constant_override("outline_size", 6)
		tab_guide_box.add_child(tl)

	var back_btn := _glossy_action_button("Back to Settings", null, Color("#7ed321"), Vector2(0, 64))
	back_btn.pressed.connect(func():
		var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
		if sm != null and sm.has_method("play_sfx"):
			sm.play_sfx("button")
		tab_guide_box.visible = false
		tab_main_box.visible = true
	)
	tab_guide_box.add_child(back_btn)

	_refresh_switches()

	# Squash-and-stretch entrance animation (pause-safe)
	_card.scale = Vector2(0.42, 0.42)
	_card.modulate.a = 0.0
	var pop_tw := create_tween()
	pop_tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pop_tw.tween_property(_card, "modulate:a", 1.0, 0.12)
	pop_tw.parallel().tween_property(_card, "scale", Vector2(1.06, 0.95), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pop_tw.tween_property(_card, "scale", Vector2(0.98, 1.02), 0.09)
	pop_tw.tween_property(_card, "scale", Vector2.ONE, 0.08)

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

func _toggle_switch_row(label_text: String, on_toggle: Callable) -> Dictionary:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if game_title_font != null:
		lbl.add_theme_font_override("font", game_title_font)
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_color_override("font_outline_color", Color("#0c1c26"))
	lbl.add_theme_constant_override("outline_size", 7)
	row.add_child(lbl)

	var track := Button.new()
	track.custom_minimum_size = Vector2(96, 46)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color("#38c159")
	bg.border_color = Color("#0c1c26")
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(23)
	track.add_theme_stylebox_override("normal", bg)
	track.add_theme_stylebox_override("hover", bg)
	track.add_theme_stylebox_override("pressed", bg)
	track.pressed.connect(on_toggle)
	row.add_child(track)

	var knob := PanelContainer.new()
	knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	knob.size = Vector2(36, 36)
	knob.position = Vector2(54, 5)
	var ks := StyleBoxFlat.new()
	ks.bg_color = Color.WHITE
	ks.border_color = Color("#0c1c26")
	ks.set_border_width_all(2)
	ks.set_corner_radius_all(18)
	knob.add_theme_stylebox_override("panel", ks)
	track.add_child(knob)
	return {"row": row, "knob": knob, "bg": bg, "track": track}

func _set_switch_visual(knob: PanelContainer, bg: StyleBoxFlat, is_on: bool) -> void:
	if not is_instance_valid(knob) or bg == null:
		return
	bg.bg_color = Color("#38c159") if is_on else Color("#4a5d6b")
	var tw := knob.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(knob, "position:x", 54.0 if is_on else 6.0, 0.12).set_trans(Tween.TRANS_QUAD)

func _refresh_switches() -> void:
	var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
	var sfx_on: bool = sm.sfx_enabled if sm != null else true
	var music_on: bool = sm.music_enabled if sm != null else true
	_set_switch_visual(switch_music_knob, switch_music_bg, music_on)
	_set_switch_visual(switch_sfx_knob, switch_sfx_bg, sfx_on)
	_update_remove_ads_button()

func _toggle_sfx() -> void:
	var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
	var gm = get_tree().root.get_node_or_null("GameManager") if is_inside_tree() else null
	var new_sfx: bool = not (sm.sfx_enabled if sm != null else true)
	if sm != null:
		sm.set_sfx_enabled(new_sfx)
		sm.play_sfx("button")
	if gm != null:
		gm.set_audio_settings(sm.music_enabled if sm != null else true, new_sfx)
	_refresh_switches()

func _toggle_music() -> void:
	var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
	var gm = get_tree().root.get_node_or_null("GameManager") if is_inside_tree() else null
	var new_music: bool = not (sm.music_enabled if sm != null else true)
	if sm != null:
		sm.set_music_enabled(new_music)
		sm.play_sfx("button")
	if gm != null:
		gm.set_audio_settings(new_music, sm.sfx_enabled if sm != null else true)
	_refresh_switches()

func _on_remove_ads_pressed() -> void:
	var gm = get_tree().root.get_node_or_null("GameManager") if is_inside_tree() else null
	var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
	if gm != null and gm.is_ads_removed:
		return
	var ad_mgr = get_tree().root.get_node_or_null("AdManager") if is_inside_tree() else null
	if ad_mgr != null and ad_mgr.has_method("request_remove_ads"):
		ad_mgr.request_remove_ads()
	if gm != null:
		gm.set_ads_removed(true)
	if ad_mgr != null and ad_mgr.has_method("remove_all_ads"):
		ad_mgr.remove_all_ads()
	if sm != null:
		sm.play_sfx("coin")
	_update_remove_ads_button()

func _update_remove_ads_button() -> void:
	var gm = get_tree().root.get_node_or_null("GameManager") if is_inside_tree() else null
	var is_removed: bool = gm.is_ads_removed if gm != null else false
	if is_instance_valid(remove_ads_btn):
		remove_ads_btn.text = "  Ad-Free Active ✓" if is_removed else "  No Ads  •  $4.99"
		remove_ads_btn.disabled = is_removed
	if is_instance_valid(vip_status_lbl):
		vip_status_lbl.text = "VIP Status:\n" + ("Ad-Free Active" if is_removed else "Standard Player")

func _side_tab_button(icon_tex: Texture2D, active: bool, on_press: Callable) -> Button:
	var btn := Button.new()
	if icon_tex != null:
		btn.icon = icon_tex
		btn.expand_icon = true
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		btn.add_theme_constant_override("icon_max_width", 34)
	btn.custom_minimum_size = Vector2(68, 64)
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#184566") if active else Color("#0f2c42")
	st.border_color = Color("#0b1d2c")
	st.set_border_width_all(4)
	st.border_width_right = 0
	st.corner_radius_top_left = 14
	st.corner_radius_bottom_left = 14
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.pressed.connect(on_press)
	_wire_button_juice(btn)
	return btn

func _glossy_action_button(text: String, icon_tex: Texture2D, bg_col: Color, sz: Vector2, text_col: Color = Color.WHITE) -> Button:
	var btn := Button.new()
	btn.text = "  " + text
	if icon_tex != null:
		btn.icon = icon_tex
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 28)
	btn.custom_minimum_size = sz
	if game_title_font != null:
		btn.add_theme_font_override("font", game_title_font)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", text_col)
	if text_col == Color.WHITE:
		btn.add_theme_color_override("font_outline_color", Color("#0b2533"))
		btn.add_theme_constant_override("outline_size", 6)
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = Color("#0c1c26")
	st.set_border_width_all(3)
	st.border_width_bottom = 7
	st.set_corner_radius_all(16)
	st.content_margin_left = 16
	st.content_margin_right = 16
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = bg_col.lightened(0.10)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", hv)
	_wire_button_juice(btn)
	return btn

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
