extends Area3D

@export var lift_force: float = 7.0  # upward velocity applied
@export var active: bool = true

func _physics_process(delta):
	for body in get_overlapping_bodies():
		if active and body.is_in_group("player"):
			body.velocity.y = lift_force
