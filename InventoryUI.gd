extends Control

@onready var grid = $Panel/GridContainer
@onready var player_data = get_node("/root/World/PlayerData")
@onready var slot_scene = preload("res://InventorySlot.tscn")


var icon_map := {
	"Iron": preload("res://assets/icons/iron.png"),
	"Copper": preload("res://assets/icons/copper.png"),
	"Silver": preload("res://assets/icons/silver.png"),
	"Gold": preload("res://assets/icons/gold.png"),
	"Diamond": preload("res://assets/icons/diamond.png"),
	"Saphire": preload("res://assets/icons/saphire.png"),
	"Ruby": preload("res://assets/icons/ruby.png"),
}

func _ready():
	self.visible = false
	await get_tree().process_frame  # 🔁 ensures all @onready vars are valid
	update_inventory_display()


const MAX_SLOTS = 30
func update_inventory_display():
	# Just to be safe, skip if grid is still null (rare edge case)
	if grid == null:
		return

	for child in grid.get_children():
		child.queue_free()

	var inventory_items = player_data.inventory.keys()

	for i in range(MAX_SLOTS):
		var slot = slot_scene.instantiate()
		await get_tree().process_frame
		
		if i < inventory_items.size():
			var ore_name = inventory_items[i]
			var count = player_data.inventory[ore_name]
			var icon = icon_map.get(ore_name)


			slot.set_item(icon, count)
		else:
			slot.set_item(null, 0)  # Empty slot
		grid.add_child(slot)
