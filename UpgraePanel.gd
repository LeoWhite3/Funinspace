extends StaticBody3D

func on_panel_interacted():
	print("Upgrade panel activated by raycast.")
	get_tree().get_root().get_node("World/Ui").show_upgrade_ui()
