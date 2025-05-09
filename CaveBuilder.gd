extends Node3D

@export var chamber_radius := 8
@export var tunnel_length := 30
@export var tunnel_radius := 3.5
@export var tunnel_count := 6
@export var tunnel_segments := 10
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

	for i in 8:
		var sphere = CSGSphere3D.new()
		sphere.radius = chamber_radius * rng.randf_range(0.9, 1.2)
		sphere.operation = CSGShape3D.OPERATION_UNION
		var offset = Vector3(
			rng.randf_range(-2.0, 2.0),
			rng.randf_range(-2.0, 2.0),
			rng.randf_range(-2.0, 2.0)
		)
		sphere.transform.origin = offset
		combiner.add_child(sphere)
		carve_points.append({ "pos": global_transform.origin + offset, "radius": sphere.radius })
		
	for i in tunnel_count:
		var angle = i * (360.0 / tunnel_count) + rng.randf_range(-10.0, 10.0)
		var elevation = rng.randf_range(-0.3, 0.3)
		var dir = (Basis(Vector3.UP, deg_to_rad(angle)) * Vector3.FORWARD).normalized()
		dir.y = elevation
		dir = dir.normalized()

		var start_pos = dir * chamber_radius * 0.9

		for j in tunnel_segments:
			var depth = tunnel_length * rng.randf_range(0.8, 1.2) / tunnel_segments
			var radius = tunnel_radius * rng.randf_range(0.7, 1.3)

			var segment = CSGPolygon3D.new()
			segment.polygon = make_rough_circle_polygon(6, radius)
			segment.depth = depth
			segment.smooth_faces = true
			segment.operation = CSGShape3D.OPERATION_UNION

			var segment_offset = dir * depth * j
			if j == 0:
				segment_offset = start_pos
			else:
				segment_offset += Vector3(
					rng.randf_range(-0.8, 0.8),
					rng.randf_range(-0.5, 0.5),
					rng.randf_range(-0.8, 0.8)
				)

			var look_dir = (segment_offset - start_pos)
			if look_dir.length() == 0:
				look_dir = Vector3.FORWARD
			var basis = Basis().looking_at(look_dir.normalized(), Vector3.UP)
			segment.transform = Transform3D(basis, segment_offset)

			combiner.add_child(segment)
			carve_points.append({ "pos": global_transform.origin + segment_offset, "radius": radius })

			start_pos = segment_offset

			if add_secondary_chambers and j == tunnel_segments - 1:
				var chamber = CSGSphere3D.new()
				chamber.radius = chamber_radius * 0.4 * rng.randf_range(0.9, 1.2)
				chamber.operation = CSGShape3D.OPERATION_UNION
				chamber.transform.origin = segment_offset + look_dir * 1.5
				combiner.add_child(chamber)
				carve_points.append({ "pos": global_transform.origin + chamber.transform.origin, "radius": chamber.radius })

	# Hide all CSG shapes after they're used for carving
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

func get_carve_points() -> Array:
	return carve_points
