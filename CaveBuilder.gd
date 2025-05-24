extends Node3D

@export var chamber_radius := 7.5
@export var tunnel_radius := 3.5
@export var tunnel_length := 100.0
@export var tunnel_segments := 20
@export var tunnel_count := 6
@export var add_secondary_chambers := true
@export var seed := 1337

var rng := RandomNumberGenerator.new()
var carve_points := []

func _ready():
	rng.seed = seed
	print("🌌 CaveBuilder: Generating cave with seed", seed)

	var combiner = CSGCombiner3D.new()
	combiner.name = "CSGCombiner3D"
	add_child(combiner)

	# Generate organic blob-like core chamber
	var core_positions := []
	for i in 8:
		var radius = chamber_radius * rng.randf_range(0.9, 1.2)
		var sphere = CSGSphere3D.new()
		sphere.radius = radius
		sphere.operation = CSGShape3D.OPERATION_UNION

		# Offset with spherical cluster distribution
		var offset = Vector3(
			rng.randf_range(-1.5, 1.5),
			rng.randf_range(-1.5, 1.5),
			rng.randf_range(-1.5, 1.5)
		)
		sphere.transform.origin = offset
		combiner.add_child(sphere)
		var world_pos = global_transform.origin + offset
		carve_points.append({ "pos": world_pos, "radius": radius })
		core_positions.append(world_pos)

	# Fully 3D tunnel branches
	for i in tunnel_count:
		# Pick a random chamber center to branch from
		var branch_origin = core_positions[rng.randi_range(0, core_positions.size() - 1)]

		# Random 3D unit direction
		var direction = Vector3(
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0),
			rng.randf_range(-1.0, 1.0)
		).normalized()

		var start_pos = branch_origin + direction * chamber_radius * 0.9

		for j in tunnel_segments:
			var depth = tunnel_length / tunnel_segments * rng.randf_range(0.8, 1.2)
			var radius = tunnel_radius * rng.randf_range(0.8, 1.2)

			# Use elliptical CSGPolygon instead of round tunnels for irregularity
			var polygon = make_rough_ellipse_polygon(6, radius, radius * rng.randf_range(0.8, 1.5))
			var segment = CSGPolygon3D.new()
			segment.polygon = polygon
			segment.depth = depth
			segment.smooth_faces = true
			segment.operation = CSGShape3D.OPERATION_UNION

			# Slight random perturbation to direction
			direction += Vector3(
				rng.randf_range(-0.2, 0.2),
				rng.randf_range(-0.2, 0.2),
				rng.randf_range(-0.2, 0.2)
			).normalized() * 0.05
			direction = direction.normalized()

			var segment_offset = direction * depth * j
			if j == 0:
				segment_offset = start_pos - global_transform.origin
			else:
				segment_offset += Vector3(
					rng.randf_range(-0.8, 0.8),
					rng.randf_range(-0.5, 0.5),
					rng.randf_range(-0.8, 0.8)
				)

			var look_dir = (segment_offset - (start_pos - global_transform.origin))
			if look_dir.length() == 0:
				look_dir = Vector3.FORWARD
			var basis = Basis().looking_at(look_dir.normalized(), Vector3.UP)
			segment.transform = Transform3D(basis, segment_offset)

			combiner.add_child(segment)
			carve_points.append({ "pos": global_transform.origin + segment_offset, "radius": radius })
			start_pos = global_transform.origin + segment_offset

			# Optional irregular mid-chamber
			if add_secondary_chambers and rng.randf() < 0.2:
				var mid_chamber = CSGSphere3D.new()
				mid_chamber.radius = chamber_radius * 0.4 * rng.randf_range(0.9, 1.2)
				mid_chamber.operation = CSGShape3D.OPERATION_UNION
				mid_chamber.transform.origin = segment_offset + look_dir * 1.5
				combiner.add_child(mid_chamber)
				carve_points.append({ "pos": global_transform.origin + mid_chamber.transform.origin, "radius": mid_chamber.radius })

	# Hide the CSGs
	for child in combiner.get_children():
		if child is CSGShape3D:
			child.visible = false

func make_rough_circle_polygon(sides: int, base_radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in sides:
		var angle = 2.0 * PI * i / sides
		var radius = base_radius * rng.randf_range(0.85, 1.15)
		points.append(Vector2(
			cos(angle) * radius,
			sin(angle) * radius
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
	
