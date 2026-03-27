extends QuestionBase

var audio_player: AudioStreamPlayer
var play_btn: Button
var is_audio_ready: bool = false

func _do_setup() -> void:
	# Inherits from QuestionBase (VBoxContainer)
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 20)
	
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	play_btn = Button.new()
	play_btn.text = "🔊 Phát Âm Thanh"
	play_btn.custom_minimum_size = Vector2(0, 80)
	play_btn.disabled = true
	add_child(play_btn)
	
	play_btn.pressed.connect(func():
		if is_audio_ready and audio_player.stream != null:
			audio_player.play()
		else:
			print("ListenChoose: Audio not ready or stream null!")
	)
	
	# Load Audio from URL
	var audio_url = str(question_data.get("audioUrl", ""))
	if audio_url == "":
		audio_url = str(question_data.get("audio_url", "")) # Fallback
		
	if audio_url != "" and audio_url.begins_with("http"):
		_load_audio_from_url(audio_url)
	else:
		play_btn.text = "Không có âm thanh!"
		
	# Setup Options like Multiple Choice
	var raw_data = str(question_data.get("data", ""))
	var options = []
	var json = JSON.new()
	if json.parse(raw_data) == OK and typeof(json.data) == TYPE_ARRAY:
		options = json.data
	else:
		options = raw_data.split(",")
		
	var correct_ans = str(question_data.get("answer", ""))
	
	var options_box = VBoxContainer.new()
	options_box.add_theme_constant_override("separation", 10)
	add_child(options_box)
	
	for i in range(options.size()):
		var btn = Button.new()
		var opt_text = str(options[i]).strip_edges()
		btn.text = opt_text
		btn.custom_minimum_size = Vector2(0, 50)
		options_box.add_child(btn)
		
		btn.pressed.connect(func():
			_on_option_selected(btn, opt_text, correct_ans, options_box)
		)

func _load_audio_from_url(url: String) -> void:
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_audio_downloaded)
	
	var headers = ["User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"]
	http.request(url, headers)
	play_btn.text = "Đang tải âm thanh..."

func _on_audio_downloaded(_result, response_code, headers, body) -> void:
	print("ListenChoose: Audio downloaded. Code: ", response_code, " Body size: ", body.size())
	if response_code == 200 and body.size() > 0:
		var stream = null
		
		# Detect type based on headers or magic bytes
		var is_ogg = false
		for h in headers:
			if "audio/ogg" in h.to_lower() or "application/ogg" in h.to_lower():
				is_ogg = true
				break
		
		# Check magic bytes for OGG (OggS)
		if not is_ogg and body.size() > 4:
			if body[0] == 0x4f and body[1] == 0x67 and body[2] == 0x67 and body[3] == 0x53:
				is_ogg = true
		
		if is_ogg:
			print("ListenChoose: Detected OGG format.")
			stream = AudioStreamOggVorbis.load_from_buffer(body)
		else:
			# Check magic bytes for WAV (RIFF ... WAVE)
			var is_wav = false
			if body.size() > 12:
				if body[0] == 0x52 and body[1] == 0x49 and body[2] == 0x46 and body[3] == 0x46: # RIFF
					if body[8] == 0x57 and body[9] == 0x41 and body[10] == 0x56 and body[11] == 0x45: # WAVE
						is_wav = true
			
			if is_wav:
				print("ListenChoose: Detected WAV format.")
				stream = AudioStreamWAV.new()
				# Simple WAV loading for standard PCM (Godot handles most common formats)
				stream.data = body
				# Note: Setting properties like format/loop/mix_rate might be needed for RAW
				# but for standard WAV header, Godot often handles it. 
				# Actually, AudioStreamWAV.data expects the raw samples if not loaded from file.
				# A better runtime solution for WAV might be needed if this fails.
			else:
				# Check for MP3
				var is_mp3 = false
				if body.size() > 3:
					if body[0] == 0x49 and body[1] == 0x44 and body[2] == 0x33: # ID3
						is_mp3 = true
					elif body[0] == 0xff and (body[1] & 0xe0) == 0xe0: # Layer 3 sync
						is_mp3 = true
				
				if is_mp3:
					print("ListenChoose: Detected MP3 format.")
					stream = AudioStreamMP3.new()
					stream.data = body
				else:
					print("ListenChoose: Unknown audio format, trying MP3 fallback.")
					stream = AudioStreamMP3.new()
					stream.data = body
			
		if stream:
			audio_player.stream = stream
			is_audio_ready = true
			play_btn.text = "🔊 Nghe Audio"
			play_btn.disabled = false
			print("ListenChoose: Audio stream ready.")
		else:
			play_btn.text = "Lỗi định dạng âm thanh!"
			print("ListenChoose: Failed to create stream.")
	else:
		play_btn.text = "Lỗi âm thanh! (Code: " + str(response_code) + ")"
		print("ListenChoose: Failed to load audio. Code: ", response_code)

func _on_option_selected(btn: Button, selected: String, correct: String, options_box: VBoxContainer) -> void:
	for child in options_box.get_children():
		child.disabled = true
			
	var is_correct = (selected.to_lower() == correct.to_lower())
	
	if is_correct:
		btn.modulate = Color.GREEN
	else:
		btn.modulate = Color.RED
		for child in options_box.get_children():
			if child.text.to_lower() == correct.to_lower():
				child.modulate = Color.GREEN
				
	submit(is_correct, selected)
