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

var selected_map_key: String = ""
var selected_chapter_id: String = ""

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
	# Load từ Database Offline (GrammarDB)
	for child in map_container.get_children():
		if child.name != "Label":
			child.queue_free()
			
	for m_key in GrammarDB.DATABASE.keys():
		var m_data = GrammarDB.DATABASE[m_key]
		var btn = Button.new()
		btn.text = m_data["icon"] + " " + m_data["title"]
		
		btn.pressed.connect(func(): _on_map_selected(m_key, m_data["title"]))
		map_container.add_child(btn)

func _on_map_selected(map_key: String, map_name: String) -> void:
	selected_map_key = map_key
	selected_chapter_id = ""
	play_button.disabled = true
	print("Đã chọn Map: ", map_name)
	
	for child in games_container.get_children():
		if child.name != "Label" and child != play_button:
			child.queue_free()
			
	var chapters = GrammarDB.DATABASE[map_key]["chapters"]
	for ch in chapters:
		var btn = Button.new()
		btn.text = "📖 " + ch["title"]
		btn.pressed.connect(func(): _on_game_selected(ch["id"]))
		games_container.add_child(btn)
		games_container.move_child(btn, games_container.get_child_count() - 2)

func _on_game_selected(chapter_id: String) -> void:
	selected_chapter_id = chapter_id
	play_button.disabled = false
	print("Đã chọn Chapter ID: ", chapter_id)

func _on_play_pressed() -> void:
	if selected_chapter_id == "":
		return
		
	print("Bắt đầu Session cho Chapter ", selected_chapter_id)
	play_button.disabled = true
	
	# Lấy danh sách câu hỏi Ôn Tập (onTap) từ DB Offline cho Chapter này
	var q_list = GrammarDB.get_questions(selected_map_key, selected_chapter_id, "onTap")
	
	if q_list.size() > 0:
		GameManager.game_questions = q_list
		GameManager.hp = 3
		GameManager.stars = 0
		get_tree().change_scene_to_file("res://scenes/AntigravityWorld.tscn")
	else:
		play_button.text = "Game chưa có câu hỏi!"
		await get_tree().create_timer(2.0).timeout
		play_button.disabled = false
		play_button.text = "Chơi game này"

func _on_logout_pressed() -> void:
	await API.logout() # Wait for session cleanup
	get_tree().change_scene_to_file("res://scenes/LoginScreen.tscn")
