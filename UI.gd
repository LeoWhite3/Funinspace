extends Control

@onready var upgradeUi = $UpgradeUi
@onready var upgrade_manager = get_parent().get_node("UpgradeManager")
@onready var player_data = get_parent().get_node("PlayerData")
@onready var player_hud = get_parent().get_node("Ui/PlayerHUD")
var was_upgrade_ui_open = false

func _ready():
	upgradeUi.visible = false
	update_button_text()
	$UpgradeUi/RadiusButton.pressed.connect(_on_buy_pressed.bind($UpgradeUi/RadiusButton))
	$UpgradeUi/SpeedButton.pressed.connect(_on_buy_pressed.bind($UpgradeUi/SpeedButton))
	$UpgradeUi/LightButton.pressed.connect(_on_buy_pressed.bind($UpgradeUi/LightButton))

func update_from_player_data():
	var stats = player_data.get_status()
	player_hud.update_status(
		stats.health,
		stats.water,
		stats.shovel_energy,
		stats.money
	)

func _process(delta):
	$PlayerHUD.update_status(
		player_data.stats["health"],
		player_data.stats["water"],
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
	var type = ""
	if button.name == "RadiusButton":
		type = "drill"
	elif button.name == "SpeedButton":
		type = "speed"
	elif button.name == "LightButton":
		type = "light"

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

		print(type + " upgraded!")
	else:
		print("Not enough money for " + type + "!")

	update_button_text()
	update_from_player_data()


func _unhandled_input(event):
	if event.is_action_pressed("escape"):  # Escape is usually bound to ui_cancel
		if upgradeUi.visible:
			hide_upgrade_ui()

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
	$UpgradeUi/RadiusButton.text = "Buy - $" + str(radius_cost)
	$UpgradeUi/SpeedButton.text = "Buy - $" + str(speed_cost)
	$UpgradeUi/LightButton.text = "Buy - $" + str(light_cost)
