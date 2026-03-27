extends Node
## VNEG_Godot/scripts/autoloads/GameManager.gd
##
## Autoload (Singleton) quản lý trạng thái của ván game hiện tại.
## Lưu trữ ID session, bộ câu hỏi, tính điểm, mạng HP.

var current_session_id: int = 0
var current_game_id: int = 0
var current_task_id: int = 0
var game_questions: Array = []
var answered_questions: Array = []

var hp: int = 3
var coins: int = 0
var stars: int = 0

## Khởi tạo trạng thái game mới
func start_session(session_id: Variant, game_id: int, task_id: int = 0) -> void:
	current_session_id = int(session_id)
	current_game_id = game_id
	current_task_id = task_id
	game_questions.clear()
	answered_questions.clear()
	hp = 3
	coins = 0
	stars = 0

## Xóa trạng thái game (sau khi kết thúc hoặc thoát)
func clear_session() -> void:
	current_session_id = 0
	current_game_id = 0
	current_task_id = 0
	game_questions.clear()
	answered_questions.clear()

## Ghi nhận một câu trả lời
func record_answer(question_id: int, raw_answer: Variant, is_correct: bool) -> void:
	answered_questions.append({
		"questionId": question_id,
		"selectedAnswer": raw_answer
	})
	
	if is_correct:
		coins += 5
		if stars < 3:
			stars += 1
	else:
		hp = max(0, hp - 1)

## Tính toán điểm số sơ bộ dựa trên số câu đã trả lời
func estimate_score() -> int:
	return answered_questions.size() * 10 

## Trả về Mảng dữ liệu kết quả để submit về Backend
func get_submission_data() -> Array:
	return answered_questions
