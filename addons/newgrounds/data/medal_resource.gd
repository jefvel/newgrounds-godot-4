extends Resource
class_name MedalResource

enum Difficulty {
	Easy = 1,
	Moderate = 2,
	Challenging = 3,
	Difficult = 4,
	Brutal = 5,
}

@export var icon: Texture2D;

@export var name: String;
@export var description: String;
@export var icon_url: String;
@export var id: int;
@export var secret: bool;

@export var unlocked: bool;
@export var value: int;

@export var difficulty: Difficulty;

static func fromDict(d: Dictionary):
	var m = MedalResource.new()
	load_from_dict(m, d)
	return m

static func load_from_dict(m: MedalResource, d: Dictionary):
	m.description = d.description
	m.name = d.name
	m.icon_url = d.icon
	m.id = d.id
	m.secret = d.secret
	m.unlocked = d.unlocked
	m.value = d.value;
	m.difficulty = d.difficulty
