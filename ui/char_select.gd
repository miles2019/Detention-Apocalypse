class_name CharSelect
extends Control
## Charakterauswahl als Klassenfoto (Vector UI Pack): fünf Karten im Foto-Rahmen, rechts ein Notizbuch mit Werten.
## Nur Mr. Scrubbs ist spielbar; die anderen sind gesperrte Platzhalter.

signal confirmed(char_id: String)
signal back_pressed

const CHARS := [
	{id = "scrubbs", name = "Mr. Scrubbs", title = "Der Hausmeister", unlocked = true,
		desc = "Ausgewogenes Startprofil. Seine Reinigungs-Aura wischt Säurepfützen auf und verwandelt sie in Heilung.",
		hp = 3, speed = 3, slots = 4, diff = "Normal", ability = "Reinigungs-Aura",
		goals = ["Überlebe die Mutierte Schule (Kapitel 1)", "Wische 10 Säurepfützen auf", "Besiege Frau Eisenhart ohne Treffer"]},
	{id = "justus", name = "Justus", title = "Der Streber", unlocked = false, desc = "+100 % Fernkampfschaden, aber wenig Leben. Mehr XP nach jeder Welle.", hp = 1, speed = 3, slots = 4, diff = "Schwer", ability = "Hausaufgaben", goals = []},
	{id = "tobi", name = "Tobi", title = "Der Rowdy", unlocked = false, desc = "Schneller Nahkämpfer mit Zwillings-Schleuder-Katapult.", hp = 3, speed = 4, slots = 3, diff = "Mittel", ability = "Rempler", goals = []},
	{id = "mia", name = "Mia", title = "Die Schulsprecherin", unlocked = false, desc = "Beschwört Klassensprecher-Drohnen mit Papierschnipseln.", hp = 2, speed = 3, slots = 4, diff = "Mittel", ability = "Drohnen", goals = []},
	{id = "leon", name = "Leon", title = "Der Sport-Profi", unlocked = false, desc = "Sehr viele Lebenspunkte, nur zwei Waffenplätze. Hürden-Sprint.", hp = 5, speed = 4, slots = 2, diff = "Leicht", ability = "Hürdenlauf", goals = []},
]

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
	for i in CHARS.size():
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
			_rebuild()
			for i in _cards.size():
				UIKit.pop_in(_cards[i], 0.06 * i))

func _make_card(i: int) -> Control:
	var ch: Dictionary = CHARS[i]
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
	var nm := UIKit.label(ch.name, 18, UIKit.NAVY if ch.unlocked else Color(0.35, 0.35, 0.4), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(nm)
	var tt := UIKit.label(ch.title, 12, UIKit.RED if ch.unlocked else Color(0.4, 0.4, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	tt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tt.custom_minimum_size = Vector2(110, 32)
	v.add_child(tt)
	if not ch.unlocked:
		var lk := HBoxContainer.new()
		lk.alignment = BoxContainer.ALIGNMENT_CENTER
		lk.add_child(UIKit.icon(UIKit.ICON % "key", Vector2(24, 24)))
		lk.add_child(UIKit.label("gesperrt", 13, UIKit.RED))
		v.add_child(lk)
	p.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and not _busy:
			_select(i))
	p.mouse_entered.connect(func():
		if i != _sel:
			Sfx.play("hover", 1.0, -10.0))
	return p

func _draw_portrait(c: Control, i: int) -> void:
	var ch: Dictionary = CHARS[i]
	var cx := c.size.x * 0.5
	var bob := absf(sin(_t * 3.0)) * (5.0 if i == _sel else 0.0)
	# Bodenmarkierung
	var pts := PackedVector2Array()
	for k in 20:
		var a := TAU * k / 20.0
		pts.append(Vector2(cx + cos(a) * 46.0, c.size.y - 14.0 + sin(a) * 10.0))
	c.draw_colored_polygon(pts, Color(1.0, 0.85, 0.2, 0.7) if i == _sel else Color(0.3, 0.25, 0.15, 0.35))
	if ch.unlocked:
		var tex: Texture2D = Db.tex("res://assets/chars/scrubbs.png")
		var s := 170.0 / float(tex.get_height())
		var sz := tex.get_size() * s
		c.draw_set_transform(Vector2(cx, c.size.y - 20.0 - bob), sin(_t * 5.0) * 0.04 if i == _sel else 0.0, Vector2.ONE)
		c.draw_texture_rect(tex, Rect2(-sz.x * 0.5, -sz.y, sz.x, sz.y), false)
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
		elif CHARS[i].unlocked:
			sb = UIKit.sbox("slot_blue", 14)
		else:
			sb = UIKit.sbox("slot_purple", 14, Color(0.6, 0.6, 0.7))
		_cards[i].add_theme_stylebox_override("panel", sb)

func _select(i: int) -> void:
	_sel = i
	if CHARS[i].unlocked:
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
	var ch: Dictionary = CHARS[_sel]
	var nb := UIKit.notebook(ch.name, Vector2(440, 676))
	_detail.add_child(nb.root)
	var v: VBoxContainer = nb.content
	v.add_theme_constant_override("separation", 7)
	v.add_child(UIKit.label(ch.title, 22, UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER))
	var d := UIKit.label(ch.desc, 15, UIKit.INK)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(340, 0)
	v.add_child(d)
	v.add_child(_bar("Lebenspunkte", ch.hp, 5, "bar_red"))
	v.add_child(_bar("Tempo", ch.speed, 5, "bar_cyan"))
	v.add_child(_bar("Waffenplätze", ch.slots, 6, "bar_green"))
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
	var sw: String = Save.data.start_weapon if ch.id == "scrubbs" else ""
	if sw != "" and Db.weapons.has(sw):
		slot.add_child(UIKit.icon(Db.weapons[sw].icon, Vector2(50, 50)))
	wr.add_child(slot)
	var wv := VBoxContainer.new()
	wr.add_child(wv)
	wv.add_child(UIKit.label("Startwaffe: " + (Db.weapons[sw].display_name if sw != "" and Db.weapons.has(sw) else "?"), 16, UIKit.NAVY))
	var ag: String = Save.data.ag_selected
	wv.add_child(UIKit.label("Start-AG: " + (Db.ags[ag].name if ag != "" and Db.ags.has(ag) else "keine"), 15, UIKit.INK))
	v.add_child(wr)
	v.add_child(UIKit.label("Meisterschaftsziele", 17, UIKit.RED))
	if ch.unlocked:
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
		var lk := UIKit.label("Gesperrt – benötigt Nachsitzen-Marken (Elite-Gegner & Bosse).", 14, UIKit.RED)
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
	var ok := UIKit.button("Anwesend!", Vector2(210, 60), 26, Color("c8f0b8"))
	ok.disabled = not ch.unlocked
	ok.pressed.connect(_confirm)
	var back := UIKit.button("Zurück", Vector2(140, 60), 22, Color("f4b0a8"))
	back.pressed.connect(func(): back_pressed.emit())
	btns.add_child(ok)
	btns.add_child(back)

func _confirm() -> void:
	if _busy or not CHARS[_sel].unlocked:
		return
	_busy = true
	var st := UIKit.stamp("ANWESEND", UIKit.GREEN, 72, -12.0)
	_stamp_holder.add_child(st)
	st.reset_size()
	st.position = Vector2(420, 330) - st.size * 0.5
	UIKit.slam_stamp(st, 0.0)
	Juice.shake(0.2)
	get_tree().create_timer(1.1, true).timeout.connect(func(): confirmed.emit(CHARS[_sel].id))

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
