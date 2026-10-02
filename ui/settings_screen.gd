class_name SettingsScreen
extends Control
## "Hausordnung & technische Dienstanweisungen": Lautstärken, Barrierefreiheit, Tastenbelegung.

signal closed

var _rebind_action := ""
var _rebind_btns := {}

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dim(0.7))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, Color("5a4630"), 5, 8, 20))
	panel.position = Vector2(240, 40)
	panel.custom_minimum_size = Vector2(800, 640)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	v.add_child(UIKit.label("Hausordnung & technische Dienstanweisungen", 28, UIKit.NAVY))
	v.add_child(UIKit.label("§1 Lautstärke: Der Rektor spricht immer am lautesten.", 14, UIKit.RED))
	for k in [["master", "Gesamt"], ["music", "Musik"], ["sfx", "Effekte"], ["voice", "Durchsagen"]]:
		_slider(v, k[1], k[0], 0.0, 1.0)
	v.add_child(UIKit.label("§2 Barrierefreiheit", 18, UIKit.RED))
	_slider(v, "Screen-Shake", "shake", 0.0, 1.5)
	_slider(v, "UI-Skalierung", "ui_scale", 0.8, 1.4)
	var cb := CheckBox.new()
	cb.text = "Reduzierte Bildschirmbewegung (kein Shake, Hit-Stop, Zeitlupe)"
	cb.add_theme_color_override("font_color", UIKit.INK)
	cb.add_theme_color_override("font_hover_color", UIKit.INK)
	cb.add_theme_color_override("font_pressed_color", UIKit.INK)
	cb.add_theme_font_size_override("font_size", 16)
	cb.button_pressed = Game.settings.reduced_motion
	cb.toggled.connect(func(on: bool):
		Game.settings.reduced_motion = on
		Game.save_settings())
	v.add_child(cb)
	v.add_child(UIKit.label("§3 Tastenbelegung (Klicken, dann neue Taste drücken)", 18, UIKit.RED))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for a in Game.ACTIONS:
		grid.add_child(UIKit.label(Game.ACTIONS[a], 16))
		var b := UIKit.button(Game.key_label(a), Vector2(130, 34), 16)
		b.pressed.connect(func():
			_rebind_action = a
			b.text = "…drücken…")
		_rebind_btns[a] = b
		grid.add_child(b)
	var close := UIKit.button("Zur Kenntnis genommen", Vector2(320, 56), 22, Color("c8f0b8"))
	close.pressed.connect(func():
		Game.save_settings()
		closed.emit())
	v.add_child(close)

func _slider(parent: Control, text: String, key: String, mn: float, mx: float) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	parent.add_child(h)
	var l := UIKit.label(text, 17)
	l.custom_minimum_size = Vector2(150, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.01
	s.custom_minimum_size = Vector2(420, 24)
	s.value = Game.settings.get(key, 1.0)
	s.value_changed.connect(func(val: float):
		Game.settings[key] = val
		if key == "ui_scale":
			get_tree().root.content_scale_factor = val
		Sfx.apply_volumes())
	s.drag_ended.connect(func(_c): Sfx.play("click"))
	h.add_child(s)

func _input(event: InputEvent) -> void:
	if not visible or _rebind_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != KEY_ESCAPE:
			Game.rebind(_rebind_action, event)
		_rebind_btns[_rebind_action].text = Game.key_label(_rebind_action)
		_rebind_action = ""
		get_viewport().set_input_as_handled()
