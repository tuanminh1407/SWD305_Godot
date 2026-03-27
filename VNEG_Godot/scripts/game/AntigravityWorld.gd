extends Node2D
## VNEG_Godot/scripts/game/AntigravityWorld.gd
##
## Quản lý luồng hiển thị câu hỏi, tính điểm, gọi API nộp bài,
## và ra lệnh đảo ngược trọng lực vật lý cho Node Player.

@onready var ui_canvas: CanvasLayer = $UI
@onready var question_label: Label = $UI/QuestionBox/QuestionLabel
@onready var choices_box: VBoxContainer = $UI/QuestionBox/ChoicesBox
@onready var stars_label: Label = $UI/TopHUD/StarsLabel
@onready var hp_label: Label = $UI/TopHUD/HPLabel
@onready var timer_label: Label = $UI/TopHUD/TimerLabel

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
		var m = floor(timer_sec / 60.0)
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
	var question_text = ""
	var q_type = str(q_data.get("questionType", "")).to_lower()
	
	if q_type == "multiple_choice" or q_type == "listen_choose" or q_type == "picture_guess":
		question_text = str(q_data.get("explanation", "Nghe/Nhìn và chọn đáp án đúng:"))
	elif q_type == "drag_drop_sentence":
		question_text = "Sắp xếp các từ sau thành câu hoàn chỉnh:"
	else:
		question_text = str(q_data.get("data", ""))
	
	# The text of the question
	var hint_str = ""
	if q_data.has("explanation") and typeof(q_data["explanation"]) == TYPE_STRING and q_data["explanation"] != "" and q_type != "multiple_choice":
		hint_str = "\n💡 " + q_data["explanation"]
		
	var display_text = question_text
	if display_text.begins_with("[") and display_text.ends_with("]"):
		# If it's a JSON string by mistake, clean it
		display_text = display_text.replace("[\"", "").replace("\"]", "").replace("\", \"", " / ")
		
	question_label.text = "Câu " + str(index + 1) + ": " + display_text + hint_str
		
	# Xóa nút/Question UI cũ
	for child in choices_box.get_children():
		child.queue_free()
		
	var q_node : QuestionBase = null
	
	if q_type == "multiple_choice" or q_type == "":
		q_node = preload("res://scripts/ui/QuestionMultipleChoice.gd").new()
	elif q_type == "fill_blank":
		q_node = preload("res://scripts/ui/QuestionFillBlank.gd").new()
	elif q_type == "listen_choose":
		q_node = preload("res://scripts/ui/QuestionListenChoose.gd").new()
	elif q_type == "find_error":
		q_node = preload("res://scripts/ui/QuestionFindError.gd").new()
	elif q_type == "picture_guess":
		q_node = preload("res://scripts/ui/QuestionPictureGuess.gd").new()
	elif q_type == "drag_drop_sentence":
		q_node = preload("res://scripts/ui/QuestionDragDropSentence.gd").new()
	else:
		# Fallback
		q_node = preload("res://scripts/ui/QuestionMultipleChoice.gd").new()
		
	if q_node:
		choices_box.add_child(q_node)
		q_node.setup(q_data)
		q_node.answer_submitted.connect(func(is_correct, raw_ans):
			_on_answer_submitted(index, q_data.get("id", 0), is_correct, raw_ans)
		)

func _on_answer_submitted(_q_index: int, q_id: int, is_correct: bool, raw_ans: Variant) -> void:
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
		_trigger_gravity_flip()
		
	_update_hud()
	
	if GameManager.hp <= 0:
		_end_game()
		return
		
	current_question_index += 1
	_show_question(current_question_index)

func _trigger_gravity_flip() -> void:
	gravity_flipped = !gravity_flipped
	PhysicsServer2D.area_set_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2(0, -1 if gravity_flipped else 1))
	if player and player.has_method("flip_gravity"):
		player.flip_gravity(gravity_flipped)

func _end_game() -> void:
	is_game_over = true
	question_label.text = "🎯 ĐANG GỬI KẾT QUẢ..."
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
	btn_exit.disabled = true # Cấm bấm trong lúc gửi API
	choices_box.add_child(btn_exit)
	
	# Gọi API Submit
	var answers = GameManager.get_submission_data()
	var res = await API.submit_answers(GameManager.current_session_id, answers)
	
	if res["ok"] and typeof(res["data"]) == TYPE_DICTIONARY:
		var d = res["data"]
		final_msg = "Kết quả: " + str(d.get("score", 0)) + " điểm!\n"
		final_msg += "Chính xác: " + str(d.get("accuracy", 0)) + "%\n"
		final_msg += "Nhận được " + str(d.get("stars", 0)) + " ⭐ và " + str(d.get("coins", 0)) + " 🪙"
	else:
		final_msg = "Lỗi khi lưu kết quả lên Server.\nStars đạt được: " + str(GameManager.stars)
	
	question_label.text = final_msg
	
	btn_exit.disabled = false
	btn_exit.pressed.connect(func(): 
		# Reset gravity before leaving
		PhysicsServer2D.area_set_param(get_world_2d().space, PhysicsServer2D.AREA_PARAM_GRAVITY_VECTOR, Vector2(0, 1))
		GameManager.clear_session()
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	)
