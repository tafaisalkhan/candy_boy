extends RefCounted
class_name HomeFurniture

const FURNITURE_DIR := "res://assets/models/furniture/"

static var _cached_scenes: Dictionary = {}

static func get_furniture_scene(item_name: String) -> PackedScene:
	if _cached_scenes.has(item_name):
		return _cached_scenes[item_name]
	var path := FURNITURE_DIR + item_name + ".glb"
	if ResourceLoader.exists(path):
		var scn := load(path) as PackedScene
		_cached_scenes[item_name] = scn
		return scn
	return null

static func spawn_item(item_name: String, pos: Vector3, rot_y_deg: float = 0.0, scale_f: float = 1.8) -> Node3D:
	var scn := get_furniture_scene(item_name)
	if not scn:
		return null
	var inst := scn.instantiate() as Node3D
	inst.name = item_name
	inst.position = pos
	inst.rotation_degrees.y = rot_y_deg
	inst.scale = Vector3.ONE * scale_f

	# Eliminate all plain white / pale materials and inject rich vibrant cartoon colors & textures!
	_colorize_furniture(inst, item_name)
	return inst

static func _colorize_furniture(inst: Node3D, item_name: String) -> void:
	for found in inst.find_children("*", "MeshInstance3D", true, false):
		var mi := found as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var orig = mi.get_active_material(s)
			if orig == null:
				orig = mi.mesh.surface_get_material(s)
			var mat := StandardMaterial3D.new()
			var mname: String = (orig as Resource).resource_name if (orig is Resource) else ""
			var mi_name: String = mi.name.to_lower()

			# Dedicated vibrant styling per item and material name
			if item_name == "kitchenFridgeLarge":
				if mname == "metalMedium" or mi_name.contains("handle"):
					mat.albedo_color = Color("#2d3436") # Sleek charcoal metallic handles
					mat.metallic = 0.7
					mat.roughness = 0.25
				else:
					mat.albedo_color = Color("#00cec9") # Retro mint cyan SMEG fridge
					mat.metallic = 0.2
					mat.roughness = 0.25
			elif item_name == "kitchenStove":
				if mname == "wood" or mname == "metalDark" or mi_name == "kitchenstove(clone)":
					mat.albedo_color = Color("#2c3e50") # Deep midnight navy stove body
					mat.metallic = 0.35
					mat.roughness = 0.3
				elif mname == "carpetWhite":
					mat.albedo_color = Color("#1e272e") # Dark cast iron burner plates
					mat.metallic = 0.5
					mat.roughness = 0.5
				elif mname == "glass":
					mat.albedo_color = Color(0.1, 0.15, 0.2, 0.7)
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					mat.roughness = 0.1
				else:
					mat.albedo_color = Color("#f39c12") # Golden knobs/metal
					mat.metallic = 0.75
					mat.roughness = 0.2
			elif item_name == "kitchenSink":
				if mname == "wood" or mi_name == "kitchensink(clone)":
					mat.albedo_color = Color("#2980b9") # Rich cobalt kitchen cabinetry
					mat.roughness = 0.4
				elif mname == "metal" or mname == "metalLight":
					mat.albedo_color = Color("#bdc3c7") # Polished chrome faucet & sink basin
					mat.metallic = 0.85
					mat.roughness = 0.15
				elif mname == "metalDark" or mname == "_defaultMat":
					mat.albedo_color = Color("#2c3e50") # Slate countertop
					mat.roughness = 0.35
				else:
					mat.albedo_color = Color("#8e44ad") # Cozy royal accent
			elif item_name == "bedDouble" or item_name == "bedSingle":
				if mi_name.contains("pillow"):
					mat.albedo_color = Color("#00cec9") # Vibrant turquoise designer pillows
					mat.roughness = 0.5
				elif mi_name == "cover":
					if s == 0:
						mat.albedo_color = Color("#e84393") # Rich magenta-rose duvet quilt
						mat.roughness = 0.55
					else:
						mat.albedo_color = Color("#f1c40f") # Vivid sunflower gold quilt border
						mat.roughness = 0.5
				elif mname == "carpetWhite":
					mat.albedo_color = Color("#e67e22") # Warm coral/amber fitted sheet
					mat.roughness = 0.6
				elif mname == "wood":
					mat.albedo_color = Color("#8b4513") # Rich warm teak headboard & frame
					mat.roughness = 0.45
				else:
					mat.albedo_color = Color("#d4ac0d") # Brass frame accents
					mat.metallic = 0.7
			elif item_name == "bear":
				if mname == "fur":
					mat.albedo_color = Color("#a0522d") # Warm cuddly honey-brown teddy fur
					mat.roughness = 0.8
				elif mname == "wood":
					mat.albedo_color = Color("#d35400") # Caramel snout and ears
					mat.roughness = 0.7
				else:
					mat.albedo_color = Color("#1e272e") # Glossy black button eyes & nose
					mat.roughness = 0.2
			elif item_name == "cabinetBedDrawerTable":
				if mname == "wood":
					mat.albedo_color = Color("#935116") # Warm cedar bedside table
					mat.roughness = 0.45
				elif mname == "metal":
					mat.albedo_color = Color("#f1c40f") # Golden brass drawer handle
					mat.metallic = 0.8
					mat.roughness = 0.25
				else:
					mat.albedo_color = Color("#b9770e") # Warm amber top
					mat.roughness = 0.4
			elif item_name.begins_with("lamp"):
				if mname == "lamp":
					mat.albedo_color = Color("#f39c12") # Warm glowing amber lampshade
					mat.emission_enabled = true
					mat.emission = Color("#e67e22")
					mat.emission_energy_multiplier = 0.8
					mat.roughness = 0.3
				else:
					mat.albedo_color = Color("#d4ac0d") # Polished brass stem & base
					mat.metallic = 0.75
					mat.roughness = 0.2
			elif item_name == "desk" or item_name == "deskCorner":
				if mname == "wood":
					mat.albedo_color = Color("#873600") # Warm mahogany study desk
					mat.roughness = 0.45
				elif mname == "metal":
					mat.albedo_color = Color("#f1c40f") # Golden brass drawer pull
					mat.metallic = 0.8
				else:
					mat.albedo_color = Color("#a0522d")
			elif item_name == "chairDesk":
				if mname == "carpet" or mi_name == "chair":
					mat.albedo_color = Color("#d35400") # Rich pumpkin leather seat & back
					mat.roughness = 0.4
				else:
					mat.albedo_color = Color("#2c3e50") # Midnight dark metal legs
					mat.metallic = 0.65
					mat.roughness = 0.35
			elif item_name == "bookcaseOpen" or item_name.begins_with("bookcase"):
				mat.albedo_color = Color("#783f04") # Rich dark cedar bookcase
				mat.roughness = 0.5
			elif item_name == "cabinetTelevisionDoors":
				if mname == "metal":
					mat.albedo_color = Color("#f1c40f") # Golden door handles
					mat.metallic = 0.8
				else:
					mat.albedo_color = Color("#5c3817") # Deep royal walnut TV cabinet
					mat.roughness = 0.45
			elif item_name == "televisionModern":
				if mname == "metal":
					mat.albedo_color = Color("#0f172a") # Dark glass flatscreen display
					mat.metallic = 0.3
					mat.roughness = 0.1
				else:
					mat.albedo_color = Color("#1e272e") # Sleek obsidian frame & stand
					mat.roughness = 0.25
			elif item_name == "loungeSofa" or item_name == "loungeChair":
				if mname == "wood":
					mat.albedo_color = Color("#422517") # Espresso dark timber legs
					mat.roughness = 0.5
				else:
					mat.albedo_color = Color("#00a884") # Vibrant plush emerald/teal sofa
					mat.roughness = 0.6
			elif item_name == "tableCoffee":
				mat.albedo_color = Color("#b9770e") # Warm golden honey oak coffee table
				mat.roughness = 0.4
			elif item_name == "pottedPlant" or item_name.begins_with("plantSmall"):
				if mname == "plant" or mi_name.contains("plant"):
					mat.albedo_color = Color("#27ae60") # Lush emerald green leaves
					mat.roughness = 0.4
				elif mname == "woodDark":
					mat.albedo_color = Color("#3e2723") # Dark potting soil
					mat.roughness = 0.9
				else:
					mat.albedo_color = Color("#d35400") # Terracotta ceramic pot
					mat.roughness = 0.6
			elif item_name == "coatRackStanding":
				if mname == "metal" or mname == "metalDark":
					mat.albedo_color = Color("#f1c40f") # Golden brass coat hooks
					mat.metallic = 0.8
				else:
					mat.albedo_color = Color("#873600") # Warm mahogany standing rack
					mat.roughness = 0.45
			elif item_name == "kitchenCoffeeMachine":
				if mname == "metal" or mname == "metalLight":
					mat.albedo_color = Color("#bdc3c7")
					mat.metallic = 0.85
				elif mname == "glass":
					mat.albedo_color = Color(0.2, 0.15, 0.1, 0.7)
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				else:
					mat.albedo_color = Color("#c0392b") # Cherry red espresso maker
					mat.roughness = 0.3
			elif item_name == "kitchenMicrowave":
				if mname == "metalDark" or mi_name.contains("door"):
					mat.albedo_color = Color("#1e272e") # Dark glass door & panel
					mat.roughness = 0.2
				else:
					mat.albedo_color = Color("#2c3e50") # Slate metallic body
					mat.metallic = 0.5
			elif item_name.begins_with("rug"):
				mat.albedo_color = Color("#c0392b") # Cozy Persian ruby woven rug
				mat.roughness = 0.85
			elif item_name == "stoolBar" or item_name == "chairCushion":
				if mname == "wood":
					mat.albedo_color = Color("#b9770e") # Warm honey oak seat
					mat.roughness = 0.4
				elif mname == "carpet" or mname == "carpetWhite":
					mat.albedo_color = Color("#d35400") # Warm cushion
				else:
					mat.albedo_color = Color("#2c3e50") # Dark metal legs
					mat.metallic = 0.7
			elif item_name.begins_with("cardboardBox"):
				if mname == "wood" or mname.contains("tape") or mi_name.contains("tape"):
					mat.albedo_color = Color("#78350f") # Dark packing tape
				else:
					mat.albedo_color = Color("#d2996e") # Warm kraft cardboard
				mat.roughness = 0.85
			else:
				# General fallback for any other furniture item - eliminate pale/white
				if mname == "wood":
					mat.albedo_color = Color("#a0522d")
				elif mname == "metal" or mname == "metalLight":
					mat.albedo_color = Color("#d4ac0d")
					mat.metallic = 0.7
				elif mname == "carpet" or mname == "carpetWhite":
					mat.albedo_color = Color("#e67e22")
				else:
					mat.albedo_color = Color("#e67e22")

			mi.set_surface_override_material(s, mat)

static func add_item_with_collision(parent: Node3D, item_name: String, pos: Vector3, rot_y_deg: float, scale_f: float, coll_size: Vector3, coll_offset: Vector3, colliders: Array[AABB]) -> Node3D:
	var inst := spawn_item(item_name, pos, rot_y_deg, scale_f)
	if inst:
		parent.add_child(inst)
		var aabb := AABB(pos + coll_offset - coll_size * 0.5, coll_size)
		colliders.append(aabb)
	return inst

static func decorate_bedroom(parent: Node3D, room_center: Vector3, half_w: float, room_depth: float, colliders: Array[AABB]) -> void:
	# 1. Double Bed with Plush Headboard on East Wall
	add_item_with_collision(
		parent, "bedDouble",
		Vector3(half_w - 2.0, 0.0, room_center.z + 1.2),
		180.0, 1.8,
		Vector3(2.1, 1.1, 2.3), Vector3(0.0, 0.55, 0.0),
		colliders
	)

	# 2. Cute Teddy Bear sitting on the bed
	var bear := spawn_item("bear", Vector3(half_w - 2.0, 0.85, room_center.z + 0.9), 180.0, 1.3)
	if bear:
		parent.add_child(bear)

	# 3. Bedside Nightstand beside bed
	add_item_with_collision(
		parent, "cabinetBedDrawerTable",
		Vector3(half_w - 1.0, 0.0, room_center.z - 1.5),
		-90.0, 1.85,
		Vector3(0.9, 0.9, 1.1), Vector3(0.0, 0.45, 0.0),
		colliders
	)

	# Bedside Lamp
	var lamp := spawn_item("lampRoundTable", Vector3(half_w - 1.0, 0.72, room_center.z - 1.5), 0.0, 1.5)
	if lamp:
		parent.add_child(lamp)

static func decorate_kitchen_living(parent: Node3D, room_center: Vector3, half_w: float, room_depth: float, colliders: Array[AABB]) -> void:
	# 1. Kitchen Refrigerator (Fridge) on North-West corner
	add_item_with_collision(
		parent, "kitchenFridgeLarge",
		Vector3(-half_w + 1.5, 0.0, room_center.z - 2.8),
		0.0, 1.8,
		Vector3(1.4, 2.1, 1.1), Vector3(0.0, 1.05, 0.0),
		colliders
	)
