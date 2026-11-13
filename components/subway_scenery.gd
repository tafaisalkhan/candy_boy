class_name SubwayScenery
extends RefCounted

# Builds realistic railway tracks with wooden ties and yellow & blue subway trains
# matching WhatsApp Image 2026-11-09 at 13.16.11.jpeg
static func build_subway_backdrop(parent: Node3D, north_z: float, hall_w: float) -> void:
	var root := Node3D.new()
	root.name = "SubwayBackdrop"
	parent.add_child(root)

	# 1. Vibrant Purple Platform Exterior Ground (matching reference screenshot)
	var ground := MeshInstance3D.new()
	ground.name = "PurplePlatformGround"
	var g_mesh := BoxMesh.new()
	g_mesh.size = Vector3(hall_w + 50.0, 0.1, 70.0)
	ground.mesh = g_mesh
	ground.position = Vector3(0.0, -0.06, 0.0)
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color("#6c5ce7") # Authentic vibrant lavender/purple from screenshot
	g_mat.roughness = 0.55
	ground.material_override = g_mat
	root.add_child(ground)

	# 2. Track 1 (Directly behind the North station wall: z = north_z - 2.8)
	_build_rail_track(root, north_z - 2.8, 38.0)
	# 3. Track 2 (Second outer track: z = north_z - 6.2)
	_build_rail_track(root, north_z - 6.2, 38.0)

	# 4. Subway Train 1 on Track 1 (Parked with open door right at station exit x = 2.0)
	_build_subway_train(root, Vector3(0.0, 0.0, north_z - 2.8), true)

	# 5. Subway Train 2 on Track 2 (Background train)
	_build_subway_train(root, Vector3(-4.0, 0.0, north_z - 6.2), false)

# Builds wooden ties and two parallel steel rails
static func _build_rail_track(parent: Node3D, track_z: float, length: float) -> void:
	var track_node := Node3D.new()
	track_node.position = Vector3(0.0, 0.0, track_z)
	parent.add_child(track_node)

	# Wooden Ties (Sleepers) every 0.75m
	var tie_mat := StandardMaterial3D.new()
	tie_mat.albedo_color = Color("#e17055") # Warm terracotta/brown wood
	tie_mat.roughness = 0.85

	var count := int(length / 0.75)
	for i in range(-count / 2, count / 2 + 1):
		var tie := MeshInstance3D.new()
		var t_mesh := BoxMesh.new()
		t_mesh.size = Vector3(0.24, 0.08, 2.0)
		tie.mesh = t_mesh
		tie.position = Vector3(float(i) * 0.75, 0.04, 0.0)
		tie.material_override = tie_mat
		track_node.add_child(tie)

	# Two Steel Rails
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color("#b2bec3")
	rail_mat.metallic = 0.95
	rail_mat.roughness = 0.2

	for rz in [-0.7, 0.7]:
		var rail := MeshInstance3D.new()
		var r_mesh := BoxMesh.new()
		r_mesh.size = Vector3(length, 0.12, 0.09)
		rail.mesh = r_mesh
		rail.position = Vector3(0.0, 0.12, rz)
		rail.material_override = rail_mat
		track_node.add_child(rail)

# Builds a stylized Subway Train car (Bright Yellow bottom, Vivid Blue top & roof)
static func _build_subway_train(parent: Node3D, pos: Vector3, has_exit_door: bool) -> void:
	var train := Node3D.new()
	train.name = "SubwayTrain"
	train.position = pos
	parent.add_child(train)

	var car_w := 18.0
	var car_h := 2.6
	var car_d := 2.3

	# Materials
	var yellow_mat := StandardMaterial3D.new()
	yellow_mat.albedo_color = Color("#f1c40f") # Bright Subway Yellow
	yellow_mat.roughness = 0.25

	var blue_mat := StandardMaterial3D.new()
	blue_mat.albedo_color = Color("#0984e3") # Vivid Subway Blue
	blue_mat.roughness = 0.25

	var window_mat := StandardMaterial3D.new()
	window_mat.albedo_color = Color("#2d3436") # Dark tinted glass
	window_mat.roughness = 0.15

	var vent_mat := StandardMaterial3D.new()
	vent_mat.albedo_color = Color("#dfe6e9")

	# Bottom Yellow Body
	var body_bot := MeshInstance3D.new()
	var bot_mesh := BoxMesh.new()
	bot_mesh.size = Vector3(car_w, car_h * 0.45, car_d)
	body_bot.mesh = bot_mesh
	body_bot.position = Vector3(0.0, car_h * 0.225 + 0.15, 0.0)
	body_bot.material_override = yellow_mat
	train.add_child(body_bot)

	# Top Blue Body
	var body_top := MeshInstance3D.new()
	var top_mesh := BoxMesh.new()
	top_mesh.size = Vector3(car_w, car_h * 0.55, car_d * 0.96)
	body_top.mesh = top_mesh
	body_top.position = Vector3(0.0, car_h * 0.725 + 0.15, 0.0)
	body_top.material_override = blue_mat
	train.add_child(body_top)

	# Windows along the train side (facing the station: z = +car_d * 0.5)
	for i in range(-4, 5):
		# Skip window at x = 2.0 if this is the open boarding door!
		if has_exit_door and absf(float(i) * 1.8 - 2.0) < 1.0:
			continue
		var win := MeshInstance3D.new()
		var w_mesh := BoxMesh.new()
		w_mesh.size = Vector3(1.1, 0.75, 0.06)
		win.mesh = w_mesh
		win.position = Vector3(float(i) * 1.8, 1.6, car_d * 0.49)
		win.material_override = window_mat
		train.add_child(win)

	# Roof Ventilation Units
	for rx in [-6.0, -2.0, 2.0, 6.0]:
		var vent := MeshInstance3D.new()
		var v_mesh := BoxMesh.new()
		v_mesh.size = Vector3(1.4, 0.22, 1.2)
		vent.mesh = v_mesh
		vent.position = Vector3(rx, car_h + 0.24, 0.0)
		vent.material_override = vent_mat
		train.add_child(vent)

	# Train Aerodynamic Rounded Cab Nose (at right end)
	var nose := MeshInstance3D.new()
	var n_mesh := SphereMesh.new()
	n_mesh.radius = 1.15
	n_mesh.height = 2.3
	nose.mesh = n_mesh
	nose.position = Vector3(car_w * 0.5, 1.3, 0.0)
	nose.scale = Vector3(1.2, 1.0, 1.0)
	nose.material_override = yellow_mat
	train.add_child(nose)

	# Green Boarding Door with Pulsing Exit Arrow (pointing to train door)
	if has_exit_door:
		var door_frame := MeshInstance3D.new()
		var df_mesh := BoxMesh.new()
		df_mesh.size = Vector3(1.8, 2.1, 0.08)
		door_frame.mesh = df_mesh
		door_frame.position = Vector3(2.0, 1.1, car_d * 0.49)
		var d_mat := StandardMaterial3D.new()
		d_mat.albedo_color = Color("#00b894") # Bright train door cyan/green
		door_frame.material_override = d_mat
		train.add_child(door_frame)

		# Pulsing Green Exit Arrow over door (matching reference screenshot!)
		var arrow_lbl := Label3D.new()
		arrow_lbl.text = "🔻"
		arrow_lbl.font_size = 56
		arrow_lbl.outline_size = 12
		arrow_lbl.outline_modulate = Color.BLACK
		arrow_lbl.modulate = Color("#2ecc71")
		arrow_lbl.position = Vector3(2.0, 2.8, car_d * 0.5 + 0.3)
		train.add_child(arrow_lbl)
