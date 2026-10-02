class_name Enemy
extends CharacterBody2D
## Datengetriebener Gegner. Verhalten: chase | hop | charge | shoot | lob | slam (Boss siehe boss.gd).
## Jeder Angriff durchläuft: idle -> windup (Warnanimation) -> act -> recover.

var data: EnemyData
var hp := 20.0
var max_hp := 20.0
var dead := false
var rig: VisualRig
var kb_vel := Vector2.ZERO
var stun_t := 0.0
var slow_t := 0.0
var slow_mult := 1.0
var atk := "idle"
var atk_t := 0.0
var atk_cd := 1.5
var act_dir := Vector2.RIGHT
var contact_cd := 0.0
var spawn_t := 0.5
var last_seen := Vector2.ZERO
var hp_mult := 1.0
var is_mini := false
var active := true

var _face := 1.0
var _walk_t := 0.0
var _wander_t := 0.0
var _wander_dir := Vector2.ZERO
var _bar_t := 0.0
var _dmg_accum := 0.0
var _dmg_text_t := 0.0
var _tex_path := ""
var _alt_tex: Texture2D
var _base_tex: Texture2D
var _strafe := 1.0
var _hit_flash_cd := 0.0
var glue_t := 0.0
var speed_boost := 1.0
var hunt := false
var glue_burst := 0.0

static var BossScript: GDScript

static func create(d: EnemyData, pos: Vector2, hp_mult_: float = 1.0, mini: bool = false) -> Enemy:
	var e: Enemy
	if d.behavior == "boss":
		if BossScript == null:
			BossScript = load("res://scripts/boss.gd")
		e = BossScript.new()
	else:
		e = Enemy.new()
	e.data = d
	e.hp_mult = hp_mult_
	e.is_mini = mini
	e.global_position = pos
	Game.arena.entities.add_child(e)
	return e

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	max_hp = data.hp * hp_mult * (0.35 if is_mini else 1.0)
	hp = max_hp
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = data.radius * (0.7 if is_mini else 1.0)
	cs.shape = sh
	cs.position = Vector2(0, -sh.radius)
	add_child(cs)
	rig = VisualRig.new()
	add_child(rig)
	_tex_path = data.textures[randi() % data.textures.size()]
	_base_tex = Db.tex(_tex_path)
	var h := data.height * (0.62 if is_mini else 1.0)
	rig.setup(_base_tex, h, data.radius * 2.6)
	if data.tex_alt != "":
		_alt_tex = Db.tex(data.tex_alt)
	if data.elite:
		rig.aura_color = Color(1.0, 0.3, 0.25)
	rig.pop_in()
	_face = 1.0
	last_seen = global_position
	atk_cd = randf_range(0.6, 1.8)
	add_to_group("enemy")
	add_to_group("overlay")
	Game.enemies.append(self)
	_walk_t = randf() * 10.0

func p(key: String, default = 0.0):
	return data.params.get(key, default)

func spd() -> float:
	return data.speed * slow_mult * speed_boost * Game.phase_mod("speed") * (1.2 if is_mini else 1.0)

func is_attacking() -> bool:
	return atk == "windup" or atk == "act"

func apply_slow(mult: float, t: float) -> void:
	slow_mult = minf(slow_mult, mult)
	slow_t = maxf(slow_t, t)

## Kaugummi: Gegner klebt fest und platzt nach kurzer Zeit (Flächenschaden)
func apply_glue(t: float, burst: float) -> void:
	if dead:
		return
	glue_t = maxf(glue_t, t)
	glue_burst = maxf(glue_burst, burst)
	rig.set_tint(Color(1.0, 0.55, 0.85))

func _glue_pop() -> void:
	var pos := global_position
	var b := glue_burst
	glue_t = 0.0
	glue_burst = 0.0
	rig.set_tint(Color.WHITE)
	Juice.ring(pos, 70.0, Color(1.0, 0.5, 0.8), 0.3, 6.0, true)
	Juice.burst(pos + Vector2(0, -20), Color(1.0, 0.5, 0.8), 14, 220.0, 0.5, 4.0, 360.0, Vector2.UP, 0.0, "circle")
	Sfx.play("splat", 1.3)
	Game.arena.stage.pulse_light(pos, Color(1.0, 0.5, 0.8), 1.2, 2.0, 0.2)
	for e in Game.enemies.duplicate():
		if is_instance_valid(e) and not e.dead and e != self and e.global_position.distance_to(pos) < 70.0 + e.data.radius:
			e.take_hit(b * 0.6, (e.global_position - pos).normalized(), 160.0, false, {tags = "pop"})
	take_hit(b, Vector2.UP, 0.0, false, {tags = "pop", quiet = true})

func stun(t: float) -> void:
	if dead:
		return
	stun_t = maxf(stun_t, t)
	if atk == "windup":
		_end_attack()
	rig.stunned = true
	Sfx.play("stun", randf_range(0.9, 1.2), -6.0)
	Juice.float_text_at(global_position, data.height - 24, "Betäubt!", Color(1, 0.9, 0.3), 15)

func _physics_process(delta: float) -> void:
	if dead or not active:
		return
	spawn_t -= delta
	if spawn_t > 0.0:
		return
	stun_t = maxf(0.0, stun_t - delta)
	rig.stunned = stun_t > 0.0
	slow_t = maxf(0.0, slow_t - delta)
	if slow_t <= 0.0:
		slow_mult = 1.0
	if glue_t > 0.0:
		glue_t -= delta
		slow_mult = minf(slow_mult, 0.2)
		if glue_t <= 0.0:
			_glue_pop()
	atk_cd -= delta
	contact_cd -= delta
	_bar_t = maxf(0.0, _bar_t - delta)
	_dmg_text_t -= delta
	if _dmg_text_t <= 0.0 and _dmg_accum > 0.0:
		Juice.float_text_at(global_position, data.height - 6, str(int(round(_dmg_accum))), Color(1, 1, 1), 15)
		_dmg_accum = 0.0
		_dmg_text_t = 0.28
	kb_vel = kb_vel.lerp(Vector2.ZERO, 1.0 - exp(-8.0 * delta))
	var pl = Game.player
	var target_ok: bool = pl != null and pl.is_targetable()
	if target_ok:
		last_seen = pl.global_position
	var to_target := last_seen - global_position
	var dist := to_target.length()
	var move := Vector2.ZERO
	if stun_t <= 0.0:
		move = _think(delta, to_target, dist, target_ok)
	velocity = move + kb_vel + _separation() * 70.0
	move_and_slide()
	_after_move(delta)
	_animate(delta, move)
	# Kontaktschaden
	if target_ok and contact_cd <= 0.0 and stun_t <= 0.0 and atk != "windup":
		var d2 = pl.global_position.distance_to(global_position)
		if d2 < data.radius + 13.0:
			var mult := (1.5 if atk == "act" else 1.0) * (1.0 + 0.1 * float(Game.difficulty))
			if pl.take_damage(data.contact_damage * mult, global_position):
				contact_cd = 0.8
				rig.squash(1.2, 0.85)
	queue_redraw()

func _after_move(_delta: float) -> void:
	if data.params.get("rattle", false) and randf() < 0.01:
		rig.squash(1.1, 0.92, 0.3)
		Sfx.play("locker", 1.9, -18.0)

func _separation() -> Vector2:
	var push := Vector2.ZERO
	for o in Game.enemies:
		if o == self or not is_instance_valid(o) or o.dead:
			continue
		var d = global_position - o.global_position
		var min_d: float = (data.radius + o.data.radius) * 0.9
		var l = d.length_squared()
		if l < min_d * min_d and l > 0.01:
			push += d.normalized() * (1.0 - sqrt(l) / min_d)
	return push

func _animate(delta: float, move: Vector2) -> void:
	var look_x := move.x if absf(move.x) > 6.0 else (last_seen.x - global_position.x)
	if data.faces_right and absf(look_x) > 4.0:
		var target := 1.0 if look_x > 0.0 else -1.0
		_face = lerpf(_face, target, 1.0 - exp(-16.0 * delta))
		rig.scale.x = _face
	elif not data.faces_right:
		rig.scale.x = 1.0
	if atk == "idle" or atk == "recover":
		var speed := move.length()
		if speed > 8.0:
			_walk_t += delta * (6.0 + speed * 0.05)
			rig.hop = absf(sin(_walk_t)) * 4.0
			rig.body.rotation = sin(_walk_t) * 0.07
		else:
			rig.hop = lerpf(rig.hop, 0.0, 0.3)
			rig.body.rotation = lerpf(rig.body.rotation, 0.0, 0.2)

# ---------------------------------------------------------------- Verhalten
func _think(delta: float, to_target: Vector2, dist: float, target_ok: bool) -> Vector2:
	match data.behavior:
		"hop": return _think_hop(delta, to_target, dist, target_ok)
		"charge": return _think_charge(delta, to_target, dist, target_ok)
		"shoot", "lob": return _think_ranged(delta, to_target, dist, target_ok)
		"slam": return _think_slam(delta, to_target, dist, target_ok)
	return _chase(delta, to_target, dist, target_ok)

func _chase(delta: float, to_target: Vector2, dist: float, target_ok: bool, mult: float = 1.0) -> Vector2:
	if target_ok:
		return to_target.normalized() * spd() * mult
	# Ziel verloren: zur letzten bekannten Position, dann herumirren
	if dist > 26.0:
		return to_target.normalized() * spd() * 0.5
	_wander_t -= delta
	if _wander_t <= 0.0:
		_wander_t = randf_range(0.6, 1.4)
		_wander_dir = Vector2.from_angle(randf() * TAU)
	return _wander_dir * spd() * 0.3

func _begin(state: String, t: float) -> void:
	atk = state
	atk_t = t

func _end_attack() -> void:
	atk = "idle"
	rig.hop = 0.0
	rig.body.scale = Vector2.ONE
	if _alt_tex != null and data.behavior != "boss":
		rig.set_texture(_base_tex)

func _think_hop(delta: float, to_target: Vector2, dist: float, target_ok: bool) -> Vector2:
	match atk:
		"idle":
			if atk_cd <= 0.0 and dist < 360.0 and target_ok:
				_begin("windup", p("windup", 0.55))
				act_dir = to_target.normalized()
				rig.squash(1.35, 0.7, p("windup", 0.55))
				Sfx.play("warn", 1.6, -12.0)
			return _chase(delta, to_target, dist, target_ok, 0.6)
		"windup":
			atk_t -= delta
			rig.body.scale = rig.body.scale.lerp(Vector2(1.3, 0.72), 0.2)
			if atk_t <= 0.0:
				act_dir = (last_seen - global_position).normalized()
				_begin("act", p("hop_time", 0.42))
				rig.squash(0.8, 1.3, 0.2)
			return Vector2.ZERO
		"act":
			atk_t -= delta
			var k: float = 1.0 - atk_t / p("hop_time", 0.42)
			rig.hop = sin(clampf(k, 0.0, 1.0) * PI) * 54.0
			if atk_t <= 0.0:
				rig.hop = 0.0
				rig.squash(1.4, 0.65, 0.35)
				Hazard.spawn(global_position, {kind = "sticky", radius = 44.0, telegraph = 0.0, duration = 4.0, slow_player = 0.5,
					color = Color(0.55, 0.85, 0.25), pattern = "waves", from_enemy = true})
				Sfx.play("splat", 1.0, -6.0)
				Juice.burst(global_position, Color(0.5, 0.85, 0.25), 8, 140.0, 0.4, 3.5)
				_begin("recover", 0.5)
			return act_dir * p("hop_speed", 400.0) * slow_mult
		"recover":
			atk_t -= delta
			if atk_t <= 0.0:
				atk = "idle"
				atk_cd = p("hop_cd", 2.6) * randf_range(0.8, 1.2)
			return Vector2.ZERO
	return Vector2.ZERO

func _think_charge(delta: float, to_target: Vector2, dist: float, target_ok: bool) -> Vector2:
	match atk:
		"idle":
			if atk_cd <= 0.0 and dist < p("trigger", 440.0) and dist > 90.0 and target_ok:
				_begin("windup", p("windup", 0.75))
				act_dir = to_target.normalized()
				rig.squash(1.15, 0.78, p("windup", 0.75))
				Sfx.play("warn", 0.8, -8.0)
			return _chase(delta, to_target, dist, target_ok)
		"windup":
			atk_t -= delta
			# Kopf senken + Zittern (Warnanimation)
			rig.body.scale = rig.body.scale.lerp(Vector2(1.12, 0.8), 0.25)
			rig.body.rotation = sin(atk_t * 60.0) * 0.06
			if atk_t <= 0.0:
				_begin("act", p("charge_time", 0.65))
				rig.squash(1.3, 0.8, 0.2)
				Juice.burst(global_position, Color(0.9, 0.9, 0.85, 0.8), 6, 120.0, 0.4, 3.0, 60.0, -act_dir)
			return Vector2.ZERO
		"act":
			atk_t -= delta
			rig.body.rotation = act_dir.x * 0.15
			if get_slide_collision_count() > 0 and atk_t < p("charge_time", 0.65) - 0.08:
				# Wand getroffen: benommen
				Juice.shake(0.2, act_dir)
				Sfx.play("kick", 1.0, -4.0)
				Juice.burst(global_position + act_dir * 20.0, Color(1, 1, 1), 6, 140.0, 0.3, 3.0)
				_begin("recover", 0.9)
				stun(0.9)
				return Vector2.ZERO
			if atk_t <= 0.0:
				_begin("recover", 0.6)
			return act_dir * p("charge_speed", 430.0) * slow_mult
		"recover":
			atk_t -= delta
			rig.body.rotation = lerpf(rig.body.rotation, 0.0, 0.2)
			if atk_t <= 0.0:
				atk = "idle"
				atk_cd = p("charge_cd", 2.8) * randf_range(0.85, 1.2)
				rig.body.scale = Vector2.ONE
			return Vector2.ZERO
	return Vector2.ZERO

func _think_ranged(delta: float, to_target: Vector2, dist: float, target_ok: bool) -> Vector2:
	var pref: float = 70.0 if hunt else p("pref", 280.0)
	match atk:
		"idle":
			var v := Vector2.ZERO
			if not target_ok:
				v = _chase(delta, to_target, dist, false)
			elif dist > pref + 30.0:
				v = to_target.normalized() * spd()
			elif dist < pref - 70.0:
				v = -to_target.normalized() * spd() * 0.9
			else:
				_wander_t -= delta
				if _wander_t <= 0.0:
					_wander_t = randf_range(0.8, 1.8)
					_strafe = -_strafe
				v = to_target.normalized().orthogonal() * _strafe * spd() * 0.6
			var cd_key := "lob_cd" if data.behavior == "lob" else "shoot_cd"
			if atk_cd <= 0.0 and dist < 560.0 and target_ok:
				_begin("windup", p("windup", 0.5))
				if _alt_tex != null:
					rig.set_texture(_alt_tex)
				rig.squash(0.85, 1.25, p("windup", 0.5))
				Sfx.play("warn", 1.2, -10.0)
				atk_cd = p(cd_key, 2.5)
			return v
		"windup":
			atk_t -= delta
			rig.body.rotation = sin(atk_t * 40.0) * 0.05
			if atk_t <= 0.0:
				_fire_ranged()
				_begin("recover", 0.35)
			return Vector2.ZERO
		"recover":
			atk_t -= delta
			if atk_t <= 0.0:
				atk = "idle"
				atk_cd = p("lob_cd" if data.behavior == "lob" else "shoot_cd", 2.5) * randf_range(0.85, 1.25)
				if _alt_tex != null:
					rig.set_texture(_base_tex)
			return Vector2.ZERO
	return Vector2.ZERO

func _fire_ranged() -> void:
	var pl = Game.player
	if pl == null:
		return
	var from := global_position + Vector2(0, -data.height * 0.55)
	rig.squash(1.2, 0.85, 0.2)
	if data.behavior == "shoot":
		var dir: Vector2 = ((pl.global_position + Vector2(0, -22)) - from).normalized()
		Projectile.create(Game.arena.fx_layer, from, dir * p("proj_speed", 280.0), {
			team = "enemy", kind = "pencil", damage = p("proj_dmg", 7.0), radius = 7.0, life = 3.0,
			tex = Db.tex(p("proj_icon", Db.p_icon(10))), tex_scale = p("proj_scale", 0.5), color = Color(1, 0.8, 0.3),
		})
		Sfx.play("shoot_pea", 0.7, -6.0)
	else:
		var predict: Vector2 = pl.global_position + pl.velocity * 0.4
		var cfg := {
			kind = "impact", radius = p("radius", 55.0), telegraph = p("fly_time", 0.95), burst_player = p("dmg", 10.0),
			color = Color(1.0, 0.7, 0.3), pattern = "stripes", fly_tex = Db.tex(p("fly_icon", "")), fly_from = from,
			from_enemy = true, sound = "splat",
		}
		if p("puddle", "") == "acid":
			cfg.color = Color(0.5, 1.0, 0.3)
			cfg.follow_up = {kind = "acid", radius = p("radius", 55.0) * 0.9, telegraph = 0.0, duration = 5.0, tick_player = 5.0, tick_enemy = 7.0,
				color = Color(0.5, 1.0, 0.3), pattern = "bubbles", from_enemy = true}
		Hazard.spawn(predict, cfg)

func _think_slam(delta: float, to_target: Vector2, dist: float, target_ok: bool) -> Vector2:
	match atk:
		"idle":
			if atk_cd <= 0.0 and dist < p("trigger", 150.0) and target_ok:
				_begin("windup", p("windup", 0.9))
				if _alt_tex != null:
					rig.set_texture(_alt_tex)
				rig.squash(0.9, 1.25, p("windup", 0.9))
				Hazard.spawn(global_position, {kind = "slam", radius = p("slam_radius", 125.0), telegraph = p("windup", 0.9),
					burst_player = p("slam_dmg", 20.0), kb = 520.0, color = Color(1.0, 0.5, 0.2), pattern = "stripes",
					from_enemy = true, sound = "explosion"})
				Sfx.play("boss_roar", 1.5, -10.0)
			return _chase(delta, to_target, dist, target_ok)
		"windup":
			atk_t -= delta
			rig.body.rotation = sin(atk_t * 50.0) * 0.04
			rig.body.scale = rig.body.scale.lerp(Vector2(1.0, 1.18), 0.15)
			if atk_t <= 0.0:
				rig.squash(1.4, 0.6, 0.4)
				if _alt_tex != null:
					rig.set_texture(_base_tex)
				_begin("recover", 0.8)
			return Vector2.ZERO
		"recover":
			atk_t -= delta
			if atk_t <= 0.0:
				atk = "idle"
				atk_cd = p("slam_cd", 3.0) * randf_range(0.9, 1.2)
				rig.body.scale = Vector2.ONE
			return Vector2.ZERO
	return Vector2.ZERO

# ---------------------------------------------------------------- Schaden / Tod
func _mat_color() -> Color:
	match data.material:
		"slime": return Color(0.45, 0.85, 0.3)
		"paper": return Color(0.95, 0.95, 0.9)
		"fur": return Color(0.5, 0.35, 0.25)
		"glass": return Color(0.7, 0.9, 1.0)
		"cloth": return Color(0.8, 0.45, 0.8)
		"meat": return Color(0.7, 0.65, 0.3)
		"metal": return Color(0.6, 0.68, 0.8)
	return Color.WHITE

func take_hit(dmg: float, dir: Vector2, kb: float, crit: bool, opts: Dictionary = {}) -> void:
	if dead or spawn_t > 0.2:
		return
	hp -= dmg
	_bar_t = 3.0
	Game.stats.damage_dealt += dmg
	var quiet: bool = opts.get("quiet", false)
	rig.flash(0.1)
	if not quiet:
		var mass := 1.0 + (data.radius - 14.0) * 0.06
		if data.elite:
			mass += 1.0
		kb_vel += dir * kb / mass
		if kb > 150.0 and not data.elite:
			stun_t = maxf(stun_t, 0.12)
		if rig._tw == null or not rig._tw.is_running():
			var ax := absf(dir.x)
			rig.squash(1.0 + 0.28 * ax - 0.1, 1.0 + 0.28 * (1.0 - ax) - 0.1, 0.25)
		Juice.burst(global_position + Vector2(0, -data.height * 0.4), _mat_color(), 4 if not crit else 9, 130.0, 0.35, 3.0, 100.0, dir)
	if crit:
		Game.stats.crits += 1
		Juice.float_text_at(global_position, data.height - 10, str(int(round(dmg))) + "!", Color(1, 0.85, 0.2), 28, true)
		Juice.hitstop(0.055)
		Juice.shake(0.3, dir)
		Juice.zoom_pop(0.02)
		rig.flash(0.14, Color(1, 0.9, 0.4))
	else:
		if dmg > 0.0:
			_dmg_accum += dmg
		if _dmg_text_t <= 0.0 and _dmg_accum > 0.0:
			Juice.float_text_at(global_position, data.height - 6, str(int(round(_dmg_accum))), Color(1, 1, 1), 15)
			_dmg_accum = 0.0
			_dmg_text_t = 0.28
	if opts.get("stun", 0.0) > 0.0:
		stun(opts.stun)
	if opts.get("slow", 0.0) > 0.0:
		apply_slow(1.0 - opts.slow, 1.2)
	if Game.player != null and Game.player.syn("Kunst") and opts.get("tags", "") != "puddle":
		apply_slow(0.75, 1.0)
	_on_damaged()
	if hp <= 0.0:
		die(dir, crit, str(opts.get("tags", "")))

func _on_damaged() -> void:
	pass

func die(dir: Vector2, crit: bool, tags: String = "") -> void:
	if dead:
		return
	dead = true
	Game.enemies.erase(self)
	Game.register_kill()
	if data.elite:
		Game.stats.elites += 1
	var pos := global_position
	var mc := _mat_color()
	Sfx.play("death", randf_range(0.9, 1.3), -6.0)
	var sc := mc
	sc.a = 0.5
	Game.arena.splat(pos, sc, 16.0 if not data.elite else 30.0)
	Juice.burst(pos + Vector2(0, -data.height * 0.4), mc, 14 if not data.elite else 28, 220.0, 0.55, 4.5, 360.0, Vector2.UP, 160.0)
	if data.material == "paper":
		Juice.burst(pos + Vector2(0, -data.height * 0.4), Color.WHITE, 8, 120.0, 0.9, 4.0, 360.0, Vector2.UP, 90.0)
	_drops(pos)
	if data.params.has("spawn_on_death"):
		_burst_open(pos)
	if data.params.get("split", false) and not is_mini:
		for i in 2:
			var m := Enemy.create(data, pos + Vector2.from_angle(randf() * TAU) * 22.0, hp_mult, true)
			m.spawn_t = 0.25
	if Game.player != null:
		Game.player.on_kill(pos, tags)
	collision_layer = 0
	set_physics_process(false)
	rig.stunned = false
	if data.elite:
		Juice.hitstop(0.07)
		Juice.shake(0.4)
	# Todesanimation: flachdrücken, wegschleudern, ausblenden
	var tw := create_tween()
	tw.set_parallel(true)
	rig.body.scale = Vector2(1.4, 0.5)
	tw.tween_property(rig.body, "rotation", dir.x * 1.2, 0.3)
	tw.tween_property(rig.body, "scale", Vector2(0.2, 0.2), 0.35).set_delay(0.05)
	tw.tween_property(rig, "modulate:a", 0.0, 0.3).set_delay(0.1)
	tw.tween_property(self, "global_position", pos + dir * 30.0, 0.3)
	tw.chain().tween_callback(queue_free)

## Spind-Mutant: Tür fliegt auf, Monster springen heraus
func _burst_open(pos: Vector2) -> void:
	Sfx.play("locker", 0.7)
	Sfx.play("splat", 0.8)
	Juice.shake(0.35)
	Juice.ring(pos, 80.0, Color(0.7, 0.8, 1.0), 0.35, 6.0, true)
	Juice.float_text_at(pos, data.height - 10, "Spind aufgebrochen!", Color(1, 0.9, 0.5), 18, true)
	var ids: Array = data.params.spawn_on_death
	for i in ids.size():
		var a := TAU * i / float(ids.size()) + randf() * 0.5
		var spawn_pos: Vector2 = Game.arena.clamp_to_arena(pos + Vector2.from_angle(a) * 36.0)
		var m: Enemy = Game.arena.spawn_enemy(ids[i], spawn_pos, hp_mult * 0.8)
		m.spawn_t = 0.3
		m.kb_vel = Vector2.from_angle(a) * 380.0

func _drops(pos: Vector2) -> void:
	var orbs := 1 if not data.elite else 5
	for i in orbs:
		Pickup.spawn("xp", maxi(1, int(data.xp / float(orbs))) if data.elite else data.xp * (1 if not is_mini else 0), pos + Vector2(0, -8), 140.0)
	if randf() < data.coin_chance * (0.5 if is_mini else 1.0):
		var coins := 1 if not data.elite else 3
		for i in coins:
			Pickup.spawn("coin", data.coin_value, pos, 130.0)
	if randf() < (0.03 if not data.elite else 0.4):
		Pickup.spawn("heal", 18, pos, 100.0)
	if randf() < (0.012 if not data.elite else 0.2):
		Pickup.spawn("rare", 1, pos, 60.0)

func _draw() -> void:
	# flache Bodenmarkierung (Sturmlauf-Pfeil etc.)
	if dead:
		return
	if atk == "windup":
		_draw_telegraph()

## Bildschirmebene: Gesundheitsbalken und Warndreieck über dem Kopf
func draw_overlay(c: Control, sp: Vector2) -> void:
	if dead or spawn_t > 0.0:
		return
	var h := data.height * (0.62 if is_mini else 1.0) * 1.12
	if (data.elite or _bar_t > 0.0) and data.behavior != "boss":
		var w := 44.0 if data.elite else 32.0
		var y := sp.y - h - 14.0
		c.draw_rect(Rect2(sp.x - w * 0.5 - 1, y - 1, w + 2, 8), Color(0, 0, 0, 0.8))
		var frac := clampf(hp / max_hp, 0.0, 1.0)
		c.draw_rect(Rect2(sp.x - w * 0.5, y, w * frac, 6), Color(1.0, 0.3, 0.25) if data.elite else Color(0.9, 0.2, 0.2))
	if atk == "windup":
		var top := sp.y - h - 26.0
		var tri := PackedVector2Array([Vector2(sp.x, top - 15), Vector2(sp.x - 12, top + 7), Vector2(sp.x + 12, top + 7)])
		c.draw_colored_polygon(tri, Color(1.0, 0.85, 0.15))
		c.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.15, 0.1, 0.05), 2.0)
		c.draw_string(ThemeDB.fallback_font, Vector2(sp.x - 4, top + 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.1, 0.05, 0.0))

func _draw_telegraph() -> void:
	if data.behavior == "charge" or data.behavior == "boss":
		var len: float = p("charge_speed", 440.0) * p("charge_time", 0.65)
		_draw_arrow(act_dir, len)

func _draw_arrow(d: Vector2, length: float) -> void:
	var a := Vector2(0, -8)
	var b := a + d * length
	var pulse := 0.4 + 0.3 * sin(Time.get_ticks_msec() * 0.03)
	draw_line(a, b, Color(1, 0.2, 0.2, pulse), 14.0)
	var n := d.orthogonal()
	draw_colored_polygon(PackedVector2Array([b + d * 26.0, b + n * 20.0, b - n * 20.0]), Color(1, 0.2, 0.2, pulse + 0.2))
