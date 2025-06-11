extends Node

@onready var player_data = get_parent().get_node("PlayerData")

var prices := {
	"Iron": 12,
	"Copper": 16,
	"Silver": 35,
	"Gold": 65,
	"Diamond": 180,
	"Saphire": 270,
	"Ruby": 540
}

func can_sell(ore_name: String, amount: int) -> bool:
	return player_data.inventory.get(ore_name, 0) >= amount

func sell_one(ore_name: String):
	if can_sell(ore_name, 1):
		player_data.remove_from_inventory(ore_name, 1)
		player_data.stats["money"] += prices[ore_name]
		print("🪙 Sold 1", ore_name)
		update_ui()


func sell_bulk(ore_name: String):
	if can_sell(ore_name, 5):
		player_data.remove_from_inventory(ore_name, 5)
		player_data.stats["money"] += prices[ore_name] * 5
		print("🪙 Sold 5", ore_name, "- New balance:", player_data.stats["money"])
		update_ui()
	else:
		print("❌ Not enough", ore_name, "to sell bulk (need 5).")

func update_ui():
	get_node("/root/World/Ui/Inventory").update_inventory_display()
	pass
