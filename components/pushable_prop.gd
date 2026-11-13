class_name PushableProp
extends Node3D

@export var prop_radius: float = 0.55
@export var blocks_vision: bool = true

var visual_node: Node3D = null
var current_aabb: AABB
var current_world_pos: Vector3

func setup_barrel(p_color: Color = Color("#1e6091"), p_span: float = 1.05) -> void:
	prop_radius = clampf(p_span * 0.45, 0.45, 0.8)
	var barrel_h := 1.15 * p_span

	visual_node = Node3D.new()
	visual_node.name = "BarrelVisual"
	add_child(visual_node)

	# Main drum cylinder
	var barrel := MeshInstance3D.new()
	var b_mesh := CylinderMesh.new()
	b_mesh.top_radius = prop_radius
	b_mesh.bottom_radius = prop_radius
	b_mesh.height = barrel_h
	barrel.mesh = b_mesh
	barrel.position = Vector3(0.0, barrel_h * 0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = p_color
	mat.metallic = 0.7
	mat.roughness = 0.35
	barrel.material_override = mat
	visual_node.add_child(barrel)

	# Top & bottom metallic hoops
	var hoop_mat := StandardMaterial3D.new()
	hoop_mat.albedo_color = Color("#2c3e50")
	hoop_mat.metallic = 0.95
	hoop_mat.roughness = 0.25

	for hy in [barrel_h * 0.22, barrel_h * 0.78]:
		var hoop := MeshInstance3D.new()
		var h_mesh := CylinderMesh.new()
		h_mesh.top_radius = prop_radius * 1.03
		h_mesh.bottom_radius = prop_radius * 1.03
		h_mesh.height = 0.08
		hoop.mesh = h_mesh
		hoop.position = Vector3(0.0, hy, 0.0)
		hoop.material_override = hoop_mat
		visual_node.add_child(hoop)

	# Recessed lid
	var lid := MeshInstance3D.new()
	var l_mesh := CylinderMesh.new()
	l_mesh.top_radius = prop_radius * 0.94
	l_mesh.bottom_radius = prop_radius * 0.94
	l_mesh.height = 0.04
	lid.mesh = l_mesh
	lid.position = Vector3(0.0, barrel_h - 0.015, 0.0)
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = p_color.darkened(0.3)
	lid_mat.metallic = 0.8
	lid.material_override = lid_mat
	visual_node.add_child(lid)

	_update_collider()

func setup_crate(p_span: float = 1.1) -> void:
	prop_radius = clampf(p_span * 0.48, 0.45, 0.8)
	var c_h := p_span

	visual_node = Node3D.new()
	visual_node.name = "CrateVisual"
	add_child(visual_node)

	# Warm timber box
	var crate := MeshInstance3D.new()
	var c_mesh := BoxMesh.new()
	c_mesh.size = Vector3(p_span * 0.98, c_h * 0.98, p_span * 0.98)
	crate.mesh = c_mesh
	crate.position = Vector3(0.0, c_h * 0.5, 0.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#b7791f")
	mat.roughness = 0.9
	crate.material_override = mat
	visual_node.add_child(crate)

	# Dark border framing
	var frame_mat := StandardMaterial3D.new()
	frame_mat.albedo_color = Color("#78350f")
	frame_mat.roughness = 0.85

	var frame := MeshInstance3D.new()
	var f_mesh := BoxMesh.new()
	f_mesh.size = Vector3(p_span * 1.02, c_h * 0.16, p_span * 1.02)
	frame.mesh = f_mesh
	frame.position = Vector3(0.0, c_h * 0.5, 0.0)
	frame.material_override = frame_mat
	visual_node.add_child(frame)

	# Top and Bottom bands
	for fy in [c_h * 0.1, c_h * 0.9]:
		var band := MeshInstance3D.new()
		var b_mesh := BoxMesh.new()
		b_mesh.size = Vector3(p_span * 1.01, 0.08, p_span * 1.01)
		band.mesh = b_mesh
		band.position = Vector3(0.0, fy, 0.0)
		band.material_override = frame_mat
		visual_node.add_child(band)

	_update_collider()

func setup_model(item_name: String, p_scale: float = 1.8, p_radius: float = 0.5) -> void:
	prop_radius = p_radius
	visual_node = Node3D.new()
	visual_node.name = item_name + "Visual"
	add_child(visual_node)

	var scn_path := "res://assets/models/furniture/" + item_name + ".glb"
	if ResourceLoader.exists(scn_path):
		var scn := load(scn_path) as PackedScene
		if scn:
			var inst := scn.instantiate() as Node3D
			inst.scale = Vector3.ONE * p_scale
			HomeFurniture._colorize_furniture(inst, item_name)
			visual_node.add_child(inst)
			_update_collider()
			return
	setup_crate(p_scale * 0.6)

func try_push(step: Vector3, colliders: Array[AABB], other_props: Array[PushableProp]) -> bool:
	var next_pos := position + step
	if not _is_colliding(next_pos, colliders) and not _collides_with_other_props(next_pos, other_props):
		position = next_pos
		_update_collider()
		return true

	if absf(step.x) > 0.001:
		var next_x := position + Vector3(step.x, 0.0, 0.0)
		if not _is_colliding(next_x, colliders) and not _collides_with_other_props(next_x, other_props):
			position = next_x
			_update_collider()
			return true

	if absf(step.z) > 0.001:
		var next_z := position + Vector3(0.0, 0.0, step.z)
		if not _is_colliding(next_z, colliders) and not _collides_with_other_props(next_z, other_props):
			position = next_z
			_update_collider()
			return true

	return false

func _collides_with_other_props(test_pos: Vector3, other_props: Array[PushableProp]) -> bool:
	for other in other_props:
		if not is_instance_valid(other) or other == self:
			continue
		var min_d := prop_radius + other.prop_radius
		var diff := test_pos - other.position
		diff.y = 0.0
		if diff.length() < min_d:
			return true
	return false

func apply_push(p_pos: Vector3, player_speed: float, delta: float, wall_colliders: Array[AABB]) -> void:
	var to_prop := position - p_pos
	to_prop.y = 0.0
	var dist := to_prop.length()
	var min_sep := 0.45 + prop_radius

	if dist < min_sep:
		var push_dir := (to_prop / maxf(0.001, dist)) if dist > 0.01 else Vector3.FORWARD
		var overlap := min_sep - dist
		var push_step := push_dir * (overlap + 0.02)
		_move_with_slide(push_step, wall_colliders)

func _move_with_slide(step: Vector3, colliders: Array[AABB]) -> void:
	var next_x := position + Vector3(step.x, 0.0, 0.0)
	if not _is_colliding(next_x, colliders):
		position = next_x

	var next_z := position + Vector3(0.0, 0.0, step.z)
	if not _is_colliding(next_z, colliders):
		position = next_z

	_update_collider()

func _is_colliding(test_pos: Vector3, colliders: Array[AABB]) -> bool:
	for aabb in colliders:
		if aabb == current_aabb:
			continue
		if aabb.grow(prop_radius).has_point(test_pos):
			return true
	return false

func _update_collider() -> void:
	var s := prop_radius * 1.8
	current_aabb = AABB(Vector3(position.x - s * 0.5, 0.0, position.z - s * 0.5), Vector3(s, 1.4, s))
	current_world_pos = position
