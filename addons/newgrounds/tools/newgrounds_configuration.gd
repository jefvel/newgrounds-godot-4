@tool
extends Control

## Editor panel for writing the Newgrounds App ID and AES key into `.env`.
## Shown as a tab in Project Settings, and in a window from Project > Tools.


const C = preload("res://addons/newgrounds/scripts/newgrounds_consts.gd")
const DotEnv = preload("res://addons/newgrounds/scripts/newgrounds_dotenv.gd")
const Config = preload("res://addons/newgrounds/scripts/newgrounds_config.gd")

@onready var _app_id_edit: LineEdit = $Container/Settings/GridContainer/AppId
@onready var _aes_key_edit: LineEdit = $Container/Settings/GridContainer/AppSecret
@onready var _status: Label = $Container/Settings/Status

func _ready() -> void:
	_load()
	_app_id_edit.text_changed.connect(_on_text_submitted)
	_aes_key_edit.text_changed.connect(_on_text_submitted)
	#_app_id_edit.text_submitted.connect(_on_text_submitted)
	#_aes_key_edit.text_submitted.connect(_on_text_submitted)
	visibility_changed.connect(_on_visibility_changed)
	_app_id_edit.grab_focus()

func _on_visibility_changed() -> void:
	if visible:
		_load()

func _load() -> void:
	var values := DotEnv.load_file(C.ENV_FILE)
	_app_id_edit.text = str(values.get(C.ENV_APP_ID, ""))
	_aes_key_edit.text = str(values.get(C.ENV_AES_KEY, ""))
	_set_status("Stored in %s. That file is gitignored and copied into the exported game." % C.ENV_FILE)

func _on_text_submitted(_text: String) -> void:
	_save()

func _save() -> void:
	var app_id := _app_id_edit.text.strip_edges()
	var aes_key := _aes_key_edit.text.strip_edges()

	if app_id.is_empty():
		_set_status("Enter the App ID from your Newgrounds project page.", true)
		return
	if aes_key.is_empty():
		_set_status("Enter the AES key from your Newgrounds project page.", true)
		return

	var key_bits := 0
	if _is_base64(aes_key):
		key_bits = Marshalls.base64_to_raw(aes_key).size() * 8
	if key_bits != 128 and key_bits != 256:
		_set_status("The AES key must be a base64-encoded 128-bit or 256-bit key.", true)
		return

	var err := DotEnv.save_values(C.ENV_FILE, {
		C.ENV_APP_ID: app_id,
		C.ENV_AES_KEY: aes_key,
	})
	if err != OK:
		_set_status("Could not write %s: %s" % [C.ENV_FILE, error_string(err)], true)
		return

	Config.reload()
	print("Newgrounds: saved App ID and AES key to %s" % C.ENV_FILE)
	_set_status("Saved to %s." % C.ENV_FILE)

func _set_status(message: String, is_error: bool = false) -> void:
	_status.text = message
	_status.modulate = Color(1.0, 0.45, 0.45) if is_error else Color(1.0, 1.0, 1.0, 0.65)

static func _is_base64(value: String) -> bool:
	if value.length() % 4 != 0:
		return false
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9+/]+={0,2}$")
	return regex.search(value) != null
