extends Control

@onready var signing_in_buttons: VBoxContainer = $SigningInButtons
@onready var sign_in_buttons: VBoxContainer = $SignInButtons

func _ready() -> void:
	signing_in_buttons.visible = false;
	visible = false;

## Show signin screen since we're not logged in.
func _on_not_signed_in() -> void:
	visible = true;

## The user is signed in and ready to go
func _on_signed_in() -> void:
	close()

## Start signing in process
func _on_sign_in_pressed() -> void:
	NG.sign_in()
	
func _on_signin_started():
	signing_in_buttons.visible = true;
	sign_in_buttons.visible = false;
	
## Happens when clicking the cancel button, or if the NG passport
## dialog was declined
func _on_signin_cancel():
	signing_in_buttons.visible = false;
	sign_in_buttons.visible = true;

func close():
	visible = false;
	get_parent().queue_free()
	
func _on_skip_sign_in_pressed() -> void:
	close()

func _on_cancel_sign_in_pressed() -> void:
	NG.sign_in_cancel()
