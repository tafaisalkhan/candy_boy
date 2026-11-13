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
var _interstitial_ad = null
var _rewarded_ad = null

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

# Interstitial Level Counter (e.g. show interstitial every 2 completed levels)
var levels_since_last_interstitial: int = 0
const INTERSTITIAL_LEVEL_INTERVAL: int = 2

func _enter_tree() -> void:
	instance = self

func _ready() -> void:
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

# ==============================================================================
# 1. BANNER AD METHODS
# ==============================================================================

func _load_banner() -> void:
	if not _plugin_available or not is_initialized or is_ads_removed or _banner_view != null:
		return

	_banner_view = AdView.new(BANNER_AD_ID, AdSize.BANNER, AdPosition.BOTTOM)
	_banner_cb = AdListener.new()
	_banner_cb.on_ad_loaded = func():
		print("[AdManager] Banner ad loaded successfully!")
		banner_loaded.emit()

	_banner_cb.on_ad_failed_to_load = func(err):
		var err_str: String = str(err.message if "message" in err else err)
		print("[AdManager] Banner ad failed to load: ", err_str)
		banner_failed.emit(err_str)
		# Retry loading after 25 seconds
		if not is_ads_removed and is_instance_valid(instance):
			var tw := instance.create_tween()
			tw.tween_interval(25.0)
			tw.tween_callback(func():
				if _banner_view == null and not is_ads_removed:
					_load_banner()
			)

	_banner_view.ad_listener = _banner_cb
	_banner_view.load_ad(AdRequest.new())

func show_banner() -> void:
	if is_ads_removed:
		return
	if not _plugin_available:
		print("[AdManager-Mock] show_banner() called in desktop mode.")
		return
	if _banner_view == null:
		if is_initialized:
			_load_banner()
	elif _banner_view.has_method("show"):
		_banner_view.show()

func hide_banner() -> void:
	if _banner_view and _banner_view.has_method("hide"):
		_banner_view.hide()

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
			interstitial_dismissed.emit()
			# Automatically preload the next interstitial
			_load_interstitial()

		_interstitial_content_cb.on_ad_failed_to_show_full_screen_content = func(err):
			var err_str: String = str(err.message if "message" in err else err)
			print("[AdManager] Interstitial ad failed to show: ", err_str)
			_interstitial_ad = null
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
		interstitial_dismissed.emit()
		return true

	if _interstitial_ad != null:
		print("[AdManager] Displaying Interstitial Ad...")
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
			_load_rewarded()

		_rewarded_content_cb.on_ad_failed_to_show_full_screen_content = func(err):
			var err_str: String = str(err.message if "message" in err else err)
			print("[AdManager] Rewarded Ad failed to show: ", err_str)
			_rewarded_ad = null
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

	if not _plugin_available:
		print("[AdManager-Mock] show_rewarded() called in desktop mode. Simulating reward after 0.5s...")
		if is_instance_valid(instance):
			var tw := instance.create_tween()
			tw.tween_interval(0.5)
			tw.tween_callback(func():
				_grant_reward(50, "coins")
			)
		return true

	if _rewarded_ad != null:
		print("[AdManager] Showing Rewarded Video Ad...")
		_reward_listener = OnUserEarnedRewardListener.new()
		_reward_listener.on_user_earned_reward = func(reward_item):
			var amt: int = reward_item.amount if reward_item else 50
			var type: String = reward_item.type if reward_item else "coins"
			_grant_reward(amt, type)

		_rewarded_ad.show(_reward_listener)
		return true
	else:
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
# 4. REMOVE ADS (IAP INTEGRATION)
# ==============================================================================

func remove_all_ads() -> void:
	is_ads_removed = true
	hide_banner()
	if _banner_view and _banner_view.has_method("destroy"):
		_banner_view.destroy()
		_banner_view = null
	_interstitial_ad = null
	print("[AdManager] All ads removed permanently.")
