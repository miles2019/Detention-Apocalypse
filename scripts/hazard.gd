class_name Hazard
extends Node2D
## Bodenzone: Warnphase -> Aktivierung (Burst) -> optional anhaltende Pfütze.
## Wird für Säure, klebrige Pfützen, Kreide, Schläge und Wurfgeschosse benutzt.

var radius := 60.0
var telegraph := 0.8
var duration := 0.0
var color := Color(0.5, 1.0, 0.3)
var pattern := "bubbles"     # bubbles | waves | stripes
var burst_player := 0.0
var burst_enemy := 0.0
var tick_player := 0.0
var tick_enemy := 0.0
var slow_player := 1.0
var slow_enemy := 1.0
var kb := 0.0
var stun_player := 0.0
var kind := "generic"       # acid | sticky | chalk | impact | slam
var fly_tex: Texture2D
var fly_from := Vector2.ZERO
var follow_up := {}
var from_enemy := true
var sound := ""
var on_activate := Callable()

var _t := 0.0
var _active := false
var _tick := 0.0
var _fade := 1.0
var _seed := 0.0

static func spawn(pos: Vector2, props: Dictionary) -> Hazard:
	if Game.arena == null:
		return null
	var h := Hazard.new()
	for k in props:
		h.set(k, props[k])
	h.global_position = pos
	Game.arena.floor_fx.add_child(h)
	return h

func _ready() -> void:
	z_index = 1
	_seed = randf() * 10.0
	if telegraph > 0.15 and from_enemy:
		Sfx.play("warn", 1.0, -9.0)

func _process(delta: float) -> void:
	_t += delta
	if not _active:
		if _t >= telegraph:
			_activate()
	else:
		var life := _t - telegraph
		if duration <= 0.0:
			_fade = 1.0 - life / 0.25
			if life >= 0.25:
				queue_free()
		else:
			_apply_zone(delta)
			if life >= duration:
				_fade = 1.0 - (life - duration) / 0.4
				if life - duration >= 0.4:
					queue_free()
	queue_redraw()

func _activate() -> void:
	_active = true
	if on_activate.is_valid():
		on_activate.call()
	var pl = Game.player
	var mul := 1.0
	if kind in ["chalk", "impact"] and not from_enemy:
		mul = Game.phase_mod("explosion")
	var big := kind in ["slam", "impact", "chalk"]
	if big:
		Game.arena.stage.pulse_light(global_position, color, 1.6, 2.6, 0.3)
		Juice.ring(global_position, radius * mul, color, 0.35, 8.0, true)
		Juice.burst(global_position, color, 14, 220.0, 0.5, 4.0)
		if sound != "":
			Sfx.play(sound)
		if kind == "slam":
			Juice.shake(0.45)
			Game.arena.room_react(global_position, 1.0)
	if burst_player > 0.0 and pl != null:
		if pl.global_position.distance_to(global_position) < radius + 10.0:
			var dir: Vector2 = (pl.global_position - global_position).normalized()
			if pl.take_damage(burst_player, global_position, true):
				if kb > 0.0:
					pl.knock(dir * kb)
				if stun_player > 0.0:
					pl.stun(stun_player)
	if burst_enemy > 0.0:
		var r := radius * mul
		for e in Game.enemies.duplicate():
			if not is_instance_valid(e) or e.dead:
				continue
			if e.global_position.distance_to(global_position) < r + e.data.radius:
				var res: Dictionary = Game.player.roll_damage(burst_enemy, 0.0)
				var dir: Vector2 = (e.global_position - global_position).normalized()
				e.take_hit(res.dmg, dir, kb * Game.phase_mod("kb"), res.crit, {slow = 0.4 if kind == "chalk" else 0.0, tags = "area"})
		Sfx.play_hit(false)
	if not follow_up.is_empty():
		Hazard.spawn(global_position, follow_up)
	if duration <= 0.0 and not big:
		queue_free()

func _apply_zone(delta: float) -> void:
	var pl = Game.player
	_tick -= delta
	var do_tick := _tick <= 0.0
	if do_tick:
		_tick = 0.45
	if pl != null:
		var d = pl.global_position.distance_to(global_position)
		if kind == "acid" and d < 38.0:
			# Reinigungs-Aura von Mr. Scrubbs: Säure wird aufgewischt und heilt
			pl.heal(2.0)
			Juice.float_text_at(global_position, 20, "Sauber gewischt!", Color(0.6, 1, 0.8), 16)
			Juice.burst(global_position, Color(0.6, 1, 0.8), 8, 120.0, 0.4, 3.0)
			duration = _t - telegraph
			return
		if kind == "heal" and d < radius and do_tick:
			pl.heal(2.0)
		if d < radius:
			if slow_player < 1.0:
				pl.apply_slow(slow_player, 0.3)
			if do_tick and tick_player > 0.0:
				pl.take_damage(tick_player, global_position, true)
	if slow_enemy < 1.0 or (do_tick and tick_enemy > 0.0):
		for e in Game.enemies:
			if not is_instance_valid(e) or e.dead:
				continue
			if e.global_position.distance_to(global_position) < radius + e.data.radius * 0.5:
				if slow_enemy < 1.0:
					e.apply_slow(slow_enemy, 0.3)
				if do_tick and tick_enemy > 0.0:
					e.take_hit(tick_enemy, Vector2.ZERO, 0.0, false, {tags = "puddle", quiet = true})

func _draw() -> void:
	var c := color
	if not _active:
		var k := clampf(_t / maxf(0.01, telegraph), 0.0, 1.0)
		if fly_tex != null:
			var p := fly_from - global_position
			var pos := p.lerp(Vector2.ZERO, k)
			pos.y -= sin(k * PI) * 110.0
			var s := 44.0 / float(fly_tex.get_width())
			draw_set_transform(pos, k * 9.0, Vector2(s, s))
			draw_texture(fly_tex, -fly_tex.get_size() * 0.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var fc := c
		fc.a = 0.12 + 0.22 * k
		draw_circle(Vector2.ZERO, radius * k, fc)
		var oc := Color(1.0, 0.25, 0.2, 0.55 + 0.35 * sin(_t * 16.0)) if from_enemy else Color(1, 1, 1, 0.5)
		for i in 18:
			var a := TAU * i / 18.0
			draw_arc(Vector2.ZERO, radius, a, a + TAU / 36.0, 4, oc, 3.0)
		if not from_enemy:
			return
		# Warndreieck mit Ausrufezeichen (Form statt nur Farbe)
		var tri := PackedVector2Array([Vector2(0, -22), Vector2(-17, 8), Vector2(17, 8)])
		draw_colored_polygon(tri, Color(1.0, 0.85, 0.15, 0.9))
		draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.15, 0.1, 0.05), 2.5)
		draw_string(ThemeDB.fallback_font, Vector2(-4, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.1, 0.05, 0.0))
		return
	if duration <= 0.0:
		return
	var fa := clampf(_fade, 0.0, 1.0)
	c.a = 0.28 * fa
	draw_circle(Vector2.ZERO, radius, c)
	var edge := color
	edge.a = 0.8 * fa
	draw_arc(Vector2.ZERO, radius, 0, TAU, 40, edge, 3.0)
	match pattern:
		"bubbles":
			for i in 7:
				var a := float(i) * 2.4 + _seed
				var rr := radius * (0.25 + 0.6 * fposmod(float(i) * 0.37, 1.0))
				var bp := Vector2(cos(a), sin(a) * 0.8) * rr
				var ph := fposmod(_t * 0.8 + float(i) * 0.31, 1.0)
				bp.y -= ph * 14.0
				var bc := edge
				bc.a *= 1.0 - ph
				draw_arc(bp, 3.0 + ph * 5.0, 0, TAU, 10, bc, 2.0)
		"waves":
			for i in 3:
				var y := -radius * 0.45 + i * radius * 0.45
				var pts := PackedVector2Array()
				for j in 11:
					pts.append(Vector2(-radius * 0.7 + j * radius * 0.14, y + sin(_t * 2.0 + j) * 3.0))
				draw_polyline(pts, edge, 2.0)
		"stripes":
			for i in 6:
				var x := -radius + i * radius * 0.4
				var a2 := Vector2(x, radius * 0.7)
				var b2 := Vector2(x + radius * 0.5, -radius * 0.7)
				if a2.length() < radius and b2.length() < radius:
					draw_line(a2, b2, edge, 2.0)
