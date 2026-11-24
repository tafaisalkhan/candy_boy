extends Control

const GAME_SCENE := "res://scenes/main.tscn"
const SPLASH_BACKGROUND_PORTRAIT := "res://assets/ui/boy_candy_splash_bg.png"
const SPLASH_BACKGROUND_ICON := "res://assets/ui/game_icon.png"

var play_button: Button = null
var settings_button: Button = null
var shop_button: Button = null
var game_scene: PackedScene = null
var start_requested: bool = false
var privacy_popup: Control = null
var settings_popup: Control = null
var shop_popup: Control = null
var support_popup: Control = null
var daily_popup: Control = null
var challenge_popup: Control = null
var challenge_info_lbl: Label = null
var challenge_play_btn: Button = null

# Loader Controls
var loader_container: VBoxContainer = null
var loading_label: Label = null
var loading_bar: ProgressBar = null
var button_container: Control = null
var is_loading_complete: bool = false

# Top & Bottom Arcade HUD on Splash/MainMenu
var title_font: Font = null
var top_left_bar: HBoxContainer = null
var top_right_bar: HBoxContainer = null
var bottom_dock: HBoxContainer = null
var coins_lbl: Label = null
var daily_badge: Control = null
var upgrade_badge: Control = null
var challenge_badge: Control = null
var daily_claim_btn: Button = null
var daily_day_cards: Array = []

var _anim_t: float = 0.0
var _pulsing_badges: Array = []
var _bottom_dock_cards: Array = []


func _ready() -> void:
	var bg_path := SPLASH_BACKGROUND_PORTRAIT if FileAccess.file_exists(ProjectSettings.globalize_path(SPLASH_BACKGROUND_PORTRAIT)) else SPLASH_BACKGROUND_ICON
	var background := TextureRect.new()
	background.texture = _load_ui_texture(bg_path)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(background)

	var vignette := ColorRect.new()
	vignette.color = Color(0.02, 0.05, 0.09, 0.22)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vignette)

	if ResourceLoader.exists("res://assets/fonts/LuckiestGuy-Regular.ttf"):
		title_font = load("res://assets/fonts/LuckiestGuy-Regular.ttf") as Font

	# Top-Center Static Bold Title (No distracting bobbing animation!)
	var title_shadow := Label.new()
	title_shadow.text = "BOY FAVORITE\nCOLLECTION"
	title_shadow.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title_shadow.offset_left = 30.0
	title_shadow.offset_right = -30.0
	title_shadow.offset_top = 152.0
	title_shadow.offset_bottom = 352.0
	title_shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_shadow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_shadow.add_theme_font_override("font", title_font)
	title_shadow.add_theme_font_size_override("font_size", 62)
	title_shadow.add_theme_color_override("font_color", Color("#102536"))
	title_shadow.add_theme_color_override("font_outline_color", Color("#102536"))
	title_shadow.add_theme_constant_override("outline_size", 18)
	add_child(title_shadow)

	var title := Label.new()
	title.text = "BOY FAVORITE\nCOLLECTION"
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_left = 30.0
	title.offset_right = -30.0
	title.offset_top = 140.0
	title.offset_bottom = 340.0
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", title_font)
	title.add_theme_font_size_override("font_size", 62)
	title.add_theme_color_override("font_color", Color("#fff3b8"))
	title.add_theme_color_override("font_outline_color", Color("#102536"))
	title.add_theme_constant_override("outline_size", 12)
	add_child(title)

	# 1. Loader Container (Shows immediately upon launch)
	_build_loader_ui(title_font)

	# 2. Arcade Top Cluster, Bottom 4-Card Dock & Big Glossy PLAY Button (Hidden until loading finishes)
	_build_action_buttons_ui(title_font)
	_build_daily_rewards_popup()
	_build_daily_challenge_popup()

	if SignalHub != null:
		SignalHub.coins_changed.connect(func(new_c: int):
			if is_instance_valid(coins_lbl):
				coins_lbl.text = str(new_c)
			_refresh_badges()
		)

	var ad_mgr = AdManager if AdManager != null else get_tree().root.get_node_or_null("AdManager")
	if ad_mgr != null:
		if ad_mgr.has_method("set_gameplay_active"):
			ad_mgr.set_gameplay_active(false)
		if ad_mgr.has_method("show_banner"):
			ad_mgr.show_banner()

	var all_args := OS.get_cmdline_user_args() + OS.get_cmdline_args()

	# Test Flag Handlers
	if "--test-privacy" in all_args or FileAccess.file_exists("res://test_privacy.flag"):
		if FileAccess.file_exists("res://test_privacy.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_privacy.flag"))
		_show_privacy_policy_popup()
		_capture_privacy_and_quit()
		return

	if "--test-splash-settings" in all_args or FileAccess.file_exists("res://test_splash_settings.flag"):
		if FileAccess.file_exists("res://test_splash_settings.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_splash_settings.flag"))
		_on_loading_finished()
		_show_settings_popup()
		_capture_screenshot_and_quit("screenshot_splash_settings.png")
		return

	if "--test-all-popups" in all_args:
		_capture_all_popups()
		return

	if "--test-splash-buttons" in all_args or FileAccess.file_exists("res://test_splash_buttons.flag"):
		if FileAccess.file_exists("res://test_splash_buttons.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_splash_buttons.flag"))
		_on_loading_finished()
		_capture_screenshot_and_quit("screenshot_splash_buttons.png")
		return

	if "--test-splash-loading" in all_args or FileAccess.file_exists("res://test_splash_loading.flag"):
		if FileAccess.file_exists("res://test_splash_loading.flag"):
			DirAccess.remove_absolute(ProjectSettings.globalize_path("res://test_splash_loading.flag"))
		if is_instance_valid(loading_bar):
			loading_bar.value = 54.0
		if is_instance_valid(loading_label):
			loading_label.text = "LOADING MISSIONS... 54%"
		_capture_screenshot_and_quit("screenshot_splash_loading.png")
		return

	for arg in all_args:
		if arg.begins_with("--test") or arg == "--play" or arg.begins_with("--level"):
			call_deferred("_start_game", true)
			return

	if FileAccess.file_exists("res://test_loop.flag") or FileAccess.file_exists("res://test_powerup.flag") or FileAccess.file_exists("res://test_screenshot.flag") or FileAccess.file_exists("res://test_cupboard.flag") or FileAccess.file_exists("res://test_victory.flag") or FileAccess.file_exists("res://test_fail.flag") or FileAccess.file_exists("res://test_rewarded_powerup.flag") or FileAccess.file_exists("res://test_mission_intro.flag"):
		call_deferred("_start_game", true)
		return

	if "--screen-game" in all_args:
		call_deferred("_start_game")
		return

	if "--screenshot" in all_args:
		_capture_and_quit()
		return

	_start_loading_animation()


func _build_loader_ui(p_font: Font) -> void:
	loader_container = VBoxContainer.new()
	loader_container.name = "LoaderContainer"
	loader_container.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	loader_container.offset_left = 140.0
	loader_container.offset_right = -140.0
	loader_container.offset_top = -270.0
	loader_container.offset_bottom = -145.0
	loader_container.alignment = BoxContainer.ALIGNMENT_CENTER
	loader_container.add_theme_constant_override("separation", 14)
	add_child(loader_container)

	loading_label = Label.new()
	loading_label.text = "LOADING MISSIONS... 0%"
	loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if p_font != null:
		loading_label.add_theme_font_override("font", p_font)
	loading_label.add_theme_font_size_override("font_size", 28)
	loading_label.add_theme_color_override("font_color", Color("#ffeaa7"))
	loading_label.add_theme_color_override("font_outline_color", Color("#2d3436"))
	loading_label.add_theme_constant_override("outline_size", 8)
	loader_container.add_child(loading_label)

	loading_bar = ProgressBar.new()
	loading_bar.min_value = 0.0
	loading_bar.max_value = 100.0
	loading_bar.value = 0.0
	loading_bar.show_percentage = false
	loading_bar.custom_minimum_size = Vector2(0, 26)

	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color("#1e272e")
	bg_style.border_color = Color("#00cec9")
	bg_style.border_width_bottom = 3
	bg_style.border_width_top = 2
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.set_corner_radius_all(13)
	loading_bar.add_theme_stylebox_override("background", bg_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color("#00cec9")
	fill_style.set_corner_radius_all(13)
	loading_bar.add_theme_stylebox_override("fill", fill_style)

	loader_container.add_child(loading_bar)


func _build_action_buttons_ui(p_font: Font) -> void:
	button_container = Control.new()
	button_container.name = "ButtonContainer"
	button_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button_container.visible = false
	add_child(button_container)

	# 1. Top-Left Cluster: Settings Gear + Packs + Mega Packs (Ant Colony Wars 00:02 video layout)
	top_left_bar = HBoxContainer.new()
	top_left_bar.position = Vector2(24, 28)
	top_left_bar.add_theme_constant_override("separation", 14)
	button_container.add_child(top_left_bar)

	settings_button = _square_top_button("", _load_ui_texture("res://assets/ui/icons/icon-settings.png"), Color("#243b4a"), Color("#6bc2f5"), Vector2(76, 76))
	settings_button.pressed.connect(_show_settings_popup)
	top_left_bar.add_child(settings_button)

	var pack_btn := _pack_top_badge("Packs", _load_ui_texture("res://assets/ui/powerup_invis_white_ball.svg"), Color("#266e8a"), Color("#7ce0ff"), "pack_stealth")
	top_left_bar.add_child(pack_btn)

	var mega_btn := _pack_top_badge("Mega\nPacks", _load_ui_texture("res://assets/ui/powerup_bypass_wall.svg"), Color("#8a2b7d"), Color("#ff94f2"), "pack_mega")
	top_left_bar.add_child(mega_btn)

	# 2. Top-Right Coin Currency Bar with [+] Button
	top_right_bar = HBoxContainer.new()
	top_right_bar.anchor_left = 1.0
	top_right_bar.anchor_right = 1.0
	top_right_bar.offset_left = -280
	top_right_bar.offset_right = -24
	top_right_bar.offset_top = 34
	top_right_bar.offset_bottom = 92
	top_right_bar.alignment = BoxContainer.ALIGNMENT_END
	button_container.add_child(top_right_bar)

	var cur_coins := GameManager.coins if GameManager != null else 1577
	var coin_bar := _currency_plus_bar(str(cur_coins), _load_ui_texture("res://assets/ui/reward-coin.png"), Color("#f0932b"), _show_shop_popup)
	coins_lbl = coin_bar.get_node("Row/Amount")
	top_right_bar.add_child(coin_bar)

	# 3. Big Glossy Green "▶  PLAY" Button with LEVEL X Badge
	var next_lvl := GameManager.highest_unlocked_level if GameManager != null else 1
	play_button = Button.new()
	play_button.text = "▶  PLAY"
	play_button.custom_minimum_size = Vector2(540, 118)
	play_button.pivot_offset = Vector2(270, 59)
	play_button.anchor_left = 0.5
	play_button.anchor_right = 0.5
	play_button.anchor_top = 1.0
	play_button.anchor_bottom = 1.0
	play_button.offset_left = -270
	play_button.offset_right = 270
	play_button.offset_top = -380
	play_button.offset_bottom = -262
	if p_font != null:
		play_button.add_theme_font_override("font", p_font)
	play_button.add_theme_font_size_override("font_size", 54)
	play_button.add_theme_color_override("font_color", Color.WHITE)
	play_button.add_theme_color_override("font_outline_color", Color("#0b2533"))
	play_button.add_theme_constant_override("outline_size", 11)
	var b_style := StyleBoxFlat.new()
	b_style.bg_color = Color("#22c55e")
	b_style.border_color = Color("#0c202b")
	b_style.set_border_width_all(5)
	b_style.border_width_bottom = 10
	b_style.set_corner_radius_all(26)
	var b_hover := b_style.duplicate() as StyleBoxFlat
	b_hover.bg_color = b_style.bg_color.lightened(0.12)
	play_button.add_theme_stylebox_override("normal", b_style)
	play_button.add_theme_stylebox_override("hover", b_hover)
	play_button.add_theme_stylebox_override("pressed", b_hover)
	play_button.pressed.connect(func():
		if GameManager != null:
			GameManager.playing_daily_challenge = false
		_start_game()
	)
	button_container.add_child(play_button)
	_wire_button_juice(play_button)

	var lvl_badge := PanelContainer.new()
	lvl_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lvl_badge.position = Vector2(368, -18)
	lvl_badge.custom_minimum_size = Vector2(150, 36)
	var lbs := StyleBoxFlat.new()
	lbs.bg_color = Color("#18a4e0")
	lbs.border_color = Color("#0c202b")
	lbs.set_border_width_all(3)
	lbs.set_corner_radius_all(12)
	lbs.content_margin_left = 12
	lbs.content_margin_right = 12
	lbs.content_margin_top = 3
	lbs.content_margin_bottom = 3
	lvl_badge.add_theme_stylebox_override("panel", lbs)
	var lbl_lvl := Label.new()
	lbl_lvl.text = "LEVEL " + str(next_lvl)
	lbl_lvl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if p_font != null:
		lbl_lvl.add_theme_font_override("font", p_font)
	lbl_lvl.add_theme_font_size_override("font_size", 20)
	lbl_lvl.add_theme_color_override("font_color", Color.WHITE)
	lbl_lvl.add_theme_color_override("font_outline_color", Color("#0c202b"))
	lbl_lvl.add_theme_constant_override("outline_size", 5)
	lvl_badge.add_child(lbl_lvl)
	play_button.add_child(lvl_badge)

	# 4. Bottom 4-Card Arcade Dock (Daily Reward, Upgrades, Daily Challenge, Coin Shop)
	bottom_dock = HBoxContainer.new()
	bottom_dock.anchor_left = 0.5
	bottom_dock.anchor_right = 0.5
	bottom_dock.anchor_top = 1.0
	bottom_dock.anchor_bottom = 1.0
	bottom_dock.offset_left = -415
	bottom_dock.offset_right = 415
	bottom_dock.offset_top = -225
	bottom_dock.offset_bottom = -75
	bottom_dock.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom_dock.add_theme_constant_override("separation", 18)
	button_container.add_child(bottom_dock)

	var card_daily := _dock_card("Daily\nReward", _load_ui_texture("res://assets/ui/reward-coin.png"), Color("#2e6b4e"), func():
		if SoundManager != null:
			SoundManager.play_sfx("button")
		_refresh_daily_panel()
		_open_inline_popup(daily_popup)
	)
	daily_badge = card_daily.get_node("Badge")
	bottom_dock.add_child(card_daily)

	var card_upg := _dock_card("Upgrades", _load_ui_texture("res://assets/ui/powerup_speed_lightning.svg"), Color("#5c3b7a"), func():
		_open_shop_tab("upgrades")
	)
	upgrade_badge = card_upg.get_node("Badge")
	bottom_dock.add_child(card_upg)

	var card_chal := _dock_card("Daily\nMission", _load_ui_texture("res://assets/ui/victory-star.png"), Color("#7a3322"), func():
		if SoundManager != null:
			SoundManager.play_sfx("button")
		_refresh_challenge_panel()
		_open_inline_popup(challenge_popup)
	)
	challenge_badge = card_chal.get_node("Badge")
	bottom_dock.add_child(card_chal)

	var card_shop := _dock_card("Coin\nShop", _load_ui_texture("res://assets/ui/icons/icon-store.png"), Color("#6e4f16"), _show_shop_popup)
	shop_button = card_shop.get_node("Button")
	bottom_dock.add_child(card_shop)

	_bottom_dock_cards = [card_daily, card_upg, card_chal, card_shop]
	_refresh_badges()


var _polling_threaded_load: bool = false
var _fake_load_progress: float = 0.0

func _start_loading_animation() -> void:
	_polling_threaded_load = true
	_fake_load_progress = 0.0

func _process(delta: float) -> void:
	_anim_t += delta
	if is_loading_complete and is_instance_valid(play_button) and _anim_t > 0.6:
		play_button.scale = Vector2.ONE * (1.0 + sin(_anim_t * 3.6) * 0.032)
	for i in range(_pulsing_badges.size() - 1, -1, -1):
		var raw_b = _pulsing_badges[i]
		if not is_instance_valid(raw_b):
			_pulsing_badges.remove_at(i)
			continue
		var b: Control = raw_b
		b.pivot_offset = b.size * 0.5
		b.rotation = sin(_anim_t * 6.0 + float(i)) * 0.14
		b.scale = Vector2.ONE * (1.0 + abs(sin(_anim_t * 4.2 + float(i))) * 0.12)

	if not _polling_threaded_load:
		return
	_fake_load_progress = minf(100.0, _fake_load_progress + delta * 180.0)
	if is_instance_valid(loading_bar):
		loading_bar.value = _fake_load_progress
	if is_instance_valid(loading_label):
		loading_label.text = "LOADING MISSIONS... %d%%" % int(_fake_load_progress)
	if _fake_load_progress >= 100.0:
		_polling_threaded_load = false
		_on_loading_finished()


func _on_loading_finished() -> void:
	is_loading_complete = true
	_anim_t = 0.0
	if is_instance_valid(loader_container):
		var ltw := create_tween()
		ltw.tween_property(loader_container, "modulate:a", 0.0, 0.18)
		ltw.tween_callback(func():
			if is_instance_valid(loader_container):
				loader_container.visible = false
		)

	if is_instance_valid(button_container):
		button_container.visible = true
		_play_menu_entrance_choreography()

	if is_instance_valid(play_button):
		play_button.grab_focus()
	var ad_mgr_upd = AdManager if AdManager != null else get_tree().root.get_node_or_null("AdManager")
	if ad_mgr_upd != null and ad_mgr_upd.has_method("check_in_app_update"):
		ad_mgr_upd.check_in_app_update()
	if GameManager != null and not GameManager.home_support_shown_this_launch:
		GameManager.home_support_shown_this_launch = true
		_show_support_popup()


func _play_menu_entrance_choreography() -> void:
	if is_instance_valid(top_left_bar):
		top_left_bar.position.y = -95.0
		var tw1 := top_left_bar.create_tween()
		tw1.tween_property(top_left_bar, "position:y", 28.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(top_right_bar):
		top_right_bar.offset_top = -85.0
		top_right_bar.offset_bottom = -27.0
		var tw2 := top_right_bar.create_tween().set_parallel(true)
		tw2.tween_property(top_right_bar, "offset_top", 34.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw2.tween_property(top_right_bar, "offset_bottom", 92.0, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in range(_bottom_dock_cards.size()):
		var c: Control = _bottom_dock_cards[i]
		if not is_instance_valid(c):
			continue
		c.pivot_offset = Vector2(95, 75)
		c.scale = Vector2.ZERO
		var ctw := c.create_tween()
		ctw.tween_interval(0.08 + i * 0.065)
		ctw.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(play_button):
		play_button.pivot_offset = Vector2(270, 59)
		play_button.scale = Vector2.ZERO
		var btw := play_button.create_tween()
		btw.tween_interval(0.16)
		btw.tween_property(play_button, "scale", Vector2.ONE, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _refresh_badges() -> void:
	if GameManager == null:
		return
	if is_instance_valid(daily_badge):
		daily_badge.visible = GameManager.can_claim_daily_bonus()
	if is_instance_valid(upgrade_badge):
		upgrade_badge.visible = GameManager.coins >= 40
	if is_instance_valid(challenge_badge):
		challenge_badge.visible = not GameManager.is_daily_challenge_done_today()
	_refresh_challenge_panel()


# ============================================================================
# 7-DAY ESCALATING DAILY REWARDS POPUP (20 -> 140 Coins)
# ============================================================================
func _build_daily_rewards_popup() -> void:
	daily_popup = Control.new()
	daily_popup.name = "DailyRewardsPopup"
	daily_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	daily_popup.visible = false
	add_child(daily_popup)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.05, 0.08, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	daily_popup.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	daily_popup.add_child(center)

	var card_size := Vector2(760, 740)
	var card := Control.new()
	card.custom_minimum_size = card_size
	card.size = card_size
	card.pivot_offset = card_size * 0.5
	center.add_child(card)

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
	card.add_child(bg_panel)

	var close_x := Button.new()
	close_x.text = "✖"
	close_x.size = Vector2(54, 54)
	close_x.position = Vector2(card_size.x - 32, -20)
	if title_font != null:
		close_x.add_theme_font_override("font", title_font)
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
	close_x.pressed.connect(func():
		if SoundManager != null:
			SoundManager.play_sfx("button")
		_close_inline_popup(daily_popup)
	)
	card.add_child(close_x)
	_wire_button_juice(close_x)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	bg_panel.add_child(v)

	var hdr := Label.new()
	hdr.text = "7-DAY DAILY REWARD"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font != null:
		hdr.add_theme_font_override("font", title_font)
	hdr.add_theme_font_size_override("font_size", 42)
	hdr.add_theme_color_override("font_color", Color("#ffe885"))
	hdr.add_theme_color_override("font_outline_color", Color("#0a1824"))
	hdr.add_theme_constant_override("outline_size", 9)
	v.add_child(hdr)

	var sub := Label.new()
	sub.text = "Claim +20 more coins every day up to Day 7 (+140), then restart at Day 1!"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if title_font != null:
		sub.add_theme_font_override("font", title_font)
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color("#d4f2ff"))
	sub.add_theme_color_override("font_outline_color", Color("#081520"))
	sub.add_theme_constant_override("outline_size", 5)
	v.add_child(sub)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	v.add_child(grid)

	daily_day_cards.clear()
	var step := GameManager.DAILY_STEP_COINS if GameManager != null else 20
	for d in range(1, 8):
		var reward := d * step
		var btn := Button.new()
		btn.text = "DAY %d  •  +%d COINS" % [d, reward]
		btn.icon = _load_ui_texture("res://assets/ui/reward-coin.png")
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 30)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(320, 82)
		if title_font != null:
			btn.add_theme_font_override("font", title_font)
		btn.add_theme_font_size_override("font_size", 22)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_outline_color", Color("#0b2533"))
		btn.add_theme_constant_override("outline_size", 6)
		var st := StyleBoxFlat.new()
		st.bg_color = Color("#1a4663")
		st.border_color = Color("#0c1c26")
		st.set_border_width_all(3)
		st.border_width_bottom = 6
		st.set_corner_radius_all(16)
		btn.add_theme_stylebox_override("normal", st)
		btn.add_theme_stylebox_override("disabled", st)
		btn.disabled = true
		grid.add_child(btn)
		daily_day_cards.append(btn)

	daily_claim_btn = Button.new()
	daily_claim_btn.text = "CLAIM TODAY'S COINS"
	daily_claim_btn.custom_minimum_size = Vector2(460, 74)
	if title_font != null:
		daily_claim_btn.add_theme_font_override("font", title_font)
	daily_claim_btn.add_theme_font_size_override("font_size", 26)
	daily_claim_btn.add_theme_color_override("font_color", Color.WHITE)
	daily_claim_btn.add_theme_color_override("font_outline_color", Color("#19470b"))
	daily_claim_btn.add_theme_constant_override("outline_size", 7)
	var cst := StyleBoxFlat.new()
	cst.bg_color = Color("#7ed321")
	cst.border_color = Color("#153309")
	cst.set_border_width_all(3)
	cst.border_width_bottom = 7
	cst.set_corner_radius_all(18)
	daily_claim_btn.add_theme_stylebox_override("normal", cst)
	daily_claim_btn.add_theme_stylebox_override("hover", cst)
	daily_claim_btn.add_theme_stylebox_override("pressed", cst)
	daily_claim_btn.add_theme_stylebox_override("disabled", cst)
	daily_claim_btn.pressed.connect(func():
		if GameManager != null:
			var gained := GameManager.claim_daily_bonus()
			if gained > 0:
				if SoundManager != null:
					SoundManager.play_sfx("coin")
				_refresh_daily_panel()
				_refresh_badges()
	)
	_wire_button_juice(daily_claim_btn)
	var cw := CenterContainer.new()
	cw.add_child(daily_claim_btn)
	v.add_child(cw)
	_refresh_daily_panel()


func _refresh_daily_panel() -> void:
	if GameManager == null:
		return
	var can_claim := GameManager.can_claim_daily_bonus()
	var current_idx := GameManager.daily_streak_day
	for i in range(daily_day_cards.size()):
		var d := i + 1
		var reward := d * GameManager.DAILY_STEP_COINS
		var card: Button = daily_day_cards[i]
		if i < current_idx:
			card.text = "DAY %d  •  CLAIMED ✓" % d
		elif i == current_idx and can_claim:
			card.text = "DAY %d ★  •  +%d COINS" % [d, reward]
		else:
			card.text = "DAY %d  •  +%d COINS" % [d, reward]
	if is_instance_valid(daily_claim_btn):
		if can_claim:
			var amt := GameManager.next_daily_reward_coins()
			var day_num := GameManager.current_daily_day_number()
			daily_claim_btn.text = "CLAIM DAY %d (+%d COINS)" % [day_num, amt]
			daily_claim_btn.disabled = false
		else:
			daily_claim_btn.text = "COME BACK TOMORROW"
			daily_claim_btn.disabled = true


# ============================================================================
# DAILY CHALLENGE POPUP (one special level per day, +150 bonus coins)
# ============================================================================
func _build_daily_challenge_popup() -> void:
	challenge_popup = Control.new()
	challenge_popup.name = "DailyChallengePopup"
	challenge_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	challenge_popup.visible = false
	add_child(challenge_popup)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.05, 0.08, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	challenge_popup.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	challenge_popup.add_child(center)

	var card_size := Vector2(700, 600)
	var card := Control.new()
	card.custom_minimum_size = card_size
	card.size = card_size
	card.pivot_offset = card_size * 0.5
	center.add_child(card)

	var bg_panel := PanelContainer.new()
	bg_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#5a2a1c")
	style.border_color = Color("#1f0b06")
	style.set_border_width_all(6)
	style.border_width_bottom = 12
	style.set_corner_radius_all(24)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 30
	style.content_margin_bottom = 30
	bg_panel.add_theme_stylebox_override("panel", style)
	card.add_child(bg_panel)

	var close_x := Button.new()
	close_x.text = "✖"
	close_x.size = Vector2(54, 54)
	close_x.position = Vector2(card_size.x - 32, -20)
	if title_font != null:
		close_x.add_theme_font_override("font", title_font)
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
	close_x.pressed.connect(func():
		if SoundManager != null:
			SoundManager.play_sfx("button")
		_close_inline_popup(challenge_popup)
	)
	card.add_child(close_x)
	_wire_button_juice(close_x)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 20)
	bg_panel.add_child(v)

	var hdr := Label.new()
	hdr.text = "DAILY CHALLENGE"
	hdr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font != null:
		hdr.add_theme_font_override("font", title_font)
	hdr.add_theme_font_size_override("font_size", 46)
	hdr.add_theme_color_override("font_color", Color("#ffd166"))
	hdr.add_theme_color_override("font_outline_color", Color("#1f0b06"))
	hdr.add_theme_constant_override("outline_size", 9)
	v.add_child(hdr)

	var star_wrap := CenterContainer.new()
	var star := TextureRect.new()
	star.texture = _load_ui_texture("res://assets/ui/victory-star.png")
	star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	star.custom_minimum_size = Vector2(130, 130)
	star_wrap.add_child(star)
	v.add_child(star_wrap)
	_pulsing_badges.append(star)

	challenge_info_lbl = Label.new()
	challenge_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	challenge_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if title_font != null:
		challenge_info_lbl.add_theme_font_override("font", title_font)
	challenge_info_lbl.add_theme_font_size_override("font_size", 24)
	challenge_info_lbl.add_theme_color_override("font_color", Color("#fff1e0"))
	challenge_info_lbl.add_theme_color_override("font_outline_color", Color("#1f0b06"))
	challenge_info_lbl.add_theme_constant_override("outline_size", 6)
	v.add_child(challenge_info_lbl)

	challenge_play_btn = Button.new()
	challenge_play_btn.custom_minimum_size = Vector2(440, 80)
	if title_font != null:
		challenge_play_btn.add_theme_font_override("font", title_font)
	challenge_play_btn.add_theme_font_size_override("font_size", 28)
	challenge_play_btn.add_theme_color_override("font_color", Color.WHITE)
	challenge_play_btn.add_theme_color_override("font_outline_color", Color("#19470b"))
	challenge_play_btn.add_theme_constant_override("outline_size", 7)
	var pst := StyleBoxFlat.new()
	pst.bg_color = Color("#22c55e")
	pst.border_color = Color("#0c202b")
	pst.set_border_width_all(4)
	pst.border_width_bottom = 8
	pst.set_corner_radius_all(20)
	var pdis := pst.duplicate() as StyleBoxFlat
	pdis.bg_color = Color("#6b6b6b")
	challenge_play_btn.add_theme_stylebox_override("normal", pst)
	challenge_play_btn.add_theme_stylebox_override("hover", pst)
	challenge_play_btn.add_theme_stylebox_override("pressed", pst)
	challenge_play_btn.add_theme_stylebox_override("disabled", pdis)
	challenge_play_btn.pressed.connect(func():
		if GameManager != null and not GameManager.is_daily_challenge_done_today():
			GameManager.playing_daily_challenge = true
			GameManager.current_level = GameManager.daily_challenge_level_number()
			_start_game()
	)
	_wire_button_juice(challenge_play_btn)
	var pw := CenterContainer.new()
	pw.add_child(challenge_play_btn)
	v.add_child(pw)
	_refresh_challenge_panel()


func _refresh_challenge_panel() -> void:
	if GameManager == null or not is_instance_valid(challenge_info_lbl):
		return
	var lvl := GameManager.daily_challenge_level_number()
	var bonus := GameManager.DAILY_CHALLENGE_BONUS_COINS
	if GameManager.is_daily_challenge_done_today():
		challenge_info_lbl.text = "Today's challenge complete! ✓\nYou earned +%d bonus coins.\nA new challenge unlocks tomorrow." % bonus
		challenge_play_btn.text = "COME BACK TOMORROW"
		challenge_play_btn.disabled = true
	else:
		challenge_info_lbl.text = "Today's mission: LEVEL %d\nSneak past Granny and grab every item!\nReward: +%d BONUS COINS" % [lvl, bonus]
		challenge_play_btn.text = "▶  PLAY CHALLENGE"
		challenge_play_btn.disabled = false


func _capture_all_popups() -> void:
	if GameManager != null:
		GameManager.home_support_shown_this_launch = true
	_on_loading_finished()
	await get_tree().create_timer(0.8).timeout
	var out_dir := OS.get_user_data_dir().path_join("popup_shots")
	DirAccess.make_dir_recursive_absolute(out_dir)
	var shots: Array[String] = []
	for kind in ["rate", "share", "coffee"]:
		var sup = (load("res://scenes/popups/support_popup.gd") as Script).new()
		sup.forced_kind = kind
		add_child(sup)
		await get_tree().create_timer(0.6).timeout
		shots.append(_save_shot(out_dir, "1_support_%s.png" % kind))
		sup.queue_free()
		await get_tree().process_frame
	_open_shop_tab("store")
	await get_tree().create_timer(0.6).timeout
	shots.append(_save_shot(out_dir, "2_store_coins_1000_2000_3000.png"))
	shop_popup.queue_free()
	shop_popup = null
	await get_tree().process_frame
	_refresh_daily_panel()
	_open_inline_popup(daily_popup)
	await get_tree().create_timer(0.6).timeout
	shots.append(_save_shot(out_dir, "3_daily_reward_7_days.png"))
	daily_popup.visible = false
	_refresh_challenge_panel()
	_open_inline_popup(challenge_popup)
	await get_tree().create_timer(0.6).timeout
	shots.append(_save_shot(out_dir, "4_daily_challenge.png"))
	print("ALL_POPUP_SHOTS: ", out_dir)
	get_tree().quit()


func _save_shot(dir: String, filename: String) -> String:
	var img := get_viewport().get_texture().get_image()
	var path := dir.path_join(filename)
	if img:
		img.save_png(path)
	return path


func _open_inline_popup(overlay: Control) -> void:
	if not is_instance_valid(overlay):
		return
	overlay.visible = true
	var dim: ColorRect = overlay.get_child(0)
	dim.modulate.a = 0.0
	var dtw := dim.create_tween()
	dtw.tween_property(dim, "modulate:a", 1.0, 0.16)
	var center := overlay.get_child(1)
	if center.get_child_count() > 0:
		var card: Control = center.get_child(0)
		card.pivot_offset = card.size * 0.5
		card.scale = Vector2(0.42, 0.42)
		card.modulate.a = 0.0
		var tw := card.create_tween()
		tw.tween_property(card, "modulate:a", 1.0, 0.12)
		tw.parallel().tween_property(card, "scale", Vector2(1.06, 0.95), 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(card, "scale", Vector2(0.98, 1.02), 0.09)
		tw.tween_property(card, "scale", Vector2.ONE, 0.08)


func _close_inline_popup(overlay: Control) -> void:
	if not is_instance_valid(overlay) or not overlay.visible:
		return
	var dim: ColorRect = overlay.get_child(0)
	var center := overlay.get_child(1)
	if center.get_child_count() > 0:
		var card: Control = center.get_child(0)
		card.pivot_offset = card.size * 0.5
		var tw := card.create_tween()
		tw.tween_property(card, "scale", Vector2(1.05, 1.05), 0.06)
		tw.tween_property(card, "scale", Vector2(0.35, 0.35), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(card, "modulate:a", 0.0, 0.14)
		tw.parallel().tween_property(dim, "modulate:a", 0.0, 0.14)
		tw.tween_callback(func():
			overlay.visible = false
			card.scale = Vector2.ONE
			card.modulate.a = 1.0
		)
	else:
		overlay.visible = false


func _open_shop_tab(tab_key: String) -> void:
	if is_instance_valid(shop_popup):
		if shop_popup.has_method("open_tab"):
			shop_popup.open_tab(tab_key)
		return
	if SoundManager != null:
		SoundManager.play_sfx("button")
	var shop_script := load("res://scenes/popups/shop_popup.gd") as Script
	if shop_script != null:
		shop_popup = shop_script.new()
		shop_popup.initial_tab = tab_key
		shop_popup.closed.connect(func():
			shop_popup = null
			_refresh_badges()
		)
		add_child(shop_popup)


func _show_shop_popup() -> void:
	_open_shop_tab("store")


func _show_support_popup() -> void:
	if is_instance_valid(support_popup):
		return
	var sup_script := load("res://scenes/popups/support_popup.gd") as Script
	if sup_script != null:
		support_popup = sup_script.new()
		support_popup.closed.connect(func():
			support_popup = null
		)
		add_child(support_popup)


func _show_settings_popup() -> void:
	if is_instance_valid(settings_popup):
		return
	if SoundManager != null:
		SoundManager.play_sfx("button")
	var scene := load("res://scenes/popups/settings_popup.tscn") as PackedScene
	if scene != null:
		settings_popup = scene.instantiate()
		settings_popup.privacy_policy_requested.connect(func():
			_show_privacy_policy_popup()
		)
		settings_popup.closed.connect(func():
			settings_popup = null
		)
		add_child(settings_popup)


func _show_privacy_policy_popup() -> void:
	if is_instance_valid(privacy_popup):
		return
	var scene := load("res://scenes/popups/privacy_policy_popup.tscn") as PackedScene
	if scene != null:
		privacy_popup = scene.instantiate()
		privacy_popup.accepted.connect(func():
			if GameManager != null:
				GameManager.set_privacy_policy_accepted(true)
			privacy_popup = null
		)
		add_child(privacy_popup)


func _capture_privacy_and_quit() -> void:
	await get_tree().create_timer(0.8).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_privacy_policy.png")
			img.save_png(path)
			print("PRIVACY_POLICY_SCREENSHOT_SAVED")
	get_tree().quit()


func _start_game(_force_start: bool = false) -> void:
	print("SPLASH: starting game...")
	var ad_mgr = AdManager if AdManager != null else get_tree().root.get_node_or_null("AdManager")
	if ad_mgr != null and ad_mgr.has_method("set_gameplay_active"):
		ad_mgr.set_gameplay_active(true)
	if SoundManager != null:
		SoundManager.play_sfx("button")
	if game_scene == null and ResourceLoader.load_threaded_get_status(GAME_SCENE) == ResourceLoader.THREAD_LOAD_LOADED:
		game_scene = ResourceLoader.load_threaded_get(GAME_SCENE) as PackedScene
	if game_scene != null:
		get_tree().change_scene_to_packed(game_scene)
	else:
		get_tree().change_scene_to_file(GAME_SCENE)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER or event.keycode == KEY_SPACE:
			_start_game()
			get_viewport().set_input_as_handled()


# ============================================================================
# SHARED ARCADE WIDGET HELPERS
# ============================================================================
func _square_top_button(text: String, icon_tex: Texture2D, bg_col: Color, border_col: Color, sz: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.icon = icon_tex
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.add_theme_constant_override("icon_max_width", 42)
	btn.custom_minimum_size = sz
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = border_col
	st.set_border_width_all(3)
	st.border_width_bottom = 6
	st.set_corner_radius_all(16)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	_wire_button_juice(btn)
	return btn


func _pack_top_badge(title_txt: String, icon_tex: Texture2D, bg_col: Color, border_col: Color, tab_key: String) -> Button:
	var btn := Button.new()
	btn.text = title_txt
	btn.icon = icon_tex
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.add_theme_constant_override("icon_max_width", 40)
	btn.custom_minimum_size = Vector2(92, 88)
	if title_font != null:
		btn.add_theme_font_override("font", title_font)
	btn.add_theme_font_size_override("font_size", 16)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color("#0c1c26"))
	btn.add_theme_constant_override("outline_size", 5)
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = border_col
	st.set_border_width_all(3)
	st.border_width_bottom = 6
	st.set_corner_radius_all(16)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", st)
	btn.add_theme_stylebox_override("pressed", st)
	btn.pressed.connect(func():
		_open_shop_tab(tab_key)
	)
	_wire_button_juice(btn)
	return btn


func _currency_plus_bar(amount_txt: String, icon_tex: Texture2D, plus_col: Color, on_press: Callable) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(215, 56)
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.06, 0.12, 0.18, 0.92)
	st.border_color = Color("#0c1c26")
	st.set_border_width_all(3)
	st.set_corner_radius_all(14)
	st.content_margin_left = 8
	st.content_margin_right = 12
	st.content_margin_top = 6
	st.content_margin_bottom = 6
	p.add_theme_stylebox_override("panel", st)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.add_theme_constant_override("separation", 10)
	p.add_child(row)

	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(38, 38)
	if title_font != null:
		plus_btn.add_theme_font_override("font", title_font)
	plus_btn.add_theme_font_size_override("font_size", 24)
	plus_btn.add_theme_color_override("font_color", Color.WHITE)
	var ps := StyleBoxFlat.new()
	ps.bg_color = plus_col
	ps.set_corner_radius_all(9)
	plus_btn.add_theme_stylebox_override("normal", ps)
	plus_btn.add_theme_stylebox_override("hover", ps)
	plus_btn.add_theme_stylebox_override("pressed", ps)
	plus_btn.pressed.connect(on_press)
	row.add_child(plus_btn)

	var amt := Label.new()
	amt.name = "Amount"
	amt.text = amount_txt
	amt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font != null:
		amt.add_theme_font_override("font", title_font)
	amt.add_theme_font_size_override("font_size", 26)
	amt.add_theme_color_override("font_color", Color.WHITE)
	amt.add_theme_color_override("font_outline_color", Color("#0c1c26"))
	amt.add_theme_constant_override("outline_size", 6)
	row.add_child(amt)

	var ic := TextureRect.new()
	ic.texture = icon_tex
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.custom_minimum_size = Vector2(34, 34)
	row.add_child(ic)
	return p


func _dock_card(title_txt: String, icon_tex: Texture2D, bg_col: Color, on_press: Callable) -> Control:
	var root := Control.new()
	root.custom_minimum_size = Vector2(190, 148)
	root.size = Vector2(190, 148)

	var btn := Button.new()
	btn.name = "Button"
	btn.text = title_txt
	btn.icon = icon_tex
	btn.expand_icon = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.add_theme_constant_override("icon_max_width", 56)
	btn.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if title_font != null:
		btn.add_theme_font_override("font", title_font)
	btn.add_theme_font_size_override("font_size", 20)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color("#0c1c26"))
	btn.add_theme_constant_override("outline_size", 6)
	var st := StyleBoxFlat.new()
	st.bg_color = bg_col
	st.border_color = Color("#0c1c26")
	st.set_border_width_all(4)
	st.border_width_bottom = 8
	st.set_corner_radius_all(20)
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	var hv := st.duplicate() as StyleBoxFlat
	hv.bg_color = bg_col.lightened(0.10)
	btn.add_theme_stylebox_override("normal", st)
	btn.add_theme_stylebox_override("hover", hv)
	btn.add_theme_stylebox_override("pressed", hv)
	btn.pressed.connect(on_press)
	root.add_child(btn)

	var badge := PanelContainer.new()
	badge.name = "Badge"
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(158, -8)
	badge.size = Vector2(34, 34)
	var bs := StyleBoxFlat.new()
	bs.bg_color = Color("#e83b3b")
	bs.border_color = Color.WHITE
	bs.set_border_width_all(2)
	bs.set_corner_radius_all(10)
	badge.add_theme_stylebox_override("panel", bs)
	var bl := Label.new()
	bl.text = "!"
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if title_font != null:
		bl.add_theme_font_override("font", title_font)
	bl.add_theme_font_size_override("font_size", 20)
	bl.add_theme_color_override("font_color", Color.WHITE)
	badge.add_child(bl)
	root.add_child(badge)
	_pulsing_badges.append(badge)
	_wire_button_juice(btn)
	return root


func _wire_button_juice(btn: Button) -> void:
	btn.button_down.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(0.91, 0.91), 0.06)
	)
	btn.button_up.connect(func():
		btn.pivot_offset = btn.size * 0.5
		var tw := btn.create_tween()
		tw.tween_property(btn, "scale", Vector2(1.06, 1.06), 0.09)
		tw.tween_property(btn, "scale", Vector2.ONE, 0.08)
	)


func _capture_screenshot_and_quit(filename: String) -> void:
	await get_tree().create_timer(0.6).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://" + filename)
			img.save_png(path)
			print("SCREENSHOT_SAVED: ", filename)
	get_tree().quit()


func _capture_and_quit() -> void:
	await get_tree().create_timer(1.2).timeout
	var vp := get_viewport()
	if vp:
		var img := vp.get_texture().get_image()
		if img:
			var path := ProjectSettings.globalize_path("res://screenshot_splash.png")
			img.save_png(path)
			print("SPLASH_SCREENSHOT_SAVED")
	get_tree().quit()


func _load_ui_texture(res_path: String) -> Texture2D:
	var global_path := ProjectSettings.globalize_path(res_path)
	if FileAccess.file_exists(global_path):
		var img := Image.load_from_file(global_path)
		if img and not img.is_empty():
			return ImageTexture.create_from_image(img)
	if ResourceLoader.exists(res_path):
		return load(res_path) as Texture2D
	return null
