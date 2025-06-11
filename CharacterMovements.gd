extends CharacterBody3D

@export var speed = 5.0
@export var mouse_sense = 0.003
@export var jump_velocity = 8.0
var is_jetpack_enabled := false
var is_jetpack_active := false
@export var jetpack_force := .4

@onready var player_sound = $PlayerSound

@onready var camera = $Camera3D
@onready var click_ray = $Camera3D/click_ray 
@onready var dig_ray = $Camera3D/dig_ray 
@onready var spotlight = $Camera3D/SpotLight3D 
@onready var player_data = get_parent().get_node("PlayerData")
@onready var player_hud = get_parent().get_node("Ui/PlayerHUD")
@onready var coord_label = player_hud.get_node("Coords")
@onready var pause_menu := get_node("/root/World/Ui/PauseMenu")
@onready var shop = get_parent().get_node("/root/World/Ui/Shop")
@onready var upgrade_ui = get_parent().get_node("/root/World/Ui/UpgradeUi")
@onready var upgrade_manager = get_node("/root/World/UpgradeManager")
@onready var inventory := get_node("/root/World/Ui/Inventory")
@export var jetpack_battery_usage_rate := 10.0 
var curr_battery: float



var dig_sounds := [
	preload("res://Sounds/Player/Dig/Dig1.wav"),
	preload("res://Sounds/Player/Dig/Dig2.wav"),
	preload("res://Sounds/Player/Dig/Dig3.wav")

]

var inventory_open = preload("res://Sounds/UiSounds/Inventory/OpenInventory.mp3")
var miss_sounds := [
	preload("res://Sounds/AttackSounds/Player/Miss1.wav"),
]

var jetpack_sound = preload("res://Sounds/JetpackSound/JetPack.wav")

var input_enabled = true
var rotation_y = 0.0
var pitch = 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var dig_cooldown = 0.5  # updated via upgrade
var dig_timer = 0.0  # counts down every frame

@onready var voxel_terrain = get_node("/root/World/ground")

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
		stats["curr_battery"],
		stats["shovel_energy"],
		stats["money"]
	)
	print("✅ HUD Stats:", stats)


	print("📦 Loaded stats:", player_data.stats)
	print("🔧 Upgrade levels:", upgrade_manager.upgrades)

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
	if get_node_or_null("/root/World/Ui/Shop") and get_node("/root/World/Ui/Shop").visible:
		ui_open = true
	# Add more checks for other panels here if needed

	if ui_open:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta):
	if not input_enabled:
		return
	var direction = Vector3.ZERO
	var forward = -transform.basis.z
	var right = transform.basis.x
	

	# Apply gravity
	velocity.y -= gravity * delta

	if get_tree().paused:
		return

	is_jetpack_active = false

	# Jetpack logic
	curr_battery = player_data.get_stat("curr_battery")

	# Jetpack logic
	if is_jetpack_enabled:
		if Input.is_action_pressed("Jump") and curr_battery > 0.0:
			if not player_sound.playing:
				player_sound.stream = jetpack_sound
				player_sound.play()
			
			velocity.y += jetpack_force
			curr_battery -= jetpack_battery_usage_rate * delta
			curr_battery = max(curr_battery, 0.0)
			player_data.set_stat("curr_battery", curr_battery)
			is_jetpack_active = true
		else:
			if player_sound.playing:
				player_sound.stop()
			is_jetpack_active = false




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
		
	# Always refresh HUD with latest stats
	var stats = player_data.get_status()
	player_hud.update_status(stats.health, stats.curr_battery, stats.shovel_energy, stats.money)

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
	if event.is_action_pressed("Inventory"):
		player_sound.stream = inventory_open
		player_sound.play()	
		inventory.visible = not inventory.visible
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
			if collider.is_in_group("ShopPanel"):
				update_mouse_visibility()
				collider.call("on_panel_interacted")

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Try to collect ore first
		if click_ray and click_ray.is_colliding():
			var collider = click_ray.get_collider()

			if collider:
				if collider.is_in_group("Ore") and collider.has_method("on_hit"):
					print("✅ Calling on_hit() on ore")
					collider.call("on_hit")
					print("🎒 Inventory after collection:", player_data.inventory)
					return

				# 👹 Attack Glorp if it's the enemy
				elif collider.is_in_group("Enemy") and collider.has_method("take_damage"):
					print("⚔️ Attacking Glorp!")
					collider.call("take_damage", 25)  # Example damage value
					return
					
		else:
			print("play miss sound")
			if player_sound and miss_sounds.size() > 0:
				var random_sound = miss_sounds[randi() % miss_sounds.size()]
				player_sound.stream = random_sound
				player_sound.play()	

		# ✅ Dig only if ray hits voxel terrain
		if dig_ray and dig_ray.is_colliding():
			var dig_collider = dig_ray.get_collider()
			if shop.visible == false && pause_menu.visible == false && upgrade_ui.visible == false:
				if dig_collider == voxel_terrain:
					if player_sound and dig_sounds.size() > 0:
						var random_sound = dig_sounds[randi() % dig_sounds.size()]
						player_sound.stream = random_sound
						player_sound.play()
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
		tool.do_sphere(position, radius)
		
		var dig_count = int(player_data.stats["dig_count"])
		

		player_data.stats["dig_count"] += 1.0
		if player_data.stats["dig_count"] == 100.0: 
			player_data.stats["dig_count"] = 0.0
		if dig_count % 10 == 0:
			player_data.stats["shovel_energy"] -= 1.0

	# Reset cooldown
	dig_timer = dig_cooldown

	# Update HUD
	var stats = player_data.get_status()
	player_hud.update_status(stats.health, stats.curr_battery, stats.shovel_energy, stats.money)

func set_dig_speed(value: float):
	dig_cooldown = 0.5 / value
	player_data.set_stat("dig_cooldown", dig_cooldown)

func set_light_brightness(value: float):
	if spotlight:
		spotlight.light_energy = clamp(value, 1.0, 10.0)
		spotlight.spot_range = 10.0 + value * 5.0
		spotlight.spot_attenuation = 1.0 / max(value, 0.01)

func take_damage(amount: int):
	var health = player_data.get_stat("health")
	if health <= 0:
		return  # Already dead

	health -= amount
	player_data.set_stat("health", health)
	print("💥 Player took", amount, "damage! Health now:", health)


	if health <= 0:
		die()

func die():
	print("☠️ Player died! Reloading...")

	input_enabled = false
	set_physics_process(false)
	visible = false


	await get_tree().create_timer(1.0).timeout

	var player_data = get_node("/root/World/PlayerData")
	if player_data:
		player_data.reload_from_save()

	# Enable player again
	visible = true
	input_enabled = true
	set_physics_process(true)
	global_transform.origin = Vector3(0.0, 20.0, 2.0)

	print("🧬 Respawn complete.")
