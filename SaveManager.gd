extends Node

var save_path := "user://savegame.json"

func save_game(player_data, upgrade_manager):
	var file = FileAccess.open(save_path, FileAccess.WRITE)
	var pos = player_data.get_parent().global_transform.origin
	var data = {
		"player": {
			"stats": player_data.stats,
			"inventory": player_data.inventory,
			"position": [pos.x, pos.y, pos.z],
		},
		"world": {
			"upgrades": upgrade_manager.upgrades,
		}
	}


	var json = JSON.new()
	var json_string = json.stringify(data)
	file.store_string(json_string)
	file.close()
	print("✅ Game saved to", save_path)

func clear_save():
	var dir := DirAccess.open("user://")
	if dir and dir.file_exists("savegame.json"):
		dir.remove("savegame.json")
		print("🧼 Save file deleted.")
	else:
		print("ℹ️ No save file found to delete.")



func load_game(player_data, upgrade_manager):
	if not FileAccess.file_exists(save_path):
		print("❌ No save file found.")
		return

	var file = FileAccess.open(save_path, FileAccess.READ)
	var json_string = file.get_as_text()
	file.close()

	var json = JSON.new()
	var result = json.parse(json_string)
	if result != OK:
		print("❌ JSON parse error:", json.get_error_message())
		return

	var data = json.get_data()

	player_data.stats = data["player"]["stats"]
	player_data.inventory = data["player"]["inventory"]
	player_data.get_parent().global_transform.origin = Vector3(
		data["player"]["position"][0],
		data["player"]["position"][1],
		data["player"]["position"][2]
	)
	
	# Sanitize stat types
	player_data.stats["dig_count"] = int(player_data.stats["dig_count"])
	player_data.stats["money"] = int(player_data.stats["money"])
	player_data.stats["shovel_energy"] = int(player_data.stats["shovel_energy"])
	player_data.stats["health"] = int(player_data.stats["health"])
	player_data.stats["water"] = float(player_data.stats["water"])
	player_data.stats["dig_radius"] = float(player_data.stats["dig_radius"])
	player_data.stats["dig_cooldown"] = float(player_data.stats["dig_cooldown"])
	player_data.stats["headlight_brightness"] = float(player_data.stats["headlight_brightness"])
	player_data.stats["can_dig"] = bool(player_data.stats["can_dig"])


	upgrade_manager.upgrades = data["world"]["upgrades"]
	print("✅ Game loaded from", save_path)
