extends CharacterBody3D
@export var speed := 5.0
@export var mouse_sense := 0.003
@export var jump_velocity := 5.0
@export var dig_radius := .25
@export var dig_count := 0
@onready var camera := $Camera3D
@onready var click_ray = $Camera3D/click_ray 
@onready var dig_ray = $Camera3D/dig_ray 

@onready var voxel_terrain = get_node("/root/World/ground")  # loads in the vaoxel terrain
@onready var upgrade_manager = get_node("/root/World/UpgradeManager") 
@onready var player_data = get_parent().get_node("PlayerData")
@onready var player_hud = get_parent().get_node("Ui/PlayerHUD")

var rotation_y = 0.0
var pitch = 0.0
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	
func _unhandled_input(event):
	if event is InputEventMouseMotion:
		rotation_y -= event.relative.x * mouse_sense
		pitch -= event.relative.y * mouse_sense
		pitch = clamp(pitch, -1.5, 1.5)
		rotation.y = rotation_y
		camera.rotation.x = pitch
		
func _physics_process(delta):
	var direction = Vector3.ZERO
	var forward = -transform.basis.z
	var right = transform.basis.x
	
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
	velocity.y = velocity.y - gravity * delta
	if is_on_floor() and Input.is_action_just_pressed("Jump"):
		velocity.y = jump_velocity
	move_and_slide()

func _input(event):
	if event.is_action_pressed("Interact"):
		print("Pressed interact key")

		if click_ray:
			print("click_ray exists")
			if click_ray.is_colliding():
				var collider = click_ray.get_collider()
				print("Raycast hit:", collider.name)

				if collider.is_in_group("UpgradePanel"):
					print("Upgrade panel hit — calling interaction")
					var success = collider.call("on_panel_interacted")
					print("Call result:", success)
			else:
				print("click_ray is NOT colliding")
		else:
			print("click_ray is null!")

				
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var collider = click_ray.get_collider()
		if collider:
			if collider.name == "ground":
				var pos = dig_ray.get_collision_point()
				dig_at(pos)

func dig_at(position: Vector3):
	var stats = player_data.get_status()
	#gets a tool that reads/writes/digs voxel data
	var tool = voxel_terrain.get_voxel_tool()
	#telling the tool you want to remove data
	tool.mode = VoxelTool.MODE_REMOVE
	
	#digs a sphere with the radius at the position youre looking at
	var radius = upgrade_manager.get_dig_radius()  # You can make this scale with upgrades later
	if player_data.shovel_energy > 0:
		tool.do_sphere(position, radius)
		dig_count += 1
		player_data.shovel_energy -= 1   # just an example
		if dig_count == 100:
			player_data.water -= 1.0
			dig_count = 0
		
	player_hud.update_status(stats.health, stats.water, stats.shovel_energy, stats.money)

		
		
