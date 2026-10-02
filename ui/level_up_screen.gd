class_name LevelUpScreen
extends Control
## Klassenarbeits-Bildschirm: Zeit steht still, ein Arbeitsblatt klappt auf, drei Upgrades zur Auswahl.

signal chosen(upgrade_id: String)

var _cards: Array = []
var _options: Array = []
var _locked := false
var _holder: Control
var _title: Label

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dim(0.62))
	_holder = Control.new()
	UIKit.full(_holder)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)

func open() -> void:
	_locked = false
	for c in _holder.get_children():
		c.queue_free()
	_cards.clear()
	# Drei zufällige gültige Upgrades
	var pool: Array = Db.levelup_pool.duplicate()
	if Game.player != null and Game.player.hp >= Game.player.max_hp - 0.5:
		if randf() < 0.7:
			pool.erase("heal")
	pool.shuffle()
	_options = pool.slice(0, 3)
	var sheet := PanelContainer.new()
	sheet.add_theme_stylebox_override("panel", UIKit.box(Color("fbf6e4"), Color("5a4630"), 5, 6, 18))
	sheet.position = Vector2(150, 50)
	sheet.custom_minimum_size = Vector2(980, 620)
	_holder.add_child(sheet)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	sheet.add_child(v)
	_title = UIKit.label("Klassenarbeit – Stufe %d erreicht!" % Game.level, 36, UIKit.NAVY)
	v.add_child(_title)
	v.add_child(UIKit.label("Aufgabe 1: Welche Verbesserung ist richtig? (Taste 1-3 oder Klick)", 18, UIKit.INK))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	v.add_child(row)
	for i in _options.size():
		var u: UpgradeData = Db.upgrades[_options[i]]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(290, 400)
		card.add_theme_stylebox_override("panel", UIKit.box(Color("ffffff"), Color("22305c"), 4, 8, 14))
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 10)
		card.add_child(cv)
		cv.add_child(UIKit.label("%s)" % "ABC"[i], 40, UIKit.RED))
		var ic := UIKit.icon(u.icon, Vector2(120, 120))
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cv.add_child(ic)
		cv.add_child(UIKit.label(u.display_name, 24, UIKit.NAVY, HORIZONTAL_ALIGNMENT_CENTER))
		var d := UIKit.label(u.desc, 18, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(260, 0)
		cv.add_child(d)
		var sj := HBoxContainer.new()
		sj.alignment = BoxContainer.ALIGNMENT_CENTER
		var si := UIKit.icon(Db.subject_icon(u.subject), Vector2(22, 22))
		sj.add_child(si)
		sj.add_child(UIKit.label(u.subject if u.subject != "" else "Allgemein", 14, Color(0.4, 0.4, 0.5)))
		cv.add_child(sj)
		row.add_child(card)
		_cards.append(card)
		card.gui_input.connect(func(ev: InputEvent):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_pick(i))
		card.mouse_entered.connect(func():
			if not _locked:
				Sfx.play("hover", 1.0, -10.0)
				create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(card, "scale", Vector2(1.04, 1.04), 0.1))
		card.mouse_exited.connect(func():
			if not _locked:
				create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(card, "scale", Vector2.ONE, 0.1))
	# Einklappen des Arbeitsblattes
	await get_tree().process_frame
	for i in _cards.size():
		var c: Control = _cards[i]
		c.pivot_offset = c.size * 0.5
	sheet.pivot_offset = Vector2(490, 0)
	sheet.scale = Vector2(1.0, 0.05)
	var tw := sheet.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(sheet, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("levelup")
	for i in _cards.size():
		UIKit.pop_in(_cards[i], 0.18 + 0.09 * i)

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or _locked:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var idx := -1
		match event.keycode:
			KEY_1, KEY_KP_1: idx = 0
			KEY_2, KEY_KP_2: idx = 1
			KEY_3, KEY_KP_3: idx = 2
		if idx >= 0 and idx < _options.size():
			_pick(idx)
			get_viewport().set_input_as_handled()

func _pick(i: int) -> void:
	if _locked:
		return
	_locked = true
	# Gewählte Karte: Haken + Stempel; andere: Kommentar des Lehrers
	for k in _cards.size():
		var card: Control = _cards[k]
		var uk: UpgradeData = Db.upgrades[_options[k]]
		if k == i:
			var ok := UIKit.stamp("Bestanden!", UIKit.GREEN, 38, -10.0)
			card.add_child(ok)
			ok.reset_size()
			ok.position = Vector2(30, 250)
			UIKit.slam_stamp(ok, 0.0)
			create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(card, "scale", Vector2(1.08, 1.08), 0.12)
			card.add_theme_stylebox_override("panel", UIKit.box(Color("e4ffe0"), UIKit.GREEN, 6, 8, 14))
		else:
			var rm := UIKit.label(uk.remark, 24, UIKit.RED)
			rm.rotation = deg_to_rad(-8.0)
			rm.position = Vector2(30, 250)
			card.add_child(rm)
			card.modulate = Color(0.7, 0.7, 0.7)
			create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(card, "scale", Vector2(0.94, 0.94), 0.12)
	Sfx.play("stamp")
	Juice.shake(0.2)
	var id: String = _options[i]
	get_tree().create_timer(1.0, true).timeout.connect(func(): chosen.emit(id))
