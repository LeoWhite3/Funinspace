extends StaticBody3D

var ore_data: Dictionary
var ore_type_name := ""
var hit_count := 0

var hit_sounds := [
	preload("res://Sounds/OreSounds/HitSounds/OreHit1.mp3"),
	preload("res://Sounds/OreSounds/HitSounds/OreHit2.mp3")

]
var Orebreak := preload("res://Sounds/OreSounds/Collection/CollectOre2.mp3")
@onready var hit_sound = $HitSound
@onready var collect_sound = $CollectSound
@onready var break_sound = $OreBreak

var collect_sounds := [
	preload("res://Sounds/OreSounds/Collection/CollectOre1.mp3"),
	preload("res://Sounds/OreSounds/Collection/CollectOre2.mp3")
]
	
	


func _ready():
	apply_ore_visuals()
	


func on_hit():
	hit_count += 1
	print("🪓 Hit ore:", ore_data.name, "hits:", hit_count)

	if hit_sound and hit_sounds.size() > 0:
		var random_sound = hit_sounds[randi() % hit_sounds.size()]
		hit_sound.stream = random_sound
		hit_sound.play()

	if hit_count > 2:
		if collect_sound and collect_sounds.size() > 0:
			var random_sound = collect_sounds[randi() % collect_sounds.size()]
			hit_sound.stream = random_sound
			hit_sound.play()
		collect_ore()

func collect_ore():
	print("✅ Collected:", ore_type_name)
		
	queue_free()
	if get_node_or_null("/root/World/PlayerData") and get_node("/root/World/PlayerData").has_method("add_to_inventory"):
		get_node("/root/World/PlayerData").add_to_inventory(ore_data)
		get_node("/root/World/Ui/Inventory").update_inventory_display()

func set_ore_type(data: Dictionary):
	ore_data = data
	ore_type_name = data.get("name", "")
	if is_inside_tree():
		apply_ore_visuals()

func apply_ore_visuals():
	var mesh = $MeshInstance3D
	var material = mesh.get_active_material(0).duplicate()
	if material is ShaderMaterial:
		material.set_shader_parameter("ore_color", ore_data.get("color", Color(1, 1, 1)))
		material.set_shader_parameter("sparkle_intensity", ore_data.get("sparkle", 0.0))
		mesh.set_surface_override_material(0, material)

func is_ore():
	return true
