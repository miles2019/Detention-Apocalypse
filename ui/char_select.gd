class_name CharSelect
extends Control
## Charakterauswahl als Klassenfoto (Vector UI Pack): Karten im Foto-Rahmen, rechts ein Notizbuch mit Werten.
## Spielbar: Mr. Scrubbs, Frau Kelle (Mensa-Köchin), Herr Probe (Referendar) – die beiden letzten kosten Nachsitzen-Marken.
## Zwei weitere Plätze sind Platzhalter ("bald verfügbar").

signal confirmed(char_id: String)
signal back_pressed

const SOON := [
	{id = "tobi", name = "Tobi", title = "Der Rowdy", soon = true, desc = "Schneller Nahkämpfer mit Zwillings-Schleuder. Noch im Nachsitzen – bald verfügbar."},
	{id = "mia", name = "Mia", title = "Die Schulsprecherin", soon = true, desc = "Beschwört Klassensprecher-Drohnen. Noch im Nachsitzen – bald verfügbar."},
]

var chars: Array = []
var _sel := 0
var _cards: Array = []
var _portraits: Array = []
var _detail: Control
var _stamp_holder: Control
var _busy := false
var _t := 0.0
var _banner: Control

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	for id in ["scrubbs", "kelle", "probe"]:
		chars.append(Db.characters[id])
	chars.append_array(SOON)
	# Titelbanner
	_banner = Panel.new()
	_banner.add_theme_stylebox_override("panel", UIKit.sbox("header_blue", 0))
	_banner.position = Vector2(40, 22)
	_banner.size = Vector2(440, 84)
	add_child(_banner)
	var bl := UIKit.label("Klassenfoto", 46, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	bl.position = Vector2(0, 10)
	bl.size = Vector2(440, 60)
	_banner.add_child(bl)
	var hint := UIKit.label("Wer ist heute anwesend?", 22, Color(0.9, 0.95, 1.0), HORIZONTAL_ALIGNMENT_LEFT, true)
	hint.position = Vector2(500, 48)
	add_child(hint)
	# Foto-Rahmen mit fünf Karten
	var frame := Panel.new()
	frame.add_theme_stylebox_override("panel", UIKit.sbox("container_cream", 0))
	frame.position = Vector2(30, 120)
	frame.size = Vector2(790, 570)
	add_child(frame)
	var row := HBoxContainer.new()
	row.position = Vector2(54, 146)
	row.add_theme_constant_override("separation", 10)
	add_child(row)
	for i in chars.size():
		var card := _make_card(i)
		row.add_child(card)
		_cards.append(card)
	var cap := UIKit.label("Klasse 7b  ·  Fotograf: Herr Kamera  ·  Freitag, 5. Stunde", 16, Color("5a2d0c"))
	cap.position = Vector2(56, 642)
	add_child(cap)
	_detail = Control.new()
	_detail.position = Vector2(830, 22)
	add_child(_detail)
	_stamp_holder = Control.new()
	UIKit.full(_stamp_holder)
	_stamp_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamp_holder)
	_rebuild()
	visibility_changed.connect(func():
		if visible:
			_busy = false
			for c in _stamp_holder.get_children():
				c.queue_free()
			for i in chars.size():
				if chars[i].id == Save.data.character:
					_sel = i
			_rebuild()
			for i in _cards.size():
				UIKit.pop_in(_cards[i], 0.06 * i))

func _playable(i: int) -> bool:
	return not chars[i].get("soon", false)

func _unlocked(i: int) -> bool:
	return _playable(i) and Save.char_unlocked(chars[i].id)

func _make_card(i: int) -> Control:
	var ch: Dictionary = chars[i]
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(142, 470)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(110, 230)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.draw.connect(func(): _draw_portrait(portrait, i))
	v.add_child(portrait)
	_portraits.append(portrait)
	var nm := UIKit.label(ch.name, 17, UIKit.NAVY if _playable(i) else Color(0.35, 0.35, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(nm)
	var tt := UIKit.label(ch.title, 12, UIKit.RED if _playable(i) else Color(0.4, 0.4, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	tt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tt.custom_minimum_size = Vector2(110, 32)
	v.add_child(tt)
	var lk := HBoxContainer.new()
	lk.name = "Lock"
	lk.alignment = BoxContainer.ALIGNMENT_CENTER
	lk.add_child(UIKit.icon(UIKit.ICON % "key", Vector2(24, 24)))
	var lt := UIKit.label("", 13, UIKit.RED)
	lt.name = "LockText"
	lk.add_child(lt)
	v.add_child(lk)
	p.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not _busy:
			_select(i))
	p.mouse_entered.connect(func():
		if i != _sel:
			Sfx.play("hover", 1.0, -10.0))
	return p

func _draw_portrait(c: Control, i: int) -> void:
	var ch: Dictionary = chars[i]
	var cx := c.size.x * 0.5
	var bob := absf(sin(_t * 3.0)) * (5.0 if i == _sel else 0.0)
	# Bodenmarkierung
	var pts := PackedVector2Array()
	for k in 20:
		var a := TAU * k / 20.0
		pts.append(Vector2(cx + cos(a) * 46.0, c.size.y - 14.0 + sin(a) * 10.0))
	c.draw_colored_polygon(pts, Color(1.0, 0.85, 0.2, 0.7) if i == _sel else Color(0.3, 0.25, 0.15, 0.35))
	if _playable(i):
		var tex: Texture2D = Db.tex(ch.tex)
		var s := 128.0 * (float(ch.height) / 66.0) / float(tex.get_height())
		var sz := tex.get_size() * s
		var mod: Color = ch.tint
		if not _unlocked(i):
			mod = Color(0.16, 0.16, 0.22, 0.95)
		c.draw_set_transform(Vector2(cx, c.size.y - 20.0 - bob), sin(_t * 5.0) * 0.04 if i == _sel else 0.0, Vector2.ONE)
		c.draw_texture_rect(tex, Rect2(-sz.x * 0.5, -sz.y, sz.x, sz.y), false, mod)
		c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		var col := Color(0.2, 0.2, 0.28, 0.92)
		c.draw_circle(Vector2(cx, c.size.y - 150.0), 30.0, col)
		c.draw_rect(Rect2(cx - 28.0, c.size.y - 122.0, 56.0, 96.0), col)
		c.draw_string(ThemeDB.fallback_font, Vector2(cx - 10.0, c.size.y - 136.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(0.9, 0.9, 1.0))

func _style_cards() -> void:
	for i in _cards.size():
		var sb: StyleBox
		if i == _sel:
			sb = UIKit.sbox("slot_yellow", 14)
		elif _unlocked(i):
			sb = UIKit.sbox("slot_blue", 14)
		else:
			sb = UIKit.sbox("slot_purple", 14, Color(0.6, 0.6, 0.7) if not _playable(i) else Color(0.85, 0.85, 0.95))
		_cards[i].add_theme_stylebox_override("panel", sb)
		var lk: Control = _cards[i].find_child("Lock", true, false)
		var lt: Label = _cards[i].find_child("LockText", true, false)
		lk.visible = not _unlocked(i)
		if _playable(i):
			lt.text = "%d Marken" % int(chars[i].cost)
		else:
			lt.text = "bald"

func _select(i: int) -> void:
	_sel = i
	if _unlocked(i):
		Sfx.play("click")
	else:
		Sfx.play("denied", 1.0, -6.0)
	_rebuild()
	UIKit.pop_in(_cards[i], 0.0)

func _bar(label: String, value: int, max_value: int, fill: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var l := UIKit.label(label, 16, Color("5a2d0c"))
	l.custom_minimum_size = Vector2(120, 0)
	h.add_child(l)
	var b := ProgressBar.new()
	b.custom_minimum_size = Vector2(220, 18)
	b.max_value = max_value
	b.value = value
	b.show_percentage = false
	b.add_theme_stylebox_override("background", UIKit.sbox("bar_back", 4))
	b.add_theme_stylebox_override("fill", UIKit.sbox(fill, 4))
	h.add_child(b)
	return h

func _rebuild() -> void:
	_style_cards()
	for c in _detail.get_children():
		c.queue_free()
	var ch: Dictionary = chars[_sel]
	var nb := UIKit.notebook(ch.name, Vector2(440, 676))
	_detail.add_child(nb.root)
	var v: VBoxContainer = nb.content
	v.add_theme_constant_override("separation", 7)
	v.add_child(UIKit.label(ch.title, 22, UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER))
	var d := UIKit.label(ch.desc, 14, UIKit.INK)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(340, 0)
	v.add_child(d)
	if _playable(_sel):
		var bars: Dictionary = ch.bars
		v.add_child(_bar("Lebenspunkte", bars.hp, 5, "bar_red"))
		v.add_child(_bar("Tempo", bars.speed, 5, "bar_cyan"))
		v.add_child(_bar("Schaden", bars.dmg, 5, "bar_green"))
		var facts := "Leben %d   ·   Tempo %d %%   ·   Schaden %d %%\nErfahrung %d %%   ·   Flächenradius %d %%" % [
			int(ch.hp), int(round(float(ch.speed) * 100.0)), int(round(float(ch.dmg) * 100.0)), int(round(float(ch.xp) * 100.0)), int(round(float(ch.area) * 100.0))]
		v.add_child(UIKit.label(facts, 13, Color("5a2d0c")))
		var ab := HBoxContainer.new()
		ab.add_theme_constant_override("separation", 8)
		ab.add_child(UIKit.icon(UIKit.ICON % "energy", Vector2(28, 28)))
		ab.add_child(UIKit.label("Fähigkeit: " + ch.ability + "   ·   " + ch.diff, 16, UIKit.NAVY))
		v.add_child(ab)
		var wr := HBoxContainer.new()
		wr.add_theme_constant_override("separation", 10)
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", UIKit.sbox("slot_blue", 6))
		slot.custom_minimum_size = Vector2(70, 76)
		var sw: String = ch.start_weapon if String(ch.start_weapon) != "" else Save.data.start_weapon
		if Db.weapons.has(sw):
			slot.add_child(UIKit.icon(Db.weapons[sw].icon, Vector2(50, 50)))
			UIKit.tip(slot, Db.weapons[sw].display_name, Tips.weapon(Db.weapons[sw], 1, null, false))
		wr.add_child(slot)
		var wv := VBoxContainer.new()
		wr.add_child(wv)
		wv.add_child(UIKit.label("Startwaffe: " + (Db.weapons[sw].display_name if Db.weapons.has(sw) else "?"), 16, UIKit.NAVY))
		var ag: String = Save.data.ag_selected
		wv.add_child(UIKit.label("Start-AG: " + (Db.ags[ag].name if ag != "" and Db.ags.has(ag) else "keine"), 15, UIKit.INK))
		v.add_child(wr)
		v.add_child(UIKit.label("Meisterschaftsziele", 17, UIKit.RED))
		for g in ch.goals:
			var gr := HBoxContainer.new()
			gr.add_theme_constant_override("separation", 6)
			gr.add_child(UIKit.icon(UIKit.ICON % "tab", Vector2(20, 20)))
			var gl := UIKit.label(g, 13, UIKit.INK)
			gl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			gl.custom_minimum_size = Vector2(320, 0)
			gr.add_child(gl)
			v.add_child(gr)
	else:
		var lk := UIKit.label("Dieser Platz auf dem Klassenfoto ist noch leer.", 14, UIKit.RED)
		lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lk.custom_minimum_size = Vector2(340, 0)
		v.add_child(lk)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var btns := HBoxContainer.new()
	btns.alignment = BoxContainer.ALIGNMENT_CENTER
	btns.add_theme_constant_override("separation", 12)
	v.add_child(btns)
	var ok: Button
	if _playable(_sel) and not _unlocked(_sel):
		var cost := int(ch.cost)
		ok = UIKit.button("Freischalten (%d Marken)" % cost, Vector2(250, 60), 17, Color("ffe08a"))
		ok.disabled = int(Save.data.marken) < cost
		ok.pressed.connect(_unlock)
		UIKit.tip(ok, "Freischalten", "Kostet %d Nachsitzen-Marken (du hast %d).\nMarken gibt es für Elite-Gegner, Bosse und Challenges." % [cost, int(Save.data.marken)])
	else:
		ok = UIKit.button("Anwesend!", Vector2(210, 60), 26, Color("c8f0b8"))
		ok.disabled = not _unlocked(_sel)
		ok.pressed.connect(_confirm)
	var back := UIKit.button("Zurück", Vector2(140, 60), 22, Color("f4b0a8"))
	back.pressed.connect(func(): back_pressed.emit())
	btns.add_child(ok)
	btns.add_child(back)

func _unlock() -> void:
	if _busy or not _playable(_sel):
		return
	if Save.unlock_char(chars[_sel].id):
		Sfx.play("levelup", 1.2, -4.0)
		Juice.shake(0.2)
		var st := UIKit.stamp("EINGESCHULT", UIKit.GREEN, 60, -10.0)
		_stamp_holder.add_child(st)
		st.reset_size()
		st.position = Vector2(420, 330) - st.size * 0.5
		UIKit.slam_stamp(st, 0.0)
		var tw := st.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(1.0)
		tw.tween_property(st, "modulate:a", 0.0, 0.3)
		tw.tween_callback(st.queue_free)
		_rebuild()
	else:
		Sfx.play("denied")

func _confirm() -> void:
	if _busy or not _unlocked(_sel):
		return
	_busy = true
	Save.data.character = chars[_sel].id
	Save.save_game()
	var st := UIKit.stamp("ANWESEND", UIKit.GREEN, 72, -12.0)
	_stamp_holder.add_child(st)
	st.reset_size()
	st.position = Vector2(420, 330) - st.size * 0.5
	UIKit.slam_stamp(st, 0.0)
	Juice.shake(0.2)
	get_tree().create_timer(1.1, true).timeout.connect(func(): confirmed.emit(chars[_sel].id))

func _process(_delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += _delta
	for p in _portraits:
		p.queue_redraw()
	queue_redraw()

func _draw() -> void:
	var sz := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.2, 0.24, 0.38))
	for i in 10:
		draw_rect(Rect2(0, i * 76.0, sz.x, 38), Color(0.22, 0.26, 0.41))
