extends CharacterBody3D

# Movement and behavior settings
@export var speed := 3.0
@export var chase_speed := 5.0
@export var dig_delay := 1.5
@export var wander_interval := 3.0
@export var chase_distance := 40.0
@export var attack_distance := 3.0
@export var wander_radius := 15.0
@export var gravity := 9.8
@export var dig_radius := 1.0
@export var vertical_follow_speed := 2.0

# Health and combat settings
@export var max_health := 100.0
@export var attack_damage := 5.0
@export var attack_cooldown := 2.0


# Node references
@onready var player = get_node("/root/World/player")
@onready var voxel_terrain = get_node("/root/World/ground")
@onready var detection_area = $DetectionArea3D
@onready var attack_area = $AttackArea3D
@onready var head_node = $Head 

# State variables
var current_health: float
var target_player := false
var can_attack := true
var dig_timer := 0.0
var wander_timer := 0.0
var attack_timer := 0.0
var wander_target := Vector3.ZERO
var patrol_center := Vector3.ZERO
var patrol_radius := 15.0

# State enum for cleaner logic
enum State {
	WANDERING,
	CHASING,
	ATTACKING,
	DIGGING
}

@onready var glorp_sound = $Glorp

var glorp_damage_sounds := [
	preload("res://Sounds/AttackSounds/Player/PlayerHitGlorp.mp3"),
	preload("res://Sounds/AttackSounds/Player/PlayerHitGlorp1.mp3"),
	preload("res://Sounds/AttackSounds/Player/PlayerHitGlorp2.wav"),
	preload("res://Sounds/AttackSounds/Player/PlayerHitGlorp3.mp3"),
	preload("res://Sounds/AttackSounds/Player/PlayerHitGlorp4.mp3"),

]


var current_state := State.WANDERING

func _ready():
	add_to_group("Enemy")
	current_health = max_health
	patrol_center = global_position  # Set initial patrol area
	
	# Connect area signals
	detection_area.body_entered.connect(_on_detection_area_entered)
	detection_area.body_exited.connect(_on_detection_area_exited)
	attack_area.body_entered.connect(_on_attack_area_entered)
	attack_area.body_exited.connect(_on_attack_area_exited)
	
	set_new_wander_target()

func _physics_process(delta):
	if not voxel_terrain or current_health <= 0:
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = max(velocity.y, 0.0)
	
	# Update timers
	dig_timer = max(0, dig_timer - delta)
	attack_timer = max(0, attack_timer - delta)
	
	# State machine
	match current_state:
		State.WANDERING:
			handle_wandering(delta)
		State.CHASING:
			handle_chasing(delta)
		State.ATTACKING:
			handle_attacking(delta)
		State.DIGGING:
			handle_digging(delta)
	
	move_and_slide()

func handle_wandering(delta):
	wander_timer -= delta
	if wander_timer <= 0:
		set_new_wander_target()
		wander_timer = wander_interval
	
	var direction = (wander_target - global_position)
	direction.y = 0  # Don't move vertically when wandering
	direction = direction.normalized()
	
	velocity.x = direction.x * speed * 0.5
	velocity.z = direction.z * speed * 0.5
	
	# Check if we need to dig while wandering
	if should_dig_to_target(wander_target):
		current_state = State.DIGGING

func handle_chasing(delta):
	if not player:
		current_state = State.WANDERING
		return
	
	var to_player = player.global_position - global_position
	var distance_to_player = to_player.length()
	
	# Rotate head to look at player
	look_at_player()
	
	# Check if we should attack
	if distance_to_player <= attack_distance and can_attack:
		current_state = State.ATTACKING
		return
	
	# Calculate movement direction (including vertical)
	var target_position = player.global_position
	var direction = (target_position - global_position).normalized()
	
	# Horizontal movement
	velocity.x = direction.x * chase_speed
	velocity.z = direction.z * chase_speed
	
	# Vertical movement (digging up/down to follow player)
	var vertical_distance = target_position.y - global_position.y
	if abs(vertical_distance) > 2.0:  # Only adjust vertically if significant difference
		velocity.y += direction.y * vertical_follow_speed
	
	# Check for obstacles
	if should_dig_to_target(target_position):
		current_state = State.DIGGING

func handle_attacking(delta):
	if not player:
		current_state = State.WANDERING
		return
	
	var distance_to_player = (player.global_position - global_position).length()
	
	# Stop moving when attacking
	velocity.x = 0
	velocity.z = 0
	
	# Look at player
	look_at_player()
	
	# Attack if cooldown is ready
	if attack_timer <= 0:
		perform_attack()
		attack_timer = attack_cooldown
	
	# Return to chasing if player is too far
	if distance_to_player > attack_distance:
		current_state = State.CHASING

func handle_digging(delta):
	if dig_timer <= 0:
		var target_pos = player.global_position if current_state == State.CHASING else wander_target
		dig_towards_target(target_pos)
		dig_timer = dig_delay
		
		# Return to appropriate state after digging
		if target_player:
			current_state = State.CHASING
		else:
			current_state = State.WANDERING

func should_dig_to_target(target_pos: Vector3) -> bool:
	var space = get_world_3d().direct_space_state
	var ray_params = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, 0.5, 0),  # Start slightly above ground
		target_pos
	)
	ray_params.exclude = [self]  # Don't hit ourselves
	
	var result = space.intersect_ray(ray_params)
	return result and result.collider != player

func dig_towards_target(target_pos: Vector3):
	if not voxel_terrain:
		return
	
	var direction = (target_pos - global_position).normalized()
	var dig_position = global_position + direction * 1.0 # Dig a bit ahead
	
	var tool = voxel_terrain.get_voxel_tool()
	tool.mode = VoxelTool.MODE_REMOVE
	var aabb = AABB(dig_position - Vector3.ONE * dig_radius, Vector3.ONE * dig_radius * 2)
	if tool.is_area_editable(aabb):
		tool.do_sphere(dig_position, dig_radius)

	
func look_at_player():
	if not player or not head_node:
		return
	
	var target_pos = player.global_position
	target_pos.y = head_node.global_position.y  # Keep head level
	head_node.look_at(target_pos, Vector3.UP)

func perform_attack():
	if not player:
		return
	
	print("⚔️ Glorp attacks!")
	
	# Deal damage to player if they have a take_damage method
	if player.has_method("take_damage"):
		player.take_damage(attack_damage)
	
	# Add visual/audio effects here
	# You could also add a brief stun or knockback effect

func take_damage(amount: float):
	current_health = max(0, current_health - amount)
	print("💔 Glorp takes ", amount, " damage! Health: ", current_health)
	
	if glorp_sound and glorp_damage_sounds.size() > 0:
		var random_sound = glorp_damage_sounds[randi() % glorp_damage_sounds.size()]
		glorp_sound.stream = random_sound
		glorp_sound.play()
	
	# Add damage feedback (flash red, play sound, etc.)
	
	if current_health <= 0:
		die()

func die():
	print("💀 Glorp has been defeated!")
	# Add death effects here (particles, sound, etc.)
	# Drop loot, give experience, etc.
	queue_free()

func heal(amount: float):
	current_health = min(max_health, current_health + amount)

func set_new_wander_target():
	var offset = Vector3(
		randf_range(-patrol_radius, patrol_radius),
		randf_range(-3.0, 3.0),  # Allow more vertical wandering
		randf_range(-patrol_radius, patrol_radius)
	)
	wander_target = patrol_center + offset

# Cave spawner calls this to set patrol area
func set_cave_patrol_area(center: Vector3, radius: float):
	patrol_center = center
	patrol_radius = radius
	set_new_wander_target()

# Cave spawner calls this to scale difficulty
func set_depth_scaling(depth: float):
	var depth_multiplier = 1.0 + (depth / 50.0)  # +100% stats per 50 units deep
	max_health *= depth_multiplier
	current_health = max_health
	attack_damage *= depth_multiplier
	speed *= min(1.5, depth_multiplier * 0.5)  # Cap speed increase

# Signal handlers
func _on_detection_area_entered(body: Node3D):
	if body.name == "player" or body.is_in_group("Player"):
		print("👀 Glorp detected player")
		alert_nearby_enemies()
		target_player = true
		current_state = State.CHASING

func _on_detection_area_exited(body: Node3D):
	if body.name == "player" or body.is_in_group("Player"):
		print("🚪 Player left Glorp detection zone")
		target_player = false
		current_state = State.WANDERING
		set_new_wander_target()

func _on_attack_area_entered(body: Node3D):
	if body.name == "player" or body.is_in_group("Player"):
		can_attack = true

func _on_attack_area_exited(body: Node3D):
	if body.name == "player" or body.is_in_group("Player"):
		can_attack = false
	if body.name == "player" or body.is_in_group("Player"):
		can_attack = false

func alert_nearby_enemies():
	for node in get_tree().get_nodes_in_group("Enemy"):
		if node != self and (node.global_position.distance_to(global_position) < 20.0):
			node.target_player = true
			node.current_state = State.CHASING
			print("📣 Alerted another Glorp!")
