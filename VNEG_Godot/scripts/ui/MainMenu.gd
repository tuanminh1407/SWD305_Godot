extends Control
## VNEG_Godot/scripts/ui/MainMenu.gd
##
## Xử lý giao diện Dashboard & Chọn Màn Chơi.

@onready var welcome_label: Label = $VBoxContainer/HeaderPanel/Header/WelcomeLabel
@onready var score_label: Label = $VBoxContainer/HeaderPanel/Header/ScoreLabel
@onready var map_container: VBoxContainer = $VBoxContainer/MainPanel/HBoxContent/MapContainer/MapScroll/MapList
@onready var games_container: VBoxContainer = $VBoxContainer/MainPanel/HBoxContent/GamesContainer/GameScroll/GameList
@onready var play_button: Button = $VBoxContainer/MainPanel/HBoxContent/GamesContainer/PlayButton

@onready var btn_teams: Button = $VBoxContainer/DashboardNav/BtnTeams
@onready var btn_profile: Button = $VBoxContainer/DashboardNav/BtnProfile

var selected_map_id: int = 0
var selected_game_id: int = 0

func _ready():
	play_button.pressed.connect(_on_play_pressed)
	if btn_teams: btn_teams.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/TeamsMenu.tscn"))
	if btn_profile: btn_profile.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/ProfileMenu.tscn"))
	
	# Add Logout button programmatically
	var btn_logout = Button.new()
	btn_logout.text = "Đăng xuất"
	btn_logout.pressed.connect(_on_logout_pressed)
	$VBoxContainer/DashboardNav.add_child(btn_logout)
	
	# Role-gated navigation buttons
	var user_role = AuthManager.get_user_role()
	if user_role == "admin":
		var btn_admin = Button.new()
		btn_admin.text = "⚙️ Admin Panel"
		btn_admin.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/AdminDashboard.tscn"))
		$VBoxContainer/DashboardNav.add_child(btn_admin)
	
	if user_role == "admin" or user_role == "staff":
		var btn_staff = Button.new()
		btn_staff.text = "👥 Staff Panel"
		btn_staff.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/StaffPanel.tscn"))
		$VBoxContainer/DashboardNav.add_child(btn_staff)
	
	if AuthManager.is_logged_in():
		welcome_label.text = "Xin chào, " + AuthManager.current_user.get("email", "Học sinh").split("@")[0] + "!"
		_load_user_stats()
	else:
		# Lỗi auth, văng về login
		get_tree().change_scene_to_file("res://scenes/LoginScreen.tscn")
		return
		
	# Load danh sách các Map học tập
	_load_maps()

func _load_user_stats() -> void:
	# Gọi API lấy Grammar Progress hiển thị hoặc tổng sao (Mock logic)
	pass

func _load_maps() -> void:
	for child in map_container.get_children():
		if child.name != "Label":
			child.queue_free()
			
	var lbl = Label.new()
	lbl.text = "Đang tải dữ liệu Maps..."
	map_container.add_child(lbl)
			
	var response = await API.get_maps()
	lbl.queue_free()
	
	if response["ok"] and typeof(response["data"]) == TYPE_ARRAY:
		var maps = response["data"]
		for m_data in maps:
			var btn = Button.new()
			btn.text = "🌍 " + str(m_data.get("name", "Map"))
			var m_id = int(m_data.get("id", 0))
			btn.pressed.connect(func(): _on_map_selected(m_id, m_data.get("name", "Map")))
			map_container.add_child(btn)
	else:
		var err = Label.new()
		err.text = "Lỗi tải Map từ Server!"
		map_container.add_child(err)

func _on_map_selected(map_id: int, map_name: String) -> void:
	selected_map_id = map_id
	selected_game_id = 0
	play_button.disabled = true
	print("Đã chọn Map ID: ", map_id, " - ", map_name)
	
	for child in games_container.get_children():
		if child.name != "Label" and child != play_button:
			child.queue_free()
			
	var lbl = Label.new()
	lbl.text = "Đang tải danh sách Game..."
	games_container.add_child(lbl)
	games_container.move_child(lbl, games_container.get_child_count() - 2)
			
	var response = await API.get_games_by_map(map_id)
	lbl.queue_free()
	
	if response["ok"] and typeof(response["data"]) == TYPE_ARRAY:
		var games = response["data"]
		if games.size() == 0:
			var no_game = Label.new()
			no_game.text = "Map này chưa có Game nào."
			games_container.add_child(no_game)
			games_container.move_child(no_game, games_container.get_child_count() - 2)
			return
			
		for g_data in games:
			var btn = Button.new()
			btn.text = "🎮 " + str(g_data.get("name", "Game"))
			var g_id = int(g_data.get("id", 0))
			btn.pressed.connect(func(): _on_game_selected(g_id, g_data.get("name", "Game")))
			games_container.add_child(btn)
			games_container.move_child(btn, games_container.get_child_count() - 2)
	else:
		var err = Label.new()
		err.text = "Lỗi tải Game từ Server!"
		games_container.add_child(err)
		games_container.move_child(err, games_container.get_child_count() - 2)

func _on_game_selected(game_id: int, game_name: String) -> void:
	selected_game_id = game_id
	play_button.disabled = false
	print("Đã chọn Game ID: ", game_id, " - ", game_name)

func _on_play_pressed() -> void:
	if selected_game_id == 0:
		return
		
	print("Bắt đầu khởi tạo Session cho Game ID: ", selected_game_id)
	play_button.disabled = true
	play_button.text = "Đang khởi tạo game..."
	
	var user_id = int(AuthManager.current_user.get("id", 0))
	var start_response = await API.start_game(user_id, selected_game_id)
	
	if start_response["ok"] and typeof(start_response["data"]) == TYPE_DICTIONARY:
		var session_id = int(start_response["data"].get("sessionId", 0))
		GameManager.start_session(session_id, selected_game_id)
		
		# Now fetch questions for this session
		play_button.text = "Đang tải câu hỏi..."
		var q_response = await API.get_questions(session_id)
		
		if q_response["ok"] and typeof(q_response["data"]) == TYPE_ARRAY:
			var q_list = q_response["data"]
			if q_list.size() > 0:
				GameManager.game_questions = q_list
				get_tree().change_scene_to_file("res://scenes/AntigravityWorld.tscn")
			else:
				play_button.text = "Game này không có câu hỏi!"
				await get_tree().create_timer(2.0).timeout
				play_button.disabled = false
				play_button.text = "Chơi game này"
		else:
			play_button.text = "Lỗi tải câu hỏi!"
			await get_tree().create_timer(2.0).timeout
			play_button.disabled = false
			play_button.text = "Chơi game này"
	else:
		play_button.text = "Lỗi khởi tạo Session!"
		await get_tree().create_timer(2.0).timeout
		play_button.disabled = false
		play_button.text = "Chơi game này"

func _on_logout_pressed() -> void:
	await API.logout() # Wait for session cleanup
	get_tree().change_scene_to_file("res://scenes/LoginScreen.tscn")
