extends Node

var app_id:String;
var aes_key:String;
var auto_init: bool;

var session: NewgroundsSession = NewgroundsSession.new();
var session_started: bool = false;

var signing_in: bool = false;
var signed_in : bool = false;

## Emitted when starting session/signing in/checking session/signing out
signal on_session_change(session: NewgroundsSession)

signal on_signed_in();
signal on_signed_out();

var medals: Dictionary = {}
func get_medal_resource(medal_id: int) -> MedalResource:
	if medals.has(medal_id):
		return medals[medal_id];
	return null

### Stores the user's total medal score, fetched with medal_get_medal_score()
var medal_score: int = 0;
signal on_medals_loaded(medals:Array[MedalResource]);
signal on_medal_unlocked(medal:MedalResource);
signal on_medal_score_get(score:int);

var save_slots:Dictionary = {};
signal on_cloudsave_slots_loaded();
signal on_cloudsave_slot_loaded(slot: int);

signal on_cloudsave_set_data(slot: int);
signal on_cloudsave_get_data(slot: int);
signal on_cloudsave_cleared(slot: int);

signal on_scoreboards_loaded(scoreboards);
signal on_highscore_submitted(board_id: int, score: ScoreboardItem)

var aes = AESContext.new();

const C = preload("res://addons/newgrounds/consts.gd")
func _ready():
	_load_session();
	_init_medals();
	
	app_id 		= ProjectSettings.get_setting(C.APP_ID_PROPERTY, "")
	aes_key 	= ProjectSettings.get_setting(C.AES_KEY_PROPERTY, "")
	auto_init 	= ProjectSettings.get_setting(C.AUTO_INIT_PROPERTY, true);
	
	var aes_bytes = Marshalls.base64_to_raw(aes_key)
	var aes_bits = aes_bytes.size() << 3;
	
	assert(aes_bits == 256 || aes_bits == 128, "Newgrounds AES Key Required (Assign it in the project settings)")
	assert(app_id, "Newgrounds App ID Required (Assign it in the project settings)")
	
	if auto_init:
		init();
	pass

func _init_medals():
	var medalMap = NewgroundsIds.MedalIdsToResource.medals;
	for medal_id in medalMap.keys():
		var medal_resource:MedalResource = load(medalMap[medal_id])
		medals[medal_id] = medal_resource;
	pass

func init():
	session_check()

func ping() -> NewgroundsRequest:
	return request("Gateway.ping", null)

## Session stuff
#############
func session_start(force: bool = false) -> NewgroundsRequest:
	return request("App.startSession", { "force": force }, "session", _session_change)

func session_end() -> NewgroundsRequest:
	return request("App.endSession", null, "", _on_session_end)
func _on_session_end(data):
	session = NewgroundsSession.new();
	on_session_change.emit(session)
	on_signed_out.emit();
	pass

func session_check() -> NewgroundsRequest:
	return request("App.checkSession", null, "session", _session_change)

func _session_change(data):
	if (!data.success):
		$Pinger.stop()
		return
	
	var call = data.result.data;
	if (!call.success):
		if !session_started:
			$Pinger.stop()
			session_start()
		return
	
	var s = data.result.data.session;
	var changed = session.setFromDictionary(s)
	
	session_started = true;
	
	if (!signed_in && session.user):
		signed_in = true;
		signing_in = false;
		$Pinger.start()
		on_signed_in.emit()
		medal_get_list();
		session._retry_sending_medals_and_highscores()
		
	_save_session()
	
	if changed:
		on_session_change.emit(session);
	pass

## Scoreboards
###############
func scoreboard_list() -> NewgroundsRequest:
	return request("ScoreBoard.getBoards", null, "scoreboards", _on_scoreboards_get)
func _on_scoreboards_get(m):
	if !m.success:
		return
	var d = m.result.data;
	if !d.success:
		return
	on_scoreboards_loaded.emit(d.scoreboards)

func scoreboard_get_scores(scoreboard_id: int, limit:int = 10, skip:int = 0, period: String = "D", social: bool = false, user:String = "", tag: String = "") -> NewgroundsRequest:
	var params = {
		"id": scoreboard_id,
		"limit": limit,
		"skip": skip,
		"period": period,
		"social": social,
	}
	if user:
		params.user = user;
	if tag:
		params.tag = tag;
	return request("ScoreBoard.getScores", params, "scores")

func scoreboard_submit(scoreboard_id: int, score: int) -> NewgroundsRequest:
	var req = request("ScoreBoard.postScore", {"id": scoreboard_id, "value": score}, "score")
	req.on_success.connect(_on_highscore_submitted.bind(scoreboard_id))
	return req;
func _on_highscore_submitted(score, scoreboard_id):
	on_highscore_submitted.emit(scoreboard_id, ScoreboardItem.fromDict(score));
	pass


func scoreboard_submit_time(scoreboard_id: int, seconds: float) -> NewgroundsRequest:
	return scoreboard_submit(scoreboard_id, int(seconds * 1000.0))


## Medals
############

## Lists medals, emits on_medals_loaded
func medal_get_list() -> NewgroundsRequest:
	var req = request("Medal.getList", null, "medals")
	req.on_success.connect(_on_medals_get)
	return req;
func _on_medals_get(m):
	var medals_list:Array[MedalResource] = [];
	for medal in m:
		var medal_res = get_medal_resource(medal.id)
		if !medal_res:
			medal_res = MedalResource.fromDict(medal);
			medals[medal_res.id] = medal_res;
		else:
			medal_res.unlocked = medal.unlocked
		medals_list.push_back(medal_res)
		
	on_medals_loaded.emit(medals_list)

## Unlocks medal. emits on_medal_unlocked on success
func medal_unlock(medal_id: int) -> NewgroundsRequest:
	var req = request("Medal.unlock", { "id": medal_id }, "medal")
	req.on_success.connect(_on_medal_unlock);
	req.on_error.connect(_on_medal_fail.bind(medal_id));
	return req;
func _on_medal_fail(error, medal_id):
	session._failed_medal_unlocks.push_back(medal_id);
	session.save()
func _on_medal_unlock(m):
	var medal = get_medal_resource(m.id);
	if medal:
		medal.unlocked = true;
	else:
		medal = MedalResource.fromDict(m);
		medals[medal.id] = medal;
	on_medal_unlocked.emit(medal)
	pass

## Fetch the user's total score, emitted by on_medal_score_get
func medal_get_medal_score() -> NewgroundsRequest:
	var req = request("Medal.getMedalScore", null);
	req.on_success.connect(_on_medal_get_medal_score)
	return req;
func _on_medal_get_medal_score(data):
	on_medal_score_get.emit(data.medal_score);

## Signs the user out from newgrounds.io and ends the current session
func sign_out():
	var req = session_end()
	session = NewgroundsSession.new()
	signed_in = false;
	session_started = false;
	signing_in = false;
	$Pinger.stop()
	pass

## Starts a session & launches newgrounds passport in case user
## has not logged in. If logged in, this will do nothing.
func sign_in():
	if (session.is_signed_in() && !session.expired):
		return
	if (!session.passport_url.is_empty()):
		signing_in = true;
		$Pinger.start()
		OS.shell_open(session.passport_url)
	else:
		var req = session_start()
		req.on_success.connect(_retry_signin, CONNECT_ONE_SHOT)
	pass

func _retry_signin(s):
	sign_in();
	
func cloudsave_load_slots() -> NewgroundsRequest:
	var req = request("CloudSave.loadSlots", null)
	req.on_success.connect(_on_cloudsave_slots_loaded)
	return req

func _on_cloudsave_slots_loaded(res):
	for s in res.slots:
		var slot: NewgroundsSaveSlot = _store_slot_data(s)
	
	on_cloudsave_slots_loaded.emit()

func cloudsave_set_data(slot_id: int, data: String) -> NewgroundsRequest:
	var req = request("CloudSave.setData", { "id": slot_id, "data": data })
	req.on_success.connect(_on_cloudsave_set_data.bind(data))
	return req;
	pass

func _on_cloudsave_set_data(res, data):
	var slot: NewgroundsSaveSlot = _store_slot_data(res.slot)
	slot.data = data;
	on_cloudsave_set_data.emit(slot.id)
	pass
	
func cloudsave_clear_slot(slot_id: int) -> NewgroundsRequest:
	var req = request("CloudSave.clearSlot", { "id": slot_id })
	req.on_success.connect(_on_cloudsave_clear_slot)
	return req;
	pass
func _on_cloudsave_clear_slot(data):
	var slot = _store_slot_data(data.slot)
	slot.data = "";
	on_cloudsave_cleared.emit(slot.id);
	pass

func cloudsave_load_slot(slot_id: int) -> NewgroundsRequest:
	var req = request("CloudSave.loadSlot", { "id": slot_id })
	req.on_success.connect(_on_cloudsave_slot_loaded)
	return req
	pass

func _on_cloudsave_slot_loaded(res):
	var slot = _store_slot_data(res.slot)
	on_cloudsave_slot_loaded.emit(slot.id)
	pass

func _store_slot_data(slot_data: Dictionary):
	var slot: NewgroundsSaveSlot
	if save_slots.has(slot_data.id):
		slot = save_slots[slot_data.id]
		slot.setValuesFromDict(slot_data)
	else:
		slot = NewgroundsSaveSlot.fromDict(slot_data)
	save_slots[slot.id] = slot
	return slot;

func cloudsave_get_data(slot_id: int) -> NewgroundsRequest:
	var request = NewgroundsRequest.new()
	request.init(app_id, aes_key, session, aes)
	add_child(request)
	
	var slot_request = cloudsave_load_slot(slot_id);
	slot_request.on_success.connect(_on_cloudsave_data_get_loaded_slot.bind(request))
	
	return request;
	pass
	
func _on_cloudsave_data_get_loaded_slot(res, data_request: NewgroundsRequest):
	var slot = _store_slot_data(res.slot);
	if res.slot.url:
		data_request.custom_request(res.slot.url)
		data_request.on_success.connect(_on_cloudsave_get_data.bind(slot))
	else:
		data_request.on_error.emit("CloudSave slot empty");
	pass

func _on_cloudsave_get_data(data, slot: NewgroundsSaveSlot):
	slot.data = data;
	on_cloudsave_get_data.emit(slot.id)
	pass
	

func request(component, parameters, field_name: String = "", callable = null) -> NewgroundsRequest:
	print(component)
	
	var request = NewgroundsRequest.new()
	request.init(app_id, aes_key, session, aes)
	add_child(request)
	
	if callable:
		request.request_completed.connect(_request_completed.bind(callable))
	
	request.create(component, parameters, field_name)
	return request

func _request_completed(result, response_code, headers, body, callable: Callable):
	var json = JSON.parse_string(body.get_string_from_utf8())
	#print(json)
	if callable:
		callable.call(json)
	pass

func _load_session():
	var _session_id = "";
	
	if OS.has_feature('web'):
		_session_id = str(JavaScriptBridge.eval("""
			var id = new URLSearchParams(window.location.search).get("ngio_session_id");
			id ? id : ""
		""", true))

	session.load();
	
	if _session_id:
		session.id = _session_id;
	pass

func _save_session():
	session.save();

func _notification(what):
	match what:
		NOTIFICATION_WM_WINDOW_FOCUS_IN:
			if signing_in:
				session_check.call_deferred()
			pass
	

