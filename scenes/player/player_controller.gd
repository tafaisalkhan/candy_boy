class_name PlayerController
extends Node3D

@export var move_speed: float = 4.0

var mesh_root: Node3D = null
var anim_player: AnimationPlayer = null
var target_rotation: float = PI
var is_moving: bool = false

var is_invisible: bool = false
var is_wall_pass: bool = false
var speed_multiplier: float = 1.0

var footstep_mgr: RefCounted = null


func _ready() -> void:
	pass


func setup(model_scene: PackedScene, skin_texture: Texture2D = null) -> void:
	if model_scene == null:
		return
	var inst := model_scene.instantiate() as Node3D
	inst.scale = Vector3.ONE * 0.55
	inst.rotation.y = PI
	add_child(inst)
	mesh_root = inst

	if skin_texture != null:
		for found in mesh_root.find_children("*", "MeshInstance3D", true, false):
			var mi := found as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var orig := mi.get_active_material(s)
				var mat := StandardMaterial3D.new()
				if orig is StandardMaterial3D:
					mat = (orig as StandardMaterial3D).duplicate() as StandardMaterial3D
				mat.albedo_texture = skin_texture
				mi.set_surface_override_material(s, mat)

	anim_player = mesh_root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim_player == null:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		mesh_root.add_child(anim_player)

	_load_anim("Idle", "res://assets/models/boys/Animations/idle.fbx", "Root|Idle")
	_load_anim("Run", "res://assets/models/boys/Animations/run.fbx", "Root|Run")

	if anim_player.has_animation("Idle"):
		anim_player.play("Idle")


func _load_anim(anim_name: String, path: String, source_anim: String) -> void:
	var scn := load(path) as PackedScene
	if scn == null or not is_instance_valid(anim_player):
		return
	var root_node := scn.instantiate()
	var src := root_node.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src == null or not src.has_animation(source_anim):
		root_node.free()
		return

	var lib: AnimationLibrary = null
	if anim_player.has_animation_library(""):
		lib = anim_player.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		anim_player.add_animation_library("", lib)

	var anim := src.get_animation(source_anim).duplicate(true) as Animation
	anim.loop_mode = Animation.LOOP_LINEAR
	if lib.has_animation(anim_name):
		lib.remove_animation(anim_name)
	lib.add_animation(anim_name, anim)
	root_node.free()


func move(move_dir: Vector3, delta: float, wall_colliders: Array[AABB], props: Array, containers: Array) -> void:
	if move_dir.length_squared() <= 0.001:
		is_moving = false
		if is_instance_valid(anim_player) and anim_player.has_animation("Idle") and anim_player.current_animation != "Idle":
			anim_player.play("Idle")
		return

	is_moving = true
	move_dir = move_dir.normalized()
	target_rotation = atan2(move_dir.x, move_dir.z)

	var cur_speed := move_speed * speed_multiplier
	var step := move_dir * cur_speed * delta

	# X movement
	var next_x := position + Vector3(step.x, 0.0, 0.0)
	if not _is_colliding(next_x, wall_colliders, props, containers):
		position.x = next_x.x

	# Z movement
	var next_z := position + Vector3(0.0, 0.0, step.z)
	if not _is_colliding(next_z, wall_colliders, props, containers):
		position.z = next_z.z

	# Cabinet push-out guard
	for c in containers:
		var aabb: AABB = c.get("collider_aabb", AABB())
		if aabb.size.length_squared() > 0.01 and aabb.grow(0.26).has_point(position):
			var cc := aabb.get_center()
			var diff := position - cc
			var half := aabb.size * 0.5 + Vector3(0.26, 0.0, 0.26)
			var ox := half.x - absf(diff.x)
			var oz := half.z - absf(diff.z)
			if ox > 0.0 and oz > 0.0:
				if ox < oz:
					position.x = cc.x + (1.0 if diff.x >= 0.0 else -1.0) * (aabb.size.x * 0.5 + 0.28)
				else:
					position.z = cc.z + (1.0 if diff.z >= 0.0 else -1.0) * (aabb.size.z * 0.5 + 0.28)

	# Rotate mesh smoothly
	if is_instance_valid(mesh_root):
		mesh_root.rotation.y = lerp_angle(mesh_root.rotation.y, target_rotation, delta * 14.0)

	# Play Run animation
	if is_instance_valid(anim_player) and anim_player.has_animation("Run") and anim_player.current_animation != "Run":
		anim_player.play("Run")


func _is_colliding(test_pos: Vector3, wall_colliders: Array[AABB], props: Array, containers: Array) -> bool:
	if not is_wall_pass:
		for aabb in wall_colliders:
			if aabb.grow(0.32).has_point(test_pos):
				return true

	for c in containers:
		var cab_aabb: AABB = c.get("collider_aabb", AABB())
		if cab_aabb.size.length_squared() > 0.01 and cab_aabb.grow(0.26).has_point(test_pos):
			return true

	for p in props:
		if is_instance_valid(p) and test_pos.distance_to(p.position) < (p.prop_radius + 0.28):
			return true

	return false


func set_transparency(alpha: float, rim_col: Color = Color.TRANSPARENT) -> void:
	if not is_instance_valid(mesh_root):
		return
	for found in mesh_root.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.get_surface_override_material(s) as StandardMaterial3D
			if mat != null:
				if alpha < 0.99:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.albedo_color.a = alpha
					mat.emission_enabled = true
					mat.emission = rim_col
					mat.emission_energy_multiplier = 0.9
				else:
					mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
					mat.albedo_color.a = 1.0
					mat.emission_enabled = false
