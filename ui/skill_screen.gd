class_name SkillScreen
extends HubModal
## Alte Tafel: permanenter Skilltree, bezahlt mit Fehlstunden-Pässen.

var _grid: GridContainer

func _init() -> void:
	title = "Alte Tafel – Nachhilfe"
	window_size = Vector2(1040, 640)

func build() -> void:
	var sub := UIKit.label("Gib deine Fehlstunden-Pässe aus: Diese Verbesserungen gelten für jeden Run.", 16, Color("5a2d0c"))
	content.add_child(sub)
	_grid = scroll_grid(2)

func open() -> void:
	_fill()
	super.open()

func _fill() -> void:
	for c in _grid.get_children():
		c.queue_free()
	for id in Db.skills:
		_grid.add_child(_card(id))

func _card(id: String) -> Control:
	var s: Dictionary = Db.skills[id]
	var lvl := Save.skill_level(id)
	var maxed: bool = lvl >= s.max_level
	var p := card_panel(Vector2(440, 112))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(UIKit.icon(s.icon, Vector2(56, 56)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UIKit.label(s.name, 19, UIKit.NAVY))
	var d := UIKit.label(s.desc, 13, UIKit.INK)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(250, 0)
	v.add_child(d)
	v.add_child(UIKit.label(pips(lvl, s.max_level), 15, Color("c07a10")))
	var b: Button
	if maxed:
		b = UIKit.button("Max", Vector2(70, 40), 16, Color("c8f0b8"))
		b.disabled = true
	else:
		var cost := Save.skill_cost(id)
		b = UIKit.button("%d" % cost, Vector2(70, 40), 18, Color("c8f0b8") if Save.data.passes >= cost else Color("f0c8c8"))
		b.pressed.connect(func():
			if Save.buy_skill(id):
				Sfx.play("levelup", 1.1, -4.0)
				Juice.shake(0.15)
				refresh()
				var old := _grid.get_children()
				_fill()
				for c in _grid.get_children():
					if c.get_index() == Db.skills.keys().find(id):
						pulse(c)
			else:
				shake(p))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(b)
	return p
