extends CanvasLayer

@onready var save_button = $Panel/Save
@onready var reset_button = $Panel/Reset
@onready var quit_button = $Panel/Quit
@onready var player_data = get_node("/root/World/PlayerData")
@onready var upgrade_manager = get_node("/root/World/UpgradeManager")
@onready var voxel_terrain = get_node("/root/World/ground")


func _ready():
	visible = false
	save_button.pressed.connect(_on_save_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _on_save_pressed():
	SaveManager.save_game(player_data, upgrade_manager,voxel_terrain)

func _on_reset_pressed():
	SaveManager.clear_save()
	call_deferred("_reload_clean_scene")


func _reload_clean_scene():
	# Optional: reset any singletons (like clearing player references)
	SaveManager.clear_save()  # If you have one

	# Fully reload scene
	get_tree().reload_current_scene()



func _on_quit_pressed():
	voxel_terrain.save_modified_blocks()
	get_tree().quit()
