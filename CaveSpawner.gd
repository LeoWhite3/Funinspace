extends Node3D


@export var cave_scene: PackedScene
@export var voxel_terrain: VoxelTerrain
@export_range(1, 10) var cave_count := 2
#distance form the orgigon where a cave can spawn creats a spwaning aread with this radius size
@export_range(20.0, 150.0) var spawn_radius := 100.0 
@export_range(-100.0, 0.0) var cave_depth := -30.0
# Maximum distance from origin that caves can be placed
@export_range(10.0, 100.0) var max_cave_radius := 50.0

# Ore spawning settings
@export_range(5, 50) var chamber_ore_count := 15
@export_range(5, 50) var tunnel_ore_count := 15
@export_range(0.01, 1.0) var ore_inset_distance := 0.05
@export_range(1.0, 10.0) var tunnel_ore_spacing := 3.0

var ore_types = [
	{
		"name": "Iron", "chance": 0.4, "min_depth": -20, "price": 10, "weight": 2.0,
		"color": Color(0.45, 0.45, 0.45), "sparkle": 0.0
	},
	{
		"name": "Copper", "chance": 0.3, "min_depth": -25, "price": 15, "weight": 1.5,
		"color": Color(0.85, 0.45, 0.25), "sparkle": 0.05
	},
	{
		"name": "Silver", "chance": 0.15, "min_depth": -35, "price": 25, "weight": 1.2,
		"color": Color(0.9, 0.9, 1.0), "sparkle": 0.2
	},
	{
		"name": "Gold", "chance": 0.1, "min_depth": -45, "price": 50, "weight": 1.0,
		"color": Color(1.0, 0.85, 0.0), "sparkle": 0.5
	},
	{
		"name": "Diamond", "chance": 0.05, "min_depth": -60, "price": 100, "weight": 0.8,
		"color": Color(0.6, 0.9, 1.0), "sparkle": 0.8
	}
]



func _ready():
	voxel_terrain = get_node_or_null("/root/World/ground")
	if not voxel_terrain:
		push_error("❌ VoxelTerrain node named 'ground' not found at /root/World/ground")
		return

	await get_tree().create_timer(0.5).timeout

	var tool = voxel_terrain.get_voxel_tool()
	tool.mode = VoxelTool.MODE_REMOVE
	print("🧭 VoxelTerrain initialized")

	for i in cave_count:
		var cave = cave_scene.instantiate()
		var angle = i * TAU / cave_count
		var dist = randf_range(max_cave_radius * 0.5, max_cave_radius)
		var x = cos(angle) * dist
		var z = sin(angle) * dist

		var cave_pos = Vector3(x, cave_depth, z)
		cave.global_position = cave_pos
		add_child(cave)
		print("📍 Cave", i, "spawned at", cave_pos)

		await get_tree().process_frame
		subtract_cave_from_voxel(cave)
		await get_tree().process_frame

		var carve_points = cave.get_node("CaveBuilder").get_carve_points()
		var result = await spawn_ores_intelligently(carve_points, cave.get_node("CaveBuilder"))

		spawn_glorps(result["chambers"], result["tunnels"])


func subtract_cave_from_voxel(cave_node: Node3D):
	if not voxel_terrain:
		push_error("🚫 voxel_terrain not set!")
		return

	var tool = voxel_terrain.get_voxel_tool()
	tool.mode = VoxelTool.MODE_REMOVE
	await get_tree().process_frame

	var points = cave_node.get_node("CaveBuilder").call("get_carve_points")
	for point in points:
		var pos = point["pos"]
		var radius = point["radius"]
		tool.do_sphere(pos, radius)

# New intelligent ore spawning that handles chambers and tunnels separately
func spawn_ores_intelligently(points: Array, cave_builder: Node) -> Dictionary:
	print("⏳ Waiting for collision mesh to generate...")
	await get_tree().create_timer(2.0).timeout

	var chamber_points = []
	var tunnel_segments = []

	classify_cave_points(points, cave_builder, chamber_points, tunnel_segments)

	spawn_chamber_ores(chamber_points)
	spawn_tunnel_ores(tunnel_segments)

	return {
		"chambers": chamber_points,
		"tunnels": tunnel_segments
	}


# Classify points into chambers vs tunnel segments
func classify_cave_points(points: Array, cave_builder: Node, chamber_points: Array, tunnel_segments: Array):
	# Get cave builder parameters
	var chamber_radius = cave_builder.chamber_radius if cave_builder.has_method("get") else 8.0
	var tunnel_radius = cave_builder.tunnel_radius if cave_builder.has_method("get") else 3.5
	var tunnel_count = cave_builder.tunnel_count if cave_builder.has_method("get") else 6
	var tunnel_segments_count = cave_builder.tunnel_segments if cave_builder.has_method("get") else 10
	
	# First 8 points are typically the main chamber spheres
	var chamber_count = 8
	for i in range(min(chamber_count, points.size())):
		chamber_points.append(points[i])
	
	# Remaining points are tunnel segments and secondary chambers
	var remaining_points = points.slice(chamber_count)
	
	# Group tunnel points into segments
	var points_per_tunnel = tunnel_segments_count + (1 if cave_builder.add_secondary_chambers else 0)
	
	for tunnel_idx in range(tunnel_count):
		var tunnel_start = tunnel_idx * points_per_tunnel
		var tunnel_end = min(tunnel_start + tunnel_segments_count, remaining_points.size())
		
		if tunnel_start < remaining_points.size():
			var tunnel_points = []
			for i in range(tunnel_start, tunnel_end):
				if i < remaining_points.size():
					tunnel_points.append(remaining_points[i])
			
			if tunnel_points.size() > 0:
				tunnel_segments.append(tunnel_points)

# Spawn ores in chamber areas using spherical distribution
func spawn_chamber_ores(chamber_points: Array):
	var ore_scene = preload("res://Ore.tscn")
	var space_state = get_world_3d().direct_space_state
	var successful_spawns = 0
	
	for chamber_point in chamber_points:
		if successful_spawns >= chamber_ore_count:
			break
			
		var chamber_center = chamber_point["pos"]
		var chamber_radius = chamber_point["radius"]
		
		# Use fibonacci sphere for even distribution
		var rays_per_chamber = 12
		for i in range(rays_per_chamber):
			if successful_spawns >= chamber_ore_count:
				break
			
			var direction = get_fibonacci_sphere_point(i, rays_per_chamber)
			var ray_start = chamber_center
			var ray_end = chamber_center + direction * (chamber_radius + 5.0)
			
			var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			query.collision_mask = 0xFFFFFFFF
			
			var result = space_state.intersect_ray(query)
			
			if result.is_empty() or result["collider"] != voxel_terrain:
				continue
			
			var hit_point = result["position"]
			var hit_normal = result["normal"]
			var ore_position = hit_point + hit_normal * ore_inset_distance
			
			var ore_data = choose_ore_type(ore_position.y)
			spawn_ore_at_position(ore_position, hit_normal, ore_scene, ore_data)

			successful_spawns += 1
			print("🏛️ Chamber ore spawned at:", ore_position)
	
	print("✅ Spawned", successful_spawns, "chamber ores")

# Spawn ores along tunnel walls
func spawn_tunnel_ores(tunnel_segments: Array):
	var ore_scene = preload("res://Ore.tscn")
	var space_state = get_world_3d().direct_space_state
	var successful_spawns = 0
	
	for tunnel_points in tunnel_segments:
		if successful_spawns >= tunnel_ore_count:
			break
		
		# Spawn ores along this tunnel
		spawn_ores_along_tunnel(tunnel_points, ore_scene, space_state, successful_spawns)
	
	print("✅ Total tunnel ores spawned:", successful_spawns)

# Spawn ores along a specific tunnel path
func spawn_ores_along_tunnel(tunnel_points: Array, ore_scene: PackedScene, space_state: PhysicsDirectSpaceState3D, spawned_count: int):
	if tunnel_points.size() < 2:
		return spawned_count
	
	var current_spawns = spawned_count
	
	# Create a path through the tunnel points
	for i in range(tunnel_points.size() - 1):
		if current_spawns >= tunnel_ore_count:
			break
			
		var start_point = tunnel_points[i]
		var end_point = tunnel_points[i + 1]
		
		var start_pos = start_point["pos"]
		var end_pos = end_point["pos"]
		var avg_radius = (start_point["radius"] + end_point["radius"]) * 0.5
		
		# Calculate tunnel direction
		var tunnel_direction = (end_pos - start_pos).normalized()
		var segment_length = start_pos.distance_to(end_pos)
		
		# Number of ore spawn attempts along this segment
		var spawn_attempts = max(1, int(segment_length / tunnel_ore_spacing))
		
		for j in range(spawn_attempts):
			if current_spawns >= tunnel_ore_count:
				break
			
			# Position along the tunnel segment
			var t = float(j) / float(spawn_attempts)
			var tunnel_pos = start_pos.lerp(end_pos, t)
			
			# Try to spawn ore on tunnel walls (radial directions)
			var radial_directions = get_tunnel_radial_directions(tunnel_direction, 6)
			
			for direction in radial_directions:
				if current_spawns >= tunnel_ore_count:
					break
				
				var ray_start = tunnel_pos
				var ray_end = tunnel_pos + direction * (avg_radius + 3.0)
				
				var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
				query.collision_mask = 0xFFFFFFFF
				
				var result = space_state.intersect_ray(query)
				
				if result.is_empty() or result["collider"] != voxel_terrain:
					continue
				
				var hit_point = result["position"]
				var hit_normal = result["normal"]
				var ore_position = hit_point + hit_normal * ore_inset_distance
				
				var ore_data = choose_ore_type(ore_position.y)
				spawn_ore_at_position(ore_position, hit_normal, ore_scene, ore_data)

				current_spawns += 1
				print("🚇 Tunnel ore spawned at:", ore_position)
				break  # Only spawn one ore per position along tunnel
	
	return current_spawns

# Get radial directions perpendicular to tunnel direction
func get_tunnel_radial_directions(tunnel_dir: Vector3, count: int) -> Array:
	var directions = []
	
	# Find two perpendicular vectors to the tunnel direction
	var up = Vector3.UP
	if abs(tunnel_dir.dot(up)) > 0.9:  # If tunnel is mostly vertical
		up = Vector3.RIGHT
	
	var right = tunnel_dir.cross(up).normalized()
	var forward = tunnel_dir.cross(right).normalized()
	
	# Generate radial directions around the tunnel
	for i in range(count):
		var angle = 2.0 * PI * i / count
		var direction = (right * cos(angle) + forward * sin(angle)).normalized()
		directions.append(direction)
	
	return directions

# Generate evenly distributed points on a sphere using fibonacci spiral
func get_fibonacci_sphere_point(i: int, n: int) -> Vector3:
	var theta = 2.0 * PI * i / (1.0 + sqrt(5.0))  # Golden angle
	var y = 1.0 - 2.0 * i / float(n - 1)
	var radius = sqrt(1.0 - y * y)
	var x = radius * cos(theta)
	var z = radius * sin(theta)
	return Vector3(x, y, z)

# Spawn an ore at a specific position with proper orientation
func spawn_ore_at_position(position: Vector3, surface_normal: Vector3, ore_scene: PackedScene, ore_data: Dictionary):
	var ore = ore_scene.instantiate()
	ore.global_position = position
	ore.look_at(position - surface_normal, Vector3.UP)
	ore.set("ore_data", ore_data)  # Pass metadata to ore instance
	add_child(ore)
	
	# Orient ore to face away from the wall

# Fallback method using voxel detection (keep your original as backup)
func spawn_ores_fallback_voxel(points: Array):
	print("🔄 Using fallback voxel-based ore spawning")
	var ore_scene = preload("res://Ore.tscn")
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	var tool = voxel_terrain.get_voxel_tool()
	
	var successful_spawns = 0
	var max_ores = chamber_ore_count + tunnel_ore_count
	
	for point in points:
		if successful_spawns >= max_ores:
			break
			
		var cave_center = point["pos"]
		var cave_radius = point["radius"]
		
		# Try multiple positions around the cave
		for attempt in range(15):
			if successful_spawns >= max_ores:
				break
				
			# Random direction from cave center
			var direction = Vector3(
				rng.randf_range(-1.0, 1.0),
				rng.randf_range(-1.0, 1.0),
				rng.randf_range(-1.0, 1.0)
			).normalized()
			
			# Check positions at different distances from center
			for distance in range(int(cave_radius * 0.8), int(cave_radius + 3)):
				var check_pos = cave_center + direction * distance
				var voxel_value = tool.get_voxel_f(check_pos)
				
				# Found transition from air to solid (wall)
				if voxel_value > 0.5:
					# Position ore slightly back toward cave center
					var ore_pos = cave_center + direction * (distance - 1.0)
					
					# Verify ore position is in air
					if tool.get_voxel_f(ore_pos) < 0.5:
						var ore_data = choose_ore_type(ore_pos.y)
						spawn_ore_at_position(ore_pos, -direction, ore_scene, ore_data)

						successful_spawns += 1
						print("🪙 Fallback ore spawned at:", ore_pos)
						break  # Found good spot, try next direction
	
	print("✅ Fallback spawned", successful_spawns, "ores")
	rng.randomize()
	var space_state = get_world_3d().direct_space_state
	
	# Pick a few key cave points
	var key_points = []
	var step = max(1, points.size() / 5)  # Use every 5th point
	for i in range(0, points.size(), step):
		key_points.append(points[i])
	
	for point in key_points:
		if successful_spawns >= max_ores:
			break
			
		var cave_center = point["pos"]
		var cave_radius = point["radius"]
		
		# Generate points on a sphere around the cave center
		var sphere_samples = 20
		for i in range(sphere_samples):
			if successful_spawns >= max_ores:
				break
			
			# Fibonacci sphere distribution for even spacing
			var theta = 2.0 * PI * i / (1.0 + sqrt(5.0))  # Golden angle
			var y = 1.0 - 2.0 * i / float(sphere_samples - 1)
			var radius = sqrt(1.0 - y * y)
			var x = radius * cos(theta)
			var z = radius * sin(theta)
			
			var direction = Vector3(x, y, z)
			var ray_start = cave_center
			var ray_end = cave_center + direction * (cave_radius + 5.0)
			
			var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
			query.collision_mask = 1
			
			var result = space_state.intersect_ray(query)
			
			if result.is_empty() or result["collider"] != voxel_terrain:
				continue
			
			var hit_point = result["position"]
			var hit_normal = result["normal"]
			var ore_position = hit_point + hit_normal * 0.2
			
			var ore = ore_scene.instantiate()
			ore.global_position = ore_position
			ore.look_at(ore_position - hit_normal, Vector3.UP)
			
			add_child(ore)
			successful_spawns += 1
			print("🪙 Spherical ore at:", ore_position)
	
	print("✅ Spawned", successful_spawns, "ores with spherical distribution") 

func choose_ore_type(spawn_depth: float) -> Dictionary:
	var available = []
	for ore in ore_types:
		if spawn_depth <= ore["min_depth"]:
			if randf() < ore["chance"]:
				available.append(ore)
	if available.size() > 0:
		return available[randi() % available.size()]
	return ore_types[0]  # fallback

func spawn_glorps(chamber_points: Array, tunnel_segments: Array):
	var glorp_scene = preload("res://glorp.tscn")

	# 👾 1. Spawn in the main chamber
	if chamber_points.size() > 0:
		var main_chamber_pos = chamber_points[0]["pos"]
		var glorp1 = glorp_scene.instantiate()
		glorp1.global_position = main_chamber_pos
		add_child(glorp1)

	# 👾 2. Spawn in a random tunnel point
	if tunnel_segments.size() > 0:
		var tunnel = tunnel_segments[randi() % tunnel_segments.size()]
		if tunnel.size() > 0:
			var tunnel_pos = tunnel[randi() % tunnel.size()]["pos"]
			var glorp2 = glorp_scene.instantiate()
			glorp2.global_position = tunnel_pos
			add_child(glorp2)


func spawn_glorp_at(pos: Vector3):
	var glorp_scene = preload("res://glorp.tscn")
	var glorp = glorp_scene.instantiate()
	glorp.global_position = pos
	add_child(glorp)
	print("👾 Spawned Glorp at:", pos)
