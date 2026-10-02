class_name MainMenu
extends Control
## Hauptmenü als animiertes Schulsekretariat (Vector UI Pack): Mutanten laufen am Fenster vorbei,
## Mr. Scrubbs schiebt seinen Eimer durch den Flur. Rechts ein Notizbuch mit den Hauptknöpfen.

signal start_pressed
signal settings_pressed
signal quit_pressed

var _window: Control
var _walkers: Array = []
var _scrubbs: Sprite2D
var _scrubbs_dir := 1.0
var _hop := 0.0
var _buttons: Array = []
var _notebook: Control
var _title: Control
var _sub: Control
var _stats: Label
var _t := 0.0

const WIN := Rect2(60, 250, 560, 250)

func _ready() -> void:
	UIKit.full(self)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Fenster mit vorbeilaufenden Mutanten
	_window = Control.new()
	_window.position = WIN.position + Vector2(10, 10)
	_window.size = WIN.size - Vector2(20, 20)
	_window.clip_contents = true
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window)
	var specs := [["frog.png", 100.0], ["rat.png", 90.0], ["bird_01.png", 120.0], ["zombie_00.png", 140.0], ["sheep_00.png", 110.0], ["nerd_00.png", 100.0]]
	var x := 0.0
	for s in specs:
		var sp := Sprite2D.new()
		sp.texture = Db.tex("res://assets/enemies/" + s[0])
		var sc: float = s[1] / float(sp.texture.get_height())
		sp.scale = Vector2(sc, sc)
		sp.centered = false
		sp.position = Vector2(x, _window.size.y - s[1] - 4)
		_window.add_child(sp)
		_walkers.append({node = sp, base_y = sp.position.y, speed = randf_range(40, 70), phase = randf() * 6.0})
		x += 170.0
	# Mr. Scrubbs mit Eimer
	_scrubbs = Sprite2D.new()
	_scrubbs.texture = Db.tex("res://assets/chars/scrubbs.png")
	_scrubbs.scale = Vector2.ONE * (150.0 / float(_scrubbs.texture.get_height()))
	_scrubbs.centered = false
	_scrubbs.position = Vector2(100, 530)
	add_child(_scrubbs)
	# Titel: rotes Banner + Holzschild
	_title = Panel.new()
	_title.add_theme_stylebox_override("panel", UIKit.sbox("header_red", 0))
	_title.position = Vector2(46, 28)
	_title.size = Vector2(640, 132)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)
	var tl := UIKit.label("NACHSITZEN", 78, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	tl.position = Vector2(0, 18)
	tl.size = Vector2(640, 96)
	_title.add_child(tl)
	_sub = Panel.new()
	_sub.add_theme_stylebox_override("panel", UIKit.sbox("label_wood", 0))
	_sub.position = Vector2(86, 166)
	_sub.size = Vector2(560, 56)
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub)
	var sl := UIKit.label("Apokalypse – Mutierte Schule", 26, Color("fff1c8"), HORIZONTAL_ALIGNMENT_CENTER, true)
	sl.position = Vector2(0, 8)
	sl.size = Vector2(560, 40)
	_sub.add_child(sl)
	# Notizbuch mit den Hauptknöpfen
	var nb := UIKit.notebook("Sekretariat", Vector2(480, 580))
	_notebook = nb.root
	_notebook.position = Vector2(740, 72)
	add_child(_notebook)
	var c: VBoxContainer = nb.content
	c.add_theme_constant_override("separation", 14)
	c.add_child(UIKit.label("Heute ist Freitag, 5. Stunde.", 15, Color("5a2d0c"), HORIZONTAL_ALIGNMENT_CENTER))
	var b1 := _menu_button("Schulhof betreten", "adventure", Color("c8f0b8"), 74, 28)
	var b2 := _menu_button("Hausordnung", "settings", Color("a8c8f8"), 60, 24)
	var b3 := _menu_button("Vorzeitig abmelden", "close", Color("f4b0a8"), 60, 22)
	b1.pressed.connect(func(): start_pressed.emit())
	b2.pressed.connect(func(): settings_pressed.emit())
	b3.pressed.connect(func(): quit_pressed.emit())
	for b in [b1, b2, b3]:
		c.add_child(b)
		_buttons.append(b)
	var sep := ColorRect.new()
	sep.color = Color(0.35, 0.2, 0.08, 0.35)
	sep.custom_minimum_size = Vector2(0, 3)
	c.add_child(sep)
	_stats = UIKit.label("", 15, Color("5a2d0c"), HORIZONTAL_ALIGNMENT_CENTER)
	_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats.custom_minimum_size = Vector2(380, 0)
	c.add_child(_stats)
	var ver := UIKit.label("Vertical Slice · Godot 4 · Platzhalter-Sounds", 13, Color(0.85, 0.85, 0.95, 0.7))
	ver.position = Vector2(16, 696)
	add_child(ver)
	visibility_changed.connect(func():
		if visible:
			_enter())

func _menu_button(text: String, icon_name: String, col: Color, h: float, fs: int) -> Button:
	var b := UIKit.button(text, Vector2(380, h), fs, col)
	b.icon = UIKit.tex_icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("icon_max_width", int(h * 0.55))
	b.add_theme_constant_override("h_separation", 14)
	b.mouse_entered.connect(func(): _hop = 1.0)
	return b

func _enter() -> void:
	_stats.text = "Fehlstunden-Pässe: %d   ·   Nachsitzen-Marken: %d\nRuns: %d   ·   Siege: %d   ·   Mutanten besiegt: %d" % [
		Save.data.passes, Save.data.marken, Save.data.runs, Save.data.wins, Save.data.total_kills]
	# Titel fällt herein, Notizbuch gleitet ein, Knöpfe poppen nacheinander auf
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	_title.position.y = -160.0
	tw.tween_property(_title, "position:y", 28.0, 0.6).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_sub.modulate.a = 0.0
	tw.tween_property(_sub, "modulate:a", 1.0, 0.3).set_delay(0.5)
	_notebook.position.x = 1400.0
	tw.tween_property(_notebook, "position:x", 740.0, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.15)
	for i in _buttons.size():
		var b: Control = _buttons[i]
		b.pivot_offset = b.custom_minimum_size * 0.5
		b.scale = Vector2(0.01, 0.01)
		tw.tween_property(b, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.5 + 0.12 * i)

func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	for w in _walkers:
		var n: Sprite2D = w.node
		n.position.x += w.speed * delta
		if n.position.x > _window.size.x + 40.0:
			n.position.x = -200.0
		n.position.y = w.base_y - absf(sin(_t * 4.0 + w.phase)) * 8.0
	_hop = maxf(0.0, _hop - delta * 3.0)
	_scrubbs.position.x += 70.0 * _scrubbs_dir * delta
	if _scrubbs.position.x > 540.0:
		_scrubbs_dir = -1.0
	elif _scrubbs.position.x < 40.0:
		_scrubbs_dir = 1.0
	_scrubbs.position.y = 530.0 - absf(sin(_t * 6.0)) * 5.0 - sin(_hop * PI) * 26.0
	_scrubbs.flip_h = _scrubbs_dir < 0.0
	queue_redraw()

func _draw() -> void:
	var r := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, r), Color(0.28, 0.33, 0.5))
	for i in 8:
		draw_rect(Rect2(0, i * 90, r.x, 45), Color(0.3, 0.35, 0.53))
	# Fenster
	draw_rect(WIN.grow(10), Color(0.35, 0.22, 0.1))
	draw_rect(WIN, Color(0.55, 0.9, 0.5))
	draw_rect(Rect2(WIN.position + Vector2(10, 10), WIN.size - Vector2(20, 20)), Color(0.5, 0.75, 0.85))
	draw_rect(Rect2(WIN.position + Vector2(10, 10), WIN.size - Vector2(20, 20)), Color(0.4, 1, 0.5, 0.12))
	draw_line(WIN.position + Vector2(WIN.size.x * 0.5, 0), WIN.position + Vector2(WIN.size.x * 0.5, WIN.size.y), Color(0.35, 0.22, 0.1), 8.0)
	draw_rect(Rect2(WIN.position.x - 20, WIN.end.y + 8, WIN.size.x + 40, 14), Color(0.45, 0.3, 0.15))
	# Flur-Boden
	draw_rect(Rect2(0, 612, r.x, r.y - 612), Color(0.76, 0.78, 0.62))
	for i in 20:
		draw_line(Vector2(i * 70.0, 612), Vector2(i * 70.0 - 90.0, r.y), Color(0.6, 0.62, 0.48), 2.0)
	draw_rect(Rect2(0, 608, r.x, 8), Color(0.2, 0.22, 0.32))
	# Eimer neben Scrubbs
	var bx := _scrubbs.position.x + (110.0 if _scrubbs_dir > 0.0 else -40.0)
	var by := 650.0 - absf(sin(_t * 6.0)) * 3.0
	draw_colored_polygon(PackedVector2Array([Vector2(bx, by - 40), Vector2(bx + 38, by - 40), Vector2(bx + 32, by), Vector2(bx + 6, by)]), Color(0.3, 0.6, 0.9))
	draw_polyline(PackedVector2Array([Vector2(bx, by - 40), Vector2(bx + 38, by - 40), Vector2(bx + 32, by), Vector2(bx + 6, by), Vector2(bx, by - 40)]), Color(0.1, 0.15, 0.3), 3.0)
	draw_arc(Vector2(bx + 19, by - 40), 15.0, PI, TAU, 10, Color(0.15, 0.15, 0.2), 3.0)
	# Glocke
	draw_circle(Vector2(690, 590), 18.0, Color(0.9, 0.75, 0.2))
	draw_rect(Rect2(674, 604, 32, 7), Color(0.5, 0.4, 0.1))
