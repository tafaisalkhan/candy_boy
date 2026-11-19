extends Node
## AdManager - Google AdMob Manager for CandyBoy
## Supports Banner, Interstitial, and Rewarded Video Ads
## (Powered by Poing Studios AdMob v5 Plugin)

# Google Official Test Ad Unit IDs (production IDs are loaded from gitignored res://admob_secrets.gd)
const ADMOB_APP_ID: String = "ca-app-pub-3940256099942544~3347511713"
const BANNER_AD_ID: String = "ca-app-pub-3940256099942544/6300978111"
const INTERSTITIAL_AD_ID: String = "ca-app-pub-3940256099942544/1033173712"
const REWARDED_AD_ID: String = "ca-app-pub-3940256099942544/5224354917"

# Google Official Test Ad Unit IDs
const TEST_BANNER_AD_ID: String = "ca-app-pub-3940256099942544/6300978111"
const TEST_INTERSTITIAL_AD_ID: String = "ca-app-pub-3940256099942544/1033173712"
const TEST_REWARDED_AD_ID: String = "ca-app-pub-3940256099942544/5224354917"

const GOOGLE_TEST_PREFIX: String = "ca-app-pub-3940256099942544"
const PRODUCT_REMOVE_ADS: String = "remove_ads"
const PRODUCT_COFFEE: String = "cofee"
const PLAY_STORE_URL: String = "https://play.google.com/store/apps/details?id=com.candyboy.boyfavoritecollection"
const SHOP_PACKS := {
	"coins_1000": {"coins": 1000, "price": "$0.99", "title": "1,000 COINS"},
	"coins_2000": {"coins": 2000, "price": "$1.29", "title": "2,000 COINS"},
	"coins_3000": {"coins": 3000, "price": "$1.99", "title": "3,000 COINS"},
}

var _banner_ad_id: String = BANNER_AD_ID
var _interstitial_ad_id: String = INTERSTITIAL_AD_ID
var _rewarded_ad_id: String = REWARDED_AD_ID

# Signals
signal banner_loaded
signal banner_failed(err_msg: String)
signal interstitial_loaded
signal interstitial_dismissed
signal interstitial_failed(err_msg: String)
signal rewarded_ad_loaded
signal rewarded_ad_completed(amount: int, reward_type: String)
signal rewarded_ad_failed(err_msg: String)
signal rewarded_ready_changed(ready: bool)
signal no_fill_changed(no_fill: bool)
signal purchase_state_changed(owned: bool, message: String)
signal pack_purchase_verified(coins: int, message: String)
signal coffee_purchased(message: String)

static var instance: Node = null
static var is_initialized: bool = false
var _plugin_available: bool = false
var is_ads_removed: bool = false
var no_fill_this_launch: bool = false
var rewarded_ready: bool = false

# Cached Ad Objects
var _banner_view = null
var _banner_view_top = null
var _banner_view_bottom = null
var _top_banner_loaded: bool = false
var _bottom_banner_loaded: bool = false
var _banner_cb_top = null
var _banner_cb_bottom = null
var _interstitial_ad = null
var _rewarded_ad = null
var _is_banner_requested: bool = false
var _show_top_banner: bool = false
var _show_bottom_banner: bool = false
var _mock_banner_layer: CanvasLayer = null
var _mock_top_banner: PanelContainer = null
var _mock_bottom_banner: PanelContainer = null
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

# Interstitial Level Counter (show interstitial at every level end)
var levels_since_last_interstitial: int = 0
const INTERSTITIAL_LEVEL_INTERVAL: int = 1

func _enter_tree() -> void:
	instance = self

func _load_local_ad_ids() -> void:
	if ResourceLoader.exists("res://admob_secrets.gd"):
		var secrets = load("res://admob_secrets.gd")
		if secrets != null:
			if "BANNER_AD_ID" in secrets and not str(secrets.BANNER_AD_ID).is_empty():
				_banner_ad_id = str(secrets.BANNER_AD_ID)
			if "INTERSTITIAL_AD_ID" in secrets and not str(secrets.INTERSTITIAL_AD_ID).is_empty():
				_interstitial_ad_id = str(secrets.INTERSTITIAL_AD_ID)
			if "REWARDED_AD_ID" in secrets and not str(secrets.REWARDED_AD_ID).is_empty():
				_rewarded_ad_id = str(secrets.REWARDED_AD_ID)
			print("[AdManager] Loaded local AdMob IDs from res://admob_secrets.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_local_ad_ids()
	print("[AdManager] Initializing AdManager...")
	call_deferred("_startup_services")

func _is_test_ad_id(ad_id: String) -> bool:
	return ad_id.begins_with(GOOGLE_TEST_PREFIX)

func _mark_no_fill(reason: String) -> void:
	if not no_fill_this_launch:
		no_fill_this_launch = true
		push_warning("[AdManager] No-fill active: %s" % reason)
		hide_banner()
		if _banner_view_top and _banner_view_top.has_method("destroy"):
			_banner_view_top.destroy()
			_banner_view_top = null
		if _banner_view_bottom and _banner_view_bottom.has_method("destroy"):
			_banner_view_bottom.destroy()
			_banner_view_bottom = null
		_top_banner_loaded = false
		_bottom_banner_loaded = false
		no_fill_changed.emit(true)
	if rewarded_ready:
		rewarded_ready = false
		rewarded_ready_changed.emit(false)

func _startup_services() -> void:
	if not is_inside_tree():
		return
	if _is_test_ad_id(_banner_ad_id) or _is_test_ad_id(_interstitial_ad_id) or _is_test_ad_id(_rewarded_ad_id):
		_plugin_available = false
		_mark_no_fill("test AdMob IDs detected — blocking ads")
		return
	if OS.get_name() == "Android" or OS.get_name() == "iOS":
		_plugin_available = true
		print("[AdManager] Mobile platform detected: %s. Initializing MobileAds SDK..." % OS.get_name())
		_init_mobile_ads()
	else:
		_plugin_available = false
		_mark_no_fill("desktop environment — live ads disabled")

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

	# 1. Top Banner Ad
	if _banner_view_top == null:
		print("[AdManager] Loading TOP banner ad: %s" % _banner_ad_id)
		_top_banner_loaded = false
		_banner_view_top = AdView.new(_banner_ad_id, AdSize.BANNER, AdPosition.TOP)
		if _banner_view_top.has_method("hide"):
			_banner_view_top.hide()
		_banner_cb_top = AdListener.new()
		_banner_cb_top.on_ad_loaded = func():
			print("[AdManager] TOP Banner ad loaded successfully!")
			_top_banner_loaded = true
			banner_loaded.emit()
			if _show_top_banner and not is_ads_removed and not no_fill_this_launch and _banner_view_top != null and _banner_view_top.has_method("show"):
				_banner_view_top.show()
			elif _banner_view_top != null and _banner_view_top.has_method("hide"):
				_banner_view_top.hide()
		_banner_cb_top.on_ad_failed_to_load = func(err):
			var err_str: String = str(err.message if "message" in err else err)
			print("[AdManager] TOP Banner ad failed to load: ", err_str)
			_mark_no_fill("top banner failed: %s" % err_str)
			banner_failed.emit(err_str)
		_banner_view_top.ad_listener = _banner_cb_top
		_banner_view_top.load_ad(AdRequest.new())
		_banner_view = _banner_view_top

	# 2. Bottom Banner Ad
	if _banner_view_bottom == null:
		print("[AdManager] Loading BOTTOM banner ad: %s" % _banner_ad_id)
		_bottom_banner_loaded = false
		_banner_view_bottom = AdView.new(_banner_ad_id, AdSize.BANNER, AdPosition.BOTTOM)
		if _banner_view_bottom.has_method("hide"):
			_banner_view_bottom.hide()
		_banner_cb_bottom = AdListener.new()
		_banner_cb_bottom.on_ad_loaded = func():
			print("[AdManager] BOTTOM Banner ad loaded successfully!")
			_bottom_banner_loaded = true
			if _show_bottom_banner and not is_ads_removed and not no_fill_this_launch and _banner_view_bottom != null and _banner_view_bottom.has_method("show"):
				_banner_view_bottom.show()
			elif _banner_view_bottom != null and _banner_view_bottom.has_method("hide"):
				_banner_view_bottom.hide()
		_banner_cb_bottom.on_ad_failed_to_load = func(err):
			var err_str: String = str(err.message if "message" in err else err)
			print("[AdManager] BOTTOM Banner ad failed to load: ", err_str)
			_mark_no_fill("bottom banner failed: %s" % err_str)
		_banner_view_bottom.ad_listener = _banner_cb_bottom
		_banner_view_bottom.load_ad(AdRequest.new())

const GAMEPLAY_TOP_BANNER_DURATION: float = 5.0
var _gameplay_banner_tween: Tween = null

func _stop_gameplay_banner_timer() -> void:
	if _gameplay_banner_tween != null and _gameplay_banner_tween.is_valid():
		_gameplay_banner_tween.kill()
		_gameplay_banner_tween = null

# Non-gameplay screens: continue showing BOTH top and bottom banner ads
func show_banner() -> void:
	if is_ads_removed or no_fill_this_launch:
		hide_banner()
		return
	_stop_gameplay_banner_timer()
	_is_banner_requested = true
	_show_top_banner = true
	_show_bottom_banner = true
	_apply_banner_visibility(true, true)

# Active gameplay: show ONLY top banner and hide/show it every 5 seconds
func show_gameplay_banner() -> void:
	if is_ads_removed or no_fill_this_launch:
		hide_banner()
		return
	_stop_gameplay_banner_timer()
	_is_banner_requested = true
	_show_top_banner = true
	_show_bottom_banner = false
	_apply_banner_visibility(true, false)

	_gameplay_banner_tween = create_tween()
	_gameplay_banner_tween.set_loops()
	_gameplay_banner_tween.tween_interval(GAMEPLAY_TOP_BANNER_DURATION)
	_gameplay_banner_tween.tween_callback(func():
		if not is_ads_removed:
			_show_top_banner = false
			_show_bottom_banner = false
			_apply_banner_visibility(false, false)
	)
	_gameplay_banner_tween.tween_interval(GAMEPLAY_TOP_BANNER_DURATION)
	_gameplay_banner_tween.tween_callback(func():
		if not is_ads_removed:
			_show_top_banner = true
			_show_bottom_banner = false
			_apply_banner_visibility(true, false)
	)

func hide_banner() -> void:
	_stop_gameplay_banner_timer()
	_is_banner_requested = false
	_show_top_banner = false
	_show_bottom_banner = false
	_apply_banner_visibility(false, false)

func _apply_banner_visibility(show_top: bool, show_bottom: bool) -> void:
	if not _plugin_available:
		if show_top or show_bottom:
			_show_mock_desktop_banner(show_top, show_bottom)
		elif is_instance_valid(_mock_banner_layer):
			_mock_banner_layer.visible = false
		return

	if not is_initialized:
		if (show_top or show_bottom) and (_banner_view_top == null or _banner_view_bottom == null):
			_load_banner()
		return

	if _banner_view_top == null or _banner_view_bottom == null:
		if show_top or show_bottom:
			_load_banner()

	if _banner_view_top != null:
		if show_top and _top_banner_loaded and not no_fill_this_launch and not is_ads_removed and _banner_view_top.has_method("show"):
			_banner_view_top.show()
		elif _banner_view_top.has_method("hide"):
			_banner_view_top.hide()

	if _banner_view_bottom != null:
		if show_bottom and _bottom_banner_loaded and not no_fill_this_launch and not is_ads_removed and _banner_view_bottom.has_method("show"):
			_banner_view_bottom.show()
		elif _banner_view_bottom.has_method("hide"):
			_banner_view_bottom.hide()

func _show_mock_desktop_banner(show_top: bool = true, show_bottom: bool = true) -> void:
	if is_ads_removed:
		return
	if not is_instance_valid(_mock_banner_layer):
		_mock_banner_layer = CanvasLayer.new()
		_mock_banner_layer.layer = 120
		_mock_banner_layer.name = "MockBannerLayer"
		add_child(_mock_banner_layer)

		# 1. Top Banner
		_mock_top_banner = _create_mock_banner_panel("[Ad] Top Banner", true)
		_mock_banner_layer.add_child(_mock_top_banner)

		# 2. Bottom Banner
		_mock_bottom_banner = _create_mock_banner_panel("[Ad] Bottom Banner", false)
		_mock_banner_layer.add_child(_mock_bottom_banner)

	_mock_banner_layer.visible = show_top or show_bottom
	if is_instance_valid(_mock_top_banner):
		_mock_top_banner.visible = show_top
	if is_instance_valid(_mock_bottom_banner):
		_mock_bottom_banner.visible = show_bottom

func _create_mock_banner_panel(label_text: String, is_top: bool) -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(360, 54)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if is_top:
		box.set_anchors_preset(Control.PRESET_CENTER_TOP)
		box.offset_left = -180
		box.offset_right = 180
		box.offset_top = 4
		box.offset_bottom = 58
	else:
		box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		box.offset_left = -180
		box.offset_right = 180
		box.offset_top = -58
		box.offset_bottom = -4

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.12, 0.16, 0.95)
	style.border_color = Color("#f1c40f")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	box.add_theme_stylebox_override("panel", style)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color("#ecf0f1"))
	lbl.add_theme_font_size_override("font_size", 14)
	box.add_child(lbl)
	return box

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
		_mark_no_fill("interstitial failed: %s" % err_str)
		interstitial_failed.emit(err_str)

	loader.load(_interstitial_ad_id, AdRequest.new(), _interstitial_cb)

func show_interstitial() -> bool:
	if is_ads_removed or no_fill_this_launch:
		return false
	if not _plugin_available:
		return false

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
		rewarded_ready = not no_fill_this_launch
		print("[AdManager] Rewarded Ad loaded and ready!")
		rewarded_ad_loaded.emit()
		rewarded_ready_changed.emit(rewarded_ready)

		_rewarded_content_cb = FullScreenContentCallback.new()
		_rewarded_content_cb.on_ad_dismissed_full_screen_content = func():
			print("[AdManager] Rewarded Ad full screen dismissed.")
			_rewarded_ad = null
			rewarded_ready = false
			rewarded_ready_changed.emit(false)
			_resume_game_from_ad()
			_load_rewarded()

		_rewarded_content_cb.on_ad_failed_to_show_full_screen_content = func(err):
			var err_str: String = str(err.message if "message" in err else err)
			print("[AdManager] Rewarded Ad failed to show: ", err_str)
			_rewarded_ad = null
			rewarded_ready = false
			rewarded_ready_changed.emit(false)
			_resume_game_from_ad()
			rewarded_ad_failed.emit(err_str)
			_load_rewarded()

		_rewarded_ad.full_screen_content_callback = _rewarded_content_cb

	_rewarded_load_cb.on_ad_failed_to_load = func(err) -> void:
		_rewarded_ad = null
		var err_str: String = str(err.message if "message" in err else err)
		print("[AdManager] Rewarded Ad failed to load: ", err_str)
		_mark_no_fill("rewarded failed: %s" % err_str)
		rewarded_ad_failed.emit(err_str)

	loader.load(_rewarded_ad_id, AdRequest.new(), _rewarded_load_cb)

## Shows the Rewarded Video.
## Calls the provided on_reward_earned callback when user finishes watching.
func show_rewarded(on_reward_earned: Callable = Callable()) -> bool:
	if no_fill_this_launch or not is_rewarded_ready():
		return false
	_pending_reward_callback = on_reward_earned
	_pause_game_for_ad()

	if _rewarded_ad != null:
		print("[AdManager] Showing Rewarded Video Ad...")
		rewarded_ready = false
		rewarded_ready_changed.emit(false)
		_reward_listener = OnUserEarnedRewardListener.new()
		_reward_listener.on_user_earned_reward = func(reward_item):
			var amt: int = reward_item.amount if reward_item else 10
			var type: String = reward_item.type if reward_item else "coins"
			_grant_reward(amt, type)

		_rewarded_ad.show(_reward_listener)
		return true
	else:
		_resume_game_from_ad()
		return false

func _grant_reward(amount: int, reward_type: String) -> void:
	print("[AdManager] Reward Granted! Amount: %d, Type: %s" % [amount, reward_type])
	if _pending_reward_callback.is_valid():
		_pending_reward_callback.call(amount, reward_type)
		_pending_reward_callback = Callable()

	rewarded_ad_completed.emit(amount, reward_type)

func is_rewarded_ready() -> bool:
	if no_fill_this_launch or not _plugin_available:
		return false
	return rewarded_ready and _rewarded_ad != null

# ==============================================================================
# 4. REMOVE ADS (IAP INTEGRATION - $4.99)
# ==============================================================================

func remove_all_ads() -> void:
	is_ads_removed = true
	hide_banner()
	if _banner_view_top and _banner_view_top.has_method("destroy"):
		_banner_view_top.destroy()
		_banner_view_top = null
	if _banner_view_bottom and _banner_view_bottom.has_method("destroy"):
		_banner_view_bottom.destroy()
		_banner_view_bottom = null
	_banner_view = null
	_interstitial_ad = null
	print("[AdManager] Banner & Interstitial ads removed permanently ($4.99). Rewarded ads remain active.")

func purchase_available() -> bool:
	return false

func request_pack_purchase(pack_id: String) -> void:
	if not SHOP_PACKS.has(pack_id):
		return
	pack_purchase_verified.emit(0, "Google Play Billing is unavailable in this build.")

func request_coffee_purchase() -> void:
	coffee_purchased.emit("Google Play Billing is unavailable in this build.")

func request_remove_ads() -> void:
	purchase_state_changed.emit(is_ads_removed, "Google Play Billing is unavailable in this build.")

func restore_purchases() -> void:
	purchase_state_changed.emit(is_ads_removed, "No previous purchases found on this device.")

func check_in_app_update() -> void:
	if OS.get_name() == "Android" and Engine.has_singleton("CandyBoyAppPlugin"):
		Engine.get_singleton("CandyBoyAppPlugin").call("check_in_app_update")

func rate_app() -> void:
	if OS.get_name() == "Android" and Engine.has_singleton("CandyBoyAppPlugin"):
		Engine.get_singleton("CandyBoyAppPlugin").call("request_in_app_review", PLAY_STORE_URL)
	else:
		OS.shell_open(PLAY_STORE_URL)

func share_game() -> void:
	var share_text := "I'm playing Boy Favorite Collection! Can you sneak past Granny? %s" % PLAY_STORE_URL
	if OS.get_name() == "Android" and Engine.has_singleton("CandyBoyAppPlugin"):
		Engine.get_singleton("CandyBoyAppPlugin").call("share_text", share_text)
	else:
		DisplayServer.clipboard_set(share_text)
