extends CanvasLayer

@onready var upgradepopup = $upgradepopup
@onready var upgrade_manager = get_parent().get_node("UpgradeManager")
@onready var player_data = get_parent().get_node("PlayerData")
@onready var player_hud = get_parent().get_node("Ui/PlayerHUD")
var was_upgrade_ui_open = false

func _ready():
	upgradepopup.visible = false
	update_button_text()
	$upgradepopup/upgradelist/BuyDrillButton.pressed.connect(_on_buy_pressed)

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
		player_data.health,
		player_data.water,
		player_data.shovel_energy,
		player_data.money
	)
	update_from_player_data()
	if was_upgrade_ui_open and not upgradepopup.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		was_upgrade_ui_open = false
	#if Input.is_action_just_pressed("ui_upgrade"):
		#upgradepopup.visible = not upgradepopup.visible
		#
		#if upgradepopup.visible:
			#Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		#else:
			#Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func show_upgrade_ui():
	upgradepopup.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	was_upgrade_ui_open = true

func _on_buy_pressed():
	var cost = upgrade_manager.get_drill_upgrade_cost()
	if player_data.spend(cost):
		upgrade_manager.upgrade_drill()
		update_button_text()
		print("Drill upgraded!")
	else:
		print("Not enough money!")

func update_button_text():
	var cost = upgrade_manager.get_drill_upgrade_cost()
	$upgradepopup/upgradelist/BuyDrillButton.text = "Buy - $" + str(cost)
