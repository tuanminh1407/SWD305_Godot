extends Control
## VNEG_Godot/scripts/ui/StaffPanel.gd
##
## Staff Panel – User Management & Reports Handling
## Sections: User List | Account Toggle | Reports Queue

@onready var header_label: Label = $VBoxContainer/Header/TitleLabel
@onready var back_button: Button = $VBoxContainer/Header/BackButton
@onready var section_bar: HBoxContainer = $VBoxContainer/SectionBar
@onready var content_area: VBoxContainer = $VBoxContainer/ScrollContainer/ContentArea
@onready var status_label: Label = $VBoxContainer/StatusLabel

var current_section: String = "users"
var all_users: Array = []
var all_reports: Array = []
var current_page: int = 1
var total_pages: int = 1

# Filter states
var filter_grade: String = ""
var filter_region: String = ""
var filter_active: String = ""
var filter_search: String = ""

func _ready():
	# Auth check: staff or admin
	if not AuthManager.is_logged_in():
		get_tree().change_scene_to_file("res://scenes/LoginScreen.tscn")
		return
	var role = AuthManager.get_user_role()
	if role != "staff" and role != "admin":
		show_status("Chỉ Staff/Admin mới có quyền truy cập!", Color.RED)
		await get_tree().create_timer(1.5).timeout
		get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
		return

	back_button.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/MainMenu.tscn"))
	_create_sections()
	_switch_section("users")

func _create_sections():
	var sections = [
		{"id": "users", "label": "👤 User Management"},
		{"id": "reports", "label": "📋 Reports Queue"},
	]
	for s in sections:
		var btn = Button.new()
		btn.text = s["label"]
		btn.pressed.connect(func(): _switch_section(s["id"]))
		btn.custom_minimum_size = Vector2(180, 36)
		section_bar.add_child(btn)

func _switch_section(section_id: String):
	current_section = section_id
	for i in range(section_bar.get_child_count()):
		var btn = section_bar.get_child(i) as Button
		if btn:
			btn.modulate = Color(1, 1, 0.5) if (i == 0 and section_id == "users") or (i == 1 and section_id == "reports") else Color(1, 1, 1)

	for child in content_area.get_children():
		child.queue_free()

	match section_id:
		"users": _load_users_section()
		"reports": _load_reports_section()

# ==============================================================================
# SECTION 1: USER MANAGEMENT
# ==============================================================================
func _load_users_section():
	show_status("Đang tải danh sách users...", Color.WHITE)

	# Filter bar
	var filter_bar = HBoxContainer.new()
	filter_bar.name = "FilterBar"
	
	var search_input = LineEdit.new()
	search_input.name = "SearchInput"
	search_input.placeholder_text = "🔍 Tìm email..."
	search_input.custom_minimum_size.x = 200
	search_input.text = filter_search
	search_input.text_changed.connect(func(t): filter_search = t)
	filter_bar.add_child(search_input)

	var grade_input = LineEdit.new()
	grade_input.name = "GradeFilter"
	grade_input.placeholder_text = "Lớp"
	grade_input.custom_minimum_size.x = 60
	grade_input.text = filter_grade
	grade_input.text_changed.connect(func(t): filter_grade = t)
	filter_bar.add_child(grade_input)

	var region_input = LineEdit.new()
	region_input.name = "RegionFilter"
	region_input.placeholder_text = "Vùng"
	region_input.custom_minimum_size.x = 80
	region_input.text = filter_region
	region_input.text_changed.connect(func(t): filter_region = t)
	filter_bar.add_child(region_input)

	var search_btn = Button.new()
	search_btn.text = "🔍 Tìm"
	search_btn.pressed.connect(_do_search_users)
	filter_bar.add_child(search_btn)

	content_area.add_child(filter_bar)

	# Pagination
	var page_bar = HBoxContainer.new()
	page_bar.name = "PageBar"
	var prev_btn = Button.new()
	prev_btn.text = "◀ Trước"
	prev_btn.pressed.connect(func():
		if current_page > 1:
			current_page -= 1
			_do_search_users()
	)
	page_bar.add_child(prev_btn)

	var page_label = Label.new()
	page_label.name = "PageLabel"
	page_label.text = "Trang %d / %d" % [current_page, total_pages]
	page_bar.add_child(page_label)

	var next_btn = Button.new()
	next_btn.text = "Tiếp ▶"
	next_btn.pressed.connect(func():
		if current_page < total_pages:
			current_page += 1
			_do_search_users()
	)
	page_bar.add_child(next_btn)
	content_area.add_child(page_bar)

	_add_separator()

	# Load users
	await _do_search_users()

func _do_search_users():
	var filters = {"page": current_page, "size": 15}
	if filter_search != "":
		filters["search"] = filter_search
	if filter_grade != "":
		filters["grade"] = int(filter_grade)
	if filter_region != "":
		filters["region"] = filter_region

	var res = await API.staff_get_users(filters)
	if not res["ok"]:
		show_status("Lỗi tải users", Color.RED)
		return

	var data = res["data"]
	all_users = data.get("users", []) if data is Dictionary else []
	var pagination = data.get("pagination", {}) if data is Dictionary else {}
	total_pages = int(pagination.get("totalPages", 1))
	current_page = int(pagination.get("page", 1))

	# Update page label
	var page_bar = content_area.get_node_or_null("PageBar")
	if page_bar:
		var pl = page_bar.get_node_or_null("PageLabel")
		if pl: pl.text = "Trang %d / %d (Total: %d)" % [current_page, total_pages, int(pagination.get("totalCount", 0))]

	# Remove old table
	var old_table = content_area.get_node_or_null("UserTable")
	if old_table: old_table.queue_free()
	await get_tree().process_frame

	# Build table
	var grid = GridContainer.new()
	grid.name = "UserTable"
	grid.columns = 7
	for h in ["ID", "Email", "Lớp", "Vùng", "Role", "Status", "Hành động"]:
		var header = Label.new()
		header.text = h
		header.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
		grid.add_child(header)

	for u in all_users:
		_add_cell(grid, str(u.get("id", "")))
		_add_cell(grid, str(u.get("email", "")))
		_add_cell(grid, str(u.get("grade", "–")))
		_add_cell(grid, str(u.get("region", "–")))
		
		var role_label = Label.new()
		role_label.text = str(u.get("role", "user"))
		var r = str(u.get("role", "user"))
		if r == "admin":
			role_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
		elif r == "staff":
			role_label.add_theme_color_override("font_color", Color(0.3, 0.8, 1))
		grid.add_child(role_label)

		var status = Label.new()
		var is_active = u.get("isActive", true)
		status.text = "✅ Active" if is_active != false else "🔒 Locked"
		status.add_theme_color_override("font_color", Color.GREEN if is_active != false else Color.RED)
		grid.add_child(status)

		var actions = HBoxContainer.new()
		var uid = int(u.get("id", 0))
		var user_active = is_active != false
		
		var toggle_btn = Button.new()
		toggle_btn.text = "🔒 Khóa" if user_active else "🔓 Mở"
		toggle_btn.pressed.connect(func(): _show_toggle_dialog(uid, str(u.get("email", "")), user_active))
		actions.add_child(toggle_btn)

		var log_btn = Button.new()
		log_btn.text = "📋 Log"
		log_btn.pressed.connect(func(): _show_audit_log(uid))
		actions.add_child(log_btn)

		grid.add_child(actions)

	content_area.add_child(grid)
	show_status("", Color.WHITE)

func _show_toggle_dialog(user_id: int, email: String, currently_active: bool):
	# Create a simple dialog
	var dialog = VBoxContainer.new()
	dialog.name = "ToggleDialog"

	# Remove old dialog if exists
	var old = content_area.get_node_or_null("ToggleDialog")
	if old: old.queue_free()
	await get_tree().process_frame

	var title = Label.new()
	var action = "Khóa" if currently_active else "Mở khóa"
	title.text = "⚡ %s tài khoản: %s" % [action, email]
	title.add_theme_font_size_override("font_size", 18)
	dialog.add_child(title)

	var reason_input = LineEdit.new()
	reason_input.name = "ReasonInput"
	reason_input.placeholder_text = "Nhập lý do..."
	reason_input.custom_minimum_size.x = 400
	dialog.add_child(reason_input)

	var btn_row = HBoxContainer.new()
	
	if currently_active:
		var suspend_btn = Button.new()
		suspend_btn.text = "⏸️ Suspend"
		suspend_btn.pressed.connect(func(): _do_toggle(user_id, false, reason_input.text, "suspend"))
		btn_row.add_child(suspend_btn)

		var ban_btn = Button.new()
		ban_btn.text = "🚫 Ban"
		ban_btn.pressed.connect(func(): _do_toggle(user_id, false, reason_input.text, "ban"))
		btn_row.add_child(ban_btn)
	else:
		var unlock_btn = Button.new()
		unlock_btn.text = "🔓 Unlock"
		unlock_btn.pressed.connect(func(): _do_toggle(user_id, true, reason_input.text, "unlock"))
		btn_row.add_child(unlock_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "❌ Hủy"
	cancel_btn.pressed.connect(func(): dialog.queue_free())
	btn_row.add_child(cancel_btn)

	dialog.add_child(btn_row)
	content_area.add_child(dialog)

func _do_toggle(user_id: int, is_active: bool, reason: String, action_type: String):
	show_status("Đang xử lý...", Color.WHITE)
	var res = await API.staff_toggle_user_status(user_id, is_active, reason, action_type)
	if res["ok"]:
		show_status("%s thành công! Audit log đã ghi." % action_type.capitalize(), Color.GREEN)
		var old_dialog = content_area.get_node_or_null("ToggleDialog")
		if old_dialog: old_dialog.queue_free()
		await _do_search_users()
	else:
		show_status("Lỗi: " + str(res.get("data", "?")), Color.RED)

func _show_audit_log(user_id: int):
	show_status("Đang tải audit log...", Color.WHITE)
	var res = await API.staff_get_user_audit_log(user_id)
	if not res["ok"]:
		show_status("Lỗi tải audit log", Color.RED)
		return

	var data = res["data"]
	var logs = data.get("logs", []) if data is Dictionary else []

	# Remove old log view
	var old = content_area.get_node_or_null("AuditLogView")
	if old: old.queue_free()
	await get_tree().process_frame

	var view = VBoxContainer.new()
	view.name = "AuditLogView"

	var title = Label.new()
	title.text = "📋 Audit Log - User #%d (%s)" % [user_id, str(data.get("email", ""))]
	title.add_theme_font_size_override("font_size", 16)
	view.add_child(title)

	if logs.size() == 0:
		var empty = Label.new()
		empty.text = "Không có log nào."
		view.add_child(empty)
	else:
		for log_entry in logs:
			var row = Label.new()
			row.text = "[%s] %s: %s" % [
				str(log_entry.get("createdAt", "")),
				str(log_entry.get("action", "")),
				str(log_entry.get("details", ""))
			]
			row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			view.add_child(row)

	var close_btn = Button.new()
	close_btn.text = "❌ Đóng"
	close_btn.pressed.connect(func(): view.queue_free())
	view.add_child(close_btn)

	content_area.add_child(view)
	show_status("", Color.WHITE)

# ==============================================================================
# SECTION 2: REPORTS QUEUE
# ==============================================================================
func _load_reports_section():
	show_status("Đang tải reports...", Color.WHITE)

	# Status filter
	var filter_bar = HBoxContainer.new()
	var status_options = ["", "pending", "resolved", "dismissed"]
	for s in status_options:
		var btn = Button.new()
		btn.text = s.capitalize() if s != "" else "Tất cả"
		btn.pressed.connect(func(): _load_reports_with_status(s))
		filter_bar.add_child(btn)
	content_area.add_child(filter_bar)

	_add_separator()
	await _load_reports_with_status("")

func _load_reports_with_status(filter_status: String):
	var res = await API.staff_get_reports(filter_status)
	if not res["ok"]:
		show_status("Lỗi tải reports", Color.RED)
		return

	var data = res["data"]
	all_reports = data.get("reports", []) if data is Dictionary else []

	# Remove old table
	var old_table = content_area.get_node_or_null("ReportTable")
	if old_table: old_table.queue_free()
	await get_tree().process_frame

	var grid = GridContainer.new()
	grid.name = "ReportTable"
	grid.columns = 6
	for h in ["ID", "User", "Loại", "Mô tả", "Status", "Hành động"]:
		var header = Label.new()
		header.text = h
		header.add_theme_color_override("font_color", Color(0.7, 0.7, 1.0))
		grid.add_child(header)

	for r in all_reports:
		_add_cell(grid, str(r.get("id", "")))
		_add_cell(grid, str(r.get("userEmail", "–")))
		_add_cell(grid, str(r.get("type", "–")))

		var desc = Label.new()
		desc.text = str(r.get("description", "")).substr(0, 40)
		desc.clip_text = true
		desc.custom_minimum_size.x = 200
		grid.add_child(desc)

		var status = Label.new()
		var st = str(r.get("status", "pending"))
		status.text = st
		match st:
			"pending": status.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
			"resolved": status.add_theme_color_override("font_color", Color.GREEN)
			"dismissed": status.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		grid.add_child(status)

		var actions = HBoxContainer.new()
		var rid = int(r.get("id", 0))

		var view_btn = Button.new()
		view_btn.text = "🔍 Chi tiết"
		view_btn.pressed.connect(func(): _view_report_detail(rid))
		actions.add_child(view_btn)

		if str(r.get("status", "")) == "pending" or str(r.get("status", "")) == "" or r.get("status") == null:
			var resolve_btn = Button.new()
			resolve_btn.text = "✅ Resolve"
			resolve_btn.pressed.connect(func(): _show_resolve_dialog(rid))
			actions.add_child(resolve_btn)

		grid.add_child(actions)

	content_area.add_child(grid)
	show_status("Đã tải %d reports" % all_reports.size(), Color.WHITE)

func _view_report_detail(report_id: int):
	show_status("Đang tải chi tiết report...", Color.WHITE)
	var res = await API.staff_get_report_detail(report_id)
	if not res["ok"]:
		show_status("Lỗi tải chi tiết", Color.RED)
		return

	var data = res["data"]
	var report = data.get("report", {}) if data is Dictionary else {}
	var sessions = data.get("recentGameSessions", []) if data is Dictionary else []

	# Remove old detail
	var old = content_area.get_node_or_null("ReportDetail")
	if old: old.queue_free()
	await get_tree().process_frame

	var view = VBoxContainer.new()
	view.name = "ReportDetail"

	var title = Label.new()
	title.text = "📋 Report #%d Detail" % report_id
	title.add_theme_font_size_override("font_size", 18)
	view.add_child(title)

	# Report info
	for key in ["type", "description", "status", "resolvedBy", "resolvedAt"]:
		var row = Label.new()
		row.text = "%s: %s" % [key.capitalize(), str(report.get(key, "–"))]
		view.add_child(row)

	# User info
	var user_info = report.get("user", null)
	if user_info is Dictionary:
		var sep = HSeparator.new()
		view.add_child(sep)
		var user_title = Label.new()
		user_title.text = "👤 User: %s (Grade: %s, Region: %s, Active: %s)" % [
			str(user_info.get("email", "")), str(user_info.get("grade", "–")),
			str(user_info.get("region", "–")), str(user_info.get("isActive", "–"))
		]
		view.add_child(user_title)

	# Recent game sessions
	if sessions is Array and sessions.size() > 0:
		var sep2 = HSeparator.new()
		view.add_child(sep2)
		var sessions_title = Label.new()
		sessions_title.text = "🎮 Recent Game Sessions:"
		view.add_child(sessions_title)
		for s in sessions:
			var row = Label.new()
			row.text = "  Game: %s | Score: %s | Accuracy: %s%% | Errors: %s" % [
				str(s.get("gameName", "?")), str(s.get("score", 0)),
				str(s.get("accuracy", 0)), str(s.get("errorCount", 0))
			]
			view.add_child(row)

	var close_btn = Button.new()
	close_btn.text = "❌ Đóng"
	close_btn.pressed.connect(func(): view.queue_free())
	view.add_child(close_btn)

	content_area.add_child(view)
	show_status("", Color.WHITE)

func _show_resolve_dialog(report_id: int):
	var old = content_area.get_node_or_null("ResolveDialog")
	if old: old.queue_free()
	await get_tree().process_frame

	var dialog = VBoxContainer.new()
	dialog.name = "ResolveDialog"

	var title = Label.new()
	title.text = "✅ Resolve Report #%d" % report_id
	title.add_theme_font_size_override("font_size", 16)
	dialog.add_child(title)

	var reason_input = LineEdit.new()
	reason_input.name = "ResolveReason"
	reason_input.placeholder_text = "Nhập lý do xử lý..."
	reason_input.custom_minimum_size.x = 400
	dialog.add_child(reason_input)

	var btn_row = HBoxContainer.new()

	var warn_btn = Button.new()
	warn_btn.text = "⚠️ Warn"
	warn_btn.pressed.connect(func(): _do_resolve(report_id, "warn", reason_input.text))
	btn_row.add_child(warn_btn)

	var ban_btn = Button.new()
	ban_btn.text = "🚫 Ban"
	ban_btn.pressed.connect(func(): _do_resolve(report_id, "ban", reason_input.text))
	btn_row.add_child(ban_btn)

	var dismiss_btn = Button.new()
	dismiss_btn.text = "❌ Dismiss"
	dismiss_btn.pressed.connect(func(): _do_resolve(report_id, "dismiss", reason_input.text, "dismissed"))
	btn_row.add_child(dismiss_btn)

	var cancel_btn = Button.new()
	cancel_btn.text = "🔙 Hủy"
	cancel_btn.pressed.connect(func(): dialog.queue_free())
	btn_row.add_child(cancel_btn)

	dialog.add_child(btn_row)
	content_area.add_child(dialog)

func _do_resolve(report_id: int, action: String, reason: String, status: String = "resolved"):
	show_status("Đang xử lý report...", Color.WHITE)
	var res = await API.staff_resolve_report(report_id, action, reason, status)
	if res["ok"]:
		show_status("Report đã xử lý: %s ✅" % action, Color.GREEN)
		var old = content_area.get_node_or_null("ResolveDialog")
		if old: old.queue_free()
		await _load_reports_with_status("")
	else:
		show_status("Lỗi: " + str(res.get("data", "?")), Color.RED)

# ==============================================================================
# UTILITIES
# ==============================================================================
func _add_cell(grid: GridContainer, text: String):
	var lbl = Label.new()
	lbl.text = text
	grid.add_child(lbl)

func _add_separator():
	var sep = HSeparator.new()
	sep.add_theme_constant_override("separation", 10)
	content_area.add_child(sep)

func show_status(msg: String, color: Color):
	if status_label:
		status_label.text = msg
		status_label.add_theme_color_override("font_color", color)
