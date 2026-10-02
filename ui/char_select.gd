class_name CharSelect
extends Control
## Charakterauswahl als Klassenfoto. Nur Mr. Scrubbs ist spielbar; die anderen sind als gesperrte Platzhalter sichtbar.

signal confirmed(char_id: String)
signal back_pressed

const CHARS := [
	{id = "scrubbs", name = "Mr. Scrubbs", title = "Der Hausmeister", unlocked = true,
		desc = "Ausgewogenes Startprofil. Seine Reinigungs-Aura wischt Säurepfützen auf und verwandelt sie in Heilung.",
		hp = 3, speed = 3, slots = 4, diff = "Normal", weapon = "mop", weapon_name = "Wischmopp", ability = "Reinigungs-Aura",
		goals = ["Überlebe die Mutierte Schule (Kapitel 1)", "Verstecke dich 5x im Spind", "Besiege Frau Eisenhart ohne Treffer"]},
	{id = "justus", name = "Justus", title = "Der Streber", unlocked = false, desc = "+100 % Fernkampfschaden, aber wenig Leben. Mehr XP nach jeder Welle.", hp = 1, speed = 3, slots = 4, diff = "Schwer", weapon = "", weapon_name = "?", ability = "Hausaufgaben", goals = []},
	{id = "tobi", name = "Tobi", title = "Der Rowdy", unlocked = false, desc = "Schneller Nahkämpfer mit Zwillings-Schleuder-Katapult.", hp = 3, speed = 4, slots = 3, diff = "Mittel", weapon = "", weapon_name = "?", ability = "Rempler", goals = []},
	{id = "mia", name = "Mia", title = "Die Schulsprecherin", unlocked = false, desc = "Beschwört Klassensprecher-Drohnen mit Papierschnipseln.", hp = 2, speed = 3, slots = 4, diff = "Mittel", weapon = "", weapon_name = "?", ability = "Drohnen", goals = []},
	{id = "leon", name = "Leon", title = "Der Sport-Profi", unlocked = false, desc = "Sehr viele Lebenspunkte, nur zwei Waffenplätze. Hürden-Sprint.", hp = 5, speed = 4, slots = 2, diff = "Leicht", weapon = "", weapon_name = "?", ability = "Hürdenlauf", goals = []},
]

var _sel := 0
var _slot_rects: Array = []
var _scrub_sprite: Sprite2D
var _detail: Control
var _stamp_holder: Control
var _confirm_btn: Button
var _busy := false
var _t := 0.0
const PHOTO := Rect2(50, 90, 760, 540)

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var title := UIKit.label("Klassenfoto", 46, Color("f2e6c4"), HORIZONTAL_ALIGNMENT_LEFT, true)
	title.position = Vector2(54, 24)
	add_child(title)
	var hint := UIKit.label("Wer ist heute anwesend?", 20, Color(0.85, 0.9, 1.0))
	hint.position = Vector2(340, 44)
	add_child(hint)
	for i in CHARS.size():
		var r := Rect2(PHOTO.position.x + 30 + i * 140, PHOTO.position.y + 90, 126, 360)
		_slot_rects.append(r)
	_scrub_sprite = Sprite2D.new()
	_scrub_sprite.texture = Db.tex("res://assets/chars/scrubbs.png")
	_scrub_sprite.centered = false
	_scrub_sprite.scale = Vector2.ONE * (150.0 / float(_scrub_sprite.texture.get_height()))
	add_child(_scrub_sprite)
	_detail = Control.new()
	_detail.position = Vector2(830, 90)
	add_child(_detail)
	_stamp_holder = Control.new()
	UIKit.full(_stamp_holder)
	_stamp_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stamp_holder)
	_confirm_btn = UIKit.button("Anwesend!", Vector2(260, 64), 28, Color("c8f0b8"))
	_confirm_btn.position = Vector2(850, 622)
	_confirm_btn.pressed.connect(_confirm)
	add_child(_confirm_btn)
	var back := UIKit.button("Zurück", Vector2(150, 50), 20)
	back.position = Vector2(1120, 632)
	back.pressed.connect(func(): back_pressed.emit())
	add_child(back)
	_rebuild_detail()
	visibility_changed.connect(func():
		if visible:
			_busy = false
			for c in _stamp_holder.get_children():
				c.queue_free())

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not _busy:
		for i in _slot_rects.size():
			if _slot_rects[i].has_point(event.position):
				_select(i)

func _select(i: int) -> void:
	_sel = i
	if CHARS[i].unlocked:
		Sfx.play("click")
	else:
		Sfx.play("denied", 1.0, -6.0)
	_rebuild_detail()

func _rebuild_detail() -> void:
	for c in _detail.get_children():
		c.queue_free()
	var ch: Dictionary = CHARS[_sel]
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, Color("5a4630"), 5, 8, 16))
	panel.custom_minimum_size = Vector2(400, 510)
	_detail.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	panel.add_child(v)
	v.add_child(UIKit.label(ch.name, 34, UIKit.NAVY))
	v.add_child(UIKit.label(ch.title, 20, UIKit.RED))
	var d := UIKit.label(ch.desc, 16, UIKit.INK)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(368, 0)
	v.add_child(d)
	v.add_child(UIKit.label("Lebenspunkte:  %d/5" % ch.hp, 17))
	v.add_child(UIKit.label("Tempo:  %d/5" % ch.speed, 17))
	v.add_child(UIKit.label("Waffenplätze:  %d" % ch.slots, 17))
	v.add_child(UIKit.label("Fähigkeit:  " + ch.ability, 17))
	v.add_child(UIKit.label("Schwierigkeit:  " + ch.diff, 17))
	var wr := HBoxContainer.new()
	wr.add_theme_constant_override("separation", 8)
	v.add_child(wr)
	wr.add_child(UIKit.label("Startwaffe + Start-AG:", 17))
	if ch.weapon != "":
		wr.add_child(UIKit.icon(Db.weapons[ch.weapon].icon, Vector2(40, 40)))
		wr.add_child(UIKit.label(ch.weapon_name, 17, UIKit.NAVY))
	else:
		wr.add_child(UIKit.label("?", 17))
	v.add_child(UIKit.label("Meisterschaftsziele:", 17, UIKit.RED))
	if ch.unlocked:
		for g in ch.goals:
			var l := UIKit.label("• " + g, 14)
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(368, 0)
			v.add_child(l)
	else:
		var lk := UIKit.label("Gesperrt – benötigt Nachsitzen-Marken (Elite-Gegner & Bosse).", 15, UIKit.RED)
		lk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lk.custom_minimum_size = Vector2(368, 0)
		v.add_child(lk)
	_confirm_btn.disabled = not ch.unlocked
	UIKit.pop_in(panel, 0.0)

func _confirm() -> void:
	if _busy or not CHARS[_sel].unlocked:
		return
	_busy = true
	var st := UIKit.stamp("ANWESEND", UIKit.GREEN, 72, -12.0)
	_stamp_holder.add_child(st)
	st.reset_size()
	st.position = PHOTO.get_center() - st.size * 0.5
	UIKit.slam_stamp(st, 0.0)
	Juice.shake(0.2)
	get_tree().create_timer(1.1, true).timeout.connect(func(): confirmed.emit(CHARS[_sel].id))

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()
	# Mr. Scrubbs wischt nervös über den Rahmen
	var r: Rect2 = _slot_rects[0]
	_scrub_sprite.position = Vector2(r.position.x + 63 - _scrub_sprite.texture.get_width() * _scrub_sprite.scale.x * 0.5, r.position.y + 360 - 150 - absf(sin(_t * 3.0)) * (4.0 if _sel == 0 else 1.0))
	_scrub_sprite.rotation = sin(_t * 5.0) * 0.04 if _sel == 0 else 0.0

func _draw() -> void:
	var sz := get_rect().size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.2, 0.24, 0.38))
	# Foto
	draw_rect(Rect2(PHOTO.position + Vector2(8, 10), PHOTO.size), Color(0, 0, 0, 0.35))
	draw_rect(PHOTO, Color(0.96, 0.93, 0.85))
	draw_rect(Rect2(PHOTO.position + Vector2(18, 18), PHOTO.size - Vector2(36, 60)), Color(0.62, 0.74, 0.86))
	draw_rect(Rect2(PHOTO.position.x + 18, PHOTO.position.y + 18 + (PHOTO.size.y - 60) * 0.55, PHOTO.size.x - 36, (PHOTO.size.y - 60) * 0.45), Color(0.72, 0.68, 0.5))
	draw_string(ThemeDB.fallback_font, PHOTO.position + Vector2(24, PHOTO.size.y - 16), "Klasse 7b  ·  Fotograf: Herr Kamera  ·  Freitag, 5. Stunde", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.25, 0.2, 0.15))
	for i in _slot_rects.size():
		var r: Rect2 = _slot_rects[i]
		var ch: Dictionary = CHARS[i]
		# markierte Bodenfläche
		draw_circle(Vector2(r.get_center().x, r.end.y - 8), 0.0, Color.WHITE)
		var cx := r.get_center().x
		var floor_pts := PackedVector2Array()
		for k in 20:
			var a := TAU * k / 20.0
			floor_pts.append(Vector2(cx + cos(a) * 58, r.end.y - 6 + sin(a) * 14))
		draw_colored_polygon(floor_pts, Color(0.3, 0.25, 0.15, 0.4) if i != _sel else Color(1.0, 0.85, 0.2, 0.7))
		if i != 0:
			# gesperrte Platzhalter-Silhouette
			var c := Color(0.2, 0.2, 0.28, 0.9)
			draw_circle(Vector2(cx, r.end.y - 130), 30, c)
			draw_rect(Rect2(cx - 28, r.end.y - 100, 56, 90), c)
			draw_string(ThemeDB.fallback_font, Vector2(cx - 8, r.end.y - 120), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.9, 0.9, 1.0))
		draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.end.y + 26), ch.name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Color(0.15, 0.12, 0.1))
		if i == _sel:
			draw_rect(r.grow(4), Color(1, 0.85, 0.2), false, 4.0)
		if not ch.unlocked:
			draw_string(ThemeDB.fallback_font, Vector2(r.position.x, r.position.y + 14), "gesperrt", HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(0.6, 0.15, 0.15))
