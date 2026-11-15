class_name GuardController
extends Node3D

signal player_spotted(reason: String)

@export var max_vision_range: float = 3.8
@export var current_vision_range: float = 1.7
@export var vision_angle: float = 32.0
@export var move_speed: float = 3.0
@export var pause_duration: float = 0.55

const GRANNY_SCENE: PackedScene = preload("res://scenes/granny/granny.tscn")
const GUARD_SHADER: Shader = preload("res://scenes/stealth_escape/angry_granny.gdshader")

var visual_node: Node3D = null
var anim_player: AnimationPlayer = null
var cone_mesh: ImmediateMesh = null
var cone_instance: MeshInstance3D = null
var cone_mat: StandardMaterial3D = null
var badge_label_3d: Label3D = null
var alert_ring: MeshInstance3D = null

var is_intelligent: bool = false
var room_aabb: AABB = AABB()
var is_hunting_player: bool = false
var base_speed: float = 3.0

var waypoints: Array[Vector3] = []
var wp_idx: int = 1
var patrol_dir: int = 1
var pause_timer: float = 0.0
var facing_yaw: float = 0.0
var growth_speed: float = 0.75
var stuck_check_timer: float = 0.0
var last_stuck_pos: Vector3 = Vector3(999.0, 999.0, 999.0)
var escape_timer: float = 0.0
var escape_vector: Vector3 = Vector3.ZERO

func setup(p_waypoints: Array[Vector3], p_range: float = 2.0, p_angle: float = 26.0, p_speed: float = 3.0, p_tint: Color = Color("#1e3799")) -> void:
	waypoints = p_waypoints
	max_vision_range = p_range
	current_vision_range = p_range
	vision_angle = p_angle
	base_speed = p_speed
	move_speed = p_speed
	_build_visuals(p_tint)

func set_room_bounds(p_bounds: AABB) -> void:
	room_aabb = p_bounds

func set_intelligent(p_intel: bool) -> void:
	is_intelligent = p_intel
	if is_intelligent:
		move_speed = base_speed * 1.25
		current_vision_range = max_vision_range * 1.15
		if is_instance_valid(badge_label_3d):
			badge_label_3d.text = "🚨 SMART GRANNY 🚨"
			badge_label_3d.modulate = Color("#ff3838")
			badge_label_3d.outline_modulate = Color("#7f1d1d")
		if is_instance_valid(cone_mat):
			cone_mat.albedo_color = Color(1.0, 0.15, 0.15, 0.85)
		if alert_ring == null:
			_create_alert_ring()
		if is_instance_valid(alert_ring):
			alert_ring.visible = true
	else:
		move_speed = base_speed
		current_vision_range = max_vision_range
		if is_instance_valid(badge_label_3d):
			badge_label_3d.text = "AVOID GRANNY"
			badge_label_3d.modulate = Color.WHITE
			badge_label_3d.outline_modulate = Color.BLACK
		if is_instance_valid(cone_mat):
			cone_mat.albedo_color = Color(0.96, 0.12, 0.22, 0.72)
		if is_instance_valid(alert_ring):
			alert_ring.visible = false

func _create_alert_ring() -> void:
	alert_ring = MeshInstance3D.new()
	alert_ring.name = "AlertRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.55
	torus.outer_radius = 0.72
	alert_ring.mesh = torus
	alert_ring.position = Vector3(0.0, 0.06, 0.0)
	var a_mat := StandardMaterial3D.new()
	a_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	a_mat.albedo_color = Color(1.0, 0.1, 0.1, 0.85)
	a_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	alert_ring.material_override = a_mat
	add_child(alert_ring)

func _build_visuals(p_tint: Color) -> void:
	visual_node = Node3D.new()
	visual_node.name = "GrannyVisual"
	add_child(visual_node)

	# 1. Granny Model with Proportional Scale (1.22)
	var template: Node3D = GRANNY_SCENE.instantiate() as Node3D
	var model: Node3D = template.get_node("Granny") as Node3D
	template.remove_child(model)
	var orig_shooter: Node = model.get_node_or_null("Shooter")
	if orig_shooter:
		model.remove_child(orig_shooter)
		orig_shooter.free()
	template.free()

	model.position = Vector3.ZERO
	model.scale = Vector3.ONE * 1.22 # Taller and broader than the boy, naturally proportioned
	visual_node.add_child(model)

	anim_player = model.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if is_instance_valid(anim_player):
		_install_granny_walk_animation(anim_player)
		_play_anim("Walk")

	# Shader tint with proper texture mapping
	for found in model.find_children("*", "MeshInstance3D", true, false):
		var m := found as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var sm := m.get_active_material(s) as BaseMaterial3D
			var om := ShaderMaterial.new()
			om.shader = GUARD_SHADER
			if sm != null and sm.albedo_texture != null:
				om.set_shader_parameter("albedo_tex", sm.albedo_texture)
				om.set_shader_parameter("use_texture", true)
			else:
				om.set_shader_parameter("use_texture", false)
			om.set_shader_parameter("recolor_outfit", true)
			om.set_shader_parameter("outfit_tint", p_tint)
			m.set_surface_override_material(s, om)

	# Police Cap on Granny
	var cap_y: float = 1.16
	var cap_r: float = 0.21
	var cap_h: float = 0.12
	_create_cylinder("PoliceCapCrown", Vector3(0.0, cap_y, 0.0), cap_r, cap_h, Color("#3558ff"), visual_node)
	_create_box("PoliceCapVisor", Vector3(0.0, cap_y - 0.02, -cap_r * 0.8), Vector3(cap_r * 1.3, 0.03, cap_r * 0.9), Color("#111936"), visual_node)

	# Floating "AVOID GRANNY" Badge
	var badge_node := Node3D.new()
	badge_node.position = Vector3(0.0, 1.85, 0.0)
	add_child(badge_node)
	var label_3d := Label3D.new()
	label_3d.text = "AVOID GRANNY"
	label_3d.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var gfont := FontFile.new()
	if gfont.load_dynamic_font(ProjectSettings.globalize_path("res://assets/fonts/LuckiestGuy-Regular.ttf")) == OK:
		label_3d.font = gfont
	label_3d.font_size = 32
	label_3d.outline_size = 10
	label_3d.outline_modulate = Color.BLACK
	label_3d.modulate = Color.WHITE
	badge_node.add_child(label_3d)
	badge_label_3d = label_3d

	# 2. Vision Cone Mesh
	cone_mesh = ImmediateMesh.new()
	cone_instance = MeshInstance3D.new()
	cone_instance.name = "GrannyVisionCone"
	cone_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cone_instance.mesh = cone_mesh
	cone_mat = StandardMaterial3D.new()
	cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_mat.albedo_color = Color(0.96, 0.12, 0.22, 0.72)
	cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone_instance.material_override = cone_mat
	add_child(cone_instance)

	if waypoints.size() > 1:
		position = waypoints[0]
		wp_idx = 1
		patrol_dir = 1
		var to_next := (waypoints[1] - waypoints[0]).normalized()
		facing_yaw = atan2(to_next.x, to_next.z)
		visual_node.rotation.y = facing_yaw + PI

func _test_guard_collision(test_pos: Vector3, colliders: Array[AABB], radius: float = 0.40) -> bool:
	for aabb in colliders:
		if aabb.grow(radius).has_point(test_pos):
			return true
	return false

func update_guard(delta: float, p_pos: Vector3, wall_colliders: Array[AABB], is_player_invisible: bool = false) -> void:
	# Animate alert ring if active
	if is_instance_valid(alert_ring) and alert_ring.visible:
		alert_ring.rotation.y += delta * 2.5

	# Check if player has entered Granny's assigned section/room
	var player_in_section: bool = false
	if room_aabb.size.length_squared() > 1.0:
		player_in_section = room_aabb.has_point(p_pos)
	else:
		player_in_section = position.distance_to(p_pos) < 6.5

	# Intelligent Granny: Immediately turns to catch player when player enters her section!
	# Player MUST use a power-up (e.g. Invisibility) to escape / survive!
	if is_intelligent and player_in_section and not is_player_invisible:
		is_hunting_player = true
		var to_player := p_pos - position
		to_player.y = 0.0
		var dist_to_p := to_player.length()

		if dist_to_p > 0.05:
			var chase_dir := to_player.normalized()
			facing_yaw = lerp_angle(facing_yaw, atan2(chase_dir.x, chase_dir.z), minf(1.0, delta * 14.0))
			if is_instance_valid(visual_node):
				visual_node.rotation.y = facing_yaw + PI

			var chase_speed: float = move_speed * 1.25
			var step := chase_dir * chase_speed * delta
			var next_pos := position + step

			if not _test_guard_collision(next_pos, wall_colliders, 0.30):
				position = next_pos
			else:
				var slide_dir1 := Vector3(-chase_dir.z, 0.0, chase_dir.x)
				var slide_dir2 := Vector3(chase_dir.z, 0.0, -chase_dir.x)
				var chosen := slide_dir1 if (position + slide_dir1).distance_to(p_pos) < (position + slide_dir2).distance_to(p_pos) else slide_dir2
				if not _test_guard_collision(position + chosen * chase_speed * delta, wall_colliders, 0.30):
					position += chosen * chase_speed * delta

			_play_anim("Walk")

			# Render vision cone while chasing
			var g_fwd := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)).normalized()
			var org := position + Vector3(0.0, 0.05, 0.0)
			_render_vision_cone(org, g_fwd, current_vision_range, vision_angle, wall_colliders)

			if dist_to_p < 1.05:
				player_spotted.emit("Caught by Smart Granny! Use a Power-up!")
			return

	is_hunting_player = false
	# 1. Waypoint Patrol Navigation with Strict Wall Collision Resolution & Anti-Stuck Watchdog
	if waypoints.size() >= 2:
		# Anti-Stuck Watchdog: detect if Granny has been immobile for >0.6s
		stuck_check_timer += delta
		if stuck_check_timer >= 0.6:
			stuck_check_timer = 0.0
			if pause_timer <= 0.0 and position.distance_to(last_stuck_pos) < 0.20:
				# Stuck in place! Force cycle waypoint and step strongly towards open waypoint
				wp_idx = (wp_idx + 1) % waypoints.size()
				var target_wp := waypoints[wp_idx]
				var to_wp := (target_wp - position)
				to_wp.y = 0.0
				var escape_dir := to_wp.normalized() if to_wp.length() > 0.1 else Vector3.FORWARD
				position += escape_dir * 0.35
				facing_yaw = atan2(escape_dir.x, escape_dir.z)
				if is_instance_valid(visual_node):
					visual_node.rotation.y = facing_yaw + PI
				_play_anim("Walk")
			last_stuck_pos = position

		var target_wp := waypoints[wp_idx]
		var to_wp := target_wp - position
		to_wp.y = 0.0
		var dist := to_wp.length()

		if escape_timer > 0.0:
			escape_timer -= delta
			position += escape_vector * move_speed * delta
			facing_yaw = atan2(escape_vector.x, escape_vector.z)
			if is_instance_valid(visual_node):
				visual_node.rotation.y = facing_yaw + PI
			_play_anim("Walk")
		elif pause_timer > 0.0:
			pause_timer -= delta
			if pause_timer <= 0.0:
				_play_anim("Walk")
			else:
				_play_anim("Idle")
		elif dist < 0.45:
			wp_idx = posmod(wp_idx + patrol_dir, waypoints.size())
			if wp_idx == 0 or wp_idx == waypoints.size() - 1 or wp_idx == waypoints.size() / 2:
				pause_timer = 0.4
				_play_anim("Idle")
			else:
				pause_timer = 0.05
		else:
			var dir := to_wp.normalized()
			var step := dir * move_speed * delta
			var next_pos := position + step

			if _test_guard_collision(next_pos, wall_colliders, 0.28):
				# Collision with element! Advance to next waypoint and escape in clear direction!
				wp_idx = (wp_idx + 1) % waypoints.size()

				# Test candidate escape directions (perpendiculars and reverse)
				var candidate_dirs: Array[Vector3] = [
					Vector3(-dir.z, 0.0, dir.x),
					Vector3(dir.z, 0.0, -dir.x),
					-dir
				]
				var chosen_escape := -dir
				for cand in candidate_dirs:
					var test_step := position + cand * (move_speed * delta + 0.3)
					if not _test_guard_collision(test_step, wall_colliders, 0.28):
						chosen_escape = cand
						break

				escape_vector = chosen_escape
				escape_timer = 0.35
				position += escape_vector * (move_speed * delta + 0.08)
				facing_yaw = atan2(escape_vector.x, escape_vector.z)
				if is_instance_valid(visual_node):
					visual_node.rotation.y = facing_yaw + PI
				pause_timer = 0.0
				_play_anim("Walk")
			else:
				position = next_pos
				facing_yaw = lerp_angle(facing_yaw, atan2(dir.x, dir.z), minf(1.0, delta * 12.0))
				if is_instance_valid(visual_node):
					visual_node.rotation.y = facing_yaw + PI
				_play_anim("Walk")

		# Strict push-out: Repel guard if penetrating any wall collider
		for aabb in wall_colliders:
			var expanded := aabb.grow(0.30)
			if expanded.has_point(position):
				var c := aabb.get_center()
				var diff := position - c
				var half_size := aabb.size * 0.5 + Vector3(0.30, 0.0, 0.30)
				var overlap_x := half_size.x - absf(diff.x)
				var overlap_z := half_size.z - absf(diff.z)
				if overlap_x > 0.0 and overlap_z > 0.0:
					if overlap_x < overlap_z:
						position.x = c.x + signf(diff.x) * (aabb.size.x * 0.5 + 0.32)
					else:
						position.z = c.z + signf(diff.z) * (aabb.size.z * 0.5 + 0.32)

	# 2. Render Vision Cone with line-of-sight raycasting
	var guard_forward := Vector3(sin(facing_yaw), 0.0, cos(facing_yaw)).normalized()
	var origin := position + Vector3(0.0, 0.05, 0.0)
	_render_vision_cone(origin, guard_forward, current_vision_range, vision_angle, wall_colliders)

	# 4. Check player detection (ignored when invisible!)
	if not is_player_invisible and _is_target_in_cone(p_pos, origin, guard_forward, current_vision_range, vision_angle, wall_colliders):
		player_spotted.emit("Caught by Granny!")

func play_catch_confrontation(p_pos: Vector3) -> void:
	is_hunting_player = false
	pause_timer = 9999.0 # Freeze routine patrol
	escape_timer = 0.0
	if is_instance_valid(cone_instance):
		cone_instance.visible = false
	if is_instance_valid(alert_ring):
		alert_ring.visible = true

	var to_player := p_pos - position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > 0.05:
		facing_yaw = atan2(to_player.x, to_player.z)
		if is_instance_valid(visual_node):
			visual_node.rotation.y = facing_yaw + PI

		# If Granny is some distance away, lunge/step forward to confront boy face-to-face
		var step_dist := clampf(dist - 0.92, 0.0, 2.2)
		if step_dist > 0.1:
			var target_pos := position + to_player.normalized() * step_dist
			var tw := create_tween()
			tw.tween_property(self, "position", target_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_play_anim("Walk")
			tw.finished.connect(func():
				_play_anim("Idle")
			)
		else:
			_play_anim("Idle")

	if is_instance_valid(badge_label_3d):
		badge_label_3d.text = "🚨 GOTCHA!"
		badge_label_3d.modulate = Color(1.0, 0.2, 0.2)

func resume_after_continue() -> void:
	is_hunting_player = false
	pause_timer = 0.0
	escape_timer = 0.0
	if is_instance_valid(cone_instance):
		cone_instance.visible = true
	if is_instance_valid(alert_ring):
		alert_ring.visible = false
	if is_instance_valid(badge_label_3d):
		badge_label_3d.text = "AVOID GRANNY"
		badge_label_3d.modulate = Color.WHITE
	_play_anim("Walk")


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
	var hit := _raycast_cone_edge(origin, norm_to, dist, colliders)
	return hit >= (dist - 0.25)

func _create_cylinder(p_name: String, pos: Vector3, radius: float, height: float, color: Color, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = p_name
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mi.mesh = cyl
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _create_box(p_name: String, pos: Vector3, size: Vector3, color: Color, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = p_name
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.material_override = mat
	parent.add_child(mi)
	return mi

func _install_granny_walk_animation(p_anim: AnimationPlayer) -> void:
	var idle := p_anim.get_animation("Idle")
	var run := p_anim.get_animation("Run")
	if idle == null or run == null:
		return
	var walk := Animation.new()
	walk.length = 1.15
	walk.loop_mode = Animation.LOOP_LINEAR
	var sample_count := 24
	for run_track in run.get_track_count():
		var track_type := run.track_get_type(run_track)
		if track_type != Animation.TYPE_POSITION_3D and track_type != Animation.TYPE_ROTATION_3D:
			continue
		var track_path := run.track_get_path(run_track)
		var idle_track := idle.find_track(track_path, track_type)
		if idle_track < 0:
			continue
		var walk_track := walk.add_track(track_type)
		walk.track_set_path(walk_track, track_path)
		var bone_name := String(track_path)
		var blend := 0.5 if bone_name.contains("Leg") else 0.32
		if bone_name.contains("Hips"):
			blend = 0.2
		for frame in range(sample_count + 1):
			var fraction := float(frame) / float(sample_count)
			var run_time := minf(run.length - 0.0001, fraction * run.length)
			var walk_time := fraction * walk.length
			if track_type == Animation.TYPE_POSITION_3D:
				var idle_pos := idle.position_track_interpolate(idle_track, 0.2)
				var run_pos := run.position_track_interpolate(run_track, run_time)
				walk.position_track_insert_key(walk_track, walk_time, idle_pos.lerp(run_pos, blend))
			else:
				var idle_rotation := idle.rotation_track_interpolate(idle_track, 0.2)
				var run_rotation := run.rotation_track_interpolate(run_track, run_time)
				walk.rotation_track_insert_key(walk_track, walk_time, idle_rotation.slerp(run_rotation, blend))
	var library := AnimationLibrary.new()
	library.add_animation("Walk", walk)
	if not p_anim.has_animation_library("routine"):
		p_anim.add_animation_library("routine", library)

func _play_anim(anim_name: String) -> void:
	if not is_instance_valid(anim_player):
		return
	var selected := anim_name
	if anim_name == "Walk" and anim_player.has_animation("routine/Walk"):
		selected = "routine/Walk"
	elif not anim_player.has_animation(selected):
		if anim_player.has_animation("Run"):
			selected = "Run"
		elif anim_player.has_animation("Idle"):
			selected = "Idle"
		else:
			return
	if anim_player.current_animation != selected:
		anim_player.play(selected)
