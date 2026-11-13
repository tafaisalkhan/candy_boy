class_name DoorController
extends Node3D

signal door_opened
signal door_closed

@export var door_width: float = 2.4
@export var requires_key: bool = false
@export var is_open: bool = false
@export var is_glass: bool = false
@export var door_color: Color = Color("#27ae60")

var pivot_l: Node3D = null
var pivot_r: Node3D = null
var padlock_node: Node3D = null
var open_amount: float = 0.0
var collider_aabb: AABB
var wall_colliders_ref: Array[AABB] = []
var last_locked_prompt_time: float = 0.0

const WALL_H: float = 2.6
const WALL_T: float = 0.35

func setup(p_width: float, p_color: Color, p_req_key: bool = false, p_is_glass: bool = false) -> void:
	door_width = p_width
	door_color = p_color
	requires_key = p_req_key
	is_glass = p_is_glass
	_build_visuals()

func _build_visuals() -> void:
	var half_w := door_width * 0.5
	var leaf_w := half_w * 0.98

	# Frame Posts
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color("#2c3e50")
	frame_mat.metallic = 0.8

	for fx in [-half_w, half_w]:
		var post := MeshInstance3D.new()
		var p_mesh := BoxMesh.new()
		p_mesh.size = Vector3(0.12, WALL_H, WALL_T * 1.1)
		post.mesh = p_mesh
		post.position = Vector3(fx, WALL_H * 0.5, 0.0)
		post.material_override = frame_mat
		add_child(post)

	# Left Pivot & Leaf
	pivot_l = Node3D.new()
	pivot_l.name = "PivotL"
	pivot_l.position = Vector3(-half_w, 0.0, 0.0)
	add_child(pivot_l)

	var leaf_l := MeshInstance3D.new()
	var l_mesh := BoxMesh.new()
	l_mesh.size = Vector3(leaf_w, WALL_H * 0.96, WALL_T * 0.5)
	leaf_l.mesh = l_mesh
	leaf_l.position = Vector3(leaf_w * 0.5, WALL_H * 0.48, 0.0)
	var leaf_mat := StandardMaterial3D.new()
	leaf_mat.albedo_color = door_color
	leaf_mat.roughness = 0.4
	leaf_l.material_override = leaf_mat
	pivot_l.add_child(leaf_l)

	# Right Pivot & Leaf
	pivot_r = Node3D.new()
	pivot_r.name = "PivotR"
	pivot_r.position = Vector3(half_w, 0.0, 0.0)
	add_child(pivot_r)

	var leaf_r := MeshInstance3D.new()
	leaf_r.mesh = l_mesh
	leaf_r.position = Vector3(-leaf_w * 0.5, WALL_H * 0.48, 0.0)
	leaf_r.material_override = leaf_mat
	pivot_r.add_child(leaf_r)

	# Silver door handles on both leaves
	var handle_mat := StandardMaterial3D.new()
	handle_mat.albedo_color = Color("#bdc3c7")
	handle_mat.metallic = 0.95
	handle_mat.roughness = 0.2

	var handle_l := MeshInstance3D.new()
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(0.08, 0.45, 0.12)
	handle_l.mesh = h_mesh
	handle_l.position = Vector3(leaf_w * 0.38, 0.0, 0.12)
	handle_l.material_override = handle_mat
	leaf_l.add_child(handle_l)

	var handle_r := MeshInstance3D.new()
	handle_r.mesh = h_mesh
	handle_r.position = Vector3(-leaf_w * 0.38, 0.0, 0.12)
	handle_r.material_override = handle_mat
	leaf_r.add_child(handle_r)

	# 3D Padlock on Locked Door
	if requires_key:
		padlock_node = Node3D.new()
		padlock_node.name = "Padlock"
		padlock_node.position = Vector3(0.0, 1.15, 0.12)
		add_child(padlock_node)

		var p_body := MeshInstance3D.new()
		var pb_mesh := BoxMesh.new()
		pb_mesh.size = Vector3(0.3, 0.28, 0.12)
		p_body.mesh = pb_mesh
		var p_mat := StandardMaterial3D.new()
		p_mat.albedo_color = Color("#f1c40f")
		p_mat.metallic = 0.9
		p_body.material_override = p_mat
		padlock_node.add_child(p_body)

		var p_shackle := MeshInstance3D.new()
		var ps_mesh := CylinderMesh.new()
		ps_mesh.top_radius = 0.12
		ps_mesh.bottom_radius = 0.12
		ps_mesh.height = 0.16
		p_shackle.mesh = ps_mesh
		p_shackle.position = Vector3(0.0, 0.22, 0.0)
		var ps_mat := StandardMaterial3D.new()
		ps_mat.albedo_color = Color("#bdc3c7")
		ps_mat.metallic = 0.85
		p_shackle.material_override = ps_mat
		padlock_node.add_child(p_shackle)

	# Initial Closed Door Collider AABB
	collider_aabb = AABB(Vector3(position.x - half_w, 0.0, position.z - WALL_T * 0.5), Vector3(door_width, WALL_H, WALL_T))

func _ready() -> void:
	var half_w := door_width * 0.5
	if absf(rotation_degrees.y - 90.0) < 15.0 or absf(rotation_degrees.y + 90.0) < 15.0 or absf(rotation_degrees.y - 270.0) < 15.0:
		collider_aabb = AABB(Vector3(global_position.x - WALL_T * 0.5, 0.0, global_position.z - half_w), Vector3(WALL_T, WALL_H, door_width))
	else:
		collider_aabb = AABB(Vector3(global_position.x - half_w, 0.0, global_position.z - WALL_T * 0.5), Vector3(door_width, WALL_H, WALL_T))

func update_door(delta: float, p_pos: Vector3, player_has_key: bool) -> void:
	var c := global_position
	var half_w := door_width * 0.5
	var in_door_zone := false
	if absf(rotation_degrees.y - 90.0) < 15.0 or absf(rotation_degrees.y + 90.0) < 15.0 or absf(rotation_degrees.y - 270.0) < 15.0:
		in_door_zone = absf(p_pos.z - c.z) <= (half_w + 0.6) and absf(p_pos.x - c.x) <= 2.2
	else:
		in_door_zone = absf(p_pos.x - c.x) <= (half_w + 0.6) and absf(p_pos.z - c.z) <= 2.2

	if in_door_zone:
		if requires_key and not player_has_key:
			_show_locked_prompt()
		else:
			open_door()
	else:
		close_door()

	# Swing animation
	var target_amt: float = 1.0 if is_open else 0.0
	open_amount = move_toward(open_amount, target_amt, delta * 6.0)
	var angle: float = open_amount * deg_to_rad(85.0)

	if is_instance_valid(pivot_l):
		pivot_l.rotation.y = -angle
	if is_instance_valid(pivot_r):
		pivot_r.rotation.y = angle

func open_door() -> void:
	if is_open:
		return
	is_open = true
	if is_instance_valid(padlock_node):
		padlock_node.visible = false
	door_opened.emit()

func close_door() -> void:
	if not is_open:
		return
	is_open = false
	door_closed.emit()

func _show_locked_prompt() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - last_locked_prompt_time < 2.2:
		return
	last_locked_prompt_time = now

	var label := Label3D.new()
	label.text = "DOOR LOCKED!\nFIND THE GOLDEN KEY"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var gfont := FontFile.new()
	if gfont.load_dynamic_font(ProjectSettings.globalize_path("res://assets/fonts/LuckiestGuy-Regular.ttf")) == OK:
		label.font = gfont
	label.font_size = 34
	label.outline_size = 12
	label.outline_modulate = Color.BLACK
	label.modulate = Color("#ff4757")
	label.position = Vector3(0.0, 2.2, 0.0)
	add_child(label)

	var tw := create_tween()
	tw.tween_property(label, "position:y", 3.2, 1.3)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.3)
	tw.tween_callback(label.queue_free)
