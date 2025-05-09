extends Node3D

@export var cave_scene: PackedScene
@export var voxel_terrain: VoxelTerrain
@export var cave_count := 1
@export var spawn_radius := 80.0
@export var cave_depth := -20.0
@export var max_cave_radius := 40.0  # must fit inside voxel terrain bounds

func _ready():

	voxel_terrain = get_node_or_null("/root/World/ground")
	if not voxel_terrain:
		push_error("❌ VoxelTerrain node named 'ground' not found at /root/World/ground")
		return

	await get_tree().create_timer(0.5).timeout  # Wait for terrain to be ready

	var tool = voxel_terrain.get_voxel_tool()
	tool.mode = VoxelTool.MODE_REMOVE
	print("🧭 VoxelTerrain global position:", voxel_terrain.global_position)
	print("🧭 VoxelTerrain transform basis scale:", voxel_terrain.transform.basis.get_scale())

	for i in cave_count:
		var cave = cave_scene.instantiate()
		var angle = i * TAU / cave_count
		var dist = randf_range(max_cave_radius * 0.5, max_cave_radius)
		var x = cos(angle) * dist
		var z = sin(angle) * dist

		var cave_pos = Vector3(x, cave_depth, z)
		cave.global_position = cave_pos
		print("📍 Cave", i, "spawned at", cave_pos)
		add_child(cave)

		await get_tree().process_frame
		print("🪨 Subtracting cave", i, "from voxel terrain...")
		subtract_cave_from_voxel(cave)

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
