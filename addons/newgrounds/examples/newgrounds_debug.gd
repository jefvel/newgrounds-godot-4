extends Control

@onready var log_in = $"Log In"

func _ready():
	NG.on_session_change.connect(sessionChange)
	NG.on_saves_synced.connect(on_saves_synced)
	sessionChange(NG.session)

func on_saves_synced():
	print("Saves have been synced")

func test():
	pass

@onready var user_name = $Profile/UserName
@onready var user_medal_score = $Profile/UserMedalScore

@onready var example_sign_in_form: Control = $ExampleSignInForm

func sessionChange(s: NewgroundsSession):
	if s.is_signed_in():
		user_name.text = s.user.name
		log_in.text = "Log out";
		refresh_medal_score();
	else:
		user_name.text = "-"
		log_in.text = "Log in";
		user_medal_score.text = '';

func refresh_medal_score():
	var scr = await NG.medal_get_medal_score()
	user_medal_score.text = '%s P' % scr

func _on_log_in_pressed():
	if NG.signed_in:
		NG.sign_out()
	else:
		NG.sign_in()
	pass # Replace with function body.

func _on_check_session_pressed():
	var session = await NG.components.app_check_session().on_success
	print(session)
	pass # Replace with function body.

func _on_check_session_2_pressed():
	var r = await NG.medal_get_list()
	for m in r:
		print("%s - unlocked: %s" % [m.name, m.unlocked])
	refresh_medal_score()
	pass # Replace with function body.

func _on_list_scoreboards_pressed():
	var r = await NG.components.scoreboard_get_boards().on_response
	print(r.data)
	pass # Replace with function body.

func _on_submit_score_pressed():
	$ExampleScoreboard.submit_time(100 + randf() * 40)
	#NG.scoreboard_submit(1230, 123)
	pass # Replace with function body.

func _on_profile_pressed():
	if NG.session.user:
		NG.session.user.open_profile_url();

func _on_load_saveslots_pressed():
	var slots = await NG.cloudsave_load_slots()
	for slot in slots:
		print(slot.timestamp)

func _on_save_slot_pressed():
	var save_slot = $"Save Slot"
	var orig_text = save_slot.text
	save_slot.text = "Saving..."
	await NGCloudSave.save_game()
	save_slot.text = orig_text

func _on_get_slot_data_pressed():
	var btn = $"Get Slot Data"
	var orig_text = btn.text
	btn.text = "Loading..."
	await NGCloudSave.load_game()
	btn.text = orig_text

func _slot_loaded(data):
	print("Loaded data slot with data %s" % data)

func _on_clear_slot_pressed():
	await NG.cloudsave_clear_slot(1)
	get_tree().reload_current_scene()
	pass # Replace with function body.

func _on_newgrounds_session_watcher_on_signed_in():
	print("NewgroundsSessionWatcher: Signed in")
	pass # Replace with function body.

func _on_newgrounds_session_watcher_on_signed_out():
	print("NewgroundsSessionWatcher: Signed out")
	pass # Replace with function body.

func _on_list_medals_2_pressed():
	var r = await NG.medal_unlock(939)
	print(r)
	pass # Replace with function body.

func _on_example_sign_in_form_on_signed_in() -> void:
	example_sign_in_form.visible = false;

func _on_example_sign_in_form_on_sign_in_skipped() -> void:
	example_sign_in_form.visible = false
