class_name SettingsScreen
extends Control
## "Hausordnung & technische Dienstanweisungen" im Notizbuch-Look: Lautstärken, Barrierefreiheit, Tastenbelegung.

signal closed

var _rebind_action := ""
var _rebind_btns := {}
var _motion_btn: Button

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dim(0.7))
	var nb := UIKit.notebook("Hausordnung & Dienstanweisungen", Vector2(900, 670))
	nb.root.position = Vector2(190, 25)
	add_child(nb.root)
	var v: VBoxContainer = nb.content
	v.add_theme_constant_override("separation", 6)
	v.add_child(_section("§1  Lautstärke – der Rektor spricht immer am lautesten"))
	for k in [["master", "Gesamt"], ["music", "Musik"], ["sfx", "Effekte"], ["voice", "Durchsagen"]]:
		_slider(v, k[1], k[0], 0.0, 1.0)
	v.add_child(_section("§2  Barrierefreiheit"))
	_slider(v, "Screen-Shake", "shake", 0.0, 1.5)
	_slider(v, "UI-Skalierung", "ui_scale", 0.8, 1.4)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 12)
	var ml := UIKit.label("Reduzierte Bildschirmbewegung (kein Shake, Hit-Stop, Zeitlupe)", 16, Color("5a2d0c"))
	ml.custom_minimum_size = Vector2(560, 0)
	mrow.add_child(ml)
	_motion_btn = UIKit.button("", Vector2(110, 38), 16, Color("c8f0b8"))
	_motion_btn.pressed.connect(func():
		Game.settings.reduced_motion = not Game.settings.reduced_motion
		Game.save_settings()
		_update_motion())
	mrow.add_child(_motion_btn)
	v.add_child(mrow)
	_update_motion()
	v.add_child(_section("§3  Tastenbelegung (anklicken, dann neue Taste drücken)"))
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for a in Game.ACTIONS:
		var l := UIKit.label(Game.ACTIONS[a], 15, UIKit.INK)
		l.custom_minimum_size = Vector2(100, 0)
		grid.add_child(l)
		var b := UIKit.button(Game.key_label(a), Vector2(100, 34), 15, Color("f7efc8"))
		b.pressed.connect(func():
			_rebind_action = a
			b.text = "…drücken…")
		_rebind_btns[a] = b
		grid.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var close := UIKit.button("Zur Kenntnis genommen", Vector2(340, 58), 22, Color("c8f0b8"))
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close.pressed.connect(func():
		Game.save_settings()
		closed.emit())
	v.add_child(close)

func _section(text: String) -> Control:
	var l := UIKit.label(text, 18, UIKit.RED)
	return l

func _update_motion() -> void:
	var on: bool = Game.settings.reduced_motion
	_motion_btn.text = "An" if on else "Aus"
	_motion_btn.add_theme_stylebox_override("normal", UIKit.sbox("btn_green" if on else "btn_red", 8))

func _slider(parent: Control, text: String, key: String, mn: float, mx: float) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	parent.add_child(h)
	var l := UIKit.label(text, 17, Color("5a2d0c"))
	l.custom_minimum_size = Vector2(170, 0)
	h.add_child(l)
	var s := HSlider.new()
	s.min_value = mn
	s.max_value = mx
	s.step = 0.01
	s.custom_minimum_size = Vector2(430, 28)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.value = Game.settings.get(key, 1.0)
	var val := UIKit.label("%d %%" % int(round(s.value * 100.0)), 16, UIKit.NAVY)
	val.custom_minimum_size = Vector2(60, 0)
	s.value_changed.connect(func(x: float):
		Game.settings[key] = x
		val.text = "%d %%" % int(round(x * 100.0))
		if key == "ui_scale":
			get_tree().root.content_scale_factor = x
		Sfx.apply_volumes())
	s.drag_ended.connect(func(_c): Sfx.play("click"))
	h.add_child(s)
	h.add_child(val)

func _input(event: InputEvent) -> void:
	if not visible or _rebind_action == "":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode != KEY_ESCAPE:
			Game.rebind(_rebind_action, event)
		_rebind_btns[_rebind_action].text = Game.key_label(_rebind_action)
		_rebind_action = ""
		get_viewport().set_input_as_handled()
