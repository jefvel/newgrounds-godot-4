@tool
extends EditorExportPlugin

## Injects the credentials from `.env` into the exported PCK as
## `res://newgrounds_config.cfg`, so they never exist as a file in the project.

const C = preload("res://addons/newgrounds/scripts/newgrounds_consts.gd")
const Config = preload("res://addons/newgrounds/scripts/newgrounds_config.gd")

func _get_name() -> String:
	return "NewgroundsConfig"

func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	Config.reload()

	var app_id := Config.app_id()
	var aes_key := Config.aes_key()
	if app_id.is_empty() or aes_key.is_empty():
		push_error(
			"Newgrounds: App ID and/or AES key are missing, exporting without credentials. " +
			"Set them in %s, or via %s / %s environment variables." %
			[C.CONFIG_ACTION_NAME, C.ENV_APP_ID, C.ENV_AES_KEY]
		)
		return

	var cfg := ConfigFile.new()
	cfg.set_value("newgrounds", "app_id", app_id)
	cfg.set_value("newgrounds", "aes_key", aes_key)

	var temp_path := "user://__newgrounds_config.cfg"
	var err := cfg.save(temp_path)
	if err != OK:
		push_error("Newgrounds: could not prepare the exported config (%s)." % error_string(err))
		return

	add_file(C.CONFIG_PATH, FileAccess.get_file_as_bytes(temp_path), false)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(temp_path))

	if _env_is_tracked_by_git():
		push_warning("Newgrounds: %s is tracked by git. Add it to .gitignore so the credentials are not committed." % C.ENV_FILE)

func _env_is_tracked_by_git() -> bool:
	if not FileAccess.file_exists(C.ENV_FILE):
		return false
	var output: Array = []
	return OS.execute("git", ["ls-files", "--error-unmatch", ".env"], output, true) == 0
