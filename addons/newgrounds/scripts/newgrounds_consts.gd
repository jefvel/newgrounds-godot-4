## Consts for configuring various things
const NEWGROUNDS_AUTOLOAD_NAME = "NG"
const NEWGROUNDS_AUTOLOAD_NODE = "res://addons/newgrounds/scripts/newgrounds.tscn"

const CLOUDSAVE_AUTOLOAD_NAME = "NGCloudSave"
const CLOUDSAVE_AUTOLOAD_NODE = "res://addons/newgrounds/scripts/newgrounds_cloudsave.gd"

const AUTO_INIT_PROPERTY 				= "newgrounds.io/auto_init";
## Legacy settings. Only read once to migrate existing projects into `.env`.
const APP_ID_PROPERTY					= "newgrounds.io/app_id"
const AES_KEY_PROPERTY					= "newgrounds.io/AES-128_key"
const IMPORTED_MEDALS_LOCATION_PROPERTY = "newgrounds.io/imported_medals_location";
const SCOREBOARD_HINT_TEXT_PROPERTY 	= "newgrounds.io/scoreboard_hint_string";
const MEDAL_HINT_TEXT_PROPERTY 			= "newgrounds.io/medal_hint_string";

## Credentials live in a gitignored `.env` at the project root, never in ProjectSettings.
const ENV_FILE 				= "res://.env"
const ENV_APP_ID 			= "NEWGROUNDS_APP_ID"
const ENV_AES_KEY 			= "NEWGROUNDS_AES_KEY"
## Config file injected into the PCK by the export plugin.
const CONFIG_PATH 			= "res://newgrounds_config.cfg"

const CONFIG_ACTION_NAME 	= "Configure Newgrounds App ID and AES Key"
const CONFIG_SCENE 			= "res://addons/newgrounds/tools/newgrounds_configuration.tscn"

const OPEN_NEWGROUNDS_HELP		= "Open Newgrounds Addon Help Page"
const NEWGROUNDS_IDS_TEMPLATE	= "res://addons/newgrounds/data/newgrounds_ids_template.txt"
const IDS_FILE_PATH 			= "res://addons/newgrounds/data/newgrounds_ids.gd"
const MEDALS_PATH 				= "res://addons/newgrounds/imported_medals"
