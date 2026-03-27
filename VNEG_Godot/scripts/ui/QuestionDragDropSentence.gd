extends QuestionBase

var word_bank: HFlowContainer
var target_zone: HFlowContainer
var submit_btn: Button

func _do_setup() -> void:
	# Inherits from QuestionBase (VBoxContainer)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 30)
	
	var instr = Label.new()
	instr.text = "Kéo các từ vào ô bên dưới để sắp xếp thành câu đúng:"
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.modulate = Color.YELLOW
	add_child(instr)
	
	# Target Zone (Where words are dropped)
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 80)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.1, 0.1, 0.1, 0.5)
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color.WHITE
	panel.add_theme_stylebox_override("panel", panel_style)
	
	target_zone = HFlowContainer.new()
	target_zone.name = "TargetZone"
	target_zone.custom_minimum_size = Vector2(0, 60)
	target_zone.alignment = FlowContainer.ALIGNMENT_CENTER
	# Set script for target_zone to handle drops
	target_zone.set_script(load("res://scripts/ui/DropZone.gd"))
	
	panel.add_child(target_zone)
	add_child(panel)
	
	# Word Bank (Initial words)
	word_bank = HFlowContainer.new()
	word_bank.name = "WordBank"
	word_bank.custom_minimum_size = Vector2(0, 100)
	word_bank.alignment = FlowContainer.ALIGNMENT_CENTER
	# Now word_bank is also a drop zone to allow dragging back
	word_bank.set_script(load("res://scripts/ui/DropZone.gd"))
	add_child(word_bank)
	
	submit_btn = Button.new()
	submit_btn.text = "Xác nhận"
	submit_btn.custom_minimum_size = Vector2(200, 60)
	add_child(submit_btn)
	submit_btn.pressed.connect(_on_submit_pressed)
	
	_setup_words()

func _setup_words() -> void:
	var raw = str(question_data.get("data", ""))
	var words = []
	
	var json = JSON.new()
	if json.parse(raw) == OK and typeof(json.data) == TYPE_ARRAY:
		words = json.data
	else:
		words = raw.replace("[", "").replace("]", "").replace("\"", "").split(",")
	
	# Shuffle words
	var shuffled = []
	for w in words:
		shuffled.append(str(w).strip_edges())
	shuffled.shuffle()
	
	for w_text in shuffled:
		if w_text == "": continue
		var w_node = preload("res://scripts/ui/DraggableWord.gd").new()
		w_node.word_text = w_text
		word_bank.add_child(w_node)
		w_node.setup()

func _on_submit_pressed() -> void:
	var user_sentence = ""
	for i in range(target_zone.get_child_count()):
		var node = target_zone.get_child(i)
		user_sentence += node.word_text + ( " " if i < target_zone.get_child_count() - 1 else "" )
	
	var correct_sentence = str(question_data.get("answer", "")).strip_edges()
	var is_correct = (user_sentence.to_lower() == correct_sentence.to_lower())
	
	submit_btn.disabled = true
	if is_correct:
		target_zone.modulate = Color.GREEN
	else:
		target_zone.modulate = Color.RED
		var lbl = Label.new()
		lbl.text = "Đáp án đúng: " + correct_sentence
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color.GREEN
		add_child(lbl)
		
	submit(is_correct, user_sentence)
