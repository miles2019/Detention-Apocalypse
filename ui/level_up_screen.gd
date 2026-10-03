class_name LevelUpScreen
extends Control
## Klassenarbeits-Bildschirm (Notizbuch-Look): Zeit steht still, Upgrades zur Auswahl (Taste 1-4 oder Klick).
## Pro Run begrenzt: Neu würfeln (R), Bannen (Option fliegt für den Run raus) und Merken (Option kommt beim nächsten Mal sicher wieder).

signal chosen(upgrade_id: String)

var _cards: Array = []
var _options: Array = []
var _locked := false
var _holder: Control
var _glow: TextureRect
var _sheet: Control

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(UIKit.dim(0.62))
	_holder = Control.new()
	UIKit.full(_holder)
	_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_holder)

func _count() -> int:
	return int(Game.player.char_data.options) if Game.player != null else 3

func _pool() -> Array:
	var pool: Array = []
	for id in Db.levelup_pool:
		if not Game.banned.has(id):
			pool.append(id)
	return pool

func open() -> void:
	_locked = false
	var pool := _pool()
	if Game.player != null and Game.player.hp >= Game.player.max_hp - 0.5:
		if randf() < 0.7 and Game.locked_upgrade != "heal":
			pool.erase("heal")
	pool.shuffle()
	_options = []
	# gemerkte Option erscheint garantiert
	if Game.locked_upgrade != "" and pool.has(Game.locked_upgrade):
		_options.append(Game.locked_upgrade)
		pool.erase(Game.locked_upgrade)
	Game.locked_upgrade = ""
	while _options.size() < _count() and not pool.is_empty():
		_options.append(pool.pop_front())
	_options.shuffle()
	_build(true)
	Sfx.play("levelup")

func _build(animate: bool) -> void:
	for c in _holder.get_children():
		c.queue_free()
	_cards.clear()
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
	var nb := UIKit.notebook("Klassenarbeit – Stufe %d erreicht!" % Game.level, Vector2(1060, 680))
	var sheet: Control = nb.root
	_sheet = sheet
	sheet.position = Vector2(110, 20)
	_holder.add_child(sheet)
	var v: VBoxContainer = nb.content
	v.add_theme_constant_override("separation", 8)
	var n := _options.size()
	v.add_child(UIKit.label("Aufgabe 1: Welche Verbesserung ist richtig?  (Taste 1-%d oder Klick)" % n, 17, Color("5a2d0c"), HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16 if n <= 3 else 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	var cw := 296.0 if n <= 3 else 236.0
	for i in n:
		var card := _make_card(i, cw)
		row.add_child(card)
		_cards.append(card)
	# Neu würfeln
	var bottom := HBoxContainer.new()
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	bottom.add_theme_constant_override("separation", 18)
	v.add_child(bottom)
	var rr := UIKit.button("Neu würfeln [R]  (%d übrig)" % Game.lv_rerolls, Vector2(330, 46), 17, Color("f4b0d0"))
	rr.disabled = Game.lv_rerolls <= 0
	rr.pressed.connect(_reroll)
	UIKit.tip(rr, "Radiergummi", "Würfelt alle nicht gemerkten Antworten neu aus.\nPro Run begrenzt.")
	bottom.add_child(rr)
	bottom.add_child(UIKit.label("Bannen: %d   ·   Merken: %d" % [Game.lv_bans, Game.lv_locks], 15, Color("5a2d0c")))
	await get_tree().process_frame
	for i in _cards.size():
		var c: Control = _cards[i]
		if is_instance_valid(c):
			c.pivot_offset = c.size * 0.5
	if animate and is_instance_valid(sheet):
		sheet.pivot_offset = Vector2(530, 0)
		sheet.scale = Vector2(1.0, 0.05)
		var tw := sheet.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_property(sheet, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		for i in _cards.size():
			if is_instance_valid(_cards[i]):
				UIKit.pop_in(_cards[i], 0.18 + 0.09 * i)

func _make_card(i: int, cw: float) -> Control:
	var id: String = _options[i]
	var u: UpgradeData = Db.upgrades[id]
	var pl = Game.player
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(cw, 412)
	var marked: bool = Game.locked_upgrade == id
	var csb := UIKit.sbox_new("card_cream", 12, Color(1.0, 0.95, 0.7) if marked else Color.WHITE)
	csb.content_margin_top = 4.0
	card.add_theme_stylebox_override("panel", csb)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 5)
	card.add_child(cv)
	var head := UIKit.label("%s)" % "ABCD"[i], 30, Color("7a2a10"), HORIZONTAL_ALIGNMENT_CENTER)
	head.custom_minimum_size = Vector2(0, 40)
	cv.add_child(head)
	var slot := PanelContainer.new()
	slot.add_theme_stylebox_override("panel", UIKit.sbox("slot_blue", 8))
	slot.custom_minimum_size = Vector2(112, 116)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	slot.add_child(UIKit.icon(u.icon, Vector2(84, 84)))
	cv.add_child(slot)
	var nm := UIKit.label(u.display_name, 21 if cw > 250.0 else 17, UIKit.NAVY, HORIZONTAL_ALIGNMENT_CENTER)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nm.custom_minimum_size = Vector2(cw - 44.0, 0)
	cv.add_child(nm)
	var d := UIKit.label(u.desc, 15, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(cw - 44.0, 0)
	cv.add_child(d)
	var change := Tips.upgrade_change(id, pl)
	if change != "":
		var ch := UIKit.label(change, 13, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
		ch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch.custom_minimum_size = Vector2(cw - 44.0, 0)
		cv.add_child(ch)
	var sj := HBoxContainer.new()
	sj.alignment = BoxContainer.ALIGNMENT_CENTER
	sj.add_child(UIKit.icon(Db.subject_icon(u.subject), Vector2(22, 22)))
	sj.add_child(UIKit.label(u.subject if u.subject != "" else "Allgemein", 14, Color(0.4, 0.4, 0.5)))
	cv.add_child(sj)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cv.add_child(spacer)
	# Bannen / Merken
	var acts := HBoxContainer.new()
	acts.alignment = BoxContainer.ALIGNMENT_CENTER
	acts.add_theme_constant_override("separation", 6)
	cv.add_child(acts)
	var bw := (cw - 54.0) * 0.5
	var ban := UIKit.button("Bannen", Vector2(bw, 36), 13, Color("f4b0a8"))
	ban.disabled = Game.lv_bans <= 0 or _pool().size() <= _count() + 1
	ban.pressed.connect(func(): _ban(i))
	UIKit.tip(ban, "Bannen", "Diese Antwort erscheint in diesem Run nie wieder und wird sofort ersetzt.")
	acts.add_child(ban)
	var lock := UIKit.button("Gemerkt" if marked else "Merken", Vector2(bw, 36), 13, Color("ffe08a") if marked else Color("a8c8f8"))
	lock.disabled = not marked and Game.lv_locks <= 0
	lock.pressed.connect(func(): _lock(i))
	UIKit.tip(lock, "Merken", "Diese Antwort erscheint bei der nächsten Klassenarbeit garantiert wieder – nimm jetzt eine andere.")
	acts.add_child(lock)
	UIKit.tip(card, u.display_name, Tips.item(u, pl.items.get(id, 0) if pl != null else 0, pl) + ("\n\n" + change if change != "" else ""))
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
	return card

func _replacement(exclude: Array) -> String:
	var pool := _pool()
	for id in exclude:
		pool.erase(id)
	pool.shuffle()
	return pool[0] if not pool.is_empty() else ""

func _reroll() -> void:
	if _locked or Game.lv_rerolls <= 0:
		return
	Game.lv_rerolls -= 1
	Sfx.play("erase")
	var pool := _pool()
	pool.shuffle()
	var keep: String = Game.locked_upgrade
	var out: Array = []
	if keep != "" and _options.has(keep):
		out.append(keep)
		pool.erase(keep)
	# möglichst andere Antworten als vorher
	var fresh: Array = pool.filter(func(id): return not _options.has(id))
	var old: Array = pool.filter(func(id): return _options.has(id))
	fresh.append_array(old)
	while out.size() < _count() and not fresh.is_empty():
		out.append(fresh.pop_front())
	_options = out
	_build(false)

func _ban(i: int) -> void:
	if _locked or Game.lv_bans <= 0 or i >= _options.size():
		return
	var id: String = _options[i]
	Game.lv_bans -= 1
	Game.banned.append(id)
	if Game.locked_upgrade == id:
		Game.locked_upgrade = ""
		Game.lv_locks += 1
	Sfx.play("denied", 1.2, -4.0)
	var rep := _replacement(_options)
	if rep != "":
		_options[i] = rep
	else:
		_options.remove_at(i)
	_build(false)

func _lock(i: int) -> void:
	if _locked or i >= _options.size():
		return
	var id: String = _options[i]
	if Game.locked_upgrade == id:
		Game.locked_upgrade = ""
		Game.lv_locks += 1
	elif Game.lv_locks > 0:
		if Game.locked_upgrade != "":
			Game.lv_locks += 1
		Game.locked_upgrade = id
		Game.lv_locks -= 1
	Sfx.play("stamp", 1.4, -6.0)
	_build(false)

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
			KEY_4, KEY_KP_4: idx = 3
			KEY_R:
				_reroll()
				get_viewport().set_input_as_handled()
				return
		if idx >= 0 and idx < _options.size():
			_pick(idx)
			get_viewport().set_input_as_handled()

func _pick(i: int) -> void:
	if _locked or i >= _options.size() or i >= _cards.size():
		return
	_locked = true
	var id: String = _options[i]
	# die gewählte Antwort muss nicht gemerkt bleiben
	if Game.locked_upgrade == id:
		Game.locked_upgrade = ""
		Game.lv_locks += 1
	for k in _cards.size():
		var card: Control = _cards[k]
		var uk: UpgradeData = Db.upgrades[_options[k]]
		if k == i:
			var ok := UIKit.stamp("Bestanden!", UIKit.GREEN, 34, -10.0)
			card.add_child(ok)
			ok.reset_size()
			ok.position = Vector2(30, 250)
			UIKit.slam_stamp(ok, 0.0)
			create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(card, "scale", Vector2(1.08, 1.08), 0.12)
			var gsb := UIKit.sbox_new("card_cream", 12, Color(0.8, 1.0, 0.8))
			gsb.content_margin_top = 4.0
			card.add_theme_stylebox_override("panel", gsb)
		else:
			var rm := UIKit.label(uk.remark, 22, UIKit.RED)
			rm.rotation = deg_to_rad(-8.0)
			rm.position = Vector2(30, 250)
			card.add_child(rm)
			card.modulate = Color(0.7, 0.7, 0.7)
			create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(card, "scale", Vector2(0.94, 0.94), 0.12)
	Sfx.play("stamp")
	Juice.shake(0.2)
	get_tree().create_timer(1.0, true).timeout.connect(func(): chosen.emit(id))
