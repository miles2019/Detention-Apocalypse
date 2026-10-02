class_name Projectile
extends Node2D
## Projektil (Spieler- oder Gegner-Team). Trefferprüfung per Distanz gegen Game.enemies bzw. Spieler.

var team := "player"
var kind := "bullet"       # bullet | flame | pea | drop | ball | pencil
var vel := Vector2.ZERO
var damage := 10.0
var pierce := 0
var bounce := 0
var life := 2.0
var radius := 8.0
var knockback := 100.0
var spin := 0.0
var color := Color.WHITE
var crit_bonus := 0.0
var stun := 0.0
var slow := 0.0
var tex: Texture2D
var tex_scale := 0.5
var weapon_id := ""
var chain := 0
var sticky := 0.0
var combo := false
var rehit := 0.0
var homing := false
var steer_speed := 400.0
var grow := 0.0
var sprite: Sprite2D
var bb: Billboard3D
var mesh3: MeshInstance3D
var _rot := 0.0
var _trail_t := 0.0
static var _mats := {}
const INF_T := 1.0e9
var _hit := {}
var _age := 0.0
var _dead := false

static func create(parent: Node, pos: Vector2, velocity: Vector2, props: Dictionary) -> Projectile:
	var p := Projectile.new()
	p.global_position = pos
	p.vel = velocity
	for k in props:
		p.set(k, props[k])
	parent.add_child(p)
	return p

func _ready() -> void:
	z_index = 15
	if team == "enemy":
		add_to_group("enemy_proj")
	visible = false     # 2D-Anteil nur Logik; Darstellung als 3D-Proxy
	_rot = vel.angle()
	var stage: Stage3D = Game.arena.stage
	if tex != null:
		bb = Billboard3D.new()
		stage.sprites.add_child(bb)
		bb.setup(tex, tex.get_height() * tex_scale, false)
	else:
		mesh3 = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 10
		sm.rings = 5
		mesh3.mesh = sm
		mesh3.material_override = _mat_for(kind, color)
		mesh3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind == "flame" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		stage.fx3.add_child(mesh3)
	_update3d(0.0)
	if bb != null:
		bb.set_body(Vector2(1.6, 0.6), _rot3())
		var tw := create_tween()
		tw.tween_method(func(k: float): if bb != null: bb.set_body(Vector2(lerpf(1.6, 1.0, k), lerpf(0.6, 1.0, k)), _rot3()), 0.0, 1.0, 0.1)

static func _mat_for(k: String, col: Color) -> StandardMaterial3D:
	var key := k + str(col.to_html())
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match k:
		"flame": m.albedo_color = Color(1.0, 0.55, 0.12)
		"pea": m.albedo_color = col.lightened(0.1)
		"drop": m.albedo_color = col
		_: m.albedo_color = Color.WHITE
	_mats[key] = m
	return m

func _rot3() -> float:
	return atan2(-vel.y * 0.8, vel.x) if spin == 0.0 else _rot

func _update3d(delta: float) -> void:
	if spin != 0.0:
		_rot += spin * delta
	var stage: Stage3D = Game.arena.stage
	var sp := clampf(vel.length() / 800.0, 0.0, 1.0)
	if bb != null:
		bb.place(global_position, 26.0)
		var st := 1.0 + (0.3 * sp if spin == 0.0 else 0.0)
		bb.set_body(Vector2(st, 1.0 / sqrt(st)), _rot3())
	elif mesh3 != null:
		var r := radius
		if kind == "flame":
			var k := clampf(_age / life, 0.0, 1.0)
			r = radius * (0.9 + k * 0.5) * (1.0 - k * 0.55)
		mesh3.position = stage.to3(global_position, 24.0)
		var stretch := 1.0 + (0.9 * sp if kind != "flame" else 0.0)
		mesh3.basis = Basis(Vector3.UP, -vel.angle()) * Basis.from_scale(Vector3(stretch, 1.0, 1.0) * r * Stage3D.S)

func _exit_tree() -> void:
	if bb != null and is_instance_valid(bb):
		bb.queue_free()
	if mesh3 != null and is_instance_valid(mesh3):
		mesh3.queue_free()

func _physics_process(delta: float) -> void:
	if _dead:
		return
	_age += delta
	if _age >= life:
		_expire()
		return
	if homing and Game.player != null:
		var tp: Vector2 = Game.player.aim_point
		var want := (tp - global_position)
		if want.length() > 8.0:
			vel = vel.lerp(want.normalized() * steer_speed, 1.0 - exp(-3.2 * delta))
	global_position += vel * delta
	_trail_t -= delta
	if _trail_t <= 0.0 and kind != "flame":
		_trail_t = 0.03 if kind != "ball" else 0.045
		var tc := color.lightened(0.25)
		tc.a = 0.8
		Game.arena.stage.emit_trail(global_position, 24.0, tc, kind == "ball")
	if grow != 0.0:
		radius += grow * delta
	var arena = Game.arena
	if arena != null:
		var res = arena.bounce_off(global_position, vel, radius)
		if res != null:
			global_position = res.pos
			vel = res.vel
			if kind == "flame":
				_expire()
				return
			if bounce > 0:
				bounce -= 1
				if team == "player":
					Sfx.play("click", 1.6, -10.0)
				else:
					Sfx.play("kick", 1.8, -8.0)
				Juice.burst(global_position, color, 4, 90.0, 0.25, 2.0)
			else:
				_expire()
				return
	if team == "player":
		_check_enemies()
		if not _dead and arena != null:
			for b in arena.boards:
				if is_instance_valid(b) and b.try_hit(self):
					return
			for n in arena.bins:
				if is_instance_valid(n):
					n.try_kick_by_projectile(self)
	else:
		_check_player()
	_update3d(delta)

func _check_enemies() -> void:
	for e in Game.enemies:
		if not is_instance_valid(e) or e.dead:
			continue
		var id = e.get_instance_id()
		if _hit.has(id):
			continue
		if global_position.distance_to(e.global_position + Vector2(0, -e.data.height * 0.4)) < radius + e.data.radius:
			_hit[id] = (_age + rehit) if rehit > 0.0 else INF_T
			var cm: float = Game.player.combo_mult() if combo else 1.0
			var r: Dictionary = Game.player.roll_damage(damage * cm, crit_bonus)
			var kb: float = knockback * Game.player.kb_mult * Game.phase_mod("kb")
			var dir := vel.normalized()
			e.take_hit(r.dmg, dir, kb, r.crit, {stun = stun, slow = slow, tags = weapon_id})
			if combo:
				Game.player.combo_hit()
			if sticky > 0.0:
				e.apply_glue(sticky, r.dmg * 2.2)
			if chain > 0:
				_chain_from(e, r.dmg)
			Sfx.play_hit(r.crit)
			Juice.burst(global_position, color, 5, 150.0, 0.3, 3.0, 120.0, dir)
			if kind == "ball":
				Juice.shake(0.12, dir)
				Game.arena.stage.pulse_light(global_position, Color(1, 0.95, 0.8), 1.0, 2.0, 0.15)
			if pierce > 0:
				pierce -= 1
			else:
				_expire(true)
				return

## Einschlag-Juice: Blitz, Ring, Rückstoß-Funken, Boden-Spritzer je nach Projektilart
func _impact(dir: Vector2, crit: bool) -> void:
	var stage: Stage3D = Game.arena.stage
	var big := 1.0 + (0.7 if crit else 0.0)
	stage.flash_at(global_position, 24.0, color.lightened(0.55), 1.0 + (1.0 if crit else 0.0))
	Juice.ring(global_position, (28.0 + (16.0 if crit else 0.0)) * (1.6 if kind == "ball" else 1.0), color, 0.22, 4.0)
	Juice.burst(global_position, color, int(8.0 * big), 250.0, 0.35, 3.0, 110.0, -dir, 0.0, "circle")
	Juice.burst(global_position, Color(1, 1, 1), 3, 170.0, 0.2, 2.0, 70.0, dir)
	match kind:
		"drop":
			if randf() < 0.5:
				Game.arena.splat(global_position, Color(0.4, 0.8, 1.0, 0.4), 11.0)
		"pea":
			if randf() < 0.4:
				Game.arena.splat(global_position, Color(0.5, 0.85, 0.3, 0.45), 8.0)
		"ball":
			Juice.shake(0.14, dir)
			stage.pulse_light(global_position, Color(1, 0.95, 0.8), 1.0, 2.0, 0.15)
			Juice.burst(global_position, Color(0.9, 0.85, 0.7, 0.8), 6, 120.0, 0.45, 5.0, 360.0, Vector2.UP, 0.0, "circle", 6.0)
		_:
			if crit:
				stage.pulse_light(global_position, color.lightened(0.4), 1.0, 1.8, 0.12)

## Kettenreaktion: Schaden springt auf nahe Gegner über (Büroklammer / Heftklammer-Hagel)
func _chain_from(src: Node, base: float) -> void:
	var jumped: Array = [src]
	var from: Node = src
	for i in chain:
		var nxt: Node = Game.nearest_enemy(from.global_position, 150.0, jumped)
		if nxt == null:
			break
		jumped.append(nxt)
		var d := base * 0.7
		ChainFX.spawn(from.global_position + Vector2(0, -from.data.height * 0.4), nxt.global_position + Vector2(0, -nxt.data.height * 0.4), color)
		nxt.take_hit(d, (nxt.global_position - from.global_position).normalized(), 60.0, false, {tags = "chain"})
		from = nxt

func _check_player() -> void:
	var pl = Game.player
	if pl == null or not pl.is_targetable():
		return
	if global_position.distance_to(pl.global_position + Vector2(0, -22)) < radius + 14.0:
		if pl.take_damage(damage, global_position):
			_expire(true)

func _expire(hit: bool = false) -> void:
	if _dead:
		return
	_dead = true
	if not hit and kind != "flame" and team == "player":
		Juice.burst(global_position, Color(0.85, 0.85, 0.8, 0.8), 5, 110.0, 0.35, 3.0, 120.0, -vel.normalized(), 0.0, "circle")
		Game.arena.stage.flash_at(global_position, 20.0, Color(1, 1, 0.9, 0.8), 1.0)
	queue_free()
