class_name SubwayTrain
extends Node3D

func setup(total_depth: float = 24.0) -> void:
	var track_z: float = -total_depth * 0.5 - 3.8
	var tie_col := Color("#8c5028")

	# 1. Wooden Railway Ties
	for tx in range(-20, 21, 2):
		_create_box("TrackTie", Vector3(float(tx), 0.05, track_z), Vector3(1.3, 0.1, 3.4), tie_col, false)

	# 2. Steel Rails
	var rail_col := Color("#586375")
	var r_mat := StandardMaterial3D.new()
	r_mat.albedo_color = rail_col
	r_mat.metallic = 0.85
	r_mat.roughness = 0.3
	_create_rail("RailNorth", Vector3(0.0, 0.15, track_z - 1.1), Vector3(48.0, 0.12, 0.14), r_mat)
	_create_rail("RailSouth", Vector3(0.0, 0.15, track_z + 1.1), Vector3(48.0, 0.12, 0.14), r_mat)

	# 3. Cartoon Subway Train Car
	var train_car := Node3D.new()
	train_car.name = "SubwayTrainCar"
	train_car.position = Vector3(0.0, 0.2, track_z)
	add_child(train_car)

	var train_w: float = 16.0
	var train_d: float = 3.0

	# Dark Chassis
	_create_box("TrainChassis", Vector3(0.0, 0.25, 0.0), Vector3(train_w - 0.6, 0.5, train_d - 0.4), Color("#0e2547"), false, train_car)
	# Bright Yellow Bottom Band
	_create_box("TrainYellowBand", Vector3(0.0, 0.8, 0.0), Vector3(train_w, 0.65, train_d), Color("#fedb26"), false, train_car)
	# Crisp White Center Stripe
	_create_box("TrainWhiteStripe", Vector3(0.0, 1.25, 0.0), Vector3(train_w + 0.04, 0.22, train_d + 0.04), Color.WHITE, false, train_car)
	# Vibrant Blue Main Body
	_create_box("TrainBlueBody", Vector3(0.0, 2.1, 0.0), Vector3(train_w, 1.5, train_d), Color("#0a84e3"), false, train_car)
	# Curved White Roof
	_create_box("TrainRoof", Vector3(0.0, 3.0, 0.0), Vector3(train_w - 0.6, 0.35, train_d - 0.3), Color("#edf4fc"), false, train_car)

	# Roof Air Conditioning Vents
	for vx in [-4.5, 0.0, 4.5]:
		_create_box("RoofVent", Vector3(vx, 3.25, 0.0), Vector3(1.8, 0.18, 1.2), Color("#747d8c"), false, train_car)

	# Rounded Nose Cabins on Left & Right Ends
	for side in [-1.0, 1.0]:
		var nose_x: float = side * (train_w * 0.5 + 0.5)
		_create_box("NoseBlue", Vector3(nose_x, 2.0, 0.0), Vector3(1.0, 1.8, train_d * 0.85), Color("#0a84e3"), false, train_car)
		_create_box("NoseYellow", Vector3(nose_x, 0.75, 0.0), Vector3(1.0, 0.7, train_d * 0.85), Color("#fedb26"), false, train_car)
		_create_box("Windshield", Vector3(nose_x, 2.1, 0.0), Vector3(1.04, 0.9, train_d * 0.65), Color("#48dbfb"), false, train_car)

	# Passenger Windows with White Frames
	for wx in [-5.5, -3.2, 3.2, 5.5]:
		_create_box("WindowGlass", Vector3(wx, 2.15, train_d * 0.5 + 0.03), Vector3(1.5, 0.85, 0.06), Color("#54a0ff"), false, train_car)
		_create_box("WindowFrame", Vector3(wx, 2.15, train_d * 0.5 + 0.02), Vector3(1.65, 0.98, 0.04), Color.WHITE, false, train_car)

	# Center Entrance Door
	var door_opening_w: float = 2.4
	_create_box("DoorwayBacking", Vector3(0.0, 1.6, 0.0), Vector3(door_opening_w, 2.5, train_d - 0.1), Color("#041e42"), false, train_car)
	_create_box("DoorwayFrame", Vector3(0.0, 1.65, train_d * 0.5 + 0.05), Vector3(door_opening_w + 0.35, 2.65, 0.15), Color("#fedb26"), false, train_car)
	_create_box("DoorwayThreshold", Vector3(0.0, 0.32, train_d * 0.5 + 0.3), Vector3(door_opening_w + 0.2, 0.15, 0.6), Color("#27ae60"), false, train_car)

	# Pulsing Green Chevron Arrow
	var arrow_node := Node3D.new()
	arrow_node.name = "PulsingGreenArrow"
	arrow_node.position = Vector3(0.0, 2.3, train_d * 0.5 + 0.35)
	train_car.add_child(arrow_node)

	var arrow_mesh_inst := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.8, 0.9, 0.2)
	arrow_mesh_inst.mesh = prism
	arrow_mesh_inst.rotation_degrees = Vector3(0.0, 0.0, 180.0)
	var arrow_mat := StandardMaterial3D.new()
	arrow_mat.albedo_color = Color("#2ecc71")
	arrow_mat.emission_enabled = true
	arrow_mat.emission = Color("#2ecc71")
	arrow_mat.emission_energy_multiplier = 1.6
	arrow_mesh_inst.material_override = arrow_mat
	arrow_node.add_child(arrow_mesh_inst)

func _create_box(b_name: String, pos: Vector3, size: Vector3, col: Color, _dummy: bool = false, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = b_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mi.material_override = mat
	var target_parent: Node3D = parent if parent != null else self
	target_parent.add_child(mi)
	return mi

func _create_rail(r_name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = r_name
	var box := BoxMesh.new()
	box.size = size
	mi.mesh = box
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi
