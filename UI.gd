extends Control

@onready var upgradeUi = $UpgradeUi
@onready var shopUi = $Shop
@onready var upgrade_manager = get_parent().get_node("UpgradeManager")
@onready var player_data = get_parent().get_node("PlayerData")
@onready var player_hud = get_parent().get_node("Ui/PlayerHUD")
var was_upgrade_ui_open = false

@onready var player_sound = get_node("/root/World/player/PlayerSound")

var sell_sound = preload("res://Sounds/UiSounds/Screen/UpgradeClick.wav")

func _ready():
	upgradeUi.visible = false
	shopUi.visible = false
	update_button_text()
	
	# Iron
	$Shop/IronPanel/SellIron.pressed.connect(sell_one_pressed.bind("Iron"))
	$Shop/IronPanel/BulkIron.pressed.connect(sell_bulk_pressed.bind("Iron"))

	# Copper
	$Shop/CopperPanel/SellCopper.pressed.connect(sell_one_pressed.bind("Copper"))
	$Shop/CopperPanel/BulkCopper.pressed.connect(sell_bulk_pressed.bind("Copper"))

	# Silver
	$Shop/SilverPanel/SellSilver.pressed.connect(sell_one_pressed.bind("Silver"))
	$Shop/SilverPanel/BulkSilver.pressed.connect(sell_bulk_pressed.bind("Silver"))

	# Gold
	$Shop/GoldPanel/SellGold.pressed.connect(sell_one_pressed.bind("Gold"))
	$Shop/GoldPanel/BulkGold.pressed.connect(sell_bulk_pressed.bind("Gold"))

	# Diamond
	$Shop/DiamondPanel/SellDiamond.pressed.connect(sell_one_pressed.bind("Diamond"))
	$Shop/DiamondPanel/BulkDiamond.pressed.connect(sell_bulk_pressed.bind("Diamond"))

	# Saphire
	$Shop/SaphirePanel/SellSaphire.pressed.connect(sell_one_pressed.bind("Saphire"))
	$Shop/SaphirePanel/BulkSaphire.pressed.connect(sell_bulk_pressed.bind("Saphire"))

	# Ruby
	$Shop/RubyPanel/SellRuby.pressed.connect(sell_one_pressed.bind("Ruby"))
	$Shop/RubyPanel/BulkRuby.pressed.connect(sell_bulk_pressed.bind("Ruby"))



	$UpgradeUi/DigRadius/RadiusButton.pressed.connect(_on_buy_pressed.bind($UpgradeUi/DigRadius/RadiusButton))
	$UpgradeUi/DigSpeed/SpeedButton.pressed.connect(_on_buy_pressed.bind($UpgradeUi/DigSpeed/SpeedButton))
	$UpgradeUi/HelmetBrightness/LightButton.pressed.connect(_on_buy_pressed.bind($UpgradeUi/HelmetBrightness/LightButton))
	$UpgradeUi/JetPack/BatteryButton.pressed.connect(_on_buy_pressed.bind($UpgradeUi/JetPack/BatteryButton))
	$UpgradeUi/Recharge/RechargeButton.pressed.connect(_on_buy_pressed.bind($UpgradeUi/Recharge/RechargeButton))
func update_from_player_data():
	var stats = player_data.get_status()
	player_hud.update_status(
		stats.health,
		stats.curr_battery,
		stats.shovel_energy,
		stats.money
	)

func _process(delta):
	$PlayerHUD.update_status(
		player_data.stats["health"],
		player_data.stats["curr_battery"],
		player_data.stats["shovel_energy"],
		player_data.stats["money"]
	)
	update_from_player_data()
	if was_upgrade_ui_open and not upgradeUi.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		was_upgrade_ui_open = false
	#if Input.is_action_just_pressed("ui_upgrade"):
		#upgradepopup.visible = not upgradepopup.visible
		#
		#if upgradepopup.visible:
			#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		#else:
			#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
func _on_buy_pressed(button):
	player_sound.stream = sell_sound
	player_sound.play()
	var type = ""
	if button.name == "RadiusButton":
		type = "drill"
	elif button.name == "SpeedButton":
		type = "speed"
	elif button.name == "LightButton":
		type = "light"
	elif button.name == "BatteryButton":
		type = "battery"
	elif button.name == "RechargeButton":
		type = "recharge"
	

	var cost = upgrade_manager.get_upgrade_cost(type)
	if player_data.spend(cost):
		upgrade_manager.upgrade(type)

		# Sync values back
		var value = upgrade_manager.get_upgrade_value(type)
		match type:
			"drill":
				player_data.set_stat("dig_radius", value)
			"speed":
				player_data.set_stat("dig_speed", value)
				get_node("/root/World/player").set_dig_speed(value)
			"light":
				get_node("/root/World/player").set_light_brightness(value)
			"battery" : 
				player_data.set_stat("max_battery", value)

		print(type + " upgraded!")
	else:
		print("Not enough money for " + type + "!")

	update_button_text()
	update_from_player_data()

@onready var shop_manager = get_parent().get_node("ShopManager")

func sell_one_pressed(ore_name: String):
	player_sound.stream = sell_sound
	player_sound.play()
	shop_manager.sell_one(ore_name)
	update_from_player_data()

func sell_bulk_pressed(ore_name: String):
	player_sound.stream = sell_sound
	player_sound.play()
	shop_manager.sell_bulk(ore_name)
	update_from_player_data()

func _unhandled_input(event):
	if event.is_action_pressed("escape"):  # Escape is usually bound to ui_cancel
		if upgradeUi.visible:
			hide_upgrade_ui()
		if shopUi.visible:
			hide_shop_ui()
			
func show_shop_ui():
	$Shop.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_node("/root/World/player").input_enabled = false

func hide_shop_ui():
	$Shop.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_node("/root/World/player").input_enabled = true

# When showing UI
func show_upgrade_ui():
	upgradeUi.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_node("/root/World/player").input_enabled = false  # Disable camera rotation
	was_upgrade_ui_open = true

func hide_upgrade_ui():
	upgradeUi.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_node("/root/World/player").input_enabled = true   # Re-enable camera rotation
	was_upgrade_ui_open = false

func update_button_text():
	var radius_cost = upgrade_manager.get_upgrade_cost("drill")
	var speed_cost = upgrade_manager.get_upgrade_cost("speed")
	var light_cost = upgrade_manager.get_upgrade_cost("light")
	var recharge_cost = upgrade_manager.get_upgrade_cost("recharge")
	var battery_cost = upgrade_manager.get_upgrade_cost("battery")
	$UpgradeUi/DigRadius/RadiusButton.text = "Buy - $" + str(radius_cost)
	$UpgradeUi/DigSpeed/SpeedButton.text = "Buy - $" + str(speed_cost)
	$UpgradeUi/HelmetBrightness/LightButton.text = "Buy - $" + str(light_cost)
	$UpgradeUi/JetPack/BatteryButton.text = "Buy - $" + str(battery_cost)
	$UpgradeUi/Recharge/RechargeButton.text = "Buy - $" + str(recharge_cost)
