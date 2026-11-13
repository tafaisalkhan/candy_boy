class_name KeyPickup
extends Node3D

signal key_collected

@export var is_collected: bool = false
var base_y: float = 0.75
var pivot: Node3D = null

func _ready() -> void:
	_build_visuals()

func setup(p_pos: Vector3) -> void:
	position = p_pos + Vector3(0.0, 0.75, 0.0)
	base_y = position.y

func _build_visuals() -> void:
	pivot = Node3D.new()
	pivot.name = "KeyPivot"
	pivot.scale = Vector3.ONE * 1.45
	add_child(pivot)

	var gold_mat := StandardMaterial3D.new()
	gold_mat.albedo_color = Color("#f1c40f")
	gold_mat.metallic = 0.95
	gold_mat.roughness = 0.15
	gold_mat.emission_enabled = true
	gold_mat.emission = Color("#f39c12")
	gold_mat.emission_energy_multiplier = 0.75

	# Key Head Ring
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.10
	ring_mesh.outer_radius = 0.20
	ring.mesh = ring_mesh
	ring.rotation_degrees.x = 90.0
	ring.material_override = gold_mat
	pivot.add_child(ring)

	# Key Shaft
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = 0.035
	shaft_mesh.bottom_radius = 0.035
	shaft_mesh.height = 0.44
	shaft.mesh = shaft_mesh
	shaft.position = Vector3(0.0, -0.3, 0.0)
	shaft.material_override = gold_mat
	pivot.add_child(shaft)

	# Key Teeth
	var tooth1 := MeshInstance3D.new()
	var t1_mesh := BoxMesh.new()
	t1_mesh.size = Vector3(0.12, 0.06, 0.04)
	tooth1.mesh = t1_mesh
	tooth1.position = Vector3(0.08, -0.42, 0.0)
	tooth1.material_override = gold_mat
	pivot.add_child(tooth1)

	var tooth2 := MeshInstance3D.new()
	var t2_mesh := BoxMesh.new()
	t2_mesh.size = Vector3(0.09, 0.06, 0.04)
	tooth2.mesh = t2_mesh
	tooth2.position = Vector3(0.06, -0.30, 0.0)
	tooth2.material_override = gold_mat
	pivot.add_child(tooth2)

	# Glow aura
	var glow := MeshInstance3D.new()
	var glow_mesh := SphereMesh.new()
	glow_mesh.radius = 0.35
	glow_mesh.height = 0.7
	var glow_mat := StandardMaterial3D.new()
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.22)
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.mesh = glow_mesh
	glow.material_override = glow_mat
	pivot.add_child(glow)

	# Floating 3D Key Label so player easily spots the key!
	var lbl := Label3D.new()
	lbl.text = "KEY"
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var gfont := FontFile.new()
	if gfont.load_dynamic_font(ProjectSettings.globalize_path("res://assets/fonts/LuckiestGuy-Regular.ttf")) == OK:
		lbl.font = gfont
	lbl.font_size = 48
	lbl.outline_size = 14
	lbl.outline_modulate = Color.BLACK
	lbl.modulate = Color("#f1c40f")
	lbl.position = Vector3(0.0, 0.72, 0.0)
	add_child(lbl)

func update_animation(delta: float, p_pos: Vector3) -> bool:
	if is_collected or not is_instance_valid(pivot):
		return false

	pivot.rotation.y += delta * 2.8
	position.y = base_y + sin(Time.get_ticks_msec() * 0.005) * 0.1

	if global_position.distance_to(p_pos) < 1.35:
		collect(p_pos)
		return true
	return false

func collect(p_pos: Vector3) -> void:
	if is_collected:
		return
	is_collected = true
	key_collected.emit()

	var tw := create_tween()
	tw.tween_property(pivot, "position:y", pivot.position.y + 1.2, 0.28)
	tw.parallel().tween_property(pivot, "scale", Vector3.ZERO, 0.28)
	tw.tween_callback(queue_free)

	_show_key_banner(p_pos)

func _show_key_banner(p_pos: Vector3) -> void:
	var label := Label3D.new()
	label.text = "🔑 KEY ACQUIRED!\nLOCKED DOORS OPEN"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 38
	label.outline_size = 12
	label.outline_modulate = Color.BLACK
	label.modulate = Color("#f1c40f")
	label.position = p_pos + Vector3(0.0, 2.3, 0.0)
	get_parent().add_child(label)

	var tw := create_tween()
	tw.tween_property(label, "position:y", p_pos.y + 3.4, 1.3)
	tw.parallel().tween_property(label, "modulate:a", 0.0, 1.3)
	tw.tween_callback(label.queue_free)
