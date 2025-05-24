extends CharacterBody3D

@export var speed = 5.0
@export var mouse_sense = 0.003
@export var jump_velocity = 5.0
var is_jetpack_enabled := false
var is_jetpack_active := false
@export var jetpack_force := .5


@onready var camera = $Camera3D
@onready var click_ray = $Camera3D/click_ray 
@onready var dig_ray = $Camera3D/dig_ray 
@onready var spotlight = $Camera3D/SpotLight3D
@onready var voxel_terrain: VoxelTerrain = null
@onready var upgrade_manager = get_node("/root/World/UpgradeManager") 
@onready var player_data = get_parent().get_node("PlayerData")
@onready var player_hud = get_parent().get_node("Ui/PlayerHUD")
@onready var coord_label = player_hud.get_node("Coords")
@onready var pause_menu := get_node("/root/World/Ui/PauseMenu")

var input_enabled = true
var rotation_y = 0.0
var pitch = 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var dig_cooldown = 0.5  # updated via upgrade
var dig_timer = 0.0  # counts down every frame

func _ready():
	await get_tree().process_frame  # wait for scene setup

	# Wait until player_data is available
	if not player_data:
		player_data = get_parent().get_node_or_null("PlayerData")
	if not player_data or not upgrade_manager:
		push_error("❌ player_data or upgrade_manager not ready.")
		return

	SaveManager.load_game(player_data, upgrade_manager)
	upgrade_manager.apply_upgrade_effects()
	upgrade_manager.update_ui()
	var stats = player_data.get_status()
	player_hud.update_status(
		stats["health"],
		stats["water"],
		stats["shovel_energy"],
		stats["money"]
	)
	print("✅ HUD Stats:", stats)


	print("📦 Loaded stats:", player_data.stats)
	print("🔧 Upgrade levels:", upgrade_manager.upgrades)

	voxel_terrain = get_node_or_null("/root/World/ground")
	if voxel_terrain == null:
		push_error("❌ Could not find VoxelTerrain at /root/World/ground")
	else:
		print("✅ Voxel terrain loaded:", voxel_terrain.name)

	if "dig_cooldown" in player_data.stats:
		dig_cooldown = player_data.stats["dig_cooldown"]
		print("🕒 Starting dig cooldown:", dig_cooldown)

func update_mouse_visibility():
	var ui_open := false

	# Check each UI panel
	if pause_menu and pause_menu.visible:
		ui_open = true
	if get_node_or_null("/root/World/Ui/UpgradeUi") and get_node("/root/World/Ui/UpgradeUi").visible:
		ui_open = true
	# Add more checks for other panels here if needed

	if ui_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta):
	var direction = Vector3.ZERO
	var forward = -transform.basis.z
	var right = transform.basis.x
	# Apply gravity
	velocity.y -= gravity * delta
	
	if get_tree().paused:
		return
		
	# Jetpack lift
	is_jetpack_active = false
	if is_jetpack_enabled and Input.is_action_pressed("Jump"):
		velocity.y += jetpack_force
		is_jetpack_active = true


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
	if event.is_action_pressed("menu"):
		if pause_menu:
			pause_menu.visible = not pause_menu.visible
			update_mouse_visibility()
	
			
	if event.is_action_pressed("JetPackToggle"):
		is_jetpack_enabled = !is_jetpack_enabled
		print("🚀 Jetpack toggled:", is_jetpack_enabled)
		
	if event.is_action_pressed("Interact"):
		if click_ray and click_ray.is_colliding():
			var collider = click_ray.get_collider()
			if collider.is_in_group("UpgradePanel"):
				update_mouse_visibility()
				collider.call("on_panel_interacted")

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:

		if click_ray and click_ray.is_colliding():
			var collider = click_ray.get_collider()

			if collider and collider.is_in_group("Ore"):
				if collider.has_method("on_hit"):
					print("✅ Calling on_hit() on ore")
					collider.call("on_hit")
					print("🎒 Inventory after collection:", player_data.inventory)
					return

		# ✅ Dig only on mouse click (not always)
		if dig_ray and dig_ray.is_colliding():
			var dig_target = dig_ray.get_collision_point()
			dig_at(dig_target)

func dig_at(position: Vector3):
	if dig_timer > 0:
		var time_left = round(dig_timer * 100) / 100.0
		print("⏳ Dig on cooldown:", time_left, "sec left.")
		return
		
	if click_ray and click_ray.is_colliding():
		var collider = click_ray.get_collider()
		if collider and collider.is_in_group("Ore"):
			if collider.has_method("on_hit"):
				collider.call("on_hit")
				return  # Don't dig terrain if we hit ore



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
