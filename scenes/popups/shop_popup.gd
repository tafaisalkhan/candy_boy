class_name ShopPopup
extends Control

signal closed

const PACK_ORDER := ["coins_1000", "coins_2000", "coins_3000"]
const UPGRADE_SPECS := [
	["sneakers", "Turbo Sneakers", "+15% permanent sneaking speed", "res://assets/ui/powerup_speed_lightning.svg"],
	["cloak", "Ghost Cloak", "+1.5s extra Invisibility duration", "res://assets/ui/powerup_invis_white_ball.svg"],
	["wall_battery", "Phase Battery", "+1.5s extra Bypass Wall duration", "res://assets/ui/powerup_bypass_wall.svg"],
	["piggy_bank", "Lucky Piggy Bank", "+5 bonus coins on every level win", "res://assets/ui/reward-coin.png"],
]

var initial_tab: String = "store"
var current_tab: String = "store"
var tab_buttons: Dictionary = {}
var body_root: VBoxContainer = null
var status_label = null
var game_title_font: Font = null
var game_body_font: Font = null
var _card: Control = null
var _anim_t: float = 0.0
var _rotating_auras: Array = []
var _bobbing_heroes: Array = []
var _pulsing_badges: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	current_tab = initial_tab
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

func _process(delta: float) -> void:
	_anim_t += delta
	for i in range(_pulsing_badges.size() - 1, -1, -1):
		var raw_b = _pulsing_badges[i]
		if not is_instance_valid(raw_b):
			_pulsing_badges.remove_at(i)
			continue
		var b: Control = raw_b
		b.pivot_offset = b.size * 0.5
		b.rotation = sin(_anim_t * 6.0 + float(i)) * 0.14
		b.scale = Vector2.ONE * (1.0 + abs(sin(_anim_t * 4.2 + float(i))) * 0.12)
	for i in range(_rotating_auras.size() - 1, -1, -1):
		var raw_a = _rotating_auras[i]
		if not is_instance_valid(raw_a):
			_rotating_auras.remove_at(i)
			continue
		var aura: Control = raw_a
		aura.pivot_offset = aura.size * 0.5
		aura.rotation += delta * 0.85
		aura.scale = Vector2.ONE * (1.0 + sin(_anim_t * 3.0) * 0.06)
	for i in range(_bobbing_heroes.size() - 1, -1, -1):
		var raw_h = _bobbing_heroes[i]
		if not is_instance_valid(raw_h):
			_bobbing_heroes.remove_at(i)
			continue
		var h: Control = raw_h
		h.pivot_offset = h.size * 0.5
		h.position.y = float(h.get_meta("base_y", h.position.y)) + sin(_anim_t * 3.2) * 7.0
		h.scale = Vector2(1.0 + sin(_anim_t * 3.2) * 0.03, 1.0 - sin(_anim_t * 3.2) * 0.025)

func _build_ui() -> void:
	name = "ShopPopup"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.01, 0.05, 0.08, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card_size := Vector2(780, 920)
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
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 28
	style.content_margin_bottom = 28
	bg_panel.add_theme_stylebox_override("panel", style)
	_card.add_child(bg_panel)

	# Top Folder Tabs sticking above the dialog frame
	var tab_row := HBoxContainer.new()
	tab_row.position = Vector2(20, -52)
	tab_row.add_theme_constant_override("separation", 8)
	_card.add_child(tab_row)

	for spec in [
		["store", "Coin Shop"],
		["upgrades", "Upgrades"],
		["pack_stealth", "Stealth Pack"],
		["pack_mega", "Mega Pack"],
	]:
		var key: String = spec[0]
		var label_txt: String = spec[1]
		var tb := Button.new()
		tb.text = label_txt
		tb.custom_minimum_size = Vector2(168, 54)
		if game_title_font != null:
			tb.add_theme_font_override("font", game_title_font)
		tb.add_theme_font_size_override("font_size", 20)
		tb.add_theme_color_override("font_color", Color.WHITE)
		tb.add_theme_color_override("font_outline_color", Color("#0c1c26"))
		tb.add_theme_constant_override("outline_size", 6)
		tb.pressed.connect(func():
			var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
			if sm != null and sm.has_method("play_sfx"):
				sm.play_sfx("button")
			open_tab(key)
		)
		tab_row.add_child(tb)
		tab_buttons[key] = tb

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

	body_root = VBoxContainer.new()
	body_root.add_theme_constant_override("separation", 18)
	bg_panel.add_child(body_root)

	open_tab(current_tab)

	var ad_mgr_sig = get_tree().root.get_node_or_null("AdManager") if is_inside_tree() else null
	if ad_mgr_sig != null and ad_mgr_sig.has_signal("pack_purchase_verified"):
		ad_mgr_sig.pack_purchase_verified.connect(_on_pack_purchase_msg)

	_card.scale = Vector2(0.42, 0.42)
	_card.modulate.a = 0.0
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_card, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(_card, "scale", Vector2(1.06, 0.95), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(_card, "scale", Vector2(0.98, 1.02), 0.09)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.08)

func open_tab(tab_key: String) -> void:
	current_tab = tab_key
	for key in tab_buttons:
		var tb: Button = tab_buttons[key]
		var active: bool = (str(key) == tab_key)
		tb.position.y = -6.0 if active else 0.0
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#1f4f73") if active else Color("#112a3d")
		st.border_color = Color("#0a1824")
		st.set_border_width_all(3)
		st.border_width_bottom = 0
		st.corner_radius_top_left = 14
		st.corner_radius_top_right = 14
		tb.add_theme_stylebox_override("normal", st)
		tb.add_theme_stylebox_override("hover", st)
		tb.add_theme_stylebox_override("pressed", st)
	_render_tab_contents()

func _render_tab_contents() -> void:
	status_label = null
	_rotating_auras.clear()
	_bobbing_heroes.clear()
	_pulsing_badges.clear()
	for child in body_root.get_children():
		child.queue_free()

	if current_tab == "upgrades":
		_build_upgrades_tab()
	elif current_tab == "pack_stealth" or current_tab == "pack_mega":
		_build_bundle_tab(current_tab == "pack_mega")
	else:
		_build_store_tab()

func _build_store_tab() -> void:
	var title := Label.new()
	title.text = "COIN SHOP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		title.add_theme_font_override("font", game_title_font)
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("#ffe885"))
	title.add_theme_color_override("font_outline_color", Color("#0c1c26"))
	title.add_theme_constant_override("outline_size", 9)
	body_root.add_child(title)

	var sub := Label.new()
	sub.text = "Instant Coin Packs for Power-Ups & Upgrades"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		sub.add_theme_font_override("font", game_title_font)
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color("#bfe6ff"))
	sub.add_theme_color_override("font_outline_color", Color("#081520"))
	sub.add_theme_constant_override("outline_size", 5)
	body_root.add_child(sub)

	var ad_mgr = get_tree().root.get_node_or_null("AdManager") if is_inside_tree() else null
	var badges := {"coins_1000": "-20%", "coins_2000": "-35%", "coins_3000": "-50%"}
	var subtitles := {
		"coins_1000": "Starter Sneaker Pouch",
		"coins_2000": "Pro Stealth Chest",
		"coins_3000": "Master Candy Vault",
	}

	for pack_id in PACK_ORDER:
		var info: Dictionary = ad_mgr.SHOP_PACKS[pack_id] if ad_mgr != null and "SHOP_PACKS" in ad_mgr else {"coins": 1000, "price": "$0.99", "title": pack_id.to_upper()}
		var card := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.08, 0.22, 0.34, 0.94)
		cs.border_color = Color("#0c1c26")
		cs.set_border_width_all(4)
		cs.set_corner_radius_all(18)
		cs.content_margin_left = 18
		cs.content_margin_right = 18
		cs.content_margin_top = 14
		cs.content_margin_bottom = 14
		card.add_theme_stylebox_override("panel", cs)
		body_root.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 16)
		card.add_child(row)

		row.add_child(_icon_slot_box(_load_tex("res://assets/ui/reward-coin.png"), Vector2(78, 78)))

		var info_v := VBoxContainer.new()
		info_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info_v.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(info_v)

		var t := Label.new()
		t.text = str(info.get("title", pack_id))
		if game_title_font != null:
			t.add_theme_font_override("font", game_title_font)
		t.add_theme_font_size_override("font_size", 28)
		t.add_theme_color_override("font_color", Color.WHITE)
		t.add_theme_color_override("font_outline_color", Color("#0c1c26"))
		t.add_theme_constant_override("outline_size", 6)
		info_v.add_child(t)

		var d := Label.new()
		d.text = str(subtitles.get(pack_id, "Instant Coin Pack"))
		if game_title_font != null:
			d.add_theme_font_override("font", game_title_font)
		d.add_theme_font_size_override("font_size", 18)
		d.add_theme_color_override("font_color", Color("#bfe6ff"))
		d.add_theme_color_override("font_outline_color", Color("#081520"))
		d.add_theme_constant_override("outline_size", 4)
		info_v.add_child(d)

		var price_str: String = ad_mgr.get_price(pack_id) if ad_mgr != null and ad_mgr.has_method("get_price") else str(info.get("price", "$0.99"))
		var btn := _lime_buy_button("%s  •  %s" % [str(info.get("title", pack_id)), price_str], str(badges.get(pack_id, "")), Vector2(245, 68))
		var p_id: String = str(pack_id)
		btn.pressed.connect(func():
			if ad_mgr != null and ad_mgr.has_method("request_pack_purchase"):
				ad_mgr.request_pack_purchase(p_id)
		)
		row.add_child(btn)

	status_label = Label.new()
	status_label.text = "Google Play handles coin pack purchases."
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if game_title_font != null:
		status_label.add_theme_font_override("font", game_title_font)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("#dfe6e9"))
	status_label.add_theme_color_override("font_outline_color", Color("#081520"))
	status_label.add_theme_constant_override("outline_size", 5)
	body_root.add_child(status_label)

func _on_pack_purchase_msg(_coins: int, msg: String) -> void:
	if is_instance_valid(status_label):
		status_label.text = msg

func _build_upgrades_tab() -> void:
	var hdr := Label.new()
	hdr.text = "SNEAK UPGRADES"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		hdr.add_theme_font_override("font", game_title_font)
	hdr.add_theme_font_size_override("font_size", 42)
	hdr.add_theme_color_override("font_color", Color("#ffe885"))
	hdr.add_theme_color_override("font_outline_color", Color("#0c1c26"))
	hdr.add_theme_constant_override("outline_size", 8)
	body_root.add_child(hdr)

	for spec in UPGRADE_SPECS:
		var key: String = spec[0]
		var name_txt: String = spec[1]
		var desc_txt: String = spec[2]
		var tex_path: String = spec[3]
		var max_lvl := 5
		var gm = get_tree().root.get_node_or_null("GameManager") if is_inside_tree() else null
		var lvl: int = gm.upgrade_level(key) if gm != null and gm.has_method("upgrade_level") else 0
		var cost: int = gm.upgrade_cost(key) if gm != null and gm.has_method("upgrade_cost") else 40

		var card := PanelContainer.new()
		var cs := StyleBoxFlat.new()
		cs.bg_color = Color(0.08, 0.22, 0.34, 0.94)
		cs.border_color = Color("#0c1c26")
		cs.set_border_width_all(4)
		cs.set_corner_radius_all(18)
		cs.content_margin_left = 16
		cs.content_margin_right = 16
		cs.content_margin_top = 12
		cs.content_margin_bottom = 12
		card.add_theme_stylebox_override("panel", cs)
		body_root.add_child(card)

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		card.add_child(row)

		row.add_child(_icon_slot_box(_load_tex(tex_path), Vector2(72, 72)))

		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_child(info)

		var t := Label.new()
		t.text = "%s  (Lv %d/5)" % [name_txt, lvl]
		if game_title_font != null:
			t.add_theme_font_override("font", game_title_font)
		t.add_theme_font_size_override("font_size", 24)
		t.add_theme_color_override("font_color", Color.WHITE)
		t.add_theme_color_override("font_outline_color", Color("#0c1c26"))
		t.add_theme_constant_override("outline_size", 6)
		info.add_child(t)

		var d := Label.new()
		d.text = desc_txt
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if game_title_font != null:
			d.add_theme_font_override("font", game_title_font)
		d.add_theme_font_size_override("font_size", 17)
		d.add_theme_color_override("font_color", Color("#bfe6ff"))
		d.add_theme_color_override("font_outline_color", Color("#081520"))
		d.add_theme_constant_override("outline_size", 4)
		info.add_child(d)

		var cur_coins: int = gm.coins if gm != null else 0
		var btn_txt := "MAXED" if lvl >= max_lvl else ("%d Coins" % cost)
		var b := _lime_buy_button(btn_txt, "", Vector2(165, 58))
		b.disabled = lvl >= max_lvl or cur_coins < cost
		var u_key: String = key
		b.pressed.connect(func():
			var gm_now = get_tree().root.get_node_or_null("GameManager") if is_inside_tree() else null
			if gm_now != null and gm_now.has_method("buy_upgrade") and gm_now.buy_upgrade(u_key):
				var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
				if sm != null and sm.has_method("play_sfx"):
					sm.play_sfx("powerup")
				_render_tab_contents()
		)
		row.add_child(b)

func _build_bundle_tab(is_mega: bool) -> void:
	var title_txt := "MEGA CANDY RAID PACK" if is_mega else "STEALTH SNEAKER PACK"
	var hero_tex := _load_tex("res://assets/ui/powerup_bypass_wall.svg" if is_mega else "res://assets/ui/powerup_invis_white_ball.svg")
	var bonus_coins := 3000 if is_mega else 1000
	var price_txt := "$1.99" if is_mega else "$0.99"
	var sku := "coins_3000" if is_mega else "coins_1000"
	var ad_mgr_p = get_tree().root.get_node_or_null("AdManager") if is_inside_tree() else null
	if ad_mgr_p != null and ad_mgr_p.has_method("get_price"):
		price_txt = ad_mgr_p.get_price(sku)
	var discount_txt := "-60%" if is_mega else "-50%"

	var hdr := Label.new()
	hdr.text = title_txt
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		hdr.add_theme_font_override("font", game_title_font)
	hdr.add_theme_font_size_override("font_size", 38)
	hdr.add_theme_color_override("font_color", Color("#ffe885"))
	hdr.add_theme_color_override("font_outline_color", Color("#0c1c26"))
	hdr.add_theme_constant_override("outline_size", 8)
	body_root.add_child(hdr)

	var hero_wrap := CenterContainer.new()
	body_root.add_child(hero_wrap)

	var hero_stage := Control.new()
	hero_stage.custom_minimum_size = Vector2(220, 195)
	hero_wrap.add_child(hero_stage)

	var aura := PanelContainer.new()
	aura.size = Vector2(165, 165)
	aura.position = Vector2(27, 15)
	aura.pivot_offset = Vector2(82, 82)
	var as_box := StyleBoxFlat.new()
	as_box.bg_color = Color(1.0, 0.82, 0.25, 0.20)
	as_box.border_color = Color(1.0, 0.88, 0.35, 0.65)
	as_box.set_border_width_all(4)
	as_box.set_corner_radius_all(34)
	aura.add_theme_stylebox_override("panel", as_box)
	hero_stage.add_child(aura)
	_rotating_auras.append(aura)

	var hero := TextureRect.new()
	hero.texture = hero_tex
	hero.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	hero.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	hero.size = Vector2(150, 150)
	hero.position = Vector2(35, 20)
	hero.set_meta("base_y", 20.0)
	hero_stage.add_child(hero)
	_bobbing_heroes.append(hero)

	var items := [
		[_load_tex("res://assets/ui/powerup_invis_white_ball.svg"), "Ghost Cloak Boost", "Sneak past Granny unseen"],
		[_load_tex("res://assets/ui/powerup_speed_lightning.svg"), "Turbo Sneaker Sprint", "Outrun guards & security cameras"],
		[_load_tex("res://assets/ui/reward-coin.png"), "+%d Coins + No Ads" % bonus_coins, "Instant treasure & ad-free play"],
	]
	for idx in range(items.size()):
		var it: Array = items[idx]
		var r := _bundle_item_row(it[0], it[1], it[2])
		r.modulate.a = 0.0
		body_root.add_child(r)
		var rtw := r.create_tween()
		rtw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		rtw.tween_interval(0.06 + idx * 0.07)
		rtw.tween_property(r, "modulate:a", 1.0, 0.18)

	status_label = Label.new()
	status_label.text = "Includes +%d Coins & VIP Perks" % bonus_coins
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if game_title_font != null:
		status_label.add_theme_font_override("font", game_title_font)
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("#b8e5ff"))
	status_label.add_theme_color_override("font_outline_color", Color("#081520"))
	status_label.add_theme_constant_override("outline_size", 5)
	body_root.add_child(status_label)

	var buy_wrap := CenterContainer.new()
	body_root.add_child(buy_wrap)
	var ad_mgr = get_tree().root.get_node_or_null("AdManager") if is_inside_tree() else null
	var buy_btn := _lime_buy_button("Buy  " + price_txt, discount_txt, Vector2(340, 74))
	buy_btn.pressed.connect(func():
		var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
		if sm != null and sm.has_method("play_sfx"):
			sm.play_sfx("coin")
		if is_instance_valid(status_label):
			status_label.text = "Opening Google Play..."
		if ad_mgr != null and ad_mgr.has_method("request_pack_purchase"):
			ad_mgr.request_pack_purchase(sku)
	)
	buy_wrap.add_child(buy_btn)

func _bundle_item_row(icon_tex: Texture2D, title_txt: String, sub_txt: String) -> PanelContainer:
	var card := PanelContainer.new()
	var cs := StyleBoxFlat.new()
	cs.bg_color = Color(0.08, 0.22, 0.34, 0.92)
	cs.border_color = Color("#0c1c26")
	cs.set_border_width_all(3)
	cs.set_corner_radius_all(16)
	cs.content_margin_left = 14
	cs.content_margin_right = 14
	cs.content_margin_top = 10
	cs.content_margin_bottom = 10
	card.add_theme_stylebox_override("panel", cs)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	card.add_child(row)
	row.add_child(_icon_slot_box(icon_tex, Vector2(64, 64)))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(v)
	var t := Label.new()
	t.text = title_txt
	if game_title_font != null:
		t.add_theme_font_override("font", game_title_font)
	t.add_theme_font_size_override("font_size", 24)
	t.add_theme_color_override("font_color", Color.WHITE)
	t.add_theme_color_override("font_outline_color", Color("#0c1c26"))
	t.add_theme_constant_override("outline_size", 6)
	v.add_child(t)
	var s := Label.new()
	s.text = sub_txt
	if game_title_font != null:
		s.add_theme_font_override("font", game_title_font)
	s.add_theme_font_size_override("font_size", 17)
	s.add_theme_color_override("font_color", Color("#bfe6ff"))
	s.add_theme_color_override("font_outline_color", Color("#081520"))
	s.add_theme_constant_override("outline_size", 4)
	v.add_child(s)
	return card

func _icon_slot_box(icon_tex: Texture2D, box_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = box_size
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#7b93a8")
	st.border_color = Color("#0c1c26")
	st.set_border_width_all(3)
	st.set_corner_radius_all(12)
	st.content_margin_left = 8
	st.content_margin_right = 8
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", st)
	var ic := TextureRect.new()
	ic.texture = icon_tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.add_child(ic)
	return p

func _lime_buy_button(text: String, badge_txt: String, btn_size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = btn_size
	if game_title_font != null:
		btn.add_theme_font_override("font", game_title_font)
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color("#19470b"))
	btn.add_theme_constant_override("outline_size", 6)
	var st := StyleBoxFlat.new()
	st.bg_color = Color("#7ed321")
	st.border_color = Color("#153309")
	st.set_border_width_all(3)
	st.border_width_bottom = 7
	st.set_corner_radius_all(16)
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = Color("#94e835")
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", hv)
	btn.add_theme_stylebox_override("disabled", st)

	if badge_txt != "":
		var badge := PanelContainer.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.position = Vector2(btn_size.x - 62, -12)
		var bs := StyleBoxFlat.new()
		bs.bg_color = Color("#ff6b1a")
		bs.border_color = Color("#3b1204")
		bs.set_border_width_all(2)
		bs.set_corner_radius_all(10)
		bs.content_margin_left = 8
		bs.content_margin_right = 8
		bs.content_margin_top = 2
		bs.content_margin_bottom = 2
		badge.add_theme_stylebox_override("panel", bs)
		var bl := Label.new()
		bl.text = badge_txt
		if game_title_font != null:
			bl.add_theme_font_override("font", game_title_font)
		bl.add_theme_font_size_override("font_size", 15)
		bl.add_theme_color_override("font_color", Color.WHITE)
		badge.add_child(bl)
		btn.add_child(badge)
		_pulsing_badges.append(badge)
	_wire_button_juice(btn)
	return btn

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
