class_name DirectorScreen
extends HubModal
## Direktorenschild: links Kapitelwahl (3x3), rechts Schwierigkeit, Modus, Mutatoren und Start.

signal start_requested

const DIFF_NAMES := ["Regelschule", "Nachsitzen I", "Nachsitzen II", "Nachsitzen III"]
const DIFF_DESC := [
	"Normale Gegner, normale Belohnung.",
	"Gegner +25 % Leben, +10 % Schaden, Belohnung +30 %.",
	"Gegner +50 % Leben, +20 % Schaden, Belohnung +60 %.",
	"Gegner +75 % Leben, +30 % Schaden, Belohnung +90 %.",
]

var _chapters: GridContainer
var _right: VBoxContainer
var _detail: Label

func _init() -> void:
	title = "Direktorenschild – Stundenplan"
	window_size = Vector2(1200, 704)

func build() -> void:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	content.add_child(cols)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	left.custom_minimum_size = Vector2(650, 0)
	cols.add_child(left)
	left.add_child(UIKit.label("Kapitel", 20, UIKit.RED))
	_chapters = GridContainer.new()
	_chapters.columns = 3
	_chapters.add_theme_constant_override("h_separation", 8)
	_chapters.add_theme_constant_override("v_separation", 8)
	left.add_child(_chapters)
	_detail = UIKit.label("", 14, UIKit.INK)
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(640, 0)
	left.add_child(_detail)
	_right = VBoxContainer.new()
	_right.add_theme_constant_override("separation", 6)
	_right.custom_minimum_size = Vector2(440, 0)
	cols.add_child(_right)

func open() -> void:
	_fill()
	super.open()

func _fill() -> void:
	for c in _chapters.get_children():
		c.queue_free()
	var ids: Array = Db.chapters.keys()
	ids.sort()
	for n in ids:
		if n > 0:
			_chapters.add_child(_chapter_card(n))
	var sel_ch: int = int(Save.data.chapter_selected)
	if not Db.chapters.has(sel_ch):
		sel_ch = 1
	var ch: Dictionary = Db.chapters[sel_ch]
	_detail.text = "%s\nRaumregel: %s" % [ch.intro, ch.get("rule", "")]
	for c in _right.get_children():
		c.queue_free()
	# ---------------- Schwierigkeit
	_right.add_child(UIKit.label("Schwierigkeit", 18, UIKit.RED))
	var dg := GridContainer.new()
	dg.columns = 2
	dg.add_theme_constant_override("h_separation", 6)
	dg.add_theme_constant_override("v_separation", 6)
	_right.add_child(dg)
	for d in 4:
		var unlocked: bool = d == 0 or int(Save.data.wins) >= d
		var b := UIKit.button(DIFF_NAMES[d], Vector2(214, 38), 15, Color("c8f0b8") if Save.data.difficulty == d else Color("f7efc8"))
		b.disabled = not unlocked
		UIKit.tip(b, DIFF_NAMES[d], DIFF_DESC[d] + ("" if unlocked else "\nWird nach %d gewonnenen Runs freigeschaltet." % d))
		b.pressed.connect(func():
			Save.data.difficulty = d
			Save.save_game()
			_fill())
		dg.add_child(b)
	# ---------------- Modus
	_right.add_child(UIKit.label("Modus", 18, UIKit.RED))
	var mg := HBoxContainer.new()
	mg.add_theme_constant_override("separation", 6)
	_right.add_child(mg)
	var endless: bool = Save.data.endless
	var m1 := UIKit.button("Kapitel mit Boss", Vector2(214, 38), 15, Color("c8f0b8") if not endless else Color("f7efc8"))
	var m2 := UIKit.button("Endlos-Nachsitzen", Vector2(214, 38), 15, Color("c8f0b8") if endless else Color("f7efc8"))
	UIKit.tip(m1, "Kapitel mit Boss", "5 Wellen, dann der Kapitel-Boss. Ein Sieg schaltet das nächste Kapitel frei.")
	var best: Array = Save.data.endless_best
	UIKit.tip(m2, "Endlos-Nachsitzen", "Die Wellen hören nie auf und werden immer härter. Alle 5 Wellen wartet ein Boss.\nLokale Bestenliste." + ("\nRekord: Welle %d" % int(best[0].wave) if not best.is_empty() else ""))
	m1.pressed.connect(func():
		Save.data.endless = false
		Save.save_game()
		_fill())
	m2.pressed.connect(func():
		Save.data.endless = true
		Save.save_game()
		_fill())
	mg.add_child(m1)
	mg.add_child(m2)
	# ---------------- Mutatoren
	var active: Array = Save.data.mutators
	var bonus := 0.0
	for id in active:
		if Db.mutators.has(id):
			bonus += float(Db.mutators[id].reward)
	_right.add_child(UIKit.label("Mutatoren   (Belohnung +%d %%)" % int(round(bonus * 100.0)), 18, UIKit.RED))
	var ug := GridContainer.new()
	ug.columns = 2
	ug.add_theme_constant_override("h_separation", 6)
	ug.add_theme_constant_override("v_separation", 5)
	_right.add_child(ug)
	for id in Db.mutators:
		var mu: Dictionary = Db.mutators[id]
		var on: bool = active.has(id)
		var mb := UIKit.button(("AN: " if on else "") + mu.name, Vector2(214, 34), 13, Color("f4b0a8") if on else Color("f7efc8"))
		UIKit.tip(mb, mu.name, "%s\nBelohnung (Pässe und Marken): +%d %%" % [mu.desc, int(round(float(mu.reward) * 100.0))])
		mb.pressed.connect(func():
			if Save.data.mutators.has(id):
				Save.data.mutators.erase(id)
				Sfx.play("click", 0.8)
			else:
				Save.data.mutators.append(id)
				Sfx.play("stamp", 1.3, -6.0)
			Save.save_game()
			_fill())
		ug.add_child(mb)
	# ---------------- Zusammenfassung + Start
	var chd: Dictionary = Save.character()
	var sw: String = chd.start_weapon if String(chd.start_weapon) != "" else Save.data.start_weapon
	var info := UIKit.label("%s  ·  %s  ·  AG: %s" % [chd.name, Db.weapons[sw].display_name, Db.ags[Save.data.ag_selected].name if Save.data.ag_selected != "" else "keine"], 13, Color("5a2d0c"))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(430, 0)
	_right.add_child(info)
	var go := UIKit.button("Unterricht beginnen", Vector2(434, 62), 26, Color("c8f0b8"))
	go.pressed.connect(func():
		close()
		start_requested.emit())
	_right.add_child(go)

func _chapter_card(n: int) -> Control:
	var ch: Dictionary = Db.chapters[n]
	var unlocked := Save.chapter_unlocked(n)
	var selected: bool = int(Save.data.chapter_selected) == n
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(210, 104)
	p.add_theme_stylebox_override("panel", UIKit.sbox("container_cream", 8, Color(0.75, 1.0, 0.75) if selected else (Color.WHITE if unlocked else Color(0.75, 0.75, 0.78))))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(v)
	v.add_child(UIKit.label("%d. %s" % [n, ch.name], 17, UIKit.NAVY if unlocked else Color(0.4, 0.4, 0.45)))
	v.add_child(UIKit.label(ch.sub, 12, UIKit.RED if unlocked else Color(0.45, 0.45, 0.5)))
	var clears: int = int(Save.data.chapter_clears.get(str(n), 0))
	var state := "Boss: %s" % ch.boss_name
	if not unlocked:
		state = "Gesperrt – besiege Kapitel %d" % (n - 1)
	var sl := UIKit.label(state, 11, UIKit.INK if unlocked else Color(0.45, 0.2, 0.2))
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sl.custom_minimum_size = Vector2(190, 0)
	v.add_child(sl)
	if unlocked:
		v.add_child(UIKit.label(("Ausgewählt  ·  " if selected else "") + "Siege: %d" % clears, 11, UIKit.GREEN if selected else Color(0.4, 0.4, 0.45)))
	UIKit.tip(p, "%d. %s" % [n, ch.name], "%s\n\nRaumregel: %s\nBoss: %s (%s)\nGegner-Leben x%.1f  ·  Belohnung x%.1f" % [ch.intro, ch.get("rule", ""), ch.boss_name, ch.boss_title, float(ch.hp_scale), float(ch.reward)])
	p.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			if unlocked:
				Save.data.chapter_selected = n
				Save.save_game()
				Sfx.play("stamp", 1.2, -6.0)
				_fill()
			else:
				shake(p))
	return p
