extends Node

var stats := {
	"money": 100000,
	"health": 100,
	"water": 100,
	"shovel_energy": 100,
	"dig_radius": 0.45,
	"headlight_brightness": 1.0,
	"dig_cooldown": 1.0,
	"dig_count": 0,
	"can_dig" : true
}

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
