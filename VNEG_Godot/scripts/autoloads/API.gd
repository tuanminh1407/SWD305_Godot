extends Node
## VNEG_Godot/scripts/autoloads/API.gd
##
## Quản lý HTTP Requests tới ASP.NET Backend.
## Sử dụng node HTTPRequest để gọi các RESTful APIs.

const API_BASE = "http://localhost:5290" # Thay đổi port tương ứng với file launchSettings.json

## Hàm tiện ích để thực hiện HTTP Request.
## Trả về một Dictionary có dạng: { "ok": bool, "status": int, "data": Variant }
func fetch(path: String, method: int = HTTPClient.METHOD_GET, body: Dictionary = {}) -> Dictionary:
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var url = API_BASE + path
	var headers = ["Content-Type: application/json"]
	
	# Đính kèm Session Token nếu đã đăng nhập (sử dụng AuthManager Autoload)
	if AuthManager.get_token() != "":
		headers.append("X-Session-Token: " + AuthManager.get_token())
	
	var json_body = ""
	if method != HTTPClient.METHOD_GET and body.size() > 0:
		json_body = JSON.stringify(body)
		
	var err = http_request.request(url, headers, method, json_body)
	if err != OK:
		http_request.queue_free()
		return { "ok": false, "status": 0, "data": "Lỗi kết nối mạng: " + str(err) }
		
	# Đợi tín hiệu request_completed
	var result = await http_request.request_completed
	
	# result là một mảng: [result (int), response_code (int), headers (PackedStringArray), body (PackedByteArray)]
	var res_code = result[1]
	var res_body_bytes = result[3]
	
	http_request.queue_free()
	
	var data = null
	if res_body_bytes.size() > 0:
		var json = JSON.new()
		var parse_err = json.parse(res_body_bytes.get_string_from_utf8())
		if parse_err == OK:
			data = json.data
		else:
			# Fallback if the body is a plain text string
			data = res_body_bytes.get_string_from_utf8()
			
	var is_ok = (res_code >= 200 and res_code < 300)
	
	print("API Response [", method, "] ", url)
	print("-> Code: ", res_code)
	print("-> Data: ", data)
	
	# If the backend returned a string and it's not JSON, Godot's JSON.parse might fail 
	# or it might return the string directly. We handled it above.
	return { "ok": is_ok, "status": res_code, "data": data }

# ==============================================================================
# AUTH API
# ==============================================================================

func register(email:String, password:String, phone:String, grade:int, region:String, avatar:String) -> Dictionary:
	var payload = {
		"email": email,
		"password": password,
		"grade": grade,
		"region": region,
		"avatarUrl": avatar,
		"phone": phone
	}
	return await fetch("/api/users/register", HTTPClient.METHOD_POST, payload)

func login(email: String, password: String) -> Dictionary:
	var payload = {
		"email": email,
		"password": password
	}
	return await fetch("/api/users/login", HTTPClient.METHOD_POST, payload)

func logout() -> Dictionary:
	var payload = { "token": AuthManager.get_token() }
	var res = await fetch("/api/users/logout", HTTPClient.METHOD_POST, payload)
	AuthManager.clear_session()
	return res

# ==============================================================================
# GAMES API
# ==============================================================================

func get_games_by_map(map_id: int) -> Dictionary:
	return await fetch("/api/game/by-map/" + str(map_id))

func start_game(user_id: int, game_id: int) -> Dictionary:
	var payload = { "userId": user_id, "gameId": game_id }
	return await fetch("/api/game/start", HTTPClient.METHOD_POST, payload)

func get_questions(session_id: int) -> Dictionary:
	return await fetch("/api/game/" + str(session_id) + "/questions")

func submit_answers(session_id: int, answers: Array) -> Dictionary:
	# answers: Array của Dictionary -> [{ "questionId": 1, "selectedAnswerId": 0 }, ...]
	var payload = { "answers": answers }
	return await fetch("/api/game/" + str(session_id) + "/submit", HTTPClient.METHOD_POST, payload)

# ==============================================================================
# MAPPING CÁC API KHÁC THEO NHU CẦU...
# ==============================================================================
func get_maps() -> Dictionary:
	return await fetch("/api/maps")
	
func get_grammar_progress() -> Dictionary:
	return await fetch("/api/grammar/progress/me")

# ==============================================================================
# ADMIN ANALYTICS API
# ==============================================================================
func admin_get_user_stats() -> Dictionary:
	return await fetch("/api/admin/analytics/user-stats")

func admin_get_retention() -> Dictionary:
	return await fetch("/api/admin/analytics/retention")

func admin_get_demographics() -> Dictionary:
	return await fetch("/api/admin/analytics/demographics")

func admin_get_system_health() -> Dictionary:
	return await fetch("/api/admin/analytics/system-health")

func admin_get_content_reports() -> Dictionary:
	return await fetch("/api/admin/analytics/content-reports")

func admin_get_error_hotspots() -> Dictionary:
	return await fetch("/api/admin/analytics/error-hotspots")

func admin_get_audit_logs(filters: Dictionary = {}) -> Dictionary:
	var query = "/api/admin/analytics/audit-logs?"
	for key in filters.keys():
		query += str(key) + "=" + str(filters[key]) + "&"
	return await fetch(query.rstrip("&"))

# ==============================================================================
# ADMIN CRUD API
# ==============================================================================
func admin_get_users() -> Dictionary:
	return await fetch("/api/admin/users")

func admin_set_user_active(user_id: int, is_active: bool) -> Dictionary:
	return await fetch("/api/admin/users/" + str(user_id) + "/active", HTTPClient.METHOD_PATCH, {"isActive": is_active})

func admin_set_user_role(user_id: int, role: String) -> Dictionary:
	return await fetch("/api/admin/users/" + str(user_id) + "/role", HTTPClient.METHOD_PATCH, {"role": role})

func admin_get_games() -> Dictionary:
	return await fetch("/api/admin/games")

func admin_create_game(dto: Dictionary) -> Dictionary:
	return await fetch("/api/admin/games", HTTPClient.METHOD_POST, dto)

func admin_update_game(game_id: int, dto: Dictionary) -> Dictionary:
	return await fetch("/api/admin/games/" + str(game_id), HTTPClient.METHOD_PUT, dto)

func admin_delete_game(game_id: int) -> Dictionary:
	return await fetch("/api/admin/games/" + str(game_id), HTTPClient.METHOD_DELETE)

func admin_get_grammar_topics() -> Dictionary:
	return await fetch("/api/admin/grammar-topics")

func admin_create_grammar_topic(dto: Dictionary) -> Dictionary:
	return await fetch("/api/admin/grammar-topics", HTTPClient.METHOD_POST, dto)

func admin_update_grammar_topic(topic_id: int, dto: Dictionary) -> Dictionary:
	return await fetch("/api/admin/grammar-topics/" + str(topic_id), HTTPClient.METHOD_PUT, dto)

func admin_delete_grammar_topic(topic_id: int) -> Dictionary:
	return await fetch("/api/admin/grammar-topics/" + str(topic_id), HTTPClient.METHOD_DELETE)

func admin_get_questions() -> Dictionary:
	return await fetch("/api/admin/questions")

func admin_create_question(dto: Dictionary) -> Dictionary:
	return await fetch("/api/admin/questions", HTTPClient.METHOD_POST, dto)

func admin_update_question(q_id: int, dto: Dictionary) -> Dictionary:
	return await fetch("/api/admin/questions/" + str(q_id), HTTPClient.METHOD_PUT, dto)

func admin_delete_question(q_id: int) -> Dictionary:
	return await fetch("/api/admin/questions/" + str(q_id), HTTPClient.METHOD_DELETE)

# ==============================================================================
# STAFF API
# ==============================================================================
func staff_get_users(filters: Dictionary = {}) -> Dictionary:
	var query = "/api/staff/users?"
	for key in filters.keys():
		query += str(key) + "=" + str(filters[key]) + "&"
	return await fetch(query.rstrip("&"))

func staff_toggle_user_status(user_id: int, is_active: bool, reason: String = "", action_type: String = "") -> Dictionary:
	var body = {"isActive": is_active, "reason": reason, "actionType": action_type}
	return await fetch("/api/staff/users/" + str(user_id) + "/status", HTTPClient.METHOD_PATCH, body)

func staff_get_user_audit_log(user_id: int) -> Dictionary:
	return await fetch("/api/staff/users/" + str(user_id) + "/audit-log")

func staff_get_reports(status: String = "", page: int = 1) -> Dictionary:
	var query = "/api/staff/reports?page=" + str(page)
	if status != "":
		query += "&status=" + status
	return await fetch(query)

func staff_get_report_detail(report_id: int) -> Dictionary:
	return await fetch("/api/staff/reports/" + str(report_id))

func staff_resolve_report(report_id: int, action: String, reason: String = "", status: String = "resolved") -> Dictionary:
	var body = {"action": action, "reason": reason, "status": status}
	return await fetch("/api/staff/reports/" + str(report_id) + "/resolve", HTTPClient.METHOD_PATCH, body)

# TEAM TASKS (STUDY & TEST) API
# ==============================================================================

func get_team_tasks(team_id: int) -> Dictionary:
	return await fetch("/api/tasks/team/" + str(team_id))

func create_team_task(team_id: int, game_id: int, reward: String = "100_coins") -> Dictionary:
	var payload = {
		"teamId": team_id,
		"gameId": game_id,
		"reward": reward
	}
	return await fetch("/api/tasks", HTTPClient.METHOD_POST, payload)

func start_team_task(task_id: int) -> Dictionary:
	return await fetch("/api/tasks/" + str(task_id) + "/start", HTTPClient.METHOD_POST)

func complete_team_task(task_id: int, session_id: int) -> Dictionary:
	return await fetch("/api/tasks/" + str(task_id) + "/complete", HTTPClient.METHOD_POST, {"sessionId": session_id})

# ==============================================================================
# USER SEARCH & TEAM MANAGEMENT EXTENSIONS
# ==============================================================================

func search_users(query: String) -> Dictionary:
	return await fetch("/api/users/search?q=" + query.uri_encode())

func add_team_member(team_id: int, user_id: int) -> Dictionary:
	return await fetch("/api/team-owner/" + str(team_id) + "/add-member", HTTPClient.METHOD_POST, {"userId": user_id})

# ==============================================================================
# USER PROFILE EXTENSIONS
# ==============================================================================

func update_me(data: Dictionary) -> Dictionary:
	return await fetch("/api/users/me", HTTPClient.METHOD_PUT, data)

func upload_image(file_path: String) -> Dictionary:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return {"ok": false, "data": "Cannot open file"}
	
	var content = file.get_buffer(file.get_length())
	file.close()
	
	var boundary = "----GodotBoundary" + str(Time.get_ticks_msec())
	var headers = [
		"Content-Type: multipart/form-data; boundary=" + boundary,
		"X-Session-Token: " + AuthManager.get_token()
	]
	
	var body = PackedByteArray()
	body.append_array(("--" + boundary + "\r\n").to_utf8_buffer())
	body.append_array(("Content-Disposition: form-data; name=\"file\"; filename=\"" + file_path.get_file() + "\"\r\n").to_utf8_buffer())
	body.append_array(("Content-Type: image/" + file_path.get_extension() + "\r\n\r\n").to_utf8_buffer())
	body.append_array(content)
	body.append_array(("\r\n--" + boundary + "--\r\n").to_utf8_buffer())
	
	var http_request = HTTPRequest.new()
	add_child(http_request)
	
	var url = API_BASE + "/api/upload"
	var err = http_request.request_raw(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		http_request.queue_free()
		return {"ok": false, "data": "Request error"}
		
	var result = await http_request.request_completed
	http_request.queue_free()
	
	var res_code = result[1]
	var res_body = result[3].get_string_from_utf8()
	
	var json = JSON.new()
	var parse_err = json.parse(res_body)
	var data = json.data if parse_err == OK else res_body
	
	return {"ok": res_code >= 200 and res_code < 300, "data": data}
