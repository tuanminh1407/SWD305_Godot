extends QuestionBase

var image_rect: TextureRect
var input_field: LineEdit
var image_loader: HTTPRequest

func _do_setup() -> void:
	# Inherits from QuestionBase (VBoxContainer)
	# Set some spacing/alignment
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 20)
	
	image_rect = TextureRect.new()
	image_rect.custom_minimum_size = Vector2(320, 240)
	image_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	add_child(image_rect)
	
	input_field = LineEdit.new()
	input_field.placeholder_text = "Nhập từ khóa theo hình..."
	input_field.custom_minimum_size = Vector2(0, 50)
	input_field.alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(input_field)
	
	var submit_btn = Button.new()
	submit_btn.text = "Xác nhận"
	submit_btn.custom_minimum_size = Vector2(0, 50)
	add_child(submit_btn)
	
	submit_btn.pressed.connect(_on_submit_pressed)
	input_field.text_submitted.connect(func(_text): _on_submit_pressed())
	
	# Load Image
	var img_url = str(question_data.get("imageUrl", ""))
	if img_url == "":
		img_url = str(question_data.get("image_url", "")) # Fallback to snake_case
		
	if img_url != "":
		_load_image(img_url)
	else:
		push_warning("PictureGuess: imageUrl is missing in q_data")

func _load_image(url: String) -> void:
	if not url.begins_with("http"): 
		push_error("PictureGuess: Invalid URL: " + url)
		return
	
	image_loader = HTTPRequest.new()
	add_child(image_loader)
	image_loader.request_completed.connect(_on_image_downloaded)
	
	# Common Browser User-Agent to avoid blocks
	var headers = ["User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"]
	var err = image_loader.request(url, headers)
	if err != OK:
		push_error("PictureGuess: HTTPRequest setup failed for " + url)

func _on_image_downloaded(_result, response_code, _headers, body) -> void:
	if response_code == 200:
		var image = Image.new()
		var err = image.load_jpg_from_buffer(body)
		if err != OK:
			err = image.load_png_from_buffer(body)
		if err != OK:
			err = image.load_webp_from_buffer(body)
			
		if err == OK:
			var texture = ImageTexture.create_from_image(image)
			image_rect.texture = texture
		else:
			push_error("PictureGuess: Failed to parse image body. Size: " + str(body.size()))
	else:
		push_error("PictureGuess: Image download failed. Code: " + str(response_code))
	
	if is_instance_valid(image_loader):
		image_loader.queue_free()

func _on_submit_pressed() -> void:
	var user_ans = input_field.text.strip_edges()
	if user_ans.is_empty():
		return
		
	input_field.editable = false
	var btn = get_child(get_child_count() - 1) # last child is submit_btn
	if btn is Button:
		btn.disabled = true
	
	var correct_ans_str = str(question_data.get("answer", "")).strip_edges()
	var is_correct = (user_ans.to_lower() == correct_ans_str.to_lower())
	
	if is_correct:
		input_field.modulate = Color.GREEN
	else:
		input_field.modulate = Color.RED
		var lbl = Label.new()
		lbl.text = "Đáp án đúng: " + correct_ans_str
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.modulate = Color.GREEN
		add_child(lbl)
		
	submit(is_correct, user_ans)
