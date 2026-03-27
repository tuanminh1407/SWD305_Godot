extends VBoxContainer
class_name QuestionBase

signal answer_submitted(is_correct: bool, selected_answer_raw: Variant)

var question_data: Dictionary = {}

func setup(data: Dictionary) -> void:
	question_data = data
	_do_setup()

# Hàm ảo cho các lớp con ghi đè
func _do_setup() -> void:
	pass

# Các lớp con sẽ gọi hàm này khi người chơi chọn xong đáp án
func submit(is_correct: bool, raw_answer: Variant) -> void:
	get_tree().create_timer(1.0).timeout.connect(func():
		answer_submitted.emit(is_correct, raw_answer)
	)
