extends Node

var drill_level := 0
var base_radius = .65
var drill_base_cost := 1000

func get_dig_radius() ->float:
	return base_radius + (drill_level * .005)
	
func get_drill_upgrade_cost() -> int:
	return drill_base_cost + drill_level * 100

func upgrade_drill():
	drill_level += 1
	
