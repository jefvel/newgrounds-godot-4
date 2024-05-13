extends Control

@onready var text_edit = $TextEdit

var test_text = ""

func _ready():
	NGCloudSave.on_cloudsave_loaded.connect(_on_loaded)
	
func _on_loaded():
	print("ExampleSaveData has been loaded.")
	print(test_text)

func _cloud_save():
	return {
		"test_text": test_text,
	}

func _cloud_set_property(property, value):
	if property == "test_text":
		text_edit.text = value
	pass

func _on_text_edit_text_changed():
	test_text = text_edit.text;
	pass # Replace with function body.
