@tool
extends EditorPlugin

const C = preload("res://addons/newgrounds/newgrounds_consts.gd")
func _enter_tree():
	add_project_setting(C.APP_ID_PROPERTY, "", TYPE_STRING)
	add_project_setting(C.AES_KEY_PROPERTY, "", TYPE_STRING)
	add_project_setting(C.AUTO_INIT_PROPERTY, true, TYPE_BOOL)
	add_project_setting(C.IMPORTED_MEDALS_LOCATION_PROPERTY, C.MEDALS_PATH, TYPE_STRING, PROPERTY_HINT_DIR, "", false)
	
	add_tool_menu_item(C.IMPORT_ACTION_NAME, _import_newgrounds)
	
	if !FileAccess.file_exists(C.IDS_FILE_PATH):
		_write_template_file([], [])
	
	if !ProjectSettings.has_setting("autoload/%s" % C.NEWGROUNDS_AUTOLOAD_NAME):
		add_autoload_singleton(C.NEWGROUNDS_AUTOLOAD_NAME, C.NEWGROUNDS_AUTOLOAD_NODE)
	if !ProjectSettings.has_setting("autoload/%s" % C.CLOUDSAVE_AUTOLOAD_NAME):
		add_autoload_singleton(C.CLOUDSAVE_AUTOLOAD_NAME, C.CLOUDSAVE_AUTOLOAD_NODE)
		
	ProjectSettings.save()
	

func _exit_tree():
	remove_autoload_singleton(C.NEWGROUNDS_AUTOLOAD_NAME)
	remove_autoload_singleton(C.CLOUDSAVE_AUTOLOAD_NAME)
	remove_tool_menu_item(C.IMPORT_ACTION_NAME)
	pass

var loadedMedals = false;
var medalList:Array[MedalResource] = [];
var loadedScoreboards = false;
var scoreboardList:Array = [];

var medalRequest: NewgroundsRequest;
var boardRequest: NewgroundsRequest;
func _import_newgrounds():
	loadedMedals = false;
	loadedScoreboards = false;
	medalList = [];
	scoreboardList = [];
	
	var app_id = ProjectSettings.get_setting(C.APP_ID_PROPERTY, "")
	var aes_key = ProjectSettings.get_setting(C.AES_KEY_PROPERTY, "")
	assert(app_id, "App ID not provided, configure it in the project settings")
	assert(aes_key, "AES key not provided, configure it in the project settings")
	
	if boardRequest and is_instance_valid(boardRequest):
		boardRequest.cancel()
	
	print("Newgrounds.io - Getting medals and scoreboards...")
	
	var e = NewgroundsRequest.new()
	add_child(e);
	e.init(app_id, aes_key);
	e.create("ScoreBoard.getBoards", null)
	e.on_success.connect(scoreboards_get)
	boardRequest = e;

	if medalRequest and is_instance_valid(medalRequest):
		medalRequest.cancel()
	
	e = NewgroundsRequest.new()
	add_child(e);
	e.init(app_id, aes_key);
	e.create("Medal.getList", null)
	e.on_success.connect(medals_get)
	medalRequest = e;
	pass

func scoreboards_get(b):
	scoreboardList = b.scoreboards;
	loadedScoreboards = true
	_write_ids()
	
const NewgroundsImage = preload("res://addons/newgrounds/scripts/newgrounds_image.gd")

func medals_get(medals):
	var medal_dir = ProjectSettings.get_setting(C.IMPORTED_MEDALS_LOCATION_PROPERTY)
	if !FileAccess.file_exists(medal_dir):
		DirAccess.make_dir_absolute(medal_dir)
	var used_names = {}
	for m in medals.medals:
		var resource_name = "%s/%s.tres" % [medal_dir, m.id]
		var medal:MedalResource;
		if ResourceLoader.exists(resource_name):
			medal = ResourceLoader.load(resource_name)
			MedalResource.load_from_dict(medal, m)
		else:
			medal = MedalResource.fromDict(m)
			medal.resource_path = resource_name;
			
		medalList.push_back(medal)
		ResourceSaver.save(medal)
		
		var imgReq = NewgroundsImage.new()
		imgReq.visible = false;
		add_child(imgReq)
		imgReq.url = 'https:' + medal.icon_url;
		imgReq.on_image_loaded.connect(_set_medal_icon.bind(medal, resource_name, imgReq))
		
	loadedMedals = true
	#print("Newgrounds.io - Medals imported")
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
		
		boardString += "	%s = %s,\n" % [boardName, b.id]
	for m in medalList:
		medalResource += '		%s: "%s",\n' % [m.id, m.resource_path]
		var medalName: String = m.name;
		medalName = _clean_name(medalName)
		if _starts_with_nonletter(medalName):
			medalName = '_%s' % medalName
		medalString += "	%s = %s,\n" % [medalName, m.id]
	
	var f = FileAccess.get_file_as_string(C.NEWGROUNDS_IDS_TEMPLATE)
	var s = f % [boardString, medalString, medalResource]
	var file = FileAccess.open(C.IDS_FILE_PATH, FileAccess.WRITE)
	file.store_string(s)
	file.close();

	var interface = get_editor_interface()
	var fs = interface.get_resource_filesystem()
	fs.update_file(C.IDS_FILE_PATH);

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
	
	
func remove_project_setting(name: String):
	ProjectSettings.clear(name)
	pass
