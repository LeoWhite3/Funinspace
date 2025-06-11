extends Panel

@onready var icon: TextureRect = $Icon
@onready var count_label: Label = $Count


func set_item(texture: Texture, count: int):
	
	if icon == null or count_label == null:
		await ready


	if icon:
		icon.texture = texture
		icon.visible = true  # Force visible for test


	if count_label:
		if count > 0:
			count_label.text = "x" + str(count)
		else:
			count_label.text = ""
