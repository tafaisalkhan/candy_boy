extends SceneTree

const AdMgrScript = preload("res://globals/ad_manager.gd")
const FailScript = preload("res://scenes/popups/fail_popup.gd")
const VictoryScript = preload("res://scenes/popups/victory_popup.gd")
const ShopScript = preload("res://scenes/popups/shop_popup.gd")
const SupportScript = preload("res://scenes/popups/support_popup.gd")
const SettingsScript = preload("res://scenes/popups/settings_popup.gd")

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var ad_mgr = AdMgrScript.new()
	ad_mgr.name = "AdManager"
	root.add_child(ad_mgr)
	await process_frame
	assert(ad_mgr.no_fill_this_launch, "Test IDs or desktop should activate no_fill_this_launch")
	assert(not ad_mgr.is_rewarded_ready(), "Rewarded ads must not be ready when no_fill_this_launch is active")

	var fail = FailScript.new()
	fail.setup("Caught!", "Tip", "", 20, 10)
	root.add_child(fail)
	await process_frame
	assert(not fail.ad_btn.visible, "FailPopup must hide ad_btn when no ad is ready")
	assert(fail.continue_btn == null, "FailPopup must not show Continue button (Retry only)")
	assert(fail.retry_btn.disabled, "FailPopup retry disabled when coins < cost")

	var victory = VictoryScript.new()
	victory.setup(1, 20)
	root.add_child(victory)
	await process_frame
	var vic_ad_btns := victory.find_children("*", "Button", true, false).filter(func(b: Button): return "2X REWARD" in b.text)
	assert(vic_ad_btns.size() == 1 and not vic_ad_btns[0].visible, "VictoryPopup must hide 2X REWARD ad button when no ad is ready")
	var vic_cont := victory.find_children("*", "Button", true, false).filter(func(b: Button): return "CONTINUE" in b.text)
	var vic_rep := victory.find_children("*", "Button", true, false).filter(func(b: Button): return "REPLAY" in b.text)
	assert(vic_cont.size() == 1 and vic_rep.size() == 1, "VictoryPopup must show both Continue and Replay buttons")

	var shop = ShopScript.new()
	root.add_child(shop)
	await process_frame
	var pack_btns := shop.find_children("*", "Button", true, false).filter(func(b: Button): return "COINS" in b.text)
	assert(pack_btns.size() == 3, "ShopPopup must show exactly 3 coin packs and no rewarded-ad card")

	var support = SupportScript.new()
	root.add_child(support)
	await process_frame
	var no_ads_labels := support.find_children("*", "Label", true, false).filter(func(l: Label): return "NO ADS TODAY" in l.text)
	assert(no_ads_labels.size() == 1, "SupportPopup shows NO ADS TODAY notice when no_fill_this_launch is active")

	var settings = SettingsScript.new()
	root.add_child(settings)
	await process_frame

	print("CandyBoy popups & ad-safety verification passed.")
	quit()
