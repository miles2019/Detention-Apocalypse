extends Node
## Speicherstand (user://save.json): Meta-Währungen, Skilltree, Freischaltungen, Challenges, Bestwerte, Archiv.

signal changed

var PATH := "user://save.json"

var data := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_user_args().has("--autotest"):
		PATH = "user://save_autotest.json"      # Bot-Läufe verändern niemals den echten Spielstand
		if not OS.get_cmdline_user_args().has("--keepsave") and FileAccess.file_exists(PATH):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_defaults()
	load_game()

func _defaults() -> void:
	data = {
		version = 1,
		passes = 0,            # Fehlstunden-Pässe (Skilltree)
		marken = 0,            # Nachsitzen-Marken (AGs)
		runs = 0, wins = 0, total_kills = 0, total_dodges = 0, total_coins = 0, total_evolutions = 0,
		best = {wave = 0, time = 9999.0, kills = 0, score = 0.0},
		skills = {},
		weapons_unlocked = Db.INITIAL_WEAPONS.duplicate(),
		start_weapon = "mop",
		chapters_unlocked = 1,
		chapter_clears = {},
		chapter_selected = 1,
		difficulty = 0,
		ags_unlocked = [],
		ag_selected = "",
		challenges = {},       # id -> {progress, claimed}
		archive = {enemies = [], weapons = [], evolutions = []},
		tutorial_seen = false,
		character = "scrubbs",
		chars_unlocked = ["scrubbs"],
		endless = false,
		endless_best = [],      # Bestenliste Endlos: [{wave, kills, time, char}]
	}

func load_game() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_merge(data, parsed)

func _merge(dst: Dictionary, src: Dictionary) -> void:
	for k in src:
		if dst.has(k) and dst[k] is Dictionary and src[k] is Dictionary:
			_merge(dst[k], src[k])
		else:
			dst[k] = src[k]

func save_game() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))
	changed.emit()

func reset_all() -> void:
	_defaults()
	save_game()

# ---------------------------------------------------------------- Währungen
func add_passes(n: int) -> void:
	data.passes += n
	save_game()

func add_marken(n: int) -> void:
	data.marken += n
	save_game()

func spend_passes(n: int) -> bool:
	if data.passes < n:
		return false
	data.passes -= n
	save_game()
	return true

func spend_marken(n: int) -> bool:
	if data.marken < n:
		return false
	data.marken -= n
	save_game()
	return true

# ---------------------------------------------------------------- Skilltree
func skill_level(id: String) -> int:
	return int(data.skills.get(id, 0))

func skill_cost(id: String) -> int:
	var s: Dictionary = Db.skills[id]
	return int(s.base_cost + s.step_cost * skill_level(id))

func buy_skill(id: String) -> bool:
	var s: Dictionary = Db.skills[id]
	if skill_level(id) >= s.max_level:
		return false
	if not spend_passes(skill_cost(id)):
		return false
	data.skills[id] = skill_level(id) + 1
	save_game()
	return true

## Summe des Meta-Bonus für einen Effekt-Schlüssel
func bonus(effect: String) -> float:
	var total := 0.0
	for id in Db.skills:
		var s: Dictionary = Db.skills[id]
		if s.effect == effect:
			total += float(s.amount) * skill_level(id)
	return total

# ---------------------------------------------------------------- Freischaltungen
func weapon_unlocked(id: String) -> bool:
	return data.weapons_unlocked.has(id)

func unlock_weapon(id: String) -> void:
	if not data.weapons_unlocked.has(id):
		data.weapons_unlocked.append(id)
		save_game()

func char_unlocked(id: String) -> bool:
	return data.chars_unlocked.has(id)

func unlock_char(id: String) -> bool:
	if char_unlocked(id):
		return true
	if not spend_marken(int(Db.characters[id].cost)):
		return false
	data.chars_unlocked.append(id)
	save_game()
	return true

func character() -> Dictionary:
	var id: String = data.character
	if not Db.characters.has(id) or not char_unlocked(id):
		id = "scrubbs"
	return Db.characters[id]

## Endlos-Ergebnis in die lokale Bestenliste eintragen; gibt den Platz (1-basiert) oder 0 zurück
func add_endless_score(wave: int, kills: int, time: float, char_name: String) -> int:
	var entry := {wave = wave, kills = kills, time = time, char = char_name}
	var list: Array = data.endless_best
	list.append(entry)
	list.sort_custom(func(a, b): return a.wave > b.wave or (a.wave == b.wave and a.kills > b.kills))
	var rank := list.find(entry) + 1
	while list.size() > 5:
		list.pop_back()
	return rank if rank <= 5 else 0

func ag_unlocked(id: String) -> bool:
	return data.ags_unlocked.has(id)

func chapter_unlocked(n: int) -> bool:
	return data.chapters_unlocked >= n

func unlock_chapter(n: int) -> void:
	if data.chapters_unlocked < n:
		data.chapters_unlocked = n
		save_game()

func discover(kind: String, id: String) -> void:
	var arr: Array = data.archive[kind]
	if not arr.has(id):
		arr.append(id)
		if kind == "evolutions":
			data.total_evolutions += 1
			add_stat("evolutions", 1)
		save_game()

# ---------------------------------------------------------------- Challenges
func add_stat(stat: String, n: float = 1.0) -> void:
	for id in Db.challenges:
		var c: Dictionary = Db.challenges[id]
		if c.stat == stat:
			var cur: Dictionary = data.challenges.get(id, {progress = 0.0, claimed = false})
			if cur.claimed:
				continue
			if c.get("mode", "sum") == "max":
				cur.progress = maxf(cur.progress, n)
			else:
				cur.progress += n
			data.challenges[id] = cur

func challenge_progress(id: String) -> float:
	return float(data.challenges.get(id, {}).get("progress", 0.0))

func challenge_done(id: String) -> bool:
	return challenge_progress(id) >= float(Db.challenges[id].goal)

func challenge_claimed(id: String) -> bool:
	return bool(data.challenges.get(id, {}).get("claimed", false))

func claim_challenge(id: String) -> bool:
	if not challenge_done(id) or challenge_claimed(id):
		return false
	var cur: Dictionary = data.challenges.get(id, {progress = 0.0, claimed = false})
	cur.claimed = true
	data.challenges[id] = cur
	var c: Dictionary = Db.challenges[id]
	data.passes += int(c.get("passes", 0))
	data.marken += int(c.get("marken", 0))
	save_game()
	return true

func claimable_count() -> int:
	var n := 0
	for id in Db.challenges:
		if challenge_done(id) and not challenge_claimed(id):
			n += 1
	return n
