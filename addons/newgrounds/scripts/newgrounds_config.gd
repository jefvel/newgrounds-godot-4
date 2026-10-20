@tool
class_name NewgroundsConfig

## Resolves the Newgrounds App ID and AES key.
##
## Lookup order, first non-empty value wins:
## 1. `res://.env` in the project folder (editor and local runs).
## 2. `res://newgrounds_config.cfg`, injected into the PCK by the export plugin.
## 3. `NEWGROUNDS_APP_ID` / `NEWGROUNDS_AES_KEY` environment variables (CI).
##
## The values are never stored in `ProjectSettings`.

const C = preload("res://addons/newgrounds/scripts/newgrounds_consts.gd")
const DotEnv = preload("res://addons/newgrounds/scripts/newgrounds_dotenv.gd")

static var _values: Dictionary = {}
static var _loaded := false

static func app_id() -> String:
	return _resolve(C.ENV_APP_ID)

static func aes_key() -> String:
	return _resolve(C.ENV_AES_KEY)

## Drops the cached values so a freshly written `.env` is picked up.
static func reload() -> void:
	_loaded = false
	_values.clear()

static func _resolve(key: String) -> String:
	if not _loaded:
		_load()
	return str(_values.get(key, "")).strip_edges()

static func _load() -> void:
	_loaded = true
	_values.clear()

	var env := DotEnv.load_file(C.ENV_FILE)
	for key in env:
		_values[key] = str(env[key])

	var cfg := ConfigFile.new()
	if cfg.load(C.CONFIG_PATH) == OK:
		if not _has(C.ENV_APP_ID):
			_values[C.ENV_APP_ID] = str(cfg.get_value("newgrounds", "app_id", ""))
		if not _has(C.ENV_AES_KEY):
			_values[C.ENV_AES_KEY] = str(cfg.get_value("newgrounds", "aes_key", ""))

	for key in [C.ENV_APP_ID, C.ENV_AES_KEY]:
		if not _has(key):
			_values[key] = OS.get_environment(key)

static func _has(key: String) -> bool:
	return not str(_values.get(key, "")).strip_edges().is_empty()
