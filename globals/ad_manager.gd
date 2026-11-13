extends Node
## AdManager - Google AdMob Manager for CandyBoy
## Supports Banner, Interstitial, and Rewarded Video Ads
## (Powered by Poing Studios AdMob v5 Plugin)

# Google AdMob Production Ad Unit IDs
const ADMOB_APP_ID: String = "ca-app-pub-1852108665659812~7826783344"
const BANNER_AD_ID: String = "ca-app-pub-1852108665659812/6246108366"
const INTERSTITIAL_AD_ID: String = "ca-app-pub-1852108665659812/4270360916"
const REWARDED_AD_ID: String = "ca-app-pub-1852108665659812/6322129982"

# Google Official Test Ad Unit IDs
const TEST_BANNER_AD_ID: String = "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_AD_ID: String = "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_AD_ID: String = "ca-app-pub-3940256099942544/5224354917"

# Signals
signal banner_loaded
signal banner_failed(err_msg: String)
signal interstitial_loaded
signal interstitial_dismissed
signal interstitial_failed(err_msg: String)
signal rewarded_ad_loaded
signal rewarded_ad_completed(amount: int, reward_type: String)
signal rewarded_ad_failed(err_msg: String)

static var instance: Node = null
static var is_initialized: bool = false
var _plugin_available: bool = false
var is_ads_removed: bool = false

# Cached Ad Objects
var _banner_view = null
var _banner_view_right = null
var _banner_view_left = null
var _banner_cb_right = null
var _banner_cb_left = null
var _interstitial_ad = null
var _rewarded_ad = null
var _is_banner_requested: bool = false
var _mock_banner_layer: CanvasLayer = null
var _mock_interstitial_layer: CanvasLayer = null
var _mock_rewarded_layer: CanvasLayer = null

# Persistent Callbacks (Kept alive in memory to prevent garbage collection)
var _init_listener = null
var _banner_cb = null
var _interstitial_cb = null
var _interstitial_content_cb = null
var _rewarded_load_cb = null
var _rewarded_content_cb = null
var _reward_listener = null

# Active pending reward callback
var _pending_reward_callback: Callable = Callable()

# Pause & Resume Tracking for Ads
var _was_game_paused_before_ad: bool = false
var _is_ad_showing: bool = false

# Interstitial Level Counter (e.g. show interstitial every 2 completed levels)
var levels_since_last_interstitial: int = 0
const INTERSTITIAL_LEVEL_INTERVAL: int = 2

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[AdManager] Initializing AdManager...")
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		_plugin_available = true
		print("[AdManager] Mobile platform detected: %s. Initializing MobileAds SDK..." % OS.get_name())
		_init_mobile_ads()
	else:
		_plugin_available = false
		print("[AdManager] Desktop/Editor environment detected. Ads will run in simulation mode.")

func _init_mobile_ads() -> void:
	if not _plugin_available:
		return

	if ClassDB.class_exists("MobileAds") or Engine.has_singleton("PoingGodotAdMob"):
		_init_listener = OnInitializationCompleteListener.new()
		_init_listener.on_initialization_complete = func(_status) -> void:
			print("[AdManager] MobileAds SDK successfully initialized!")
			is_initialized = true
			_load_banner()
			_load_interstitial()
			_load_rewarded()

		MobileAds.initialize(_init_listener)
	else:
		print("[AdManager] MobileAds native plugin not available in this build.")


func _pause_game_for_ad() -> void:
	if _is_ad_showing:
		return
	_is_ad_showing = true
	_was_game_paused_before_ad = get_tree().paused
	get_tree().paused = true
	if SoundManager != null:
		SoundManager.stop_or_duck_bgm(true)


func _resume_game_from_ad() -> void:
	if not _is_ad_showing:
		return
	_is_ad_showing = false
	get_tree().paused = _was_game_paused_before_ad
	if SoundManager != null and SoundManager.music_enabled:
		SoundManager.start_bgm()

# ==============================================================================
# 1. BANNER AD METHODS
# ==============================================================================

func _load_banner() -> void:
	if not _plugin_available or not is_initialized or is_ads_removed:
		return

	# 1. Right Side Banner Ad
	if _banner_view_right == null:
		print("[AdManager] Loading RIGHT banner ad: %s" % BANNER_AD_ID)
		_banner_view_right = AdView.new(BANNER_AD_ID, AdSize.BANNER, AdPosition.RIGHT)
		_banner_cb_right = AdListener.new()
		_banner_cb_right.on_ad_loaded = func():
			print("[AdManager] RIGHT Banner ad loaded successfully!")
			banner_loaded.emit()
			if _is_banner_requested and _banner_view_right != null and _banner_view_right.has_method("show"):
				_banner_view_right.show()
		_banner_cb_right.on_ad_failed_to_load = func(err):
			var err_str: String = str(err.message if "message" in err else err)
			print("[AdManager] RIGHT Banner ad failed to load: ", err_str)
			banner_failed.emit(err_str)
		_banner_view_right.ad_listener = _banner_cb_right
		_banner_view_right.load_ad(AdRequest.new())
		_banner_view = _banner_view_right

	# 2. Left Side Banner Ad
	if _banner_view_left == null:
		print("[AdManager] Loading LEFT banner ad: %s" % BANNER_AD_ID)
		_banner_view_left = AdView.new(BANNER_AD_ID, AdSize.BANNER, AdPosition.LEFT)
		_banner_cb_left = AdListener.new()
		_banner_cb_left.on_ad_loaded = func():
			print("[AdManager] LEFT Banner ad loaded successfully!")
			if _is_banner_requested and _banner_view_left != null and _banner_view_left.has_method("show"):
				_banner_view_left.show()
		_banner_cb_left.on_ad_failed_to_load = func(err):
			var err_str: String = str(err.message if "message" in err else err)
			print("[AdManager] LEFT Banner ad failed to load: ", err_str)
		_banner_view_left.ad_listener = _banner_cb_left
		_banner_view_left.load_ad(AdRequest.new())

# Intermittent Banner Timer Settings:
# Shows banner temporarily for 18 seconds, then hides it for 42 seconds!
const BANNER_VISIBLE_TIME: float = 18.0
const BANNER_HIDDEN_TIME: float = 42.0

var _is_banner_cycle_active: bool = false
var _banner_cycle_tween: Tween = null

func show_banner() -> void:
	if is_ads_removed:
		print("[AdManager] Banner not shown: Ads removed via IAP.")
		return

	_is_banner_requested = true
	if not _is_banner_cycle_active:
		_start_banner_interval_cycle()

func hide_banner() -> void:
	_is_banner_requested = false
	_stop_banner_interval_cycle()
	_apply_banner_visibility(false)

func _start_banner_interval_cycle() -> void:
	_is_banner_cycle_active = true
	_run_banner_cycle_step(true)

func _stop_banner_interval_cycle() -> void:
	_is_banner_cycle_active = false
	if _banner_cycle_tween != null and _banner_cycle_tween.is_valid():
		_banner_cycle_tween.kill()
		_banner_cycle_tween = null

func _run_banner_cycle_step(show_now: bool) -> void:
	if not _is_banner_requested or is_ads_removed or not _is_banner_cycle_active:
		_apply_banner_visibility(false)
		return

	_apply_banner_visibility(show_now)

	if _banner_cycle_tween != null and _banner_cycle_tween.is_valid():
		_banner_cycle_tween.kill()
	_banner_cycle_tween = create_tween()

	var wait_time: float = BANNER_VISIBLE_TIME if show_now else BANNER_HIDDEN_TIME
	_banner_cycle_tween.tween_interval(wait_time)
	_banner_cycle_tween.tween_callback(func():
		if _is_banner_requested and not is_ads_removed and _is_banner_cycle_active:
			_run_banner_cycle_step(not show_now)
	)

func _apply_banner_visibility(is_visible: bool) -> void:
	if not _plugin_available:
		if is_visible:
			_show_mock_desktop_banner()
		else:
			if is_instance_valid(_mock_banner_layer):
				_mock_banner_layer.visible = false
		return

	if not is_initialized:
		if is_visible and (_banner_view_right == null or _banner_view_left == null):
			_load_banner()
		return

	if _banner_view_right == null or _banner_view_left == null:
		if is_visible:
			_load_banner()

	if is_visible:
		if _banner_view_right != null and _banner_view_right.has_method("show"):
			_banner_view_right.show()
		if _banner_view_left != null and _banner_view_left.has_method("show"):
			_banner_view_left.show()
	else:
		if _banner_view_right != null and _banner_view_right.has_method("hide"):
			_banner_view_right.hide()
		if _banner_view_left != null and _banner_view_left.has_method("hide"):
			_banner_view_left.hide()

func _show_mock_desktop_banner() -> void:
	if is_ads_removed:
		return
	if is_instance_valid(_mock_banner_layer):
		_mock_banner_layer.visible = true
		return

	_mock_banner_layer = CanvasLayer.new()
	_mock_banner_layer.layer = 120
	_mock_banner_layer.name = "MockBannerLayer"
	add_child(_mock_banner_layer)

	# 1. Left Side Banner
	var left_box := PanelContainer.new()
	left_box.custom_minimum_size = Vector2(48, 220)
	left_box.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left_box.offset_left = 6
	left_box.offset_right = 54
	left_box.offset_top = 220
	left_box.offset_bottom = -220
	left_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var l_style := StyleBoxFlat.new()
	l_style.bg_color = Color(0.10, 0.12, 0.16, 0.95)
	l_style.border_color = Color("#f1c40f")
	l_style.border_width_right = 2
	l_style.corner_radius_top_right = 8
	l_style.corner_radius_bottom_right = 8
	left_box.add_theme_stylebox_override("panel", l_style)

	var l_vbox := VBoxContainer.new()
	l_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	l_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_box.add_child(l_vbox)

	var l_badge := Label.new()
	l_badge.text = "[Ad]\nLeft\nBanner"
	l_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l_badge.add_theme_color_override("font_color", Color("#ecf0f1"))
	l_badge.add_theme_font_size_override("font_size", 12)
	l_vbox.add_child(l_badge)
	_mock_banner_layer.add_child(left_box)

	# 2. Right Side Banner
	var right_box := PanelContainer.new()
	right_box.custom_minimum_size = Vector2(48, 220)
	right_box.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right_box.offset_left = -54
	right_box.offset_right = -6
	right_box.offset_top = 220
	right_box.offset_bottom = -220
	right_box.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var r_style := StyleBoxFlat.new()
	r_style.bg_color = Color(0.10, 0.12, 0.16, 0.95)
	r_style.border_color = Color("#f1c40f")
	r_style.border_width_left = 2
	r_style.corner_radius_top_left = 8
	r_style.corner_radius_bottom_left = 8
	right_box.add_theme_stylebox_override("panel", r_style)

	var r_vbox := VBoxContainer.new()
	r_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	r_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right_box.add_child(r_vbox)

	var r_badge := Label.new()
	r_badge.text = "[Ad]\nRight\nBanner"
	r_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	r_badge.add_theme_color_override("font_color", Color("#ecf0f1"))
	r_badge.add_theme_font_size_override("font_size", 12)
	r_vbox.add_child(r_badge)
	_mock_banner_layer.add_child(right_box)

# ==============================================================================
# 2. INTERSTITIAL AD METHODS
# ==============================================================================

func _load_interstitial() -> void:
	if not _plugin_available or not is_initialized or is_ads_removed or _interstitial_ad != null:
		return

	var loader := InterstitialAdLoader.new()
	_interstitial_cb = InterstitialAdLoadCallback.new()

	_interstitial_cb.on_ad_loaded = func(ad: InterstitialAd) -> void:
		_interstitial_ad = ad
		print("[AdManager] Interstitial ad loaded and cached!")
		interstitial_loaded.emit()

		_interstitial_content_cb = FullScreenContentCallback.new()
		_interstitial_content_cb.on_ad_dismissed_full_screen_content = func():
			print("[AdManager] Interstitial ad dismissed by user.")
			_interstitial_ad = null
			_resume_game_from_ad()
			interstitial_dismissed.emit()
			# Automatically preload the next interstitial
			_load_interstitial()

		_interstitial_content_cb.on_ad_failed_to_show_full_screen_content = func(err):
			var err_str: String = str(err.message if "message" in err else err)
			print("[AdManager] Interstitial ad failed to show: ", err_str)
			_interstitial_ad = null
			_resume_game_from_ad()
			interstitial_failed.emit(err_str)
			_load_interstitial()

		_interstitial_ad.full_screen_content_callback = _interstitial_content_cb

	_interstitial_cb.on_ad_failed_to_load = func(err) -> void:
		_interstitial_ad = null
		var err_str: String = str(err.message if "message" in err else err)
		print("[AdManager] Interstitial failed to load: ", err_str)
		interstitial_failed.emit(err_str)
		if not is_ads_removed and is_instance_valid(instance):
			var tw := instance.create_tween()
			tw.tween_interval(30.0)
			tw.tween_callback(func():
				if _interstitial_ad == null and not is_ads_removed:
					_load_interstitial()
			)

	loader.load(INTERSTITIAL_AD_ID, AdRequest.new(), _interstitial_cb)

func show_interstitial() -> bool:
	if is_ads_removed:
		return false
	if not _plugin_available:
		print("[AdManager-Mock] show_interstitial() invoked (desktop simulation).")
		_pause_game_for_ad()
		if is_instance_valid(instance):
			var tw := instance.create_tween()
			tw.tween_interval(0.6)
			tw.tween_callback(func():
				_resume_game_from_ad()
				interstitial_dismissed.emit()
			)
		else:
			_resume_game_from_ad()
			interstitial_dismissed.emit()
		return true

	if _interstitial_ad != null:
		print("[AdManager] Displaying Interstitial Ad...")
		_pause_game_for_ad()
		_interstitial_ad.show()
		return true
	else:
		print("[AdManager] Interstitial ad not ready yet, preloading now...")
		if is_initialized:
			_load_interstitial()
		return false

## Helper to show interstitial every N levels (e.g. on victory)
func on_level_finished_check_interstitial(force_show: bool = false) -> bool:
	levels_since_last_interstitial += 1
	if force_show or levels_since_last_interstitial >= INTERSTITIAL_LEVEL_INTERVAL:
		levels_since_last_interstitial = 0
		return show_interstitial()
	return false

# ==============================================================================
# 3. REWARDED VIDEO AD METHODS
# ==============================================================================

func _load_rewarded() -> void:
	if not _plugin_available or not is_initialized or _rewarded_ad != null:
		return

	var loader := RewardedAdLoader.new()
	_rewarded_load_cb = RewardedAdLoadCallback.new()

	_rewarded_load_cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_rewarded_ad = ad
		print("[AdManager] Rewarded Ad loaded and ready!")
		rewarded_ad_loaded.emit()

		_rewarded_content_cb = FullScreenContentCallback.new()
		_rewarded_content_cb.on_ad_dismissed_full_screen_content = func():
			print("[AdManager] Rewarded Ad full screen dismissed.")
			_rewarded_ad = null
			_resume_game_from_ad()
			_load_rewarded()

		_rewarded_content_cb.on_ad_failed_to_show_full_screen_content = func(err):
			var err_str: String = str(err.message if "message" in err else err)
			print("[AdManager] Rewarded Ad failed to show: ", err_str)
			_rewarded_ad = null
			_resume_game_from_ad()
			rewarded_ad_failed.emit(err_str)
			_load_rewarded()

		_rewarded_ad.full_screen_content_callback = _rewarded_content_cb

	_rewarded_load_cb.on_ad_failed_to_load = func(err) -> void:
		_rewarded_ad = null
		var err_str: String = str(err.message if "message" in err else err)
		print("[AdManager] Rewarded Ad failed to load: ", err_str)
		rewarded_ad_failed.emit(err_str)
		if is_instance_valid(instance):
			var tw := instance.create_tween()
			tw.tween_interval(25.0)
			tw.tween_callback(func():
				if _rewarded_ad == null:
					_load_rewarded()
			)

	loader.load(REWARDED_AD_ID, AdRequest.new(), _rewarded_load_cb)

## Shows the Rewarded Video.
## Calls the provided on_reward_earned callback when user finishes watching.
func show_rewarded(on_reward_earned: Callable = Callable()) -> bool:
	_pending_reward_callback = on_reward_earned
	_pause_game_for_ad()

	if not _plugin_available:
		print("[AdManager-Mock] show_rewarded() called in desktop mode. Simulating reward after 0.8s...")
		if is_instance_valid(instance):
			var tw := instance.create_tween()
			tw.tween_interval(0.8)
			tw.tween_callback(func():
				_resume_game_from_ad()
				_grant_reward(10, "coins")
			)
		else:
			_resume_game_from_ad()
			_grant_reward(10, "coins")
		return true

	if _rewarded_ad != null:
		print("[AdManager] Showing Rewarded Video Ad...")
		_reward_listener = OnUserEarnedRewardListener.new()
		_reward_listener.on_user_earned_reward = func(reward_item):
			var amt: int = reward_item.amount if reward_item else 10
			var type: String = reward_item.type if reward_item else "coins"
			_grant_reward(amt, type)

		_rewarded_ad.show(_reward_listener)
		return true
	else:
		_resume_game_from_ad()
		print("[AdManager] Rewarded Ad not ready yet. Preloading...")
		rewarded_ad_failed.emit("Rewarded ad is loading, please try again in a few seconds!")
		if is_initialized:
			_load_rewarded()
		return false

func _grant_reward(amount: int, reward_type: String) -> void:
	print("[AdManager] Reward Granted! Amount: %d, Type: %s" % [amount, reward_type])
	if _pending_reward_callback.is_valid():
		_pending_reward_callback.call(amount, reward_type)
		_pending_reward_callback = Callable()

	rewarded_ad_completed.emit(amount, reward_type)

func is_rewarded_ready() -> bool:
	if not _plugin_available:
		return true # Always mock ready on desktop
	return _rewarded_ad != null

# ==============================================================================
# 4. REMOVE ADS (IAP INTEGRATION - $4.99)
# ==============================================================================

func remove_all_ads() -> void:
	is_ads_removed = true
	hide_banner()
	if _banner_view_right and _banner_view_right.has_method("destroy"):
		_banner_view_right.destroy()
		_banner_view_right = null
	if _banner_view_left and _banner_view_left.has_method("destroy"):
		_banner_view_left.destroy()
		_banner_view_left = null
	_banner_view = null
	_interstitial_ad = null
	print("[AdManager] Banner & Interstitial ads removed permanently ($4.99). Rewarded ads remain active.")
