extends Node

@onready var player_data = get_parent().get_node("PlayerData") # Assign this to your PlayerData node in the editor

var upgrades = {
	"drill": {"level": 0, "base_value": 0.65, "base_cost": 1000, "scale": 0.005},
	"speed": {"level": 0, "base_value": 1.0,  "base_cost": 1000, "scale": 0.005},
	"light": {"level": 0, "base_value": 1.0,  "base_cost": 1000, "scale": 0.005}
}

func get_upgrade_value(type: String) -> float:
	return upgrades[type]["base_value"] + upgrades[type]["level"] * upgrades[type]["scale"]

func get_upgrade_cost(type: String) -> int:
	return upgrades[type]["base_cost"] + upgrades[type]["level"] * 100

func upgrade(type: String):
	upgrades[type]["level"] += 1
	var value = get_upgrade_value(type)

	match type:
		"drill":
			player_data.set_stat("dig_radius", value)
			print("✅ DRILL upgraded: radius =", player_data.get_stat("dig_radius"))

		"speed":
			var cooldown = 0.5 / value
			player_data.set_stat("dig_cooldown", cooldown)
			print("✅ SPEED upgraded: cooldown =", player_data.get_stat("dig_cooldown"))

		"light":
			player_data.set_stat("headlight_brightness", value)
			print("✅ LIGHT upgraded: brightness =", player_data.get_stat("headlight_brightness"))



	
