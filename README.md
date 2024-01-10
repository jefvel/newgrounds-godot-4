# Newgrounds.io API for Godot 4

## Quick start

Install and enable the addon. Go to the project settings and look for `Newgrounds.io`.
In there, add the app ID and encryption key found on the Newgrounds project page.

![Configure the addon](/images/project_settings.png)

Once this is done, you are ready to go! The nodes `NG` and `NGCloudSave` are accessible in code.

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
	if s.signed_in():
		print("Signed in")
	else:
		print("Not signed in")
```

### Unlock medal

```gdscript
NG.medal_unlock(id)
```

### Post a score

```gdscript
NG.scoreboard_submit(id, value)
NG.scoreboard_submit_time(id, seconds)
```

## Using the `NewgroundsMedalUnlocker` and `NewgroundsScoreboard` nodes

It's possible to import medals and scoreboards from Newgrounds. To do this, browse the menu to `Project > Tools > Import Newgrounds Medals & Scoreboards`. A project reload might be required after this. Once that is done, IDs of both medals and scoreboards will be available in the enums `NewgroundsIds.ScoreboardId` & `NewgroundsIds.MedalId`.

![Importing medals & scoreboard data from newgrounds](/images/import.png)

### Unlocking medals

To track and unlock a medal add a `NewgroundsMedalUnlocker` node and select
the medal it should represent in its properties. Call `$Medal.unlock()` to unlock it.
It also has a signal `on_unlock(medal)`, and the property `unlocked` to check if it's unlocked.

## Requests

The `NG` node contains various methods for calling the Newgrounds API, they all return a `NewgroundsRequest`:

```gdscript
NG.ping()

NG.session_start()
NG.session_check()
NG.session_end()

NG.scoreboard_list();
NG.scoreboard_get_scores(id, limit, skip, period, social, user, tag)
NG.scoreboard_submit(id, value)
NG.scoreboard_submit_time(id, seconds)

NG.medal_get_list()
NG.medal_unlock(id)
NG.medal_get_medal_score()

NG.cloudsave_load_slots()
NG.cloudsave_load_slot(slot_id)
NG.cloudsave_clear_slot(slot_id)
NG.cloudsave_get_data(slot_id)
NG.cloudsave_set_data(slot_id, data_string)
```

You can listen to the request done by these calls:

```gdscript
func get_scoreboards():
	var req = NG.scoreboard_list();
	req.on_success.connect(on_success)
	req.on_error.connect(on_error)

func on_success(scoreboards):
	print(scoreboards)
func on_error(error):
	print(error)
```
