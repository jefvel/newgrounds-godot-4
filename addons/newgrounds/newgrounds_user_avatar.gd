@icon("res://addons/newgrounds/icons/avatar.png")
extends Control

@export var animate_on_set: bool = true;

@onready var image = $NewgroundsImage
@onready var session_watcher:NewgroundsSessionWatcher = $NewgroundsSessionWatcher

func _ready():
	if NG.signed_in:
		image.url = NG.session.user.icons.large;

func _on_newgrounds_session_watcher_on_signed_in():
	image.url = NG.session.user.icons.large;
	pass

func _on_newgrounds_session_watcher_on_signed_out():
	image.url = ''
	pass

@onready var animations = $Animations

var fade_tween: Tween;
func _on_newgrounds_image_on_image_start_loading():
	if fade_tween:
		fade_tween.kill();
	fade_tween = get_tree().create_tween()
	fade_tween.tween_property(image, "modulate:a", 0.6, 0.2)


func _on_newgrounds_image_on_image_loaded(_image):
	if fade_tween:
		fade_tween.kill();
	if animate_on_set:
		animations.play("image_loaded")
	image.modulate.a = 1
