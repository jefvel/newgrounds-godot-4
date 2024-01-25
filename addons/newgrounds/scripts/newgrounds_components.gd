##  (Mostly for internal use) A node containing predefined API requests to Newgrounds.io
extends Node

var aes_key: String
var app_id: String

var aes = AESContext.new();
var session: NewgroundsSession;

func init(app_id: String, aes_key: String, session: NewgroundsSession):
	self.app_id = app_id
	self.aes_key = aes_key
	self.session = session
	pass

func ping() -> NewgroundsRequest:
	return _request("Gateway.ping", null, "pong")
	
## App session stuff
#############
func app_start_session(force: bool = false) -> NewgroundsRequest:
	return _request("App.startSession", { "force": force }, "session")

func app_end_session() -> NewgroundsRequest:
	return _request("App.endSession", null)

func app_check_session() -> NewgroundsRequest:
	return _request("App.checkSession", null, "session")
	

## Scoreboards
###############
func scoreboard_get_boards() -> NewgroundsRequest:
	return _request("ScoreBoard.getBoards", null, "scoreboards")

func scoreboard_get_scores(scoreboard_id: int, limit:int = 10, skip:int = 0, period: String = "D", social: bool = false, user:String = "", tag: String = "", app_id: String = "") -> NewgroundsRequest:
	var params = {
		"id": scoreboard_id,
		"limit": limit,
		"skip": skip,
		"period": period,
		"social": social,
	}
	if app_id:
		params.app_id = app_id;
	if user:
		params.user = user;
	if tag:
		params.tag = tag;
	return _request("ScoreBoard.getScores", params, "scores")

func scoreboard_post_score(scoreboard_id: int, score: int) -> NewgroundsRequest:
	return _request("ScoreBoard.postScore", {"id": scoreboard_id, "value": score}, "score")

## Medals
############
func medal_get_list(app_id: String = "") -> NewgroundsRequest:
	var data = null
	if app_id != "":
		data = { "app_id": app_id }
	return _request("Medal.getList", data, "medals")

func medal_unlock(medal_id: int) -> NewgroundsRequest:
	return _request("Medal.unlock", { "id": medal_id }, "medal")

func medal_get_medal_score() -> NewgroundsRequest:
	return _request("Medal.getMedalScore", null, "medal_score");

## CloudSave
##############
func cloudsave_load_slots(app_id: String = "") -> NewgroundsRequest:
	var data = null
	if app_id != "":
		data = { "app_id": app_id }
	return _request("CloudSave.loadSlots", data, "slots")

func cloudsave_load_slot(slot_id: int, app_id: String = "") -> NewgroundsRequest:
	var data = { "id": slot_id }
	if app_id != "":
		data.app_id = app_id
	return _request("CloudSave.loadSlot", data, "slot")

func cloudsave_clear_slot(slot_id: int) -> NewgroundsRequest:
	return _request("CloudSave.clearSlot", { "id": slot_id }, "slot")

func cloudsave_set_data(slot_id: int, data: String) -> NewgroundsRequest:
	return _request("CloudSave.setData", { "id": slot_id, "data": data }, "slot")

func cloudsave_get_data(slot_data_url: String) -> NewgroundsRequest:
	#print('Newgrounds: Call CloudSave.getData')

	var request = NewgroundsRequest.new()
	request.init(app_id, aes_key, session, aes)
	add_child(request)
	request.custom_request(slot_data_url)
	return request

func _request(component, parameters, field_name: String = "") -> NewgroundsRequest:
	#print('Newgrounds: Call %s' % component)
	
	var request = NewgroundsRequest.new()
	request.init(app_id, aes_key, session, aes)
	add_child(request)
	
	request.create(component, parameters, field_name)
	return request
