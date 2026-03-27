extends QuestionBase

@onready var container = VBoxContainer.new()
var input_field: LineEdit

func _do_setup() -> void:
	add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	input_field = LineEdit.new()
	input_field.placeholder_text = "Nhập câu trả lời..."
	input_field.custom_minimum_size = Vector2(0, 50)
	input_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	container.add_child(input_field)
	
	var submit_btn = Button.new()
	submit_btn.text = "Xác nhận"
	submit_btn.custom_minimum_size = Vector2(0, 50)
	container.add_child(submit_btn)
	
	submit_btn.pressed.connect(_on_submit_pressed)
	input_field.text_submitted.connect(func(_text): _on_submit_pressed())

func _on_submit_pressed() -> void:
	var user_ans = input_field.text.strip_edges()
	if user_ans.is_empty():
		return
		
	input_field.editable = false
	var btn = container.get_child(1) # submit_btn
	btn.disabled = true
	
	var correct_ans_str = str(question_data.get("answer", "")).strip_edges()
	var is_correct = (user_ans.to_lower() == correct_ans_str.to_lower())
	
	if is_correct:
		input_field.modulate = Color.GREEN
	else:
		input_field.modulate = Color.RED
		var lbl = Label.new()
		lbl.text = "Đáp án đúng: " + correct_ans_str
		lbl.modulate = Color.GREEN
		container.add_child(lbl)
		
	submit(is_correct, user_ans)
