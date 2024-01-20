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
	return timestamp == 0 and !url

func setValuesFromDict(d: Dictionary):
	var s = self
	s.id = d.id;
	s.size = d.size;
	s.timestamp = d.timestamp;
	if d.url:
		s.url = d.url;
	if d.datetime:
		s.datetime = d.datetime;
