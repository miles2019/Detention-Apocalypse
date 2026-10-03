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
	_characters(db)
	_sets(db)
	_affixes(db)

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
		"Schäumender Sprühnebel verlangsamt Gegner und macht sie nass.", 10, {knockback = 40.0, spread = 42.0, fire_sfx = "shoot_flame", tags = PackedStringArray(["water"]), params = {foam = true, slow = 0.5}})
	db._w("projector", "Overhead-Projektor", "Physik", "cone", 16, 1.8, 230, 19, Color("fff3a0"),
		"Blendet Gegner im Lichtkegel und setzt den Boden in Brand.", 15, {knockback = 120.0, spread = 50.0, fire_sfx = "phase_Physik", tags = PackedStringArray(["fire"]), params = {blind = 0.9, fire = true}})
	db._w("gum", "Kaugummi-Blaster", "Kunst", "bullet", 5, 0.6, 420, 18, Color("ff7fc0"),
		"Klebt Gegner fest – nach kurzer Zeit platzen sie.", 12, {speed = 520.0, knockback = 40.0, fire_sfx = "splat", params = {sticky = 1.3}})
	db._w("calculator", "Taschenrechner", "Mathe", "bullet", 5, 0.28, 400, 25, Color("8fe0a0"),
		"Jeder Treffer in Folge erhöht den Multiplikator.", 12, {speed = 640.0, spread = 4.0, knockback = 50.0, fire_sfx = "shoot_pea", params = {combo = true}})
	db._w("soup", "Suppenkelle", "Chemie", "lob", 20, 1.5, 360, 37, Color("ff9a4a"),
		"Schleudert heiße Mensa-Suppe: Flächenschaden und eine brennende Pfütze.", 13, {knockback = 180.0, fire_sfx = "shoot_chalk", proj_icon = P % 1, params = {puddle = "fire"}})
	# --- Waffen mit eigener Spielweise (Fallen, Sog, Geschütz, Bumerang, Scharfschütze ...)
	db._w("banana", "Bananenschale", "Sport", "mine", 18, 1.7, 300, 0, Color("ffe24a"),
		"Legt Schalen hinter dir ab. Wer ausrutscht, ist betäubt und reißt andere mit um.", 10, {fire_sfx = "splat"})
	db._w("magnet", "Magnet-Kanone", "Physik", "vortex", 6, 4.4, 380, 2, Color("6aa8ff"),
		"Erzeugt ein Sogfeld: zieht Gegner und Münzen zusammen und implodiert. Perfekt vor Flächenangriffen.", 15, {fire_sfx = "phase_Physik"})
	db._w("crossbow", "Bleistift-Armbrust", "Mathe", "bullet", 30, 1.5, 640, 3, Color("ffd24a"),
		"Scharfschuss durch alle Gegner. Je weiter der Bolzen fliegt, desto mehr Schaden (bis +100 %).", 15,
		{speed = 1150.0, pierce = 99, knockback = 240.0, proj_icon = P % 10, proj_scale = 0.6, fire_sfx = "shoot_compass", params = {snipe = true}})
	db._w("keys", "Schlüsselbund", "Hausmeister", "boomerang", 13, 1.3, 300, 4, Color("f2c230"),
		"Fliegt los und kommt zurück – trifft auf Hin- und Rückweg alles in der Bahn.", 11, {speed = 600.0, knockback = 120.0, fire_sfx = "shoot_compass"})
	db._w("plane", "Papierflieger-Werfer", "Kunst", "bullet", 8, 0.55, 520, 26, Color("f4f4ff"),
		"Flieger suchen sich ihr Ziel selbst – auch um Tische herum.", 12,
		{speed = 400.0, knockback = 70.0, proj_icon = P % 8, proj_scale = 0.5, fire_sfx = "shoot_pea", params = {seek = true}})
	db._w("spray", "Sprühdose", "Kunst", "cone", 5, 0.5, 150, 20, Color("ff5fa8"),
		"Sprüht Farbflächen: Gegner darin werden langsam und nehmen Schaden, du läufst darauf 25 % schneller.", 11,
		{knockback = 40.0, spread = 40.0, fire_sfx = "shoot_flame", params = {paint = true, slow = 0.3}})
	db._w("bat", "Baseballschläger", "Sport", "melee", 20, 0.95, 108, 36, Color("ffb070"),
		"Schlägt gegnerische Geschosse zurück. Getroffene Gegner fliegen als Kegelkugel in ihre Mitschüler.", 13,
		{knockback = 640.0, spread = 120.0, fire_sfx = "kick", params = {reflect = true, launch = true}})
	db._w("sledge", "Vorschlaghammer", "Hausmeister", "fissure", 28, 2.4, 420, 44, Color("ffc27a"),
		"Schlag in den Boden: eine Erdspalte läuft nach vorn, betäubt und zertrümmert Tische.", 15, {knockback = 300.0, fire_sfx = "explosion"})
	db._w("screwdriver", "Schraubenzieher", "Physik", "melee", 7, 0.28, 88, 33, Color("c8d6ff"),
		"Blitzschnelle Stiche lockern die Schrauben: jeder Treffer +8 % erlittener Schaden (bis 5x).", 11,
		{knockback = 60.0, spread = 50.0, fire_sfx = "click", params = {shred = true}})
	db._w("broom", "Besen", "Hausmeister", "melee", 11, 0.9, 138, 39, Color("e8c070"),
		"Riesiger Bogen: kehrt Gegner weit weg und alle Münzen und Erfahrung im Bogen zu dir.", 10,
		{knockback = 540.0, spread = 175.0, fire_sfx = "shoot_mop", params = {sweep = true}})
	db._w("pipe", "Leckes Wasserrohr", "Physik", "turret", 6, 5.0, 380, 29, Color("5ec8ff"),
		"Stellt ein Geschütz auf, das selbstständig spritzt und Gegner nass macht.", 14, {fire_sfx = "locker", tags = PackedStringArray(["water"])})
	db._w("sock", "Stinksocken-Mörser", "Chemie", "bullet", 16, 1.6, 440, 11, Color("b8d84a"),
		"Die Socke platzt beim Aufprall und hinterlässt eine Stinkwolke, die Gegner vergiftet und bremst.", 14,
		{speed = 430.0, knockback = 160.0, proj_icon = P % 11, proj_scale = 0.6, fire_sfx = "shoot_chalk", params = {explode = 85.0, cloud = true}})
	db._w("slingshot", "Zwille", "Sport", "bullet", 12, 0.8, 540, 6, Color("ff7a5a"),
		"Wer stillsteht, zielt besser: bis zu +200 % Schaden, solange du dich nicht bewegst.", 11,
		{speed = 950.0, knockback = 220.0, proj_icon = P % 6, proj_scale = 0.4, fire_sfx = "shoot_pea", params = {still = true}})
	# --- Evolutionen
	db._w("trident", "Dreizack der Tafelaufsicht", "Mathe", "bullet", 30, 1.1, 680, 40, Color("ffd24a"),
		"EVOLUTION: Drei Scharfschuss-Bolzen auf einmal – jeder durchschlägt den ganzen Raum.", 0,
		{evolution = true, count = 3, spread = 14.0, speed = 1250.0, pierce = 99, knockback = 260.0, proj_icon = P % 10, proj_scale = 0.65, fire_sfx = "shoot_compass", params = {snipe = true}})
	db._w("sprinkler", "Sprinkleranlage", "Physik", "turret", 8, 4.0, 380, 30, Color("5ec8ff"),
		"EVOLUTION: Das Rohr sprüht in alle Richtungen und hält doppelt so lange.", 0,
		{evolution = true, fire_sfx = "locker", tags = PackedStringArray(["water"]), params = {jets = 6}})
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
	db.evolutions.append({"a": "crossbow", "b": "magnet", "result": "trident"})
	db.evolutions.append({"a": "pipe", "b": "water", "result": "sprinkler"})
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

static func _characters(db: Node) -> void:
	db.characters = {
		scrubbs = {id = "scrubbs", name = "Mr. Scrubbs", title = "Der Hausmeister", cost = 0, tex = "res://assets/chars/scrubbs.png",
			tint = Color.WHITE, height = 66.0, hp = 100.0, speed = 1.0, dmg = 1.0, slots = 4, xp = 1.0, area = 1.0, heal = 1.0, options = 3,
			start_weapon = "", bars = {hp = 3, speed = 3, dmg = 3}, diff = "Normal", ability = "Reinigungs-Aura",
			desc = "Ausgewogenes Startprofil. Seine Reinigungs-Aura wischt Säurepfützen auf und verwandelt sie in Heilung. Startwaffe frei wählbar (Werkbank).",
			goals = ["Überlebe die Mutierte Schule (Kapitel 1)", "Wische 10 Säurepfützen auf", "Besiege Frau Eisenhart ohne Treffer"]},
		kelle = {id = "kelle", name = "Frau Kelle", title = "Die Mensa-Köchin", cost = 5, tex = "res://assets/chars/scrubbs.png",
			tint = Color(1.0, 0.78, 0.72), height = 76.0, hp = 140.0, speed = 0.85, dmg = 1.0, slots = 4, xp = 1.0, area = 1.35, heal = 2.0, options = 3,
			start_weapon = "soup", bars = {hp = 5, speed = 2, dmg = 3}, diff = "Leicht", ability = "Nachschlag",
			desc = "Flächenschaden-Spezialistin: +35 % Radius aller Flächenangriffe und viel Leben, dafür langsam. Heil-Drops wirken doppelt. Startet mit der Suppenkelle.",
			goals = ["Triff 5 Gegner mit einer Suppenkelle", "Gewinne ein Kapitel ohne Ausweichen", "Erreiche Welle 10 im Endlos-Nachsitzen"]},
		probe = {id = "probe", name = "Herr Probe", title = "Der Referendar", cost = 8, tex = "res://assets/chars/scrubbs.png",
			tint = Color(0.72, 0.85, 1.0), height = 58.0, hp = 70.0, speed = 1.06, dmg = 0.85, slots = 4, xp = 2.0, area = 1.0, heal = 1.0, options = 4,
			start_weapon = "paperclip", bars = {hp = 2, speed = 3, dmg = 2}, diff = "Schwer", ability = "Fortbildung",
			desc = "Schwach und zerbrechlich, lernt aber doppelt so schnell: +100 % Erfahrung und vier Antworten bei jeder Klassenarbeit. Startet mit der Büroklammer-Schleuder.",
			goals = ["Erreiche Stufe 15 in einem Run", "Besiege einen Boss mit Herrn Probe", "Banne 2 Upgrades in einem Run"]},
	}

## Fach-Sets: Stufe 1 ab 2 Teilen, Stufe 2 ab 4 Teilen (Waffen + Items eines Fachs)
static func _sets(db: Node) -> void:
	db.sets = {
		"Chemie": ["Gegner hinterlassen beim Tod Säureimpulse.", "Säureimpulse sind größer und fast doppelt so stark."],
		"Sport": ["+10 % Tempo.", "+20 % Tempo, Ausweichen lädt 25 % schneller."],
		"Mathe": ["+10 % kritische Trefferchance.", "Kritische Treffer verursachen 2,5-fachen Schaden."],
		"Musik": ["Basswellen betäuben öfter.", "Jeder 10. Kill löst eine Schockwelle aus."],
		"Kunst": ["Treffer verlangsamen Gegner.", "Verlangsamte Gegner erleiden +20 % Schaden."],
		"Physik": ["Projektile prallen 1x öfter ab und fliegen 15 % schneller.", "Projektile durchschlagen einen Gegner zusätzlich."],
		"Hausmeister": ["+20 % Rückstoß.", "Jeder 6. Kill heilt 3 Lebenspunkte."],
	}

## Elite-Affixe: zufällige Modifikatoren für normale Gegner. Garantierte Beute.
static func _affixes(db: Node) -> void:
	db.affixes = {
		streber = {name = "Streber", color = Color(0.4, 1.0, 0.5), desc = "Heilt Mutanten in der Nähe."},
		clown = {name = "Klassenclown", color = Color(1.0, 0.6, 0.9), desc = "Teilt sich beim Tod."},
		petze = {name = "Petze", color = Color(1.0, 0.85, 0.3), desc = "Ruft Verstärkung."},
		sprinter = {name = "Koffein-Junkie", color = Color(0.4, 0.8, 1.0), desc = "Sehr schnell."},
		schild = {name = "Klassensprecher", color = Color(0.8, 0.8, 1.0), desc = "Schild blockt Treffer und lädt sich wieder auf."},
		knall = {name = "Chemie-Unfall", color = Color(1.0, 0.5, 0.2), desc = "Explodiert beim Tod."},
	}

## Endlos-Nachsitzen: prozedurale Welle n (Budget wächst, Gegnertypen kommen nach und nach dazu)
static func endless_wave(n: int) -> Dictionary:
	var pool := [["bird", 1.0, 1], ["frog", 1.5, 1], ["rat", 2.0, 2], ["nerd", 2.0, 2], ["sheep", 2.0, 3], ["football", 3.0, 3],
		["zombie", 3.5, 4], ["chemist", 3.0, 4], ["locker", 5.0, 3], ["brute", 9.0, 6]]
	var budget := 14.0 + 5.0 * float(n)
	var groups := {}
	var avail: Array = []
	for p in pool:
		if n >= int(p[2]):
			avail.append(p)
	var guard := 0
	while budget > 0.0 and guard < 300:
		guard += 1
		var p: Array = avail[randi() % avail.size()]
		var id: String = p[0]
		if id == "brute" and int(groups.get("brute", 0)) >= 1 + n / 6:
			continue
		if id == "locker" and int(groups.get("locker", 0)) >= 3:
			continue
		groups[id] = int(groups.get(id, 0)) + 1
		budget -= float(p[1])
	return {duration = minf(60.0, 30.0 + 2.0 * float(n)), groups = groups}
