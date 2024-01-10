@icon("res://addons/newgrounds/icons/medal.png")

extends Node
## A node used for unlocking/listening to a Newgrounds medal.
class_name NewgroundsMedalUnlocker

@export var medal_id: NewgroundsIds.MedalId = 0;

var unlocked: bool = false;

signal on_unlock(medal:MedalResource);

func unlock():
	if unlocked:
		return
	var req = NG.medal_unlock(medal_id)
	pass

func _ready():
	var medal = NG.get_medal_resource(medal_id)
	if medal and medal.unlocked:
		unlocked = medal.unlocked;

	NG.on_medals_loaded.connect(_medals_loaded);
	NG.on_medal_unlocked.connect(_on_medal_unlocked);

func _medals_loaded(m: Array[MedalResource]):
	for med in m:
		if med.id == medal_id:
			unlocked = med.unlocked;
			#NG.on_medals_loaded.disconnect(_medals_loaded)
	pass

func _on_medal_unlocked(m:MedalResource):
	if m.id == medal_id:
		on_unlock.emit(m)
		unlocked = true;
		# NG.on_medal_unlocked.disconnect(_on_medal_unlocked)
	
