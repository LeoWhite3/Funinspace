extends Node

var save_path := "res://SavedGame/savegame.json"

# 🔍 Safely get the player node when needed
func get_player() -> Node:
	var p := get_node_or_null("/root/World/player")
	if not p:
		print("❌ Could not find player node")
	return p

# 🔍 Safely get the voxel terrain node when needed
func get_voxel_terrain() -> Node:
	var vt := get_node_or_null("/root/World/ground")
	if not vt:
		print("❌ Could not find voxel terrain node")
	return vt

func save_game(player_data, upgrade_manager, _unused):
	var player = get_player()
	var voxel_terrain = get_voxel_terrain()
	if not is_instance_valid(player) or not is_instance_valid(voxel_terrain):
		print("❌ Save aborted: missing references")
		return

	var ores := []
	for child in get_tree().current_scene.get_children():
		if child.has_method("is_ore") and child.is_ore():
			ores.append({
				"position": child.global_position,
				"ore_type": child.ore_type_name
			})


	var glorps := []
	for child in get_tree().current_scene.get_children():
		if child.name.begins_with("Glorp") or child.is_in_group("Enemy"):  # Adjust if needed
			glorps.append({
				"position": child.global_position,
				"health": child.current_health,
				"state": child.current_state,
				# Add other properties you want to persist (e.g., patrol_center, depth, etc.)
			})


	var file = FileAccess.open(save_path, FileAccess.WRITE)
	print("📁 Saving to: ", ProjectSettings.globalize_path(save_path))

	var pos = player.global_transform.origin
	var data = {
		"player": {
			"stats": player_data.stats,
			"inventory": player_data.inventory,
			"position": [pos.x, pos.y, pos.z],
		},
		"world": {
			"upgrades": upgrade_manager.upgrades,
			"ores": ores,
			"glorps": glorps
		}
	}

	var json = JSON.new()
	file.store_string(json.stringify(data))
	file.close()
	print("✅ Game saved to", save_path)

	# 💾 Save terrain
	voxel_terrain.save_modified_blocks()

func clear_save():
	var dir := DirAccess.open("res://SavedGame/")
	var voxel_terrain = get_voxel_terrain()

	if dir:
		if dir.file_exists("savegame.json"):
			dir.remove("savegame.json")
			print("🧼 Save file deleted.")

		if dir.file_exists("terrain_save.db"):
			if voxel_terrain:
				voxel_terrain.stream = null
			dir.remove("terrain_save.db")
			print("🧼 Terrain save deleted.")

func load_game(player_data, upgrade_manager):
	var player = get_player()
	var voxel_terrain = get_voxel_terrain()
	if not is_instance_valid(player) or not FileAccess.file_exists(save_path):
		print("❌ Cannot load game: missing player or file")
		return

	var file = FileAccess.open(save_path, FileAccess.READ)
	var result = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(result) != TYPE_DICTIONARY:
		print("❌ Failed to parse save file.")
		return

	if result.has("player"):
		var player_info = result["player"]
		player_data.stats = player_info.get("stats", {})
		player_data.inventory = player_info.get("inventory", {})
		var pos = player_info.get("position", [0, 0, 0])
		player.global_transform.origin = Vector3(pos[0], pos[1], pos[2])
		print("📍 Loaded player at:", pos)

	if result["world"].has("upgrades"):
		upgrade_manager.upgrades = result["world"]["upgrades"]
		print("🔧 Upgrades restored")

	if result["world"].has("ores"):
		for child in get_tree().current_scene.get_children():
			if child.has_method("is_ore") and child.is_ore():
				child.queue_free()

		var ore_scene = preload("res://Ore.tscn")
		for ore_entry in result["world"]["ores"]:
			var ore = ore_scene.instantiate()
			var pos = ore_entry["position"]
			if typeof(pos) == TYPE_ARRAY and pos.size() == 3:
				ore.global_position = Vector3(pos[0], pos[1], pos[2])
			elif typeof(pos) == TYPE_VECTOR3:
				ore.global_position = pos
			else:
				print("⚠️ Invalid ore position:", pos)
				continue
			ore.set_ore_type(get_ore_type_by_name(ore_entry["ore_type"]))
			get_tree().current_scene.add_child(ore)
			
	#if result["world"].has("glorps"):
	## Clean up existing Glorps
		#for child in get_tree().current_scene.get_children():
			#if child.name.begins_with("Glorp") or child.is_in_group("Enemy"):
				#child.queue_free()
#
		#var glorp_scene = preload("res://Glorp.tscn")
		#for g in result["world"]["glorps"]:
			#var glorp = glorp_scene.instantiate()
			#var pos = g["position"]
			#if typeof(pos) == TYPE_VECTOR3:
				#glorp.global_position = pos
			#elif typeof(pos) == TYPE_ARRAY and pos.size() == 3:
				#glorp.global_position = Vector3(pos[0], pos[1], pos[2])
			#else:
				#print("⚠️ Invalid Glorp position format:", pos)
			#glorp.current_health = g.get("health", glorp.max_health)
			#glorp.current_state = g.get("state", glorp.State.WANDERING)
			#get_tree().current_scene.add_child(glorp)


	print("🪨 Loaded", result["world"]["ores"].size(), "ores")

func get_ore_type_by_name(name: String) -> Dictionary:
	var cave_spawner = get_node_or_null("/root/World/CaveSpawner")
	if cave_spawner and cave_spawner.has("ore_types"):
		for ore in cave_spawner.ore_types:
			if ore["name"] == name:
				return ore
	print("⚠️ Ore type not found for:", name)
	return {}
