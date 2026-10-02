class_name PauseScreen
extends Control
## Pausemenü.

signal resume_pressed
signal settings_pressed
signal quit_to_menu_pressed

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dim(0.65))
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(UIKit.PAPER, Color("5a4630"), 5, 8, 24))
	panel.position = Vector2(440, 150)
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	v.add_child(UIKit.label("Stunde unterbrochen", 36, UIKit.NAVY, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIKit.label("Der Rektor macht eine Durchsage…", 16, UIKit.RED, HORIZONTAL_ALIGNMENT_CENTER))
	var b1 := UIKit.button("Weiter lernen", Vector2(360, 58), 24, Color("c8f0b8"))
	var b2 := UIKit.button("Hausordnung", Vector2(360, 52), 22)
	var b3 := UIKit.button("Zum Sekretariat (Abbrechen)", Vector2(360, 52), 20, Color("f0c8c8"))
	b1.pressed.connect(func(): resume_pressed.emit())
	b2.pressed.connect(func(): settings_pressed.emit())
	b3.pressed.connect(func(): quit_to_menu_pressed.emit())
	for b in [b1, b2, b3]:
		v.add_child(b)
	visibility_changed.connect(func():
		if visible:
			UIKit.pop_in(panel))
