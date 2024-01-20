extends Node

## Called once the save process is complete
signal on_cloudsave_saved;
## Called at the start of loading a save, could be useful to reset the state of objects
signal on_cloudsave_load_start;
## Called once all properties have been loaded
signal on_cloudsave_loaded;

func save_game(save_slot: int = 1):
	var save_string = "";
	var save_nodes = get_tree().get_nodes_in_group("CloudSave")
	for node in save_nodes:
		# Check the node has a save function.
		if !node.has_method("_cloud_save"):
			print("Newgrounds.io - NGCloudSave: Node '%s' is missing a _cloud_save() function, skipped" % node.name)
			continue

		# Call the node's save function.
		var node_data = node.call("_cloud_save")
		node_data.__node_path = node.get_path()
		node_data.__node_scene_path = node.get_scene_file_path();

		# JSON provides a static method to serialized JSON string.
		var json_string = JSON.stringify(node_data)

		save_string += Marshalls.utf8_to_base64(json_string) + "\n"

	save_string = NG.offline_data.hash_string(save_string);
	
	var req = await NG.cloudsave_set_data(save_slot, save_string)
	
	on_cloudsave_saved.emit()

func load_game(save_slot:int = 1):
	on_cloudsave_load_start.emit()
	var text_data = await NG.cloudsave_get_data(save_slot)
	if text_data == "":
		on_cloudsave_loaded.emit();
		return
	
	var rows = NG.offline_data.unhash_string(text_data).split("\n", false)
	for row in rows:
		var json_string = Marshalls.base64_to_utf8(row)

		# Creates the helper class to interact with JSON
		var json = JSON.new()

		# Check if there is any error while parsing the JSON string, skip in case of failure
		var parse_result = json.parse(json_string)
		if not parse_result == OK:
			print("JSON Parse Error: ", json.get_error_message(), " in ", json_string, " at line ", json.get_error_line())
			continue

		# Get the data from the JSON object
		var node_data: Dictionary = json.get_data()
		var node_path = node_data.__node_path;
		if !get_tree().root.has_node(node_path):
			print("Newgrounds.io - NGCloudSave: Node %s not found, skipping." % node_path)
			continue;
		
		var new_node = get_tree().root.get_node(node_path)
		
		if !new_node:
			continue
			
		var scr = new_node.get_script()
		if scr and scr.can_instantiate():
			var newdd = scr.new();
			var initial_vals = newdd._cloud_save();
			for i in initial_vals.keys():
				new_node.set(i, initial_vals[i])
		
		# Now we set the remaining variables.
		for i in node_data.keys():
			if i == "__node_path" or i == "__node_scene_path":
				continue
			# print("set %s to %s" % [i, node_data[i]])
			new_node.set(i, node_data[i])
			if new_node.has_method("_cloud_set_property"):
				new_node.call("_cloud_set_property", i, node_data[i])
	on_cloudsave_loaded.emit();
