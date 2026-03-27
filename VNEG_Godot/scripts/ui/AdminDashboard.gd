extends Control
## VNEG_Godot/scripts/ui/AdminDashboard.gd
##
## Admin Dashboard – 5 Tab Panel
## Tabs: User Analytics | System Health | Content Reports | Knowledge Mgmt | Export

# ── Node References ──
@onready var header_label: Label = $VBoxContainer/Header/TitleLabel
@onready var back_button: Button = $VBoxContainer/Header/BackButton
@onready var tab_bar: HBoxContainer = $VBoxContainer/TabBar
@onready var content_area: VBoxContainer = $VBoxContainer/ScrollContainer/ContentArea
@onready var status_label: Label = $VBoxContainer/StatusLabel

# Stats
@onready var stat_users: Label = $VBoxContainer/StatsRow/StatUsers/Value
@onready var stat_games: Label = $VBoxContainer/StatsRow/StatGames/Value
@onready var stat_topics: Label = $VBoxContainer/StatsRow/StatTopics/Value
@onready var stat_questions: Label = $VBoxContainer/StatsRow/StatQuestions/Value

var current_tab: String = "analytics"

# CRUD state
var edit_game_id: int = -1
var edit_topic_id: int = -1
var edit_question_id: int = -1
var all_games: Array = []
var all_topics: Array = []
var all_questions: Array = []

# Audit Log state
var audit_page: int = 1
var audit_total_pages: int = 1
var audit_filter_action: String = ""

func _ready():
	# Auth check
	if not AuthManager.is_logged_in() or AuthManager.get_user_role() != "admin":
		show_status("Chỉ Admin mới có quyền truy cập!", Color.RED)
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return

	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))

	# Create tab buttons
	_create_tabs()
	_load_summary_stats()
	_switch_tab("analytics")

func _create_tabs():
	var tabs = [
		{"id": "analytics", "label": "📊 User Analytics"},
		{"id": "health", "label": "🖥️ System Health"},
		{"id": "content", "label": "📈 Content Reports"},
		{"id": "knowledge", "label": "📝 Knowledge Mgmt"},
		{"id": "audit", "label": "📜 Audit Log"},
		{"id": "export", "label": "📤 Export"},
	]
	for t in tabs:
		var btn = Button.new()
		btn.text = t["label"]
		btn.pressed.connect(func(): _switch_tab(t["id"]))
		btn.custom_minimum_size = Vector2(160, 36)
		tab_bar.add_child(btn)

func _switch_tab(tab_id: String):
	current_tab = tab_id
	# Update button styles
	for i in range(tab_bar.get_child_count()):
		var btn = tab_bar.get_child(i) as Button
		if btn:
			btn.modulate = Color(1, 1, 0.5) if i == _get_tab_index(tab_id) else Color(1, 1, 1)

	# Clear content
	for child in content_area.get_children():
		child.queue_free()
	await get_tree().process_frame

	match tab_id:
		"analytics": _load_analytics_tab()
		"health": _load_health_tab()
		"content": _load_content_tab()
		"knowledge": _load_knowledge_tab()
		"audit": _load_audit_tab()
		"export": _load_export_tab()

func _get_tab_index(tab_id: String) -> int:
	match tab_id:
		"analytics": return 0
		"health": return 1
		"content": return 2
		"knowledge": return 3
		"audit": return 4
		"export": return 5
	return 0

# ==============================================================================
# SUMMARY STATS
# ==============================================================================
func _load_summary_stats():
	var users_res = await API.admin_get_users()
	var games_res = await API.admin_get_games()
	var topics_res = await API.admin_get_grammar_topics()
	var questions_res = await API.admin_get_questions()

	if users_res["ok"] and users_res["data"] is Array:
		stat_users.text = str(users_res["data"].size())
	else:
		_handle_api_error("stats/users", users_res)
		
	if games_res["ok"] and games_res["data"] is Array:
		stat_games.text = str(games_res["data"].size())
		all_games = games_res["data"]
	else:
		_handle_api_error("stats/games", games_res)
		
	if topics_res["ok"] and topics_res["data"] is Array:
		stat_topics.text = str(topics_res["data"].size())
		all_topics = topics_res["data"]
	else:
		_handle_api_error("stats/topics", topics_res)
		
	if questions_res["ok"] and questions_res["data"] is Array:
		stat_questions.text = str(questions_res["data"].size())
		all_questions = questions_res["data"]
	else:
		_handle_api_error("stats/questions", questions_res)

# ==============================================================================
# TAB 1: USER ANALYTICS
# ==============================================================================
func _load_analytics_tab():
	show_status("Đang tải User Analytics...", Color.WHITE)

	# DAU/MAU stats
	var stats_res = await API.admin_get_user_stats()
	if not stats_res["ok"]:
		_handle_api_error("User Analytics", stats_res)
		return
	
	if stats_res["ok"] and stats_res["data"] is Dictionary:
		var d = stats_res["data"]
		var info = Label.new()
		info.text = "📊 DAU: %s  |  MAU: %s  |  Total: %s  |  New (7d): %s" % [
			str(d.get("dau", 0)), str(d.get("mau", 0)),
			str(d.get("totalUsers", 0)), str(d.get("newUsersLast7d", 0))
		]
		info.add_theme_font_size_override("font_size", 18)
		content_area.add_child(info)

	# Retention
	var ret_res = await API.admin_get_retention()
	if ret_res["ok"] and ret_res["data"] is Dictionary:
		var r = ret_res["data"]
		_add_section_label("📈 Retention (Cohort: %s users)" % str(r.get("cohortSize", 0)))

		var grid = GridContainer.new()
		grid.columns = 3
		for header in ["D1", "D7", "D30"]:
			var h = Label.new()
			h.text = header
			h.add_theme_font_size_override("font_size", 16)
			h.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
			grid.add_child(h)
		for key in ["d1", "d7", "d30"]:
			var val = Label.new()
			val.text = str(r.get(key, 0)) + "%"
			val.add_theme_font_size_override("font_size", 20)
			grid.add_child(val)
		content_area.add_child(grid)

	# Demographics
	var demo_res = await API.admin_get_demographics()
	if demo_res["ok"] and demo_res["data"] is Dictionary:
		var d = demo_res["data"]
		_add_section_label("👤 Demographics – By Grade")
		if d.has("byGrade") and d["byGrade"] is Array:
			for item in d["byGrade"]:
				var row = Label.new()
				var grade_name = "Không rõ" if int(item.get("grade", 0)) == 0 else "Lớp " + str(item.get("grade", 0))
				row.text = "  %s: %s users" % [grade_name, str(item.get("count", 0))]
				content_area.add_child(row)

		_add_section_label("🌍 Demographics – By Region")
		if d.has("byRegion") and d["byRegion"] is Array:
			for item in d["byRegion"]:
				var row = Label.new()
				row.text = "  %s: %s users" % [str(item.get("region", "?")), str(item.get("count", 0))]
				content_area.add_child(row)

	show_status("", Color.WHITE)

# ==============================================================================
# TAB 2: SYSTEM HEALTH
# ==============================================================================
func _load_health_tab():
	show_status("Đang tải System Health...", Color.WHITE)
	var res = await API.admin_get_system_health()
	if not res["ok"]:
		show_status("Lỗi tải System Health", Color.RED)
		return

	var d = res["data"]
	var uptime = d.get("uptime", 100.0)
	var concurrent = d.get("concurrentUsers", 0)
	var errors = d.get("errorCount", 0)
	var alert = d.get("alertUptimeLow", false)

	# Alert banner
	if alert:
		var alert_label = Label.new()
		alert_label.text = "⚠️ CẢNH BÁO: Uptime dưới 99.5%! Kiểm tra hệ thống ngay!"
		alert_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		alert_label.add_theme_font_size_override("font_size", 20)
		content_area.add_child(alert_label)

	_add_section_label("🖥️ System Health Overview")

	var info = VBoxContainer.new()
	var uptime_color = Color.GREEN if uptime >= 99.5 else Color(1, 0.6, 0)
	_add_stat_row(info, "Uptime", str(uptime) + "%", uptime_color)
	_add_stat_row(info, "Concurrent Users", str(concurrent), Color.WHITE)
	_add_stat_row(info, "Errors (24h)", str(errors), Color(1, 0.5, 0.5) if errors > 0 else Color.GREEN)
	_add_stat_row(info, "Total Logs (24h)", str(d.get("totalLogs24h", 0)), Color.WHITE)
	content_area.add_child(info)

	show_status("", Color.WHITE)

func _add_stat_row(parent: VBoxContainer, label_text: String, value_text: String, color: Color):
	var hbox = HBoxContainer.new()
	var lbl = Label.new()
	lbl.text = label_text + ": "
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.custom_minimum_size.x = 200
	hbox.add_child(lbl)

	var val = Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", 20)
	val.add_theme_color_override("font_color", color)
	hbox.add_child(val)
	parent.add_child(hbox)

# ==============================================================================
# TAB 3: CONTENT REPORTS
# ==============================================================================
func _load_content_tab():
	show_status("Đang tải Content Reports...", Color.WHITE)

	# Top Games
	var games_res = await API.admin_get_content_reports()
	if not games_res["ok"]:
		_handle_api_error("Content Reports", games_res)
		return
		
	if games_res["ok"] and games_res["data"] is Array:
		_add_section_label("🎮 Top 10 Most Played Games")
		var grid = GridContainer.new()
		grid.columns = 4
		for h in ["Game", "Sessions", "Avg Score", "Avg Accuracy"]:
			var header = Label.new()
			header.text = h
			header.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
			grid.add_child(header)

		for item in games_res["data"]:
			_add_grid_cell(grid, str(item.get("gameName", "?")))
			_add_grid_cell(grid, str(item.get("sessionCount", 0)))
			_add_grid_cell(grid, str(snapped(item.get("avgScore", 0), 0.1)))
			_add_grid_cell(grid, str(snapped(item.get("avgAccuracy", 0), 0.1)) + "%")
		content_area.add_child(grid)

	# Error Hotspots
	var hotspots_res = await API.admin_get_error_hotspots()
	if hotspots_res["ok"] and hotspots_res["data"] is Array:
		_add_section_label("🔥 Error Hotspots – Grammar Topics")
		var grid2 = GridContainer.new()
		grid2.columns = 3
		for h in ["Topic", "Code", "Error Count"]:
			var header = Label.new()
			header.text = h
			header.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
			grid2.add_child(header)

		for item in hotspots_res["data"]:
			_add_grid_cell(grid2, str(item.get("topicName", "?")))
			_add_grid_cell(grid2, str(item.get("topicCode", "")))
			var error_label = Label.new()
			error_label.text = str(item.get("errorCount", 0))
			error_label.add_theme_color_override("font_color", Color(1, 0.5, 0.5))
			grid2.add_child(error_label)
		content_area.add_child(grid2)

	show_status("", Color.WHITE)

func _add_grid_cell(grid: GridContainer, text: String):
	var lbl = Label.new()
	lbl.text = text
	grid.add_child(lbl)

# ==============================================================================
# TAB 4: KNOWLEDGE MANAGEMENT
# ==============================================================================
func _load_knowledge_tab():
	# Sub-tab buttons
	var sub_tabs = HBoxContainer.new()
	for st in [{"id": "games", "label": "🎮 Games"}, {"id": "grammar", "label": "📚 Grammar"}, {"id": "questions", "label": "❓ Questions"}]:
		var btn = Button.new()
		btn.text = st["label"]
		btn.pressed.connect(_load_knowledge_sub.bind(st["id"]))
		sub_tabs.add_child(btn)
	content_area.add_child(sub_tabs)

	_add_separator()
	_load_knowledge_sub("games")

func _load_knowledge_sub(sub: String):
	# Remove everything after the sub-tab buttons and separator (first 2 children)
	var children = content_area.get_children()
	for i in range(2, children.size()):
		children[i].queue_free()
	await get_tree().process_frame

	match sub:
		"games": _build_games_crud()
		"grammar": _build_grammar_crud()
		"questions": _build_questions_crud()

# ── GAMES CRUD ──
func _build_games_crud():
	_add_section_label("🎮 Quản lý Games (Soft Delete)")

	# Form
	var form = VBoxContainer.new()
	form.name = "GameForm"
	var form_title = Label.new()
	form_title.name = "FormTitle"
	form_title.text = "➕ Thêm Game mới"
	form.add_child(form_title)

	var row1 = HBoxContainer.new()
	_add_form_field(row1, "gName", "Tên game", 200)
	_add_form_field(row1, "gMapId", "Map ID", 80)
	_add_form_field(row1, "gType", "Loại (main/mini/boss)", 160)
	_add_form_field(row1, "gOrder", "Thứ tự", 80)
	form.add_child(row1)

	var btn_row = HBoxContainer.new()
	var save_btn = Button.new()
	save_btn.text = "💾 Lưu"
	save_btn.pressed.connect(_save_game)
	btn_row.add_child(save_btn)
	var reset_btn = Button.new()
	reset_btn.text = "↩ Reset"
	reset_btn.pressed.connect(func(): edit_game_id = -1; _load_knowledge_sub("games"))
	btn_row.add_child(reset_btn)
	form.add_child(btn_row)
	content_area.add_child(form)

	_add_separator()

	# Table
	var grid = GridContainer.new()
	grid.name = "GameTable"
	grid.columns = 6
	for h in ["ID", "Tên", "Map", "Loại", "Active", "Hành động"]:
		var header = Label.new()
		header.text = h
		header.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
		grid.add_child(header)

	for g in all_games:
		_add_grid_cell(grid, str(g.get("id", "")))
		_add_grid_cell(grid, str(g.get("name", "")))
		_add_grid_cell(grid, str(g.get("mapId", "")))
		_add_grid_cell(grid, str(g.get("gameType", "")))
		var active_label = Label.new()
		active_label.text = "✅" if g.get("isActive", true) != false else "❌"
		grid.add_child(active_label)

		var actions = HBoxContainer.new()
		var edit_btn = Button.new()
		edit_btn.text = "✏️"
		var gid = int(g.get("id", 0))
		edit_btn.pressed.connect(func(): _edit_game(gid))
		actions.add_child(edit_btn)
		var del_btn = Button.new()
		del_btn.text = "🗑️"
		del_btn.pressed.connect(func(): _delete_game(gid))
		actions.add_child(del_btn)
		grid.add_child(actions)

	content_area.add_child(grid)

func _save_game():
	var form = content_area.get_node_or_null("GameForm")
	if not form: return
	var name_val = _get_form_value(form, "gName")
	var map_id = _get_form_value(form, "gMapId")
	var game_type = _get_form_value(form, "gType")
	var order = _get_form_value(form, "gOrder")

	if name_val == "" or map_id == "":
		show_status("Tên và Map ID là bắt buộc!", Color.RED)
		return

	var dto = {
		"name": name_val,
		"mapId": int(map_id),
		"gameType": game_type if game_type != "" else "main",
		"orderIndex": int(order) if order != "" else 1,
		"isPremium": false,
		"isActive": true
	}

	show_status("Đang lưu...", Color.WHITE)
	var res
	if edit_game_id > 0:
		res = await API.admin_update_game(edit_game_id, dto)
	else:
		res = await API.admin_create_game(dto)

	if res["ok"]:
		show_status("Đã lưu game thành công! ✅", Color.GREEN)
		edit_game_id = -1
		var reload = await API.admin_get_games()
		if reload["ok"] and reload["data"] is Array:
			all_games = reload["data"]
			stat_games.text = str(all_games.size())
		_load_knowledge_sub("games")
	else:
		show_status("Lỗi: " + str(res.get("data", "?")), Color.RED)

func _edit_game(gid: int):
	edit_game_id = gid
	var g = null
	for item in all_games:
		if int(item.get("id", 0)) == gid:
			g = item
			break
	if not g: return
	_load_knowledge_sub("games")
	# Fill form after rebuild (deferred)
	await get_tree().process_frame
	var form = content_area.get_node_or_null("GameForm")
	if form:
		var title = form.get_node_or_null("FormTitle")
		if title: title.text = "✏️ Sửa Game #" + str(gid)
		_set_form_value(form, "gName", str(g.get("name", "")))
		_set_form_value(form, "gMapId", str(g.get("mapId", "")))
		_set_form_value(form, "gType", str(g.get("gameType", "")))
		_set_form_value(form, "gOrder", str(g.get("orderIndex", 1)))

func _delete_game(gid: int):
	show_status("Đang xóa game #" + str(gid) + "...", Color.WHITE)
	var res = await API.admin_delete_game(gid)
	if res["ok"]:
		show_status("Đã xóa (soft delete) ✅", Color.GREEN)
		var reload = await API.admin_get_games()
		if reload["ok"] and reload["data"] is Array:
			all_games = reload["data"]
			stat_games.text = str(all_games.size())
		_load_knowledge_sub("games")
	else:
		show_status("Lỗi xóa game", Color.RED)

# ── GRAMMAR CRUD ──
func _build_grammar_crud():
	_add_section_label("📚 Quản lý Grammar Topics (Soft Delete)")

	var form = VBoxContainer.new()
	form.name = "GrammarForm"
	var form_title = Label.new()
	form_title.name = "FormTitle"
	form_title.text = "➕ Thêm Grammar Topic"
	form.add_child(form_title)

	var row1 = HBoxContainer.new()
	_add_form_field(row1, "gtCode", "Code", 100)
	_add_form_field(row1, "gtName", "Tên", 200)
	_add_form_field(row1, "gtParent", "Parent ID", 80)
	_add_form_field(row1, "gtDiff", "Độ khó (1-3)", 100)
	form.add_child(row1)

	var row2 = HBoxContainer.new()
	_add_form_field(row2, "gtDesc", "Mô tả", 300)
	form.add_child(row2)

	var btn_row = HBoxContainer.new()
	var save_btn = Button.new()
	save_btn.text = "💾 Lưu"
	save_btn.pressed.connect(_save_grammar)
	btn_row.add_child(save_btn)
	var reset_btn = Button.new()
	reset_btn.text = "↩ Reset"
	reset_btn.pressed.connect(func(): edit_topic_id = -1; _load_knowledge_sub("grammar"))
	btn_row.add_child(reset_btn)
	form.add_child(btn_row)
	content_area.add_child(form)

	_add_separator()

	var grid = GridContainer.new()
	grid.columns = 6
	for h in ["ID", "Code", "Tên", "Difficulty", "Active", "Hành động"]:
		var header = Label.new()
		header.text = h
		header.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
		grid.add_child(header)

	for t in all_topics:
		_add_grid_cell(grid, str(t.get("id", "")))
		_add_grid_cell(grid, str(t.get("code", "")))
		_add_grid_cell(grid, str(t.get("name", "")))
		_add_grid_cell(grid, str(t.get("difficulty", "")))
		var active_label = Label.new()
		active_label.text = "✅" if t.get("isActive", true) != false else "❌"
		grid.add_child(active_label)

		var actions = HBoxContainer.new()
		var edit_btn = Button.new()
		edit_btn.text = "✏️"
		var tid = int(t.get("id", 0))
		edit_btn.pressed.connect(func(): _edit_grammar(tid))
		actions.add_child(edit_btn)
		var del_btn = Button.new()
		del_btn.text = "🗑️"
		del_btn.pressed.connect(func(): _delete_grammar(tid))
		actions.add_child(del_btn)
		grid.add_child(actions)

	content_area.add_child(grid)

func _save_grammar():
	var form = content_area.get_node_or_null("GrammarForm")
	if not form: return
	var code = _get_form_value(form, "gtCode")
	var name_val = _get_form_value(form, "gtName")
	var parent = _get_form_value(form, "gtParent")
	var diff = _get_form_value(form, "gtDiff")
	var desc = _get_form_value(form, "gtDesc")

	if code == "" or name_val == "":
		show_status("Code và Tên là bắt buộc!", Color.RED)
		return

	var dto = {
		"code": code,
		"name": name_val,
		"parentId": int(parent) if parent != "" else null,
		"difficulty": int(diff) if diff != "" else null,
		"description": desc if desc != "" else null,
		"isActive": true if edit_topic_id <= 0 else null
	}

	show_status("Đang lưu...", Color.WHITE)
	var res
	if edit_topic_id > 0:
		res = await API.admin_update_grammar_topic(edit_topic_id, dto)
	else:
		res = await API.admin_create_grammar_topic(dto)

	if res["ok"]:
		show_status("Đã lưu grammar topic ✅", Color.GREEN)
		edit_topic_id = -1
		var reload = await API.admin_get_grammar_topics()
		if reload["ok"] and reload["data"] is Array:
			all_topics = reload["data"]
			stat_topics.text = str(all_topics.size())
		_load_knowledge_sub("grammar")
	else:
		show_status("Lỗi: " + str(res.get("data", "?")), Color.RED)

func _edit_grammar(tid: int):
	edit_topic_id = tid
	var t = null
	for item in all_topics:
		if int(item.get("id", 0)) == tid:
			t = item
			break
	if not t: return
	_load_knowledge_sub("grammar")
	await get_tree().process_frame
	var form = content_area.get_node_or_null("GrammarForm")
	if form:
		var title = form.get_node_or_null("FormTitle")
		if title: title.text = "✏️ Sửa Topic #" + str(tid)
		_set_form_value(form, "gtCode", str(t.get("code", "")))
		_set_form_value(form, "gtName", str(t.get("name", "")))
		_set_form_value(form, "gtParent", str(t.get("parentId", "")))
		_set_form_value(form, "gtDiff", str(t.get("difficulty", "")))
		_set_form_value(form, "gtDesc", str(t.get("description", "")))

func _delete_grammar(tid: int):
	show_status("Đang xóa topic #" + str(tid) + "...", Color.WHITE)
	var res = await API.admin_delete_grammar_topic(tid)
	if res["ok"]:
		show_status("Đã xóa (soft delete) ✅", Color.GREEN)
		var reload = await API.admin_get_grammar_topics()
		if reload["ok"] and reload["data"] is Array:
			all_topics = reload["data"]
			stat_topics.text = str(all_topics.size())
		_load_knowledge_sub("grammar")
	else:
		show_status("Lỗi xóa topic", Color.RED)

# ── QUESTIONS CRUD ──
func _build_questions_crud():
	_add_section_label("❓ Quản lý Câu Hỏi (Soft Delete)")

	var form = VBoxContainer.new()
	form.name = "QuestionForm"
	var form_title = Label.new()
	form_title.name = "FormTitle"
	form_title.text = "➕ Thêm Câu Hỏi"
	form.add_child(form_title)

	var row1 = HBoxContainer.new()
	_add_form_field(row1, "qGameId", "Game ID", 80)
	_add_form_field(row1, "qType", "Loại (mc/fill/order)", 150)
	_add_form_field(row1, "qDiff", "Độ khó (1-3)", 100)
	_add_form_field(row1, "qAnswer", "Đáp án (index)", 120)
	form.add_child(row1)

	var row2 = HBoxContainer.new()
	_add_form_field(row2, "qData", "Dữ liệu JSON", 400)
	form.add_child(row2)

	var btn_row = HBoxContainer.new()
	var save_btn = Button.new()
	save_btn.text = "💾 Lưu"
	save_btn.pressed.connect(_save_question)
	btn_row.add_child(save_btn)
	var reset_btn = Button.new()
	reset_btn.text = "↩ Reset"
	reset_btn.pressed.connect(func(): edit_question_id = -1; _load_knowledge_sub("questions"))
	btn_row.add_child(reset_btn)

	# CSV Import button
	var csv_btn = Button.new()
	csv_btn.text = "📥 Import CSV"
	csv_btn.pressed.connect(_import_csv_questions)
	btn_row.add_child(csv_btn)

	form.add_child(btn_row)
	content_area.add_child(form)

	_add_separator()

	var grid = GridContainer.new()
	grid.columns = 6
	for h in ["ID", "Game ID", "Loại", "Difficulty", "Active", "Hành động"]:
		var header = Label.new()
		header.text = h
		header.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
		grid.add_child(header)

	for q in all_questions:
		_add_grid_cell(grid, str(q.get("id", "")))
		_add_grid_cell(grid, str(q.get("gameId", "")))
		_add_grid_cell(grid, str(q.get("questionType", "")))
		_add_grid_cell(grid, str(q.get("difficulty", "")))
		var active_label = Label.new()
		active_label.text = "✅" if q.get("isActive", true) != false else "❌"
		grid.add_child(active_label)

		var actions = HBoxContainer.new()
		var edit_btn = Button.new()
		edit_btn.text = "✏️"
		var qid = int(q.get("id", 0))
		edit_btn.pressed.connect(func(): _edit_question(qid))
		actions.add_child(edit_btn)
		var del_btn = Button.new()
		del_btn.text = "🗑️"
		del_btn.pressed.connect(func(): _delete_question(qid))
		actions.add_child(del_btn)
		grid.add_child(actions)

	content_area.add_child(grid)

func _save_question():
	var form = content_area.get_node_or_null("QuestionForm")
	if not form: return
	var game_id = _get_form_value(form, "qGameId")
	var q_type = _get_form_value(form, "qType")
	var diff = _get_form_value(form, "qDiff")
	var answer = _get_form_value(form, "qAnswer")
	var data = _get_form_value(form, "qData")

	if game_id == "" or data == "":
		show_status("Game ID và Dữ liệu là bắt buộc!", Color.RED)
		return

	var dto = {
		"gameId": int(game_id),
		"questionType": q_type if q_type != "" else "mc",
		"difficulty": int(diff) if diff != "" else 1,
		"answer": answer,
		"data": data,
		"isActive": false # Draft → Admin review toggle to publish
	}

	show_status("Đang lưu...", Color.WHITE)
	var res
	if edit_question_id > 0:
		res = await API.admin_update_question(edit_question_id, dto)
	else:
		res = await API.admin_create_question(dto)

	if res["ok"]:
		show_status("Đã lưu câu hỏi ✅ (IsActive=false, cần review)", Color.GREEN)
		edit_question_id = -1
		var reload = await API.admin_get_questions()
		if reload["ok"] and reload["data"] is Array:
			all_questions = reload["data"]
			stat_questions.text = str(all_questions.size())
		_load_knowledge_sub("questions")
	else:
		show_status("Lỗi: " + str(res.get("data", "?")), Color.RED)

func _edit_question(qid: int):
	edit_question_id = qid
	var q = null
	for item in all_questions:
		if int(item.get("id", 0)) == qid:
			q = item
			break
	if not q: return
	_load_knowledge_sub("questions")
	await get_tree().process_frame
	var form = content_area.get_node_or_null("QuestionForm")
	if form:
		var title = form.get_node_or_null("FormTitle")
		if title: title.text = "✏️ Sửa Câu hỏi #" + str(qid)
		_set_form_value(form, "qGameId", str(q.get("gameId", "")))
		_set_form_value(form, "qType", str(q.get("questionType", "")))
		_set_form_value(form, "qDiff", str(q.get("difficulty", "")))
		_set_form_value(form, "qAnswer", str(q.get("answer", "")))
		_set_form_value(form, "qData", str(q.get("data", "")))

func _delete_question(qid: int):
	show_status("Đang xóa câu hỏi #" + str(qid) + "...", Color.WHITE)
	var res = await API.admin_delete_question(qid)
	if res["ok"]:
		show_status("Đã xóa (soft delete) ✅", Color.GREEN)
		var reload = await API.admin_get_questions()
		if reload["ok"] and reload["data"] is Array:
			all_questions = reload["data"]
			stat_questions.text = str(all_questions.size())
		_load_knowledge_sub("questions")
	else:
		show_status("Lỗi xóa câu hỏi", Color.RED)

func _import_csv_questions():
	var fd = FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.csv ; CSV Files"])
	fd.file_selected.connect(_on_csv_selected)
	add_child(fd)
	fd.popup_centered(Vector2(600, 400))

func _on_csv_selected(path: String):
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		show_status("Không thể mở file CSV", Color.RED)
		return

	var headers_line = file.get_line()
	var headers = headers_line.split(",")
	var count = 0

	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "": continue
		var cols = line.split(",")
		if cols.size() < 4: continue

		var dto = {
			"gameId": int(cols[0]),
			"questionType": cols[1] if cols.size() > 1 else "mc",
			"difficulty": int(cols[2]) if cols.size() > 2 else 1,
			"data": cols[3] if cols.size() > 3 else "",
			"answer": cols[4] if cols.size() > 4 else "",
			"isActive": false
		}
		var res = await API.admin_create_question(dto)
		if res["ok"]:
			count += 1

	show_status("Import CSV xong! Đã tạo %d câu hỏi (draft)" % count, Color.GREEN)
	var reload = await API.admin_get_questions()
	if reload["ok"] and reload["data"] is Array:
		all_questions = reload["data"]
		stat_questions.text = str(all_questions.size())
	_load_knowledge_sub("questions")

# ==============================================================================
# TAB 5: AUDIT LOG
# ==============================================================================
func _load_audit_tab():
	show_status("Đang tải Audit Log...", Color.WHITE)
	
	# Filter bar
	var filter_bar = HBoxContainer.new()
	var action_input = LineEdit.new()
	action_input.placeholder_text = "Filter by action (e.g. user_status_change)"
	action_input.custom_minimum_size.x = 300
	action_input.text = audit_filter_action
	action_input.text_changed.connect(func(t): audit_filter_action = t)
	filter_bar.add_child(action_input)
	
	var search_btn = Button.new()
	search_btn.text = "🔍 Lọc"
	search_btn.pressed.connect(func(): audit_page = 1; _do_load_audit())
	filter_bar.add_child(search_btn)
	content_area.add_child(filter_bar)
	
	# Pagination bar
	var page_bar = HBoxContainer.new()
	page_bar.name = "AuditPageBar"
	var prev_btn = Button.new()
	prev_btn.text = "◀"
	prev_btn.pressed.connect(func(): if audit_page > 1: audit_page -= 1; _do_load_audit())
	page_bar.add_child(prev_btn)
	
	var page_label = Label.new()
	page_label.name = "PageLabel"
	page_bar.add_child(page_label)
	
	var next_btn = Button.new()
	next_btn.text = "▶"
	next_btn.pressed.connect(func(): if audit_page < audit_total_pages: audit_page += 1; _do_load_audit())
	page_bar.add_child(next_btn)
	content_area.add_child(page_bar)
	
	_add_separator()
	
	var table = GridContainer.new()
	table.name = "AuditTable"
	table.columns = 5
	for h in ["Time", "User", "Action", "Details", "ID"]:
		var header = Label.new()
		header.text = h
		header.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
		table.add_child(header)
	content_area.add_child(table)
	
	await _do_load_audit()

func _do_load_audit():
	var filters = {"page": audit_page, "size": 20}
	if audit_filter_action != "":
		filters["action"] = audit_filter_action
		
	var res = await API.admin_get_audit_logs(filters)
	if not res["ok"]:
		_handle_api_error("Audit Log", res)
		return
		
	var data = res["data"]
	var logs = data.get("logs", [])
	var pagination = data.get("pagination", {})
	audit_total_pages = int(pagination.get("totalPages", 1))
	audit_page = int(pagination.get("page", 1))
	
	# Update pagination label
	var page_bar = content_area.get_node_or_null("AuditPageBar")
	if page_bar:
		var pl = page_bar.get_node_or_null("PageLabel")
		if pl: pl.text = " Trang %d / %d (Mục: %d) " % [audit_page, audit_total_pages, int(pagination.get("totalCount", 0))]
		
	# Update table
	var table = content_area.get_node_or_null("AuditTable")
	if not table: return
	
	# Clear previous rows (keep header: first 5 children)
	for i in range(table.get_child_count() - 1, 4, -1):
		table.get_child(i).queue_free()
	
	await get_tree().process_frame
	
	for l in logs:
		_add_grid_cell(table, str(l.get("createdAt", "")))
		_add_grid_cell(table, str(l.get("userEmail", "System")))
		_add_grid_cell(table, str(l.get("action", "")))
		
		var details = Label.new()
		details.text = str(l.get("details", ""))
		details.clip_text = true
		details.custom_minimum_size.x = 400
		details.tooltip_text = details.text
		table.add_child(details)
		
		_add_grid_cell(table, str(l.get("id", "")))
		
	show_status("", Color.WHITE)

# ==============================================================================
# TAB 6: EXPORT
# ==============================================================================
func _load_export_tab():
	_add_section_label("📤 Export Data to CSV")

	for export_type in ["users", "games", "questions"]:
		var hbox = HBoxContainer.new()
		var label = Label.new()
		label.text = "Export " + export_type.capitalize() + ":"
		label.custom_minimum_size.x = 200
		hbox.add_child(label)

		var btn = Button.new()
		btn.text = "📥 Download CSV"
		var et = export_type # capture
		btn.pressed.connect(func(): _do_export(et))
		hbox.add_child(btn)
		content_area.add_child(hbox)

	_add_section_label("ℹ️ Files sẽ được lưu vào user://exports/")
	
	var open_folder_btn = Button.new()
	open_folder_btn.text = "📂 Mở thư mục Export"
	open_folder_btn.pressed.connect(func(): OS.shell_open(ProjectSettings.globalize_path("user://exports")))
	content_area.add_child(open_folder_btn)

func _do_export(export_type: String):
	show_status("Đang export " + export_type + "...", Color.WHITE)

	# Fetch data and save locally
	var data_res: Dictionary
	var csv_content: String = ""

	match export_type:
		"users":
			data_res = await API.admin_get_users()
			if data_res["ok"] and data_res["data"] is Array:
				csv_content = "id,email,phone,grade,region,role,isActive,createdAt\n"
				for u in data_res["data"]:
					csv_content += "%s,%s,%s,%s,%s,%s,%s,%s\n" % [
						str(u.get("id","")), str(u.get("email","")), str(u.get("phone","")),
						str(u.get("grade","")), str(u.get("region","")), str(u.get("role","")),
						str(u.get("isActive","")), str(u.get("createdAt",""))
					]
		"games":
			data_res = await API.admin_get_games()
			if data_res["ok"] and data_res["data"] is Array:
				csv_content = "id,name,mapId,gameType,orderIndex,isPremium,isActive\n"
				for g in data_res["data"]:
					csv_content += "%s,%s,%s,%s,%s,%s,%s\n" % [
						str(g.get("id","")), str(g.get("name","")), str(g.get("mapId","")),
						str(g.get("gameType","")), str(g.get("orderIndex","")),
						str(g.get("isPremium","")), str(g.get("isActive",""))
					]
		"questions":
			data_res = await API.admin_get_questions()
			if data_res["ok"] and data_res["data"] is Array:
				csv_content = "id,gameId,questionType,difficulty,isActive,answer\n"
				for q in data_res["data"]:
					csv_content += "%s,%s,%s,%s,%s,%s\n" % [
						str(q.get("id","")), str(q.get("gameId","")), str(q.get("questionType","")),
						str(q.get("difficulty","")), str(q.get("isActive","")), str(q.get("answer",""))
					]

	if csv_content == "":
		show_status("Không có dữ liệu để export", Color.RED)
		return

	# Save file
	DirAccess.make_dir_recursive_absolute("user://exports")
	var filename = "user://exports/%s_%s.csv" % [export_type, Time.get_datetime_string_from_system().replace(":", "-")]
	var file = FileAccess.open(filename, FileAccess.WRITE)
	if file:
		file.store_string(csv_content)
		file.close()
		show_status("Đã export thành công: " + filename, Color.GREEN)
	else:
		show_status("Lỗi ghi file", Color.RED)

# ==============================================================================
# UTILITIES
# ==============================================================================
func _add_section_label(text: String):
	var sep = HSeparator.new()
	content_area.add_child(sep)
	var lbl = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.85, 1.0))
	content_area.add_child(lbl)

func _add_separator():
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	content_area.add_child(sep)

func _add_form_field(parent: HBoxContainer, field_name: String, placeholder: String, width: float):
	var input = LineEdit.new()
	input.name = field_name
	input.placeholder_text = placeholder
	input.custom_minimum_size.x = width
	parent.add_child(input)

func _get_form_value(form: Node, field_name: String) -> String:
	var input = _find_line_edit(form, field_name)
	return input.text.strip_edges() if input else ""

func _set_form_value(form: Node, field_name: String, value: String):
	var input = _find_line_edit(form, field_name)
	if input:
		input.text = value

func _find_line_edit(node: Node, field_name: String) -> LineEdit:
	if node is LineEdit and node.name == field_name:
		return node as LineEdit
	for child in node.get_children():
		var result = _find_line_edit(child, field_name)
		if result:
			return result
	return null

func show_status(msg: String, color: Color):
	if status_label:
		status_label.text = msg
		status_label.add_theme_color_override("font_color", color)

func _handle_api_error(context: String, res: Dictionary):
	var err_msg = "Lỗi " + context + " (HTTP " + str(res.get("status", 0)) + ")"
	if res.get("data") and res["data"] is String:
		err_msg += ": " + res["data"]
	show_status(err_msg, Color.RED)
	printerr(err_msg)
