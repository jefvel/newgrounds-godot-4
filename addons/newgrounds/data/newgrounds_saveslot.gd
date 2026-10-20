class_name NewgroundsSaveSlot

var id: int;
var size: int;
var timestamp: int;
var url: String;
var datetime: String;

var data: String;

static func fromDict(d: Dictionary):
	var s = NewgroundsSaveSlot.new()
	s.setValuesFromDict(d)
	return s;
	
func is_empty():
	return timestamp == 0 and url.is_empty()

func setValuesFromDict(d: Dictionary):
	var s = self
	s.id = int(d.get("id", 0));
	s.size = int(d.get("size", 0));
	s.timestamp = int(d.get("timestamp", 0));
	s.url = str(d.get("url", ""));
	s.datetime = str(d.get("datetime", ""));
