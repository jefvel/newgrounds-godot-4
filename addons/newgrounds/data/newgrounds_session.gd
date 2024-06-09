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
	expired = false
	passport_url = ""
	remember = true
	user = null

func is_signed_in():
	return user != null;

func setFromDictionary(d:Dictionary):
	var dirty = false
	
	if expired != d.expired:
		dirty = true
	expired = d.expired;
	
	if id != d.id:
		dirty = true;
	id = d.id;
	
	remember = d.remember;
	
	if (d.has("passport_url")):
		passport_url = d.passport_url;
	var had_user = user != null
	var has_user = d.user != null
	if has_user:
		var u = d.user;
		user_id = u.id
		user = NewgroundsUser.fromDict(u);
	if has_user != had_user:
		dirty = true
	if !_first_set:
		dirty = true;
		_first_set = true;
	return dirty
	

func save():
	var s = FileAccess.open(SESSION_FILE_NAME, FileAccess.WRITE);
	var data = {
		"id": id,
		"user_id": user_id,
	}
	
	var jsondata = JSON.stringify(data)

	var d = NG.offline_data.hash_string(jsondata)
	
	s.store_line(d)
	s.close()
	
func load():
	if !FileAccess.file_exists(SESSION_FILE_NAME):
		return
	var save_game = FileAccess.open(SESSION_FILE_NAME, FileAccess.READ);
	while save_game.get_position() < save_game.get_length():
		var json_string = NG.offline_data.unhash_string(save_game.get_line())

		# Creates the helper class to interact with JSON
		var json = JSON.new()

		# Check if there is any error while parsing the JSON string, skip in case of failure
		var parse_result = json.parse(json_string)
		if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			continue
		
		# Get the data from the JSON object
		var node_data = json.get_data()
		for i in node_data.keys():
			set(i, node_data[i])
