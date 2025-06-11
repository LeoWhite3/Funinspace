extends Node3D

@export var chamber_radius := 7.5
@export var tunnel_radius := 3.5
@export var tunnel_length := 100.0
@export var tunnel_segments := 20
@export var tunnel_count := 6
@export var add_secondary_chambers := true
@export var seed := 1337

# Enhanced cave generation parameters
@export var cave_complexity := 2  # 1=Simple, 2=Medium, 3=Complex
@export var branch_probability := 0.3
@export var chamber_cluster_count := 3  # Multiple chamber clusters
@export var vertical_variation := 0.5  # How much caves go up/down
@export var cave_interconnectivity := 0.4  # Chance tunnels connect to other chambers

var rng := RandomNumberGenerator.new()
var carve_points := []
var chamber_centers := []
var tunnel_networks := []

func _ready():
	rng.seed = seed
	print("🌌 Enhanced CaveBuilder: Generating cave with seed", seed, "complexity", cave_complexity)

	var combiner = CSGCombiner3D.new()
	combiner.name = "CSGCombiner3D"
	add_child(combiner)

	# Generate multiple chamber clusters for more interesting layouts
	generate_chamber_clusters(combiner)
	
	# Create interconnected tunnel network
	generate_tunnel_network(combiner)
	
	# Add branching tunnels based on complexity
	if cave_complexity >= 2:
		generate_branch_tunnels(combiner)
	
	# Add complex features for high complexity caves
	if cave_complexity >= 3:
		generate_cave_features(combiner)

	# Hide the CSG shapes
	for child in combiner.get_children():
		if child is CSGShape3D:
			child.visible = false

func generate_chamber_clusters(combiner: CSGCombiner3D):
	for cluster_idx in chamber_cluster_count:
		var cluster_center = Vector3(
			rng.randf_range(-chamber_radius * 4, chamber_radius * 4),  # Increased from 2 to 4
			rng.randf_range(-chamber_radius * vertical_variation, chamber_radius * vertical_variation),
			rng.randf_range(-chamber_radius * 4, chamber_radius * 4)   # Increased from 2 to 4
		)
		
		var chambers_in_cluster = rng.randi_range(3, 5)
		var cluster_chambers = []
		
		for i in chambers_in_cluster:
			var radius = chamber_radius * rng.randf_range(0.8, 1.3)
			var sphere = CSGSphere3D.new()
			sphere.radius = radius
			sphere.operation = CSGShape3D.OPERATION_UNION

			var angle = (2.0 * PI * i) / chambers_in_cluster
			var distance = chamber_radius * rng.randf_range(1.5, 2.5)  # Increased from 0.5-1.2 to 1.5-2.5
			var offset = cluster_center + Vector3(
				cos(angle) * distance,
				rng.randf_range(-2.0, 2.0),  # More vertical variation
				sin(angle) * distance
			)
			
			sphere.transform.origin = offset
			combiner.add_child(sphere)
			
			var world_pos = global_transform.origin + offset
			carve_points.append({
				"pos": world_pos, 
				"radius": radius, 
				"type": "chamber",
				"cluster": cluster_idx
			})
			chamber_centers.append(world_pos)
			cluster_chambers.append(world_pos)
		
		tunnel_networks.append(cluster_chambers)

func generate_tunnel_network(combiner: CSGCombiner3D):
	# Connect chambers within clusters
	for cluster_chambers in tunnel_networks:
		connect_chambers_in_cluster(cluster_chambers, combiner)
	
	# Connect different clusters
	if tunnel_networks.size() > 1:
		connect_chamber_clusters(combiner)

func connect_chambers_in_cluster(chambers: Array, combiner: CSGCombiner3D):
	for i in range(chambers.size() - 1):
		var start_pos = chambers[i]
		var end_pos = chambers[i + 1]
		create_curved_tunnel(start_pos, end_pos, combiner, "intra_cluster")

func connect_chamber_clusters(combiner: CSGCombiner3D):
	for i in range(tunnel_networks.size() - 1):
		# Pick random chambers from each cluster to connect
		var cluster_a = tunnel_networks[i]
		var cluster_b = tunnel_networks[i + 1]
		
		var start_chamber = cluster_a[rng.randi_range(0, cluster_a.size() - 1)]
		var end_chamber = cluster_b[rng.randi_range(0, cluster_b.size() - 1)]
		
		create_curved_tunnel(start_chamber, end_chamber, combiner, "inter_cluster")

func create_curved_tunnel(start_pos: Vector3, end_pos: Vector3, combiner: CSGCombiner3D, tunnel_type: String):
	var total_distance = start_pos.distance_to(end_pos)
	var segments = max(5, int(total_distance / 8.0))  # Adaptive segment count
	
	var control_points = generate_tunnel_curve(start_pos, end_pos, segments)
	
	for i in range(segments):
		var current_pos = control_points[i]
		var next_pos = control_points[min(i + 1, control_points.size() - 1)]
		
		var segment_radius = tunnel_radius * rng.randf_range(0.7, 1.3)
		var segment_length = current_pos.distance_to(next_pos)
		
		# Create more organic tunnel shapes
		var polygon = make_organic_tunnel_polygon(8, segment_radius)
		var segment = CSGPolygon3D.new()
		segment.polygon = polygon
		segment.depth = segment_length
		segment.smooth_faces = true
		segment.operation = CSGShape3D.OPERATION_UNION
		
		# Orient segment toward next point
		var direction = (next_pos - current_pos).normalized()
		if direction.length() > 0:
			var basis = Basis.looking_at(direction, Vector3.UP)
			segment.transform = Transform3D(basis, current_pos - global_transform.origin)
		else:
			segment.transform.origin = current_pos - global_transform.origin
		
		combiner.add_child(segment)
		carve_points.append({
			"pos": global_transform.origin + segment.transform.origin,
			"radius": segment_radius,
			"type": "tunnel_" + tunnel_type,
			"segment_index": i
		})

func generate_tunnel_curve(start: Vector3, end: Vector3, segments: int) -> Array:
	var points = []
	var midpoint = (start + end) * 0.5
	
	# Add randomness to create natural curves
	var curve_offset = Vector3(
		rng.randf_range(-tunnel_length * 0.2, tunnel_length * 0.2),
		rng.randf_range(-tunnel_length * 0.1, tunnel_length * 0.1),
		rng.randf_range(-tunnel_length * 0.2, tunnel_length * 0.2)
	)
	midpoint += curve_offset
	
	# Generate points along bezier curve
	for i in segments + 1:
		var t = float(i) / float(segments)
		var point = bezier_curve(start, midpoint, end, t)
		
		# Add some noise for organic feel
		point += Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-0.5, 0.5),
			rng.randf_range(-1.0, 1.0)
		)
		
		points.append(point)
	
	return points

func bezier_curve(p0: Vector3, p1: Vector3, p2: Vector3, t: float) -> Vector3:
	var u = 1.0 - t
	return u * u * p0 + 2.0 * u * t * p1 + t * t * p2

func generate_branch_tunnels(combiner: CSGCombiner3D):
	var branch_count = randi_range(2, 5)
	
	for i in branch_count:
		if rng.randf() > branch_probability:
			continue
		
		# Pick random chamber to branch from
		var start_chamber = chamber_centers[rng.randi_range(0, chamber_centers.size() - 1)]
		
		# Create branch direction
		var branch_direction = Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-vertical_variation, vertical_variation),
			rng.randf_range(-1.0, 1.0)
		).normalized()
		
		var branch_length = tunnel_length * rng.randf_range(0.5, 0.8)
		var branch_end = start_chamber + branch_direction * branch_length
		
		create_curved_tunnel(start_chamber, branch_end, combiner, "branch")

func generate_cave_features(combiner: CSGCombiner3D):
	# Add small alcoves and crevices
	var feature_count = rng.randi_range(3, 8)
	
	for i in feature_count:
		var base_chamber = chamber_centers[rng.randi_range(0, chamber_centers.size() - 1)]
		
		# Create small feature chambers
		var feature_radius = chamber_radius * rng.randf_range(0.2, 0.5)
		var feature_distance = chamber_radius * rng.randf_range(0.8, 1.5)
		
		var direction = Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized()
		
		var feature_pos = base_chamber + direction * feature_distance
		
		var feature = CSGSphere3D.new()
		feature.radius = feature_radius
		feature.operation = CSGShape3D.OPERATION_UNION
		feature.transform.origin = feature_pos - global_transform.origin
		
		combiner.add_child(feature)
		carve_points.append({
			"pos": feature_pos,
			"radius": feature_radius,
			"type": "feature",
			"feature_type": "alcove"
		})

func make_organic_tunnel_polygon(sides: int, base_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		var angle = 2.0 * PI * i / sides
		
		# Create more organic, less circular tunnels
		var radius_variation = rng.randf_range(0.7, 1.4)
		var radius = base_radius * radius_variation
		
		# Add some angular distortion
		var angle_offset = rng.randf_range(-0.2, 0.2)
		angle += angle_offset
		
		points.append(Vector2(
			cos(angle) * radius,
			sin(angle) * radius * rng.randf_range(0.8, 1.2)  # Slightly elliptical
		))
	return points

func make_rough_ellipse_polygon(sides: int, base_radius_x: float, base_radius_y: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		var angle = 2.0 * PI * i / sides
		var radius_x = base_radius_x * rng.randf_range(0.85, 1.15)
		var radius_y = base_radius_y * rng.randf_range(0.85, 1.15)
		points.append(Vector2(
			cos(angle) * radius_x,
			sin(angle) * radius_y
		))
	return points

func get_carve_points() -> Array:
	return carve_points

func get_chamber_centers() -> Array:
	return chamber_centers

func get_tunnel_networks() -> Array:
	return tunnel_networks
