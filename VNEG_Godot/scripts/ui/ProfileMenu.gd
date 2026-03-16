extends Control
## VNEG_Godot/scripts/ui/ProfileMenu.gd
##
## Xử lý giao diện Hồ sơ (Profile) và hiển thị Cây Ngữ Pháp.

@onready var user_info_label: Label = $VBoxContainer/HBoxContent/ProfilePanel/VBox/UserInfoLabel
@onready var stats_label: Label = $VBoxContainer/HBoxContent/ProfilePanel/VBox/StatsLabel
@onready var grammar_tree_container: VBoxContainer = $VBoxContainer/HBoxContent/GrammarPanel/VBox/ScrollContainer/GrammarList
@onready var status_label: Label = $VBoxContainer/HBoxContent/ProfilePanel/VBox/StatusLabel

func _ready():
	if has_node("VBoxContainer/HeaderPanel/Header/BackButton"):
		$VBoxContainer/HeaderPanel/Header/BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
		
	# Add Logout button programmatically next to back button if it exists
	var btn_logout = Button.new()
	btn_logout.text = "Đăng xuất"
	btn_logout.pressed.connect(_on_logout_pressed)
	$VBoxContainer/HBoxContent/ProfilePanel/VBox.add_child(btn_logout)
		
	if AuthManager.is_logged_in():
		_update_user_info_ui()
	
	_load_grammar_progress()

func _update_user_info_ui() -> void:
	var user = AuthManager.current_user
	user_info_label.text = "Hồ sơ: " + user.get("email", "Unknown") + "\nLớp: " + str(user.get("grade", "?")) + " | Vùng: " + user.get("region", "")
	
	# Add Avatar UI elements if they don't exist
	var top_panel = $VBoxContainer/HBoxContent/ProfilePanel/VBox
	if not top_panel.has_node("AvatarContainer"):
		var avatar_hb = HBoxContainer.new()
		avatar_hb.name = "AvatarContainer"
		
		# Avatar Display
		var avatar_rect = TextureRect.new()
		avatar_rect.name = "AvatarRect"
		avatar_rect.custom_minimum_size = Vector2(64, 64)
		avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar_hb.add_child(avatar_rect)
		
		# Edit UI
		var edit_vbox = VBoxContainer.new()
		var url_input = LineEdit.new()
		url_input.name = "UrlInput"
		url_input.placeholder_text = "Dán link ảnh đại diện..."
		url_input.text = user.get("avatarUrl", "")
		edit_vbox.add_child(url_input)
		
		var save_btn = Button.new()
		save_btn.text = "Lưu ảnh"
		save_btn.pressed.connect(func(): _on_save_avatar_pressed(url_input.text))
		edit_vbox.add_child(save_btn)
		
		var upload_btn = Button.new()
		upload_btn.text = "Tải ảnh lên"
		upload_btn.pressed.connect(_on_upload_pressed)
		edit_vbox.add_child(upload_btn)
		
		avatar_hb.add_child(edit_vbox)
		top_panel.add_child(avatar_hb)
		top_panel.move_child(avatar_hb, 0) # Place at the start
		
		# Setup FileDialog
		var file_dialog = FileDialog.new()
		file_dialog.name = "AvatarDialog"
		file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		file_dialog.access = FileDialog.ACCESS_FILESYSTEM
		file_dialog.filters = ["*.png, *.jpg, *.jpeg ; Images"]
		file_dialog.file_selected.connect(_on_avatar_file_selected)
		add_child(file_dialog)
		
	_load_avatar(user.get("avatarUrl", ""))

func _on_upload_pressed() -> void:
	var dialog = get_node_or_null("AvatarDialog")
	if dialog:
		dialog.popup_centered(Vector2(600, 400))

func _on_avatar_file_selected(path: String) -> void:
	status_label.text = "Đang tải ảnh lên..."
	var res = await API.upload_image(path)
	if res["ok"]:
		var new_url = res["data"]["url"]
		var url_input = get_node_or_null("VBoxContainer/HBoxContent/ProfilePanel/VBox/AvatarContainer/VBoxContainer/UrlInput")
		if url_input: url_input.text = new_url
		_on_save_avatar_pressed(new_url)
	else:
		var err_detail = str(res["data"])
		if res["data"] is Dictionary and res["data"].has("errors"):
			err_detail = JSON.stringify(res["data"]["errors"])
		status_label.text = "Lỗi tải lên: " + err_detail
		status_label.add_theme_color_override("font_color", Color.RED)
		print("Upload error detail: ", res)

func _load_avatar(url: String) -> void:
	if url == "" or not url.begins_with("http"):
		return
		
	var http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(func(result, code, headers, body):
		if result == OK and code == 200:
			var img = Image.new()
			var err = img.load_jpg_from_buffer(body) # Try JPG
			if err != OK: err = img.load_png_from_buffer(body) # Try PNG
			
			if err == OK:
				var tex = ImageTexture.create_from_image(img)
				var rect = get_node_or_null("VBoxContainer/HBoxContent/ProfilePanel/VBox/AvatarContainer/AvatarRect")
				if rect: rect.texture = tex
		http.queue_free()
	)
	http.request(url)

func _on_save_avatar_pressed(new_url: String) -> void:
	status_label.text = "Đang cập nhật ảnh..."
	var res = await API.update_me({"avatarUrl": new_url})
	if res["ok"]:
		status_label.text = "Cập nhật thành công!"
		# Update local session data
		AuthManager.current_user["avatarUrl"] = new_url
		AuthManager.save_session(AuthManager.session_token, AuthManager.current_user)
		_load_avatar(new_url)
	else:
		status_label.text = "Lỗi cập nhật: " + str(res["data"])
		status_label.add_theme_color_override("font_color", Color.RED)

func _load_grammar_progress() -> void:
	status_label.text = "Đang tải tiến trình học..."
	
	# Gọi 2 API song song: Topcis và Progress
	# Trong GDScript, ta gọi await tuần tự hoặc tự viết cơ chế Promise. Ở đây gọi tuần tự cho dễ hiểu.
	var res_topics = await API.fetch("/api/grammar/topics")
	var res_prog = await API.get_grammar_progress()
	
	if res_topics["ok"] and res_prog["ok"]:
		status_label.text = ""
		
		var topics: Array = res_topics["data"]
		var progress: Array = []
		if res_prog["data"] != null and res_prog["data"].has("progress"):
			progress = res_prog["data"]["progress"]
			
		# Map progress theo Topic ID
		var prog_dict = {}
		for p in progress:
			prog_dict[int(p["grammarTopicId"])] = p
			
		# Xóa UI cũ
		for child in grammar_tree_container.get_children():
			child.queue_free()
			
		# Sinh UI
		for t in topics:
			var panel = PanelContainer.new()
			var vbox = VBoxContainer.new()
			
			var title_lbl = Label.new()
			title_lbl.text = t["name"] + " (" + t.get("code", "") + ")"
			title_lbl.add_theme_font_size_override("font_size", 16)
			
			var p_data = prog_dict.get(int(t["id"]), null)
			var mastery = 0.0
			var info_text = "Chưa học"
			var color = Color.GRAY
			
			if p_data != null:
				mastery = float(p_data.get("masteryLevel", 0.0))
				var correct = int(p_data.get("correct", 0))
				var wrong = int(p_data.get("wrong", 0))
				info_text = "Mức độ: " + str(mastery) + "% | ✅ " + str(correct) + " | ❌ " + str(wrong)
				
				if mastery >= 80: color = Color.GREEN
				elif mastery >= 50: color = Color.YELLOW
				elif mastery > 0: color = Color.ORANGE
				
			var info_lbl = Label.new()
			info_lbl.text = info_text
			info_lbl.add_theme_color_override("font_color", color)
			
			# Thanh tiến trình (ProgressBar)
			var pbar = ProgressBar.new()
			pbar.max_value = 100
			pbar.value = mastery
			pbar.custom_minimum_size = Vector2(0, 10)
			
			vbox.add_child(title_lbl)
			vbox.add_child(info_lbl)
			vbox.add_child(pbar)
			
			panel.add_child(vbox)
			grammar_tree_container.add_child(panel)
			
	else:
		status_label.text = "Lỗi tải dữ liệu ngữ pháp!"
		status_label.add_theme_color_override("font_color", Color.RED)

func _on_logout_pressed() -> void:
	await API.logout()
	get_tree().change_scene_to_file("res://scenes/LoginScreen.tscn")
