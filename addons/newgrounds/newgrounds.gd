extends Node

var app_id:String;
var aes_key:String;
var auto_init: bool;

@onready var components = $Components

var session: NewgroundsSession = NewgroundsSession.new();
var session_started: bool = false;

var signing_in: bool = false;
var signed_in : bool = false;

## Emitted when starting session/signing in/signing out
signal on_session_change(session: NewgroundsSession)

signal on_signed_in();
signal on_signed_out();

var medals: Dictionary = {}
func get_medal_resource(medal_id: int) -> MedalResource:
	if medals.has(medal_id):
		return medals[medal_id];
	return null

var medal_score: int = 0; ## Stores the user's total medal score, fetched with medal_get_medal_score()
signal on_medals_loaded(medals:Array[MedalResource]);
signal on_medal_unlocked(medal:MedalResource);
signal on_medal_score_get(score:int);

var save_slots:Dictionary = {};
signal on_cloudsave_slots_loaded();
signal on_cloudsave_slot_loaded(slot: int);

signal on_cloudsave_set_data(slot: int);
signal on_cloudsave_get_data(slot: int);
signal on_cloudsave_cleared(slot: int);

signal on_highscore_submitted(board_id: int, score: NewgroundsScoreboardItem)

var aes = AESContext.new();

const C = preload("res://addons/newgrounds/newgrounds_consts.gd")
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
	
	components.init(app_id, aes_key, session)
	
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
	_refresh_session()

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
		var req = _session_start()
		await req.on_response
		# retry signin
		sign_in()
	pass

## Signs the user out from newgrounds.io and ends the current session
func sign_out():
	await components.app_end_session().on_response
	
	session.reset()
	session.save()
	signed_in = false;
	session_started = false;
	signing_in = false;
	$Pinger.stop()
	
	on_session_change.emit(session)
	on_signed_out.emit();
	pass


func _refresh_session() -> NewgroundsRequest:
	var res = components.app_check_session()
	res.on_response.connect(_session_change)
	return res

## Session stuff
#############
func _session_start(force: bool = false) -> NewgroundsRequest:
	var req = components.app_start_session()
	req.on_response.connect(_session_change)
	return req
	#return request("App.startSession", { "force": force }, "session", _session_change)

func _session_change(data:NewgroundsResponse):
	if (data.error):
		if !session_started:
			$Pinger.stop()
			_session_start()
		return
	
	var s = data.data;
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

func scoreboard_submit(scoreboard_id: int, score: int) -> NewgroundsScoreboardItem:
	var req = await components.scoreboard_post_score(scoreboard_id, score).on_response
	if req.error:
		return null
	return NewgroundsScoreboardItem.fromDict(req.data);
func scoreboard_submit_time(scoreboard_id: int, seconds: float) -> NewgroundsScoreboardItem:
	return await scoreboard_submit(scoreboard_id, int(seconds * 1000.0))

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
	var req = components.medal_unlock(medal_id)
	req.on_response.connect(_medal_unlock_response.bind(medal_id))
	return req;

func _medal_unlock_response(res, medal_id):
	if res.error:
		session._failed_medal_unlocks.push_back(medal_id);
		session.save()
		return
	
	var m = res.data;
	var medal = get_medal_resource(medal_id);
	if medal:
		medal.unlocked = true;
	else:
		medal = MedalResource.fromDict(m);
		medals[medal.id] = medal;
	on_medal_unlocked.emit(medal)
	pass

## Fetch the user's total score, emitted by on_medal_score_get
func medal_get_medal_score() -> int:
	var req = await components.medal_get_medal_score().on_response
	on_medal_score_get.emit(req.data)
	return req.data;

## CLoudsave stuff
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
	
	var slot_request = components.cloudsave_load_slot(slot_id);
	slot_request.on_response.connect(_on_cloudsave_data_get_loaded_slot.bind(request))
	
	return request;
	pass
	
func _on_cloudsave_data_get_loaded_slot(res:NewgroundsResponse, data_request: NewgroundsRequest):
	var slot = _store_slot_data(res.data);
	if !res.error and res.data.url:
		data_request.custom_request(res.data.url)
		var loadRes = await data_request.on_response # .connect(_on_cloudsave_get_data.bind(slot))
		
		if loadRes.error:
			data_request.on_error.emit("Failed to load cloudsave")
			return
		
		slot.data = loadRes.data
		on_cloudsave_get_data.emit(slot.id)
	else:
		data_request.on_error.emit("CloudSave slot empty");
	pass

func _on_cloudsave_get_data(data, slot: NewgroundsSaveSlot):
	slot.data = data.data;
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
				_refresh_session.call_deferred()
			pass
	

