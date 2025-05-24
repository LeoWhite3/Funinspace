extends Node

var stats := {
	"money": 100000,
	"health": 100,
	"water": 100,
	"shovel_energy": 100,
	"dig_radius": 1.00,
	"headlight_brightness": 2.0,
	"dig_cooldown": .00001,
	"dig_count": 0,
	"can_dig" : true
}

var inventory := {}

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
