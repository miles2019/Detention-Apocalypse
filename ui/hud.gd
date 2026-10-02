class_name HUD
extends CanvasLayer
## HUD im Run: Lebenspunkte, Tinte (XP), Brotdose (Geld), Stundenplan-Karte, Welle, Waffen-Spindfächer, Boss, Durchsagen.

var _c: Control
var _banner: PanelContainer
var _banner_label: Label
var _banner_tw: Tween
var _stamps: Control
var _chain_label: Label
var _chain_tw: Tween
var _flash: ColorRect
var _hp_ghost := 100.0
var _hp_shown := 100.0
var _xp_shown := 0.0
var _money_pop := 0.0
var _money_shake := 0.0
var _hurt_a := 0.0
var _boss := {hp = 0.0, max = 1.0, ghost = 1.0, on = false}
var _wave_info := {alive = 0, left = 0}
var _slot_flash := [0.0, 0.0, 0.0, 0.0]
var _slot_ready := [true, true, true, true]
var _splashes: Array = []
var _stamp_n := 0
var _last_xp := 0
var _last_money := 0

const SLOT := 72.0

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_c = Control.new()
	UIKit.full(_c)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw_hud)
	add_child(_c)
	# Durchsage-Banner
	_banner = PanelContainer.new()
	_banner.add_theme_stylebox_override("panel", UIKit.box(Color("8f1d1d"), Color("2b0a0a"), 4, 8, 10))
	_banner.position = Vector2(230, 94)
	_banner.custom_minimum_size = Vector2(820, 0)
	_banner.visible = false
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	_banner.add_child(hb)
	var ic := UIKit.icon(Db.w_icon(8), Vector2(44, 44))
	hb.add_child(ic)
	_banner_label = UIKit.label("", 19, Color("fff4d6"))
	_banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_label.custom_minimum_size = Vector2(740, 0)
	hb.add_child(_banner_label)
	_c.add_child(_banner)
	_stamps = Control.new()
	UIKit.full(_stamps)
	_stamps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.add_child(_stamps)
	_chain_label = UIKit.label("", 34, Color(1, 0.88, 0.3), HORIZONTAL_ALIGNMENT_CENTER, true)
	_chain_label.position = Vector2(340, 190)
	_chain_label.custom_minimum_size = Vector2(600, 0)
	_chain_label.modulate.a = 0.0
	_c.add_child(_chain_label)
	_flash = ColorRect.new()
	UIKit.full(_flash)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	Game.announce.connect(_on_announce)
	Game.stamp_requested.connect(_on_stamp)
	Game.chain_event.connect(_on_chain)
	Game.player_hurt.connect(func(): _hurt_a = 0.7)
	Game.money_changed.connect(_on_money)
	Game.xp_changed.connect(_on_xp)
	Game.boss_changed.connect(func(hp: float, mx: float, on: bool):
		_boss.hp = hp
		_boss.max = mx
		_boss.on = on)
	Game.wave_progress.connect(func(a: int, l: int):
		_wave_info.alive = a
		_wave_info.left = l)
	Game.phase_changed.connect(func(_id):
		_flash.color.a = 0.5
		create_tween().tween_property(_flash, "color:a", 0.0, 0.5))

func reset() -> void:
	_banner.visible = false
	_boss.on = false
	_hurt_a = 0.0
	_hp_shown = 100.0
	_hp_ghost = 100.0
	_xp_shown = 0.0
	_last_xp = 0
	_last_money = 0
	_wave_info = {alive = 0, left = 0}
	for ch in _stamps.get_children():
		ch.queue_free()

func _process(delta: float) -> void:
	if not visible:
		return
	var pl = Game.player
	if pl != null:
		_hp_shown = lerpf(_hp_shown, pl.hp, 1.0 - exp(-16.0 * delta))
		_hp_ghost = move_toward(_hp_ghost, pl.hp, 30.0 * delta) if _hp_ghost > pl.hp else pl.hp
		for i in pl.weapons.size():
			if i >= 4:
				break
			var ready: bool = pl.weapons[i].cd_ratio() >= 0.99
			if ready and not _slot_ready[i]:
				_slot_flash[i] = 1.0
			_slot_ready[i] = ready
			_slot_flash[i] = maxf(0.0, _slot_flash[i] - delta * 4.0)
	_xp_shown = lerpf(_xp_shown, float(Game.xp) / float(Game.xp_needed()), 1.0 - exp(-10.0 * delta))
	_money_pop = maxf(0.0, _money_pop - delta * 3.0)
	_money_shake = maxf(0.0, _money_shake - delta * 2.5)
	_hurt_a = maxf(0.0, _hurt_a - delta * 1.8)
	_boss.ghost = move_toward(_boss.ghost, _boss.hp / maxf(1.0, _boss.max), delta * 0.5) if _boss.ghost > _boss.hp / maxf(1.0, _boss.max) else _boss.hp / maxf(1.0, _boss.max)
	for s in _splashes:
		s.life -= delta
		s.vel.y += 500.0 * delta
		s.pos += s.vel * delta
	_splashes = _splashes.filter(func(s): return s.life > 0.0)
	# Mauszeiger im Run verstecken (eigenes Fadenkreuz)
	var in_run: bool = Game.state == Game.State.IN_RUN or Game.state == Game.State.WAVE_TRANSITION
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if in_run else Input.MOUSE_MODE_VISIBLE
	_c.queue_redraw()

func _txt(pos: Vector2, text: String, size: int, color: Color = Color.WHITE, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	var f := ThemeDB.fallback_font
	_c.draw_string_outline(f, pos, text, align as HorizontalAlignment, width, size, maxi(3, size / 5), Color(0.05, 0.05, 0.1))
	_c.draw_string(f, pos, text, align as HorizontalAlignment, width, size, color)

func _tex(path: String, rect: Rect2, mod: Color = Color.WHITE) -> void:
	var t: Texture2D = Db.tex(path)
	if t == null:
		return
	# Seitenverhältnis erhalten
	var s := minf(rect.size.x / t.get_width(), rect.size.y / t.get_height())
	var sz := t.get_size() * s
	_c.draw_texture_rect(t, Rect2(rect.position + (rect.size - sz) * 0.5, sz), false, mod)

func _draw_hud() -> void:
	var pl = Game.player
	if pl == null:
		return
	var c := _c
	# ------- Hurt-Vignette
	if _hurt_a > 0.0:
		for i in 8:
			var a := _hurt_a * 0.35 * (1.0 - float(i) / 8.0)
			var t := 14.0 * (i + 1)
			c.draw_rect(Rect2(0, 0, 1280, t), Color(0.9, 0.1, 0.1, a * 0.3))
			c.draw_rect(Rect2(0, 720 - t, 1280, t), Color(0.9, 0.1, 0.1, a * 0.3))
			c.draw_rect(Rect2(0, 0, t, 720), Color(0.9, 0.1, 0.1, a * 0.3))
			c.draw_rect(Rect2(1280 - t, 0, t, 720), Color(0.9, 0.1, 0.1, a * 0.3))
	# ------- Status-Karte links
	c.draw_style_box(UIKit.box(Color(0.96, 0.9, 0.76, 0.96), Color("5a4630"), 4, 10, 6), Rect2(14, 14, 316, 128))
	var low: bool = pl.hp / pl.max_hp < 0.3
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	_tex(Db.i_icon(20), Rect2(24, 22, 38, 38), Color(1, 1, 1, 1.0 if not low else 0.6 + 0.4 * pulse))
	var hp_r := Rect2(70, 28, 246, 24)
	c.draw_rect(hp_r.grow(3), Color(0.15, 0.1, 0.1))
	c.draw_rect(hp_r, Color(0.3, 0.12, 0.12))
	c.draw_rect(Rect2(hp_r.position, Vector2(hp_r.size.x * clampf(_hp_ghost / pl.max_hp, 0, 1), hp_r.size.y)), Color(1, 0.95, 0.85))
	var hf := clampf(_hp_shown / pl.max_hp, 0, 1)
	c.draw_rect(Rect2(hp_r.position, Vector2(hp_r.size.x * hf, hp_r.size.y)), Color(0.88, 0.2, 0.2) if not low else Color(1.0, 0.25 + 0.2 * pulse, 0.2))
	# abwischbarer Balken: Kratzspuren
	for i in 10:
		var x := hp_r.position.x + 10.0 + i * 24.0
		if x < hp_r.position.x + hp_r.size.x * hf - 10.0:
			c.draw_line(Vector2(x, hp_r.position.y + 5), Vector2(x + 9, hp_r.position.y + 15), Color(1, 1, 1, 0.22), 2.0)
	_txt(Vector2(70, 47), "%d / %d" % [ceili(pl.hp), int(pl.max_hp)], 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 246.0)
	# Tinte (XP)
	_tex(Db.i_icon(15), Rect2(26, 64, 34, 34))
	var xp_r := Rect2(70, 74, 190, 14)
	c.draw_rect(xp_r.grow(3), Color(0.1, 0.1, 0.2))
	c.draw_rect(xp_r, Color(0.13, 0.15, 0.3))
	c.draw_rect(Rect2(xp_r.position, Vector2(xp_r.size.x * clampf(_xp_shown, 0, 1), xp_r.size.y)), Color(0.25, 0.4, 0.95))
	c.draw_rect(Rect2(xp_r.position, Vector2(xp_r.size.x * clampf(_xp_shown, 0, 1), 4)), Color(0.55, 0.7, 1.0))
	_txt(Vector2(268, 88), "Lv %d" % Game.level, 17, Color(0.7, 0.85, 1.0))
	for s in _splashes:
		c.draw_circle(s.pos, 2.5, Color(0.3, 0.45, 1.0, clampf(s.life * 3.0, 0, 1)))
	# Brotdose (Pausengeld)
	var shake := sin(Time.get_ticks_msec() * 0.06) * 3.0 * _money_shake
	c.draw_set_transform(Vector2(26, 110) + Vector2(18, 18), shake * 0.03, Vector2.ONE * (1.0 + 0.25 * _money_pop))
	var sw: Texture2D = Db.tex("res://assets/items/sandwich.png")
	c.draw_texture_rect(sw, Rect2(-18, -18, 36, 36), false)
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var mf := 24 + int(8 * _money_pop)
	_txt(Vector2(74, 128), "Pausengeld: %d" % Game.money, mf, Color(1.0, 0.88, 0.3))
	# ------- Stundenplan-Karte (Phase)
	if Game.phase_id != "" and Db.phases.has(Game.phase_id):
		var ph: PhaseData = Db.phases[Game.phase_id]
		var pr := Rect2(490, 12, 300, 74)
		c.draw_style_box(UIKit.box(Color(0.96, 0.9, 0.76, 0.96), Color("22305c"), 4, 10, 6), pr)
		c.draw_rect(Rect2(pr.position.x + 6, pr.position.y + 6, 64, 62), Color(0.14, 0.19, 0.36))
		_tex(ph.icon, Rect2(pr.position.x + 10, pr.position.y + 10, 56, 54))
		_txt(Vector2(pr.position.x + 78, pr.position.y + 28), "Stunde: " + ph.display_name, 20, Color(1, 0.95, 0.8))
		var left := 0.0
		if Game.arena != null and Game.arena.phases != null:
			left = Game.arena.phases.time_left
		var fr := clampf(left / PhaseManager.PHASE_LENGTH, 0.0, 1.0)
		c.draw_rect(Rect2(pr.position.x + 78, pr.position.y + 36, 210, 8), Color(0.15, 0.15, 0.3))
		c.draw_rect(Rect2(pr.position.x + 78, pr.position.y + 36, 210 * fr, 8), Db.subject_color(ph.id))
		_txt(Vector2(pr.position.x + 78, pr.position.y + 62), ph.rule.substr(0, 40), 11, Color(0.95, 0.9, 0.75))
		_txt(Vector2(pr.position.x + 250, pr.position.y + 28), "%ds" % ceili(left), 16, Color(0.8, 0.9, 1))
	# ------- Welle rechts
	var wr := Rect2(1280 - 14 - 232, 14, 232, 72)
	c.draw_style_box(UIKit.box(Color(0.96, 0.9, 0.76, 0.96), Color("5a4630"), 4, 10, 6), wr)
	if Game.wave > Game.TOTAL_WAVES:
		_txt(wr.position + Vector2(14, 32), "BOSSKAMPF", 24, Color(1, 0.4, 0.3))
		_txt(wr.position + Vector2(14, 58), "Gegner: %d" % Game.enemies.size(), 17, Color.WHITE)
	else:
		_txt(wr.position + Vector2(14, 32), "Welle %d / %d" % [maxi(1, Game.wave), Game.TOTAL_WAVES], 24, Color(1, 0.95, 0.8))
		var remaining: int = _wave_info.alive + _wave_info.left
		_txt(wr.position + Vector2(14, 58), "Gegner: %d" % remaining, 17, Color.WHITE)
		for i in Game.TOTAL_WAVES:
			var col := Color(0.4, 0.8, 0.4) if i < Game.wave - 1 else (Color(1, 0.8, 0.2) if i == Game.wave - 1 else Color(0.35, 0.3, 0.3))
			c.draw_circle(wr.position + Vector2(130 + i * 18, 52), 6.0, col)
			c.draw_arc(wr.position + Vector2(130 + i * 18, 52), 6.0, 0, TAU, 12, Color(0.1, 0.1, 0.1), 1.5)
	# ------- Boss-Balken
	if _boss.on:
		var br := Rect2(360, 720 - 150, 560, 26)
		c.draw_rect(br.grow(4), Color(0.1, 0.05, 0.05))
		c.draw_rect(br, Color(0.3, 0.08, 0.08))
		c.draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(_boss.ghost, 0, 1), br.size.y)), Color(1, 0.95, 0.85))
		c.draw_rect(Rect2(br.position, Vector2(br.size.x * clampf(_boss.hp / _boss.max, 0, 1), br.size.y)), Color(0.9, 0.2, 0.2))
		c.draw_line(Vector2(br.position.x + br.size.x * 0.5, br.position.y - 4), Vector2(br.position.x + br.size.x * 0.5, br.position.y + 30), Color.WHITE, 2.0)
		_txt(Vector2(br.position.x, br.position.y - 8), "Frau Eisenhart – Sportlehrerin", 18, Color(1, 0.9, 0.7))
	# ------- Waffen-Spindfächer
	var total_w := 4 * SLOT + 3 * 10.0
	var x0 := (1280.0 - total_w) * 0.5
	var y0 := 720.0 - SLOT - 16.0
	for i in 4:
		var r := Rect2(x0 + i * (SLOT + 10.0), y0, SLOT, SLOT)
		c.draw_rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.35))
		c.draw_rect(r, Color(0.45, 0.52, 0.6))
		c.draw_rect(r.grow(-4), Color(0.58, 0.66, 0.74))
		c.draw_rect(r, Color(0.1, 0.12, 0.18), false, 3.0)
		for v in 3:
			c.draw_line(r.position + Vector2(18 + v * 18, 6), r.position + Vector2(18 + v * 18, 12), Color(0.2, 0.25, 0.32), 2.0)
		if i < pl.weapons.size():
			var w: WeaponRunner = pl.weapons[i]
			var bob := 0.0
			_tex(w.data.icon, Rect2(r.position + Vector2(8, 12), Vector2(56, 52)))
			# Cooldown-Ring
			var ratio := w.cd_ratio()
			if ratio < 0.99:
				c.draw_arc(r.get_center(), 30.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 28, Color(1, 1, 1, 0.9), 4.0)
				c.draw_rect(r.grow(-3), Color(0, 0, 0, 0.3 * (1.0 - ratio)))
			if _slot_flash[i] > 0.0:
				c.draw_rect(r, Color(1, 1, 1, _slot_flash[i] * 0.5))
			# Stufe
			for l in w.level:
				c.draw_rect(Rect2(r.position.x + 6 + l * 9, r.position.y + SLOT - 11, 7, 6), Color(1, 0.85, 0.2))
			if w.data.evolution:
				c.draw_rect(r.grow(2), Color(1, 0.85, 0.2), false, 3.0)
				_txt(r.position + Vector2(4, 16), "EVO", 12, Color(1, 0.9, 0.3))
			# Fachsymbol
			_tex(Db.subject_icon(w.data.subject), Rect2(r.position + Vector2(SLOT - 22, 2), Vector2(20, 20)))
		else:
			c.draw_string(ThemeDB.fallback_font, r.position + Vector2(24, 46), "-", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.3, 0.35, 0.42))
	# Ausweichen-Anzeige
	var dr := Vector2(x0 - 54, y0 + SLOT * 0.5)
	c.draw_circle(dr, 22.0, Color(0.1, 0.12, 0.18, 0.9))
	var dfrac := 1.0 - clampf(pl.dash_cd / 0.85, 0.0, 1.0)
	c.draw_arc(dr, 19.0, -PI / 2, -PI / 2 + TAU * dfrac, 24, Color(0.6, 0.9, 1.0) if dfrac >= 1.0 else Color(0.5, 0.5, 0.6), 4.0)
	_txt(dr + Vector2(-16, 6), ">>", 16, Color.WHITE)
	_txt(dr + Vector2(-24, 38), Game.key_label("dash"), 11, Color(0.8, 0.85, 0.95), HORIZONTAL_ALIGNMENT_CENTER, 48.0)
	# Fach-Synergien (Symbol + Zähler)
	var sx := x0 + total_w + 14.0
	var sy := y0
	for s in pl.subject_counts:
		if s == "Hausmeister":
			continue
		var cnt: int = pl.subject_counts[s]
		var active: bool = cnt >= 2
		var chip := Rect2(sx, sy, 96, 22)
		c.draw_rect(chip, Color(0.1, 0.12, 0.2, 0.85))
		c.draw_rect(chip, Db.subject_color(s) if active else Color(0.4, 0.4, 0.45), false, 2.0)
		_tex(Db.subject_icon(s), Rect2(chip.position + Vector2(2, 1), Vector2(20, 20)))
		_txt(chip.position + Vector2(26, 17), ("%s %d/2" % [s, cnt]) if cnt < 2 else ("%s aktiv" % s), 12, Color.WHITE if active else Color(0.7, 0.7, 0.75))
		sy += 25.0
		if sy > y0 + SLOT:
			sy = y0
			sx += 100.0
	# ------- Fadenkreuz
	if Game.state == Game.State.IN_RUN or Game.state == Game.State.WAVE_TRANSITION:
		var m := get_viewport().get_mouse_position()
		var big := 1.4 if pl.manual_aim else 1.0
		c.draw_arc(m, 11.0 * big, 0, TAU, 20, Color(0, 0, 0, 0.8), 4.0)
		c.draw_arc(m, 11.0 * big, 0, TAU, 20, Color.WHITE, 2.0)
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			c.draw_line(m + d * 14.0 * big, m + d * 20.0 * big, Color.WHITE, 2.0)
		c.draw_circle(m, 1.8, Color(1, 0.3, 0.3))

# ---------------------------------------------------------------- Ereignisse
func _on_money(v: int) -> void:
	if v > _last_money:
		_money_pop = 1.0
		_money_shake = 1.0
	_last_money = v

func _on_xp(xp: int, _need: int, _lv: int) -> void:
	if xp > _last_xp:
		var r := Vector2(70 + 190.0 * clampf(_xp_shown, 0, 1), 80)
		for i in 3:
			_splashes.append({pos = r, vel = Vector2(randf_range(-40, 90), randf_range(-120, -30)), life = 0.5})
	_last_xp = xp

func _on_announce(text: String, kind: String) -> void:
	if text == "" or kind == "boss_warn":
		return
	var col := Color("8f1d1d")
	match kind:
		"phase": col = Color("22305c")
		"info": col = Color("2f4a38")
		"boss": col = Color("7a0f0f")
		"wave", "chaos": col = Color("8f1d1d")
	_banner.add_theme_stylebox_override("panel", UIKit.box(col, Color(0.05, 0.03, 0.03), 4, 8, 10))
	_banner_label.text = text
	_banner_label.visible_characters = 0
	_banner.visible = true
	_banner.modulate.a = 1.0
	if _banner_tw:
		_banner_tw.kill()
	_banner_tw = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_banner_tw.tween_property(_banner_label, "visible_characters", text.length(), minf(2.5, text.length() * 0.025))
	_banner_tw.tween_interval(2.0 + text.length() * 0.03)
	_banner_tw.tween_property(_banner, "modulate:a", 0.0, 0.5)
	_banner_tw.tween_callback(func(): _banner.visible = false)

func _on_stamp(text: String, color: Color) -> void:
	var st := UIKit.stamp(text, color, 46, randf_range(-8.0, 6.0))
	st.position = Vector2(640, 300 + (_stamp_n % 3) * 70) - st.size * 0.5
	_stamp_n += 1
	_stamps.add_child(st)
	st.reset_size()
	st.position = Vector2(640, 280 + (_stamp_n % 3) * 80) - st.size * 0.5
	UIKit.slam_stamp(st, 0.0)
	var tw := st.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(1.4)
	tw.tween_property(st, "modulate:a", 0.0, 0.4)
	tw.tween_callback(st.queue_free)

func _on_chain(n: int) -> void:
	var t := "%d-fache Gruppenarbeit!" % n
	if n >= 8:
		t = "Hervorragende Gruppenarbeit! x%d" % n
	elif n >= 5:
		t = "Pädagogisch bedenklich! x%d" % n
	_chain_label.text = t
	_chain_label.pivot_offset = Vector2(300, 20)
	_chain_label.modulate.a = 1.0
	_chain_label.scale = Vector2(0.6, 0.6)
	if _chain_tw:
		_chain_tw.kill()
	_chain_tw = create_tween()
	_chain_tw.tween_property(_chain_label, "scale", Vector2(1.15, 1.15), 0.1).set_trans(Tween.TRANS_BACK)
	_chain_tw.tween_property(_chain_label, "scale", Vector2.ONE, 0.08)
	_chain_tw.tween_interval(0.9)
	_chain_tw.tween_property(_chain_label, "modulate:a", 0.0, 0.4)
