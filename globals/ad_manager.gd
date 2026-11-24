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

# Interstitial Level Counter & Policy Pacing
# - Interstitial frequency:               Every 3 completed levels (INTERSTITIAL_LEVEL_INTERVAL = 3)
# - Minimum interval between interstitials: 120 seconds (MIN_INTERSTITIAL_INTERVAL_SEC = 120.0)
# - Maximum interstitials per hour:       10 (MAX_INTERSTITIALS_PER_HOUR = 10, rolling 3600s window)
# - Banner:                               One per screen, away from controls (bottom banner only on non-gameplay screens)
# - Banner refresh:                       AdMob-managed automatic refresh
# - Rewarded ads:                         User-initiated only
# - First-level interstitial:             Disabled
# - Ads during gameplay:                  Disabled
# - Failed ad loading:                    Retry with exponential backoff (2s -> 64s, max 6 attempts)
var levels_since_last_interstitial: int = 0
const INTERSTITIAL_LEVEL_INTERVAL: int = 3
const MIN_INTERSTITIAL_INTERVAL_SEC: float = 120.0
const MAX_INTERSTITIALS_PER_HOUR: int = 10
const ROLLING_HOUR_SEC: float = 3600.0
const BACKOFF_BASE_SEC: float = 2.0
const BACKOFF_MAX_SEC: float = 64.0
const BACKOFF_MAX_ATTEMPTS: int = 6

var last_interstitial_unix_sec: float = -999999.0
var interstitial_timestamps_sec: Array[float] = []
var gameplay_active: bool = false
var _banner_retry_attempt: int = 0
var _interstitial_retry_attempt: int = 0
var _rewarded_retry_attempt: int = 0

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
	call_deferred("_start_billing")

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
	var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
	if sm != null and sm.has_method("stop_or_duck_bgm"):
		sm.stop_or_duck_bgm(true)


func _resume_game_from_ad() -> void:
	if not _is_ad_showing:
		return
	_is_ad_showing = false
	get_tree().paused = _was_game_paused_before_ad
	var sm = get_tree().root.get_node_or_null("SoundManager") if is_inside_tree() else null
	if sm != null and sm.music_enabled:
		sm.start_bgm()

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

func _compute_backoff_delay(attempt: int) -> float:
	var exp_delay := minf(BACKOFF_MAX_SEC, BACKOFF_BASE_SEC * pow(2.0, float(clampi(attempt, 0, BACKOFF_MAX_ATTEMPTS))))
	return exp_delay + randf_range(0.0, 0.75)

func set_gameplay_active(active: bool) -> void:
	gameplay_active = active
	if gameplay_active:
		hide_banner()

# Non-gameplay screens: show ONLY ONE banner per screen (bottom banner, away from controls)
func show_banner() -> void:
	if is_ads_removed or no_fill_this_launch or gameplay_active:
		hide_banner()
		return
	_stop_gameplay_banner_timer()
	_is_banner_requested = true
	_show_top_banner = false
	_show_bottom_banner = true
	_apply_banner_visibility(false, true)

# Active gameplay: Ads during gameplay are strictly disabled per AdMob Policy Standard
func show_gameplay_banner() -> void:
	set_gameplay_active(true)
	hide_banner()

func hide_banner() -> void:
	_stop_gameplay_banner_timer()
	_is_banner_requested = false
	_show_top_banner = false
	_show_bottom_banner = false
	_apply_banner_visibility(false, false)

func _apply_banner_visibility(show_top: bool, show_bottom: bool) -> void:
	if not _plugin_available:
		if is_instance_valid(_mock_banner_layer):
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
		if _interstitial_retry_attempt < BACKOFF_MAX_ATTEMPTS and not is_ads_removed:
			var delay := _compute_backoff_delay(_interstitial_retry_attempt)
			_interstitial_retry_attempt += 1
			get_tree().create_timer(delay).timeout.connect(_load_interstitial)
		else:
			_mark_no_fill("interstitial failed: %s" % err_str)
		interstitial_failed.emit(err_str)

	loader.load(_interstitial_ad_id, AdRequest.new(), _interstitial_cb)

func _can_show_interstitial_now() -> bool:
	if is_ads_removed or no_fill_this_launch or gameplay_active or not _plugin_available:
		return false
	var now_sec := Time.get_unix_time_from_system()
	if (now_sec - last_interstitial_unix_sec) < MIN_INTERSTITIAL_INTERVAL_SEC:
		return false
	var cutoff := now_sec - ROLLING_HOUR_SEC
	for i in range(interstitial_timestamps_sec.size() - 1, -1, -1):
		if interstitial_timestamps_sec[i] < cutoff:
			interstitial_timestamps_sec.remove_at(i)
	if interstitial_timestamps_sec.size() >= MAX_INTERSTITIALS_PER_HOUR:
		return false
	return true

func show_interstitial() -> bool:
	if not _can_show_interstitial_now():
		return false

	if _interstitial_ad != null:
		print("[AdManager] Displaying Interstitial Ad...")
		var now_sec := Time.get_unix_time_from_system()
		last_interstitial_unix_sec = now_sec
		interstitial_timestamps_sec.append(now_sec)
		_pause_game_for_ad()
		_interstitial_ad.show()
		return true
	else:
		print("[AdManager] Interstitial ad not ready yet, preloading now...")
		if is_initialized:
			_load_interstitial()
		return false

## Helper to show interstitial every 3 completed levels (Level 1 disabled, 120s cooldown, max 10/hr)
func on_level_finished_check_interstitial(force_show: bool = false, completed_level: int = -1) -> bool:
	set_gameplay_active(false)
	var gm = get_tree().root.get_node_or_null("GameManager") if is_inside_tree() else null
	var lvl: int = completed_level if completed_level > 0 else (int(gm.current_level) if gm != null else 2)
	# First-level interstitial: Disabled
	if lvl <= 1:
		return false
	levels_since_last_interstitial += 1
	if force_show or levels_since_last_interstitial >= INTERSTITIAL_LEVEL_INTERVAL:
		if _can_show_interstitial_now():
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
		if _rewarded_retry_attempt < BACKOFF_MAX_ATTEMPTS:
			var delay := _compute_backoff_delay(_rewarded_retry_attempt)
			_rewarded_retry_attempt += 1
			get_tree().create_timer(delay).timeout.connect(_load_rewarded)
		else:
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
	return _billing_ready

# ==============================================================================
# 5. GOOGLE PLAY BILLING (coins_1000 / coins_2000 / coins_3000 / cofee / remove_ads)
# ==============================================================================
var _billing_plugin = null
var _billing_ready: bool = false
var live_prices: Dictionary = {}

func _start_billing() -> void:
	if OS.get_name() != "Android" or not Engine.has_singleton("CandyBoyAppPlugin"):
		return
	_billing_plugin = Engine.get_singleton("CandyBoyAppPlugin")
	if not _billing_plugin.has_method("billing_start"):
		_billing_plugin = null
		return
	_billing_plugin.connect("billing_connected", _on_billing_connected)
	_billing_plugin.connect("billing_error", _on_billing_error)
	_billing_plugin.connect("billing_prices", _on_billing_prices)
	_billing_plugin.connect("purchase_success", _on_purchase_success)
	_billing_plugin.connect("purchase_pending", _on_purchase_pending)
	_billing_plugin.connect("purchase_failed", _on_purchase_failed)
	_billing_plugin.connect("restore_finished", _on_restore_finished)
	_billing_plugin.billing_start()

func _on_billing_connected() -> void:
	_billing_ready = true
	print("[Billing] Connected to Google Play Billing.")

func _on_billing_error(msg: String) -> void:
	push_warning("[Billing] " + msg)
	purchase_state_changed.emit(is_ads_removed, msg)

func _on_billing_prices(json_txt: String) -> void:
	var parsed = JSON.parse_string(json_txt)
	if parsed is Dictionary:
		live_prices = parsed

## Real localized Google Play price if loaded, else the default USD price.
func get_price(product_id: String) -> String:
	if live_prices.has(product_id):
		return str(live_prices[product_id])
	if SHOP_PACKS.has(product_id):
		return str(SHOP_PACKS[product_id]["price"])
	if product_id == PRODUCT_COFFEE:
		return "$1.99"
	if product_id == PRODUCT_REMOVE_ADS:
		return "$4.99"
	return ""

func _on_purchase_success(product_id: String, restored: bool) -> void:
	var gm = get_tree().root.get_node_or_null("GameManager") if is_inside_tree() else null
	if SHOP_PACKS.has(product_id):
		var coins: int = int(SHOP_PACKS[product_id]["coins"])
		if gm != null and gm.has_method("add_coins"):
			gm.add_coins(coins)
		pack_purchase_verified.emit(coins, "+%d coins added. Thank you!" % coins)
	elif product_id == PRODUCT_COFFEE:
		coffee_purchased.emit("Thank you so much for the coffee! ☕")
	elif product_id == PRODUCT_REMOVE_ADS:
		if gm != null and gm.has_method("set_ads_removed"):
			gm.set_ads_removed(true)
		else:
			remove_all_ads()
		purchase_state_changed.emit(true, "Ads removed restored!" if restored else "Ads removed forever. Thank you!")

func _on_purchase_pending(product_id: String) -> void:
	var msg := "Payment pending — your item arrives once Google Play confirms it."
	if SHOP_PACKS.has(product_id):
		pack_purchase_verified.emit(0, msg)
	elif product_id == PRODUCT_COFFEE:
		coffee_purchased.emit(msg)
	else:
		purchase_state_changed.emit(is_ads_removed, msg)

func _on_purchase_failed(product_id: String, msg: String) -> void:
	if product_id == PRODUCT_COFFEE:
		coffee_purchased.emit(msg)
	elif product_id == PRODUCT_REMOVE_ADS:
		purchase_state_changed.emit(is_ads_removed, msg)
	else:
		pack_purchase_verified.emit(0, msg)
		if product_id == "":
			coffee_purchased.emit(msg)
			purchase_state_changed.emit(is_ads_removed, msg)

func _on_restore_finished(count: int) -> void:
	purchase_state_changed.emit(is_ads_removed, "Restore complete." if count > 0 else "No previous purchases found.")

func _buy(product_id: String) -> bool:
	if _billing_plugin == null:
		return false
	_billing_plugin.billing_purchase(product_id)
	return true

func request_pack_purchase(pack_id: String) -> void:
	if not SHOP_PACKS.has(pack_id):
		return
	if not _buy(pack_id):
		pack_purchase_verified.emit(0, "Purchases are only available in the Google Play version.")

func request_coffee_purchase() -> void:
	if not _buy(PRODUCT_COFFEE):
		coffee_purchased.emit("Purchases are only available in the Google Play version.")

func request_remove_ads() -> void:
	if is_ads_removed:
		purchase_state_changed.emit(true, "Ads are already removed.")
		return
	if not _buy(PRODUCT_REMOVE_ADS):
		purchase_state_changed.emit(is_ads_removed, "Purchases are only available in the Google Play version.")

func restore_purchases() -> void:
	if _billing_plugin == null:
		purchase_state_changed.emit(is_ads_removed, "Purchases are only available in the Google Play version.")
		return
	_billing_plugin.billing_restore()

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
