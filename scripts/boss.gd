extends Enemy
## Kapitel-Bosse: Frau Eisenhart (Sport), Prof. Dr. Ätz (Chemie), Rektor Dr. Zorn (Verwaltung).
## Jedes Muster: windup (Warnung) -> act -> recover. Phase 2 bei 50 % Leben.

var phase2 := false
var _pattern := ""
var _last_pattern := ""
var _rule_t := 0.0
var _trail_t := 0.0
var _fire_cd := 6.0

func _ready() -> void:
	super._ready()
	active = false     # wird nach dem Boss-Intro von der Arena aktiviert
	data.params = {charge_speed = 470.0, charge_time = 0.7}
	atk_cd = 1.5
	Game.boss_changed.emit(hp, max_hp, true)

## Bosse laufen immer direkt auf Mr. Scrubbs zu – Tische und Regale im Weg werden einfach zertrümmert
func _seek(to_target: Vector2) -> Vector2:
	return to_target.normalized()

func _clear_path() -> bool:
	return true

func _after_move(_delta: float) -> void:
	if not active:
		return
	var dir := velocity.normalized() if velocity.length() > 5.0 else act_dir
	var n: int = Game.arena.smash_obstacles(global_position + Vector2(0, -data.radius), data.radius * rig.size_mul + 14.0, dir)
	if n > 0:
		rig.squash(1.25, 0.82, 0.3)
		Juice.hitstop(0.04)

func _patterns() -> Array:
	var info: Dictionary = Db.boss_info.get(data.id, {})
	return info.get("patterns", ["balls", "whistle", "charge"])

func _process(delta: float) -> void:
	if _rule_t > 0.0 and Game.state == Game.State.IN_RUN:
		_rule_t -= delta
		if _rule_t <= 0.0:
			Game.rule_block = ""
			Game.announce.emit("Die Schulregel wurde aufgehoben. Bitte wieder normal prügeln.", "boss")
	if phase2 and data.id == "zorn" and active and Game.state == Game.State.IN_RUN and not dead:
		_fire_cd -= delta
		if _fire_cd <= 0.0:
			_fire_cd = 7.0
			_fire_line(4)

func _think(delta: float, to_target: Vector2, dist: float, target_ok: bool) -> Vector2:
	match atk:
		"idle":
			if atk_cd <= 0.0 and target_ok:
				_start_pattern(to_target, dist)
			return _chase(delta, to_target, dist, target_ok, 0.9 if not phase2 else 1.15)
		"windup":
			atk_t -= delta
			rig.body.rotation = sin(atk_t * 45.0) * 0.05
			rig.body.scale = rig.body.scale.lerp(Vector2(1.08, 0.92) if _pattern != "whistle" else Vector2(0.92, 1.12), 0.2)
			if _pattern in ["balls", "charge", "files"]:
				act_dir = (last_seen - global_position).normalized()
			if atk_t <= 0.0:
				_do_pattern()
			return Vector2.ZERO
		"act":
			atk_t -= delta
			if _pattern == "charge":
				if get_slide_collision_count() > 0 and atk_t < 0.6:
					Juice.shake(0.5, act_dir)
					Sfx.play("explosion")
					Game.arena.room_react(global_position, 1.0)
					_begin("recover", 1.4)
					stun(1.2)
					return Vector2.ZERO
				if atk_t <= 0.0:
					_begin("recover", 0.7)
				return act_dir * 470.0 * slow_mult
			if _pattern == "pool":
				_trail_t -= delta
				if _trail_t <= 0.0:
					_trail_t = 0.28
					Hazard.spawn(global_position, {kind = "acid", radius = 48.0, telegraph = 0.0, duration = 6.0, tick_player = 5.0, tick_enemy = 5.0,
						color = Color(0.5, 1.0, 0.3), pattern = "bubbles", from_enemy = true})
				if atk_t <= 0.0:
					_begin("recover", 0.6)
				return (last_seen - global_position).normalized() * 190.0 * slow_mult
			if atk_t <= 0.0:
				_begin("recover", 0.6)
			return Vector2.ZERO
		"recover":
			atk_t -= delta
			rig.body.scale = rig.body.scale.lerp(Vector2.ONE, 0.2)
			rig.body.rotation = lerpf(rig.body.rotation, 0.0, 0.2)
			if atk_t <= 0.0:
				atk = "idle"
				atk_cd = (1.8 if not phase2 else 1.1) * randf_range(0.9, 1.2)
			return Vector2.ZERO
	return Vector2.ZERO

func _start_pattern(to_target: Vector2, dist: float) -> void:
	var options: Array = _patterns().duplicate()
	if dist < 160.0 and options.has("whistle"):
		options = ["whistle", "balls"]
	options.erase(_last_pattern)
	_pattern = options[randi() % options.size()]
	_last_pattern = _pattern
	var windup := 0.9
	match _pattern:
		"balls": windup = 0.85
		"whistle": windup = 1.1
		"charge": windup = 0.8
		"flasks": windup = 1.0
		"pool": windup = 0.7
		"files": windup = 0.8
		"rule": windup = 1.3
		"summon": windup = 1.0
		"fireline": windup = 0.9
		"slamwave": windup = 0.9
		"laser": windup = 1.0
		"geyser": windup = 0.9
		"clones": windup = 0.8
	if phase2:
		windup *= 0.8
	_begin("windup", windup)
	act_dir = to_target.normalized()
	rig.squash(1.1, 0.88, windup)
	Sfx.play("warn", 0.9, -4.0)

func _do_pattern() -> void:
	match _pattern:
		"balls":
			var n := 5 if phase2 else 3
			var from := global_position + Vector2(0, -data.height * 0.6)
			for i in n:
				var off := deg_to_rad(18.0) * (float(i) - (n - 1) * 0.5)
				Projectile.create(Game.arena.fx_layer, from, act_dir.rotated(off) * 300.0, {
					team = "enemy", kind = "ball", damage = 14.0, radius = 15.0, life = 7.0, bounce = 3,
					tex = Db.tex(Db.p_icon(3)), tex_scale = 1.1, spin = 8.0, color = Color(1, 1, 1),
				})
			Sfx.play("shoot_mega", 1.4, -2.0)
			rig.squash(1.25, 0.8, 0.3)
			Juice.shake(0.25, act_dir)
			_begin("act", 0.3)
		"whistle":
			Shockwave.create(Game.arena.fx_layer, global_position + Vector2(0, -20), {
				team = "enemy", max_radius = 430.0, duration = 0.85, damage = 8.0, knockback = 320.0, stun = 0.8,
				color = Color(1.0, 0.9, 0.3), thickness = 16.0,
			})
			Sfx.play("phase_Sport", 1.0, 0.0)
			Juice.shake(0.5)
			Juice.zoom_pop(0.05)
			Game.arena.room_react(global_position, 1.5)
			rig.squash(0.85, 1.25, 0.3)
			_begin("act", 0.5)
		"charge":
			_begin("act", 0.7)
			rig.squash(1.3, 0.8, 0.2)
			Sfx.play("boss_roar", 1.2, -4.0)
		"flasks":
			_flask_volley()
			rig.squash(0.85, 1.3, 0.3)
			_begin("act", 0.4)
		"pool":
			_trail_t = 0.0
			_begin("act", 1.7)
			Sfx.play("splat", 0.8)
		"files":
			_file_volley()
			_begin("act", 0.4)
		"rule":
			_announce_rule()
			_begin("act", 0.5)
		"summon":
			_summon(3 if not phase2 else 5)
			_begin("act", 0.5)
		"fireline":
			_fire_line(5 if not phase2 else 7)
			_begin("act", 0.5)
		"slamwave":
			_slam_wave()
			_begin("act", 0.6)
		"laser":
			_laser_cross()
			_begin("act", 0.5)
		"geyser":
			_geysers()
			_begin("act", 0.5)
		"clones":
			var ids2: Array = Db.boss_info.get(data.id, {}).get("summons", ["sheep"])
			for i in (2 if not phase2 else 3):
				var a2 := TAU * i / 3.0 + randf()
				var cp: Vector2 = Game.arena.clamp_to_arena(global_position + Vector2.from_angle(a2) * 130.0)
				var ce: Enemy = Game.arena.spawn_enemy(ids2[i % ids2.size()], cp, 0.9, "sprinter" if phase2 else "clown")
				ce.spawn_t = 0.35
			Juice.ring(global_position, 140.0, Color(1.0, 0.5, 0.8), 0.4, 6.0, true)
			Sfx.play("boss_roar", 1.5, -6.0)
			_begin("act", 0.5)

func _flask_volley() -> void:
	var pl = Game.player
	if pl == null:
		return
	var n := 7 if phase2 else 4
	var from := global_position + Vector2(0, -data.height * 0.6)
	for i in n:
		var p: Vector2 = pl.global_position + pl.velocity * 0.4
		if i > 0:
			p = pl.global_position + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 190.0)
		p = Game.arena.clamp_to_arena(p)
		Hazard.spawn(p, {kind = "impact", radius = 58.0, telegraph = 1.15 + 0.12 * i, burst_player = 10.0,
			color = Color(0.5, 1.0, 0.3), pattern = "bubbles", fly_tex = Db.tex(Db.i_icon(9)), fly_from = from, from_enemy = true, sound = "splat",
			follow_up = {kind = "acid", radius = 54.0, telegraph = 0.0, duration = 5.0, tick_player = 5.0, tick_enemy = 6.0,
				color = Color(0.5, 1.0, 0.3), pattern = "bubbles", from_enemy = true}})
	Sfx.play("shoot_chalk", 0.8)

func _file_volley() -> void:
	var from := global_position + Vector2(0, -data.height * 0.6)
	var n := 9 if phase2 else 6
	var spd := 400.0 if phase2 else 330.0
	for i in n:
		var off := deg_to_rad(12.0) * (float(i) - (n - 1) * 0.5)
		Projectile.create(Game.arena.fx_layer, from, act_dir.rotated(off) * spd, {
			team = "enemy", kind = "pencil", damage = 11.0, radius = 11.0, life = 4.0,
			tex = Db.tex(Db.p_icon(8)), tex_scale = 0.8, color = Color(1, 1, 1),
		})
	Sfx.play("shoot_stapler", 0.7)
	Juice.shake(0.25, act_dir)
	rig.squash(1.2, 0.85, 0.3)

func _announce_rule() -> void:
	var block := "melee" if randf() < 0.5 else "ranged"
	Game.rule_block = block
	_rule_t = 7.0
	var para := randi() % 9 + 1
	var txt := "Schulregel §%d: Nahkampfwaffen sind ab sofort verboten!" % para
	if block == "ranged":
		txt = "Schulregel §%d: Fernkampfwaffen sind ab sofort verboten!" % para
	Game.arena.announcer.say(txt, "boss")
	Game.stamp_requested.emit("REGEL: %s" % ("Kein Nahkampf" if block == "melee" else "Kein Fernkampf"), Color(0.9, 0.2, 0.2))
	Juice.shake(0.4)
	Sfx.play("boss_roar", 1.4, -4.0)
	_summon(2)

func _summon(n: int) -> void:
	var ids: Array = Db.boss_info.get(data.id, {}).get("summons", ["nerd", "nerd", "chemist", "bird", "bird"])
	for i in n:
		var a := TAU * i / float(n) + randf()
		var pos: Vector2 = Game.arena.clamp_to_arena(global_position + Vector2.from_angle(a) * 150.0)
		var e: Enemy = Game.arena.spawn_enemy(ids[i % ids.size()], pos, 0.8)
		e.spawn_t = 0.35
	Juice.ring(global_position, 150.0, Color(1, 0.8, 0.4), 0.4, 6.0, true)

## Drei Einschläge nacheinander: unter dem Boss, beim Spieler, vor dem Spieler
func _slam_wave() -> void:
	var pl = Game.player
	if pl == null:
		return
	var spots: Array = [global_position, pl.global_position, pl.global_position + pl.velocity * 0.6]
	if phase2:
		spots.append(pl.global_position + Vector2.from_angle(randf() * TAU) * 140.0)
	for i in spots.size():
		var p: Vector2 = Game.arena.clamp_to_arena(spots[i])
		Hazard.spawn(p, {kind = "slam", radius = 150.0 if i == 0 else 115.0, telegraph = 0.55 + 0.4 * i, burst_player = 16.0, kb = 480.0,
			color = Color(1.0, 0.5, 0.2), pattern = "stripes", from_enemy = true, sound = "explosion"})
	rig.squash(1.4, 0.6, 0.4)
	Sfx.play("boss_roar", 1.2, -4.0)

## Stromkreuz: Linien aus Stromfeldern in vier (Phase 2: acht) Richtungen
func _laser_cross() -> void:
	var dirs := 8 if phase2 else 4
	var base := randf() * TAU
	for k in dirs:
		var d := Vector2.from_angle(base + TAU * k / float(dirs))
		for i in 5:
			var p: Vector2 = global_position + d * (90.0 + i * 92.0)
			if not Arena.PLAY.grow(-20.0).has_point(p):
				break
			Hazard.spawn(p, {kind = "shock", radius = 46.0, telegraph = 0.9 + 0.05 * i, duration = 1.6, tick_player = 8.0, tick_enemy = 4.0,
				color = Color(1.0, 0.92, 0.3), pattern = "stripes", from_enemy = true})
	Sfx.play("phase_Physik", 1.6, -2.0)
	Juice.shake(0.3)

## Geysire: Wassereinschläge rund um den Spieler, die Pfützen hinterlassen
func _geysers() -> void:
	var pl = Game.player
	if pl == null:
		return
	var n := 8 if phase2 else 5
	for i in n:
		var p: Vector2 = pl.global_position + pl.velocity * 0.3
		if i > 0:
			p = pl.global_position + Vector2.from_angle(randf() * TAU) * randf_range(70.0, 220.0)
		p = Game.arena.clamp_to_arena(p)
		Hazard.spawn(p, {kind = "impact", radius = 62.0, telegraph = 1.0 + 0.1 * i, burst_player = 11.0, kb = 260.0,
			color = Color(0.4, 0.75, 1.0), pattern = "waves", from_enemy = true, sound = "splat",
			follow_up = {kind = "water", radius = 70.0, telegraph = 0.0, duration = 4.0, slow_player = 0.75, slow_enemy = 0.85,
				color = Color(0.4, 0.75, 1.0), pattern = "waves", from_enemy = true}})
	Sfx.play("splat", 0.6)
	rig.squash(0.85, 1.3, 0.3)

func _fire_line(n: int) -> void:
	var pl = Game.player
	if pl == null:
		return
	var dir: Vector2 = (pl.global_position - global_position).normalized()
	for i in n:
		var p: Vector2 = Game.arena.clamp_to_arena(global_position + dir * (90.0 + i * 100.0))
		Hazard.spawn(p, {kind = "fire", radius = 70.0, telegraph = 0.9 + 0.12 * i, duration = 5.0, tick_player = 6.0, tick_enemy = 9.0,
			color = Color(1.0, 0.55, 0.15), pattern = "bubbles", from_enemy = true})
	Sfx.play("boss_roar", 1.3, -6.0)

func _on_damaged() -> void:
	Game.boss_changed.emit(maxf(hp, 0.0), max_hp, true)
	if not phase2 and hp <= max_hp * 0.5 and hp > 0.0:
		_enter_phase2()

func _enter_phase2() -> void:
	phase2 = true
	atk = "idle"
	atk_cd = 1.4
	rig.body.scale = Vector2.ONE
	rig.aura_color = Color(1.0, 0.25, 0.2)
	rig.flash(0.5, Color(1, 0.3, 0.2))
	Sfx.play("boss_roar")
	Juice.shake(0.8)
	Juice.zoom_pop(0.08)
	Juice.hitstop(0.14)
	Game.arena.cinematic_focus(global_position, 1.4, 1.1)
	Game.stamp_requested.emit("PHASE 2", Color(0.9, 0.2, 0.2))
	match data.id:
		"etz":
			Game.arena.announcer.say("Prof. Dr. Ätz trinkt seine eigene Formel und wird... größer. Das ist nicht im Lehrplan.", "boss")
			rig.size_mul = 1.35
			speed_boost = 1.3
			rig.set_tint(Color(0.75, 1.0, 0.7))
			Game.arena.events.start("raeumung")
		"zorn":
			Game.arena.announcer.say("Räumungsübung! Ich wiederhole: Dies ist eine Räumungsübung. Die Arena wird kleiner.", "boss")
			speed_boost = 1.2
			_fire_cd = 2.0
		"coach":
			Game.arena.announcer.say("Phase 2! Frau Eisenhart ruft das Schatten-Völkerballteam!", "boss")
			for i in 3:
				var a := TAU * i / 3.0 + 0.5
				var pos: Vector2 = Game.arena.clamp_to_arena(global_position + Vector2.from_angle(a) * 150.0)
				var e := Enemy.create(Db.enemies["football"], pos, 0.7)
				e.rig.set_tint(Color(0.55, 0.5, 0.75))
				e.spawn_t = 0.4
		_:
			Game.arena.announcer.say(Db.boss_info.get(data.id, {}).get("phase2", "Phase 2!"), "boss")
			speed_boost = 1.2
			_summon(3)

func _draw_telegraph() -> void:
	if _pattern == "charge":
		_draw_arrow(act_dir, 470.0 * 0.7)
	elif _pattern == "balls" or _pattern == "files":
		var n := (5 if phase2 else 3) if _pattern == "balls" else (9 if phase2 else 6)
		for i in n:
			var off := deg_to_rad(18.0 if _pattern == "balls" else 12.0) * (float(i) - (n - 1) * 0.5)
			var d := act_dir.rotated(off)
			draw_line(Vector2(0, -data.height * 0.6), Vector2(0, -data.height * 0.6) + d * 260.0, Color(1, 0.25, 0.2, 0.55), 5.0)
	elif _pattern == "whistle":
		var k := 1.0 - atk_t / 1.1
		draw_arc(Vector2(0, -20), 430.0 * 0.25 * clampf(k, 0.0, 1.0) + 20.0, 0, TAU, 32, Color(1, 0.9, 0.3, 0.7), 4.0)

func die(dir: Vector2, crit: bool, tags: String = "") -> void:
	if dead:
		return
	Game.rule_block = ""
	Game.boss_changed.emit(0.0, max_hp, false)
	Juice.slowmo(1.0, 0.18)
	Juice.shake(1.0)
	Juice.zoom_pop(-0.1)
	Sfx.play("boss_roar", 0.6)
	for e in Game.enemies.duplicate():
		if e != self and is_instance_valid(e) and not e.dead:
			e.take_hit(9999.0, Vector2.UP, 0.0, false, {quiet = true})
	for i in 14:
		Pickup.spawn("coin", 2, global_position, 220.0)
	for i in 6:
		Pickup.spawn("xp", 10, global_position + Vector2(0, -20), 220.0)
	Pickup.spawn("rare", 1, global_position, 100.0)
	Game.stats.bosses += 1
	super.die(dir, crit, tags)
	if Game.endless:
		Game.get_tree().create_timer(2.2, true, false, true).timeout.connect(Game.arena.endless_boss_done)
	else:
		Game.get_tree().create_timer(2.2, true, false, true).timeout.connect(Game.end_run.bind(true))
