extends QuestionBase

var flow_container: HFlowContainer

func _do_setup() -> void:
	# Inherits from QuestionBase (VBoxContainer)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 20)
	
	var instr_lbl = Label.new()
	instr_lbl.text = "Cách chơi: Click vào từ mà bạn nghĩ là sai trong câu."
	instr_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr_lbl.modulate = Color.YELLOW
	add_child(instr_lbl)
	
	flow_container = HFlowContainer.new()
	flow_container.custom_minimum_size = Vector2(0, 100)
	flow_container.alignment = FlowContainer.ALIGNMENT_CENTER
	add_child(flow_container)
	
	var raw_data = str(question_data.get("data", ""))
	var words = []
	
	var json = JSON.new()
	if json.parse(raw_data) == OK and typeof(json.data) == TYPE_ARRAY:
		words = json.data
	else:
		# Fallback if not JSON
		words = raw_data.replace("[", "").replace("]", "").replace("\"", "").split(",")
	
	var correct_ans = str(question_data.get("answer", "")).strip_edges()
	
	for i in range(words.size()):
		var w = str(words[i]).strip_edges()
		if w == "": continue
		var btn = Button.new()
		btn.text = w
		btn.add_theme_font_size_override("font_size", 24)
		btn.custom_minimum_size = Vector2(0, 40)
		btn.flat = true 
		flow_container.add_child(btn)
		btn.pressed.connect(func():
			_on_word_selected(btn, w, correct_ans, i)
		)

func _on_word_selected(btn: Button, selected_word: String, correct_word: String, index: int) -> void:
	# Disable all
	for child in flow_container.get_children():
		child.disabled = true
		
	# Check if answer matches the exact text or the index if answer is a number
	var is_correct = false
	if correct_word.is_valid_int() and int(correct_word) == index:
		is_correct = true
	elif selected_word.to_lower() == correct_word.to_lower():
		is_correct = true
		
	if is_correct:
		btn.modulate = Color.GREEN
		btn.flat = false
	else:
		btn.modulate = Color.RED
		btn.flat = false
		for i in range(flow_container.get_child_count()):
			var child = flow_container.get_child(i)
			if (correct_word.is_valid_int() and i == int(correct_word)) or child.text.to_lower() == correct_word.to_lower():
				child.modulate = Color.GREEN
				child.flat = false
				
	submit(is_correct, selected_word)
