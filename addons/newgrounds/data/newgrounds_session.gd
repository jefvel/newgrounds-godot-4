class_name NewgroundsSession

const SESSION_FILE_NAME = 'user://ng_session_data'

var id: String = "";
var user_id: int = 0;
var expired: bool = false;
var passport_url: String = "";
var remember: bool = true;

var user: NewgroundsUser = null;

var _first_set = false;

func reset():
	id = ""
	user_id = 0
	expired = false
	passport_url = ""
	remember = true
	user = null

func is_signed_in():
	return user != null;

func setFromDictionary(d: Dictionary) -> bool:
	var dirty := false

	var new_expired: bool = bool(d.get("expired", expired))
	if expired != new_expired:
		dirty = true
	expired = new_expired

	var new_id: String = str(d.get("id", id))
	if id != new_id:
		dirty = true
	id = new_id

	remember = bool(d.get("remember", remember))

	if d.has("passport_url"):
		passport_url = str(d.passport_url)

	var had_user := user != null
	var previous_user_id := user_id
	var user_data = d.get("user")
	var has_user := user_data is Dictionary
	if has_user:
		user_id = int(user_data.get("id", 0))
		user = NewgroundsUser.fromDict(user_data)
	else:
		user = null
		user_id = 0

	if has_user != had_user or user_id != previous_user_id:
		dirty = true

	if !_first_set:
		dirty = true
		_first_set = true

	return dirty

func save():
	var file = FileAccess.open(SESSION_FILE_NAME, FileAccess.WRITE);
	if file == null:
		push_error("Newgrounds: could not save the session (%s)." % error_string(FileAccess.get_open_error()))
		return

	var data = {
		"id": id,
		"user_id": user_id,
	}

	file.store_line(NG.offline_data.hash_string(JSON.stringify(data)))
	file.close()

func load():
	if !FileAccess.file_exists(SESSION_FILE_NAME):
		return

	var file = FileAccess.open(SESSION_FILE_NAME, FileAccess.READ);
	if file == null:
		push_error("Newgrounds: could not load the session (%s)." % error_string(FileAccess.get_open_error()))
		return

	while file.get_position() < file.get_length():
		var json_string = NG.offline_data.unhash_string(file.get_line())
		if json_string.is_empty():
			continue

		var json = JSON.new()
		if json.parse(json_string) != OK:
			push_warning("Newgrounds: session JSON parse error: %s" % json.get_error_message())
			continue

		var node_data = json.get_data()
		if not (node_data is Dictionary):
			continue

		for i in node_data.keys():
			if i == "id" or i == "user_id":
				set(i, node_data[i])

	file.close()
