extends StaticBody3D

var click_sound := preload("res://Sounds/UiSounds/Screen/OpenScreen.wav")
@onready var shop_ui = get_parent().get_node("/root/World/Ui/Shop")
@onready var ClickSound = $OpenSound
	
	





func on_panel_interacted():
	if click_sound && shop_ui.visible == false:
		ClickSound.stream = click_sound
		ClickSound.play()
	print("Shop panel activated by raycast.")
	
	get_tree().get_root().get_node("World/Ui").show_shop_ui()
