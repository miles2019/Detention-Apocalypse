class_name StatsScreen
extends Control
## Schülerakte: alle Werte, Waffen, Items und Fach-Sets des laufenden Runs (Tab / Pausemenü / Kiosk).

signal closed

var _root: Control

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dim(0.7))

func open() -> void:
	var pl = Game.player
	if pl == null:
		return
	if _root != null:
		_root.queue_free()
	var size_ := Vector2(1160, 680)
	var nb := UIKit.notebook("Schülerakte – %s" % pl.char_data.name, size_)
	_root = nb.root
	_root.position = (Vector2(1280, 720) - size_) * 0.5
	add_child(_root)
	var x := UIKit.button("X", Vector2(52, 46), 22, Color("e0453a"))
	x.position = Vector2(size_.x - 74.0, 34.0)
	x.pressed.connect(close)
	_root.add_child(x)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	nb.content.add_child(cols)
	cols.add_child(_col_stats(pl))
	cols.add_child(_col_weapons(pl))
	cols.add_child(_col_items(pl))
	var hint := UIKit.label("Mit der Maus über Waffen, Items und Werte fahren für Details.   [Tab] / [Esc] schließt", 13, Color("5a2d0c"), HORIZONTAL_ALIGNMENT_CENTER)
	hint.position = Vector2(0, size_.y - 62.0)
	hint.size = Vector2(size_.x, 20)
	_root.add_child(hint)
	visible = true
	UIKit.pop_in(_root)
	Sfx.play("stamp", 1.3, -8.0)

func close() -> void:
	if not visible:
		return
	visible = false
	Sfx.play("click", 0.8)
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_ESCAPE, KEY_TAB]:
		close()
		get_viewport().set_input_as_handled()

func _head(text: String) -> Label:
	return UIKit.label(text, 20, UIKit.RED)

func _row(name: String, value: String, tip: String) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.sbox("container_cream", 4))
	p.custom_minimum_size = Vector2(300, 28)
	var h := HBoxContainer.new()
	p.add_child(h)
	var a := UIKit.label(name, 14, UIKit.NAVY)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	h.add_child(UIKit.label(value, 15, UIKit.INK, HORIZONTAL_ALIGNMENT_RIGHT))
	UIKit.tip(p, name, tip)
	return p

func _col_stats(pl) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.custom_minimum_size = Vector2(310, 0)
	v.add_child(_head("Werte"))
	var crit_mult: float = pl.crit_mult + (0.5 if pl.syn_tier("Mathe") >= 2 else 0.0)
	var crit: float = pl.crit + (0.10 if pl.syn("Mathe") else 0.0)
	var rows := [
		["Leben", "%d / %d" % [ceili(pl.hp), int(pl.max_hp)], "Aktuelle und maximale Lebenspunkte."],
		["Schaden", "%d %%" % int(round(pl.dmg_mult * 100.0)), "Multiplikator auf den Schaden aller Waffen."],
		["Angriffstempo", "%d %%" % int(round(pl.atk_speed * 100.0)), "Verkürzt die Abklingzeit aller Waffen."],
		["Krit-Chance", "%d %%" % int(round(crit * 100.0)), "Chance auf einen kritischen Treffer."],
		["Krit-Schaden", "x%.1f" % crit_mult, "Schadensfaktor kritischer Treffer."],
		["Tempo", "%d" % int(pl.move_speed()), "Bewegungstempo in Pixeln pro Sekunde (inkl. Fachphase)."],
		["Extra-Projektile", "+%d" % pl.extra_proj, "Zusätzliche Projektile für Schuss- und Flammenwaffen."],
		["Flächenradius", "%d %%" % int(round(pl.area_mult * 100.0)), "Größe von Wellen, Würfen, Kegeln und Rundumschlägen."],
		["Rückstoß", "%d %%" % int(round(pl.kb_mult * 100.0)), "Wie weit Treffer Gegner zurückwerfen."],
		["Sammelradius", "%d" % int(pl.magnet), "Reichweite, aus der Münzen und Erfahrung angezogen werden."],
		["Erfahrung", "%d %%" % int(round((1.0 + Save.bonus("xp")) * float(pl.char_data.xp) * 100.0)), "Multiplikator auf gesammelte Erfahrung."],
		["Waffenplätze", "%d / %d" % [pl.weapons.size(), pl.slots], "Belegte und verfügbare Spindfächer."],
	]
	for r in rows:
		v.add_child(_row(r[0], r[1], r[2]))
	return v

func _col_weapons(pl) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(380, 0)
	v.add_child(_head("Waffen (%d / %d)" % [pl.weapons.size(), pl.slots]))
	for w in pl.weapons:
		var wr: WeaponRunner = w
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UIKit.sbox("container_cream", 6))
		p.custom_minimum_size = Vector2(380, 74)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		p.add_child(h)
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", UIKit.sbox("slot_yellow" if wr.data.evolution else "slot_blue", 4))
		slot.custom_minimum_size = Vector2(62, 62)
		slot.add_child(UIKit.icon(wr.data.icon, Vector2(44, 44)))
		h.add_child(slot)
		var tv := VBoxContainer.new()
		tv.add_theme_constant_override("separation", 0)
		h.add_child(tv)
		tv.add_child(UIKit.label(wr.data.display_name, 17, UIKit.NAVY))
		var lvl := "EVOLUTION" if wr.data.evolution else "Stufe %d / %d" % [wr.level, wr.data.max_level]
		tv.add_child(UIKit.label("%s   ·   %s" % [lvl, wr.data.subject], 13, UIKit.RED))
		var line := "dauerhaft aktiv" if wr.data.kind == "orbit" else "Schaden %d   ·   alle %.2f s" % [int(round(wr.dmg())), wr.cooldown()]
		tv.add_child(UIKit.label(line, 13, UIKit.INK))
		UIKit.tip(p, wr.data.display_name, Tips.weapon(wr.data, wr.level, pl))
		v.add_child(p)
	for i in range(pl.weapons.size(), pl.slots):
		var e := PanelContainer.new()
		e.add_theme_stylebox_override("panel", UIKit.sbox("container_cream", 6, Color(1, 1, 1, 0.45)))
		e.custom_minimum_size = Vector2(380, 40)
		e.add_child(UIKit.label("freies Spindfach", 13, Color(0.45, 0.4, 0.35), HORIZONTAL_ALIGNMENT_CENTER))
		v.add_child(e)
	return v

func _col_items(pl) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(340, 0)
	v.add_child(_head("Items"))
	if pl.items.is_empty():
		v.add_child(UIKit.label("Noch keine Items – der Pausenkiosk hilft.", 13, Color(0.45, 0.4, 0.35)))
	var g := GridContainer.new()
	g.columns = 5
	g.add_theme_constant_override("h_separation", 6)
	g.add_theme_constant_override("v_separation", 6)
	v.add_child(g)
	for id in pl.items:
		var u: UpgradeData = Db.upgrades[id]
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", UIKit.sbox("slot_blue", 4))
		slot.custom_minimum_size = Vector2(60, 60)
		slot.add_child(UIKit.icon(u.icon, Vector2(40, 40)))
		var cnt := UIKit.label("x%d" % pl.items[id], 13, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, true)
		cnt.size_flags_vertical = Control.SIZE_SHRINK_END
		slot.add_child(cnt)
		UIKit.tip(slot, u.display_name, Tips.item(u, pl.items[id], pl))
		g.add_child(slot)
	v.add_child(_head("Fach-Sets"))
	var any := false
	for s in Db.sets:
		var n: int = pl.subject_counts.get(s, 0)
		if n <= 0:
			continue
		any = true
		var tier: int = pl.syn_tier(s)
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UIKit.sbox("container_cream", 4, Color.WHITE if tier > 0 else Color(1, 1, 1, 0.55)))
		p.custom_minimum_size = Vector2(340, 34)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		p.add_child(h)
		h.add_child(UIKit.icon(Db.subject_icon(s), Vector2(24, 24)))
		var nm := UIKit.label(s, 15, Db.subject_color(s).darkened(0.55))
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(nm)
		var goal := 2 if n < 2 else 4
		var state := "%d / %d" % [mini(n, goal), goal]
		if tier == 1:
			state += "   Stufe I"
		elif tier == 2:
			state = "%d   Stufe II" % n
		h.add_child(UIKit.label(state, 14, UIKit.GREEN if tier > 0 else UIKit.INK, HORIZONTAL_ALIGNMENT_RIGHT))
		UIKit.tip(p, "Fach-Set " + s, "Teile (Waffen + Items): %d\n\nab 2: %s\nab 4: %s" % [n, Db.sets[s][0], Db.sets[s][1]])
		v.add_child(p)
	if not any:
		v.add_child(UIKit.label("Sammle Waffen und Items desselben Fachs.", 13, Color(0.45, 0.4, 0.35)))
	v.add_child(_head("Dieser Run"))
	var st: Dictionary = Game.stats
	v.add_child(UIKit.label("Stufe %d   ·   Welle %d   ·   %d:%02d\n%d besiegt   ·   %d Elite   ·   Kette %d\nNeu würfeln %d   ·   Bannen %d   ·   Merken %d" % [
		Game.level, maxi(1, Game.wave), int(st.time) / 60, int(st.time) % 60, st.kills, st.elites + st.champions, st.max_chain,
		Game.lv_rerolls, Game.lv_bans, Game.lv_locks], 13, Color("5a2d0c")))
	return v
