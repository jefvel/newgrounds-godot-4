extends Control
## This will show a list of medals. Clicking on a medal will unlock it.

@onready var item_list = $Container/Content/ItemList
var medal_list = [];

func _ready():
	_refresh_list(NG.medals.values())
	NG.medal_get_list()
	NG.on_medal_unlocked.connect(_on_medal_unlocked)
	NG.on_medals_loaded.connect(_refresh_list)
	pass # Replace with function body.

func _on_medal_unlocked(medal_id:int):
	_refresh_list(NG.medals.values())

func _refresh_list(medals):
	item_list.clear()
	var i = 0
	for m in medals:
		var name = m.name
		if m.unlocked:
			name += " (unlocked)"
		item_list.add_item(name, m.icon)
		item_list.set_item_tooltip(i, m.description)
		i += 1;
	medal_list = medals;

func _on_item_list_item_clicked(index):
	NG.medal_unlock(medal_list[index].id)
	pass # Replace with function body.
