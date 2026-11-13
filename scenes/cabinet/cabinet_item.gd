class_name CabinetItem
extends Node3D

signal item_taken(item_id: String, item_name: String, icon: String)

@export var item_id: String = ""
@export var item_name: String = ""
@export var item_icon: String = "🎁"
@export var requires_key: bool = false
@export var is_open: bool = false
@export var is_collected: bool = false

var door_left: Node3D = null
var door_right: Node3D = null
var beacon_node: Node3D = null
var prompt_node: Label3D = null
var lock_badge: Label3D = null
var padlock_node: Node3D = null
var item_node: Node3D = null

var collider_aabb: AABB = AABB()


static func create(parent: Node3D, pos: Vector3, rot_y: float, item_dict: Dictionary, font: Font = null) -> CabinetItem:
	var cab := CabinetItem.new()
	cab.name = "Cabinet_%s" % item_dict.get("id", "item")
	cab.setup(item_dict)
	parent.add_child(cab)
	cab.position = pos
	cab.rotation.y = rot_y
	cab._build_geometry(pos, rot_y, item_dict, font)
	return cab


func _build_geometry(pos: Vector3, rot_y: float, item_dict: Dictionary, font: Font = null) -> void:
	var cup_w: float = float(item_dict.get("width", 2.2))
	var cup_h: float = float(item_dict.get("height", 2.8))
	var cup_d: float = float(item_dict.get("depth", 1.4))

	var half_w := cup_w * 0.5
	var half_d := cup_d * 0.5
	if absf(rot_y) > 0.1:
		collider_aabb = AABB(pos - Vector3(half_d, 0.0, half_w), Vector3(cup_d, cup_h, cup_w))
	else:
		collider_aabb = AABB(pos - Vector3(half_w, 0.0, half_d), Vector3(cup_w, cup_h, cup_d))

	var cab_facade := Node3D.new()
	cab_facade.name = "CabinetFacade"
	add_child(cab_facade)

	var primary_col := Color(item_dict.get("color", "#8e44ad"))
	var cab_mat := StandardMaterial3D.new()
	cab_mat.albedo_color = primary_col.darkened(0.25)
	cab_mat.roughness = 0.5

	var door_mat := StandardMaterial3D.new()
	door_mat.albedo_color = primary_col.lightened(0.12)
	door_mat.roughness = 0.45

	var brass_mat := StandardMaterial3D.new()
	brass_mat.albedo_color = Color("#f1c40f")
	brass_mat.metallic = 0.85
	brass_mat.roughness = 0.25

	# Carcass Box
	var frame_mesh := MeshInstance3D.new()
	var frame_box := BoxMesh.new()
	frame_box.size = Vector3(cup_w, cup_h, cup_d)
	frame_mesh.mesh = frame_box
	frame_mesh.position = Vector3(0.0, cup_h * 0.5, 0.0)
	frame_mesh.material_override = cab_mat
	cab_facade.add_child(frame_mesh)

	# Doors
	var door_w := cup_w * 0.48
	var door_h := cup_h * 0.88
	var front_z := cup_d * 0.5 + 0.02
	var door_y := cup_h * 0.5

	var l_hinge := Node3D.new()
	l_hinge.name = "HingeLeft"
	l_hinge.position = Vector3(-cup_w * 0.5 + 0.08, door_y, front_z)
	cab_facade.add_child(l_hinge)

	var l_mesh := MeshInstance3D.new()
	var d_box := BoxMesh.new()
	d_box.size = Vector3(door_w, door_h, 0.08)
	l_mesh.mesh = d_box
	l_mesh.position = Vector3(door_w * 0.5, 0.0, 0.04)
	l_mesh.material_override = door_mat
	l_hinge.add_child(l_mesh)
	door_left = l_hinge

	var r_hinge := Node3D.new()
	r_hinge.name = "HingeRight"
	r_hinge.position = Vector3(cup_w * 0.5 - 0.08, door_y, front_z)
	cab_facade.add_child(r_hinge)

	var r_mesh := MeshInstance3D.new()
	r_mesh.mesh = d_box
	r_mesh.position = Vector3(-door_w * 0.5, 0.0, 0.04)
	r_mesh.material_override = door_mat
	r_hinge.add_child(r_mesh)
	door_right = r_hinge

	# Floating Beacon
	var beacon := Node3D.new()
	beacon.name = "ItemBeacon"
	beacon.position = Vector3(0.0, cup_h + 1.0, 0.3)
	add_child(beacon)
	beacon_node = beacon

	var icon_lbl := Label3D.new()
	icon_lbl.text = item_icon
	icon_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	icon_lbl.font_size = 46
	icon_lbl.outline_size = 12
	icon_lbl.outline_modulate = Color.BLACK
	beacon.add_child(icon_lbl)

	# Interaction prompt
	var prompt := Label3D.new()
	prompt.text = "🔒 KEY REQUIRED!" if requires_key else "🚪 [ OPEN CABINET ]"
	prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if font != null:
		prompt.font = font
	prompt.font_size = 40
	prompt.outline_size = 14
	prompt.outline_modulate = Color.BLACK
	prompt.modulate = Color("#ff7675") if requires_key else Color("#ffeaa7")
	prompt.position = Vector3(0.0, cup_h + 1.5, 0.3)
	prompt.visible = false
	add_child(prompt)
	prompt_node = prompt

	# Padlock if locked
	if requires_key:
		var padlock := Node3D.new()
		padlock.position = Vector3(0.0, door_y, front_z + 0.12)
		cab_facade.add_child(padlock)
		var p_mesh := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(0.35, 0.38, 0.14)
		p_mesh.mesh = p_box
		p_mesh.material_override = brass_mat
		padlock.add_child(p_mesh)
		padlock_node = padlock

		var l_badge := Label3D.new()
		l_badge.text = "🔒 KEY REQUIRED"
		l_badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		if font != null:
			l_badge.font = font
		l_badge.font_size = 44
		l_badge.outline_size = 14
		l_badge.outline_modulate = Color.BLACK
		l_badge.modulate = Color("#ff7675")
		l_badge.position = Vector3(0.0, cup_h + 0.45, 0.5)
		add_child(l_badge)
		lock_badge = l_badge

	# Mini item inside
	var mini_item := CollectibleItem.create_item_visual(item_dict.get("type", "candy_heart"), item_dict.get("color", "#e74c3c"))
	mini_item.position = Vector3(0.0, cup_h * 0.4, 0.0)
	mini_item.scale = Vector3(0.1, 0.1, 0.1)
	mini_item.visible = false
	add_child(mini_item)
	item_node = mini_item


func setup(dict: Dictionary) -> void:
	item_id = dict.get("id", "item")
	item_name = dict.get("name", "Item")
	item_icon = dict.get("icon", "🎁")
	requires_key = bool(dict.get("requires_key", false))


func unlock() -> void:
	if not requires_key or is_open:
		return
	requires_key = false
	if is_instance_valid(lock_badge):
		lock_badge.text = "UNLOCKED!"
		lock_badge.modulate = Color("#2ecc71")
	if is_instance_valid(padlock_node):
		padlock_node.queue_free()
	if is_instance_valid(prompt_node):
		prompt_node.text = "[ OPEN CABINET ]"
		prompt_node.modulate = Color("#2ecc71")


func open_cabinet() -> void:
	if is_open:
		return
	is_open = true
	is_collected = true

	if SoundManager != null:
		SoundManager.play_sfx("cabinet")
	if SignalHub != null:
		SignalHub.emit_cabinet_opened(item_id)

	if is_instance_valid(beacon_node):
		beacon_node.visible = false
		beacon_node.queue_free()
	if is_instance_valid(lock_badge):
		lock_badge.visible = false
		lock_badge.queue_free()
	if is_instance_valid(padlock_node):
		padlock_node.visible = false
		padlock_node.queue_free()
	if is_instance_valid(prompt_node):
		prompt_node.visible = false
		prompt_node.queue_free()

	# Swing doors
	var tw := create_tween()
	tw.set_parallel(true)
	if is_instance_valid(door_left):
		tw.tween_property(door_left, "rotation:y", deg_to_rad(-110.0), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_instance_valid(door_right):
		tw.tween_property(door_right, "rotation:y", deg_to_rad(110.0), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	# Reveal item pop
	if is_instance_valid(item_node):
		item_node.visible = true
		item_node.scale = Vector3(0.25, 0.25, 0.25)
		var pop_tw := create_tween()
		pop_tw.set_parallel(true)
		pop_tw.tween_property(item_node, "scale", Vector3.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pop_tw.tween_property(item_node, "position:y", item_node.position.y + 0.9, 0.22)
		pop_tw.chain().tween_interval(0.18)
		pop_tw.chain().tween_callback(func():
			if is_instance_valid(item_node):
				item_node.visible = false
				item_node.queue_free()
		)

	item_taken.emit(item_id, item_name, item_icon)
	if SignalHub != null:
		SignalHub.emit_item_collected(item_id, item_name, 1, 1)
