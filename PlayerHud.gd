extends Control

@onready var health_bar = $HealthBar
@onready var water_bar = $WaterBar
@onready var shovel_bar = $EnergyBar
@onready var money_label = $Money


func update_status(health: int, water: int, shovel_energy: int, money: int):
	health_bar.value = health
	water_bar.value = water
	shovel_bar.value = shovel_energy
	money_label.text = "$" + str(money)
