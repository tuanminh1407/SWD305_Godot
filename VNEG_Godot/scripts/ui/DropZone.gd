extends HFlowContainer

func _can_drop_data(at_position: Vector2, data) -> bool:
	return data is Label and data.has_method("setup")

func _drop_data(at_position: Vector2, data) -> void:
	if data.get_parent():
		data.get_parent().remove_child(data)
	
	# Calculate where to insert based on mouse position
	var insert_index = -1
	for i in range(get_child_count()):
		var child = get_child(i)
		if at_position.x < (child.position.x + child.size.x / 2):
			insert_index = i
			break
	
	if insert_index == -1:
		add_child(data)
	else:
		add_child(data)
		move_child(data, insert_index)

	# Small visual feedback if it's the target zone
	if name == "TargetZone":
		modulate = Color.WHITE
