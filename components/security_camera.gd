class_name SecurityCamera
extends Node3D

signal player_spotted(reason: String)

@export var max_vision_range: float = 7.8
@export var current_vision_range: float = 3.5
@export var vision_angle: float = 38.0
@export var sweep_speed: float = 1.25
@export var sweep_amplitude: float = 0.55

var head_node: Node3D = null
var cone_mesh: ImmediateMesh = null
var cone_instance: MeshInstance3D = null
var base_yaw: float = 0.0
var sweep_time: float = 0.0
var growth_speed: float = 0.75

func setup(wall_yaw: float, p_range: float = 4.0, p_angle: float = 30.0) -> void:
	base_yaw = wall_yaw
	max_vision_range = p_range
	current_vision_range = p_range
	vision_angle = p_angle
	_build_visuals()

func _build_visuals() -> void:
	var bracket := Node3D.new()
	bracket.rotation.y = base_yaw
	add_child(bracket)

	# Wall Mount Plate & Arm
	var plate := MeshInstance3D.new()
	var p_mesh := BoxMesh.new()
	p_mesh.size = Vector3(0.36, 0.42, 0.08)
	plate.mesh = p_mesh
	plate.position = Vector3(0.0, 0.0, 0.04)
	var plate_mat := StandardMaterial3D.new()
	plate_mat.albedo_color = Color("#2b3340")
	plate.material_override = plate_mat
	bracket.add_child(plate)

	var arm := MeshInstance3D.new()
	var a_mesh := BoxMesh.new()
	a_mesh.size = Vector3(0.12, 0.12, 0.48)
	arm.mesh = a_mesh
	arm.position = Vector3(0.0, 0.0, 0.28)
	arm.material_override = plate_mat
	bracket.add_child(arm)

	# Swivel Camera Head
	head_node = Node3D.new()
	head_node.name = "CamHead"
	head_node.position = Vector3(0.0, 0.0, 0.52)
	head_node.rotation.y = base_yaw
	bracket.add_child(head_node)

	var housing := MeshInstance3D.new()
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(0.38, 0.32, 0.62)
	housing.mesh = h_mesh
	housing.position = Vector3(0.0, 0.0, 0.12)
	var h_mat := StandardMaterial3D.new()
	h_mat.albedo_color = Color("#0984e3")
	housing.material_override = h_mat
	head_node.add_child(housing)

	var led := MeshInstance3D.new()
	var led_m := CylinderMesh.new()
	led_m.top_radius = 0.08
	led_m.bottom_radius = 0.08
	led_m.height = 0.08
	led.mesh = led_m
	led.position = Vector3(0.0, 0.20, 0.25)
	var led_mat := StandardMaterial3D.new()
	led_mat.albedo_color = Color("#ff2a4b")
	led_mat.emission_enabled = true
	led_mat.emission = Color("#ff2a4b")
	led_mat.emission_energy_multiplier = 2.0
	led.material_override = led_mat
	head_node.add_child(led)

	# Vision Cone Mesh
	cone_mesh = ImmediateMesh.new()
	cone_instance = MeshInstance3D.new()
	cone_instance.name = "CameraScanCone"
	cone_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone_instance.mesh = cone_mesh
	var cone_mat := StandardMaterial3D.new()
	cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_mat.albedo_color = Color(1.0, 0.16, 0.16, 0.72)
	cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone_instance.material_override = cone_mat
	add_child(cone_instance)

func update_camera(delta: float, p_pos: Vector3, wall_colliders: Array[AABB], is_player_invisible: bool = false) -> void:
	if not is_instance_valid(head_node):
		return

	# 1. Sweep rotation (bracket already has base_yaw, so head_node uses local sweep_offset!)
	sweep_time += delta * sweep_speed
	var sweep_offset := sin(sweep_time) * sweep_amplitude
	var cam_yaw: float = base_yaw + sweep_offset
	head_node.rotation.y = sweep_offset
	var cam_forward := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw)).normalized()

	# 2. Render Vision Cone on floor with raycast occlusion
	var origin := Vector3(head_node.global_position.x, 0.05, head_node.global_position.z)
	_render_vision_cone(origin, cam_forward, current_vision_range, vision_angle, wall_colliders)

	# 4. Player detection check (ignored when invisible!)
	if not is_player_invisible and _is_target_in_cone(p_pos, origin, cam_forward, current_vision_range, vision_angle, wall_colliders):
		player_spotted.emit("Spotted by the security camera!")

func _render_vision_cone(origin: Vector3, forward: Vector3, v_range: float, half_angle: float, colliders: Array[AABB]) -> void:
	if cone_mesh == null:
		return
	cone_mesh.clear_surfaces()
	var steps := 24
	var base_yaw := atan2(forward.x, forward.z)
	var half_rad := deg_to_rad(half_angle)
	var local_origin := cone_instance.to_local(origin)

	var arc_points: Array[Vector3] = []
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		var angle := base_yaw - half_rad + (2.0 * half_rad * t)
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var hit_d := _raycast_cone_edge(origin, dir, v_range, colliders)
		var pt := origin + dir * hit_d
		arc_points.append(cone_instance.to_local(pt))

	cone_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(steps):
		cone_mesh.surface_add_vertex(local_origin)
		cone_mesh.surface_add_vertex(arc_points[i])
		cone_mesh.surface_add_vertex(arc_points[i + 1])
	cone_mesh.surface_end()

func _raycast_cone_edge(origin: Vector3, dir: Vector3, max_dist: float, colliders: Array[AABB]) -> float:
	var closest := max_dist
	for aabb in colliders:
		var hit := _ray_intersects_aabb_2d(origin, dir, aabb, closest)
		if hit > 0.0 and hit < closest:
			closest = hit
	return closest

func _ray_intersects_aabb_2d(origin: Vector3, dir: Vector3, aabb: AABB, max_d: float) -> float:
	var tmin := 0.0
	var tmax := max_d
	for i in [0, 2]:
		var o := origin.x if i == 0 else origin.z
		var d := dir.x if i == 0 else dir.z
		var bmin := aabb.position.x if i == 0 else aabb.position.z
		var bmax := aabb.end.x if i == 0 else aabb.end.z
		if absf(d) < 0.0001:
			if o < bmin or o > bmax:
				return -1.0
		else:
			var inv := 1.0 / d
			var t1 := (bmin - o) * inv
			var t2 := (bmax - o) * inv
			if t1 > t2:
				var tmp := t1
				t1 = t2
				t2 = tmp
			tmin = maxf(tmin, t1)
			tmax = minf(tmax, t2)
			if tmin > tmax:
				return -1.0
	return tmin if tmin > 0.0 else (tmax if tmax > 0.0 else -1.0)

func _is_target_in_cone(target: Vector3, origin: Vector3, forward: Vector3, v_range: float, half_angle: float, colliders: Array[AABB]) -> bool:
	var to_t := target - origin
	to_t.y = 0.0
	var dist := to_t.length()
	if dist > v_range or dist < 0.2:
		return false
	var norm_to := to_t / dist
	var dot := forward.dot(norm_to)
	if dot < cos(deg_to_rad(half_angle)):
		return false
	# Check line of sight occlusion
	var hit := _raycast_cone_edge(origin, norm_to, dist, colliders)
	return hit >= (dist - 0.25)
