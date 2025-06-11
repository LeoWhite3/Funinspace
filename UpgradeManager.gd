extends Node

@onready var player_data = get_parent().get_node("PlayerData") # Assign this to your PlayerData node in the editor

var upgrades = {
	"drill": {"level": 0, "base_value": 1.00, "base_cost": 1000, "scale": 0.005},
	"speed": {"level": 0, "base_value": 2.00,  "base_cost": 1000, "scale": 0.005},
	"light": {"level": 0, "base_value": 2.0,  "base_cost": 1000, "scale": 0.005},
	"battery": {"level" : 0, "base_value" : 200.0, "base_cost": 1000, "scale":1.0},
	"recharge":  {"base_value" : 50.0, "base_cost" : 500}
}

func get_upgrade_value(type: String) -> float:
	if type == "recharge":
		return upgrades["recharge"]["base_value"] + player_data.get_stat("curr_battery")
		
	return upgrades[type]["base_value"] + upgrades[type]["level"] * upgrades[type]["scale"]

func get_upgrade_cost(type: String) -> int:
	if type == "recharge":
		return upgrades[type]["base_cost"]
	return upgrades[type]["base_cost"] + upgrades[type]["level"] * 100

func upgrade(type: String):
	var value: float
	if type != "recharge":
		upgrades[type]["level"] += 1
		value = get_upgrade_value(type)
	else:
		value = get_upgrade_value(type)

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
		"battery": 
			player_data.set_stat("max_battery", value)
			print("✅ BATTERY upgraded: battery =", player_data.get_stat("max_battery"))
		"recharge": 
			var current = player_data.get_stat("curr_battery")
			var recharge = upgrades["recharge"]["base_value"]
			var max = player_data.get_stat("max_battery")
			var new_val = min(current + recharge, max)
			player_data.set_stat("curr_battery", new_val)
			print("🔋 Recharge applied: battery =", new_val, "/", max)


func apply_upgrade_effects():
	for type in upgrades.keys():
		match type:
			"drill":
				player_data.set_stat("dig_radius", get_upgrade_value("drill"))
			"speed":
				player_data.set_stat("dig_cooldown", 0.5 / get_upgrade_value("speed"))
			"light":
				player_data.set_stat("headlight_brightness", get_upgrade_value("light"))
			"battery":
				player_data.set_stat("max_battery", get_upgrade_value("battery"))

func update_ui():
	$/root/World/Ui/UpgradeUi/DigRadius/RadiusButton.text = "Buy - $%d" % get_upgrade_cost("drill")
	$/root/World/Ui/UpgradeUi/DigSpeed/SpeedButton.text = "Buy - $%d" % get_upgrade_cost("speed")
	$/root/World/Ui/UpgradeUi/HelmetBrightness/LightButton.text = "Buy - $%d" % get_upgrade_cost("light")
	$/root/World/Ui/UpgradeUi/JetPack/BatteryButton.text = "Buy  - $%d" % get_upgrade_cost("battery")
	$/root/World/Ui/UpgradeUi/Recharge/RechargeButton.text = "Buy  - $%d" % get_upgrade_cost("recharge")
	$"/root/World/Ui/UpgradeUi".queue_redraw()


	
