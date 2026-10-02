class_name PauseScreen
extends Control
## Pausemenü im Notizbuch-Look.

signal resume_pressed
signal settings_pressed
signal quit_to_menu_pressed

var _quit_btn: Button
var _root: Control
var _info: Label

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dim(0.65))
	var nb := UIKit.notebook("Stunde unterbrochen", Vector2(500, 520))
	_root = nb.root
	_root.position = Vector2(390, 100)
	add_child(_root)
	var v: VBoxContainer = nb.content
	v.add_theme_constant_override("separation", 14)
	v.add_child(UIKit.label("Der Rektor macht eine Durchsage…", 17, UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER))
	var b1 := _btn("Weiter lernen", "adventure", Color("c8f0b8"), 68, 26)
	var b2 := _btn("Hausordnung", "settings", Color("a8c8f8"), 58, 22)
	var b3 := _btn("Run abbrechen", "close", Color("f4b0a8"), 58, 20)
	b1.pressed.connect(func(): resume_pressed.emit())
	b2.pressed.connect(func(): settings_pressed.emit())
	b3.pressed.connect(func(): quit_to_menu_pressed.emit())
	_quit_btn = b3
	for b in [b1, b2, b3]:
		v.add_child(b)
	_info = UIKit.label("", 15, Color("5a2d0c"), HORIZONTAL_ALIGNMENT_CENTER)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(380, 0)
	v.add_child(_info)
	visibility_changed.connect(func():
		if visible:
			_update_info()
			UIKit.pop_in(_root))

func _btn(text: String, icon_name: String, col: Color, h: float, fs: int) -> Button:
	var b := UIKit.button(text, Vector2(390, h), fs, col)
	b.icon = UIKit.tex_icon(icon_name)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_constant_override("icon_max_width", int(h * 0.55))
	b.add_theme_constant_override("h_separation", 14)
	return b

func _update_info() -> void:
	if Game.state_before_pause == Game.State.HUB:
		_info.text = "Schulhof – hier kann dir nichts passieren. Fast nichts."
	else:
		_info.text = "Welle %d  ·  Stufe %d  ·  %d besiegt  ·  %d:%02d" % [maxi(1, Game.wave), Game.level, Game.stats.kills, int(Game.stats.time) / 60, int(Game.stats.time) % 60]

func set_quit_text(t: String) -> void:
	if _quit_btn:
		_quit_btn.text = t
