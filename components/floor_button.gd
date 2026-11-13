class_name FloorButton
extends Node3D

signal button_pressed(target_laser: String)

@export var button_id: String = ""
@export var target_laser: String = ""
@export var is_pressed: bool = false

var pad_mesh: MeshInstance3D = null
var pad_mat: StandardMaterial3D = null
var wire_line: MeshInstance3D = null

func setup(p_id: String, p_target: String, target_world_pos: Vector3 = Vector3.ZERO) -> void:
	button_id = p_id
	target_laser = p_target
	_build_visuals(target_world_pos)

func _build_visuals(target_world_pos: Vector3) -> void:
	# 1. Beveled metallic base ring
	var base := MeshInstance3D.new()
	var b_mesh := CylinderMesh.new()
	b_mesh.top_radius = 0.65
	b_mesh.bottom_radius = 0.72
	b_mesh.height = 0.05
	base.mesh = b_mesh
	base.position = Vector3(0.0, 0.025, 0.0)
	var base_mat := StandardMaterial3D.new()
	base_mat.albedo_color = Color("#2c3e50")
	base_mat.metallic = 0.8
	base.material_override = base_mat
	add_child(base)

	# 2. Pressable Center Button Disc (Starts RED)
	pad_mesh = MeshInstance3D.new()
	var p_mesh := CylinderMesh.new()
	p_mesh.top_radius = 0.52
	p_mesh.bottom_radius = 0.52
	p_mesh.height = 0.06
	pad_mesh.mesh = p_mesh
	pad_mesh.position = Vector3(0.0, 0.06, 0.0)

	pad_mat = StandardMaterial3D.new()
	pad_mat.albedo_color = Color("#ff3838")
	pad_mat.emission_enabled = true
	pad_mat.emission = Color("#ff4757")
	pad_mat.emission_energy_multiplier = 0.8
	pad_mesh.material_override = pad_mat
	add_child(pad_mesh)

	# 3. Yellow Down Arrow Indicator
	var arrow := MeshInstance3D.new()
	var arr_mesh := PrismMesh.new()
	arr_mesh.size = Vector3(0.35, 0.35, 0.02)
	arrow.mesh = arr_mesh
	arrow.position = Vector3(0.0, 0.095, 0.0)
	arrow.rotation_degrees = Vector3(90.0, 180.0, 0.0)
	var arr_mat := StandardMaterial3D.new()
	arr_mat.albedo_color = Color("#f1c40f")
	arrow.material_override = arr_mat
	add_child(arrow)

	# 4. Yellow Floor Conduit Wire to Target Laser
	if target_world_pos != Vector3.ZERO:
		var local_target := target_world_pos - position
		_build_conduit_wire(local_target)

func _build_conduit_wire(to_pos: Vector3) -> void:
	var wire_mat := StandardMaterial3D.new()
	wire_mat.albedo_color = Color("#f1c40f")
	wire_mat.emission_enabled = true
	wire_mat.emission = Color("#f39c12")
	wire_mat.emission_energy_multiplier = 0.5

	# L-shaped conduit wire path
	var corner := Vector3(0.0, 0.015, to_pos.z)
	var seg1_len := absf(to_pos.z)
	if seg1_len > 0.1:
		var s1 := MeshInstance3D.new()
		var b1 := BoxMesh.new()
		b1.size = Vector3(0.06, 0.02, seg1_len)
		s1.mesh = b1
		s1.position = Vector3(0.0, 0.015, to_pos.z * 0.5)
		s1.material_override = wire_mat
		add_child(s1)

	var seg2_len := absf(to_pos.x)
	if seg2_len > 0.1:
		var s2 := MeshInstance3D.new()
		var b2 := BoxMesh.new()
		b2.size = Vector3(seg2_len, 0.02, 0.06)
		s2.mesh = b2
		s2.position = Vector3(to_pos.x * 0.5, 0.015, to_pos.z)
		s2.material_override = wire_mat
		add_child(s2)

func check_activation(p_pos: Vector3, props_positions: Array[Vector3]) -> bool:
	if is_pressed:
		return false
	var my_pos := global_position
	# Check player distance
	if p_pos.distance_to(my_pos) <= 0.85:
		press()
		return true
	# Check pushable props distance
	for prop_pos in props_positions:
		if prop_pos.distance_to(my_pos) <= 0.95:
			press()
			return true
	return false

func press() -> void:
	if is_pressed:
		return
	is_pressed = true

	# Pad depresses and turns bright WHITE with glowing halo
	if pad_mat:
		pad_mat.albedo_color = Color("#ffffff")
		pad_mat.emission = Color("#ffffff")
		pad_mat.emission_energy_multiplier = 2.0

	if pad_mesh:
		var tw := create_tween()
		tw.tween_property(pad_mesh, "position:y", 0.02, 0.12)

	button_pressed.emit(target_laser)
