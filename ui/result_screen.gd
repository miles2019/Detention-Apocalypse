class_name ResultScreen
extends Control
## Run-Ende mit Zeugnis (Notizbuch-Look): Noten werden nacheinander abgestempelt, danach Belohnungen und Buttons.

signal restart_pressed
signal menu_pressed

var _root: Control

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

func open(won: bool) -> void:
	if _root != null:
		_root.queue_free()
	var st: Dictionary = Game.stats
	var chap: Dictionary = Db.chapters.get(Game.chapter, Db.chapters[1])
	var nb := UIKit.notebook("Zeugnis – %s" % chap.name, Vector2(960, 690))
	_root = nb.root
	_root.position = Vector2(160, 15)
	add_child(_root)
	var box: VBoxContainer = nb.content
	box.add_theme_constant_override("separation", 6)
	var sub := "Mr. Scrubbs hat das Kapitel bestanden." if won else "Mr. Scrubbs wurde von der Pausenaufsicht abgeholt."
	box.add_child(UIKit.label(sub, 17, Color("5a2d0c"), HORIZONTAL_ALIGNMENT_CENTER))
	var dmg_g := _grade(st.damage_dealt, [4000, 2800, 1800, 1000, 400])
	var dodge_g := _grade(st.dodges, [8, 5, 3, 2, 1])
	var obj_g := _grade(st.objects_used, [10, 7, 5, 3, 1])
	var syn_g := _grade(st.synergies + st.max_chain * 0.3, [4.0, 3.0, 2.0, 1.0, 0.3])
	var conduct_g := 1
	if st.damage_taken > 80: conduct_g = 2
	if st.damage_taken > 160: conduct_g = 3
	if st.damage_taken > 260: conduct_g = 4
	if st.damage_taken > 400: conduct_g = 5
	if st.damage_taken > 600: conduct_g = 6
	var rows := [
		["Schaden", dmg_g, ["Sehr überzeugend", "Überzeugend", "Befriedigend", "Ausreichend", "Mangelhaft", "Ungenügend"][dmg_g - 1]],
		["Sport (Ausweichen)", dodge_g, ["Olympiareif", "Sportlich akzeptabel", "Solide", "Bewegungsarm", "Sitzenbleiber", "Attest nötig"][dodge_g - 1]],
		["Objekte & Events", obj_g, ["Gespräch mit der Hausmeisterei erforderlich", "Ziemlich zerstörerisch", "Nutzt Inventar", "Zaghaft", "Scheut Objekte", "Objekte ungenutzt"][obj_g - 1]],
		["Fach-Synergien", syn_g, ["Ausgezeichnete Gruppenarbeit", "Gute Gruppenarbeit", "Teamfähig", "Einzelgänger", "Schwänzt Gruppenarbeit", "Keine Teilnahme"][syn_g - 1]],
		["Betragen", conduct_g, ["Vorbildlich", "Gut", "Befriedigend", "Auffällig", "Sehr unruhig", "Elterntermin vereinbaren"][conduct_g - 1]],
	]
	var stamps: Array = []
	var sum := 0
	for r in rows:
		sum += r[1]
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UIKit.sbox("container_cream", 8))
		p.custom_minimum_size = Vector2(0, 62)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 14)
		p.add_child(h)
		var a := UIKit.label(r[0], 21, UIKit.NAVY)
		a.custom_minimum_size = Vector2(260, 0)
		h.add_child(a)
		var gp := PanelContainer.new()
		gp.add_theme_stylebox_override("panel", UIKit.sbox(_grade_slot(r[1]), 6))
		gp.custom_minimum_size = Vector2(64, 52)
		var g := UIKit.label(str(r[1]), 32, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
		gp.add_child(g)
		gp.modulate.a = 0.0
		h.add_child(gp)
		var c := UIKit.label(r[2], 17, UIKit.INK)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.custom_minimum_size = Vector2(400, 0)
		c.modulate.a = 0.0
		h.add_child(c)
		box.add_child(p)
		stamps.append([gp, c])
	var avg := float(sum) / rows.size()
	var info := "Notenschnitt: %.1f   ·   Besiegt: %d   ·   Wellen: %d/%d   ·   Zeit: %d:%02d   ·   Pausengeld: %d   ·   Kritische: %d   ·   Beste Kette: %d" % [
		avg, st.kills, st.waves, Game.TOTAL_WAVES, int(st.time) / 60, int(st.time) % 60, st.money_earned, st.crits, st.max_chain]
	var il := UIKit.label(info, 14, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	il.custom_minimum_size = Vector2(860, 0)
	box.add_child(il)
	# Belohnungen
	var rw: Dictionary = Game.last_rewards
	if not rw.is_empty():
		var rr := HBoxContainer.new()
		rr.alignment = BoxContainer.ALIGNMENT_CENTER
		rr.add_theme_constant_override("separation", 10)
		rr.add_child(UIKit.icon(UIKit.ICON % "coins", Vector2(34, 34)))
		rr.add_child(UIKit.label("+%d Fehlstunden-Pässe" % rw.passes, 20, UIKit.GREEN))
		rr.add_child(UIKit.icon(UIKit.ICON % "gem", Vector2(34, 34)))
		rr.add_child(UIKit.label("+%d Nachsitzen-Marken" % rw.marken, 20, Color("2a7ab8")))
		box.add_child(rr)
		for u in rw.unlocks:
			box.add_child(UIKit.label("Freigeschaltet: " + u, 17, UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER))
	var verdict := UIKit.stamp("VERSETZT!" if won else "Nicht entschuldigt", UIKit.GREEN if won else UIKit.RED, 46, -6.0)
	var vh := CenterContainer.new()
	vh.add_child(verdict)
	vh.custom_minimum_size = Vector2(0, 76)
	box.add_child(vh)
	verdict.modulate.a = 0.0
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	buttons.modulate.a = 0.0
	box.add_child(buttons)
	var b1 := UIKit.button("Nochmal (gleiche Einstellungen)", Vector2(360, 58), 20, Color("c8f0b8"))
	var b2 := UIKit.button("Zum Schulhof", Vector2(260, 58), 22, Color("a8c8f8"))
	b1.pressed.connect(func(): restart_pressed.emit())
	b2.pressed.connect(func(): menu_pressed.emit())
	buttons.add_child(b1)
	buttons.add_child(b2)
	await get_tree().process_frame
	UIKit.pop_in(_root)
	var t := 0.4
	for pair in stamps:
		UIKit.slam_stamp(pair[0], t)
		var cc: Label = pair[1]
		cc.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(cc, "modulate:a", 1.0, 0.25).set_delay(t + 0.15)
		t += 0.5
	UIKit.slam_stamp(verdict, t + 0.2)
	if won:
		get_tree().create_timer(t + 0.3, true).timeout.connect(func(): Sfx.play("rare"))
	buttons.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(buttons, "modulate:a", 1.0, 0.3).set_delay(t + 0.8)
