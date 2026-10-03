class_name ResultScreen
extends Control
## Run-Ende als Zeugnis (Notizbuch-Look): links die Fachnoten (werden nacheinander abgestempelt), rechts Gesamtnote,
## Statistik und Belohnungen. Die Buttons sitzen fest am unteren Rand (auch per Enter / R bedienbar).

signal restart_pressed
signal menu_pressed

const SIZE := Vector2(1040, 696)

var _root: Control
var _ready_t := 0.0
var _buttons_on := false

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dim(0.78))

func _grade(value: float, thresholds: Array) -> int:
	for i in thresholds.size():
		if value >= thresholds[i]:
			return i + 1
	return 6

func _grade_slot(g: int) -> String:
	if g <= 2:
		return "slot_green"
	if g >= 5:
		return "slot_red"
	return "slot_blue"

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not _buttons_on:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_ENTER, KEY_KP_ENTER]:
			get_viewport().set_input_as_handled()
			_go_menu()
		elif event.keycode == KEY_R:
			get_viewport().set_input_as_handled()
			_go_restart()

func _go_menu() -> void:
	if _buttons_on:
		_buttons_on = false
		menu_pressed.emit()

func _go_restart() -> void:
	if _buttons_on:
		_buttons_on = false
		restart_pressed.emit()

func open(won: bool) -> void:
	if _root != null:
		_root.queue_free()
	_buttons_on = false
	var st: Dictionary = Game.stats
	var chap: Dictionary = Db.chapters.get(Game.chapter, Db.chapters[1])
	var ch: Dictionary = Save.character()
	var title := "Zeugnis – %s" % chap.name
	if Game.endless:
		title = "Zeugnis – Endlos-Nachsitzen"
	var nb := UIKit.notebook(title, SIZE)
	_root = nb.root
	_root.position = (Vector2(1280, 720) - SIZE) * 0.5
	add_child(_root)
	nb.content.visible = false
	var sub := "%s hat das Kapitel bestanden." % ch.name if won else "%s wurde von der Pausenaufsicht abgeholt." % ch.name
	if Game.endless:
		sub = "%s hat bis Welle %d nachgesessen." % [ch.name, Game.wave]
	var sl := UIKit.label(sub, 17, Color("5a2d0c"), HORIZONTAL_ALIGNMENT_CENTER)
	sl.position = Vector2(60, 104)
	sl.size = Vector2(SIZE.x - 120.0, 24)
	_root.add_child(sl)
	# ---------------- Noten
	var time_scale := 1.0 + float(st.waves) / 6.0 if Game.endless else 1.0
	var dmg_g := _grade(st.damage_dealt / time_scale, [4000, 2800, 1800, 1000, 400])
	var dodge_g := _grade(st.dodges, [8, 5, 3, 2, 1])
	var obj_g := _grade(st.objects_used + st.events, [10, 7, 5, 3, 1])
	var syn_g := _grade(st.synergies + st.max_chain * 0.3, [4.0, 3.0, 2.0, 1.0, 0.3])
	var coin_g := _grade(st.money_earned / time_scale, [130, 95, 65, 40, 15])
	var conduct_g := 1
	for lim in [80, 160, 260, 400, 600]:
		if st.damage_taken / time_scale > lim:
			conduct_g += 1
	var rows := [
		["Schaden", dmg_g, ["Sehr überzeugend", "Überzeugend", "Befriedigend", "Ausreichend", "Mangelhaft", "Ungenügend"][dmg_g - 1]],
		["Sport (Ausweichen)", dodge_g, ["Olympiareif", "Sportlich akzeptabel", "Solide", "Bewegungsarm", "Sitzenbleiber", "Attest nötig"][dodge_g - 1]],
		["Sachkunde (Objekte)", obj_g, ["Gespräch mit der Hausmeisterei nötig", "Ziemlich zerstörerisch", "Nutzt das Inventar", "Zaghaft", "Scheut Objekte", "Objekte ungenutzt"][obj_g - 1]],
		["Gruppenarbeit (Sets)", syn_g, ["Ausgezeichnete Gruppenarbeit", "Gute Gruppenarbeit", "Teamfähig", "Einzelgänger", "Schwänzt Gruppenarbeit", "Keine Teilnahme"][syn_g - 1]],
		["Wirtschaft (Sammeln)", coin_g, ["Taschengeld-Millionär", "Sparfuchs", "Kommt über die Runden", "Knapp bei Kasse", "Pleite", "Schuldet dem Kiosk Geld"][coin_g - 1]],
		["Betragen", conduct_g, ["Vorbildlich", "Gut", "Befriedigend", "Auffällig", "Sehr unruhig", "Elterntermin vereinbaren"][conduct_g - 1]],
	]
	var stamps: Array = []
	var sum := 0
	var y := 136.0
	for r in rows:
		sum += r[1]
		var p := Panel.new()
		p.add_theme_stylebox_override("panel", UIKit.sbox("container_cream", 6))
		p.position = Vector2(56, y)
		p.size = Vector2(590, 54)
		_root.add_child(p)
		var a := UIKit.label(r[0], 18, UIKit.NAVY)
		a.position = Vector2(16, 14)
		a.size = Vector2(240, 26)
		p.add_child(a)
		var gp := Panel.new()
		gp.add_theme_stylebox_override("panel", UIKit.sbox(_grade_slot(r[1]), 4))
		gp.position = Vector2(262, 4)
		gp.size = Vector2(54, 46)
		p.add_child(gp)
		var g := UIKit.label(str(r[1]), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
		g.position = Vector2(0, 4)
		g.size = Vector2(54, 36)
		gp.add_child(g)
		gp.modulate.a = 0.0
		var c := UIKit.label(r[2], 13, UIKit.INK)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.position = Vector2(328, 8)
		c.size = Vector2(250, 40)
		c.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c.modulate.a = 0.0
		p.add_child(c)
		stamps.append([gp, c])
		y += 59.0
	# ---------------- rechte Spalte: Gesamtnote, Statistik, Belohnungen
	var avg := float(sum) / rows.size()
	var rx := 668.0
	var gl := UIKit.label("Gesamtnote", 18, UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
	gl.position = Vector2(rx, 136)
	gl.size = Vector2(320, 24)
	_root.add_child(gl)
	var big := Panel.new()
	big.add_theme_stylebox_override("panel", UIKit.sbox(_grade_slot(int(round(avg))), 6))
	big.position = Vector2(rx + 100.0, 162)
	big.size = Vector2(120, 84)
	_root.add_child(big)
	var bl := UIKit.label(("%.1f" % avg).replace(".", ","), 46, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	bl.position = Vector2(0, 10)
	bl.size = Vector2(120, 60)
	big.add_child(bl)
	big.modulate.a = 0.0
	var lines: Array = [
		"Besiegt: %d   ·   Elite: %d" % [st.kills, st.elites + st.champions],
		("Welle erreicht: %d" % Game.wave) if Game.endless else ("Wellen: %d / %d" % [st.waves, Game.TOTAL_WAVES]),
		"Zeit: %d:%02d   ·   Stufe %d" % [int(st.time) / 60, int(st.time) % 60, Game.level],
		"Pausengeld: %d   ·   Kritische: %d" % [st.money_earned, st.crits],
		"Beste Kette: %d   ·   Zertrümmert: %d" % [st.max_chain, st.smashed],
		("Mutatoren: %d aktiv, Belohnung +%d %%" % [Game.mutators.size(), int(round(Game.mutator_bonus() * 100.0))]) if not Game.mutators.is_empty() else "Keine Mutatoren",
	]
	var ly := 254.0
	for t in lines:
		var l := UIKit.label(t, 14, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		l.position = Vector2(rx, ly)
		l.size = Vector2(320, 20)
		_root.add_child(l)
		ly += 21.0
	ly += 6.0
	if Game.endless:
		var hl := UIKit.label("Bestenliste", 16, UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
		hl.position = Vector2(rx, ly)
		hl.size = Vector2(320, 22)
		_root.add_child(hl)
		ly += 22.0
		var list: Array = Save.data.endless_best
		for i in mini(list.size(), 5):
			var e: Dictionary = list[i]
			var mine: bool = Game.endless_rank == i + 1
			var el := UIKit.label("%d.  Welle %d  ·  %d Kills  ·  %s" % [i + 1, int(e.wave), int(e.kills), str(e.char)], 11, UIKit.GREEN if mine else UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
			el.position = Vector2(rx, ly)
			el.size = Vector2(320, 18)
			_root.add_child(el)
			ly += 18.0
		ly += 4.0
	var rw: Dictionary = Game.last_rewards
	if not rw.is_empty():
		var rr := HBoxContainer.new()
		rr.alignment = BoxContainer.ALIGNMENT_CENTER
		rr.add_theme_constant_override("separation", 6)
		rr.position = Vector2(rx, ly)
		rr.size = Vector2(320, 30)
		rr.add_child(UIKit.icon(UIKit.ICON % "coins", Vector2(26, 26)))
		rr.add_child(UIKit.label("+%d Pässe" % rw.passes, 16, UIKit.GREEN))
		rr.add_child(UIKit.icon(UIKit.ICON % "gem", Vector2(26, 26)))
		rr.add_child(UIKit.label("+%d Marken" % rw.marken, 16, Color("2a7ab8")))
		_root.add_child(rr)
		ly += 32.0
		for u in rw.unlocks:
			var ul := UIKit.label("Neu: " + u, 13, UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER)
			ul.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ul.position = Vector2(rx, ly)
			ul.size = Vector2(320, 36)
			_root.add_child(ul)
			ly += 38.0
	# ---------------- Stempel + Unterschrift
	var vtext := "VERSETZT!" if won else "Nicht entschuldigt"
	if Game.endless:
		vtext = "NEUER REKORD!" if Game.endless_rank == 1 else "Nachsitzen beendet"
	var verdict := UIKit.stamp(vtext, UIKit.GREEN if (won or Game.endless_rank == 1) else UIKit.RED, 38, -6.0)
	_root.add_child(verdict)
	verdict.reset_size()
	verdict.position = Vector2(rx + 160.0 - verdict.size.x * 0.5, 506.0)
	verdict.modulate.a = 0.0
	var sig := UIKit.label("gez. Rektor Dr. Zorn", 13, Color(0.35, 0.3, 0.45))
	sig.position = Vector2(64, 494)
	sig.size = Vector2(300, 20)
	_root.add_child(sig)
	# ---------------- Buttons: fest am unteren Rand
	var b1 := UIKit.button("Nochmal [R]", Vector2(300, 60), 22, Color("c8f0b8"))
	var b2 := UIKit.button("Zum Schulhof [Enter]", Vector2(340, 60), 22, Color("a8c8f8"))
	b1.position = Vector2(56, SIZE.y - 104.0)
	b2.position = Vector2(56 + 300 + 18, SIZE.y - 104.0)
	b1.pressed.connect(_go_restart)
	b2.pressed.connect(_go_menu)
	UIKit.tip(b1, "Nochmal", "Startet sofort einen neuen Run mit denselben Einstellungen.")
	UIKit.tip(b2, "Zum Schulhof", "Zurück zum Hub: Skills kaufen, Charakter wechseln, Kapitel wählen.")
	_root.add_child(b1)
	_root.add_child(b2)
	get_tree().create_timer(0.7, true).timeout.connect(func(): _buttons_on = true)
	await get_tree().process_frame
	if not is_instance_valid(verdict):
		return
	UIKit.pop_in(_root)
	var t := 0.35
	for pair in stamps:
		UIKit.slam_stamp(pair[0], t)
		var cc: Label = pair[1]
		cc.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(cc, "modulate:a", 1.0, 0.25).set_delay(t + 0.15)
		t += 0.32
	UIKit.slam_stamp(big, t + 0.1)
	UIKit.slam_stamp(verdict, t + 0.45)
	if won or Game.endless_rank == 1:
		get_tree().create_timer(t + 0.5, true).timeout.connect(func(): Sfx.play("rare"))
