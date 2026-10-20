# Newgrounds.io API for Godot 4

## Quick start

Install and enable the addon. Then set your app ID and encryption key found on the
Newgrounds project page. You can do this in **Project Settings > Newgrounds**, which
writes them to a gitignored `.env` file at the project root:

```sh
# .env
NEWGROUNDS_APP_ID=123456
NEWGROUNDS_AES_KEY=your-base64-aes-key
```

You can also copy `.env.example` and edit it by hand, or set the same variables in your
CI environment. On export, the addon embeds them into the game automatically.

The credentials are deliberately not stored in `ProjectSettings`, so they cannot end up
in `project.godot`. Add `.env` to your `.gitignore` (this repository already does).

You should also import your medals/scoreboards from Newgrounds. Open
**Project Settings > Newgrounds** and press **Import**, then **Reload project** when the
import finishes. The `newgrounds_ids.gd` file is generated in the same folder as the
imported medal resources. This makes it possible to get medal/scoreboard names using
`NewgroundsIds.ScoreboardId` and `NewgroundsIds.MedalId`.

Once done, you are ready to go! The nodes `NG` and `NGCloudSave` are accessible in code.

### How the credentials are resolved

At runtime the addon looks for the values in this order:

1. `res://.env` — used in the editor and when running from source.
2. `res://newgrounds_config.cfg` — injected into the PCK by the export plugin. This
   file never exists on disk, so there is nothing to commit or `.gitignore`.
3. The `NEWGROUNDS_APP_ID` / `NEWGROUNDS_AES_KEY` environment variables — handy for CI.

In CI, export the secrets as environment variables before building:

```sh
NEWGROUNDS_APP_ID=123456 NEWGROUNDS_AES_KEY=... godot --headless --export-release "Web" build/index.html
```

Because the key has to be readable by the client, this is obfuscation rather than real
secrecy: anyone can extract it from the `.pck`. Keep the key revocable and don't use it
for anything that matters on its own.

Don't add `.env` to the export preset's non-resource filters (`*`, `.env`, ...): the value
is already injected by the addon, and a matching filter would ship the file in plaintext
as well.

### Signing in & out

When running the game on Newgrounds, you should be signed in automatically once the addon is initialized.

```gdscript
# Manually sign in, will launch newgrounds passport
NG.sign_in()

# Signing out, ending the session
NG.sign_out()

# Track session changes
NG.on_session_change.connect(session_change)

# ...

func session_change(s : NewgroundsSession):
	if s.is_signed_in():
		print("Signed in")
	else:
		print("Not signed in")
```

### Unlock medal

```gdscript
await NG.medal_unlock(id) # or NewgroundsIds.MedalId.MEDAL_NAME if you've imported medals and scoreboards.
print("Medal unlocked!")
```

You can also listen to any new medal unlock, if you want to show a unlock popup or something similar:

```gdscript
NG.on_medal_unlocked.connect(_medal_unlock)

func _medal_unlock(medal_id:int):
	print("Unlocked medal with ID %s" % medal_id);
	var medal = NG.get_medal_resource(medal_id)
	print(medal.name)
```

### Submit a score

```gdscript
await NG.scoreboard_submit(id, value)
print("Score submitted!")
await NG.scoreboard_submit_time(id, milliseconds)
print("Time submitted!")
```

### Get scores

```gdscript
var limit = 10;
var scores = await NG.scoreboard_get_scores(scoreboard_id, limit)
for score in scores:
	print("user %s has the score %s" % [score.user.name, score.formatted_value])
```

## Cloud save & load

To save and load strings, you can do this:

```gdscript
var data = "hello hello";
await NG.cloudsave_set_data(1, data)

data = "stuff";
data = await NG.cloudsave_get_data(1);
print(data) # "hello hello"
```

A more automated way is possible using `NGCloudSave`. First, create a node with a script attached.
Add the node to the group `CloudSave`. Then add the following script:

```gdscript
var test_text = ""
var test_number = 1;

# the properties returned by `_cloud_save` will be restored when loading
func _cloud_save():
	return {
		"test_text": test_text,
		"test_number": test_number,
	}
```

Now, you can call `NGCloudSave.save_game()` and `NGCloudSave.load_game()` to store/load the properties defined in the script.

For it to work, it's important that the node has the same path when loading/saving. Therefore it could be good to add the save object as an autoload script.

## Using the `NewgroundsMedalUnlocker` and `NewgroundsScoreboard` nodes

These nodes require you to have imported medals and scoreboards. They're useful for tracking medals and getting scoreboard data.

### Unlocking medals

To track and unlock a medal add a `NewgroundsMedalUnlocker` node and select
the medal it should represent in its properties. Call `$Medal.unlock()` to unlock it.
It also has a signal `on_unlocked(medal)`, and the property `unlocked` to check if it's unlocked.

### Loading scoreboard scores

Simply add a `NewgroundsScoreboard` node, and assign its scoreboard id. You can call `refresh()` on it to fetch new scores. Its signal `on_scores_get` is called when scores are loaded.

## Offline mode

The addon keeps track of unlocked medals, submitted scores, and cloud saves even when offline/signed out.
It will sync with Newgrounds when the user signs in.

## Examples

There are a few examples in the examples directory. Drag in `newgrounds_debug.tscn` into your scene and look around if you want to see them in action.

## Requests

`NG` tries to handle most logic for you, but it's also possible to manually call components.
`NG.components` node contains various methods for calling the Newgrounds API, if you want to do it manually.They all return a `NewgroundsRequest`:

```gdscript
NG.components.ping()

NG.components.app_start_session()
NG.components.app_check_session()
NG.components.app_end_session()

NG.components.scoreboard_get_boards();
# optional app_id to get other games' scores
NG.components.scoreboard_get_scores(id, limit, skip, period, social, user = "", tag = "", app_id = "")

NG.components.scoreboard_post_score(id, value)

# optional app_id can be provided to get other games' medals
NG.components.medal_get_list(app_id = "")
NG.components.medal_unlock(id)
NG.components.medal_get_medal_score()

# optional app_id to get other games' save slots
NG.components.cloudsave_load_slots(app_id = "")
NG.components.cloudsave_load_slot(slot_id, app_id = "")
NG.components.cloudsave_get_data(data_url)

NG.components.cloudsave_set_data(slot_id, data_string)
NG.components.cloudsave_clear_slot(slot_id)
```

You can listen to the request done by these calls:

```gdscript
func get_scoreboards():
	var response = await NG.components.scoreboard_get_boards().on_response
	if response.error:
		printerr(response.error_message)
	else:
		print(response.data);
```
