class_name LevelGenerator
extends RefCounted

static var cabinet_models: Array[String] = [
	"bookcaseClosedDoors",
	"bookcaseClosedWide",
	"cabinetTelevisionDoors",
	"kitchenCabinet",
	"kitchenCabinetDrawer"
]

static var cabinet_colors: Array[String] = [
	"#1e3799", # Royal Sapphire Blue
	"#b71540", # Imperial Ruby Red
	"#10ac84", # Emerald Jade Green
	"#d35400", # Warm Mahogany Amber
	"#6c5ce7", # Amethyst Purple
	"#8e44ad", # Deep Plum Violet
	"#0097e6", # Cerulean Teal
	"#e17055"  # Terracotta Coral
]

# 9 Different Elements / Toys to find across levels
static var toy_types: Array[Dictionary] = [
	{ "type": "candy",  "name": "Secret Candy",      "icon": "🍬", "color": "#f1c40f" },
	{ "type": "ball",   "name": "Championship Ball", "icon": "⚽", "color": "#ffffff" },
	{ "type": "bat",    "name": "Power Bat",         "icon": "🏏", "color": "#e67e22" },
	{ "type": "game",   "name": "Golden Arcade",     "icon": "🎮", "color": "#9b59b6" },
	{ "type": "bear",   "name": "Vintage Teddy",     "icon": "🧸", "color": "#e74c3c" },
	{ "type": "trophy", "name": "Golden Trophy",     "icon": "🏆", "color": "#f1c40f" },
	{ "type": "gem",    "name": "Diamond Gem",       "icon": "💎", "color": "#00cec9" },
	{ "type": "robot",  "name": "Toy Robot",         "icon": "🤖", "color": "#0984e3" },
	{ "type": "dice",   "name": "Lucky Dice",        "icon": "🎲", "color": "#ffffff" }
]

static var guard_tints: Array[String] = [
	"#1e3799", # Cobalt Navy
	"#d63031", # Crimson Red
	"#009432", # Forest Emerald
	"#6c5ce7", # Royal Violet
	"#e67e22"  # Amber Orange
]

# Multi-Directional Unlimited Level Generator:
# - Initial stage (Levels 1-3): 1 room (Center Concourse)
# - Adds rooms to the LEFT side, RIGHT side, and ABOVE as levels increase!
# - Different toy elements to find in large custom-colored cabinets
# - Zero security cameras anywhere
# - 1 Patrolling Granny per room with full anti-stuck navigation
static func generate_level(lvl: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = lvl * 7919

	var house_w: float = 14.0
	var room_depth: float = 16.0
	var half_w := house_w * 0.5
	var half_d := room_depth * 0.5

	# Determine layout type based on level
	# 1 room (lvl 1-3)
	# 2 rooms (lvl 4-5): above or left
	# 3 rooms (lvl 6-9): Center + Left Wing + Right Wing!
	# 4 rooms (lvl 10-15): Center + Left Wing + Right Wing + Above (Grand Cross Estate!)
	# 5-6 rooms (lvl 16+): Full 2x3 Multi-Wing Mansion!
	var num_rooms: int = 1
	if lvl <= 3:
		num_rooms = 1
	elif lvl <= 5:
		num_rooms = 2
	elif lvl <= 9:
		num_rooms = 3
	elif lvl <= 15:
		num_rooms = 4
	elif lvl <= 22:
		num_rooms = 5
	else:
		num_rooms = 6

	# Number of items to find
	var target_count: int = 1
	if lvl <= 2:
		target_count = 1
	elif lvl <= 5:
		target_count = 2
	elif lvl <= 11:
		target_count = 3
	else:
		target_count = 4

	var data := {
		"level": lvl,
		"name": "Level %d: %d-Room Multi-Wing Estate" % [lvl, num_rooms],
		"num_rooms": num_rooms,
		"room_depth": room_depth,
		"house_width": house_w,
		"theme": "outdoor",
		"visible_rooms": num_rooms,
		"coins": 50 + lvl * 10,
		"camera": {
			"position": [0.0, 31.0, 6.0],
			"rotation_degrees": [-70.0, 0.0, 0.0],
			"fov": 50.0,
			"follow_z_offset": 4.5
		},
		"characters": {
			"player": {
				"type": "boy",
				"pos": [0.0, 0.0, half_d - 2.5],
				"scale": 0.55,
				"speed": 6.2
			}
		},
		"rooms": []
	}

	# Room Definitions with 2D positions:
	# Room 0: Center Concourse at [0, 0, 0]
	# Room 1: Left Wing at [-house_w, 0, 0]
	# Room 2: Right Wing at [+house_w, 0, 0]
	# Room 3: Above Room at [0, 0, -room_depth]
	# Room 4: Top-Left Room at [-house_w, 0, -room_depth]
	# Room 5: Top-Right Room at [+house_w, 0, -room_depth]
	var room_specs: Array[Dictionary] = []

	if num_rooms == 1:
		room_specs.append({
			"name": "Central_Grand_Hall",
			"center": [0.0, 0.0, 0.0],
			"doors": []
		})
	elif num_rooms == 2:
		if lvl % 2 == 0:
			# Above Room
			room_specs.append({
				"name": "Central_Concourse",
				"center": [0.0, 0.0, 0.0],
				"doors": [{ "wall": "north", "x": 0.0, "width": 2.8, "color": "#27ae60" }]
			})
			room_specs.append({
				"name": "North_Vault",
				"center": [0.0, 0.0, -room_depth],
				"open_south": true,
				"doors": []
			})
		else:
			# Left Room
			room_specs.append({
				"name": "Central_Concourse",
				"center": [0.0, 0.0, 0.0],
				"doors": [{ "wall": "west", "z": 0.0, "width": 2.8, "color": "#27ae60" }]
			})
			room_specs.append({
				"name": "West_Wing",
				"center": [-house_w, 0.0, 0.0],
				"open_east": true,
				"doors": []
			})
	elif num_rooms == 3:
		# Left Wing + Center Concourse + Right Wing!
		room_specs.append({
			"name": "Central_Concourse",
			"center": [0.0, 0.0, 0.0],
			"doors": [
				{ "wall": "west", "z": 0.0, "width": 2.8, "color": "#27ae60" },
				{ "wall": "east", "z": 0.0, "width": 2.8, "color": "#27ae60" }
			]
		})
		room_specs.append({
			"name": "West_Wing_Left",
			"center": [-house_w, 0.0, 0.0],
			"open_east": true,
			"doors": []
		})
		room_specs.append({
			"name": "East_Wing_Right",
			"center": [house_w, 0.0, 0.0],
			"open_west": true,
			"doors": []
		})
	elif num_rooms >= 4:
		# The Grand Cross Estate: Center + Left + Right + Above!
		room_specs.append({
			"name": "Central_Concourse",
			"center": [0.0, 0.0, 0.0],
			"doors": [
				{ "wall": "west", "z": 0.0, "width": 2.8, "color": "#27ae60" },
				{ "wall": "east", "z": 0.0, "width": 2.8, "color": "#27ae60" },
				{ "wall": "north", "x": 0.0, "width": 2.8, "color": "#27ae60" }
			]
		})
		room_specs.append({
			"name": "West_Wing_Left",
			"center": [-house_w, 0.0, 0.0],
			"open_east": true,
			"doors": []
		})
		room_specs.append({
			"name": "East_Wing_Right",
			"center": [house_w, 0.0, 0.0],
			"open_west": true,
			"doors": []
		})
		room_specs.append({
			"name": "North_Vault_Above",
			"center": [0.0, 0.0, -room_depth],
			"open_south": true,
			"doors": []
		})
		if num_rooms >= 5:
			# Top-Left Room
			room_specs[1]["doors"].append({ "wall": "north", "x": -house_w, "width": 2.8, "color": "#27ae60" })
			room_specs.append({
				"name": "North_West_Chamber",
				"center": [-house_w, 0.0, -room_depth],
				"open_south": true,
				"doors": []
			})
		if num_rooms >= 6:
			# Top-Right Room
			room_specs[2]["doors"].append({ "wall": "north", "x": house_w, "width": 2.8, "color": "#27ae60" })
			room_specs.append({
				"name": "North_East_Chamber",
				"center": [house_w, 0.0, -room_depth],
				"open_south": true,
				"doors": []
			})

	var items_allocated: int = 0

	for r_idx in range(num_rooms):
		var spec: Dictionary = room_specs[r_idx]
		var r_dict := {
			"index": r_idx,
			"name": spec["name"],
			"center": spec["center"],
			"width": house_w,
			"depth": room_depth,
			"doors": spec.get("doors", []),
			"open_north": spec.get("open_north", false),
			"open_south": spec.get("open_south", false),
			"open_west": spec.get("open_west", false),
			"open_east": spec.get("open_east", false),
			"compartments": [],
			"items": [],
			"guards": [],
			"cameras": [] # ZERO security cameras across all levels!
		}

		# Compartments per room (wide central avenue)
		var wall_offset_x := half_w * 0.52
		var comp_len := room_depth * 0.40
		r_dict["compartments"].append({
			"pos": [-wall_offset_x, 0.0, 0.0],
			"size": [0.35, 2.6, comp_len]
		})
		r_dict["compartments"].append({
			"pos": [wall_offset_x, 0.0, 0.0],
			"size": [0.35, 2.6, comp_len]
		})

		# If outer vault room, add privacy wall
		if r_idx > 0 and num_rooms > 2:
			r_dict["compartments"].append({
				"pos": [0.0, 0.0, -half_d * 0.35],
				"size": [3.6, 2.6, 0.35]
			})

		# Cabinets with different toy elements:
		# If single room: placed at far north wall
		# If multi-room: distributed across outer rooms (Left, Right, Above - never in start Room 0)
		var can_spawn_items_here := (num_rooms == 1) or (r_idx > 0)
		if can_spawn_items_here and items_allocated < target_count:
			var items_in_this_room := 1
			if num_rooms == 1:
				items_in_this_room = target_count
			elif r_idx == num_rooms - 1:
				items_in_this_room = target_count - items_allocated
			else:
				items_in_this_room = mini(1, target_count - items_allocated)

			for it_i in range(items_in_this_room):
				var toy_info: Dictionary = toy_types[(lvl + items_allocated) % toy_types.size()]
				var cab_x: float = -half_w + 1.8
				var cab_z: float = -half_d + 1.8
				var cab_rot: float = 90.0
				match it_i % 4:
					0:
						cab_x = -half_w + 1.8
						cab_z = -half_d + 1.8
						cab_rot = 90.0
					1:
						cab_x = half_w - 1.8
						cab_z = -half_d + 1.8
						cab_rot = -90.0
					2:
						cab_x = -half_w + 1.8
						cab_z = 1.0
						cab_rot = 90.0
					3:
						cab_x = half_w - 1.8
						cab_z = 1.0
						cab_rot = -90.0

				var model_name: String = cabinet_models[(items_allocated + lvl) % cabinet_models.size()]
				var col_str: String = cabinet_colors[(items_allocated + lvl * 2) % cabinet_colors.size()]
				var req_key: bool = (lvl >= 3 and items_allocated == 0)

				r_dict["items"].append({
					"id": "%s_%d" % [toy_info["type"], items_allocated],
					"type": toy_info["type"],
					"name": toy_info["name"],
					"icon": toy_info["icon"],
					"pos": [cab_x, 0.0, cab_z],
					"rot_y": cab_rot,
					"container": "cupboard",
					"container_model": model_name,
					"container_scale": 2.6, # Larger prominent size!
					"container_color": col_str, # Rich distinct color!
					"requires_key": req_key,
					"collectible": true,
					"is_target": true,
					"color": toy_info["color"],
					"reward": 50 + lvl * 5
				})
				items_allocated += 1

		# Spawn a golden Key in Room 0 for Level 3+ so player collects the key to unlock the locked cabinet!
		if r_idx == 0 and lvl >= 3:
			r_dict["items"].append({
				"id": "key",
				"type": "key",
				"pos": [0.0, 0.0, -3.2],
				"collectible": true
			})

		# 1 Patrolling Granny per room!
		var g_speed: float = clampf(2.7 + float(lvl) * 0.02 + float(r_idx) * 0.05, 2.7, 3.4)
		var g_tint: String = guard_tints[(lvl + r_idx) % guard_tints.size()]
		var patrol_w := half_w * 0.65
		var patrol_d := half_d * 0.55
		var wp_z_center := (patrol_d * 0.35) if (r_idx == 0 and num_rooms > 1) else 0.0

		r_dict["guards"].append({
			"type": "granny",
			"tint": g_tint,
			"speed": g_speed,
			"vision_range": 3.4,
			"vision_angle": 30.0,
			"waypoints": [
				[-patrol_w, 0.0, wp_z_center - patrol_d * 0.5],
				[patrol_w, 0.0, wp_z_center - patrol_d * 0.5],
				[patrol_w, 0.0, wp_z_center + patrol_d * 0.5],
				[-patrol_w, 0.0, wp_z_center + patrol_d * 0.5]
			]
		})

		# Security Camera mounted on the wall in each room!
		var cam_side_x: float = (-half_w + 0.35) if (r_idx % 2 == 0) else (half_w - 0.35)
		var cam_dir_x: float = 1.0 if (r_idx % 2 == 0) else -1.0
		r_dict["cameras"].append({
			"pos": [cam_side_x, 2.35, -2.2],
			"inward_dir": [cam_dir_x, 0.0, 0.0],
			"vision_range": 4.8,
			"vision_angle": 26.0
		})

		data["rooms"].append(r_dict)

	return data
