extends StaticBody3D
var click_sound := preload("res://Sounds/UiSounds/Screen/OpenScreen.wav")
@onready var ClickSound = $OpenSound
@onready var upgrade_ui = get_parent().get_node("/root/World/Ui/UpgradeUi")

func on_panel_interacted():
	if click_sound && upgrade_ui.visible == false:
		ClickSound.stream = click_sound
		ClickSound.play()
	get_tree().get_root().get_node("World/Ui").show_upgrade_ui()
