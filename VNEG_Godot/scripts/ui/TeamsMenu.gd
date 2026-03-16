extends Control
## VNEG_Godot/scripts/ui/TeamsMenu.gd
##
## Xử lý giao diện Quản lý Nhóm (Teams) trong Godot.
## Gắn script này vào Node Root của màn hình TeamsMenu.tscn.

@onready var team_list_container: VBoxContainer = $VBoxContainer/MainPanel/HBox/LeftPanel/ScrollContainer/TeamList
@onready var create_team_name_input: LineEdit = $VBoxContainer/MainPanel/HBox/RightPanel/CreateBox/NameInput
@onready var create_team_desc_input: LineEdit = $VBoxContainer/MainPanel/HBox/RightPanel/CreateBox/DescInput
@onready var create_btn: Button = $VBoxContainer/MainPanel/HBox/RightPanel/CreateBox/CreateButton
@onready var join_code_input: LineEdit = $VBoxContainer/MainPanel/HBox/RightPanel/JoinBox/CodeInput
@onready var join_btn: Button = $VBoxContainer/MainPanel/HBox/RightPanel/JoinBox/JoinButton
@onready var status_label: Label = $VBoxContainer/MainPanel/HBox/RightPanel/StatusLabel

func _ready():
	create_btn.pressed.connect(_on_create_team_pressed)
	join_btn.pressed.connect(_on_join_team_pressed)
	
	# Nút Back về MainMenu
	if has_node("VBoxContainer/HeaderPanel/Header/BackButton"):
		$VBoxContainer/HeaderPanel/Header/BackButton.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
		
	_load_my_teams()

func _load_my_teams() -> void:
	status_label.text = "Đang tải danh sách nhóm..."
	status_label.add_theme_color_override("font_color", Color.WHITE)
	
	var response = await API.fetch("/api/teams/me")
	
	if response["ok"]:
		status_label.text = ""
		var teams: Array = response["data"]
		
		# Xóa danh sách cũ
		for child in team_list_container.get_children():
			child.queue_free()
			
		if teams.size() == 0:
			var lbl = Label.new()
			lbl.text = "Bạn chưa tham gia nhóm nào."
			team_list_container.add_child(lbl)
			return
			
		for t in teams:
			var panel = PanelContainer.new()
			var vbox = VBoxContainer.new()
			
			var name_lbl = Label.new()
			name_lbl.text = "👥 " + t["name"]
			name_lbl.add_theme_font_size_override("font_size", 18)
			
			var desc_lbl = Label.new()
			desc_lbl.text = t.get("description", "Không có mô tả")
			
			var role_lbl = Label.new()
			var is_owner = (t["ownerId"] == AuthManager.get_user_id())
			role_lbl.text = "Vai trò: " + ("Trưởng nhóm" if is_owner else "Thành viên")
			role_lbl.add_theme_color_override("font_color", Color.GOLD if is_owner else Color.LIGHT_BLUE)
			
			vbox.add_child(name_lbl)
			vbox.add_child(desc_lbl)
			vbox.add_child(role_lbl)
			
			if is_owner:
				var code_lbl = Label.new()
				code_lbl.text = "Code mời: " + t["inviteCode"]
				vbox.add_child(code_lbl)
				
			var details_btn = Button.new()
			details_btn.text = "Xem chi tiết"
			details_btn.pressed.connect(func(): _show_team_details(t))
			vbox.add_child(details_btn)
				
			panel.add_child(vbox)
			team_list_container.add_child(panel)
	else:
		show_status("Lỗi tải danh sách nhóm", Color.RED)

func _on_create_team_pressed() -> void:
	var t_name = create_team_name_input.text.strip_edges()
	var t_desc = create_team_desc_input.text.strip_edges()
	
	if t_name == "":
		show_status("Vui lòng nhập tên nhóm!", Color.RED)
		return
		
	create_btn.disabled = true
	show_status("Đang tạo...", Color.WHITE)
	
	var payload = {
		"name": t_name,
		"description": t_desc
	}
	
	var response = await API.fetch("/api/teams", HTTPClient.METHOD_POST, payload)
	
	create_btn.disabled = false
	if response["ok"]:
		show_status("Tạo nhóm thành công!", Color.GREEN)
		create_team_name_input.text = ""
		create_team_desc_input.text = ""
		_load_my_teams()
	else:
		show_status(str(response["data"]), Color.RED)

func _on_join_team_pressed() -> void:
	var code = join_code_input.text.strip_edges()
	
	if code == "":
		show_status("Vui lòng nhập mã nhóm!", Color.RED)
		return
		
	join_btn.disabled = true
	show_status("Đang tham gia...", Color.WHITE)
	
	var payload = { "inviteCode": code }
	var response = await API.fetch("/api/teams/join", HTTPClient.METHOD_POST, payload)
	
	join_btn.disabled = false
	if response["ok"]:
		show_status("Tham gia thành công!", Color.GREEN)
		join_code_input.text = ""
		_load_my_teams()
	else:
		show_status(str(response["data"]), Color.RED)

func show_status(msg: String, color: Color) -> void:
	status_label.text = msg
	status_label.add_theme_color_override("font_color", color)

var details_panel: Panel = null

func _show_team_details(team_data: Dictionary) -> void:
	if details_panel != null:
		details_panel.queue_free()
		
	details_panel = Panel.new()
	details_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	var color_rect = ColorRect.new()
	color_rect.color = Color(0, 0, 0, 0.8)
	color_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	details_panel.add_child(color_rect)
	
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	details_panel.add_child(center)
	
	var bg_panel = PanelContainer.new()
	bg_panel.custom_minimum_size = Vector2(800, 500)
	center.add_child(bg_panel)
	
	var vbox = VBoxContainer.new()
	bg_panel.add_child(vbox)
	
	var title = Label.new()
	title.text = "Chi tiết nhóm: " + team_data["name"]
	title.add_theme_font_size_override("font_size", 20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	
	var is_owner = team_data["ownerId"] == AuthManager.get_user_id()
	
	var split = HBoxContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(split)
	
	# --- LEFT: MEMBERS ---
	var left_vbox = VBoxContainer.new()
	left_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(left_vbox)
	
	var mem_title = Label.new()
	mem_title.text = "Đang tải thành viên..."
	left_vbox.add_child(mem_title)
	
	if is_owner:
		var search_hb = HBoxContainer.new()
		var search_input = LineEdit.new()
		search_input.placeholder_text = "Tìm email (VD: thinh@...)"
		search_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		search_hb.add_child(search_input)
		var search_btn = Button.new()
		search_btn.text = "Tìm"
		search_hb.add_child(search_btn)
		left_vbox.add_child(search_hb)
		
		var search_results = VBoxContainer.new()
		left_vbox.add_child(search_results)
		
		search_btn.pressed.connect(func(): _on_search_users(search_input.text, search_results, team_data["id"], mem_title, left_vbox))
	
	var mem_scroll = ScrollContainer.new()
	mem_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var mem_list = VBoxContainer.new()
	mem_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mem_scroll.add_child(mem_list)
	left_vbox.add_child(mem_scroll)
	
	# --- RIGHT: TASKS ---
	var right_vbox = VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right_vbox)
	
	var task_title = Label.new()
	task_title.text = "Đang tải bài tập..."
	right_vbox.add_child(task_title)
	
	if is_owner:
		var create_hb = HBoxContainer.new()
		var gid_input = LineEdit.new()
		gid_input.placeholder_text = "Nhập Game ID (VD: 1)"
		create_hb.add_child(gid_input)
		var create_t_btn = Button.new()
		create_t_btn.text = "Tạo Bài Tập"
		create_t_btn.pressed.connect(func(): _on_create_team_task(team_data["id"], gid_input.text))
		create_hb.add_child(create_t_btn)
		right_vbox.add_child(create_hb)
		
	var task_scroll = ScrollContainer.new()
	task_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var task_list = VBoxContainer.new()
	task_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_scroll.add_child(task_list)
	right_vbox.add_child(task_scroll)
	
	# --- BOTTOM BUTTONS ---
	var btn_hbox = HBoxContainer.new()
	btn_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	
	var close_btn = Button.new()
	close_btn.text = "Đóng"
	close_btn.pressed.connect(func(): details_panel.queue_free())
	btn_hbox.add_child(close_btn)
	
	if is_owner:
		var del_btn = Button.new()
		del_btn.text = "Xóa nhóm"
		del_btn.add_theme_color_override("font_color", Color.RED)
		del_btn.pressed.connect(func(): _on_delete_team(team_data["id"]))
		btn_hbox.add_child(del_btn)
	else:
		var leave_btn = Button.new()
		leave_btn.text = "Rời nhóm"
		leave_btn.add_theme_color_override("font_color", Color.ORANGE)
		leave_btn.pressed.connect(func(): _on_leave_team(team_data["id"]))
		btn_hbox.add_child(leave_btn)
		
	vbox.add_child(btn_hbox)
	
	add_child(details_panel)
	
	# FETCH MEMBERS & TASKS CONCURRENTLY
	_fetch_members(team_data, is_owner, mem_title, mem_list)
	_fetch_tasks(team_data["id"], task_title, task_list)

func _fetch_members(team_data: Dictionary, is_owner: bool, title_lbl: Label, list_container: Control) -> void:
	var res = await API.fetch("/api/teams/" + str(team_data["id"]) + "/members")
	if res["ok"]:
		title_lbl.text = "Thành viên (" + str(res["data"].size()) + ")"
		for child in list_container.get_children(): child.queue_free()
		for m in res["data"]:
			var m_hbox = HBoxContainer.new()
			var m_lbl = Label.new()
			var is_m_owner = m["role"] == "owner" or m["userId"] == team_data["ownerId"]
			var m_role = " (Trưởng nhóm)" if is_m_owner else " (Thành viên)"
			m_lbl.text = "- " + m.get("email", "Unknown") + m_role
			m_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			m_hbox.add_child(m_lbl)
			
			if is_owner and m["userId"] != AuthManager.get_user_id():
				var kick_btn = Button.new()
				kick_btn.text = "Đuổi"
				kick_btn.pressed.connect(func(): _on_kick_member(team_data["id"], m["userId"]))
				m_hbox.add_child(kick_btn)
			list_container.add_child(m_hbox)
	else:
		title_lbl.text = "Lỗi tải thành viên hoặc nhóm chưa có thành viên!"
		title_lbl.add_theme_color_override("font_color", Color.RED)

func _fetch_tasks(team_id: int, title_lbl: Label, list_container: Control) -> void:
	var res = await API.get_team_tasks(team_id)
	if res["ok"]:
		var tasks = res["data"]
		title_lbl.text = "Bài tập nhóm (" + str(tasks.size()) + ")"
		for child in list_container.get_children(): child.queue_free()
		
		for t in tasks:
			var t_hbox = HBoxContainer.new()
			var t_lbl = Label.new()
			t_lbl.text = "Game " + str(t["gameId"]) + " | Thưởng: " + str(t.get("reward", "100_coins")) + " | Trạng thái: " + str(t["status"])
			t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			t_hbox.add_child(t_lbl)
			
			if str(t["status"]) != "completed":
				var play_btn = Button.new()
				play_btn.text = "Làm bài"
				play_btn.add_theme_color_override("font_color", Color.GREEN)
				play_btn.pressed.connect(func(): _on_play_team_task(t))
				t_hbox.add_child(play_btn)
			list_container.add_child(t_hbox)
	else:
		title_lbl.text = "Lỗi tải bài tập!"

func _on_create_team_task(team_id: int, game_id_str: String) -> void:
	var gid = int(game_id_str)
	if gid <= 0:
		show_status("Vui lòng nhập Game ID hợp lệ!", Color.RED)
		return
	if details_panel: details_panel.queue_free()
	show_status("Đang tạo bài tập...", Color.WHITE)
	var res = await API.create_team_task(team_id, gid)
	if res["ok"]:
		show_status("Đã tạo bài tập", Color.GREEN)
	else:
		var err_msg = str(res["data"])
		if res["data"] is Dictionary and res["data"].has("detail"):
			err_msg = str(res["data"]["detail"])
		show_status("Lỗi tạo bài tập: " + err_msg, Color.RED)

func _on_play_team_task(task_data: Dictionary) -> void:
	if details_panel: details_panel.queue_free()
	show_status("Đang tải dữ liệu bài thi...", Color.WHITE)
	
	var st_res = await API.start_team_task(task_data["id"])
	if st_res["ok"]:
		var session_id = str(st_res["data"]["sessionId"])
		var game_id = int(st_res["data"]["gameId"])
		
		var q_res = await API.get_questions(session_id)
		if q_res["ok"]:
			GameManager.game_questions = q_res["data"]
			GameManager.start_session(session_id, game_id, task_data["id"])
			get_tree().change_scene_to_file("res://scenes/AntigravityWorld.tscn")
		else:
			show_status("Lỗi tải câu hỏi!", Color.RED)
	else:
		show_status("Không thể bắt đầu: " + str(st_res["data"]), Color.RED)

func _on_leave_team(team_id: int) -> void:
	if details_panel: details_panel.queue_free()
	show_status("Đang rời nhóm...", Color.WHITE)
	var res = await API.fetch("/api/teams/" + str(team_id) + "/leave", HTTPClient.METHOD_POST)
	if res["ok"]:
		show_status("Đã rời nhóm", Color.GREEN)
		_load_my_teams()
	else:
		show_status("Lỗi rời nhóm: " + str(res["data"]), Color.RED)

func _on_delete_team(team_id: int) -> void:
	if details_panel: details_panel.queue_free()
	show_status("Đang xóa nhóm...", Color.WHITE)
	var res = await API.fetch("/api/team-owner/" + str(team_id), HTTPClient.METHOD_DELETE)
	if res["ok"]:
		show_status("Đã xóa nhóm", Color.GREEN)
		_load_my_teams()
	else:
		show_status("Lỗi xóa nhóm: " + str(res["data"]), Color.RED)

func _on_kick_member(team_id: int, user_id: int) -> void:
	if details_panel: details_panel.queue_free()
	show_status("Đang đuổi thành viên...", Color.WHITE)
	var payload = {"userId": user_id}
	var res = await API.fetch("/api/team-owner/" + str(team_id) + "/remove-member", HTTPClient.METHOD_POST, payload)
	if res["ok"]:
		show_status("Đã đuổi thành viên", Color.GREEN)
		_load_my_teams()
	else:
		show_status("Lỗi đuổi thành viên: " + str(res["data"]), Color.RED)

func _on_search_users(query: String, results_container: Control, team_id: int, title_lbl: Label, members_vbox: Control) -> void:
	for child in results_container.get_children(): child.queue_free()
	if query.length() < 3:
		return
		
	var res = await API.search_users(query)
	if res["ok"]:
		var users = res["data"]
		if users.size() == 0:
			var lbl = Label.new()
			lbl.text = "Không tìm thấy người dùng."
			results_container.add_child(lbl)
			return
			
		for u in users:
			var hb = HBoxContainer.new()
			var lbl = Label.new()
			lbl.text = u["email"]
			lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hb.add_child(lbl)
			var add_btn = Button.new()
			add_btn.text = "Thêm"
			add_btn.pressed.connect(func(): _on_add_team_member(team_id, u["id"], results_container, title_lbl, members_vbox))
			hb.add_child(add_btn)
			results_container.add_child(hb)
	else:
		var lbl = Label.new()
		lbl.text = "Lỗi tìm kiếm."
		results_container.add_child(lbl)

func _on_add_team_member(team_id: int, user_id: int, results_container: Control, title_lbl: Label, members_vbox: Control) -> void:
	for child in results_container.get_children(): child.queue_free()
	show_status("Đang thêm thành viên...", Color.WHITE)
	var res = await API.add_team_member(team_id, user_id)
	if res["ok"]:
		show_status("Đã thêm thành viên!", Color.GREEN)
		# Refresh member list
		_fetch_members({"id": team_id, "ownerId": AuthManager.get_user_id()}, true, title_lbl, members_vbox.get_child(members_vbox.get_child_count()-1).get_child(0))
	else:
		show_status("Lỗi thêm: " + str(res["data"]), Color.RED)
