class_name ShopScreen
extends Control
## Pausenkiosk: vier Angebotskarten, Kaufen, Reroll (Radiergummi), Spind-Übersicht.

signal closed
signal evolution_requested(recipe: Dictionary)

const CARD := Vector2(262, 410)

var _offers: Array = []
var _cards: Array = []
var _rerolls := 0
var _row: HBoxContainer
var _inv: HBoxContainer
var _money: Label
var _reroll_btn: Button
var _title: Label
var _eraser: ColorRect
var _busy := false

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	var banner := Panel.new()
	banner.add_theme_stylebox_override("panel", UIKit.sbox("header_blue", 0))
	banner.position = Vector2(36, 14)
	banner.size = Vector2(700, 76)
	add_child(banner)
	_title = UIKit.label("Pausenkiosk", 40, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
	_title.position = Vector2(0, 8)
	_title.size = Vector2(700, 56)
	banner.add_child(_title)
	var pill := Panel.new()
	pill.add_theme_stylebox_override("panel", UIKit.sbox("panel_black", 6))
	pill.position = Vector2(860, 24)
	pill.size = Vector2(370, 58)
	add_child(pill)
	var coin := UIKit.icon(UIKit.ICON % "coins", Vector2(40, 40))
	coin.position = Vector2(12, 9)
	pill.add_child(coin)
	_money = UIKit.label("", 26, Color(1, 0.9, 0.4), HORIZONTAL_ALIGNMENT_RIGHT, true)
	_money.position = Vector2(60, 10)
	_money.size = Vector2(290, 40)
	pill.add_child(_money)
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 18)
	_row.position = Vector2(50, 92)
	add_child(_row)
	_inv = HBoxContainer.new()
	_inv.add_theme_constant_override("separation", 10)
	_inv.position = Vector2(50, 560)
	add_child(_inv)
	_reroll_btn = UIKit.button("Radiergummi: neu würfeln", Vector2(340, 58), 20, Color("f4b0d0"))
	_reroll_btn.position = Vector2(600, 598)
	_reroll_btn.pressed.connect(_reroll)
	add_child(_reroll_btn)
	var go := UIKit.button("Nächste Stunde", Vector2(280, 68), 28, Color("c8f0b8"))
	go.icon = UIKit.tex_icon("adventure")
	go.expand_icon = true
	go.add_theme_constant_override("icon_max_width", 30)
	go.add_theme_font_size_override("font_size", 25)
	go.position = Vector2(960, 590)
	go.pressed.connect(func():
		if not _busy:
			closed.emit())
	add_child(go)
	_eraser = ColorRect.new()
	_eraser.color = Color("f2a0b8")
	_eraser.size = Vector2(70, 420)
	_eraser.visible = false
	_eraser.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_eraser)
	Game.money_changed.connect(func(_v): _update_money())

func open() -> void:
	_rerolls = 0
	_busy = false
	_title.text = "Pausenkiosk – Welle %d geschafft" % Game.wave
	_roll()
	_build_cards()
	_refresh_inventory()
	_update_money()

func _update_money() -> void:
	_money.text = "%d" % Game.money
	var cost := _reroll_cost()
	_reroll_btn.text = "Radiergummi: neu würfeln (%d)" % cost
	_reroll_btn.disabled = Game.money < cost
	for i in _cards.size():
		_update_card_state(i)

func _reroll_cost() -> int:
	if _rerolls == 0 and Save.bonus("free_reroll") > 0.0:
		return 0
	return 3 + 2 * _rerolls

# ---------------------------------------------------------------- Angebote
func _roll() -> void:
	var pl = Game.player
	_offers.clear()
	var cand: Array = []
	for id in Db.weapons:
		var wd: WeaponData = Db.weapons[id]
		if wd.evolution or not Save.weapon_unlocked(id):
			continue
		var owned: WeaponRunner = pl.get_weapon(id)
		if owned != null and owned.level >= wd.max_level:
			continue
		cand.append(id)
	cand.shuffle()
	# Evolutions-Partner bevorzugen
	var partners: Array = []
	for r in Db.evolutions:
		var a: WeaponRunner = pl.get_weapon(r.a)
		var b: WeaponRunner = pl.get_weapon(r.b)
		if a != null and (b == null or b.level < 2) and cand.has(r.b):
			partners.append(r.b)
		if b != null and (a == null or a.level < 2) and cand.has(r.a):
			partners.append(r.a)
		if a != null and a.level < 2 and cand.has(r.a):
			partners.append(r.a)
		if b != null and b.level < 2 and cand.has(r.b):
			partners.append(r.b)
	var picks: Array = []
	if not partners.is_empty():
		partners.shuffle()
		picks.append(partners[0])
		cand.erase(partners[0])
	while picks.size() < 2 and not cand.is_empty():
		picks.append(cand.pop_front())
	for id in picks:
		var wd: WeaponData = Db.weapons[id]
		var owned: WeaponRunner = pl.get_weapon(id)
		var price := wd.price + (Game.wave - 1)
		if owned != null:
			price = wd.price + owned.level * 4
		price = maxi(1, int(round(float(price) * (1.0 - Save.bonus("discount")))))
		_offers.append({kind = "weapon", id = id, price = price, sold = false})
	var items: Array = []
	for id in Db.upgrades:
		var u: UpgradeData = Db.upgrades[id]
		if u.shop and pl.items.get(id, 0) < 3:
			items.append(id)
	items.shuffle()
	for k in 2:
		if items.is_empty():
			break
		var id: String = items.pop_front()
		var u: UpgradeData = Db.upgrades[id]
		_offers.append({kind = "item", id = id, price = maxi(1, int(round(float(u.price + int(Game.wave / 2)) * (1.0 - Save.bonus("discount"))))), sold = false})

func _build_cards() -> void:
	for c in _row.get_children():
		c.queue_free()
	_cards.clear()
	for i in _offers.size():
		var card := _make_card(i)
		_row.add_child(card)
		_cards.append(card)
	await get_tree().process_frame
	# Einfeder-Animation: Karten fallen von oben ein
	for i in _cards.size():
		var c: Control = _cards[i]
		if not is_instance_valid(c):
			continue
		c.pivot_offset = CARD * 0.5
		var base_y := c.position.y
		c.position.y = base_y - 420.0
		c.modulate.a = 0.0
		var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tw.tween_interval(0.08 * i)
		tw.tween_callback(func(): Sfx.play("click", 0.8 + 0.1 * i, -6.0))
		tw.set_parallel(true)
		tw.tween_property(c, "position:y", base_y, 0.38).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_property(c, "modulate:a", 1.0, 0.1)
	for i in _cards.size():
		_update_card_state(i)

func _make_card(i: int) -> Control:
	var o: Dictionary = _offers[i]
	var card := PanelContainer.new()
	card.custom_minimum_size = CARD
	var csb := UIKit.sbox_new("card_cream", 10)
	csb.content_margin_top = 6.0
	card.add_theme_stylebox_override("panel", csb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var icon_path := ""
	var name := ""
	var desc := ""
	var subject := ""
	var status := ""
	if o.kind == "weapon":
		var wd: WeaponData = Db.weapons[o.id]
		icon_path = wd.icon
		name = wd.display_name
		desc = wd.desc
		subject = wd.subject
		var owned: WeaponRunner = Game.player.get_weapon(o.id)
		status = "NEU" if owned == null else "Stufe %d → %d" % [owned.level, owned.level + 1]
		for r in Db.evolutions:
			if r.a == o.id or r.b == o.id:
				var other: String = r.b if r.a == o.id else r.a
				desc += "\nEvolution: + %s (Stufe 2) = %s" % [Db.weapons[other].display_name, Db.weapons[r.result].display_name]
	else:
		var u: UpgradeData = Db.upgrades[o.id]
		icon_path = u.icon
		name = u.display_name
		desc = u.desc
		subject = u.subject
		status = "Item (x%d)" % (Game.player.items.get(o.id, 0) + 1) if Game.player.items.get(o.id, 0) > 0 else "Item"
	o["status"] = status
	var sj := HBoxContainer.new()
	sj.add_theme_constant_override("separation", 6)
	sj.add_child(UIKit.icon(Db.subject_icon(subject), Vector2(26, 26)))
	sj.add_child(UIKit.label(subject if subject != "" else "Allgemein", 16, Db.subject_color(subject).darkened(0.6)))
	v.add_child(sj)
	var slot := PanelContainer.new()
	slot.add_theme_stylebox_override("panel", UIKit.sbox("slot_blue", 8))
	slot.custom_minimum_size = Vector2(112, 118)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ic := UIKit.icon(icon_path, Vector2(86, 86))
	slot.add_child(ic)
	v.add_child(slot)
	v.add_child(UIKit.label(name, 22, UIKit.NAVY, HORIZONTAL_ALIGNMENT_CENTER))
	var d := UIKit.label(desc, 14, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(236, 66)
	v.add_child(d)
	var st := UIKit.label(status, 16, UIKit.GREEN, HORIZONTAL_ALIGNMENT_CENTER)
	st.name = "Status"
	v.add_child(st)
	var pr := HBoxContainer.new()
	pr.alignment = BoxContainer.ALIGNMENT_CENTER
	pr.add_theme_constant_override("separation", 6)
	pr.add_child(UIKit.icon(Db.i_icon(24), Vector2(30, 30)))
	var pl := UIKit.label(str(o.price), 28, Color("8a6a00"))
	pl.name = "Price"
	pr.add_child(pl)
	v.add_child(pr)
	var b := UIKit.button("Kaufen", Vector2(200, 50), 24, Color("c8f0b8"))
	b.name = "Buy"
	b.pressed.connect(func(): _buy(i))
	v.add_child(b)
	return card

func _update_card_state(i: int) -> void:
	if i >= _cards.size() or not is_instance_valid(_cards[i]):
		return
	var o: Dictionary = _offers[i]
	var card: Control = _cards[i]
	var buy: Button = card.find_child("Buy", true, false)
	var price: Label = card.find_child("Price", true, false)
	var st: Label = card.find_child("Status", true, false)
	if buy == null:
		return
	if o.sold:
		buy.disabled = true
		buy.text = "Verkauft"
		return
	var full: bool = o.kind == "weapon" and not Game.player.has_slot_for(o.id)
	var afford: bool = Game.money >= o.price
	if full:
		st.text = "Spindfächer voll!"
		st.add_theme_color_override("font_color", UIKit.RED)
		buy.disabled = true
	else:
		st.text = o.status
		st.add_theme_color_override("font_color", UIKit.GREEN)
		buy.disabled = false
	# Nicht genug Geld: Preis rot + durchgestrichen (zusätzlich zur Farbe: Text "zu teuer")
	price.add_theme_color_override("font_color", Color("8a6a00") if afford else Color(0.85, 0.1, 0.1))
	price.text = str(o.price) if afford else str(o.price) + " (zu teuer)"
	price.add_theme_font_size_override("font_size", 28 if afford else 18)

func _buy(i: int) -> void:
	if _busy:
		return
	var o: Dictionary = _offers[i]
	var card: Control = _cards[i]
	if o.sold:
		return
	if o.kind == "weapon" and not Game.player.has_slot_for(o.id):
		_deny(card)
		return
	if not Game.spend_money(o.price):
		_deny(card)
		return
	var pl = Game.player
	if o.kind == "weapon":
		pl.equip(o.id)
	else:
		pl.add_item(o.id)
	o.sold = true
	Sfx.play("buy")
	# Karte wird mit einem "Klack" in ein Spindfach geschoben
	var target := _inv.position + Vector2(40 + 80 * minf(pl.weapons.size(), 3), 40)
	card.pivot_offset = CARD * 0.5
	var tw := card.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(card, "scale", Vector2(1.06, 1.06), 0.08)
	tw.set_parallel(true)
	tw.tween_property(card, "global_position", target - CARD * 0.5, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(card, "scale", Vector2(0.15, 0.15), 0.32).set_delay(0.08)
	tw.tween_property(card, "modulate:a", 0.0, 0.1).set_delay(0.34)
	tw.chain().tween_callback(func():
		Sfx.play("locker", 1.5, -8.0)
		_refresh_inventory()
		_flash_slot())
	await get_tree().create_timer(0.55, true).timeout
	if is_instance_valid(card):
		card.modulate = Color(1, 1, 1, 0.35)
		card.scale = Vector2.ONE
		card.global_position = card.global_position
	_update_money()
	var r: Dictionary = pl.check_evolution()
	if not r.is_empty():
		_busy = true
		evolution_requested.emit(r)

func evolution_done() -> void:
	_busy = false
	_refresh_inventory()
	for i in _cards.size():
		_update_card_state(i)

func _deny(card: Control) -> void:
	Sfx.play("denied")
	var tw := card.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	var x := card.position.x
	for k in 4:
		tw.tween_property(card, "position:x", x + (8 if k % 2 == 0 else -8), 0.04)
	tw.tween_property(card, "position:x", x, 0.04)

func _reroll() -> void:
	if _busy or Game.money < _reroll_cost():
		return
	Game.spend_money(_reroll_cost())
	_rerolls += 1
	_busy = true
	Sfx.play("erase")
	# Radiergummi wischt über die Karten
	_eraser.visible = true
	_eraser.position = Vector2(30, 90)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(_eraser, "position:x", 1200.0, 0.45).set_trans(Tween.TRANS_SINE)
	for k in 6:
		var c: Control = _cards[k] if k < _cards.size() else null
		if c != null:
			create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(c, "modulate:a", 0.0, 0.12).set_delay(0.07 * k)
	await tw.finished
	_eraser.visible = false
	_roll()
	_build_cards()
	_busy = false
	_update_money()

func _refresh_inventory() -> void:
	for c in _inv.get_children():
		c.queue_free()
	var pl = Game.player
	_inv.add_child(UIKit.label("Dein Spind:", 20, Color("f2e6c4"), HORIZONTAL_ALIGNMENT_LEFT, true))
	for i in pl.slots:
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", UIKit.sbox("slot_blue", 6))
		p.custom_minimum_size = Vector2(76, 82)
		if i < pl.weapons.size():
			var w: WeaponRunner = pl.weapons[i]
			var vv := VBoxContainer.new()
			vv.add_theme_constant_override("separation", 0)
			vv.add_child(UIKit.icon(w.data.icon, Vector2(54, 46)))
			vv.add_child(UIKit.label("Stufe %d" % w.level if not w.data.evolution else "EVO", 12, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER))
			p.add_child(vv)
		_inv.add_child(p)
	_inv.add_child(UIKit.label("   Items:", 20, Color("f2e6c4"), HORIZONTAL_ALIGNMENT_LEFT, true))
	for id in pl.items:
		var u: UpgradeData = Db.upgrades[id]
		var h := HBoxContainer.new()
		h.add_child(UIKit.icon(u.icon, Vector2(34, 34)))
		h.add_child(UIKit.label("x%d" % pl.items[id], 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, true))
		_inv.add_child(h)

func _flash_slot() -> void:
	Juice.shake(0.15)

func _draw() -> void:
	var sz := get_rect().size
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0.17, 0.2, 0.33))
	for i in 12:
		draw_rect(Rect2(0, i * 64.0, sz.x, 32), Color(0.19, 0.22, 0.36))
	# Verkaufstresen
	draw_rect(Rect2(0, 80, sz.x, 440), Color(0.35, 0.24, 0.12))
	draw_rect(Rect2(0, 84, sz.x, 432), Color(0.5, 0.35, 0.18))
	draw_rect(Rect2(0, 520, sz.x, 12), Color(0.25, 0.16, 0.08))
