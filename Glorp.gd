extends CharacterBody3D

@export var speed := 3.0
@export var dig_delay := 2.0
@export var wander_interval := 3.0
@export var chase_distance := 40.0
@export var wander_radius := 15.0
@export var gravity := 9.8
@export var dig_radius := .5

@onready var player = get_node("/root/World/player")
@onready var voxel_terrain = get_node("/root/World/ground")
@onready var area = $Area3D

var target_player := false
var dig_timer := 0.0
var wander_timer := 0.0
var wander_target := Vector3.ZERO

func _ready():
	area.body_entered.connect(_on_area_3d_body_entered)
	area.body_exited.connect(_on_area_3d_body_exited)
	_set_new_wander_target()

func _physics_process(delta):
	if not voxel_terrain:
		return

	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	# Player logic
	if player and target_player:
		var to_player = player.global_position - global_position
		var distance = to_player.length()

		if distance <= chase_distance:
			var space = get_world_3d().direct_space_state
			var ray_params = PhysicsRayQueryParameters3D.create(global_position, player.global_position)
			var result = space.intersect_ray(ray_params)

			if result and result.collider != player:
				# Something is in the way, dig toward it
				dig_timer -= delta
				if dig_timer <= 0:
					dig_at(result.position)
					dig_timer = dig_delay
			else:
				# No obstruction, move toward player
				var dir = to_player.normalized()
				velocity.x = dir.x * speed
				velocity.z = dir.z * speed
		else:
			velocity.x = 0
			velocity.z = 0

		move_and_slide()
		return

	# Wander logic (only if not chasing)
	wander_timer -= delta
	if wander_timer <= 0:
		_set_new_wander_target()
		wander_timer = wander_interval

	var wander_direction = (wander_target - global_position).normalized()
	velocity.x = wander_direction.x * speed * 0.5
	velocity.z = wander_direction.z * speed * 0.5

	# Check for collisions during wandering
	var space = get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.create(global_position, wander_target)
	var result = space.intersect_ray(ray_params)
	if result and result.collider != null:
		dig_timer -= delta
		if dig_timer <= 0:
			dig_at(result.position)
			dig_timer = dig_delay

	move_and_slide()

func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.name == "player" or body.is_in_group("Player"):
		print("👀 Glorp detected player")
		target_player = true

func _on_area_3d_body_exited(body: Node3D) -> void:
	if body.name == "player" or body.is_in_group("Player"):
		print("🚪 Player left Glorp detection zone")
		target_player = false
		_set_new_wander_target()

func _set_new_wander_target():
	var offset = Vector3(
		randf_range(-wander_radius, wander_radius),
		randf_range(-2.0, 2.0),
		randf_range(-wander_radius, wander_radius)
	)
	wander_target = global_position + offset

func dig_at(position: Vector3):
	if voxel_terrain:
		var tool = voxel_terrain.get_voxel_tool()
		tool.mode = VoxelTool.MODE_REMOVE
		tool.do_sphere(position, dig_radius)

	# Optional callback — handled in _physics_process manually
	pass
