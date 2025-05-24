extends StaticBody3D

var ore_data: Dictionary
var hit_count := 0

func _ready():
	var mesh = $MeshInstance3D
	var material = mesh.get_active_material(0).duplicate()

	if material is ShaderMaterial:
		material.set_shader_parameter("ore_color", ore_data.get("color", Color(1, 1, 1)))
		material.set_shader_parameter("sparkle_intensity", ore_data.get("sparkle", 0.0))
		mesh.set_surface_override_material(0, material)

	print("💎 Ore type:", ore_data.get("name", "unknown"))

func on_hit():
	hit_count += 1
	print("🪓 Hit ore:", ore_data.name, "hits:", hit_count)
	if hit_count >= 2:
		collect_ore()

func collect_ore():
	print("✅ Collected:", ore_data.name)
	queue_free()
	# Optional: Add to inventory system
	if get_node_or_null("/root/World/PlayerData") and get_node("/root/World/PlayerData").has_method("add_to_inventory"):
		get_node("/root/World/PlayerData").add_to_inventory(ore_data)
