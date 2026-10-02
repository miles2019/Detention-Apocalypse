class_name HubModal
extends Control
## Basisklasse der Schulhof-Menüs: Notizbuch-Fenster (Vector UI Pack), Währungsleiste, Schließen-Knopf, Pause beim Öffnen.

signal closed

var title := ""
var window_size := Vector2(1000, 620)
var nb: Dictionary
var content: VBoxContainer
var _cur_label: Label
var _root: Control

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(UIKit.dim(0.62))
	nb = UIKit.notebook(title, window_size)
	_root = nb.root
	_root.position = (Vector2(1280, 720) - window_size) * 0.5
	add_child(_root)
	content = nb.content
	# Schließen-Knopf
	var x := UIKit.button("X", Vector2(52, 46), 22, Color("e0453a"))
	x.position = Vector2(window_size.x - 74.0, 34.0)
	x.pressed.connect(close)
	_root.add_child(x)
	# Währungsleiste
	var cur := HBoxContainer.new()
	cur.position = Vector2(60, window_size.y - 56.0)
	cur.add_theme_constant_override("separation", 10)
	_root.add_child(cur)
	cur.add_child(UIKit.icon(UIKit.ICON % "coins", Vector2(34, 34)))
	_cur_label = UIKit.label("", 20, Color("5a2d0c"))
	cur.add_child(_cur_label)
	build()

## Von Unterklassen überschrieben: Inhalt aufbauen
func build() -> void:
	pass

func refresh() -> void:
	_cur_label.text = "Fehlstunden-Pässe: %d     Nachsitzen-Marken: %d" % [Save.data.passes, Save.data.marken]

func open() -> void:
	refresh()
	visible = true
	Game.modal_open = true
	get_tree().paused = true
	Sfx.play("stamp", 1.2, -8.0)
	_root.pivot_offset = window_size * 0.5
	_root.scale = Vector2(0.85, 0.85)
	_root.modulate.a = 0.0
	var tw := _root.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(_root, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(_root, "modulate:a", 1.0, 0.12)

func close() -> void:
	if not visible:
		return
	visible = false
	Game.modal_open = false
	get_tree().paused = false
	Sfx.play("click", 0.8)
	closed.emit()

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()

## Karte kurz aufpoppen lassen (Kauf-Feedback)
func pulse(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(c, "scale", Vector2(1.06, 1.06), 0.08)
	tw.tween_property(c, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func shake(c: Control) -> void:
	var x := c.position.x
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	for k in 4:
		tw.tween_property(c, "position:x", x + (8 if k % 2 == 0 else -8), 0.04)
	tw.tween_property(c, "position:x", x, 0.04)
	Sfx.play("denied", 1.0, -4.0)

## Kleine Pip-Anzeige ●●○○○
func pips(level: int, max_level: int) -> String:
	return "●".repeat(level) + "○".repeat(max_level - level)

func card_panel(min_size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	p.add_theme_stylebox_override("panel", UIKit.sbox("container_cream", 10))
	return p

func scroll_grid(columns: int, h_sep: int = 12, v_sep: int = 12) -> GridContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.custom_minimum_size = Vector2(0, window_size.y - 330.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(sc)
	var g := GridContainer.new()
	g.columns = columns
	g.add_theme_constant_override("h_separation", h_sep)
	g.add_theme_constant_override("v_separation", v_sep)
	sc.add_child(g)
	return g
