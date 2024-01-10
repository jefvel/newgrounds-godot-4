class_name NewgroundsSession

const SESSION_FILE_NAME = 'user://ng_session_data'

var id: String = "";
var expired: bool = false;
var passport_url: String = "";
var remember: bool = true;


var user: NewgroundsUser = null;

var _failed_medal_unlocks:Array[int] = [];
var _failed_highscore_posts:Array = [];

func is_signed_in():
	return user != null;

func setFromDictionary(d:Dictionary):
	expired = d.expired;
	id = d.id;
	remember = d.remember;
	
	if (d.has("passport_url")):
		passport_url = d.passport_url;
	if d.user:
		var u = d.user;
		user = NewgroundsUser.fromDict(u);
	

func save():
	var s = FileAccess.open(SESSION_FILE_NAME, FileAccess.WRITE);
	var data = {
		"id": id,
		"_failed_medal_unlocks": _failed_medal_unlocks,
		"_failed_highscore_posts": _failed_highscore_posts,
	}
	var d = Marshalls.utf8_to_base64(JSON.stringify(data))
	s.store_line(d)
	s.close()
	
func load():
	if !FileAccess.file_exists(SESSION_FILE_NAME):
		return
	var save_game = FileAccess.open(SESSION_FILE_NAME, FileAccess.READ);
	while save_game.get_position() < save_game.get_length():
		var json_string = Marshalls.base64_to_utf8(save_game.get_line())

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


func _retry_sending_medals_and_highscores():
	var meds = _failed_medal_unlocks;
	_failed_medal_unlocks = [];
	for medal_id in meds:
		NG.medal_unlock(medal_id)
	
	var scrs = _failed_highscore_posts
	_failed_highscore_posts = [];
	for scr in scrs:
		NG.scoreboard_submit(scr.id, scr.value)
