class_name AGScreen
extends HubModal
## AG-Schaukasten: Begleiter mit Nachsitzen-Marken freischalten und auswählen.

var _row: HBoxContainer

func _init() -> void:
	title = "AG-Schaukasten"
	window_size = Vector2(1000, 600)

func build() -> void:
	var sub := UIKit.label("Arbeitsgemeinschaften: Jede AG schickt einen kleinen Begleiter mit in den Run (nur einer gleichzeitig).", 16, Color("5a2d0c"))
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(880, 0)
	content.add_child(sub)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 14)
	content.add_child(_row)

func open() -> void:
	_fill()
	super.open()

func _fill() -> void:
	for c in _row.get_children():
		c.queue_free()
	for id in Db.ags:
		_row.add_child(_card(id))

func _card(id: String) -> Control:
	var a: Dictionary = Db.ags[id]
	var unlocked := Save.ag_unlocked(id)
	var active: bool = Save.data.ag_selected == id
	var p := card_panel(Vector2(280, 380))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	var tex := UIKit.icon(a.tex, Vector2(150, 130))
	tex.modulate = a.tint if unlocked else Color(0.15, 0.15, 0.2)
	tex.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(tex)
	v.add_child(UIKit.label(a.name, 22, UIKit.NAVY, HORIZONTAL_ALIGNMENT_CENTER))
	var d := UIKit.label(a.desc, 14, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(240, 70)
	v.add_child(d)
	var b: Button
	if active:
		b = UIKit.button("Aktiv – abwählen", Vector2(220, 46), 16, Color("c8f0b8"))
		b.pressed.connect(func():
			Save.data.ag_selected = ""
			Save.save_game()
			Sfx.play("click")
			_fill())
	elif unlocked:
		b = UIKit.button("Mitnehmen", Vector2(220, 46), 18, Color("f7efc8"))
		b.pressed.connect(func():
			Save.data.ag_selected = id
			Save.save_game()
			Sfx.play("stamp", 1.2, -6.0)
			_fill())
	else:
		b = UIKit.button("%d Marken" % a.cost, Vector2(220, 46), 18, Color("c8f0b8") if Save.data.marken >= a.cost else Color("f0c8c8"))
		b.pressed.connect(func():
			if Save.spend_marken(a.cost):
				Save.data.ags_unlocked.append(id)
				Save.data.ag_selected = id
				Save.save_game()
				Sfx.play("rare", 1.0, -4.0)
				Juice.shake(0.3)
				refresh()
				_fill()
			else:
				shake(p))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	return p
