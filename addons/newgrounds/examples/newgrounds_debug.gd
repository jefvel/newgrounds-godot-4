extends Control

@onready var log_in = $"Log In"

func _ready():
	NG.on_session_change.connect(sessionChange)
	sessionChange(NG.session)
	
func test():
	
	pass

@onready var user_name = $Profile/UserName
@onready var user_medal_score = $Profile/UserMedalScore

func sessionChange(s:NewgroundsSession):
	if s.is_signed_in():
		user_name.text = s.user.name
		log_in.text = "Log out";
		var scr = await NG.medal_get_medal_score().on_response
		user_medal_score.text = '%s' % scr.data
	else:
		user_name.text = "-"
		log_in.text = "Log in";
		user_medal_score.text = '';

func _on_log_in_pressed():
	if NG.signed_in:
		NG.sign_out()
	else:
		NG.sign_in()
	pass # Replace with function body.

func _on_check_session_pressed():
	NG.session_check()
	pass # Replace with function body.


func _on_check_session_2_pressed():
	NG.medal_get_list()
	pass # Replace with function body.


func _on_list_scoreboards_pressed():
	NG.scoreboards_get()
	pass # Replace with function body.


func _on_submit_score_pressed():
	$ExampleScoreboard.submit_time(100 + randf() * 40)
	pass # Replace with function body.


func _on_profile_pressed():
	if NG.session.user:
		NG.session.user.open_profile_url();
	pass # Replace with function body.


func _on_load_saveslots_pressed():
	NG.cloudsave_load_slots()
	pass # Replace with function body.


func _on_save_slot_pressed():
	#NG.cloudsave_set_data(1, "TEST DATA HE HE %s" % randi())
	NGCloudSave.save_game(1)
	pass # Replace with function body.


func _on_get_slot_data_pressed():
	NGCloudSave.load_game()
	#NG.cloudsave_get_data(1).on_success.connect(_slot_loaded)
	pass # Replace with function body.

func _slot_loaded(data):
	print("Loaded data slot with data %s" % data)


func _on_clear_slot_pressed():
	NG.cloudsave_clear_slot(1)
	pass # Replace with function body.


func _on_newgrounds_session_watcher_on_signed_in():
	print("NewgroundsSessionWatcher: Signed in")
	pass # Replace with function body.


func _on_newgrounds_session_watcher_on_signed_out():
	print("NewgroundsSessionWatcher: Signed out")
	pass # Replace with function body.
