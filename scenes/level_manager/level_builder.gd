class_name LevelBuilder
extends RefCounted

const WALL_H: float = 4.2
const WALL_T: float = 0.35

var wall_colliders: Array[AABB] = []
var active_doors: Array[DoorController] = []
var entrance_door_pos: Vector3 = Vector3.ZERO
var entrance_outside_pos: Vector3 = Vector3.ZERO

var wall_mat: StandardMaterial3D = null
var floor_mats: Array[StandardMaterial3D] = []


func _init() -> void:
	_init_materials()


func _init_materials() -> void:
	wall_mat = StandardMaterial3D.new()
	wall_mat.albedo_color = Color("#ecf0f1")
	wall_mat.roughness = 0.85

	var mat_light := StandardMaterial3D.new()
	mat_light.albedo_color = Color("#f8f9fa")
	mat_light.roughness = 0.9

	var mat_dark := StandardMaterial3D.new()
	mat_dark.albedo_color = Color("#e9ecef")
	mat_dark.roughness = 0.9

	floor_mats = [mat_light, mat_dark]


func build(level_root: Node3D, active_level_data: Dictionary, player_spawn_pos: Vector3) -> Dictionary:
	wall_colliders.clear()
	active_doors.clear()

	var rooms: Array = active_level_data.get("rooms", [])
	var room_depth: float = float(active_level_data.get("room_depth", 10.0))
	var house_w: float = float(active_level_data.get("house_width", 14.0))
	var half_w := house_w * 0.5

	for r_idx in range(rooms.size()):
		var r_data: Dictionary = rooms[r_idx]
		var is_positioned_room: bool = r_data.has("center")
		var r_center := Vector3(0.0, 0.0, -float(r_idx) * room_depth)
		var cur_w := house_w
		var cur_d := room_depth

		if is_positioned_room:
			var raw_c: Array = r_data["center"]
			r_center = Vector3(float(raw_c[0]), 0.0, float(raw_c[2]))
			cur_w = float(r_data.get("width", house_w))
			cur_d = float(r_data.get("depth", room_depth))

		var cur_half_w := cur_w * 0.5
		var cur_half_d := cur_d * 0.5

		var r_node := Node3D.new()
		r_node.name = "Room_%d" % r_idx
		level_root.add_child(r_node)

		# 1. Floor
		_create_room_floor(r_center, cur_w, cur_d, r_node)

		if not is_positioned_room:
			# Legacy linear 1D room building (Levels 1-6)
			var r_z_mid: float = r_center.z
			_create_wall(Vector3(-half_w, WALL_H * 0.5, r_z_mid), Vector3(WALL_T, WALL_H, room_depth), r_node)
			_create_wall(Vector3(half_w, WALL_H * 0.5, r_z_mid), Vector3(WALL_T, WALL_H, room_depth), r_node)

			if r_data.has("compartment_archetype"):
				var arch_name: String = String(r_data.get("compartment_archetype", ""))
				RoomCompartmentBuilder.build_archetype(
					arch_name,
					Vector3(0.0, 0.0, r_z_mid),
					half_w,
					room_depth,
					r_node,
					Callable(self, "_create_wall"),
					Callable(self, "_create_interior_door")
				)

			for comp in r_data.get("compartments", []):
				var c_raw: Array = comp.get("pos", [0.0, 0.0, 0.0])
				var c_size_raw: Array = comp.get("size", [0.35, WALL_H, 3.5])
				var c_pos := Vector3(float(c_raw[0]), float(c_size_raw[1]) * 0.5, r_z_mid + float(c_raw[2]))
				var c_size := Vector3(float(c_size_raw[0]), float(c_size_raw[1]), float(c_size_raw[2]))
				_create_wall(c_pos, c_size, r_node)

			if r_idx < rooms.size() - 1:
				var div_z := r_z_mid - room_depth * 0.5
				var doors_arr: Array = r_data.get("doors", [])
				if doors_arr.is_empty():
					doors_arr.append({ "x": 0.0, "width": 2.4, "color": "#f1be28" })

				var door_info: Dictionary = doors_arr[0]
				var dw: float = float(door_info.get("width", 2.4))
				var dx: float = float(door_info.get("x", 0.0))
				var d_color := Color("#27ae60")
				var req_key: bool = bool(door_info.get("requires_key", false))

				var left_w := (dx - dw * 0.5) - (-half_w)
				if left_w > 0.05:
					_create_wall(Vector3(-half_w + left_w * 0.5, WALL_H * 0.5, div_z), Vector3(left_w, WALL_H, WALL_T), r_node)
				var right_w := half_w - (dx + dw * 0.5)
				if right_w > 0.05:
					_create_wall(Vector3(half_w - right_w * 0.5, WALL_H * 0.5, div_z), Vector3(right_w, WALL_H, WALL_T), r_node)

				var door := DoorController.new()
				door.position = Vector3(dx, 0.0, div_z)
				door.setup(dw, d_color, req_key)
				r_node.add_child(door)
				active_doors.append(door)
			elif r_idx == rooms.size() - 1:
				var north_z := r_z_mid - room_depth * 0.5
				_create_wall(Vector3(0.0, WALL_H * 0.5, north_z), Vector3(house_w, WALL_H, WALL_T), r_node)

			if r_idx == 0:
				var south_z := r_z_mid + room_depth * 0.5
				var entry_x: float = player_spawn_pos.x
				var dw_s: float = 3.0
				var left_sw := (entry_x - dw_s * 0.5) - (-half_w)
				if left_sw > 0.05:
					_create_wall(Vector3(-half_w + left_sw * 0.5, WALL_H * 0.5, south_z), Vector3(left_sw, WALL_H, WALL_T), r_node)
				var right_sw := half_w - (entry_x + dw_s * 0.5)
				if right_sw > 0.05:
					_create_wall(Vector3(half_w - right_sw * 0.5, WALL_H * 0.5, south_z), Vector3(right_sw, WALL_H, WALL_T), r_node)
				var s_door := DoorController.new()
				s_door.position = Vector3(entry_x, 0.0, south_z)
				s_door.setup(dw_s, Color("#27ae60"), false)
				r_node.add_child(s_door)
				active_doors.append(s_door)
				entrance_door_pos = Vector3(entry_x, 0.0, south_z)
				entrance_outside_pos = Vector3(entry_x, 0.0, south_z + 3.2)
				_create_room_floor(Vector3(entry_x, 0.0, south_z + 2.1), 3.4, 4.2, r_node)

	return {
		"wall_colliders": wall_colliders,
		"active_doors": active_doors,
		"entrance_door_pos": entrance_door_pos,
		"entrance_outside_pos": entrance_outside_pos
	}


func _create_wall(pos: Vector3, sz: Vector3, parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = sz
	mi.mesh = box
	mi.position = pos
	if wall_mat != null:
		mi.material_override = wall_mat
	parent.add_child(mi)

	var aabb := AABB(pos - sz * 0.5, sz)
	wall_colliders.append(aabb)


func _create_interior_door(pos: Vector3, width: float, req_key: bool, parent: Node3D) -> void:
	var door := DoorController.new()
	door.position = pos
	door.setup(width, Color("#27ae60"), req_key)
	parent.add_child(door)
	active_doors.append(door)


func _create_room_floor(center: Vector3, w: float, d: float, parent: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(w, 0.1, d)
	mi.mesh = box
	mi.position = Vector3(center.x, -0.05, center.z)
	if not floor_mats.is_empty():
		mi.material_override = floor_mats[0]
	parent.add_child(mi)
