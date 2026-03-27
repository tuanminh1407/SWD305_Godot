extends Container

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_OBJECT and data is Label

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if typeof(data) == TYPE_OBJECT and data is Label:
		var parent = data.get_parent()
		if parent:
			parent.remove_child(data)
			
		# Insert based on mouse X position relative to other children
		var drop_index = get_child_count()
		for i in range(get_child_count()):
			var child = get_child(i)
			if at_position.x < child.position.x + (child.size.x / 2):
				drop_index = i
				break
				
		add_child(data)
		move_child(data, drop_index)
