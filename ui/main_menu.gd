class_name MainMenu
extends Control
## Hauptmenü als animiertes Schulsekretariat: Mutanten laufen am Fenster vorbei,
## Mr. Scrubbs schiebt seinen Eimer durch den Flur.

signal start_pressed
signal settings_pressed
signal quit_pressed

var _window: Control
var _walkers: Array = []
var _scrubbs: Sprite2D
var _bucket_t := 0.0
var _scrubbs_dir := 1.0
var _buttons: Array = []
var _t := 0.0

const WIN := Rect2(70, 170, 560, 270)

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
	_scrubbs.position = Vector2(100, 520)
	add_child(_scrubbs)
	# Titel
	var title := UIKit.label("NACHSITZEN", 76, Color("f2e6c4"), HORIZONTAL_ALIGNMENT_LEFT, true)
	title.position = Vector2(64, 36)
	add_child(title)
	var sub := UIKit.label("Apokalypse – Mutierte Schule", 28, Color("b8ffa8"), HORIZONTAL_ALIGNMENT_LEFT, true)
	sub.position = Vector2(70, 118)
	add_child(sub)
	# Buttons (Formulare auf dem Tresen)
	var col := VBoxContainer.new()
	col.position = Vector2(780, 190)
	col.add_theme_constant_override("separation", 22)
	add_child(col)
	var b1 := UIKit.button("Unterricht beginnen", Vector2(400, 76), 30, Color("f7efc8"))
	var b2 := UIKit.button("Hausordnung", Vector2(400, 62), 24)
	var b3 := UIKit.button("Vorzeitig abmelden", Vector2(400, 62), 24)
	b1.pressed.connect(func(): start_pressed.emit())
	b2.pressed.connect(func(): settings_pressed.emit())
	b3.pressed.connect(func(): quit_pressed.emit())
	for b in [b1, b2, b3]:
		col.add_child(b)
		_buttons.append(b)
	var hint := UIKit.label("Hausordnung = Einstellungen  ·  Esc = Pause", 14, Color(0.85, 0.85, 0.95, 0.8))
	hint.position = Vector2(786, 480)
	add_child(hint)
	var ver := UIKit.label("Vertical Slice · Godot 4 · Platzhalter-Sounds", 13, Color(0.8, 0.8, 0.9, 0.7))
	ver.position = Vector2(16, 696)
	add_child(ver)
	visibility_changed.connect(func():
		if visible:
			_enter())

func _enter() -> void:
	for i in _buttons.size():
		var b: Control = _buttons[i]
		b.modulate.a = 0.0
		b.position.x = 80.0
		var tw := b.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(0.12 * i)
		tw.set_parallel(true)
		tw.tween_property(b, "modulate:a", 1.0, 0.2)
		tw.tween_property(b, "position:x", 0.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
	_scrubbs.position.x += 70.0 * _scrubbs_dir * delta
	if _scrubbs.position.x > 560.0:
		_scrubbs_dir = -1.0
	elif _scrubbs.position.x < 40.0:
		_scrubbs_dir = 1.0
	_scrubbs.position.y = 520.0 - absf(sin(_t * 6.0)) * 5.0
	_scrubbs.flip_h = _scrubbs_dir < 0.0
	queue_redraw()

func _draw() -> void:
	var r := get_rect().size
	draw_rect(Rect2(Vector2.ZERO, r), Color(0.28, 0.33, 0.5))
	for i in 8:
		draw_rect(Rect2(0, i * 90, r.x, 45), Color(0.3, 0.35, 0.53))
	# Fenster
	draw_rect(WIN.grow(10), Color(0.35, 0.22, 0.1))
	draw_rect(WIN, Color(0.55, 0.9, 0.5))
	draw_rect(Rect2(WIN.position + Vector2(10, 10), WIN.size - Vector2(20, 20)), Color(0.5, 0.75, 0.85))
	# Fensterglas-Spiegelung über Mutanten
	draw_rect(Rect2(WIN.position + Vector2(10, 10), WIN.size - Vector2(20, 20)), Color(0.4, 1, 0.5, 0.12))
	draw_line(WIN.position + Vector2(WIN.size.x * 0.5, 0), WIN.position + Vector2(WIN.size.x * 0.5, WIN.size.y), Color(0.35, 0.22, 0.1), 8.0)
	draw_rect(Rect2(WIN.position.x - 20, WIN.end.y + 8, WIN.size.x + 40, 14), Color(0.45, 0.3, 0.15))
	# Flur-Boden und Tresen
	draw_rect(Rect2(0, 600, r.x, r.y - 600), Color(0.76, 0.78, 0.62))
	for i in 20:
		draw_line(Vector2(i * 70.0, 600), Vector2(i * 70.0 - 90.0, r.y), Color(0.6, 0.62, 0.48), 2.0)
	draw_rect(Rect2(0, 596, r.x, 8), Color(0.2, 0.22, 0.32))
	# Eimer neben Scrubbs
	var bx := _scrubbs.position.x + (110.0 if _scrubbs_dir > 0.0 else -40.0)
	var by := 640.0 - absf(sin(_t * 6.0)) * 3.0
	draw_colored_polygon(PackedVector2Array([Vector2(bx, by - 40), Vector2(bx + 38, by - 40), Vector2(bx + 32, by), Vector2(bx + 6, by)]), Color(0.3, 0.6, 0.9))
	draw_polyline(PackedVector2Array([Vector2(bx, by - 40), Vector2(bx + 38, by - 40), Vector2(bx + 32, by), Vector2(bx + 6, by), Vector2(bx, by - 40)]), Color(0.1, 0.15, 0.3), 3.0)
	draw_arc(Vector2(bx + 19, by - 40), 15.0, PI, TAU, 10, Color(0.15, 0.15, 0.2), 3.0)
	# Anschlagtafel
	draw_rect(Rect2(110, 480, 0, 0), Color.WHITE)
	# Tresen rechts mit Papieren
	draw_rect(Rect2(740, 120, 480, 470), Color(0.45, 0.3, 0.15))
	draw_rect(Rect2(750, 130, 460, 450), Color(0.86, 0.78, 0.58))
	draw_rect(Rect2(740, 120, 480, 470), Color(0.2, 0.12, 0.06), false, 5.0)
	# Glocke
	draw_circle(Vector2(1160, 540), 22.0, Color(0.9, 0.75, 0.2))
	draw_rect(Rect2(1140, 556, 40, 8), Color(0.5, 0.4, 0.1))
	draw_circle(Vector2(1160, 512), 5.0, Color(0.3, 0.25, 0.1))
