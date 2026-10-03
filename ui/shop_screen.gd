class_name ShopScreen
extends Control
## Pausenkiosk: drei Waffen + zwei Items, Kaufen, Reroll (Radiergummi), Merken (Waffe bleibt im Angebot), Spind mit Verkauf.

signal closed
signal evolution_requested(recipe: Dictionary)
signal stats_requested

const CARD := Vector2(232, 410)
const WEAPON_OFFERS := 3
const MAX_LOCKS := 2

var _offers: Array = []
var _cards: Array = []
var _rerolls := 0
var _row: HBoxContainer
var _inv: Control
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
	_title = UIKit.label("Pausenkiosk", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
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
	_row.add_theme_constant_override("separation", 12)
	_row.position = Vector2(36, 92)
	add_child(_row)
	# Unterer Bereich: links der Spind (Waffen verkaufen, Items), rechts Akte / Reroll / Weiter
	var inv_bg := Panel.new()
	inv_bg.add_theme_stylebox_override("panel", UIKit.sbox("panel_black", 6, Color(1, 1, 1, 0.9)))
	inv_bg.position = Vector2(36, 528)
	inv_bg.size = Vector2(872, 184)
	inv_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(inv_bg)
	_inv = Control.new()
	_inv.position = Vector2(52, 536)
	_inv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inv)
	var akte := UIKit.button("Schülerakte [Tab]", Vector2(318, 42), 18, Color("a8c8f8"))
	akte.position = Vector2(926, 530)
	akte.pressed.connect(func(): stats_requested.emit())
	UIKit.tip(akte, "Schülerakte", "Alle Werte, Waffen, Items und Fach-Sets im Überblick.")
	add_child(akte)
	_reroll_btn = UIKit.button("Radiergummi: neu würfeln", Vector2(318, 50), 17, Color("f4b0d0"))
	_reroll_btn.position = Vector2(926, 578)
	_reroll_btn.pressed.connect(_reroll)
	UIKit.tip(_reroll_btn, "Radiergummi", "Würfelt alle Angebote neu aus. Wird mit jedem Mal teurer.")
	add_child(_reroll_btn)
	var go := UIKit.button("Nächste Stunde", Vector2(318, 68), 28, Color("c8f0b8"))
	go.icon = UIKit.tex_icon("adventure")
	go.expand_icon = true
	go.add_theme_constant_override("icon_max_width", 30)
	go.add_theme_font_size_override("font_size", 23)
	go.position = Vector2(926, 636)
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
	_reroll_btn.text = "Neu würfeln (%d Geld)" % cost
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
		if wd.evolution:
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
	# gemerkte Waffen bleiben im Angebot, bis sie gekauft oder freigegeben werden
	for id in Game.shop_locks.duplicate():
		if cand.has(id) and picks.size() < WEAPON_OFFERS:
			picks.append(id)
			cand.erase(id)
		else:
			Game.shop_locks.erase(id)
	if not partners.is_empty() and picks.size() < WEAPON_OFFERS:
		partners.shuffle()
		for pid in partners:
			if cand.has(pid):
				picks.append(pid)
				cand.erase(pid)
				break
	# möglichst unterschiedliche Spielweisen anbieten
	var kinds := {}
	for id in picks:
		kinds[Db.weapons[id].kind] = true
	for id in cand.duplicate():
		if picks.size() >= WEAPON_OFFERS:
			break
		if not kinds.has(Db.weapons[id].kind):
			kinds[Db.weapons[id].kind] = true
			picks.append(id)
			cand.erase(id)
	while picks.size() < WEAPON_OFFERS and not cand.is_empty():
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
	var csb := UIKit.sbox_new("card_cream", 10, Color(1.0, 0.95, 0.7) if (o.kind == "weapon" and Game.shop_locks.has(o.id)) else Color.WHITE)
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
	var sl := UIKit.label(subject if subject != "" else "Allgemein", 14, Db.subject_color(subject).darkened(0.6))
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sj.add_child(sl)
	if o.kind == "weapon":
		# Merken: diese Waffe bleibt auch nach dem Neu-Würfeln und im nächsten Kiosk im Angebot
		var locked: bool = Game.shop_locks.has(o.id)
		var lb := UIKit.button("Gemerkt" if locked else "Merken", Vector2(84, 28), 11, Color("ffe08a") if locked else Color("a8c8f8"))
		lb.name = "Lock"
		lb.pressed.connect(func(): _toggle_lock(i))
		UIKit.tip(lb, "Merken", "Die Waffe bleibt im Angebot – auch nach dem Neu-Würfeln und im nächsten Kiosk –, bis du sie kaufst oder wieder freigibst.\nHöchstens %d Waffen gleichzeitig." % MAX_LOCKS)
		sj.add_child(lb)
	v.add_child(sj)
	var slot := PanelContainer.new()
	slot.add_theme_stylebox_override("panel", UIKit.sbox("slot_blue", 8))
	slot.custom_minimum_size = Vector2(100, 104)
	slot.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ic := UIKit.icon(icon_path, Vector2(74, 74))
	slot.add_child(ic)
	v.add_child(slot)
	var nl := UIKit.label(name, 18, UIKit.NAVY, HORIZONTAL_ALIGNMENT_CENTER)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(206, 0)
	v.add_child(nl)
	var d := UIKit.label(desc, 13, UIKit.INK, HORIZONTAL_ALIGNMENT_CENTER)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(206, 66)
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
	var b := UIKit.button("Kaufen", Vector2(180, 50), 22, Color("c8f0b8"))
	b.name = "Buy"
	b.pressed.connect(func(): _buy(i))
	v.add_child(b)
	# Hover-Info mit echten Werten
	if o.kind == "weapon":
		var wd2: WeaponData = Db.weapons[o.id]
		var own: WeaponRunner = Game.player.get_weapon(o.id)
		UIKit.tip(card, wd2.display_name, Tips.weapon(wd2, 1 if own == null else own.level + 1, Game.player, false))
	else:
		var u2: UpgradeData = Db.upgrades[o.id]
		var chg := Tips.upgrade_change(o.id, Game.player)
		UIKit.tip(card, u2.display_name, Tips.item(u2, Game.player.items.get(o.id, 0), Game.player) + ("\n\n" + chg if chg != "" else ""))
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
		Game.shop_locks.erase(o.id)
	else:
		pl.add_item(o.id)
	o.sold = true
	Sfx.play("buy")
	# Karte wird mit einem "Klack" in ein Spindfach geschoben
	var target := _inv.position + Vector2(40 + 86 * minf(pl.weapons.size(), 5), 60)
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
		# verkaufte Karte bleibt als unsichtbarer Platzhalter in der Reihe (Layout springt nicht)
		card.modulate = Color(1, 1, 1, 0.0)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.scale = Vector2.ONE
		_row.queue_sort()
	_update_money()
	var r: Dictionary = pl.check_evolution()
	if not r.is_empty():
		_busy = true
		evolution_requested.emit(r)

func _toggle_lock(i: int) -> void:
	if _busy or i >= _offers.size():
		return
	var o: Dictionary = _offers[i]
	if o.sold or o.kind != "weapon":
		return
	if Game.shop_locks.has(o.id):
		Game.shop_locks.erase(o.id)
		Sfx.play("click", 0.8)
	elif Game.shop_locks.size() < MAX_LOCKS:
		Game.shop_locks.append(o.id)
		Sfx.play("stamp", 1.4, -6.0)
	else:
		_deny(_cards[i])
		return
	var locked: bool = Game.shop_locks.has(o.id)
	var lb: Button = _cards[i].find_child("Lock", true, false)
	if lb != null:
		lb.text = "Gemerkt" if locked else "Merken"
	var csb := UIKit.sbox_new("card_cream", 10, Color(1.0, 0.95, 0.7) if locked else Color.WHITE)
	csb.content_margin_top = 6.0
	_cards[i].add_theme_stylebox_override("panel", csb)

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
	var can_sell: bool = pl.weapons.size() > 1
	var head := UIKit.label("Dein Spind", 15, Color("f2e6c4"), HORIZONTAL_ALIGNMENT_LEFT, true)
	head.position = Vector2(0, 0)
	_inv.add_child(head)
	for i in pl.slots:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(80, 76)
		p.size = Vector2(80, 76)
		p.position = Vector2(i * 86.0, 24)
		if i < pl.weapons.size():
			var w: WeaponRunner = pl.weapons[i]
			p.add_theme_stylebox_override("panel", UIKit.sbox("slot_yellow" if w.data.evolution else "slot_blue", 4))
			var vv := VBoxContainer.new()
			vv.add_theme_constant_override("separation", 0)
			vv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vv.add_child(UIKit.icon(w.data.icon, Vector2(54, 44)))
			vv.add_child(UIKit.label("Stufe %d" % w.level if not w.data.evolution else "EVO", 12, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true))
			p.add_child(vv)
			var value: int = pl.sell_value(w)
			UIKit.tip(p, w.data.display_name, Tips.weapon(w.data, w.level, pl) + "\n\nVerkaufswert: %d Pausengeld" % value)
			_inv.add_child(p)
			var sb := UIKit.button("+%d" % value, Vector2(80, 36), 15, Color("f4b0a8"))
			sb.icon = UIKit.tex_icon("coins")
			sb.expand_icon = true
			sb.add_theme_constant_override("icon_max_width", 18)
			sb.position = Vector2(i * 86.0, 104)
			sb.disabled = not can_sell
			UIKit.tip(sb, "Verkaufen", ("%s für %d Pausengeld verkaufen. Das Spindfach wird frei." % [w.data.display_name, value]) if can_sell else "Deine letzte Waffe kannst du nicht verkaufen – eine brauchst du immer.")
			sb.pressed.connect(func(): _sell(w, sb))
			_inv.add_child(sb)
		else:
			p.add_theme_stylebox_override("panel", UIKit.sbox("slot_purple", 4, Color(0.75, 0.75, 0.85, 0.8)))
			UIKit.tip(p, "Freies Spindfach", "Hier passt noch eine Waffe hinein.")
			_inv.add_child(p)
	var ix := maxf(float(pl.slots), 4.0) * 86.0 + 18.0
	var il := UIKit.label("Items", 15, Color("f2e6c4"), HORIZONTAL_ALIGNMENT_LEFT, true)
	il.position = Vector2(ix, 0)
	_inv.add_child(il)
	var k := 0
	var per_row := maxi(3, int((856.0 - ix) / 50.0))
	for id in pl.items:
		var u: UpgradeData = Db.upgrades[id]
		var ip := PanelContainer.new()
		ip.add_theme_stylebox_override("panel", UIKit.sbox("slot_blue", 2))
		ip.custom_minimum_size = Vector2(46, 46)
		ip.size = Vector2(46, 46)
		ip.position = Vector2(ix + (k % per_row) * 50.0, 24 + (k / per_row) * 50.0)
		var ic := UIKit.icon(u.icon, Vector2(30, 30))
		ip.add_child(ic)
		var cnt := UIKit.label("x%d" % pl.items[id], 12, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT, true)
		cnt.size_flags_vertical = Control.SIZE_SHRINK_END
		ip.add_child(cnt)
		UIKit.tip(ip, u.display_name, Tips.item(u, pl.items[id], pl))
		_inv.add_child(ip)
		k += 1
	if pl.items.is_empty():
		var none := UIKit.label("noch keine", 13, Color(0.75, 0.75, 0.85))
		none.position = Vector2(ix, 30)
		_inv.add_child(none)

## Waffe verkaufen: Geld zurück, Spindfach wird frei (mindestens eine Waffe bleibt)
func _sell(w: WeaponRunner, btn: Control) -> void:
	if _busy:
		return
	var v: int = Game.player.sell_weapon(w)
	if v <= 0:
		Sfx.play("denied")
		return
	Sfx.play("coin", 0.9)
	Sfx.play("locker", 1.3, -8.0)
	Juice.shake(0.12)
	var fl := UIKit.label("+%d" % v, 30, Color(1, 0.9, 0.3), HORIZONTAL_ALIGNMENT_CENTER, true)
	fl.position = btn.global_position + Vector2(10, -20)
	add_child(fl)
	var tw := fl.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tw.tween_property(fl, "position", Vector2(1040, 30), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(fl, "modulate:a", 0.2, 0.55)
	tw.chain().tween_callback(fl.queue_free)
	_refresh_inventory()
	_update_money()

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
