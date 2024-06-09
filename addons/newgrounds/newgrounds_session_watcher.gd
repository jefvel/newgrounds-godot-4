@icon("res://addons/newgrounds/icons/session.png")
## A node used for tracking the logged in status of a Newgrounds user. 
class_name NewgroundsSessionWatcher extends Node

var signed_in: bool;

var user_name: String;

var session: NewgroundsSession;

## Emitted once the player is confirmed to be signed in and ready.
signal on_signed_in();
## Emitted when the player is not signed in to newgrounds after checking the session
signal on_not_signed_in;

## Emitted when the player initiates the sign in process
signal on_signin_started;
## Emitted if the user manually cancels the sign in or declines the Newgrounds Passport prompt
signal on_signin_cancelled;

## Emitted once the user has manually signed out.
signal on_signed_out();

signal on_session_change(s: NewgroundsSession);

func _ready():
	NG.on_session_change.connect(_session_change)
	NG.on_signin_cancelled.connect(on_signin_cancelled.emit)
	NG.on_signin_started.connect(on_signin_started.emit)
	refresh_session()
	pass

func refresh_session():
	if !NG.refreshing_session:
		if NG.signed_in:
			on_signed_in.emit();
		else:
			NG.refresh_session()
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
	
	if !is_signed_in:
		_is_signed_out()
		
	signed_in = is_signed_in
	
	on_session_change.emit(s);
	
func _is_signed_out():
	on_not_signed_in.emit()

func sign_in():
	if !NG.signed_in:
		NG.sign_in()
	pass
