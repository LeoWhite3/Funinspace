extends Area3D

@export var health := 3
@onready var mesh = $MeshInstance3D

func _ready():
	mesh = get_node("MeshInstance3D")  # Make sure mesh is a child

func mine():
	health -= 1
	print("Ore hit! Remaining: ", health)
	if health <= 0:
		queue_free()  # Remove ore
