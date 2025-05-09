extends CharacterBody3D

@export var speed = 5.0
@export var mouse_sense = 0.003
@export var jump_velocity = 5.0

@onready var camera = $Camera3D
@onready var click_ray = $Camera3D/click_ray 
@onready var dig_ray = $Camera3D/dig_ray 
@onready var spotlight = $Camera3D/SpotLight3D
@onready var voxel_terrain: VoxelTerrain = null
@onready var upgrade_manager = get_node("/root/World/UpgradeManager") 
@onready var player_data = get_parent().get_node("PlayerData")
@onready var player_hud = get_parent().get_node("Ui/PlayerHUD")
@onready var coord_label = player_hud.get_node("Coords")

var input_enabled = true
var rotation_y = 0.0
var pitch = 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var dig_cooldown = 0.5  # updated via upgrade
var dig_timer = 0.0  # counts down every frame

func _ready():
	await get_tree().process_frame
	voxel_terrain = get_node_or_null("/root/World/ground")
	if voxel_terrain == null:
		push_error("❌ Could not find VoxelTerrain at /root/World/ground")
	else:
		print("✅ Voxel terrain loaded:", voxel_terrain.name)

	if "dig_cooldown" in player_data.stats:
		dig_cooldown = player_data.stats["dig_cooldown"]
		print("🕒 Starting dig cooldown:", dig_cooldown)

func _physics_process(delta):
	var direction = Vector3.ZERO
	var forward = -transform.basis.z
	var right = transform.basis.x

	if coord_label:
		var pos = global_position
		coord_label.text = str(Vector3i(pos))

	if Input.is_action_pressed("Move_forward"):
		direction += forward
	if Input.is_action_pressed("Move_Back"):
		direction -= forward
	if Input.is_action_pressed("Move_left"):
		direction -= right
	if Input.is_action_pressed("Move_right"):
		direction += right

	direction = direction.normalized()
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	velocity.y -= gravity * delta

	if is_on_floor() and Input.is_action_just_pressed("Jump"):
		velocity.y = jump_velocity

	move_and_slide()

	# ⏳ Reduce dig cooldown every frame
	if dig_timer > 0:
		dig_timer -= delta

func _unhandled_input(event):
	if not input_enabled:
		return  

	if event is InputEventMouseMotion:
		rotation_y -= event.relative.x * mouse_sense
		pitch -= event.relative.y * mouse_sense
		pitch = clamp(pitch, -1.5, 1.5)
		rotation.y = rotation_y
		camera.rotation.x = pitch

func _input(event):
	if event.is_action_pressed("Interact"):
		if click_ray and click_ray.is_colliding():
			var collider = click_ray.get_collider()
			if collider.is_in_group("UpgradePanel"):
				collider.call("on_panel_interacted")

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var collider = click_ray.get_collider()
		if collider and collider.name == "ground":
			var pos = dig_ray.get_collision_point()
			dig_at(pos)

func dig_at(position: Vector3):
	if dig_timer > 0:
		var time_left = round(dig_timer * 100) / 100.0
		print("⏳ Dig on cooldown:", time_left, "sec left.")
		return

	var tool = voxel_terrain.get_voxel_tool()
	tool.mode = VoxelTool.MODE_REMOVE

	var radius = player_data.get_stat("dig_radius")
	var can_dig = player_data.get_stat("can_dig")

	if can_dig:
		print("🛠️ Digging at:", position, "Radius:", radius)
		tool.do_sphere(position, radius)

		player_data.stats["dig_count"] += 1
		if player_data.stats["dig_count"] == 100: 
			player_data.stats["water"] -= 1.0
			player_data.stats["dig_count"] = 0
		if player_data.stats["dig_count"] % 10 == 0:
			player_data.stats["shovel_energy"] -= 1
	else:
		print("⛔ Cannot dig right now (can_dig is false)")

	# Reset cooldown
	dig_timer = dig_cooldown

	# Update HUD
	var stats = player_data.get_status()
	player_hud.update_status(stats.health, stats.water, stats.shovel_energy, stats.money)

func set_dig_speed(value: float):
	dig_cooldown = 0.5 / value
	player_data.set_stat("dig_cooldown", dig_cooldown)
	print("🕒 Dig cooldown set to:", dig_cooldown)

func set_light_brightness(value: float):
	if spotlight:
		spotlight.light_energy = clamp(value, 1.0, 10.0)
		spotlight.spot_range = 10.0 + value * 5.0
		spotlight.spot_attenuation = 1.0 / max(value, 0.01)
		print("💡 Spotlight updated:")
		print("- Energy:", spotlight.light_energy)
		print("- Range:", spotlight.spot_range)
		print("- Attenuation:", spotlight.spot_attenuation)
	else:
		print("⚠️ Spotlight not found.")



		
		
