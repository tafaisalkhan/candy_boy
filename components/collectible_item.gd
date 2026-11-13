class_name CollectibleItem
extends RefCounted

static func get_item_info(item_type: String) -> Dictionary:
	match item_type.to_lower():
		"ball", "toy_ball":
			return { "type": "ball", "name": "Toy Ball", "icon": "⚽", "color": Color("#e74c3c") }
		"bat", "toy_bat", "baseball_bat":
			return { "type": "bat", "name": "Toy Bat", "icon": "🏏", "color": Color("#3498db") }
		"game", "gameboy", "console":
			return { "type": "game", "name": "Game Boy", "icon": "🎮", "color": Color("#9b59b6") }
		"bear", "teddy", "teddy_bear":
			return { "type": "bear", "name": "Teddy Bear", "icon": "🧸", "color": Color("#d35400") }
		"trophy", "cup":
			return { "type": "trophy", "name": "Golden Trophy", "icon": "🏆", "color": Color("#f1c40f") }
		"gem", "diamond", "crystal":
			return { "type": "gem", "name": "Diamond Gem", "icon": "💎", "color": Color("#00cec9") }
		"robot", "toy_robot":
			return { "type": "robot", "name": "Toy Robot", "icon": "🤖", "color": Color("#0984e3") }
		"dice", "die", "game_dice":
			return { "type": "dice", "name": "Lucky Dice", "icon": "🎲", "color": Color("#ffffff") }
		"candy", _:
			return { "type": "candy", "name": "Candy", "icon": "🍭", "color": Color("#e84393") }

static func create_item_visual(item_type: String, custom_color: Color = Color.TRANSPARENT) -> Node3D:
	var info := get_item_info(item_type)
	var type_clean: String = String(info.get("type", "candy"))
	var base_col: Color = custom_color if custom_color != Color.TRANSPARENT else Color(info.get("color", Color("#e84393")))

	var root := Node3D.new()
	root.name = "MiniatureItem_%s" % type_clean

	match type_clean:
		"ball":
			_build_mini_ball(root, base_col)
		"bat":
			_build_mini_bat(root, base_col)
		"game":
			_build_mini_game(root, base_col)
		"bear":
			_build_mini_bear(root, base_col)
		"trophy":
			_build_mini_trophy(root, base_col)
		"gem":
			_build_mini_gem(root, base_col)
		"robot":
			_build_mini_robot(root, base_col)
		"dice":
			_build_mini_dice(root, base_col)
		"candy", _:
			_build_mini_candy(root, base_col)

	return root

static func _build_mini_candy(root: Node3D, col: Color) -> void:
	# Miniature Candy: length ~0.35m, radius 0.12m
	var core := MeshInstance3D.new()
	var c_mesh := CylinderMesh.new()
	c_mesh.top_radius = 0.12
	c_mesh.bottom_radius = 0.12
	c_mesh.height = 0.20
	core.mesh = c_mesh
	core.rotation_degrees.z = 90.0
	var c_mat := StandardMaterial3D.new()
	c_mat.albedo_color = col
	c_mat.roughness = 0.2
	c_mat.emission_enabled = true
	c_mat.emission = col
	c_mat.emission_energy_multiplier = 0.35
	core.material_override = c_mat
	root.add_child(core)

	# White Stripe across center
	var stripe := MeshInstance3D.new()
	var s_mesh := CylinderMesh.new()
	s_mesh.top_radius = 0.125
	s_mesh.bottom_radius = 0.125
	s_mesh.height = 0.06
	stripe.mesh = s_mesh
	stripe.rotation_degrees.z = 90.0
	var s_mat := StandardMaterial3D.new()
	s_mat.albedo_color = Color.WHITE
	s_mat.roughness = 0.2
	stripe.material_override = s_mat
	root.add_child(stripe)

	# Wrapper Twists
	var wing_mat := StandardMaterial3D.new()
	wing_mat.albedo_color = col.lightened(0.3)
	wing_mat.roughness = 0.35

	for sign in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var w_mesh := BoxMesh.new()
		w_mesh.size = Vector3(0.07, 0.14, 0.07)
		wing.mesh = w_mesh
		wing.position = Vector3(sign * 0.13, 0.0, 0.0)
		wing.rotation_degrees.y = sign * 25.0
		wing.material_override = wing_mat
		root.add_child(wing)

	_add_floating_label(root, "🍭 CANDY", 0.32)

static func _build_mini_ball(root: Node3D, col: Color) -> void:
	# Miniature Toy Ball: radius 0.16m (~32cm diameter toy ball)
	var ball := MeshInstance3D.new()
	var s_mesh := SphereMesh.new()
	s_mesh.radius = 0.16
	s_mesh.height = 0.32
	ball.mesh = s_mesh
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = col
	b_mat.roughness = 0.15
	b_mat.emission_enabled = true
	b_mat.emission = col
	b_mat.emission_energy_multiplier = 0.25
	ball.material_override = b_mat
	root.add_child(ball)

	# Decorative Yellow/White Equator Ring
	var ring := MeshInstance3D.new()
	var r_mesh := TorusMesh.new()
	r_mesh.inner_radius = 0.156
	r_mesh.outer_radius = 0.164
	ring.mesh = r_mesh
	ring.rotation_degrees.x = 90.0
	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = Color("#f1c40f")
	r_mat.roughness = 0.2
	ring.material_override = r_mat
	root.add_child(ring)

	_add_floating_label(root, "⚽ TOY BALL", 0.34)

static func _build_mini_bat(root: Node3D, col: Color) -> void:
	# Miniature Toy Bat: total length ~0.5m, tilted casually
	var pivot := Node3D.new()
	pivot.name = "BatTilt"
	pivot.rotation_degrees = Vector3(15.0, 0.0, 22.0)
	root.add_child(pivot)

	# Handle (white grip wrap)
	var handle := MeshInstance3D.new()
	var h_mesh := CylinderMesh.new()
	h_mesh.top_radius = 0.022
	h_mesh.bottom_radius = 0.022
	h_mesh.height = 0.18
	handle.mesh = h_mesh
	handle.position = Vector3(0.0, -0.10, 0.0)
	var h_mat := StandardMaterial3D.new()
	h_mat.albedo_color = Color("#f5f6fa")
	h_mat.roughness = 0.4
	handle.material_override = h_mat
	pivot.add_child(handle)

	# Knob end
	var knob := MeshInstance3D.new()
	var k_mesh := SphereMesh.new()
	k_mesh.radius = 0.03
	k_mesh.height = 0.06
	knob.mesh = k_mesh
	knob.position = Vector3(0.0, -0.19, 0.0)
	var k_mat := StandardMaterial3D.new()
	k_mat.albedo_color = col.darkened(0.2)
	knob.material_override = k_mat
	pivot.add_child(knob)

	# Bat Barrel
	var barrel := MeshInstance3D.new()
	var b_mesh := CylinderMesh.new()
	b_mesh.top_radius = 0.042
	b_mesh.bottom_radius = 0.026
	b_mesh.height = 0.32
	barrel.mesh = b_mesh
	barrel.position = Vector3(0.0, 0.12, 0.0)
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = col
	b_mat.roughness = 0.15
	b_mat.emission_enabled = true
	b_mat.emission = col
	b_mat.emission_energy_multiplier = 0.25
	barrel.material_override = b_mat
	pivot.add_child(barrel)

	_add_floating_label(root, "🏏 TOY BAT", 0.38)

static func _build_mini_game(root: Node3D, col: Color) -> void:
	# Handheld Retro Game Boy Console: 0.18m x 0.26m x 0.038m
	var body := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(0.18, 0.26, 0.038)
	body.mesh = b_mesh
	var b_mat := StandardMaterial3D.new()
	b_mat.albedo_color = col
	b_mat.roughness = 0.3
	body.material_override = b_mat
	root.add_child(body)

	# Dark Screen Bezel
	var bezel := MeshInstance3D.new()
	var bz_mesh := BoxMesh.new()
	bz_mesh.size = Vector3(0.14, 0.11, 0.004)
	bezel.mesh = bz_mesh
	bezel.position = Vector3(0.0, 0.045, 0.019)
	var bz_mat := StandardMaterial3D.new()
	bz_mat.albedo_color = Color("#2c3e50")
	bz_mat.roughness = 0.2
	bezel.material_override = bz_mat
	root.add_child(bezel)

	# Pixel Screen (Glowing matrix green)
	var screen := MeshInstance3D.new()
	var sc_mesh := BoxMesh.new()
	sc_mesh.size = Vector3(0.11, 0.08, 0.004)
	screen.mesh = sc_mesh
	screen.position = Vector3(0.0, 0.045, 0.021)
	var sc_mat := StandardMaterial3D.new()
	sc_mat.albedo_color = Color("#55efc4")
	sc_mat.emission_enabled = true
	sc_mat.emission = Color("#55efc4")
	sc_mat.emission_energy_multiplier = 0.75
	screen.material_override = sc_mat
	root.add_child(screen)

	# D-Pad (directional cross)
	var dpad_h := MeshInstance3D.new()
	var dh_mesh := BoxMesh.new()
	dh_mesh.size = Vector3(0.045, 0.014, 0.008)
	dpad_h.mesh = dh_mesh
	dpad_h.position = Vector3(-0.045, -0.055, 0.021)
	var dp_mat := StandardMaterial3D.new()
	dp_mat.albedo_color = Color("#1e272e")
	dpad_h.material_override = dp_mat
	root.add_child(dpad_h)

	var dpad_v := MeshInstance3D.new()
	var dv_mesh := BoxMesh.new()
	dv_mesh.size = Vector3(0.014, 0.045, 0.008)
	dpad_v.mesh = dv_mesh
	dpad_v.position = Vector3(-0.045, -0.055, 0.021)
	dpad_v.material_override = dp_mat
	root.add_child(dpad_v)

	# Action Buttons (Ruby Red)
	var btn_mat := StandardMaterial3D.new()
	btn_mat.albedo_color = Color("#e74c3c")

	var btn_a := MeshInstance3D.new()
	var btn_mesh := CylinderMesh.new()
	btn_mesh.top_radius = 0.012
	btn_mesh.bottom_radius = 0.012
	btn_mesh.height = 0.01
	btn_a.mesh = btn_mesh
	btn_a.rotation_degrees.x = 90.0
	btn_a.position = Vector3(0.055, -0.045, 0.021)
	btn_a.material_override = btn_mat
	root.add_child(btn_a)

	var btn_b := MeshInstance3D.new()
	btn_b.mesh = btn_mesh
	btn_b.rotation_degrees.x = 90.0
	btn_b.position = Vector3(0.035, -0.065, 0.021)
	btn_b.material_override = btn_mat
	root.add_child(btn_b)

	_add_floating_label(root, "🎮 GAME BOY", 0.34)

static func _build_mini_bear(root: Node3D, _col: Color) -> void:
	var bear_scene := load("res://assets/models/furniture/bear.glb") as PackedScene
	if bear_scene:
		var bear_inst := bear_scene.instantiate() as Node3D
		bear_inst.scale = Vector3.ONE * 0.45
		root.add_child(bear_inst)
	else:
		var s := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.15
		sm.height = 0.3
		s.mesh = sm
		root.add_child(s)

	_add_floating_label(root, "🧸 TEDDY", 0.34)

static func _build_mini_trophy(root: Node3D, col: Color) -> void:
	# Golden Trophy: Base + Stem + Cup + Handles
	var base := MeshInstance3D.new()
	var b_mesh := CylinderMesh.new()
	b_mesh.top_radius = 0.08
	b_mesh.bottom_radius = 0.10
	b_mesh.height = 0.06
	base.mesh = b_mesh
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = col
	g_mat.metallic = 0.9
	g_mat.roughness = 0.2
	base.material_override = g_mat
	root.add_child(base)

	var cup := MeshInstance3D.new()
	var c_mesh := CylinderMesh.new()
	c_mesh.top_radius = 0.12
	c_mesh.bottom_radius = 0.04
	c_mesh.height = 0.18
	cup.mesh = c_mesh
	cup.position = Vector3(0.0, 0.12, 0.0)
	cup.material_override = g_mat
	root.add_child(cup)

	_add_floating_label(root, "🏆 TROPHY", 0.35)

static func _build_mini_gem(root: Node3D, col: Color) -> void:
	# Glowing Crystal Prism
	var gem := MeshInstance3D.new()
	var g_mesh := SphereMesh.new()
	g_mesh.radius = 0.14
	g_mesh.height = 0.28
	g_mesh.radial_segments = 6
	g_mesh.rings = 3
	gem.mesh = g_mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = 0.3
	mat.roughness = 0.1
	mat.emission_enabled = true
	mat.emission = col
	mat.emission_energy_multiplier = 0.6
	gem.material_override = mat
	root.add_child(gem)

	_add_floating_label(root, "💎 GEM", 0.34)

static func _build_mini_robot(root: Node3D, col: Color) -> void:
	# Retro Toy Robot
	var body := MeshInstance3D.new()
	var b_mesh := BoxMesh.new()
	b_mesh.size = Vector3(0.18, 0.22, 0.12)
	body.mesh = b_mesh
	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = col
	r_mat.metallic = 0.6
	r_mat.roughness = 0.3
	body.material_override = r_mat
	root.add_child(body)

	var head := MeshInstance3D.new()
	var h_mesh := BoxMesh.new()
	h_mesh.size = Vector3(0.12, 0.10, 0.10)
	head.mesh = h_mesh
	head.position = Vector3(0.0, 0.16, 0.0)
	head.material_override = r_mat
	root.add_child(head)

	_add_floating_label(root, "🤖 ROBOT", 0.36)

static func _build_mini_dice(root: Node3D, col: Color) -> void:
	# Lucky Dice Cube with Pips
	var cube := MeshInstance3D.new()
	var c_mesh := BoxMesh.new()
	c_mesh.size = Vector3(0.20, 0.20, 0.20)
	cube.mesh = c_mesh
	var d_mat := StandardMaterial3D.new()
	d_mat.albedo_color = col
	d_mat.roughness = 0.2
	cube.material_override = d_mat
	root.add_child(cube)

	var pip_mat := StandardMaterial3D.new()
	pip_mat.albedo_color = Color("#e74c3c")
	var pip_mesh := SphereMesh.new()
	pip_mesh.radius = 0.025
	pip_mesh.height = 0.05
	for p_pos in [Vector3(0.0, 0.102, 0.0), Vector3(-0.05, 0.0, 0.102), Vector3(0.05, 0.0, 0.102)]:
		var pip := MeshInstance3D.new()
		pip.mesh = pip_mesh
		pip.position = p_pos
		pip.material_override = pip_mat
		root.add_child(pip)

	_add_floating_label(root, "🎲 DICE", 0.34)

static func _add_floating_label(parent: Node3D, text: String, y_pos: float) -> void:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.font_size = 28
	lbl.outline_size = 10
	lbl.outline_modulate = Color.BLACK
	lbl.modulate = Color("#ffeaa7")
	lbl.position = Vector3(0.0, y_pos, 0.0)
	parent.add_child(lbl)
