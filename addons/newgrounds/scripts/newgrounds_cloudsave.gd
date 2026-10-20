extends Node

## Called once the save process is complete
signal on_cloudsave_saved;
## Called at the start of loading a save, could be useful to reset the state of objects
signal on_cloudsave_load_start;
## Called once all properties have been loaded
signal on_cloudsave_loaded;

func save_game(save_slot: int = 1) -> void:
	var save_string = "";
	var save_nodes = get_tree().get_nodes_in_group("CloudSave")
	for node in save_nodes:
		# Check the node has a save function.
		if !node.has_method("_cloud_save"):
			push_warning("Newgrounds.io - NGCloudSave: Node '%s' is missing a _cloud_save() function, skipped" % node.name)
			continue

		# Call the node's save function.
		var node_data = node.call("_cloud_save")
		if not (node_data is Dictionary):
			push_warning("Newgrounds.io - NGCloudSave: Node '%s' _cloud_save() must return a Dictionary, skipped" % node.name)
			continue

		node_data.__node_path = node.get_path()
		node_data.__node_scene_path = node.get_scene_file_path()

		save_string += Marshalls.utf8_to_base64(JSON.stringify(node_data)) + "\n"

	save_string = NG.offline_data.hash_string(save_string);

	var slot = await NG.cloudsave_set_data(save_slot, save_string)

	if slot != null or NG.offline_mode:
		on_cloudsave_saved.emit()
	else:
		push_error("Newgrounds.io - NGCloudSave: could not save slot %s." % save_slot)

func load_game(save_slot:int = 1) -> void:
	on_cloudsave_load_start.emit()
	var text_data = await NG.cloudsave_get_data(save_slot)
	if text_data == "":
		on_cloudsave_loaded.emit();
		return

	var rows = NG.offline_data.unhash_string(text_data).split("\n", false)
	for row in rows:
		var json_string = Marshalls.base64_to_utf8(row)

		var json = JSON.new()
		var parse_result = json.parse(json_string)
		if parse_result != OK:
			push_warning("Newgrounds.io - NGCloudSave: JSON Parse Error: %s in %s at line %s" % [json.get_error_message(), json_string, json.get_error_line()])
			continue

		var node_data = json.get_data()
		if not (node_data is Dictionary):
			push_warning("Newgrounds.io - NGCloudSave: malformed save data, skipping.")
			continue

		var node_path = node_data.get("__node_path")
		if node_path == null or not get_tree().root.has_node(node_path):
			push_warning("Newgrounds.io - NGCloudSave: Node %s not found, skipping." % node_path)
			continue

		var new_node = get_tree().root.get_node(node_path)
		if not new_node:
			continue

		var scr = new_node.get_script()
		if scr and scr.can_instantiate():
			var instance = scr.new()
			if instance.has_method("_cloud_save"):
				var initial_vals = instance.call("_cloud_save")
				if initial_vals is Dictionary:
					for i in initial_vals.keys():
						new_node.set(i, initial_vals[i])
			if instance is Node:
				instance.free()

		for i in node_data.keys():
			if i == "__node_path" or i == "__node_scene_path":
				continue
			new_node.set(i, node_data[i])
			if new_node.has_method("_cloud_set_property"):
				new_node.call("_cloud_set_property", i, node_data[i])
	on_cloudsave_loaded.emit();
