class_name FootstepManager
extends Node

var last_pos: Vector3 = Vector3(999.0, 999.0, 999.0)
var footstep_side: float = 1.0

func spawn_footstep_if_needed(parent: Node3D, pos: Vector3, yaw: float) -> void:
	if parent == null:
		return
	if last_pos.distance_to(pos) < 0.48:
		return
	last_pos = pos
	footstep_side = -footstep_side
	if SoundManager != null:
		SoundManager.play_footstep()

	var offset := Vector3(cos(yaw), 0.0, -sin(yaw)) * (0.11 * footstep_side)
	var print_node := MeshInstance3D.new()
	var quad := PlaneMesh.new()
	quad.size = Vector2(0.16, 0.24)
	print_node.mesh = quad
	print_node.position = pos + offset + Vector3(0.0, 0.015, 0.0)
	print_node.rotation.y = yaw

	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.28, 0.32, 0.38, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	print_node.material_override = mat
	parent.add_child(print_node)

	var tw := print_node.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.8)
	tw.tween_callback(print_node.queue_free)
