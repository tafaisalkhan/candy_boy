class_name LaserBarrier
extends Node3D

signal player_tripped(barrier_id: String)

@export var barrier_id: String = ""
@export var barrier_width: float = 2.4
@export var is_active: bool = true

var beams: Array[MeshInstance3D] = []
var emitter_l: MeshInstance3D = null
var emitter_r: MeshInstance3D = null

func setup(p_id: String, p_width: float = 2.4, p_active: bool = true) -> void:
	barrier_id = p_id
	barrier_width = p_width
	is_active = p_active
	_build_visuals()

func _build_visuals() -> void:
	var half_w := barrier_width * 0.5

	# 1. Emitter Posts
	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color("#2c3e50")
	post_mat.metallic = 0.8
	post_mat.roughness = 0.35

	for x_side in [-half_w, half_w]:
		var post := MeshInstance3D.new()
		var p_mesh := BoxMesh.new()
		p_mesh.size = Vector3(0.18, 1.4, 0.18)
		post.mesh = p_mesh
		post.position = Vector3(x_side, 0.7, 0.0)
		post.material_override = post_mat
		add_child(post)

		# Glowing Red Emitter Ring
		var cap := MeshInstance3D.new()
		var c_mesh := CylinderMesh.new()
		c_mesh.top_radius = 0.12
		c_mesh.bottom_radius = 0.12
		c_mesh.height = 0.1
		cap.mesh = c_mesh
		cap.position = Vector3(x_side, 1.42, 0.0)
		var cap_mat := StandardMaterial3D.new()
		cap_mat.albedo_color = Color("#ff2a4b")
		cap_mat.emission_enabled = true
		cap_mat.emission = Color("#ff2a4b")
		cap_mat.emission_energy_multiplier = 2.0
		cap.material_override = cap_mat
		add_child(cap)

	# 2. Glowing Laser Beams
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(1.0, 0.15, 0.15, 0.85)
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mat.emission_enabled = true
	beam_mat.emission = Color("#ff2a4b")
	beam_mat.emission_energy_multiplier = 2.8
	beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for h in [0.45, 0.75, 1.05]:
		var beam := MeshInstance3D.new()
		var b_mesh := CylinderMesh.new()
		b_mesh.top_radius = 0.032
		b_mesh.bottom_radius = 0.032
		b_mesh.height = barrier_width
		beam.mesh = b_mesh
		beam.position = Vector3(0.0, h, 0.0)
		beam.rotation_degrees.z = 90.0
		beam.material_override = beam_mat
		add_child(beam)
		beams.append(beam)

	visible = is_active

func deactivate() -> void:
	if not is_active:
		return
	is_active = false
	var tw := create_tween()
	for beam in beams:
		tw.parallel().tween_property(beam, "scale:x", 0.0, 0.25)
		tw.parallel().tween_property(beam, "scale:z", 0.0, 0.25)
	tw.tween_callback(func(): visible = false)

func check_player_collision(p_pos: Vector3) -> bool:
	if not is_active:
		return false
	var local_p := to_local(p_pos)
	if absf(local_p.x) <= (barrier_width * 0.5) and absf(local_p.z) <= 0.45 and local_p.y >= 0.0 and local_p.y <= 1.5:
		player_tripped.emit(barrier_id)
		return true
	return false
