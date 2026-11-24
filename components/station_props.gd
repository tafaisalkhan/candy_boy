class_name StationProps
extends RefCounted

const PLANT_SCENE_PATH: String = "res://assets/models/furniture/pottedPlant.glb"
const CONE_SCENE_PATH: String = "res://assets/models/cars/cone.glb"
const BENCH_SCENE_PATH: String = "res://assets/models/furniture/benchCushion.glb"

# 1. Red Snack & Drink Vending Machine
static func create_vending_machine(pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "VendingMachine"
	root.position = pos
	root.rotation_degrees.y = rot_y

	# Red Outer Cabinet
	var cab := MeshInstance3D.new()
	var c_box := BoxMesh.new()
	c_box.size = Vector3(1.3, 2.3, 0.85)
	cab.mesh = c_box
	cab.position = Vector3(0.0, 1.15, 0.0)
	var cab_mat := StandardMaterial3D.new()
	cab_mat.albedo_color = Color("#d63031")
	cab.material_override = cab_mat
	root.add_child(cab)

	# Glass Display Window
	var win := MeshInstance3D.new()
	var w_box := BoxMesh.new()
	w_box.size = Vector3(0.95, 1.3, 0.05)
	win.mesh = w_box
	win.position = Vector3(0.0, 1.35, 0.43)
	var win_mat := StandardMaterial3D.new()
	win_mat.albedo_color = Color("#2d3436")
	win_mat.roughness = 0.1
	win.material_override = win_mat
	root.add_child(win)

	# Snack & Beverage Rows (Bright colored cans & bags inside)
	var colors := [Color("#0984e3"), Color("#f1c40f"), Color("#00b894"), Color("#e84393")]
	for row in range(3):
		var ry: float = 0.95 + float(row) * 0.4
		for col in range(3):
			var cx: float = -0.32 + float(col) * 0.32
			var item := MeshInstance3D.new()
			var i_box := BoxMesh.new()
			i_box.size = Vector3(0.18, 0.25, 0.08)
			item.mesh = i_box
			item.position = Vector3(cx, ry, 0.44)
			var i_mat := StandardMaterial3D.new()
			i_mat.albedo_color = colors[(row + col) % colors.size()]
			item.material_override = i_mat
			root.add_child(item)

	# Bottom Dispensing Slot
	var slot := MeshInstance3D.new()
	var s_box := BoxMesh.new()
	s_box.size = Vector3(0.85, 0.35, 0.06)
	slot.mesh = s_box
	slot.position = Vector3(0.0, 0.35, 0.43)
	var slot_mat := StandardMaterial3D.new()
	slot_mat.albedo_color = Color("#111111")
	slot.material_override = slot_mat
	root.add_child(slot)

	return root

# 2. Yellow Subway Station ATM Machine
static func create_atm(pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "StationATM"
	root.position = pos
	root.rotation_degrees.y = rot_y

	# Yellow Cabinet
	var cab := MeshInstance3D.new()
	var c_box := BoxMesh.new()
	c_box.size = Vector3(1.1, 2.1, 0.75)
	cab.mesh = c_box
	cab.position = Vector3(0.0, 1.05, 0.0)
	var cab_mat := StandardMaterial3D.new()
	cab_mat.albedo_color = Color("#f1c40f")
	cab.material_override = cab_mat
	root.add_child(cab)

	# Blue "ATM" Top Signboard
	var sign_node := MeshInstance3D.new()
	var s_box := BoxMesh.new()
	s_box.size = Vector3(1.02, 0.42, 0.08)
	sign_node.mesh = s_box
	sign_node.position = Vector3(0.0, 1.82, 0.39)
	var sign_mat := StandardMaterial3D.new()
	sign_mat.albedo_color = Color("#0984e3")
	sign_node.material_override = sign_mat
	root.add_child(sign_node)

	var label_3d := Label3D.new()
	label_3d.text = "ATM"
	label_3d.position = Vector3(0.0, 1.82, 0.45)
	label_3d.font_size = 48
	label_3d.outline_size = 8
	label_3d.outline_modulate = Color.BLACK
	label_3d.modulate = Color.WHITE
	root.add_child(label_3d)

	# Screen
	var scr := MeshInstance3D.new()
	var sc_box := BoxMesh.new()
	sc_box.size = Vector3(0.75, 0.55, 0.05)
	scr.mesh = sc_box
	scr.position = Vector3(0.0, 1.25, 0.39)
	var sc_mat := StandardMaterial3D.new()
	sc_mat.albedo_color = Color("#2c3e50")
	scr.material_override = sc_mat
	root.add_child(scr)

	return root

# 3. Subway Turnstile / Ticket Barrier Gates
static func create_turnstile(pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "SubwayTurnstile"
	root.position = pos
	root.rotation_degrees.y = rot_y

	var post_mat := StandardMaterial3D.new()
	post_mat.albedo_color = Color("#2980b9")
	post_mat.metallic = 0.85
	post_mat.roughness = 0.25

	# Left and Right blue barrier pedestals
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var p_box := BoxMesh.new()
		p_box.size = Vector3(0.35, 1.1, 0.95)
		post.mesh = p_box
		post.position = Vector3(side * 0.75, 0.55, 0.0)
		post.material_override = post_mat
		root.add_child(post)

	# Yellow swinging gate paddle
	var gate := MeshInstance3D.new()
	var g_box := BoxMesh.new()
	g_box.size = Vector3(0.9, 0.45, 0.08)
	gate.mesh = g_box
	gate.position = Vector3(0.0, 0.65, 0.0)
	var g_mat := StandardMaterial3D.new()
	g_mat.albedo_color = Color("#f1c40f")
	gate.material_override = g_mat
	root.add_child(gate)

	return root

# 4. Station Clock Post
static func create_station_clock(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "StationClock"
	root.position = pos

	# Blue Pole Mount
	var pole := MeshInstance3D.new()
	var p_cyl := CylinderMesh.new()
	p_cyl.top_radius = 0.1
	p_cyl.bottom_radius = 0.14
	p_cyl.height = 2.2
	pole.mesh = p_cyl
	pole.position = Vector3(0.0, 1.1, 0.0)
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color("#2c3e50")
	pole_mat.metallic = 0.8
	pole.material_override = pole_mat
	root.add_child(pole)

	# Circular Clock Head
	var clock_head := MeshInstance3D.new()
	var c_cyl := CylinderMesh.new()
	c_cyl.top_radius = 0.45
	c_cyl.bottom_radius = 0.45
	c_cyl.height = 0.22
	clock_head.mesh = c_cyl
	clock_head.position = Vector3(0.0, 2.35, 0.0)
	clock_head.rotation_degrees.x = 90.0
	var head_mat := StandardMaterial3D.new()
	head_mat.albedo_color = Color("#34495e")
	clock_head.material_override = head_mat
	root.add_child(clock_head)

	# White Clock Face
	for face_z in [-0.12, 0.12]:
		var face := MeshInstance3D.new()
		var f_cyl := CylinderMesh.new()
		f_cyl.top_radius = 0.38
		f_cyl.bottom_radius = 0.38
		f_cyl.height = 0.03
		face.mesh = f_cyl
		face.position = Vector3(0.0, 2.35, face_z)
		face.rotation_degrees.x = 90.0
		var face_mat := StandardMaterial3D.new()
		face_mat.albedo_color = Color.WHITE
		face.material_override = face_mat
		root.add_child(face)

	return root

# 5. Potted Bush with Flowers (GLB Asset)
static func create_potted_plant(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "PottedPlant"
	root.position = pos

	var ps := load(PLANT_SCENE_PATH) as PackedScene if ResourceLoader.exists(PLANT_SCENE_PATH) else null
	if is_instance_valid(ps):
		var plant: Node3D = ps.instantiate() as Node3D
		plant.scale = Vector3.ONE * 0.95
		root.add_child(plant)
	return root

# 6. Caution Wet Floor Sign / Cone (GLB Asset)
static func create_caution_cone(pos: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "CautionCone"
	root.position = pos

	var cs := load(CONE_SCENE_PATH) as PackedScene if ResourceLoader.exists(CONE_SCENE_PATH) else null
	if is_instance_valid(cs):
		var cone: Node3D = cs.instantiate() as Node3D
		cone.scale = Vector3.ONE * 0.85
		root.add_child(cone)
	return root

# 7. Waiting Room Bench (GLB Asset)
static func create_waiting_bench(pos: Vector3, rot_y: float = 0.0) -> Node3D:
	var root := Node3D.new()
	root.name = "WaitingBench"
	root.position = pos
	root.rotation_degrees.y = rot_y

	var bs := load(BENCH_SCENE_PATH) as PackedScene if ResourceLoader.exists(BENCH_SCENE_PATH) else null
	if is_instance_valid(bs):
		var bench: Node3D = bs.instantiate() as Node3D
		bench.scale = Vector3.ONE * 0.95
		root.add_child(bench)
	return root
