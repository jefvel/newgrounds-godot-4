class_name NewgroundsScoreboardItem

var index: int;

var user: NewgroundsUser = null;
var formatted_value: String;
var value: int;
var tag: String;

static func fromDict(d: Dictionary) -> NewgroundsScoreboardItem:
	var s = NewgroundsScoreboardItem.new()
	
	s.formatted_value = d.formatted_value;
	s.value = d.value
	if d.has("tag") and d.tag:
		s.tag = d.tag;
	if d.has("user") and d.user:
		s.user = NewgroundsUser.fromDict(d.user)
	
	return s
