extends RefCounted
class_name OutdoorScenery

const TREE_PATHS := [
	"res://resources/meshes/scenery/SceneryModels_BubbleTree2.res",
	"res://resources/meshes/scenery/SceneryModels_Bubble_Tree_1.res",
	"res://resources/meshes/scenery/SceneryModels_Pine_Tree_Tall.res",
	"res://resources/meshes/scenery/SceneryModels_Pine_Tree_Small.res",
	"res://resources/meshes/scenery/SceneryModels_Christmas_Tree.res"
]

static var _cached_meshes: Array[Mesh] = []

static func _ensure_meshes() -> void:
	if not _cached_meshes.is_empty():
		return
	for path in TREE_PATHS:
		if ResourceLoader.exists(path):
			var m := load(path) as Mesh
			if m:
				_cached_meshes.append(m)

static func build_outdoor_trees(parent: Node3D, house_w: float, total_depth: float, north_z: float, south_z: float, colliders: Array[AABB], entrance_x: float = 0.0) -> void:
	_ensure_meshes()
	if _cached_meshes.is_empty():
		return

	var scenery_root := Node3D.new()
	scenery_root.name = "OutdoorScenery"
	parent.add_child(scenery_root)

	var half_w := house_w * 0.5
	var center_z := (north_z + south_z) * 0.5
	var yard_w := house_w + 30.0
	var yard_d := total_depth + 30.0

	# 1. Lush Outdoor Lawn Ground Plane
	var lawn := MeshInstance3D.new()
	lawn.name = "LawnGround"
	var box := BoxMesh.new()
	box.size = Vector3(yard_w, 0.1, yard_d)
	lawn.mesh = box
	lawn.position = Vector3(0.0, -0.07, center_z)

	var lawn_mat := StandardMaterial3D.new()
	var g_path := ProjectSettings.globalize_path("res://assets/textures/grass/aerial_grass_rock_diff_2k.jpg")
	var n_path := ProjectSettings.globalize_path("res://assets/textures/grass/aerial_grass_rock_nor_gl_2k.jpg")
	if FileAccess.file_exists(g_path):
		var g_img := Image.load_from_file(g_path)
		if g_img:
			lawn_mat.albedo_texture = ImageTexture.create_from_image(g_img)
	if FileAccess.file_exists(n_path):
		var n_img := Image.load_from_file(n_path)
		if n_img:
			lawn_mat.normal_enabled = true
			lawn_mat.normal_texture = ImageTexture.create_from_image(n_img)
	lawn_mat.albedo_color = Color("#2ecc71") # Lush vibrant outdoor garden lawn
	lawn_mat.uv1_scale = Vector3(18.0, 18.0, 1.0)
	lawn_mat.roughness = 0.85
	lawn.material_override = lawn_mat
	scenery_root.add_child(lawn)

	# 2. Spawn Trees around all 4 perimeter sides of the house walls
	var tree_idx := 0

	# West side trees (along left exterior wall)
	for z in range(int(north_z) - 2, int(south_z) + 3, 3):
		for x_off in [-half_w - 1.6, -half_w - 4.2]:
			var pos := Vector3(x_off + sin(z * 1.5) * 0.3, 0.0, float(z) + cos(z * 2.0) * 0.3)
			_spawn_tree(scenery_root, pos, tree_idx, colliders)
			tree_idx += 1

	# East side trees (along right exterior wall)
	for z in range(int(north_z) - 2, int(south_z) + 3, 3):
		for x_off in [half_w + 1.6, half_w + 4.2]:
			var pos := Vector3(x_off + cos(z * 1.8) * 0.3, 0.0, float(z) + sin(z * 1.4) * 0.3)
			_spawn_tree(scenery_root, pos, tree_idx, colliders)
			tree_idx += 1

	# North side trees (behind top room wall)
	for x in range(-int(half_w) - 1, int(half_w) + 2, 3):
		for z_off in [north_z - 1.8, north_z - 4.5]:
			var pos := Vector3(float(x) + sin(x * 1.3) * 0.3, 0.0, z_off + cos(x * 1.7) * 0.3)
			_spawn_tree(scenery_root, pos, tree_idx, colliders)
			tree_idx += 1

	# South side trees (outside bottom room wall - leave entrance/exit walkway completely clear!)
	for x in range(-int(half_w) - 1, int(half_w) + 2, 3):
		if absf(float(x) - entrance_x) < 3.6 or absf(float(x)) < 2.8:
			continue
		for z_off in [south_z + 2.0, south_z + 4.8]:
			var pos := Vector3(float(x) + cos(x * 1.2) * 0.3, 0.0, z_off + sin(x * 1.6) * 0.3)
			_spawn_tree(scenery_root, pos, tree_idx, colliders)
			tree_idx += 1

static func _spawn_tree(parent: Node3D, pos: Vector3, idx: int, _colliders: Array[AABB]) -> void:
	if _cached_meshes.is_empty():
		return
	var mesh: Mesh = _cached_meshes[idx % _cached_meshes.size()]
	var tree_inst := MeshInstance3D.new()
	tree_inst.mesh = mesh
	tree_inst.position = pos

	# Varied rotation and subtle scale variation for organic natural look
	var rot := float(idx * 67 % 360)
	tree_inst.rotation_degrees.y = rot
	var scale_var := 0.72 + float(idx % 5) * 0.06 # 0.72 to 0.96
	tree_inst.scale = Vector3.ONE * scale_var
	parent.add_child(tree_inst)
