class_name DbExtra
extends RefCounted
## Erweiterte Inhalte der Datenbank: neue Waffen + Evolutionen, Events, Skilltree, Kapitel, Challenges, AGs.

const W := "res://assets/weapons/w_%02d.png"
const I := "res://assets/icons/i_%02d.png"
const P := "res://assets/proj/p_%02d.png"
const E := "res://assets/enemies/"

static func build(db: Node) -> void:
	_enemies(db)
	_weapons(db)
	_events(db)
	_skills(db)
	_chapters(db)
	_challenges(db)
	_ags(db)

static func _weapons(db: Node) -> void:
	db._w("ruler", "Lineal-Schwert", "Mathe", "melee", 12, 0.5, 95, 34, Color("cfe3ff"),
		"Schnelle Hiebe mit präzisem Winkel.", 11, {knockback = 210.0, spread = 95.0, fire_sfx = "shoot_mop", tags = PackedStringArray(["melee"])})
	db._w("plunger", "Pömpel", "Hausmeister", "melee", 15, 1.0, 125, 31, Color("e04040"),
		"Saugt Gegner heran und betäubt sie kurz.", 10, {knockback = 0.0, spread = 60.0, fire_sfx = "kick", params = {pull = true, stun = 0.8}})
	db._w("crowbar", "Brecheisen", "Hausmeister", "slam", 42, 1.9, 118, 32, Color("9aa7c4"),
		"Wuchtiger Rundumschlag mit Erdbeben.", 12, {knockback = 560.0, fire_sfx = "explosion"})
	db._w("tennis", "Tennis-Kanone", "Sport", "bullet", 14, 0.7, 460, 13, Color("e8ff6a"),
		"Der Ball prallt fünfmal ab.", 11, {speed = 760.0, bounce = 5, proj_icon = P % 3, proj_scale = 0.45, knockback = 170.0, fire_sfx = "shoot_compass"})
	db._w("whistle", "Trillerpfeife", "Sport", "ring", 0, 5.5, 230, 12, Color("e0e8f0"),
		"Betäubt alle Gegner in Reichweite.", 12, {knockback = 90.0, fire_sfx = "phase_Sport", params = {stun_all = 1.3, no_damage = true}})
	db._w("dodgeball", "Völkerball", "Sport", "ball", 20, 3.0, 420, P % 3, Color("ffffff"),
		"Riesiger Ball prallt durch die Arena und trifft immer wieder.", 14, {speed = 380.0, knockback = 260.0, fire_sfx = "shoot_mega"})
	db._w("paperclip", "Büroklammer-Schleuder", "Mathe", "bullet", 9, 0.8, 440, 21, Color("c9d2e0"),
		"Springt auf nahe Gegner über.", 12, {speed = 620.0, proj_icon = W % 21, proj_scale = 0.3, knockback = 90.0, fire_sfx = "shoot_stapler", params = {chain = 2}})
	db._w("cleaner", "Reinigungsmittel", "Chemie", "cone", 6, 0.45, 160, 22, Color("e8ffff"),
		"Schäumender Sprühnebel verlangsamt Gegner.", 10, {knockback = 40.0, spread = 42.0, fire_sfx = "shoot_flame", params = {foam = true, slow = 0.5}})
	db._w("projector", "Overhead-Projektor", "Physik", "cone", 16, 1.8, 230, 19, Color("fff3a0"),
		"Blendet Gegner im Lichtkegel und setzt den Boden in Brand.", 15, {knockback = 120.0, spread = 50.0, fire_sfx = "phase_Physik", params = {blind = 0.9, fire = true}})
	db._w("gum", "Kaugummi-Blaster", "Kunst", "bullet", 5, 0.6, 420, 18, Color("ff7fc0"),
		"Klebt Gegner fest – nach kurzer Zeit platzen sie.", 12, {speed = 520.0, knockback = 40.0, fire_sfx = "splat", params = {sticky = 1.3}})
	db._w("calculator", "Taschenrechner", "Mathe", "bullet", 5, 0.28, 400, 25, Color("8fe0a0"),
		"Jeder Treffer in Folge erhöht den Multiplikator.", 12, {speed = 640.0, spread = 4.0, knockback = 50.0, fire_sfx = "shoot_pea", params = {combo = true}})
	# --- Evolutionen
	db._w("geometry", "Geometrie-Todesstern", "Mathe", "orbit", 11, 0.2, 115, 17, Color("ffd84a"),
		"EVOLUTION: Rotierende Zirkel schneiden Ringbahnen um Mr. Scrubbs.", 0, {evolution = true, params = {blades = 4}, fire_sfx = "shoot_compass"})
	db._w("gumsalvo", "Klebrige Salve", "Kunst", "bullet", 6, 0.12, 440, 16, Color("ff7fc0"),
		"EVOLUTION: Maschinengewehr aus Kaugummi – alles klebt und explodiert.", 0, {evolution = true, speed = 700.0, spread = 10.0, knockback = 30.0, fire_sfx = "shoot_pea", params = {sticky = 0.9}})
	db._w("diktat", "Diktat-Terror", "Musik", "ring", 30, 3.2, 270, 9, Color("c78bff"),
		"EVOLUTION: Schallverstärkte Rechtschreibfehler betäuben alles im Raum.", 0, {evolution = true, knockback = 520.0, fire_sfx = "shoot_mega", params = {stun_all = 1.4, letters = true}})
	db._w("referee", "Schiedsrichter des Untergangs", "Sport", "ball", 26, 5.0, 480, 35, Color("ffe08a"),
		"EVOLUTION: Der Ball folgt deinem Zielpunkt und verteilt Betäubungen.", 0, {evolution = true, speed = 420.0, knockback = 320.0, fire_sfx = "shoot_mega", params = {homing = true, stun = 1.0}})
	db._w("staplehail", "Heftklammer-Hagel", "Mathe", "bullet", 9, 0.75, 400, 5, Color("8fd18f"),
		"EVOLUTION: Klammern verbinden Gegner – Schaden springt weit über.", 0, {evolution = true, count = 5, speed = 640.0, spread = 44.0, pierce = 1, proj_icon = P % 0, proj_scale = 0.6, fire_sfx = "shoot_stapler", params = {chain = 3}})
	db._w("turbo", "Turbo-Schrubbkanone", "Chemie", "cone", 12, 0.4, 240, 41, Color("c8ffff"),
		"EVOLUTION: Reinigt Pfützen und verwandelt sie in heilende, rutschige Zonen.", 0, {evolution = true, spread = 56.0, knockback = 80.0, fire_sfx = "shoot_flame", params = {foam = true, slow = 0.4, clean = true}})
	db._w("compound", "Zinseszins-Klinge", "Mathe", "melee", 18, 0.4, 125, 48, Color("ffe066"),
		"EVOLUTION: Jeder Treffer in Folge erhöht den Multiplikator weiter.", 0, {evolution = true, knockback = 230.0, spread = 135.0, fire_sfx = "shoot_mop", params = {combo = true, big = true}})
	db.evolutions.append({"a": "ruler", "b": "compass", "result": "geometry"})
	db.evolutions.append({"a": "blowpipe", "b": "gum", "result": "gumsalvo"})
	db.evolutions.append({"a": "chalk", "b": "megaphone", "result": "diktat"})
	db.evolutions.append({"a": "whistle", "b": "dodgeball", "result": "referee"})
	db.evolutions.append({"a": "stapler", "b": "paperclip", "result": "staplehail"})
	db.evolutions.append({"a": "mop", "b": "cleaner", "result": "turbo"})
	db.evolutions.append({"a": "calculator", "b": "ruler", "result": "compound"})
	# Werkbank-Preise (Fehlstunden-Pässe) für noch nicht freigeschaltete Startwaffen
	for id in db.weapons:
		var wd: WeaponData = db.weapons[id]
		if not wd.evolution and not db.INITIAL_WEAPONS.has(id):
			db.start_weapon_cost[id] = int(wd.price * 0.7) + 2

static func _events(db: Node) -> void:
	db.events = {
		hitzefrei = {name = "Hitzefrei!", icon = I % 14, color = Color(1.0, 0.55, 0.2), duration = 16.0,
			rule = "Alle bewegen sich 20 % schneller.", mods = {speed = 1.2},
			text = "Achtung, Durchsage: Die Schulheizung wurde überdreht. Hitzefrei! Bitte nicht rennen. Alle: rennen."},
		vokabeltest = {name = "Unerwarteter Vokabeltest!", icon = I % 1, color = Color(0.9, 0.85, 0.4), duration = 16.0,
			rule = "Gegner treffen 50 % härter, du erhältst +50 % Erfahrung.", mods = {enemy_dmg = 1.5, xp = 1.5},
			text = "Liebe Mutanten, wir schreiben einen unangekündigten Vokabeltest. Fehler werden schmerzhaft bestraft."},
		pausenaufsicht = {name = "Pausenaufsicht!", icon = I % 7, color = Color(1.0, 0.35, 0.3), duration = 0.0,
			rule = "Elite-Aufsichten jagen dich.", mods = {},
			text = "Die Pausenaufsicht ist jetzt für Sie zuständig, Herr Scrubbs. Zwei Kollegen sind schon unterwegs."},
		raeumung = {name = "Räumungsübung!", icon = I % 26, color = Color(1.0, 0.7, 0.2), duration = 14.0,
			rule = "Bereiche der Arena brennen – nicht stehen bleiben!", mods = {},
			text = "Dies ist eine Räumungsübung. Bitte verlassen Sie brennende Bereiche geordnet und zügig."},
		stromausfall = {name = "Stromausfall!", icon = I % 27, color = Color(0.5, 0.6, 1.0), duration = 14.0,
			rule = "Dunkelheit: nur dein Wischer-Scheinwerfer leuchtet.", mods = {},
			text = "Es gab einen kleinen Stromausfall. Bitte bewahren Sie Ruhe und Ihre Taschenlampe."},
	}

static func _sk(db: Node, id: String, name: String, desc: String, icon: String, max_level: int, base_cost: int, step_cost: int, effect: String, amount: float) -> void:
	db.skills[id] = {name = name, desc = desc, icon = icon, max_level = max_level, base_cost = base_cost, step_cost = step_cost, effect = effect, amount = amount}

static func _skills(db: Node) -> void:
	_sk(db, "vitality", "Zähe Haut", "+10 maximale Lebenspunkte pro Stufe", I % 20, 5, 3, 2, "max_hp", 10.0)
	_sk(db, "sprint", "Sportunterricht", "+4 % Bewegungstempo pro Stufe", I % 13, 5, 3, 2, "speed", 0.04)
	_sk(db, "power", "Nachhilfe", "+6 % Schaden pro Stufe", I % 8, 5, 4, 2, "dmg", 0.06)
	_sk(db, "crit", "Glückskeks", "+2 % kritische Trefferchance pro Stufe", I % 6, 5, 3, 2, "crit", 0.02)
	_sk(db, "magnet", "Magnetschuhe", "+25 Aufsammelreichweite pro Stufe", I % 21, 4, 2, 2, "magnet", 25.0)
	_sk(db, "purse", "Taschengeld", "+4 Start-Pausengeld pro Stufe", I % 24, 5, 2, 1, "start_money", 4.0)
	_sk(db, "study", "Streber-Gen", "+8 % Erfahrung pro Stufe", I % 3, 5, 3, 2, "xp", 0.08)
	_sk(db, "slot", "Größerer Spind", "+1 Waffenplatz pro Stufe", I % 22, 2, 15, 10, "slots", 1.0)
	_sk(db, "haggle", "Verhandlungsgeschick", "-8 % Kioskpreise pro Stufe", I % 4, 3, 4, 3, "discount", 0.08)
	_sk(db, "reroll", "Gratis-Radiergummi", "Erster Reroll im Kiosk ist kostenlos", I % 11, 1, 8, 0, "free_reroll", 1.0)
	_sk(db, "excuse", "Entschuldigungszettel", "Einmal pro Run mit 50 % Leben wiederbeleben", I % 1, 1, 20, 0, "revive", 1.0)
	_sk(db, "dash", "Turnbeutel", "-8 % Ausweich-Abklingzeit pro Stufe", I % 29, 3, 3, 2, "dash_cd", 0.08)
	_sk(db, "regen", "Pausenbrot-Abo", "+6 Leben am Ende jeder Welle pro Stufe", I % 5, 3, 3, 3, "wave_heal", 6.0)

static func _chapters(db: Node) -> void:
	db.chapters = {
		0: {id = 0, name = "Schulhof", sub = "Hub", style = "yard", boss = "coach", boss_name = "", boss_title = "", hp_scale = 1.0, phases = ["Physik"], reward = 0.0,
			floor = {a = Color(0.50, 0.52, 0.55), b = Color(0.46, 0.48, 0.51), grout = Color(0.25, 0.26, 0.3, 0.5)}, waves = [], intro = ""},
		1: {id = 1, name = "Erdgeschoss", sub = "Flure & Klassenzimmer", style = "classroom", boss = "coach", boss_name = "Frau Eisenhart",
			boss_title = "Sportlehrerin", hp_scale = 1.0, phases = ["Physik", "Sport", "Chemie"], reward = 1.0,
			floor = {a = Color(0.60, 0.56, 0.45), b = Color(0.54, 0.53, 0.45), grout = Color(0.3, 0.28, 0.24, 0.55)},
			waves = db.waves, intro = "Das Erdgeschoss: Flure, Klassenzimmer und eine sehr schlecht gelaunte Sportlehrerin."},
		2: {id = 2, name = "1. Stock", sub = "MINT-Trakt", style = "lab", boss = "etz", boss_name = "Prof. Dr. Ätz",
			boss_title = "Chemielehrer", hp_scale = 1.5, phases = ["Chemie", "Physik", "Chemie", "Sport"], reward = 1.6,
			floor = {a = Color(0.62, 0.7, 0.62), b = Color(0.54, 0.64, 0.58), grout = Color(0.25, 0.32, 0.3, 0.6)},
			waves = [
				{duration = 38.0, groups = {chemist = 4, nerd = 6, bird = 8, frog = 4}},
				{duration = 42.0, groups = {sheep = 6, chemist = 4, nerd = 6, locker = 1, rat = 4}},
				{duration = 46.0, groups = {zombie = 4, chemist = 5, football = 4, nerd = 5, locker = 2}},
				{duration = 50.0, groups = {brute = 1, chemist = 6, sheep = 6, zombie = 3, football = 4, locker = 2}},
				{duration = 54.0, groups = {brute = 2, chemist = 8, sheep = 8, zombie = 4, nerd = 6, locker = 3}},
			], intro = "Der MINT-Trakt: Hier blubbert es, zischt es und gelegentlich explodiert es aus pädagogischen Gründen."},
		3: {id = 3, name = "2. Stock", sub = "Bibliothek & Kunst", style = "library", boss = "zorn", boss_name = "Rektor Dr. Zorn",
			boss_title = "Schulleiter", hp_scale = 2.1, phases = ["Physik", "Sport", "Chemie"], reward = 2.4,
			floor = {a = Color(0.5, 0.36, 0.27), b = Color(0.44, 0.31, 0.23), grout = Color(0.2, 0.12, 0.09, 0.6)},
			waves = [
				{duration = 40.0, groups = {nerd = 8, bird = 10, sheep = 6, locker = 1}},
				{duration = 44.0, groups = {football = 5, zombie = 4, nerd = 8, chemist = 3, locker = 2}},
				{duration = 48.0, groups = {brute = 2, sheep = 8, rat = 8, nerd = 6, locker = 2}},
				{duration = 52.0, groups = {zombie = 6, chemist = 6, football = 6, brute = 2, locker = 3}},
				{duration = 56.0, groups = {brute = 3, football = 8, zombie = 6, chemist = 6, sheep = 10, locker = 3}},
			], intro = "Die Bibliothek: Bücherlabyrinthe, Stille und ein Rektor, der seine Mutation für eine Schulveranstaltung hält."},
	}

static func _ch(db: Node, id: String, name: String, desc: String, stat: String, goal: float, passes: int, marken: int = 0, mode: String = "sum") -> void:
	db.challenges[id] = {name = name, desc = desc, stat = stat, goal = goal, passes = passes, marken = marken, mode = mode}

static func _challenges(db: Node) -> void:
	_ch(db, "kills_100", "Pausenhof-Ordnung", "Besiege insgesamt 100 Mutanten.", "kills", 100, 3)
	_ch(db, "kills_500", "Schulweghelfer", "Besiege insgesamt 500 Mutanten.", "kills", 500, 8, 1)
	_ch(db, "dodge_25", "Sportlich!", "Weiche 25x im letzten Moment aus.", "dodges", 25, 3)
	_ch(db, "coins_150", "Taschengeld-Millionär", "Sammle insgesamt 150 Pausengeld.", "coins", 150, 3)
	_ch(db, "evo_1", "Ordnungsgemäße Fusion", "Entdecke deine erste Evolutionswaffe.", "evolutions", 1, 6, 2)
	_ch(db, "combo_8", "Gruppenarbeit", "Erreiche eine Kill-Kette von 8.", "chain_max", 8, 3, 0, "max")
	_ch(db, "events_5", "Durchsagen-Profi", "Überstehe 5 Schul-Events.", "events", 5, 4)
	_ch(db, "flawless", "Vorbildliches Betragen", "Schließe 3 Wellen ohne Schaden ab.", "flawless_waves", 3, 5)
	_ch(db, "level_10", "Klassenbester", "Erreiche Stufe 10 in einem Run.", "level_max", 10, 4, 0, "max")
	_ch(db, "clear_1", "Erdgeschoss gesäubert", "Besiege Frau Eisenhart.", "chapter1", 1, 6, 3)
	_ch(db, "clear_2", "MINT bestanden", "Besiege Prof. Dr. Ätz.", "chapter2", 1, 10, 4)
	_ch(db, "clear_3", "Rektorat erobert", "Besiege Rektor Dr. Zorn.", "chapter3", 1, 15, 6)

static func _ags(db: Node) -> void:
	db.ags = {
		hamster = {name = "Schul-Hamster", desc = "Bringt regelmäßig Pausengeld und vergrößert die Aufsammelreichweite.", cost = 3,
			tex = E + "rat.png", height = 26.0, tint = Color(1.0, 0.85, 0.6)},
		hund = {name = "Schul-Hund", desc = "Bellt regelmäßig: Mutanten in der Nähe erstarren vor Schreck.", cost = 5,
			tex = E + "sheep_00.png", height = 32.0, tint = Color(0.75, 0.55, 0.4)},
		kroete = {name = "Labor-Kröte", desc = "Heilt Mr. Scrubbs regelmäßig und frisst Säurepfützen.", cost = 7,
			tex = E + "frog.png", height = 30.0, tint = Color(0.8, 1.0, 0.7)},
	}

static func _enemies(db: Node) -> void:
	db._en("etz", "Prof. Dr. Ätz", 1100, 62, 14, ["chemist.png"], 150, "boss",
		{radius = 30.0, xp = 100, coin_chance = 1.0, coin_value = 8, material = "glass", faces_right = false, elite = true})
	db._en("zorn", "Rektor Dr. Zorn", 1500, 56, 16, ["bigfrog_00.png"], 170, "boss",
		{radius = 36.0, xp = 120, coin_chance = 1.0, coin_value = 10, material = "slime", faces_right = false, elite = true, tex_alt = E + "bigfrog_01.png"})
