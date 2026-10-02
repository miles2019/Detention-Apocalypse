extends Enemy
## Mini-Boss: Frau Eisenhart, die Sportlehrerin.
## Angriffe: Medizinbälle (prallen ab), Trillerpfeifen-Schockwelle (betäubt), Sturmlauf.
## Phase 2 bei 50 % Lebenspunkten: ruft das Schatten-Völkerballteam, Angriffe werden schneller.

var phase2 := false
var _pattern := ""
var _last_pattern := ""
var _whistle_r := 0.0
var _ball_dirs: Array = []

func _ready() -> void:
	super._ready()
	active = false     # wird nach dem Boss-Intro vom Arena-Objekt aktiviert
	data.params = {charge_speed = 470.0, charge_time = 0.7}
	atk_cd = 1.5
	Game.boss_changed.emit(hp, max_hp, true)

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
			if _pattern == "balls" or _pattern == "charge":
				act_dir = (last_seen - global_position).normalized() if _pattern == "charge" else (last_seen - global_position).normalized()
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
	var options := ["balls", "whistle", "charge"]
	if dist < 160.0:
		options = ["whistle", "balls"]
	options.erase(_last_pattern)
	_pattern = options[randi() % options.size()]
	_last_pattern = _pattern
	var windup := 0.9
	match _pattern:
		"balls": windup = 0.85
		"whistle": windup = 1.1
		"charge": windup = 0.8
	if phase2:
		windup *= 0.8
	_begin("windup", windup)
	act_dir = to_target.normalized()
	rig.squash(1.1, 0.88, windup)
	Sfx.play("warn", 0.9, -4.0)
	Game.announce.emit("", "boss_warn")

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

func _on_damaged() -> void:
	Game.boss_changed.emit(maxf(hp, 0.0), max_hp, true)
	if not phase2 and hp <= max_hp * 0.5 and hp > 0.0:
		_enter_phase2()

func _enter_phase2() -> void:
	phase2 = true
	atk = "idle"
	atk_cd = 1.0
	rig.body.scale = Vector2.ONE
	rig.aura_color = Color(1.0, 0.25, 0.2)
	rig.flash(0.5, Color(1, 0.3, 0.2))
	Sfx.play("boss_roar")
	Juice.shake(0.8)
	Juice.zoom_pop(0.08)
	Juice.hitstop(0.12)
	Game.announce.emit("Phase 2! Frau Eisenhart ruft das Schatten-Völkerballteam!", "boss")
	Game.stamp_requested.emit("PHASE 2", Color(0.9, 0.2, 0.2))
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		var pos := global_position + Vector2.from_angle(a) * 150.0
		pos = Game.arena.clamp_to_arena(pos)
		var e := Enemy.create(Db.enemies["football"], pos, 0.7)
		e.rig.set_tint(Color(0.55, 0.5, 0.75))
		e.spawn_t = 0.4

func _draw_telegraph() -> void:
	if _pattern == "charge":
		_draw_arrow(act_dir, 470.0 * 0.7)
	elif _pattern == "balls":
		var n := 5 if phase2 else 3
		for i in n:
			var off := deg_to_rad(18.0) * (float(i) - (n - 1) * 0.5)
			var d := act_dir.rotated(off)
			draw_line(Vector2(0, -data.height * 0.6), Vector2(0, -data.height * 0.6) + d * 260.0, Color(1, 0.25, 0.2, 0.55), 5.0)
	elif _pattern == "whistle":
		var k := 1.0 - atk_t / 1.1
		draw_arc(Vector2(0, -20), 430.0 * 0.25 * clampf(k, 0.0, 1.0) + 20.0, 0, TAU, 32, Color(1, 0.9, 0.3, 0.7), 4.0)

func die(dir: Vector2, crit: bool, tags: String = "") -> void:
	if dead:
		return
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
	super.die(dir, crit, tags)
	Game.get_tree().create_timer(2.2, true, false, true).timeout.connect(Game.end_run.bind(true))

