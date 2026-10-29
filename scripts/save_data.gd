extends Node
## Autoload "Save": persistent progress (gems, cleared levels, skins, records).

const PATH := "user://turbopip_save.json"

var data := {
	"gems": 0,
	"levels": {},        # "1-1" -> best crystal count (0..3)
	"skin": "menthe",
	"owned": ["menthe"],
	"best": {},          # mini-game records
	"sound": true,
}

func _ready() -> void:
	load_data()

func load_data() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		for k in d:
			data[k] = d[k]
	data.gems = int(data.gems)

func persist() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))

func add_gems(n: int) -> void:
	data.gems = int(data.gems) + n
	persist()

static func level_key(w: int, l: int) -> String:
	return "%d-%d" % [w + 1, l + 1]

func level_done(w: int, l: int) -> bool:
	return data.levels.has(level_key(w, l))

func level_crystals(w: int, l: int) -> int:
	return int(data.levels.get(level_key(w, l), 0))

func is_unlocked(w: int, l: int) -> bool:
	if w == 0 and l == 0:
		return true
	if l > 0:
		return level_done(w, l - 1)
	return level_done(w - 1, WorldData.LEVELS_PER_WORLD - 1)

func world_crystals(w: int) -> int:
	var n := 0
	for l in WorldData.LEVELS_PER_WORLD:
		n += level_crystals(w, l)
	return n

func best(k: String) -> int:
	return int(data.best.get(k, 0))

func set_best(k: String, v: int) -> bool:
	if v > best(k):
		data.best[k] = v
		persist()
		return true
	return false
