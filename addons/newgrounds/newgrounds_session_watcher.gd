@icon("res://addons/newgrounds/icons/session.png")
## A node used for tracking the logged in status of a Newgrounds user. 
class_name NewgroundsSessionWatcher extends Node

var signed_in: bool;

var user_name: String;

var session: NewgroundsSession;

signal on_signed_in();
signal on_signed_out();

func _ready():
	NG.on_session_change.connect(_session_change)
	pass

func _session_change(s: NewgroundsSession):
	session = s;
	var is_signed_in = s.is_signed_in()
	if is_signed_in:
		user_name = s.user.name;
		if !signed_in:
			on_signed_in.emit();
	else:
		if signed_in:
			on_signed_out.emit()
	
	signed_in = is_signed_in

func sign_in():
	if !NG.signed_in:
		NG.sign_in()
	pass
