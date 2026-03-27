extends QuestionBase

func _do_setup() -> void:
	# Inherits from QuestionBase (VBoxContainer)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 15)
	
	var raw_data = str(question_data.get("data", ""))
	var options = []
	var json = JSON.new()
	if json.parse(raw_data) == OK and typeof(json.data) == TYPE_ARRAY:
		options = json.data
	else:
		options = raw_data.split(",")
		
	var correct_ans = str(question_data.get("answer", ""))
	
	for i in range(options.size()):
		var btn = Button.new()
		var opt_text = str(options[i]).strip_edges().replace("\"", "")
		btn.text = opt_text
		btn.custom_minimum_size = Vector2(0, 60)
		add_child(btn)
		
		btn.pressed.connect(func():
			_on_option_selected(btn, opt_text, correct_ans)
		)

func _on_option_selected(btn: Button, selected: String, correct: String) -> void:
	for child in get_children():
		if child is Button:
			child.disabled = true
			
	var is_correct = (selected.to_lower() == correct.to_lower())
	
	if is_correct:
		btn.modulate = Color.GREEN
	else:
		btn.modulate = Color.RED
		# Show the correct answer
		for child in get_children():
			if child is Button and child.text.to_lower() == correct.to_lower():
				child.modulate = Color.GREEN
				
	submit(is_correct, selected)
