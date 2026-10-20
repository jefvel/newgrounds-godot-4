## Consts for configuring various things
const NEWGROUNDS_AUTOLOAD_NAME = "NG"
const NEWGROUNDS_AUTOLOAD_NODE = "res://addons/newgrounds/scripts/newgrounds.tscn"

const CLOUDSAVE_AUTOLOAD_NAME = "NGCloudSave"
const CLOUDSAVE_AUTOLOAD_NODE = "res://addons/newgrounds/scripts/newgrounds_cloudsave.gd"

const AUTO_INIT_PROPERTY 				= "newgrounds.io/auto_init";
## Internal marker for the directory the generated IDs file currently lives in.
const LAST_IDS_PATH_PROPERTY 			= "newgrounds.io/last_ids_file_path";
## Legacy settings. Only read once to migrate existing projects into `.env`.
const APP_ID_PROPERTY					= "newgrounds.io/app_id"
const AES_KEY_PROPERTY					= "newgrounds.io/AES-128_key"
const IMPORTED_MEDALS_LOCATION_PROPERTY = "newgrounds.io/imported_medals_location";

## Credentials live in a gitignored `.env` at the project root, never in ProjectSettings.
const ENV_FILE 				= "res://.env"
const ENV_APP_ID 			= "NEWGROUNDS_APP_ID"
const ENV_AES_KEY 			= "NEWGROUNDS_AES_KEY"
## Config file injected into the PCK by the export plugin.
const CONFIG_PATH 			= "res://newgrounds_config.cfg"

const CONFIG_ACTION_NAME 	= "Project Settings > Newgrounds"
const CONFIG_SCENE 			= "res://addons/newgrounds/tools/newgrounds_configuration.tscn"

const NEWGROUNDS_IDS_TEMPLATE	= "res://addons/newgrounds/data/newgrounds_ids_template.txt"
## Generated next to the imported medal resources (see imported_medals_location).
const IDS_FILE_NAME 			= "newgrounds_ids.gd"
## Old fixed location. Moved into the configured medals directory on startup.
const LEGACY_IDS_FILE_PATH 	= "res://addons/newgrounds/data/newgrounds_ids.gd"
const MEDALS_PATH 			= "res://imported_newgrounds_medals"
