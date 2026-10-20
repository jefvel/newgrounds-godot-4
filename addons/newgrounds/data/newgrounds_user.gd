class_name NewgroundsUser

var icons: NewgroundsUserIcons;
var id: int;
var name: String;
var supporter: bool;

static func fromDict(u: Dictionary) -> NewgroundsUser:
	var user = NewgroundsUser.new();
	user.id = int(u.get("id", 0));
	user.name = str(u.get("name", ""));
	user.supporter = bool(u.get("supporter", false));

	var icons = u.get("icons")
	var i = NewgroundsUserIcons.new()
	if icons is Dictionary:
		i.large = str(icons.get("large", ""));
		i.medium = str(icons.get("medium", ""));
		i.small = str(icons.get("small", ""));

	user.icons = i
	return user

func open_profile_url():
	if name.is_empty():
		return
	var prefix = 'https:'
	if OS.has_feature('web'):
		prefix = '';
	OS.shell_open("%s//%s.newgrounds.com" % [prefix, name])
	
class NewgroundsUserIcons:
	var large: String = "";
	var medium: String = "";
	var small: String = "";
