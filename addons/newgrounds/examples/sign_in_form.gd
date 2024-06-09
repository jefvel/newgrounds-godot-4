extends Control

@onready var signing_in_buttons: VBoxContainer = $SignInForm/SigningInButtons
@onready var sign_in_buttons: VBoxContainer = $SignInForm/SignInButtons
@onready var newgrounds_session_watcher: NewgroundsSessionWatcher = $NewgroundsSessionWatcher

signal on_signed_in;
signal on_sign_in_skipped;

@onready var anim: AnimationPlayer = $Anim

var is_ready = false;

func _ready() -> void:
	visible = false;
	signing_in_buttons.visible = false;
	sign_in_buttons.visible = false;
	is_ready = true;
	newgrounds_session_watcher.refresh_session()

## Show signin screen since we're not logged in.
func _on_not_signed_in() -> void:
	if is_ready and !NG.signing_in and !visible:
		anim.play("show_login")
		visible = true;

## The user is signed in and ready to go
func _on_signed_in() -> void:
	on_signed_in.emit();
	reset_form()

## Start signing in process
func _on_sign_in_pressed() -> void:
	NG.sign_in()
	
func _on_signin_started():
	anim.play("logging_in")
	
## Happens when clicking the cancel button, or if the NG passport
## dialog was declined
func _on_signin_cancel():
	reset_form()
	
func reset_form():
	anim.play("cancel_login")
	
func _on_skip_sign_in_pressed() -> void:
	on_sign_in_skipped.emit()

func _on_cancel_sign_in_pressed() -> void:
	NG.sign_in_cancel()
