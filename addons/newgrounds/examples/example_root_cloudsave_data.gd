extends Node
var hehe = randi_range(0, 1500)
func _ready() -> void:
	add_to_group("CloudSave")

func _cloud_save():
	print("Saving data")
	return {
		"hehe": hehe
	}
	pass
