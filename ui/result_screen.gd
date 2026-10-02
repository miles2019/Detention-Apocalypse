class_name ResultScreen
extends Control
## Run-Ende mit Zeugnis: Noten werden nacheinander abgestempelt, danach erscheinen die Buttons.

signal restart_pressed
signal menu_pressed

var _sheet: PanelContainer
var _box: VBoxContainer
var _buttons: HBoxContainer

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dim(0.78))

func _grade(value: float, thresholds: Array) -> int:
	# thresholds: Werte für Note 1..5 (aufsteigend), darüber -> 6 (umgekehrt für "weniger ist besser" bei Aufrufer)
	for i in thresholds.size():
		if value >= thresholds[i]:
			return i + 1
	return 6

func open(won: bool) -> void:
	if _sheet != null:
		_sheet.queue_free()
	var st: Dictionary = Game.stats
	_sheet = PanelContainer.new()
	_sheet.add_theme_stylebox_override("panel", UIKit.box(Color("fbf6e4"), Color("5a4630"), 5, 6, 20))
	_sheet.position = Vector2(250, 20)
	_sheet.custom_minimum_size = Vector2(780, 680)
	add_child(_sheet)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 8)
	_sheet.add_child(_box)
	_box.add_child(UIKit.label("Zeugnis", 48, UIKit.NAVY, HORIZONTAL_ALIGNMENT_CENTER))
	var sub := "Mr. Scrubbs hat das Kapitel bestanden." if won else "Mr. Scrubbs wurde von der Pausenaufsicht abgeholt."
	_box.add_child(UIKit.label(sub, 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
	# Noten berechnen (1 = sehr gut ... 6 = ungenügend)
	var dmg_g := _grade(st.damage_dealt, [4000, 2800, 1800, 1000, 400])
	var dodge_g := _grade(st.dodges, [8, 5, 3, 1, 0] if false else [8, 5, 3, 2, 1])
	var obj_g := _grade(st.objects_used, [10, 7, 5, 3, 1])
	var syn_g := _grade(st.synergies + st.max_chain * 0.3, [4.0, 3.0, 2.0, 1.0, 0.3])
	var conduct_g := 1
	if st.damage_taken > 80: conduct_g = 2
	if st.damage_taken > 160: conduct_g = 3
	if st.damage_taken > 260: conduct_g = 4
	if st.damage_taken > 400: conduct_g = 5
	if st.objects_used > 18 or st.damage_taken > 600: conduct_g = 6
	var rows := [
		["Schaden", dmg_g, ["Sehr überzeugend", "Überzeugend", "Befriedigend", "Ausreichend", "Mangelhaft", "Ungenügend"][dmg_g - 1]],
		["Sport (Ausweichen)", dodge_g, ["Olympiareif", "Sportlich akzeptabel", "Solide", "Bewegungsarm", "Sitzenbleiber", "Attest nötig"][dodge_g - 1]],
		["Objektzerstörung", obj_g, ["Gespräch mit der Hausmeisterei erforderlich", "Ziemlich zerstörerisch", "Nutzt Inventar", "Zaghaft", "Scheut Objekte", "Spinde ungenutzt"][obj_g - 1]],
		["Fach-Synergien", syn_g, ["Ausgezeichnete Gruppenarbeit", "Gute Gruppenarbeit", "Teamfähig", "Einzelgänger", "Schwänzt Gruppenarbeit", "Keine Teilnahme"][syn_g - 1]],
		["Betragen", conduct_g, ["Vorbildlich", "Gut", "Befriedigend", "Auffällig", "Sehr unruhig", "Elterntermin vereinbaren"][conduct_g - 1]],
	]
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 10)
	_box.add_child(grid)
	var stamps: Array = []
	var sum := 0
	for r in rows:
		sum += r[1]
		var a := UIKit.label(r[0], 22, UIKit.INK)
		a.custom_minimum_size = Vector2(230, 0)
		grid.add_child(a)
		var g := UIKit.label(str(r[1]), 34, UIKit.GREEN if r[1] <= 2 else (UIKit.RED if r[1] >= 5 else UIKit.NAVY), HORIZONTAL_ALIGNMENT_CENTER)
		g.custom_minimum_size = Vector2(60, 0)
		g.modulate.a = 0.0
		grid.add_child(g)
		var c := UIKit.label(r[2], 17, UIKit.NAVY)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.custom_minimum_size = Vector2(420, 0)
		c.modulate.a = 0.0
		grid.add_child(c)
		stamps.append([g, c])
	var avg := float(sum) / rows.size()
	var info := "Notenschnitt: %.1f   ·   Gegner besiegt: %d   ·   Wellen: %d/%d   ·   Zeit: %d:%02d   ·   Pausengeld verdient: %d   ·   Kritische Treffer: %d   ·   Beste Kette: %d" % [
		avg, st.kills, st.waves, Game.TOTAL_WAVES, int(st.time) / 60, int(st.time) % 60, st.money_earned, st.crits, st.max_chain]
	var il := UIKit.label(info, 14, UIKit.INK)
	il.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	il.custom_minimum_size = Vector2(730, 0)
	_box.add_child(il)
	var verdict := UIKit.stamp("VERSETZT!" if won else "Nicht entschuldigt", UIKit.GREEN if won else UIKit.RED, 48, -6.0)
	var vh := CenterContainer.new()
	vh.add_child(verdict)
	vh.custom_minimum_size = Vector2(0, 90)
	_box.add_child(vh)
	verdict.modulate.a = 0.0
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 20)
	_buttons.modulate.a = 0.0
	_box.add_child(_buttons)
	var b1 := UIKit.button("Nächste Stunde (Neustart)", Vector2(320, 58), 22, Color("c8f0b8"))
	var b2 := UIKit.button("Zum Sekretariat", Vector2(260, 58), 22)
	b1.pressed.connect(func(): restart_pressed.emit())
	b2.pressed.connect(func(): menu_pressed.emit())
	_buttons.add_child(b1)
	_buttons.add_child(b2)
	await get_tree().process_frame
	UIKit.pop_in(_sheet)
	# Animierte Stempel nacheinander
	var t := 0.4
	for pair in stamps:
		UIKit.slam_stamp(pair[0], t)
		var cc: Label = pair[1]
		cc.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(cc, "modulate:a", 1.0, 0.25).set_delay(t + 0.15)
		t += 0.55
	UIKit.slam_stamp(verdict, t + 0.2)
	if won:
		get_tree().create_timer(t + 0.3, true).timeout.connect(func(): Sfx.play("rare"))
	_buttons.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(_buttons, "modulate:a", 1.0, 0.3).set_delay(t + 0.9)
