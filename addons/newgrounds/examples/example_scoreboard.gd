extends Control

@export var data: NewgroundsScoreboard;

@onready var item_list:ItemList = $ItemList
@onready var period:OptionButton = $Control2/Period
@onready var loading_indicator = $ItemList/LoadingIndicator
@onready var scoreboard_name = $"../../Scoreboard Name"

func _ready():
	loading_indicator.visible = false;
	data.on_scores_get.connect(scores_get)
	var name = NewgroundsIds.ScoreboardId.find_key(data.scoreboard_id)
	if data.scoreboard_id != 0 and name:
		scoreboard_name.text = name;
	else:
		if !data.scoreboard_id:
			scoreboard_name.text = "No scoreboard set"
		else:
			scoreboard_name.text = "Unknown scoreboard"
	for e in NewgroundsScoreboard.ScoreboardPeriod.keys():
		period.add_item(e, NewgroundsScoreboard.ScoreboardPeriod.get(e))
	data.scoreboard_period = period.get_item_id(period.selected)

var score_list: Array[NewgroundsScoreboardItem] = [];
func scores_get(scores: Array[NewgroundsScoreboardItem]):
	item_list.clear()
	score_list = scores;
	for score in scores:
		item_list.add_item("[%s] %s - %s" % [score.index, score.user.name, score.formatted_value])
		
	$"Control/Next Page".disabled = data.reached_end
	$"Control/Previous Page".disabled = data.page == 0
	pass


func _on_refresh_pressed():
	data.refresh()
	pass # Replace with function body.


func _on_previous_page_pressed():
	data.previous_page()
	pass # Replace with function body.


func _on_next_page_pressed():
	data.next_page()
	pass # Replace with function body.

func _process(delta):
	loading_indicator.visible = data.refreshing

func _on_period_item_selected(index):
	var v = period.get_item_id(index);
	data.scoreboard_period = v
	pass # Replace with function body.


func _on_item_list_item_clicked(index):
	var s = score_list[index];
	if s.user:
		s.user.open_profile_url()
	pass # Replace with function body.
