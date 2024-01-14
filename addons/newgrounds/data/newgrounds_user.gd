class_name NewgroundsUser

var icons: NewgroundsUserIcons;
var id: int;
var name: String;
var supporter: bool;

static func fromDict(u: Dictionary) -> NewgroundsUser:
	var user = NewgroundsUser.new();
	user.id = u.id;
	user.name = u.name;
	user.supporter = u.supporter;
	
	var i = NewgroundsUserIcons.new()
	if u.icons:
		i.large = u.icons.large;
		i.medium = u.icons.medium;
		i.small = u.icons.small;
	
	user.icons = i
	return user

func open_profile_url():
	var prefix = 'https:'
	if OS.has_feature('web'):
		prefix = '';
	OS.shell_open("%s//%s.newgrounds.com" % [prefix, name])
	
class NewgroundsUserIcons:
	var large: String = "";
	var medium: String = "";
	var small: String = "";
