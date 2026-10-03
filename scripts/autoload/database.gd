extends Node
## Zentrale Datenbank: Waffen, Gegner, Upgrades, Fachphasen, Wellen, Durchsagen.
## Alle Balancing-Werte stehen hier an einer Stelle.

const W := "res://assets/weapons/w_%02d.png"
const I := "res://assets/icons/i_%02d.png"
const P := "res://assets/proj/p_%02d.png"
const E := "res://assets/enemies/"

var weapons := {}
var enemies := {}
var upgrades := {}
var phases := {}
var waves := []
var evolutions := []   # {a, b, result}
var levelup_pool := ["atk_speed", "move_speed", "max_hp", "crit", "proj", "magnet", "dmg", "heal"]
var lines := {}
var events := {}
var skills := {}
var chapters := {}
var challenges := {}
var ags := {}
var start_weapon_cost := {}
var characters := {}
var sets := {}
var affixes := {}
var mutators := {}
var boss_info := {}          # id -> {patterns, summons, phase2}
var boss_order: Array = []   # Reihenfolge der Bosse im Endlos-Modus
const INITIAL_WEAPONS := ["mop", "water", "bunsen", "blowpipe", "chalk", "stapler", "megaphone", "compass"]
var _tex_cache := {}

func _ready() -> void:
	_build_weapons()
	_build_enemies()
	_build_upgrades()
	_build_phases()
	_build_waves()
	_build_lines()
	DbExtra.build(self)
	# Bodentexturen vorab laden: der Boden wird nur einmal gezeichnet und braucht sie sofort
	for t in ["grass", "tile", "wood"]:
		if ResourceLoader.exists("res://assets/textures/%s.png" % t):
			tex("res://assets/textures/%s.png" % t)

func tex(path: String) -> Texture2D:
	if path == "":
		return null
	if not _tex_cache.has(path):
		_tex_cache[path] = load(path)
	return _tex_cache[path]

var _status_cache := {}
## Status, den eine Waffe verursacht: "wet" (Wasser), "burn" (Feuer) oder "" – aus den Waffen-Tags abgeleitet
func weapon_status(id: String) -> String:
	if _status_cache.has(id):
		return _status_cache[id]
	var st := ""
	if weapons.has(id):
		var t: PackedStringArray = weapons[id].tags
		var w := t.has("water")
		var f := t.has("fire")
		if w and not f:
			st = "wet"
		elif f and not w:
			st = "burn"
	_status_cache[id] = st
	return st

func w_icon(i: int) -> String: return W % i
func i_icon(i: int) -> String: return I % i
func p_icon(i: int) -> String: return P % i

func subject_icon(subject: String) -> String:
	match subject:
		"Chemie": return I % 9
		"Physik": return I % 16
		"Sport": return I % 29
		"Musik": return W % 8
		"Mathe": return W % 17
		"Kunst": return W % 48
		_: return W % 43

func subject_symbol(subject: String) -> String:
	# Form-/Textsymbol, damit Faecher nicht nur ueber Farbe erkennbar sind
	match subject:
		"Chemie": return "(C)"
		"Physik": return "(P)"
		"Sport": return "(S)"
		"Musik": return "(M)"
		"Mathe": return "(+)"
		"Kunst": return "(K)"
		_: return "(H)"

func subject_color(subject: String) -> Color:
	match subject:
		"Chemie": return Color("7bd84a")
		"Physik": return Color("6aa8ff")
		"Sport": return Color("ff9a3c")
		"Musik": return Color("c78bff")
		"Mathe": return Color("ffd84a")
		"Kunst": return Color("ff6fa8")
		_: return Color("d8d8d8")

func _w(id: String, name: String, subject: String, kind: String, dmg: float, cd: float, reach: float, icon: Variant, color: Color, desc: String, price: int, extra := {}) -> WeaponData:
	var d := WeaponData.new()
	d.id = id; d.display_name = name; d.subject = subject; d.kind = kind
	d.damage = dmg; d.cooldown = cd; d.reach = reach; d.icon = icon if icon is String else W % int(icon)
	d.color = color; d.desc = desc; d.price = price
	for k in extra:
		d.set(k, extra[k])
	weapons[id] = d
	return d

func _build_weapons() -> void:
	_w("mop", "Wischmopp", "Hausmeister", "melee", 16, 0.8, 100, 43, Color("fff2a8"),
		"Breiter Schwung. Starker Rückstoß, quietscht.", 0,
		{knockback = 360.0, spread = 150.0, fire_sfx = "shoot_mop", tags = PackedStringArray(["melee"])})
	_w("bunsen", "Bunsenbrenner", "Chemie", "flame", 5, 0.5, 170, 10, Color("ff8a2a"),
		"Kurzer Feuerstrahl mit Brandspuren.", 14,
		{count = 6, speed = 420.0, knockback = 50.0, spread = 24.0, fire_sfx = "shoot_flame", tags = PackedStringArray(["fire"])})
	_w("water", "Wasserpistole", "Chemie", "bullet", 9, 0.34, 420, 1, Color("5ec8ff"),
		"Schnelles Projektil, federnder Rückstoß.", 12,
		{speed = 720.0, knockback = 150.0, proj_scale = 0.5, fire_sfx = "shoot_water", tags = PackedStringArray(["water"])})
	_w("megaphone", "Megafon", "Musik", "ring", 18, 2.3, 175, 8, Color("c78bff"),
		"Basswelle schleudert Gegner zurück. Betäubt manchmal.", 18,
		{knockback = 640.0, fire_sfx = "shoot_mega", tags = PackedStringArray(["sound"])})
	_w("compass", "Zirkel-Werfer", "Mathe", "bullet", 15, 1.1, 460, 47, Color("dfe6ee"),
		"Rotierender Zirkel prallt ab und spaltet Gegner.", 16,
		{speed = 520.0, pierce = 2, bounce = 3, knockback = 130.0, proj_scale = 0.55, fire_sfx = "shoot_compass", tags = PackedStringArray(["bounce"])})
	_w("blowpipe", "Erbsen-Blasrohr", "Sport", "bullet", 5, 0.2, 380, 7, Color("9ae36a"),
		"Schneller Dauerbeschuss mit kleinen Erbsen.", 10,
		{speed = 800.0, knockback = 60.0, spread = 6.0, fire_sfx = "shoot_pea", tags = PackedStringArray(["rapid"])})
	_w("stapler", "Tacker", "Mathe", "bullet", 8, 0.75, 360, 23, Color("8fd18f"),
		"Dreifach-Salve Heftklammern, durchschlägt Gegner.", 13,
		{count = 3, speed = 640.0, pierce = 1, spread = 16.0, knockback = 90.0, proj_icon = P % 0, proj_scale = 0.6, fire_sfx = "shoot_stapler", tags = PackedStringArray(["pierce"])})
	_w("chalk", "Kreide-Katapult", "Kunst", "lob", 22, 1.7, 380, 14, Color("ffd97a"),
		"Flächenangriff: Kreidewolke verlangsamt Gegner.", 15,
		{knockback = 220.0, fire_sfx = "shoot_chalk", proj_icon = P % 1, tags = PackedStringArray(["area"])})
	_w("steam", "Dampf-Kanone", "Chemie", "steam", 10, 2.4, 330, 15, Color("e8f4ff"),
		"EVOLUTION: Riesige Dampfwolke schmilzt Gegnergruppen und drückt sie weg.", 0,
		{knockback = 320.0, evolution = true, fire_sfx = "shoot_steam", proj_icon = P % 9, tags = PackedStringArray(["area", "fire", "water"])})
	evolutions.append({"a": "bunsen", "b": "water", "result": "steam"})

func _en(id: String, name: String, hp: float, speed: float, dmg: float, tex_files: Array, height: float, behavior: String, extra := {}) -> EnemyData:
	var d := EnemyData.new()
	d.id = id; d.display_name = name; d.hp = hp; d.speed = speed; d.contact_damage = dmg
	var arr := PackedStringArray()
	for t in tex_files:
		arr.append(E + t)
	d.textures = arr
	d.height = height; d.behavior = behavior
	for k in extra:
		d.set(k, extra[k])
	enemies[id] = d
	return d

func _build_enemies() -> void:
	_en("frog", "Frosch-Mutant", 24, 55, 8, ["frog.png"], 54, "hop",
		{radius = 16.0, xp = 3, coin_chance = 0.7, material = "slime", faces_right = false,
		params = {hop_cd = 2.6, windup = 0.55, hop_time = 0.42, hop_speed = 400.0}})
	_en("rat", "Riesenratte", 34, 62, 9, ["rat.png"], 58, "charge",
		{radius = 17.0, xp = 4, coin_chance = 0.75, material = "fur", faces_right = true,
		params = {charge_cd = 2.8, windup = 0.75, charge_time = 0.65, charge_speed = 430.0, trigger = 440.0}})
	_en("bird", "Schulranzen-Krabber", 12, 112, 6, ["bird_00.png", "bird_01.png", "bird_02.png", "bird_03.png"], 44, "chase",
		{radius = 11.0, xp = 2, coin_chance = 0.5, material = "cloth", faces_right = true})
	_en("nerd", "Streber-Mutant", 18, 72, 5, ["nerd_00.png", "nerd_01.png", "nerd_02.png"], 42, "shoot",
		{radius = 12.0, xp = 3, coin_chance = 0.6, material = "paper", faces_right = true,
		params = {pref = 270.0, shoot_cd = 2.0, windup = 0.5, proj_speed = 280.0, proj_dmg = 7.0, proj_icon = P % 10, proj_scale = 0.5}})
	_en("zombie", "Mensa-Zombie", 72, 38, 10, ["zombie_00.png"], 68, "lob",
		{radius = 18.0, xp = 6, coin_chance = 0.5, material = "meat", faces_right = true, tex_alt = E + "zombie_01.png",
		params = {pref = 300.0, lob_cd = 3.3, windup = 0.55, fly_time = 0.95, radius = 52.0, dmg = 12.0, fly_icon = "res://assets/items/sandwich.png", puddle = ""}})
	_en("football", "Football-Oktopus", 46, 92, 12, ["foot_00.png", "foot_01.png", "foot_02.png"], 62, "charge",
		{radius = 18.0, xp = 6, coin_chance = 0.5, material = "cloth", faces_right = true,
		params = {charge_cd = 2.2, windup = 0.5, charge_time = 0.7, charge_speed = 520.0, trigger = 480.0}})
	_en("brute", "Pausenhof-Rowdy", 210, 42, 14, ["brute_00.png"], 104, "slam",
		{radius = 26.0, xp = 20, coin_chance = 1.0, coin_value = 4, material = "meat", faces_right = true, elite = true, tex_alt = E + "brute_01.png",
		params = {slam_cd = 3.0, windup = 0.9, slam_radius = 125.0, slam_dmg = 20.0, trigger = 150.0}})
	_en("chemist", "Chemie-Mutant", 40, 52, 7, ["chemist.png"], 58, "lob",
		{radius = 15.0, xp = 6, coin_chance = 0.5, material = "glass", faces_right = false,
		params = {pref = 330.0, lob_cd = 3.6, windup = 0.45, fly_time = 1.0, radius = 58.0, dmg = 9.0, fly_icon = "res://assets/icons/i_09.png", puddle = "acid"}})
	_en("sheep", "Woll-Mutant", 42, 64, 8, ["sheep_00.png", "sheep_01.png", "sheep_02.png"], 54, "chase",
		{radius = 16.0, xp = 4, coin_chance = 0.55, material = "cloth", faces_right = false, params = {split = true}})
	_en("locker", "Spind-Mutant", 95, 34, 11, ["locker.png"], 96, "chase",
		{radius = 22.0, xp = 9, coin_chance = 1.0, coin_value = 2, material = "metal", faces_right = false,
		params = {spawn_on_death = ["bird", "bird", "frog"], rattle = true}})
	_en("coach", "Frau Eisenhart", 950, 72, 14, ["coach_boss.png"], 150, "boss",
		{radius = 34.0, xp = 100, coin_chance = 1.0, coin_value = 8, material = "meat", faces_right = false, elite = true})

func _up(id: String, name: String, desc: String, icon: String, subject := "", price := 8, shop := false, remark := "Fast richtig") -> UpgradeData:
	var u := UpgradeData.new()
	u.id = id; u.display_name = name; u.desc = desc; u.icon = icon; u.subject = subject
	u.price = price; u.shop = shop; u.remark = remark
	upgrades[id] = u
	return u

func _build_upgrades() -> void:
	_up("atk_speed", "Schnellschreiber", "+15 % Angriffstempo", I % 29, "Sport", 10, true, "Mehr üben")
	_up("move_speed", "Turnschuhe", "+10 % Bewegungstempo", I % 13, "Sport", 10, true, "Zu langsam")
	_up("max_hp", "Pausenbrot-Reserve", "+20 maximale Lebenspunkte", I % 20, "Hausmeister", 9, true, "Mehr lernen")
	_up("crit", "Glücksklee", "+10 % kritische Trefferchance", I % 6, "Mathe", 11, true, "Fast richtig")
	_up("proj", "Doppelte Munition", "+1 Projektil", I % 11, "Mathe", 15, true, "Knapp daneben")
	_up("magnet", "Magnet-Hufeisen", "Größere Aufsammelreichweite", I % 21, "Physik", 8, true, "Nicht beachtet")
	_up("dmg", "Hantel", "+12 % Schaden", I % 8, "Sport", 12, true, "Zu schwach")
	_up("heal", "Schulapfel", "Heilt 35 % der Lebenspunkte", I % 5, "Hausmeister", 8, true, "Später vielleicht")
	_up("goggles", "Schutzbrille", "+20 Lebenspunkte, +8 % Schaden", I % 27, "Chemie", 12, true, "Nicht relevant")
	_up("flask", "Erlenmeyerkolben", "+15 % Schaden, größere Explosionen", I % 9, "Chemie", 12, true, "Zu explosiv")

func _ph(id: String, name: String, icon: int, tint: Color, rule: String, ann: String, mods: Dictionary) -> void:
	var p := PhaseData.new()
	p.id = id; p.display_name = name; p.icon = I % icon; p.tint = tint
	p.rule = rule; p.announcement = ann; p.mods = mods
	phases[id] = p

func _build_phases() -> void:
	_ph("Physik", "Physik", 16, Color(0.88, 0.94, 1.04),
		"Projektile prallen 2x häufiger ab und fliegen schneller.",
		"Liebe Klasse, heute Physik! Newtons Gesetze gelten auch für Hausmeister.",
		{bounce = 2, proj_speed = 1.15})
	_ph("Sport", "Sport", 29, Color(1.02, 0.97, 0.91),
		"Alle bewegen sich schneller, Rückstoß +60 %.",
		"Sportunterricht! Bitte alle Schuhe binden. Auch die Mutanten.",
		{speed = 1.25, kb = 1.6})
	_ph("Chemie", "Chemie", 9, Color(0.94, 1.03, 0.94),
		"Säurepfützen entstehen, Explosionen +50 % Radius.",
		"Chemie! Bitte nichts anfassen, was blubbert. Danke.",
		{explosion = 1.5, acid = true})

func _build_waves() -> void:
	waves = [
		{duration = 30.0, groups = {bird = 8, frog = 4}},
		{duration = 36.0, groups = {frog = 6, rat = 4, bird = 8, locker = 1}},
		{duration = 40.0, groups = {rat = 5, nerd = 5, bird = 10, frog = 4, locker = 2}},
		{duration = 44.0, groups = {zombie = 3, nerd = 5, football = 3, sheep = 5, frog = 4, brute = 1, locker = 2}},
		{duration = 48.0, groups = {chemist = 3, zombie = 3, football = 4, sheep = 6, rat = 5, nerd = 4, brute = 2, locker = 3}},
	]

func _build_lines() -> void:
	lines = {
		"wave_1": ["Achtung, eine Durchsage des Rektors! Herr Scrubbs, legen Sie sofort den Besen nieder! Das Einschlagen von außerirdischem Eigentum ist laut Schulordnung §4b verboten."],
		"wave": ["Eine Durchsage: Wer nicht pünktlich zum Unterricht erscheint, bekommt einen Eintrag.", "Herr Scrubbs, die Flure sind immer noch nicht gewischt!", "Hier spricht der Rektor: Die Pausenaufsicht ist leider verhindert."],
		"chaos": ["Eine kurze Information für die Bio-Klasse: Herr Scrubbs eignet sich hervorragend als Anschauungsobjekt.", "Pädagogisch bedenklich, Herr Scrubbs. Pädagogisch bedenklich.", "Wer ihn erledigt, bekommt eine 1+ mit Sternchen!"],
		"boss": ["Herr Scrubbs! Da Sie die Flure nicht gewischt haben, setze ich Frau Eisenhart aus der Sporthalle auf Sie an. Sie bekommen eine glatte 6 in Betragen!"],
		"boss_2": ["Herr Scrubbs! Professor Ätz hat seine Formel verbessert und sich dabei gleich mit. Das Ergebnis dürfen Sie später aufwischen."],
		"boss_3": ["Herr Scrubbs, hier spricht der Rektor persönlich. Ihr Hausmeistervertrag endet in diesem Raum. Leider ebenso Sie."],
		"win": ["Das... das war nicht im Lehrplan."],
	}
