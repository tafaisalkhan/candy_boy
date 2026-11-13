class_name RoomCompartmentBuilder
extends RefCounted

const WALL_H: float = 2.6
const WALL_T: float = 0.35

# Build compartments within a Big Hall based on archetype name
# Returns metadata Dictionary:
# {
#   "cabinet_spots": Array[Dictionary], # [ { "pos": Vector3, "rot_y": float, "container": "atm"|"cupboard" } ]
#   "patrol_routes": Array[Array],      # [ [ Vector3, Vector3, ... ], ... ]
#   "exit_door": Dictionary,            # { "x": float, "width": float, "z": float }
#   "floor_pads": Array[Vector3]        # Positions of decorative circular floor buttons
# }
static func build_archetype(archetype: String, r_center: Vector3, half_w: float, depth: float, parent: Node3D, create_wall_cb: Callable, create_door_cb: Callable) -> Dictionary:
	match archetype.to_lower():
		"station_hall", "station_concourse", "reference_station":
			return _build_station_hall(r_center, half_w, depth, parent, create_wall_cb, create_door_cb)
		"dual_wing_depot", "two_chambers":
			return _build_dual_wing_depot(r_center, half_w, depth, parent, create_wall_cb)
		"serpentine_terminal", "three_galleries":
			return _build_serpentine_terminal(r_center, half_w, depth, parent, create_wall_cb)
		"ring_vault_gallery", "four_quadrants":
			return _build_ring_vault_gallery(r_center, half_w, depth, parent, create_wall_cb, create_door_cb)
		_:
			return _build_station_hall(r_center, half_w, depth, parent, create_wall_cb, create_door_cb)

# 1. Exact 1:1 replica of WhatsApp Image 2026-11-09 at 13.16.11.jpeg:
# - Big Hall with inner border walls
# - North green exit door at x = 2.0 leading into the subway train
# - Left vertical alley corridor with floor button
# - Central green double doors flanked by 4 turnstiles
# - Top vertical divider creating the ATM chamber (left) and exit vestibule (right)
# - Yellow/Blue ATM machine against the top wall
# - Lower-right alcove with yellow barrier gate
# - Multi-point patrol routes for Grannies looping around the halls!
static func _build_station_hall(r_center: Vector3, half_w: float, depth: float, parent: Node3D, create_wall_cb: Callable, create_door_cb: Callable) -> Dictionary:
	var r_z := r_center.z
	var half_d := depth * 0.5
	var north_z := r_z - half_d
	var south_z := r_z + half_d

	# 1. Left Vertical Alley Wall (At x = -2.8, runs from south wall z = south_z up to z = r_z - 4.0)
	var left_wall_len := (south_z) - (r_z - 4.0)
	var left_wall_mid_z := (r_z - 4.0) + left_wall_len * 0.5
	create_wall_cb.call(Vector3(-2.8, WALL_H * 0.5, left_wall_mid_z), Vector3(WALL_T, WALL_H, left_wall_len), parent)

	# 2. Mid Horizontal Dividing Wall (At z = r_z - 4.0, from x = -2.8 to x = 2.0)
	var mid_div_z := r_z - 4.0
	var door_w := 2.2
	var door_x := 0.0

	# Left segment of mid dividing wall
	var seg_left_start := -2.8
	var seg_left_end := door_x - door_w * 0.5
	var seg_left_w := seg_left_end - seg_left_start
	if seg_left_w > 0.05:
		create_wall_cb.call(Vector3(seg_left_start + seg_left_w * 0.5, WALL_H * 0.5, mid_div_z), Vector3(seg_left_w, WALL_H, WALL_T), parent)

	# Right segment of mid dividing wall
	var seg_right_start := door_x + door_w * 0.5
	var seg_right_end := 2.0
	var seg_right_w := seg_right_end - seg_right_start
	if seg_right_w > 0.05:
		create_wall_cb.call(Vector3(seg_right_start + seg_right_w * 0.5, WALL_H * 0.5, mid_div_z), Vector3(seg_right_w, WALL_H, WALL_T), parent)

	# Central Green Double Doors in the mid dividing wall
	if create_door_cb.is_valid():
		create_door_cb.call(Vector3(door_x, 0.0, mid_div_z), door_w, Color("#27ae60"), false, parent)

	# 3. Top Vertical Partition Wall (At x = 2.0, runs from mid_div_z up to north_z)
	var top_v_len := (mid_div_z) - (north_z)
	var top_v_mid_z := north_z + top_v_len * 0.5
	create_wall_cb.call(Vector3(2.0, WALL_H * 0.5, top_v_mid_z), Vector3(WALL_T, WALL_H, top_v_len), parent)

	# 4. Lower-Right Vertical Stub Wall (At x = 2.0, runs from z = r_z + 0.5 to z = r_z + 6.0)
	create_wall_cb.call(Vector3(2.0, WALL_H * 0.5, r_z + 3.25), Vector3(WALL_T, WALL_H, 5.5), parent)

	return {
		"cabinet_spots": [
			# Yellow/Blue ATM machine against top wall in upper-left chamber
			{ "pos": Vector3(-1.8, 0.0, north_z + 0.7), "rot_y": 180.0, "container": "atm" },
			# Secondary Cupboard in upper-right chamber (away from start spawn!)
			{ "pos": Vector3(half_w - 1.2, 0.0, north_z + 1.5), "rot_y": -90.0, "container": "cupboard" }
		],
		"patrol_routes": [
			# Guard 1: Upper Chamber & Left Alley Circuit (6 waypoints looping around paths!)
			[
				Vector3(-4.8, 0.0, r_z - 7.5),
				Vector3(-1.8, 0.0, r_z - 7.0),
				Vector3(-0.4, 0.0, r_z - 5.2),
				Vector3(-4.8, 0.0, r_z - 5.2),
				Vector3(-4.8, 0.0, r_z - 0.5),
				Vector3(-4.8, 0.0, r_z - 5.2)
			],
			# Guard 2: Lower Concourse Loop (Circling around right stub wall which spans z = r_z + 0.5 to z = r_z + 6.0)
			[
				Vector3(4.5, 0.0, r_z + 7.5),
				Vector3(4.5, 0.0, r_z - 1.0),
				Vector3(0.0, 0.0, r_z - 1.0),
				Vector3(0.0, 0.0, r_z + 7.5)
			]
		],
		"exit_door": { "x": 2.0, "width": 2.2, "z": north_z },
		"floor_pads": [
			Vector3(-4.8, 0.02, r_z) # White circular button in left alley
		]
	}

# 2. Dual-Wing Depot (Wide hall 17m x 19m with central divider and 3 crossover archways)
static func _build_dual_wing_depot(r_center: Vector3, half_w: float, depth: float, parent: Node3D, create_wall_cb: Callable) -> Dictionary:
	var r_z := r_center.z
	var half_d := depth * 0.5
	var north_z := r_z - half_d
	var south_z := r_z + half_d

	# Central dividing wall at x = 0.0 with 3 crossover doorways (North z = r_z - 5.0, Center z = r_z, South z = r_z + 5.0)
	var dw := 2.6
	# Segment 1 (North tip)
	var s1_len := (r_z - 5.0 - dw * 0.5) - north_z
	create_wall_cb.call(Vector3(0.0, WALL_H * 0.5, north_z + s1_len * 0.5), Vector3(WALL_T, WALL_H, s1_len), parent)

	# Segment 2 (Between North and Center archways)
	var s2_start := r_z - 5.0 + dw * 0.5
	var s2_end := r_z - dw * 0.5
	var s2_len := s2_end - s2_start
	create_wall_cb.call(Vector3(0.0, WALL_H * 0.5, s2_start + s2_len * 0.5), Vector3(WALL_T, WALL_H, s2_len), parent)

	# Segment 3 (Between Center and South archways)
	var s3_start := r_z + dw * 0.5
	var s3_end := r_z + 5.0 - dw * 0.5
	var s3_len := s3_end - s3_start
	create_wall_cb.call(Vector3(0.0, WALL_H * 0.5, s3_start + s3_len * 0.5), Vector3(WALL_T, WALL_H, s3_len), parent)

	# Segment 4 (South tip - leaving open concourse across south wall)
	var s4_start := r_z + 5.0 + dw * 0.5
	var s4_end := south_z - 2.8
	var s4_len := s4_end - s4_start
	if s4_len > 0.05:
		create_wall_cb.call(Vector3(0.0, WALL_H * 0.5, s4_start + s4_len * 0.5), Vector3(WALL_T, WALL_H, s4_len), parent)

	# Side partition stubs creating private storage corners
	create_wall_cb.call(Vector3(-half_w + 2.0, WALL_H * 0.5, r_z - 2.5), Vector3(4.0, WALL_H, WALL_T), parent)
	create_wall_cb.call(Vector3(half_w - 2.0, WALL_H * 0.5, r_z + 2.5), Vector3(4.0, WALL_H, WALL_T), parent)

	return {
		"cabinet_spots": [
			{ "pos": Vector3(-half_w + 1.2, 0.0, north_z + 1.2), "rot_y": 90.0, "container": "cupboard" },
			{ "pos": Vector3(half_w - 1.2, 0.0, north_z + 1.2), "rot_y": -90.0, "container": "cupboard" }
		],
		"patrol_routes": [
			# Guard 1: North loop through both wings via North & Center archways
			[
				Vector3(-3.5, 0.0, r_z - 5.0),
				Vector3(3.5, 0.0, r_z - 5.0),
				Vector3(3.5, 0.0, r_z),
				Vector3(-3.5, 0.0, r_z)
			],
			# Guard 2: South loop through both wings via Center & South archways
			[
				Vector3(3.5, 0.0, r_z),
				Vector3(3.5, 0.0, r_z + 5.0),
				Vector3(-3.5, 0.0, r_z + 5.0),
				Vector3(-3.5, 0.0, r_z)
			]
		],
		"exit_door": { "x": 3.5, "width": 2.4, "z": north_z },
		"floor_pads": []
	}

# 3. Serpentine Terminal (Long security hall 14m x 24m with weaving screening partitions)
static func _build_serpentine_terminal(r_center: Vector3, half_w: float, depth: float, parent: Node3D, create_wall_cb: Callable) -> Dictionary:
	var r_z := r_center.z
	var half_d := depth * 0.5
	var north_z := r_z - half_d
	var south_z := r_z + half_d

	# Wall 1 from Left (leaving 3.2m opening on right)
	var w1_len := half_w * 2.0 - 3.2
	create_wall_cb.call(Vector3(-half_w + w1_len * 0.5, WALL_H * 0.5, r_z - 4.5), Vector3(w1_len, WALL_H, WALL_T), parent)

	# Wall 2 from Right (leaving 3.2m opening on left)
	create_wall_cb.call(Vector3(half_w - w1_len * 0.5, WALL_H * 0.5, r_z + 2.5), Vector3(w1_len, WALL_H, WALL_T), parent)

	return {
		"cabinet_spots": [
			{ "pos": Vector3(-half_w + 1.2, 0.0, north_z + 1.2), "rot_y": 90.0, "container": "atm" },
			{ "pos": Vector3(half_w - 1.2, 0.0, r_z - 1.0), "rot_y": -90.0, "container": "cupboard" }
		],
		"patrol_routes": [
			# Guard 1: Sweeps the winding S-curve corridor from North to Mid through right opening
			[
				Vector3(-3.5, 0.0, r_z - 8.0),
				Vector3(5.2, 0.0, r_z - 8.0),
				Vector3(5.2, 0.0, r_z - 1.0),
				Vector3(-3.5, 0.0, r_z - 1.0),
				Vector3(5.2, 0.0, r_z - 1.0),
				Vector3(5.2, 0.0, r_z - 8.0)
			],
			# Guard 2: Sweeps the open South screening hall
			[
				Vector3(-4.5, 0.0, r_z + 5.5),
				Vector3(4.5, 0.0, r_z + 5.5),
				Vector3(4.5, 0.0, r_z + 8.0),
				Vector3(-4.5, 0.0, r_z + 8.0)
			]
		],
		"exit_door": { "x": 0.0, "width": 2.4, "z": north_z },
		"floor_pads": [
			Vector3(-half_w + 1.6, 0.02, r_z - 1.0)
		]
	}

# 4. Ring Vault Gallery (Square hall 18m x 22m with central 6x6 fortified vault and perimeter ring)
static func _build_ring_vault_gallery(r_center: Vector3, half_w: float, depth: float, parent: Node3D, create_wall_cb: Callable, create_door_cb: Callable) -> Dictionary:
	var r_z := r_center.z
	var half_d := depth * 0.5
	var north_z := r_z - half_d
	var south_z := r_z + half_d

	var v_w := 6.0
	var v_d := 6.0
	var v_hw := v_w * 0.5
	var v_hd := v_d * 0.5

	# Central Vault North, West, East walls
	create_wall_cb.call(Vector3(0.0, WALL_H * 0.5, r_z - v_hd), Vector3(v_w, WALL_H, WALL_T), parent)
	create_wall_cb.call(Vector3(-v_hw, WALL_H * 0.5, r_z), Vector3(WALL_T, WALL_H, v_d), parent)
	create_wall_cb.call(Vector3(v_hw, WALL_H * 0.5, r_z), Vector3(WALL_T, WALL_H, v_d), parent)

	# South Vault wall with Green Vault Doorway
	var door_w := 2.2
	var seg_w := (v_w - door_w) * 0.5
	create_wall_cb.call(Vector3(-v_hw + seg_w * 0.5, WALL_H * 0.5, r_z + v_hd), Vector3(seg_w, WALL_H, WALL_T), parent)
	create_wall_cb.call(Vector3(v_hw - seg_w * 0.5, WALL_H * 0.5, r_z + v_hd), Vector3(seg_w, WALL_H, WALL_T), parent)
	if create_door_cb.is_valid():
		create_door_cb.call(Vector3(0.0, 0.0, r_z + v_hd), door_w, Color("#27ae60"), false, parent)

	return {
		"cabinet_spots": [
			{ "pos": Vector3(0.0, 0.0, r_z - 1.8), "rot_y": 180.0, "container": "cupboard" }, # Inside central vault!
			{ "pos": Vector3(-half_w + 1.2, 0.0, r_z), "rot_y": 90.0, "container": "atm" },
			{ "pos": Vector3(half_w - 1.2, 0.0, r_z), "rot_y": -90.0, "container": "cupboard" }
		],
		"patrol_routes": [
			# Guard 1: Full clockwise perimeter loop around the central vault!
			[
				Vector3(-5.5, 0.0, r_z - 5.5),
				Vector3(5.5, 0.0, r_z - 5.5),
				Vector3(5.5, 0.0, r_z + 5.5),
				Vector3(-5.5, 0.0, r_z + 5.5)
			],
			# Guard 2: Sweeps the North Transit Gallery
			[
				Vector3(5.5, 0.0, north_z + 2.0),
				Vector3(-5.5, 0.0, north_z + 2.0)
			]
		],
		"exit_door": { "x": 0.0, "width": 2.4, "z": north_z },
		"floor_pads": []
	}

# Clean Hall Environment: No clutter props per user request ("only cabinet require with item to find else remove all things")
static func _build_turnstile_post(_pos: Vector3, _parent: Node3D) -> void:
	pass

static func _build_yellow_barrier(_pos: Vector3, _parent: Node3D) -> void:
	pass
