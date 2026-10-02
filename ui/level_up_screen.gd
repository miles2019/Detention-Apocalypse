class_name LevelUpScreen
extends Control
## Klassenarbeits-Bildschirm (Notizbuch-Look): Zeit steht still, drei Upgrades zur Auswahl (Taste 1-3 oder Klick).

signal chosen(upgrade_id: String)

var _cards: Array = []
var _options: Array = []
var _locked := false
var _holder: Control
var _glow: TextureRect

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
	var pool: Array = Db.levelup_pool.duplicate()
	if Game.player != null and Game.player.hp >= Game.player.max_hp - 0.5:
		if randf() < 0.7:
			pool.erase("heal")
	pool.shuffle()
	_options = pool.slice(0, 3)
	# Strahlenkranz hinter dem Blatt (Pack-Effekt), dreht sich langsam
	_glow = TextureRect.new()
	_glow.texture = Db.tex("res://assets/ui/Effects/effect_yellow.png")
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.size = Vector2(900, 900)
	_glow.position = Vector2(190, -90)
	_glow.pivot_offset = Vector2(450, 450)
	_glow.modulate = Color(1, 1, 1, 0.35)
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_holder.add_child(_glow)
	var nb := UIKit.notebook("Klassenarbeit – Stufe %d erreicht!" % Game.level, Vector2(1040, 640))
	var sheet: Control = nb.root
	sheet.position = Vector2(120, 40)
	_holder.add_child(sheet)
	var v: VBoxContainer = nb.content
	v.add_child(UIKit.label("Aufgabe 1: Welche Verbesserung ist richtig?  (Taste 1-3 oder Klick)", 18, Color("5a2d0c"), HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	for i in _options.size():
		var u: UpgradeData = Db.upgrades[_options[i]]
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(296, 410)
		var csb := UIKit.sbox_new("card_cream", 12)
		csb.content_margin_top = 4.0
		card.add_theme_stylebox_override("panel", csb)
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 8)
		card.add_child(cv)
		var head := UIKit.label("%s)" % "ABC"[i], 32, Color("7a2a10"), HORIZONTAL_ALIGNMENT_CENTER)
		head.custom_minimum_size = Vector2(0, 44)
		cv.add_child(head)
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", UIKit.sbox("slot_blue", 8))
		slot.custom_minimum_size = Vector2(130, 140)
		slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		slot.add_child(UIKit.icon(u.icon, Vector2(100, 100)))
		cv.add_child(slot)
		cv.add_child(UIKit.label(u.display_name, 23, UIKit.NAVY, HORIZONTAL_ALIGNMENT_CENTER))
		var d := UIKit.label(u.desc, 17, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(250, 0)
		cv.add_child(d)
		var sj := HBoxContainer.new()
		sj.alignment = BoxContainer.ALIGNMENT_CENTER
		sj.add_child(UIKit.icon(Db.subject_icon(u.subject), Vector2(22, 22)))
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
				create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(card, "scale", Vector2(1.05, 1.05), 0.1))
		card.mouse_exited.connect(func():
			if not _locked:
				create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(card, "scale", Vector2.ONE, 0.1))
	await get_tree().process_frame
	for i in _cards.size():
		var c: Control = _cards[i]
		c.pivot_offset = c.size * 0.5
	sheet.pivot_offset = Vector2(520, 0)
	sheet.scale = Vector2(1.0, 0.05)
	var tw := sheet.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(sheet, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("levelup")
	for i in _cards.size():
		UIKit.pop_in(_cards[i], 0.18 + 0.09 * i)

func _process(delta: float) -> void:
	if _glow != null and is_instance_valid(_glow) and visible:
		_glow.rotation += delta * 0.25

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
	for k in _cards.size():
		var card: Control = _cards[k]
		var uk: UpgradeData = Db.upgrades[_options[k]]
		if k == i:
			var ok := UIKit.stamp("Bestanden!", UIKit.GREEN, 38, -10.0)
			card.add_child(ok)
			ok.reset_size()
			ok.position = Vector2(40, 290)
			UIKit.slam_stamp(ok, 0.0)
			create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(card, "scale", Vector2(1.08, 1.08), 0.12)
			var gsb := UIKit.sbox_new("card_cream", 12, Color(0.8, 1.0, 0.8))
			gsb.content_margin_top = 4.0
			card.add_theme_stylebox_override("panel", gsb)
		else:
			var rm := UIKit.label(uk.remark, 24, UIKit.RED)
			rm.rotation = deg_to_rad(-8.0)
			rm.position = Vector2(40, 290)
			card.add_child(rm)
			card.modulate = Color(0.7, 0.7, 0.7)
			create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(card, "scale", Vector2(0.94, 0.94), 0.12)
	Sfx.play("stamp")
	Juice.shake(0.2)
	var id: String = _options[i]
	get_tree().create_timer(1.0, true).timeout.connect(func(): chosen.emit(id))
