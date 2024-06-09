extends Node

const OFFLINE_FILE_NAME = "user://offline_save_data.dat"

enum MedalUnlockState {
	Locked,
	UnlockedLocal,
	UnlockedNewgrounds,
}

# When anonymous, _user_id is 0.
# Once logged in, it'll change. 
var _user_id = 0;

var _medal_unlocks = {};
var _failed_highscore_posts = {};

var _save_slots = {};

func add_failed_medal_unlock(medal_id:int):
	if _medal_unlocks.has(str(medal_id)) and _medal_unlocks[str(medal_id)] == MedalUnlockState.UnlockedNewgrounds:
		return
	_medal_unlocks[str(medal_id)] = MedalUnlockState.UnlockedLocal;
	save()

func set_medal_unlocked(medal_id: int, unlocked = true):
	_medal_unlocks[str(medal_id)] = MedalUnlockState.UnlockedNewgrounds if unlocked else MedalUnlockState.Locked
	save()
	
func is_medal_unlocked(medal_id:int):
	var has_value = _medal_unlocks.has(str(medal_id)) 
	return has_value and _medal_unlocks[str(medal_id)] != MedalUnlockState.Locked

func get_medal_unlock_state(medal_id: int):
	if !_medal_unlocks.has(str(medal_id)):
		return 0;
	return _medal_unlocks[str(medal_id)]
	
func add_failed_scoreboard_post(scoreboard_id: int, score: int):
	var str_key = str(scoreboard_id)
	if !_failed_highscore_posts.has(str_key):
		_failed_highscore_posts[str_key] = {
			"min": score,
			"max": score,
		};
	else:
		var p = _failed_highscore_posts[str_key];
		p.max = max(p.max, score);
		p.min = min(p.min, score);
	save()

func _get_slot_data(slot_id:int):
	if _save_slots.has(str(slot_id)):
		return _save_slots[str(slot_id)]
	
	var data = {
		"id": slot_id,
		"timestamp": 0,
		"data": '',
	}
	
	_save_slots[str(slot_id)] = data
	return data;

func clear_slot_data(slot_id: int):
	var slot = _get_slot_data(slot_id)
	slot.timestamp = 0;
	slot.data = ''
	save();

func store_local_slot_data(slot_id: int, data_string: String, timestamp = int(Time.get_unix_time_from_system())):
	var data = _get_slot_data(slot_id);
	data.data = data_string;
	data.timestamp = timestamp
	save();
	pass
	
## returns local saveslot data if remove save is older
func get_local_slot_data(slot_id: int, remote_timestamp: int):
	var data = _get_slot_data(slot_id)
	if data.timestamp >= remote_timestamp:
		return data.data;
	return ''

func hash_string(d: String):
	var m = d.md5_text();
	return "%s:%s" % [m, Marshalls.utf8_to_base64(d)]

func unhash_string(d: String):
	var splits = d.split(":")
	if splits.size() != 2:
		return '';
	var parsed = Marshalls.base64_to_utf8(splits[1])
	if parsed.md5_text() != splits[0]:
		return ''
	return parsed;

func retry_sending_medals_and_highscores():
	await NG.medal_get_list()
	for medal_id in _medal_unlocks.keys():
		var medal_status = _medal_unlocks[medal_id];
		if medal_status == MedalUnlockState.UnlockedLocal:
			NG.medal_unlock(int(medal_id), true)
	
	var scrs = _failed_highscore_posts
	_failed_highscore_posts = {};
	for scoreboard_id_str in scrs.keys():
		var post = scrs[scoreboard_id_str]
		var scoreboard_id = int(scoreboard_id_str)
		NG.scoreboard_submit(scoreboard_id, post.max)
		if (post.min != post.max):
			NG.scoreboard_submit(scoreboard_id, post.min)
	save();
	
	sync_save_slots()
	
func sync_save_slots():
	var slots = await NG.cloudsave_load_slots();
	for s in slots:
		var local_slot = _get_slot_data(s.id)
		if local_slot.timestamp > s.timestamp:
			await NG.cloudsave_set_data(s.id, local_slot.data)
			#print("uploaded slot #%s to newgrounds" % s.id)
		elif s.timestamp > local_slot.timestamp:
			await NG.cloudsave_get_data(s.id)
			#print("downloaded slot #%s from newgrounds" % s.id)
	
	save()
	pass

func save():
	var s = FileAccess.open(OFFLINE_FILE_NAME, FileAccess.WRITE);
	var data = {
		"_medal_unlocks": _medal_unlocks,
		"_failed_highscore_posts": _failed_highscore_posts,
		"_save_slots": _save_slots
	}
	
	var jsondata = JSON.stringify(data)

	var d = hash_string(jsondata)
	
	s.store_line(d)
	s.close()
	
func load():
	if !FileAccess.file_exists(OFFLINE_FILE_NAME):
		return
	var save_game = FileAccess.open(OFFLINE_FILE_NAME, FileAccess.READ);
	while save_game.get_position() < save_game.get_length():
		var json_string = unhash_string(save_game.get_line())

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
			var value = node_data[i]
			if i == "_failed_highscore_posts" and value is Array:
				_failed_highscore_posts = {};
				for p in value:
					add_failed_scoreboard_post(p.id, p.value)
				continue
			set(i, value)
