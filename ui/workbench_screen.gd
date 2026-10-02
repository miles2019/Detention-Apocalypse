class_name WorkbenchScreen
extends HubModal
## Werkbank: Startwaffen freischalten/wählen und Rezeptbuch der Evolutionen.

var _tab := "weapons"
var _tabs: HBoxContainer
var _body: VBoxContainer

func _init() -> void:
	title = "Werkbank"
	window_size = Vector2(1060, 650)

func build() -> void:
	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 10)
	content.add_child(_tabs)
	var b1 := UIKit.button("Startwaffen", Vector2(200, 44), 18, Color("f7efc8"))
	var b2 := UIKit.button("Rezeptbuch (Evolutionen)", Vector2(280, 44), 18, Color("f7efc8"))
	b1.pressed.connect(func(): _set_tab("weapons"))
	b2.pressed.connect(func(): _set_tab("recipes"))
	_tabs.add_child(b1)
	_tabs.add_child(b2)
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_body)

func open() -> void:
	_set_tab(_tab)
	super.open()

func _set_tab(t: String) -> void:
	_tab = t
	for c in _body.get_children():
		c.queue_free()
	if t == "weapons":
		_weapons()
	else:
		_recipes()
	refresh()

func _weapons() -> void:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, window_size.y - 290.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(sc)
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	sc.add_child(g)
	var ids: Array = []
	for id in Db.weapons:
		if not Db.weapons[id].evolution:
			ids.append(id)
	for id in ids:
		g.add_child(_weapon_card(id))

func _weapon_card(id: String) -> Control:
	var wd: WeaponData = Db.weapons[id]
	var unlocked := Save.weapon_unlocked(id)
	var active: bool = Save.data.start_weapon == id
	var p := card_panel(Vector2(236, 168))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var ic := UIKit.icon(wd.icon, Vector2(64, 56))
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if not unlocked:
		ic.modulate = Color(0.25, 0.25, 0.3)
	v.add_child(ic)
	v.add_child(UIKit.label(wd.display_name, 16, UIKit.NAVY, HORIZONTAL_ALIGNMENT_CENTER))
	var sj := UIKit.label(wd.subject, 12, Db.subject_color(wd.subject).darkened(0.35), HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(sj)
	var b: Button
	if active:
		b = UIKit.button("Aktiv", Vector2(150, 36), 16, Color("c8f0b8"))
		b.disabled = true
	elif unlocked:
		b = UIKit.button("Wählen", Vector2(150, 36), 16, Color("f7efc8"))
		b.pressed.connect(func():
			Save.data.start_weapon = id
			Save.save_game()
			Sfx.play("stamp", 1.2, -6.0)
			_set_tab("weapons"))
	else:
		var cost: int = Db.start_weapon_cost.get(id, 10)
		b = UIKit.button("%d Pässe" % cost, Vector2(150, 36), 16, Color("c8f0b8") if Save.data.passes >= cost else Color("f0c8c8"))
		b.pressed.connect(func():
			if Save.spend_passes(cost):
				Save.unlock_weapon(id)
				Sfx.play("levelup", 1.2, -4.0)
				Juice.shake(0.15)
				_set_tab("weapons")
			else:
				shake(p))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	return p

func _recipes() -> void:
	var intro := UIKit.label("Zwei passende Waffen auf Stufe 2 verschmelzen im Kiosk zu einer Evolution. Entdeckte Rezepte werden hier eingetragen.", 15, Color("5a2d0c"))
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(900, 0)
	_body.add_child(intro)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, window_size.y - 330.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 6)
	sc.add_child(list)
	for r in Db.evolutions:
		list.add_child(_recipe_row(r))

func _recipe_row(r: Dictionary) -> Control:
	var found: bool = Save.data.archive.evolutions.has(r.result)
	var p := card_panel(Vector2(900, 70))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	for id in [r.a, r.b]:
		var seen: bool = Save.data.archive.weapons.has(id)
		var ic := UIKit.icon(Db.weapons[id].icon, Vector2(48, 48))
		if not seen:
			ic.modulate = Color(0.2, 0.2, 0.25)
		h.add_child(ic)
		h.add_child(UIKit.label(Db.weapons[id].display_name if seen else "???", 15, UIKit.INK))
		if id == r.a:
			h.add_child(UIKit.label("+", 26, UIKit.RED))
	h.add_child(UIKit.label("=", 26, UIKit.RED))
	var res: WeaponData = Db.weapons[r.result]
	var ri := UIKit.icon(res.icon, Vector2(52, 52))
	if not found:
		ri.modulate = Color(0.1, 0.1, 0.15)
	h.add_child(ri)
	var vb := VBoxContainer.new()
	h.add_child(vb)
	vb.add_child(UIKit.label(res.display_name if found else "Unentdeckte Evolution", 17, UIKit.NAVY if found else Color(0.4, 0.4, 0.45)))
	if found:
		var d := UIKit.label(res.desc.replace("EVOLUTION: ", ""), 12, UIKit.INK)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(330, 0)
		vb.add_child(d)
	return p
