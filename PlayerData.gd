extends Node

var stats := {
	"money": 100000.0,
	"health": 100.0,
	"max_battery" : 200.0,
	"curr_battery": 100000000.0,
	"shovel_energy": 100,
	"dig_radius": 1.00,
	"headlight_brightness": 2.0,
	"dig_cooldown": .00001,
	"dig_count": 0,
	"can_dig" : true
}

var original_defaults := {
	"health": 100.0,
	"curr_battery": 100000000.0,
	"shovel_energy": 100,
	"dig_count": 0,
	"can_dig": true
}

var inventory := {}

@onready var Ui = get_parent().get_node("Ui")
func reload_from_save():
	var save_path = "res://SavedGame/savegame.json"
	if not FileAccess.file_exists(save_path):
		print("⚠️ No save file found.")
		return

	var file = FileAccess.open(save_path, FileAccess.READ)
	var content = file.get_as_text()
	file.close()

	var result = JSON.parse_string(content)
	if typeof(result) != TYPE_DICTIONARY or not result.has("player"):
		print("❌ Save data invalid.")
		return

	var saved_stats = result["player"].get("stats", {})
	var saved_inventory = result["player"].get("inventory", {})
	stats = saved_stats
	# Override only selected stats with saved versions
	for key in original_defaults.keys():
		stats[key] = original_defaults[key]
	
	
	print(stats)
	# Restore inventory completely
	inventory = {}
	Ui.update_from_player_data()
	print("✅ Player stats and inventory reloaded from save.")


func remove_from_inventory(ore_name: String, amount: int = 1):
	if inventory.has(ore_name):
		inventory[ore_name] -= amount
		if inventory[ore_name] <= 0:
			inventory.erase(ore_name)  # ⬅️ Automatically free the slot

func add_to_inventory(ore: Dictionary):
	var ore_name = ore.get("name", "Unknown")
	if not inventory.has(ore_name):
		inventory[ore_name] = 0
	inventory[ore_name] += 1
	print("📦 Inventory updated:", inventory)

func spend(amount: int) -> bool:
	if stats["money"] >= amount:
		stats["money"] -= amount
		return true
	return false

func get_status() -> Dictionary:
	return stats.duplicate()

func get_stat(key: String) -> Variant:
	return stats.get(key, null)

func set_stat(key: String, value: Variant) -> void:
	if stats.has(key):
		stats[key] = value
