class_name DirectorScreen
extends HubModal
## Direktorenschild: Kapitel und Schwierigkeit wählen, Loadout prüfen, Unterricht beginnen.

signal start_requested

const DIFF_NAMES := ["Regelschule", "Nachsitzen I", "Nachsitzen II", "Nachsitzen III"]
const DIFF_DESC := [
	"Normale Gegner, normale Belohnung.",
	"Gegner +25 % Leben, +10 % Schaden, Belohnung +30 %.",
	"Gegner +50 % Leben, +20 % Schaden, Belohnung +60 %.",
	"Gegner +75 % Leben, +30 % Schaden, Belohnung +90 %.",
]

var _chapters: HBoxContainer
var _diff: HBoxContainer
var _info: Label
var _mode: HBoxContainer

func _init() -> void:
	title = "Direktorenschild – Stundenplan"
	window_size = Vector2(1100, 704)

func build() -> void:
	content.add_child(UIKit.label("Kapitel", 20, UIKit.RED))
	_chapters = HBoxContainer.new()
	_chapters.add_theme_constant_override("separation", 14)
	content.add_child(_chapters)
	content.add_child(UIKit.label("Schwierigkeit", 20, UIKit.RED))
	_diff = HBoxContainer.new()
	_diff.add_theme_constant_override("separation", 10)
	content.add_child(_diff)
	_mode = HBoxContainer.new()
	_mode.add_theme_constant_override("separation", 10)
	content.add_child(_mode)
	_info = UIKit.label("", 15, UIKit.INK)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(960, 0)
	content.add_child(_info)
	var go := UIKit.button("Unterricht beginnen", Vector2(380, 68), 28, Color("c8f0b8"))
	go.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	go.pressed.connect(func():
		close()
		start_requested.emit())
	content.add_child(go)

func open() -> void:
	_fill()
	super.open()

func _fill() -> void:
	for c in _chapters.get_children():
		c.queue_free()
	for n in [1, 2, 3]:
		_chapters.add_child(_chapter_card(n))
	for c in _diff.get_children():
		c.queue_free()
	for d in 4:
		var unlocked: bool = d == 0 or int(Save.data.wins) >= d
		var b := UIKit.button(DIFF_NAMES[d], Vector2(230, 44), 16, Color("f7efc8") if Save.data.difficulty != d else Color("c8f0b8"))
		b.disabled = not unlocked
		b.pressed.connect(func():
			Save.data.difficulty = d
			Save.save_game()
			_fill())
		_diff.add_child(b)
	for c in _mode.get_children():
		c.queue_free()
	_mode.add_child(UIKit.label("Modus:", 20, UIKit.RED))
	var endless: bool = Save.data.endless
	var m1 := UIKit.button("Kapitel mit Boss", Vector2(250, 44), 16, Color("c8f0b8") if not endless else Color("f7efc8"))
	var m2 := UIKit.button("Endlos-Nachsitzen", Vector2(250, 44), 16, Color("c8f0b8") if endless else Color("f7efc8"))
	UIKit.tip(m1, "Kapitel mit Boss", "5 Wellen, dann der Kapitel-Boss. Ein Sieg schaltet das nächste Kapitel frei.")
	UIKit.tip(m2, "Endlos-Nachsitzen", "Die Wellen hören nie auf und werden immer härter. Alle 5 Wellen wartet ein Boss.\nZiel: so weit wie möglich kommen – mit lokaler Bestenliste.")
	m1.pressed.connect(func():
		Save.data.endless = false
		Save.save_game()
		_fill())
	m2.pressed.connect(func():
		Save.data.endless = true
		Save.save_game()
		Sfx.play("stamp", 1.2, -6.0)
		_fill())
	_mode.add_child(m1)
	_mode.add_child(m2)
	var best: Array = Save.data.endless_best
	if not best.is_empty():
		_mode.add_child(UIKit.label("  Rekord: Welle %d" % int(best[0].wave), 16, UIKit.NAVY))
	var sel: int = Save.data.difficulty
	var chd: Dictionary = Save.character()
	var sw: String = chd.start_weapon if String(chd.start_weapon) != "" else Save.data.start_weapon
	var loadout := "%s   ·   Startwaffe: %s   ·   AG: %s" % [chd.name, Db.weapons[sw].display_name, Db.ags[Save.data.ag_selected].name if Save.data.ag_selected != "" else "keine"]
	_info.text = "%s\n%s" % [DIFF_DESC[sel], loadout + "   ·   Höhere Stufen werden nach gewonnenen Runs freigeschaltet."]

func _chapter_card(n: int) -> Control:
	var ch: Dictionary = Db.chapters[n]
	var unlocked := Save.chapter_unlocked(n)
	var selected: bool = Save.data.chapter_selected == n
	var p := card_panel(Vector2(330, 190))
	if selected:
		p.add_theme_stylebox_override("panel", UIKit.sbox("card_cream", 10, Color(0.8, 1.0, 0.8)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	v.add_child(UIKit.label("%d. %s" % [n, ch.name], 22, UIKit.NAVY))
	v.add_child(UIKit.label(ch.sub, 15, UIKit.RED))
	var d := UIKit.label(ch.intro, 12, UIKit.INK)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(300, 0)
	v.add_child(d)
	var clears: int = int(Save.data.chapter_clears.get(str(n), 0))
	v.add_child(UIKit.label("Boss: %s   ·   Siege: %d" % [ch.boss_name, clears], 13, UIKit.NAVY))
	var b: Button
	if not unlocked:
		b = UIKit.button("Gesperrt – besiege Kapitel %d" % (n - 1), Vector2(300, 40), 14, Color("d0d0d0"))
		b.disabled = true
	elif selected:
		b = UIKit.button("Ausgewählt", Vector2(300, 40), 16, Color("c8f0b8"))
		b.disabled = true
	else:
		b = UIKit.button("Wählen", Vector2(300, 40), 16, Color("f7efc8"))
		b.pressed.connect(func():
			Save.data.chapter_selected = n
			Save.save_game()
			Sfx.play("stamp", 1.2, -6.0)
			_fill())
	v.add_child(b)
	return p
