extends Label

var word_text: String = ""

func setup() -> void:
	text = word_text
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_font_size_override("font_size", 24)
	
	# Add some padding and background
	var sb = StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	sb.set_corner_radius_all(5)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 5
	sb.content_margin_bottom = 5
	add_theme_stylebox_override("normal", sb)

func _get_drag_data(_at_position: Vector2):
	var preview_label = Label.new()
	preview_label.text = text
	preview_label.add_theme_font_size_override("font_size", 24)
	
	var style = get_theme_stylebox("normal").duplicate()
	style.bg_color.a = 0.5
	preview_label.add_theme_stylebox_override("normal", style)
	
	var preview_ctl = Control.new()
	preview_ctl.add_child(preview_label)
	preview_label.position = -preview_label.get_minimum_size() / 2
	
	set_drag_preview(preview_ctl)
	
	return self
