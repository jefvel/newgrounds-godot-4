@icon("res://addons/newgrounds/icons/medal.png")
extends Node
## A node used for unlocking/listening to a Newgrounds medal.
class_name NewgroundsMedalUnlocker

@export var medal_id: NewgroundsIds.MedalId = 0;

@export var unlocked: bool = false;

signal on_unlocked(medal:MedalResource);

func unlock():
	if unlocked:
		return
	NG.medal_unlock(medal_id)
	pass

func _ready() -> void:
	unlocked = NG.medal_is_unlocked(medal_id);
	NG.on_medals_loaded.connect(_medals_loaded);
	NG.on_medal_unlocked.connect(_on_medal_unlocked);

func _medals_loaded(m: Array[MedalResource]):
	unlocked = NG.medal_is_unlocked(medal_id);
	pass

func _on_medal_unlocked(id:int):
	if id == medal_id:
		on_unlocked.emit(NG.get_medal_resource(id))
		unlocked = true;
