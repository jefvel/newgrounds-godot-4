@tool
extends Control

signal import_requested

const C = preload("res://addons/newgrounds/scripts/newgrounds_consts.gd")
const DotEnv = preload("res://addons/newgrounds/scripts/newgrounds_dotenv.gd")
const Config = preload("res://addons/newgrounds/scripts/newgrounds_config.gd")

@onready var _app_id_edit: LineEdit = $Container/Settings/GridContainer/AppId
@onready var _aes_key_edit: LineEdit = $Container/Settings/GridContainer/AppSecret
@onready var _status: Label = $Container/Settings/Status

@onready var auto_init: CheckBox = $Container/Settings/VBoxContainer/AutoInit

@onready var select_dir: Button = $Container/Settings/HBoxContainer/SelectDir

@onready var resource_dir: LineEdit = $Container/Settings/HBoxContainer/ResourceDir

@onready var import_from_newgrounds: Button = $Container/Settings/VBoxContainer2/VBoxContainer/ImportFromNewgrounds
@onready var import_result: Label = $Container/Settings/VBoxContainer2/ImportResult
@onready var reload_project: Button = $"Container/Settings/VBoxContainer2/VBoxContainer/Reload Project"

var _loading := false
var _dir_dialog: EditorFileDialog

func _ready() -> void:
	_dir_dialog = EditorFileDialog.new()
	_dir_dialog.title = "Select the folder for imported medal resources"
	_dir_dialog.file_mode = EditorFileDialog.FILE_MODE_OPEN_DIR
	_dir_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_dir_dialog.dir_selected.connect(_on_dir_selected)
	add_child(_dir_dialog)

	_load()
	_app_id_edit.text_changed.connect(_on_text_submitted)
	_aes_key_edit.text_changed.connect(_on_text_submitted)
	auto_init.toggled.connect(_on_auto_init_toggled)
	resource_dir.text_submitted.connect(_on_resource_dir_submitted)
	resource_dir.focus_exited.connect(_on_resource_dir_focus_exited)
	select_dir.pressed.connect(_on_select_dir_pressed)
	import_from_newgrounds.pressed.connect(_on_import_pressed)
	reload_project.pressed.connect(_on_reload_project_pressed)
	reload_project.visible = false
	visibility_changed.connect(_on_visibility_changed)
	_app_id_edit.grab_focus()

func _on_visibility_changed() -> void:
	if visible:
		_load()

func _load() -> void:
	_loading = true
	var values := DotEnv.load_file(C.ENV_FILE)
	_app_id_edit.text = str(values.get(C.ENV_APP_ID, ""))
	_aes_key_edit.text = str(values.get(C.ENV_AES_KEY, ""))
	auto_init.button_pressed = bool(ProjectSettings.get_setting(C.AUTO_INIT_PROPERTY, true))
	resource_dir.text = str(ProjectSettings.get_setting(C.IMPORTED_MEDALS_LOCATION_PROPERTY, C.MEDALS_PATH))
	_loading = false
	_set_status("Stored in %s. That file is gitignored and copied into the exported game." % C.ENV_FILE)

func _on_text_submitted(_text: String) -> void:
	if _loading:
		return
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

func _on_auto_init_toggled(enabled: bool) -> void:
	if _loading:
		return
	ProjectSettings.set_setting(C.AUTO_INIT_PROPERTY, enabled)
	ProjectSettings.save()

func _on_resource_dir_submitted(_text: String) -> void:
	_save_resource_dir()

func _on_resource_dir_focus_exited() -> void:
	_save_resource_dir()

func _save_resource_dir() -> void:
	if _loading:
		return

	var path := resource_dir.text.strip_edges().replace("\\", "/")
	if path.is_empty():
		_set_result("Enter a folder for the generated medal resources.", true)
		resource_dir.text = str(ProjectSettings.get_setting(C.IMPORTED_MEDALS_LOCATION_PROPERTY, C.MEDALS_PATH))
		return
	if not (path.begins_with("res://") or path.begins_with("user://")):
		_set_result("The folder must be inside the project (res://...) or user://.", true)
		resource_dir.text = str(ProjectSettings.get_setting(C.IMPORTED_MEDALS_LOCATION_PROPERTY, C.MEDALS_PATH))
		return

	if path != "res://" and path != "user://" and path.ends_with("/"):
		path = path.substr(0, path.length() - 1)
	resource_dir.text = path

	var current := str(ProjectSettings.get_setting(C.IMPORTED_MEDALS_LOCATION_PROPERTY, C.MEDALS_PATH))
	if path == current:
		return

	ProjectSettings.set_setting(C.IMPORTED_MEDALS_LOCATION_PROPERTY, path)
	ProjectSettings.save()
	_set_result("Imported medals will be saved to %s." % path)

func _on_select_dir_pressed() -> void:
	var current := resource_dir.text.strip_edges()
	if not current.is_empty() and DirAccess.dir_exists_absolute(current):
		_dir_dialog.current_dir = current
	_dir_dialog.popup_centered_ratio(0.5)

func _on_dir_selected(dir: String) -> void:
	resource_dir.text = dir
	_save_resource_dir()

func _on_import_pressed() -> void:
	if get_signal_connection_list("import_requested").is_empty():
		_set_result("The Newgrounds editor plugin is not loaded.", true)
		return
	import_from_newgrounds.disabled = true
	reload_project.visible = false
	_set_result("Importing medals and leaderboards from Newgrounds...")
	import_requested.emit()

func _on_reload_project_pressed() -> void:
	EditorInterface.restart_editor(true)

func show_import_result(success: bool, message: String) -> void:
	import_from_newgrounds.disabled = false
	if success:
		reload_project.visible = true
	_set_result(message, not success)

func _set_status(message: String, is_error: bool = false) -> void:
	_status.text = message
	_status.modulate = Color(1.0, 0.45, 0.45) if is_error else Color(1.0, 1.0, 1.0, 0.65)

func _set_result(message: String, is_error: bool = false) -> void:
	import_result.text = message
	import_result.modulate = Color(1.0, 0.45, 0.45) if is_error else Color(1.0, 1.0, 1.0, 0.65)

static func _is_base64(value: String) -> bool:
	if value.length() % 4 != 0:
		return false
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9+/]+={0,2}$")
	return regex.search(value) != null
