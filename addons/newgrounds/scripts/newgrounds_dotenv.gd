@tool
class_name NewgroundsDotEnv

static func parse(text: String) -> Dictionary:
	var values := {}
	for raw in text.split("\n"):
		var line := raw.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("export "):
			line = line.substr(7).strip_edges()
		var equals := line.find("=")
		if equals <= 0:
			continue
		var key := line.substr(0, equals).strip_edges()
		if key.is_empty():
			continue
		values[key] = _unquote(line.substr(equals + 1).strip_edges())
	return values

static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var text := file.get_as_text()
	file.close()
	return parse(text)

static func save_values(path: String, values: Dictionary) -> Error:
	var lines: Array[String] = []
	var written := {}

	if FileAccess.file_exists(path):
		var existing := FileAccess.open(path, FileAccess.READ)
		if existing == null:
			return FileAccess.get_open_error()
		for raw in existing.get_as_text().split("\n"):
			var key := _line_key(raw)
			if not key.is_empty() and values.has(key):
				lines.append("%s=%s" % [key, _quote(str(values[key]))])
				written[key] = true
			else:
				lines.append(raw)
		existing.close()

	while not lines.is_empty() and lines[lines.size() - 1].strip_edges().is_empty():
		lines.pop_back()

	for key in values:
		if not written.has(key):
			lines.append("%s=%s" % [key, _quote(str(values[key]))])

	var output := FileAccess.open(path, FileAccess.WRITE)
	if output == null:
		return FileAccess.get_open_error()
	output.store_string("\n".join(PackedStringArray(lines)) + "\n")
	output.close()
	return OK

static func _line_key(raw: String) -> String:
	var line := raw.strip_edges()
	if line.is_empty() or line.begins_with("#"):
		return ""
	if line.begins_with("export "):
		line = line.substr(7).strip_edges()
	var equals := line.find("=")
	if equals <= 0:
		return ""
	return line.substr(0, equals).strip_edges()

static func _quote(value: String) -> String:
	if value.is_empty():
		return ""
	for character in [" ", "\t", "#", "\"", "\\"]:
		if value.contains(character):
			return "\"%s\"" % value.replace("\\", "\\\\").replace("\"", "\\\"")
	return value

static func _unquote(value: String) -> String:
	if value.length() >= 2:
		var quote := value[0]
		if (quote == "\"" or quote == "'") and value[value.length() - 1] == quote:
			value = value.substr(1, value.length() - 2)
			if quote == "\"":
				value = value.replace("\\\"", "\"").replace("\\\\", "\\")
	return value
