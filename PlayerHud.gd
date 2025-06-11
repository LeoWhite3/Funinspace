extends Control

@onready var health_bar = $HealthBar
@onready var battery_bar = $BatteryBar
@onready var shovel_bar = $EnergyBar
@onready var money_label = $Money


func update_status(health: int, battery: int, shovel_energy: int, money: int):
	health_bar.value = health
	battery_bar.value = battery
	shovel_bar.value = shovel_energy
	money_label.text = "$" + str(money)
