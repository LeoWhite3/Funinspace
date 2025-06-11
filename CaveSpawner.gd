extends Node3D

@export var cave_scene: PackedScene
@export var voxel_terrain: VoxelTerrain
@export_range(1, 2) var caves := 1  # Just one cave for testing
@export_range(1, 4) var cave_count := 4  # Just one cave for testing
@export_range(10.0, 50.0) var spawn_radius := 25.0  # Much closer to origin
@export_range(-30.0, -200.0) var cave_depth := -20.0  # Shallower caves
@export_range(20.0, 200.0) var max_cave_radius := 100.0

# Enhanced ore spawning system
@export_group("Ore Spawning")
@export_range(8, 25) var base_ores_per_chamber := 30
@export_range(3, 15) var base_ores_per_tunnel := 15
@export_range(0.5, 2.0) var depth_ore_multiplier := 1.5  # More ores deeper
@export_range(0.1, 0.8) var ore_density_variance := 0.5  # Random variation
@export_range(0.5, 3.0) var ore_cluster_chance := 0.85  # Chance for ore veins
@export_range(0.0, 2.0) var ore_inset_distance := 0.01

@export_range(10.0, 300.0) var glorp_respawn_interval := 90.0  # seconds between spawns
var cave_glorps := {}  # key: cave_id (int), value: Array of Glorp nodes
@export_range(1, 50) var max_glorps_per_cave := 5


var raycast_origins: Array = []
@onready var loading_screen = get_node("/root/World/Ui/LoadingScreen")
@onready var player = get_node("/root/World/player")
@onready var player_data = get_parent().get_node("PlayerData")
@onready var upgrade_manager = get_node("/root/World/UpgradeManager")

# Advanced ore types with better balancing
var ore_types = [

	{ "name": "Iron",    "chance": 0.45,  "min_depth": -60,  "max_depth": -15,  "price": 12,  "weight": 2.0, "vein_size": 4, "color": Color(0.45, 0.45, 0.45), "sparkle": 0.05 },
	{ "name": "Copper",  "chance": 0.35,  "min_depth": -80,  "max_depth": -20,  "price": 18,  "weight": 1.5, "vein_size": 3, "color": Color(0.85, 0.45, 0.25), "sparkle": 0.1 },
	{ "name": "Silver",  "chance": 0.18,  "min_depth": -120, "max_depth": -40,  "price": 35,  "weight": 1.2, "vein_size": 3, "color": Color(0.9, 0.9, 1.0), "sparkle": 0.3 },
	{ "name": "Gold",    "chance": 0.12,  "min_depth": -150, "max_depth": -60,  "price": 65,  "weight": 1.0, "vein_size": 2, "color": Color(1.0, 0.85, 0.0), "sparkle": 0.5 },
	{ "name": "Diamond", "chance": 0.03,  "min_depth": -200, "max_depth": -100, "price": 180, "weight": 0.7, "vein_size": 1, "color": Color(0.6, 0.9, 1.0), "sparkle": 0.9 },
	]


# Cave quality and loot scaling
var cave_quality_levels = [
	{"name": "Poor", "ore_multiplier": 0.7, "rare_chance": 0.5},
	{"name": "Common", "ore_multiplier": 1.0, "rare_chance": 1.0},
	{"name": "Rich", "ore_multiplier": 1.4, "rare_chance": 1.5},
	{"name": "Abundant", "ore_multiplier": 1.8, "rare_chance": 2.0},
	{"name": "Legendary", "ore_multiplier": 2.5, "rare_chance": 3.0}
]

# Store cave position for debugging
var cave_position: Vector3

func _ready():
	loading_screen.visible = true
	player.input_enabled = false
	voxel_terrain = get_node_or_null("/root/World/ground")
	if not voxel_terrain:
		push_error("❌ VoxelTerrain node named 'ground' not found.")
		return

	var save_exists := FileAccess.file_exists("res://SavedGame/terrain_save.db")
	print("🗂️ Save exists:", save_exists)
	
	if save_exists:
		# ✅ Load existing saved terrain
		print("📂 Terrain save found. Loading terrain...")
		var stream := VoxelStreamSQLite.new()
		stream.database_path = "res://SavedGame/terrain_save.db"
		voxel_terrain.stream = stream

		await wait_for_terrain_ready()
		print("✅ Terrain loaded.")
		voxel_terrain.save_modified_blocks()
		var save_path := "res://SavedGame/savegame.json"
		if FileAccess.file_exists(save_path):
			var save_file = FileAccess.open(save_path, FileAccess.READ)
			var json_text = save_file.get_as_text()
			save_file.close()

			var parsed = JSON.parse_string(json_text)
			if typeof(parsed) == TYPE_DICTIONARY:
				load_saved_ores(parsed)
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		
	else:
		var stream := VoxelStreamSQLite.new()
		stream.database_path = "res://SavedGame/terrain_save.db"
		voxel_terrain.stream = stream
		# 🛠️ Generate and then save terrain
		print("🌄 No terrain save found. Generating caves...")
		await generate_and_carve_caves()
		SaveManager.save_game(player_data, upgrade_manager,voxel_terrain)
	
	
		

	

	# ✅ Enable player and remove loading screen
	print("closing load")
	loading_screen.visible = false
	player.input_enabled = true


func load_saved_ores(data: Dictionary):
	if not data.has("world") or not data["world"].has("ores"):
		print("🔍 No saved ores to load.")
		return

	var ore_scene = preload("res://Ore.tscn")

	for entry in data["world"]["ores"]:
		var ore_type = entry.get("ore_type", "")
		var pos_string = str(entry.get("position", ""))
		
		# Parse string like "(x, y, z)" into Vector3
		pos_string = pos_string.strip_edges()
		if pos_string.begins_with("(") and pos_string.ends_with(")"):
			pos_string = pos_string.substr(1, pos_string.length() - 2)
		var clean = pos_string.split(",")

		if clean.size() != 3:
			print("⚠️ Skipping invalid ore position:", pos_string)
			continue

		var pos = Vector3(clean[0].to_float(), clean[1].to_float(), clean[2].to_float())
		
		var ore = ore_scene.instantiate()
		ore.global_position = pos
		ore.set_ore_type(get_ore_type_by_name(ore_type))
		get_tree().current_scene.add_child(ore)

	print("✅ Loaded", data["world"]["ores"].size(), "ores from save.")

func get_ore_type_by_name(name: String) -> Dictionary:
	for ore in ore_types:
		if ore["name"] == name:
			return ore
	return {}


func generate_and_carve_caves():
	var all_carve_points: Array = []
	var all_qualities: Array = []
	var avg_depth := 0.0

	for i in cave_count:
		print("🗻 Generating cave", i + 1, "of", cave_count)
		var cave_data = await generate_enhanced_cave(i)

		all_carve_points += cave_data["carve_points"]
		all_qualities.append(cave_data["quality"])
		avg_depth += cave_data["depth"]

		var cave_chambers = cave_data["carve_points"].filter(
			func(p): return p.get("type", "") == "chamber"
		)
		var cave_data_dict = { "chambers": cave_chambers }

		spawn_enhanced_enemies(cave_data_dict, cave_data["quality"], cave_data["depth"])
		start_glorp_respawn_loop(cave_data_dict, cave_data["quality"], cave_data["depth"], i)

		await get_tree().create_timer(0.5).timeout

	print("🕒 Waiting for collider mesh to update...")
	await wait_for_collider_mesh_to_update()

	var avg_quality = merge_cave_qualities(all_qualities)
	avg_depth /= float(cave_count)

	await spawn_enhanced_ore_system(all_carve_points, null, avg_quality, avg_depth)

	print("✅ Done! All caves, enemies, and ores generated.")

func start_glorp_respawn_loop(cave_data: Dictionary, quality: Dictionary, depth: float, cave_id: int = 0):
	var interval = glorp_respawn_interval + cave_id * 10.0
	call_deferred("_glorp_respawn_loop", cave_data, quality, depth, interval, cave_id)

func _glorp_respawn_loop(cave_data: Dictionary, quality: Dictionary, depth: float, interval: float, cave_id: int):
	while true:
		await get_tree().create_timer(interval).timeout
		spawn_enhanced_enemies(cave_data, quality, depth, cave_id)

func collect_raycast_origins(points: Array):
	for point in points:
		if point.has("pos") and point.has("radius"):
			# Store raycast origin at edge of cave point sphere
			var pos = point["pos"]
			var radius = point["radius"]
			var directions = get_radial_directions(6)
			for dir in directions:
				var ray_origin = pos + dir * radius * 0.9  # slightly inside wall
				raycast_origins.append(ray_origin)

func merge_cave_qualities(qualities: Array) -> Dictionary:
	if qualities.is_empty():
		return cave_quality_levels[1]  # fallback to "Common"

	var total_ore := 0.0
	var total_rare := 0.0
	for q in qualities:
		total_ore += q["ore_multiplier"]
		total_rare += q["rare_chance"]

	var avg_ore = total_ore / qualities.size()
	var avg_rare = total_rare / qualities.size()

	# Return a merged "virtual" quality object
	return {
		"name": "Merged",
		"ore_multiplier": avg_ore,
		"rare_chance": avg_rare
	}

# Wait for terrain to be properly generated
func wait_for_terrain_ready():
	# Wait initial time for terrain generation
	await get_tree().create_timer(2.0).timeout
	
	# Check if terrain is generating
	var max_wait_time = 10.0
	var wait_time = 0.0
	var check_interval = 0.5
	
	while wait_time < max_wait_time:
		# Try to get a voxel tool
		var tool = voxel_terrain.get_voxel_tool()
		if tool:
			# Test if we can actually carve by doing a small test sphere
			var test_pos = Vector3(0, -5, 0)
			tool.mode = VoxelTool.MODE_REMOVE
			tool.do_sphere(test_pos, 1.0)
			
			# Wait for the carve to process
			await get_tree().create_timer(0.5).timeout
			
			print("✅ Voxel terrain is ready for carving!")
			return
		
		print("⏳ Still waiting for terrain... (", wait_time, "s)")
		await get_tree().create_timer(check_interval).timeout
		wait_time += check_interval
	
	print("⚠️ Terrain may not be fully ready, proceeding anyway...")

func wait_for_collider_mesh_to_update(max_wait := 3.0):
	print("🕒 Waiting for terrain collider mesh to update...")
	var elapsed := 0.0
	var check_interval := 0.3
	
	while elapsed < max_wait:
		# Probe using a test raycast to see if terrain collider exists
		var test_origin = cave_position + Vector3.UP * 10.0
		var test_target = cave_position + Vector3.DOWN * 20.0
		
		var query = PhysicsRayQueryParameters3D.create(test_origin, test_target)
		var result = get_world_3d().direct_space_state.intersect_ray(query)
		
		if not result.is_empty() and result["collider"] == voxel_terrain:
			print("✅ Collider mesh is now ready.")
			return
		
		await get_tree().create_timer(check_interval).timeout
		elapsed += check_interval
	
	print("⚠️ Collider may still not be ready after", max_wait, "seconds.")

func generate_enhanced_cave(cave_index: int) -> Dictionary:
	var cave = cave_scene.instantiate()
	var cave_pos = get_cave_position(cave_index)
	cave_position = cave_pos
	cave.global_position = cave_pos
	add_child(cave)

	await get_tree().process_frame
	await get_tree().process_frame

	var cave_quality = determine_cave_quality(cave_pos.y)
	print("🗻 Cave", cave_index, "spawned at", cave_pos, "- Quality:", cave_quality["name"])

	await get_tree().create_timer(0.5).timeout
	await subtract_cave_from_voxel(cave)
	if cave_index == 0:
		await create_surface_entrance(cave_pos)

	var builder = cave.get_node("CaveBuilder")
	var carve_points = builder.get_carve_points()
	collect_raycast_origins(carve_points)

	return {
		"position": cave_pos,
		"quality": cave_quality,
		"depth": cave_pos.y,
		"carve_points": carve_points
	}

# Updated carving function with proper waiting
func subtract_cave_from_voxel(cave_node: Node3D):
	if not voxel_terrain:
		push_error("🚫 voxel_terrain not set!")
		return

	var tool = voxel_terrain.get_voxel_tool()
	if not tool:
		push_error("❌ Could not get voxel tool!")
		return
		
	tool.mode = VoxelTool.MODE_REMOVE

	# Check if cave_node and CaveBuilder exist
	var cave_builder = cave_node.get_node_or_null("CaveBuilder")
	if not cave_builder:
		push_error("❌ CaveBuilder node not found in cave scene!")
		return
	
	if not cave_builder.has_method("get_carve_points"):
		push_error("❌ CaveBuilder doesn't have get_carve_points method!")
		return

	var points = cave_builder.call("get_carve_points")
	print("🗻 Carving cave with", points.size(), "points")
	
	if points.is_empty():
		push_error("❌ No carve points returned from CaveBuilder!")
		return
	
	# Carve each point with waiting between operations
	for i in range(points.size()):
		var point = points[i]
		var pos = point["pos"]
		var radius = point["radius"]
		
		tool.do_sphere(pos, radius)
		
		# Wait every few operations to let voxel system process
		if i % 5 == 0:
			await get_tree().process_frame
			await get_tree().process_frame
	
	# Final wait for all carving to complete
	await get_tree().create_timer(0.5).timeout
	print("✅ Cave carving completed")

# Create surface entrance AFTER cave is carved and make it more obvious
func create_surface_entrance(cave_pos: Vector3):
	if not voxel_terrain:
		return
		
	var tool = voxel_terrain.get_voxel_tool()
	tool.mode = VoxelTool.MODE_REMOVE
	
	var start = Vector3(cave_pos.x, 25, cave_pos.z)
	var end = cave_pos
	var height_diff = abs(start.y - end.y)
	var steps = int(height_diff / 1.2)
	
	# Random seed for consistent but varied paths
	var rng = RandomNumberGenerator.new()
	rng.seed = hash(cave_pos)
	
	# Generate control points for a more natural path
	var control_points = []
	control_points.append(start)
	
	# Add intermediate waypoints for natural meandering
	var num_waypoints = 3 + rng.randi() % 3  # 3-5 waypoints
	for i in range(num_waypoints):
		var progress = float(i + 1) / (num_waypoints + 1)
		var waypoint = Vector3(
			lerp(start.x, end.x, progress) + rng.randf_range(-8, 8),
			lerp(start.y, end.y, progress),
			lerp(start.z, end.z, progress) + rng.randf_range(-8, 8)
		)
		control_points.append(waypoint)
	
	control_points.append(end)
	
	# Create the tunnel following the natural path
	for i in range(steps):
		var t = float(i) / steps
		
		# Use Catmull-Rom spline for smooth curves between control points
		var pos = get_spline_point(control_points, t)
		
		# Add some natural roughness
		var roughness = Vector3(
			rng.randf_range(-1.5, 1.5),
			rng.randf_range(-0.8, 0.8),
			rng.randf_range(-1.5, 1.5)
		)
		pos += roughness
		
		# Vary tunnel radius for more natural look
		var base_radius = 3.5
		var radius_variation = sin(t * PI * 4) * 0.8 + rng.randf_range(-0.5, 0.5)
		var radius = base_radius + radius_variation
		radius = max(radius, 2.0)  # Ensure minimum passable size
		
		tool.do_sphere(pos, radius)
		
		# Add some side chambers occasionally
		if rng.randf() < 0.15:  # 15% chance
			var side_offset = Vector3(
				rng.randf_range(-4, 4),
				rng.randf_range(-2, 2),
				rng.randf_range(-4, 4)
			)
			tool.do_sphere(pos + side_offset, radius * 0.6)
		
		# Yield periodically to prevent frame drops
		if i % 3 == 0:
			await get_tree().process_frame

# Helper function for smooth spline interpolation
func get_spline_point(points: Array, t: float) -> Vector3:
	var count = points.size()
	if count < 2:
		return points[0] if count > 0 else Vector3.ZERO
	
	# Clamp t to valid range
	t = clamp(t, 0.0, 1.0)
	
	# Scale t to point segments
	var scaled_t = t * (count - 1)
	var segment = int(scaled_t)
	var local_t = scaled_t - segment
	
	# Ensure we don't go out of bounds
	segment = min(segment, count - 2)
	
	# Get the four points for Catmull-Rom spline
	var p0 = points[max(0, segment - 1)]
	var p1 = points[segment]
	var p2 = points[min(count - 1, segment + 1)]
	var p3 = points[min(count - 1, segment + 2)]
	
	# Catmull-Rom spline calculation
	var t2 = local_t * local_t
	var t3 = t2 * local_t
	
	return 0.5 * (
		(2 * p1) +
		(-p0 + p2) * local_t +
		(2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
		(-p0 + 3 * p1 - 3 * p2 + p3) * t3
	)

func get_cave_position(cave_index: int) -> Vector3:
	# Simple positioning very close to origin for testing
	var angle = (2.0 * PI * cave_index) / cave_count
	var distance = spawn_radius  # Much smaller radius now (25 units)
	
	var cave_pos = Vector3(
		cos(angle) * distance,
		cave_depth,  # Now only -15 depth
		sin(angle) * distance
	)
	
	print("🎯 Cave will be positioned at:", cave_pos)
	print("🎯 Surface entrance will be near:", Vector3(cave_pos.x, 0, cave_pos.z))
	
	return cave_pos

func determine_cave_quality(depth: float) -> Dictionary:
	var base_quality_index = 1  # Common by default
	
	# Deeper caves have higher chance for better quality
	var depth_bonus = max(0, int(abs(depth) / 30))  # +1 quality level per 30 depth
	var random_roll = randf()
	
	# Quality chances: Poor(15%), Common(40%), Rich(25%), Abundant(15%), Legendary(5%)
	if random_roll < 0.15:
		base_quality_index = 0  # Poor
	elif random_roll < 0.55:
		base_quality_index = 1  # Common
	elif random_roll < 0.80:
		base_quality_index = 2  # Rich
	elif random_roll < 0.95:
		base_quality_index = 3  # Abundant
	else:
		base_quality_index = 4  # Legendary
	
	# Apply depth bonus
	var final_quality_index = min(4, base_quality_index + depth_bonus)
	return cave_quality_levels[final_quality_index]

func spawn_enhanced_ore_system(points: Array, cave_builder: Node, quality: Dictionary, cave_depth: float) -> Dictionary:
	await get_tree().create_timer(2.0).timeout

	var ore_scene = preload("res://Ore.tscn")
	var space_state = get_world_3d().direct_space_state
	var spawned = 0

	# How many to spawn total
	var depth_multiplier = 1.0 + (abs(cave_depth) / 100.0) * depth_ore_multiplier
	var quality_multiplier = quality["ore_multiplier"]
	var variance = randf_range(1.0 - ore_density_variance, 1.0 + ore_density_variance)
	var total_ore_target = int((base_ores_per_chamber + base_ores_per_tunnel) * cave_count * depth_multiplier * quality_multiplier * variance)

	raycast_origins.shuffle()
	for i in range(min(total_ore_target, raycast_origins.size())):
		var origin = raycast_origins[i]
		var direction = Vector3(randf_range(-1, 1), randf_range(-0.3, 0.3), randf_range(-1, 1)).normalized()

		var spawn_result = attempt_ore_spawn(origin, direction, 6.0, space_state, ore_scene, quality, origin.y)
		spawned += spawn_result

	print("✅ Total ores spawned:", spawned)

	return {
		"total_ores": spawned,
		"quality": quality
	}

func spawn_advanced_chamber_ores(chamber_points: Array, target_count: int, quality: Dictionary, cave_depth: float) -> int:
	var ore_scene = preload("res://Ore.tscn")
	var space_state = get_world_3d().direct_space_state
	var spawned = 0
	
	for chamber in chamber_points:
		if spawned >= target_count:
			break
		
		var chamber_center = chamber["pos"]
		var chamber_radius = chamber["radius"]
		
		# Use golden ratio spiral for optimal distribution
		var ores_for_chamber = min(target_count - spawned, randi_range(6, 12))
		var golden_angle = PI * (3.0 - sqrt(5.0))
		
		for i in range(ores_for_chamber):
			var y = 1 - (2.0 * i / (ores_for_chamber - 1))
			var radius = sqrt(1 - y * y)
			var theta = golden_angle * i
			
			var direction = Vector3(
				cos(theta) * radius,
				y * 0.5,  # Reduce vertical spread
				sin(theta) * radius
			)
			
			var spawn_result = attempt_ore_spawn(chamber_center, direction, chamber_radius, space_state, ore_scene, quality, cave_depth)
			if spawn_result > 0:
				spawned += spawn_result
				
		# Chance for ore veins in chambers
		if randf() < ore_cluster_chance:
			spawned += spawn_ore_vein(chamber_center, chamber_radius, space_state, ore_scene, quality, cave_depth)
	
	return spawned

func spawn_advanced_tunnel_ores(tunnel_points: Array, target_count: int, quality: Dictionary, cave_depth: float) -> int:
	var ore_scene = preload("res://Ore.tscn")
	var space_state = get_world_3d().direct_space_state
	var spawned = 0
	
	# Group tunnel points by type for better distribution
	var tunnel_groups = {}
	for point in tunnel_points:
		var tunnel_type = point.get("type", "tunnel")
		if not tunnel_groups.has(tunnel_type):
			tunnel_groups[tunnel_type] = []
		tunnel_groups[tunnel_type].append(point)
	
	# Distribute ores across tunnel types
	for tunnel_type in tunnel_groups:
		var points = tunnel_groups[tunnel_type]
		var ores_for_type = target_count / tunnel_groups.size()
		
		for i in range(min(ores_for_type, points.size())):
			if spawned >= target_count:
				break
			
			var point = points[i]
			var directions = get_radial_directions(6)
			
			for direction in directions:
				if spawned >= target_count:
					break
				
				var spawn_result = attempt_ore_spawn(point["pos"], direction, point["radius"], space_state, ore_scene, quality, cave_depth)
				if spawn_result > 0:
					spawned += spawn_result
					break  # Only one ore per tunnel segment
	
	return spawned

func spawn_ore_vein(center: Vector3, radius: float, space_state: PhysicsDirectSpaceState3D, ore_scene: PackedScene, quality: Dictionary, cave_depth: float) -> int:
	var spawned = 0
	var vein_size = randi_range(2, 5)
	var ore_type = choose_ore_type(cave_depth, quality)
	
	if not ore_type:
		return 0
	
	var vein_direction = Vector3(
		randf_range(-1, 1),
		randf_range(-0.5, 0.5),
		randf_range(-1, 1)
	).normalized()
	
	for i in range(vein_size):
		var vein_pos = center + vein_direction * (i * 2.0)
		var random_offset = Vector3(
			randf_range(-1, 1),
			randf_range(-1, 1),
			randf_range(-1, 1)
		)
		
		var final_pos = vein_pos + random_offset
		var direction = (final_pos - center).normalized()
		
		var spawn_result = attempt_ore_spawn(center, direction, radius, space_state, ore_scene, quality, cave_depth, ore_type)
		spawned += spawn_result
	
	if spawned > 0:
		print("💎 Ore vein spawned:", ore_type["name"], "x", spawned)
	
	return spawned

func spawn_feature_ores(feature_points: Array, quality: Dictionary, cave_depth: float) -> int:
	var ore_scene = preload("res://Ore.tscn")
	var space_state = get_world_3d().direct_space_state
	var spawned = 0
	
	for feature in feature_points:
		# Features have a higher chance of rare ores
		var enhanced_quality = quality.duplicate()
		enhanced_quality["rare_chance"] *= 1.5
		
		var directions = get_radial_directions(4)
		for direction in directions:
			var spawn_result = attempt_ore_spawn(feature["pos"], direction, feature["radius"], space_state, ore_scene, enhanced_quality, cave_depth)
			spawned += spawn_result
	
	return spawned

func attempt_ore_spawn(center: Vector3, direction: Vector3, radius: float, space_state: PhysicsDirectSpaceState3D, ore_scene: PackedScene, quality: Dictionary, cave_depth: float, forced_ore_type: Dictionary = {}) -> int:
	var spawn_distance = randf_range(radius * 0.6, radius + 3.0)
	var ray_start = center
	var ray_end = center + direction.normalized() * spawn_distance
	
	var ray_params = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	ray_params.collide_with_areas = false
	ray_params.collide_with_bodies = true
	ray_params.collision_mask = 0xFFFFFFFF
	
	var result = space_state.intersect_ray(ray_params)
	
	if result.is_empty() or not result.has("collider") or result["collider"] != voxel_terrain:
		return 0
	
	var hit_point = result["position"]
	var hit_normal = result["normal"]
	var ore_position = hit_point + hit_normal * -ore_inset_distance
	
	# Choose ore type based on depth + quality
	var ore_type = forced_ore_type if not forced_ore_type.is_empty() else choose_ore_type(ore_position.y, quality)
	if ore_type.is_empty():
		return 0

	var ore = ore_scene.instantiate()
	ore.global_position = ore_position
	ore.look_at_from_position(ore_position, ore_position - hit_normal, Vector3.UP)

	
	if ore.has_method("set_ore_type"):
		ore.set_ore_type(ore_type)
	elif ore.has_method("setup_ore"):
		ore.setup_ore(ore_type)
	
	get_tree().current_scene.add_child(ore)

	# Optional vein cluster
	var vein_size = ore_type.get("vein_size", 1)
	if vein_size > 1 and randf() < 0.6:
		return 1 + spawn_simple_vein_cluster(ore_position, ore_type, vein_size - 1, ore_scene)
	
	return 1

func spawn_simple_vein_cluster(center: Vector3, ore_type: Dictionary, count: int, ore_scene: PackedScene) -> int:
	var spawned = 0
	var space_state = get_world_3d().direct_space_state
	
	for i in range(count):
		var direction = Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-0.5, 0.5),
			randf_range(-1.0, 1.0)
		).normalized()
		
		var spawn_result = attempt_ore_spawn(center, direction, 6.0, space_state, ore_scene, {"rare_chance": 1.0}, center.y, ore_type)
		if spawn_result > 0:
			spawned += spawn_result
	
	return spawned

func debug_ore_spawning():
	print("🔍 DEBUG: Checking ore spawning system")
	var ore_scene = preload("res://Ore.tscn")
	if not ore_scene:
		print("❌ Ore scene not found!")
		return
	
	# Test spawn one ore at origin
	var test_ore = ore_scene.instantiate()
	test_ore.global_position = Vector3(0, 5, 0)  # Above ground
	get_tree().current_scene.add_child(test_ore)
	print("✅ Test ore spawned at origin")

func choose_ore_type(depth: float, quality: Dictionary) -> Dictionary:
	var valid_ores = []
	var rare_multiplier = quality["rare_chance"]
	
	# Filter ores by depth
	for ore in ore_types:
		if ore["min_depth"] <= depth and depth <= ore["max_depth"]:
			var adjusted_chance = ore["chance"] * rare_multiplier
			var weight = max(1, int(adjusted_chance * 100))
			for i in range(weight):
				valid_ores.append(ore)
	
	if valid_ores.is_empty():
		return {}
	
	return valid_ores[randi() % valid_ores.size()]

func get_radial_directions(count: int) -> Array:
	var directions = []
	var angle_step = 2.0 * PI / count
	
	for i in range(count):
		var angle = i * angle_step
		directions.append(Vector3(
			cos(angle),
			randf_range(-0.3, 0.3),
			sin(angle)
		).normalized())
	
	return directions

func spawn_enhanced_enemies(cave_data: Dictionary, quality: Dictionary, cave_depth: float, cave_id: int = 0):
	if not cave_data.has("chambers"):
		print("🚫 Missing 'chambers' in cave_data! Skipping enemy spawn.")
		return
	
	if not cave_glorps.has(cave_id):
		cave_glorps[cave_id] = []

	# Clean up dead Glorps
	cave_glorps[cave_id] = cave_glorps[cave_id].filter(func(g): return is_instance_valid(g))

	var current_count = cave_glorps[cave_id].size()
	if current_count >= max_glorps_per_cave:
		print("⛔ Cave", cave_id, "already has", current_count, "Glorps. Skipping spawn.")
		return

	var enemy_scene = preload("res://Glorp.tscn")
	if not enemy_scene:
		print("⚠️ No enemy scene found, skipping enemy spawning")
		return
	
	var chambers = cave_data["chambers"]
	var base_enemy_count = max(1, chambers.size() / 2)
	var depth_multiplier = 1.0 + (abs(cave_depth) / 50.0) * 0.3
	var quality_multiplier = quality.get("rare_chance", 1.0) * 0.5
	var enemy_count = int(base_enemy_count * depth_multiplier * quality_multiplier)

	# Cap to max allowed
	enemy_count = min(enemy_count, max_glorps_per_cave - current_count)
	enemy_count = min(enemy_count, chambers.size())  # no more than 1 per chamber

	print("👹 Spawning", enemy_count, "Glorps in cave", cave_id)

	var available_chambers = chambers.duplicate()
	available_chambers.shuffle()

	for i in range(enemy_count):
		if i >= available_chambers.size():
			break
		
		var chamber = available_chambers[i]
		var enemy = enemy_scene.instantiate()
		

		if enemy.has_method("set_difficulty_scale"):
			var difficulty = 1.0 + (abs(cave_depth) / 100.0) + (quality_multiplier - 1.0)
			enemy.set_difficulty_scale(difficulty)
		
		get_tree().current_scene.add_child(enemy)
		enemy.global_position = chamber["pos"] + Vector3(0, 1.5, 0)
		cave_glorps[cave_id].append(enemy)

# Debug function to visualize cave data
func debug_cave_info():
	pass
	print("🔍 Cave System Debug Info:")
	print("  Total caves:", cave_count)
	print("  Spawn radius:", spawn_radius)
	print("  Cave depth range:", cave_depth, "±20")
	print("  Ore types available:", ore_types.size())
	print("  Quality levels:", cave_quality_levels.size())
