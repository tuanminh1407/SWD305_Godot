extends Node2D
## VNEG_Godot/scripts/game/AntigravityWorld.gd
##
## Quản lý luồng hiển thị câu hỏi, tính điểm, gọi API nộp bài,
## và ra lệnh đảo ngược trọng lực vật lý cho Node Player.

@onready var ui_canvas: CanvasLayer = $UI
@onready var question_label: Label = $UI/Control/QuestionPanel/QuestionBox/QuestionLabel
@onready var choices_box: VBoxContainer = $UI/Control/QuestionPanel/QuestionBox/ChoicesBox
@onready var stars_label: Label = $UI/Control/MarginContainer/TopPanel/TopHUD/StarsLabel
@onready var hp_label: Label = $UI/Control/MarginContainer/TopPanel/TopHUD/HPLabel
@onready var timer_label: Label = $UI/Control/MarginContainer/TopPanel/TopHUD/TimerLabel

@onready var player: CharacterBody2D = $Player # Tham chiếu tới nhân vật

var timer_sec: float = 0.0
var current_question_index: int = 0
var is_game_over: bool = false
var gravity_flipped: bool = false

func _ready():
	_update_hud()
	if GameManager.game_questions.size() > 0:
		_show_question(0)
	else:
		question_label.text = "Lỗi: Không tìm thấy bộ câu hỏi!"

func _process(delta: float) -> void:
	if not is_game_over:
		timer_sec += delta
		var m = int(timer_sec) / 60
		var s = int(timer_sec) % 60
		timer_label.text = str(m).pad_zeros(2) + ":" + str(s).pad_zeros(2)

func _update_hud() -> void:
	stars_label.text = "⭐ " + str(GameManager.stars)
	var hp_str = ""
	for i in range(GameManager.hp): hp_str += "♥️"
	hp_label.text = hp_str if GameManager.hp > 0 else "💀"

func _show_question(index: int) -> void:
	if index >= GameManager.game_questions.size():
		_end_game()
		return
		
	var q_data = GameManager.game_questions[index]
	
	if q_data != null and q_data.has("question"):
		# Hiển thị Hint (thành ngữ, gốc từ) nếu có
		var hint_str = ""
		if q_data.has("thanGu"): hint_str = "\n💡 Thành ngữ: " + q_data["thanGu"]
		if q_data.has("scramble"): hint_str = "\n🔀 Từ gốc: " + str(q_data["scramble"])
		
		question_label.text = "Câu " + str(index + 1) + ": " + q_data["question"] + hint_str
	else:
		question_label.text = "Câu " + str(index + 1) + ": (Content missing)"
		
	# Xóa nút cũ
	for child in choices_box.get_children():
		child.queue_free()
		
	var choices = q_data.get("options", [])
	if choices.size() > 0:
		for i in range(choices.size()):
			var btn = Button.new()
			btn.text = str(choices[i])
			# Vô hiệu hóa nút trong 0.5s để chống Spam click
			btn.disabled = true
			await get_tree().create_timer(0.5).timeout
			btn.disabled = false
			
			var correct = 0
			if q_data.has("correctIndex"):
				correct = int(q_data["correctIndex"])
			elif q_data.has("correctIndices") and q_data["correctIndices"].size() > 0:
				correct = int(q_data["correctIndices"][0])
				
			btn.pressed.connect(func(): _on_answer_selected(index, i, correct))
			choices_box.add_child(btn)

func _on_answer_selected(q_id: int, selected_index: int, correct_index: int) -> void:
	if is_game_over: return
	
	# Vô hiệu hóa toàn bộ nút
	for child in choices_box.get_children():
		if child is Button:
			child.disabled = true
		
	var is_correct = (selected_index == correct_index)
	var q_data = GameManager.game_questions[q_id]
	var real_q_id = int(q_data.get("id", 0))
	GameManager.record_answer(real_q_id, selected_index, is_correct)
	if is_correct:
		choices_box.get_child(selected_index).modulate = Color(0, 1, 0)
		GameManager.stars += 10
		_trigger_gravity_flip()
	else:
		choices_box.get_child(selected_index).modulate = Color(1, 0, 0)
		GameManager.hp -= 1
		if correct_index < choices_box.get_child_count():
			choices_box.get_child(correct_index).modulate = Color(0, 1, 0)
			
	_update_hud()
	
	if GameManager.hp <= 0:
		_end_game()
		return
		
	# Chờ 1.5s rồi qua câu tiếp
	await get_tree().create_timer(1.5).timeout
	current_question_index += 1
	_show_question(current_question_index)

func _trigger_gravity_flip() -> void:
	gravity_flipped = !gravity_flipped
	PhysicsServer2D.area_set_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2(0, -1 if gravity_flipped else 1))
	if player and player.has_method("flip_gravity"):
		player.flip_gravity(gravity_flipped)

func _end_game() -> void:
	is_game_over = true
	question_label.text = "🎯 HOÀN THÀNH!"
	for child in choices_box.get_children():
		child.queue_free()
		
	var final_msg = "Kết quả: " + str(GameManager.stars) + " điểm!\nĐang lưu kết quả..."
	question_label.text = final_msg
	
	if GameManager.current_session_id != "":
		await API.submit_answers(GameManager.current_session_id, GameManager.get_submission_data())
		if GameManager.current_task_id != 0:
			await API.complete_team_task(GameManager.current_task_id, int(GameManager.current_session_id))
			
	question_label.text = "Kết quả: " + str(GameManager.stars) + " điểm!\nCảm ơn bạn đã thi tài!"
	
	var btn_exit = Button.new()
	btn_exit.text = "Về Dashboard"
	btn_exit.pressed.connect(func(): 
		# Reset gravity before leaving
		PhysicsServer2D.area_set_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2(0, 1))
		GameManager.clear_session()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
	choices_box.add_child(btn_exit)
