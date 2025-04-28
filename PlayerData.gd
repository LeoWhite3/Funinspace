extends Node

# Core player stats
var money: int = 1000
var health: int = 100
var water: int = 100
var shovel_energy: int = 100

# Spend logic
func spend(amount: int) -> bool:
	if money >= amount:
		money -= amount
		return true
	return false
	
# Optional: Getter to return a dictionary
func get_status() -> Dictionary:
	return {
		"money": money,
		"health": health,
		"water": water,
		"shovel_energy": shovel_energy
	}
	
