@icon("res://addons/newgrounds/icons/scoreboard.png")
## A node for fetching and submitting scores to a Newgrounds scoreboard.
class_name NewgroundsScoreboard extends Node

enum ScoreboardPeriod {
	Day,
	Week,
	Month,
	Year,
	All,
}

var refreshing: bool = false;

signal on_scores_get(scores: Array[NewgroundsScoreboardItem]);
signal on_score_submitted(score: NewgroundsScoreboardItem);

@export var scoreboard_id: NewgroundsIds.ScoreboardId = NewgroundsIds.ScoreboardId.None;
@export var scoreboard_period: ScoreboardPeriod = ScoreboardPeriod.All : 
	set = _set_period

func _set_period(p):
	if scoreboard_period == p:
		return
	reached_end = false;
	scoreboard_period = p
	page = 0;
	
	refresh()

## Scores per page
@export_range(1, 100) var page_size: int = 10;

## Fetch scores of friends only
@export var social: bool = false : set = _set_social;
func _set_social(s):
	social = s;
	_test_refresh()

## Fetch only personal scores
@export var own_scores: bool = false : set = _set_own_scores;
func _set_own_scores(o):
	own_scores = o;
	_test_refresh()
	
## Will automatically fetch scores when changing properties
## Otherwise refresh() needs to be called
@export var auto_fetch: bool = true;

var page: int = 0;

var score_tag: String;
var user: String;

var reached_end: bool = false;

var scores: Array[NewgroundsScoreboardItem] = [];

func _test_refresh():
	if auto_fetch:
		refresh();
	pass

func _ready():
	NG.on_signed_in.connect(_signed_in)
	NG.on_highscore_submitted.connect(_on_score_submitted)
	if auto_fetch:
		refresh()
	pass

func _signed_in():
	if auto_fetch and own_scores:
		refresh();

func _on_score_submitted(_scoreboard_id: int, score):
	if auto_fetch and scoreboard_id == _scoreboard_id:
		refresh()

func submit_score(score: int):
	var res = await NG.scoreboard_submit(scoreboard_id, score)
	if !res:
		printerr('could not post score')
		return
	on_score_submitted.emit(res);

func submit_time(time: float):
	return await submit_score(int(time * 1000.0));

func next_page():
	if refreshing or reached_end:
		return
	page += 1;
	refresh();

func previous_page():
	if refreshing:
		return
	reached_end = false;
	page -= 1;
	if page < 0:
		page = 0
	refresh();

var req: NewgroundsRequest
func refresh():
	refreshing = true;
	var period = _getPeriod()
	var skip = page_size * page;
	var limit = page_size;
	var _usr = user;
	if (req && is_instance_valid(req)):
		req.cancel()
	if own_scores:
		if NG.session.user:
			_usr = NG.session.user.name;
		else:
			scores = [];
			refreshing = false;
			return;
	req = NG.components.scoreboard_get_scores(scoreboard_id, limit, skip, period, social, _usr, score_tag)
	req.on_success.connect(_score_get);
	req.on_error.connect(_get_failure)
	pass

func _get_failure(error):
	refreshing = false;

func _score_get(new_scores):
	refreshing = false;
	var index = page * page_size + 1;
	var score_count = new_scores.size()
	
	if score_count < page_size:
		reached_end = true;
		if score_count == 0:
			if page > 0:
				page -= 1;
			else:
				scores = []
			on_scores_get.emit(scores);
			return;
	
	scores = [];
	for score in new_scores:
		var s = NewgroundsScoreboardItem.fromDict(score);
		s.index = index;
		scores.push_back(s)
		index += 1
	
	on_scores_get.emit(scores);
	pass

func _getPeriod():
	match scoreboard_period:
		ScoreboardPeriod.Day:
			return "D"
		ScoreboardPeriod.Week:
			return "W"
		ScoreboardPeriod.Month:
			return "M"
		ScoreboardPeriod.Year:
			return "Y"
		ScoreboardPeriod.All:
			return "A"
	return "D"
