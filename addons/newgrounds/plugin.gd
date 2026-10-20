@tool
extends EditorPlugin

const C = preload("res://addons/newgrounds/scripts/newgrounds_consts.gd")
const DotEnv = preload("res://addons/newgrounds/scripts/newgrounds_dotenv.gd")
const Exporter = preload("res://addons/newgrounds/tools/newgrounds_exporter.gd")
const Config = preload("res://addons/newgrounds/scripts/newgrounds_config.gd")

signal import_finished(success: bool, message: String)

var _exporter: EditorExportPlugin
var _project_settings_tab: Control

func _enter_tree():
	_migrate_legacy_credentials()

	add_project_setting(C.AUTO_INIT_PROPERTY, true, TYPE_BOOL, PROPERTY_HINT_NONE, "", false)
	add_project_setting(C.IMPORTED_MEDALS_LOCATION_PROPERTY, C.MEDALS_PATH, TYPE_STRING, PROPERTY_HINT_DIR, "", false)

	_exporter = Exporter.new()
	add_export_plugin(_exporter)

	_add_project_settings_tab()

	if not ProjectSettings.has_setting("global_group/CloudSave"):
		ProjectSettings.set_setting("global_group/CloudSave", "Newgrounds Cloudsave")

	_migrate_ids_file()

	if !FileAccess.file_exists(_get_ids_path()):
		_write_template_file([], [])

	if !ProjectSettings.has_setting("autoload/%s" % C.NEWGROUNDS_AUTOLOAD_NAME):
		add_autoload_singleton(C.NEWGROUNDS_AUTOLOAD_NAME, C.NEWGROUNDS_AUTOLOAD_NODE)
	if !ProjectSettings.has_setting("autoload/%s" % C.CLOUDSAVE_AUTOLOAD_NAME):
		add_autoload_singleton(C.CLOUDSAVE_AUTOLOAD_NAME, C.CLOUDSAVE_AUTOLOAD_NODE)

	ProjectSettings.save()

func _exit_tree():
	remove_autoload_singleton(C.NEWGROUNDS_AUTOLOAD_NAME)
	remove_autoload_singleton(C.CLOUDSAVE_AUTOLOAD_NAME)

	if is_instance_valid(_project_settings_tab):
		remove_control_from_container(CONTAINER_PROJECT_SETTING_TAB_RIGHT, _project_settings_tab)
		_project_settings_tab.queue_free()
		_project_settings_tab = null
	if is_instance_valid(_exporter):
		remove_export_plugin(_exporter)
		_exporter = null
	pass

func _add_project_settings_tab() -> void:
	_project_settings_tab = preload(C.CONFIG_SCENE).instantiate()
	_project_settings_tab.name = "Newgrounds"
	add_control_to_container(CONTAINER_PROJECT_SETTING_TAB_RIGHT, _project_settings_tab)
	if _project_settings_tab.has_signal("import_requested"):
		_project_settings_tab.connect("import_requested", _import_newgrounds)
	if _project_settings_tab.has_signal("medals_dir_changed"):
		_project_settings_tab.connect("medals_dir_changed", _on_medals_dir_changed)
	if not import_finished.is_connected(_on_import_finished):
		import_finished.connect(_on_import_finished)

func _on_medals_dir_changed(old_dir: String, _new_dir: String) -> void:
	var ids_path := _get_ids_path()
	var previous_path := str(ProjectSettings.get_setting(C.LAST_IDS_PATH_PROPERTY, ""))
	if previous_path.is_empty():
		previous_path = _ids_path_for_dir(old_dir)

	var moved := _move_ids_file(previous_path, ids_path)
	moved = _move_ids_file(C.LEGACY_IDS_FILE_PATH, ids_path) or moved

	ProjectSettings.set_setting(C.LAST_IDS_PATH_PROPERTY, ids_path)
	ProjectSettings.set_as_internal(C.LAST_IDS_PATH_PROPERTY, true)
	ProjectSettings.save()

	if moved and is_instance_valid(_project_settings_tab):
		_project_settings_tab.call("show_import_result", true, "Moved the Newgrounds IDs file to %s. Reload the project to apply the change." % ids_path)

func _on_import_finished(success: bool, message: String) -> void:
	if is_instance_valid(_project_settings_tab):
		_project_settings_tab.call("show_import_result", success, message)

## Directory the generated medal resources and IDs file are written to.
func _get_medals_dir() -> String:
	var dir := str(ProjectSettings.get_setting(C.IMPORTED_MEDALS_LOCATION_PROPERTY, C.MEDALS_PATH)).strip_edges().replace("\\", "/")
	if dir.is_empty():
		dir = C.MEDALS_PATH
	if dir.ends_with("/") and dir != "res://" and dir != "user://":
		dir = dir.substr(0, dir.length() - 1)
	return dir

func _get_ids_path() -> String:
	return _ids_path_for_dir(_get_medals_dir())

func _ids_path_for_dir(dir: String) -> String:
	var normalized := dir.strip_edges().replace("\\", "/")
	if normalized.ends_with("/"):
		return normalized + C.IDS_FILE_NAME
	return normalized + "/" + C.IDS_FILE_NAME

## Moves the generated IDs file out of its old location so there is only one
## `NewgroundsIds` class in the project.
func _migrate_ids_file() -> void:
	var ids_path := _get_ids_path()
	var previous_path := str(ProjectSettings.get_setting(C.LAST_IDS_PATH_PROPERTY, ""))
	if not previous_path.is_empty() and previous_path != ids_path:
		_move_ids_file(previous_path, ids_path)
	_move_ids_file(C.LEGACY_IDS_FILE_PATH, ids_path)

	ProjectSettings.set_setting(C.LAST_IDS_PATH_PROPERTY, ids_path)
	ProjectSettings.set_as_internal(C.LAST_IDS_PATH_PROPERTY, true)

## Returns true if the file was moved or a stale copy was removed.
func _move_ids_file(from_path: String, to_path: String) -> bool:
	if from_path.is_empty() or from_path == to_path:
		return false
	if not FileAccess.file_exists(from_path):
		return false

	if not FileAccess.file_exists(to_path):
		var dir_error := DirAccess.make_dir_recursive_absolute(to_path.get_base_dir())
		if dir_error != OK:
			push_error("Newgrounds: could not create %s (%s)." % [to_path.get_base_dir(), error_string(dir_error)])
			return false

		var contents := FileAccess.get_file_as_string(from_path)
		if contents.is_empty():
			push_error("Newgrounds: could not read %s." % from_path)
			return false

		var file := FileAccess.open(to_path, FileAccess.WRITE)
		if file == null:
			push_error("Newgrounds: could not move %s to %s (%s)." % [from_path, to_path, error_string(FileAccess.get_open_error())])
			return false
		file.store_string(contents)
		file.close()

	DirAccess.remove_absolute(from_path)

	var fs := get_editor_interface().get_resource_filesystem()
	fs.update_file(from_path)
	fs.update_file(to_path)
	print("Newgrounds: moved %s to %s." % [from_path, to_path])
	return true

## Existing medal id -> resource path mapping, if the generated file is present.
func _get_existing_medal_resources() -> Dictionary:
	var ids_path := _get_ids_path()
	if not ResourceLoader.exists(ids_path):
		return {}
	var ids_script = load(ids_path)
	if ids_script == null:
		return {}
	var ids_class = ids_script.MedalIdsToResource
	if ids_class and ids_class.medals is Dictionary:
		return ids_class.medals
	return {}


func _migrate_legacy_credentials() -> void:
	var legacy := {}
	for pair in [[C.ENV_APP_ID, C.APP_ID_PROPERTY], [C.ENV_AES_KEY, C.AES_KEY_PROPERTY]]:
		var value := str(ProjectSettings.get_setting(pair[1], "")).strip_edges()
		if not value.is_empty():
			legacy[pair[0]] = value

	if legacy.is_empty():
		return

	var stored := DotEnv.load_file(C.ENV_FILE)
	var updates := {}
	for key in legacy:
		if str(stored.get(key, "")).strip_edges().is_empty():
			updates[key] = legacy[key]

	if not updates.is_empty():
		DotEnv.save_values(C.ENV_FILE, updates)

	for property in [C.APP_ID_PROPERTY, C.AES_KEY_PROPERTY]:
		ProjectSettings.clear(property)
	ProjectSettings.save()
	Config.reload()
	print("Newgrounds: moved the App ID and AES key from ProjectSettings to %s. Add .env to your .gitignore." % C.ENV_FILE)


var loadedMedals = false;
var medalList:Array[MedalResource] = [];
var loadedScoreboards = false;
var scoreboardList:Array = [];

var medalRequest: NewgroundsRequest;
var boardRequest: NewgroundsRequest;
var _import_finished_emitted := false
func _import_newgrounds():
	_import_finished_emitted = false;
	loadedMedals = false;
	loadedScoreboards = false;
	medalList = [];
	scoreboardList = [];

	var app_id = Config.app_id()
	var aes_key = Config.aes_key()
	if app_id.is_empty() or aes_key.is_empty():
		var message := "Add the App ID and AES key on the Newgrounds tab (Project Settings > Newgrounds) or in %s before importing." % C.ENV_FILE
		printerr("Newgrounds.io - " + message)
		_finish_import(false, message)
		return

	if boardRequest and is_instance_valid(boardRequest):
		boardRequest.cancel()

	print("Newgrounds.io - Getting medals and scoreboards...")

	var e = NewgroundsRequest.new()
	add_child(e);
	e.init(app_id, aes_key);
	e.create("ScoreBoard.getBoards", null)
	e.on_response.connect(scoreboards_get)
	boardRequest = e;

	if medalRequest and is_instance_valid(medalRequest):
		medalRequest.cancel()

	e = NewgroundsRequest.new()
	add_child(e);
	e.init(app_id, aes_key);
	e.create("Medal.getList", null)
	e.on_response.connect(medals_get)
	medalRequest = e;
	pass

func _finish_import(success: bool, message: String) -> void:
	if _import_finished_emitted:
		return
	_import_finished_emitted = true
	import_finished.emit(success, message)

func scoreboards_get(res:NewgroundsResponse):
	if (res.error):
		if res.error == NewgroundsRequest.ERR_CANCELLED:
			return
		var message := "Could not get scoreboards: %s" % res.error_message
		printerr(message)
		_finish_import(false, message)
		return
	var b = res.data;
	scoreboardList = b.scoreboards;
	loadedScoreboards = true
	_write_ids()

const NewgroundsImage = preload("res://addons/newgrounds/scripts/newgrounds_image.gd")

func medals_get(res: NewgroundsResponse):
	if (res.error):
		if res.error == NewgroundsRequest.ERR_CANCELLED:
			return
		var message := "Could not get medals: %s" % res.error_message
		printerr(message)
		_finish_import(false, message)
		return
	var data = res.data;
	var medal_dir := str(ProjectSettings.get_setting(C.IMPORTED_MEDALS_LOCATION_PROPERTY, C.MEDALS_PATH)).strip_edges()
	if medal_dir.is_empty():
		medal_dir = C.MEDALS_PATH
	if not DirAccess.dir_exists_absolute(medal_dir):
		var err := DirAccess.make_dir_recursive_absolute(medal_dir)
		if err != OK:
			var message := "Could not create the medal folder %s: %s" % [medal_dir, error_string(err)]
			printerr(message)
			_finish_import(false, message)
			return

	var used_names = {}
	var medal_names := _get_existing_medal_resources()
	const not_allowed = [':',"'",'/','\\','?','*','"','|', '%','<','>']
	for m in data.medals:
		var medal_name: String = m.name.to_snake_case();
		for c in not_allowed:
			medal_name = medal_name.replace(c, "")
		if (used_names.has(medal_name)):
			used_names[medal_name] = used_names[medal_name] + 1
			medal_name += "_%s" % used_names[medal_name]
		else:
			used_names[medal_name] = 1

		var old_resource_name = medal_names.get(int(m.id))
		var resource_name = "%s/%s.tres" % [medal_dir, medal_name]
		var medal:MedalResource;
		if old_resource_name and ResourceLoader.exists(old_resource_name):
			medal = ResourceLoader.load(old_resource_name)
			MedalResource.load_from_dict(medal, m)
			if old_resource_name != resource_name:
				medal.take_over_path(resource_name)
				DirAccess.remove_absolute(old_resource_name)
				pass
		else:
			medal = MedalResource.fromDict(m)
			medal.take_over_path(resource_name)

		ResourceSaver.save(medal, resource_name, ResourceSaver.SaverFlags.FLAG_CHANGE_PATH)
		medalList.push_back(medal)

		var imgReq = NewgroundsImage.new()
		imgReq.visible = false;
		add_child(imgReq)
		var icon_url = medal.icon_url;
		if !icon_url.begins_with("https:"):
			icon_url = "https:" + icon_url;
		imgReq.url = icon_url;
		imgReq.on_image_loaded.connect(_set_medal_icon.bind(medal, resource_name, imgReq))

	loadedMedals = true
	_write_ids()
	pass

func _set_medal_icon(img: ImageTexture, medal: MedalResource, path: String, ngImage:NewgroundsImage):
	medal.icon = img
	ResourceSaver.save(medal)
	ngImage.queue_free()
	pass

func _clean_name(name):
	var regex = RegEx.new()
	regex.compile("[^\\w ]")
	return regex.sub(name, "", true).to_pascal_case()

func _starts_with_nonletter(str):
	var regex = RegEx.new()
	regex.compile("^[^a-zA-Z]")
	return regex.search(str)

func _write_ids():
	if !loadedMedals or !loadedScoreboards:
		return
	_write_template_file(scoreboardList, medalList)
	print("Newgrounds.io - Wrote Medal and Scoreboard IDs, reload the project to update")
	get_editor_interface().get_resource_filesystem().scan()
	_finish_import(true, "Imported %d medals and %d scoreboards. Use \"Reload project\" to apply the new IDs." % [medalList.size(), scoreboardList.size()])
	pass

func _write_template_file(scoreboardList, medalList):
	var boardString = ""
	var medalString = ""
	var medalResource = "";
	for b in scoreboardList:
		var boardName: String = b.name;
		boardName = _clean_name(boardName)
		if _starts_with_nonletter(boardName):
			boardName = '_%s' % boardName

		boardString += "	%s = %s,\n" % [boardName, int(b.id)]

	var used_names = {}
	for m in medalList:
		medalResource += '		%s: "%s",\n' % [int(m.id), m.resource_path]
		var medal_name: String = m.name;
		medal_name = _clean_name(medal_name)
		if _starts_with_nonletter(medal_name):
			medal_name = '_%s' % medal_name
		if (used_names.has(medal_name)):
			used_names[medal_name] = used_names[medal_name] + 1
			medal_name += "_%s" % used_names[medal_name]
		else:
			used_names[medal_name] = 1
		medalString += "	%s = %s,\n" % [medal_name, int(m.id)]

	var f = FileAccess.get_file_as_string(C.NEWGROUNDS_IDS_TEMPLATE)
	if f.is_empty():
		push_error("Newgrounds: could not read %s." % C.NEWGROUNDS_IDS_TEMPLATE)
		return

	var ids_path := _get_ids_path()
	var dir_error := DirAccess.make_dir_recursive_absolute(ids_path.get_base_dir())
	if dir_error != OK:
		push_error("Newgrounds: could not create %s (%s)." % [ids_path.get_base_dir(), error_string(dir_error)])
		return

	var s = f % [boardString, medalString, medalResource]
	var file = FileAccess.open(ids_path, FileAccess.WRITE)
	if file == null:
		push_error("Newgrounds: could not write %s (%s)." % [ids_path, error_string(FileAccess.get_open_error())])
		return
	file.store_string(s)
	file.close();

	var interface = get_editor_interface()
	var fs = interface.get_resource_filesystem()
	fs.update_file(ids_path);

func add_project_setting(name: String, default_value, type: int, hint: int = PROPERTY_HINT_NONE, hint_string: String = "", basic: bool = true) -> void:

	if !ProjectSettings.has_setting(name):
		ProjectSettings.set_setting(name, default_value)

	var setting_info: Dictionary = {
		"name": name,
		"type": type,
		"hint": hint,
		"hint_string": hint_string
	}

	ProjectSettings.add_property_info(setting_info)
	ProjectSettings.set_initial_value(name, default_value)
	ProjectSettings.set_as_basic(name, basic)
