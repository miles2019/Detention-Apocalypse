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
var grow := 0.0
var sprite: Sprite2D
var bb: Billboard3D
var mesh3: MeshInstance3D
var _rot := 0.0
static var _mats := {}
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
		bb.setup(tex, tex.get_height() * tex_scale)
		bb.sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	else:
		mesh3 = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 10
		sm.rings = 5
		mesh3.mesh = sm
		mesh3.material_override = _mat_for(kind)
		mesh3.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stage.fx3.add_child(mesh3)
	_update3d(0.0)
	if bb != null:
		bb.set_body(Vector2(1.6, 0.6), _rot3())
		var tw := create_tween()
		tw.tween_method(func(k: float): if bb != null: bb.set_body(Vector2(lerpf(1.6, 1.0, k), lerpf(0.6, 1.0, k)), _rot3()), 0.0, 1.0, 0.1)

static func _mat_for(k: String) -> StandardMaterial3D:
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	match k:
		"flame": m.albedo_color = Color(1.0, 0.55, 0.12)
		"pea": m.albedo_color = Color(0.5, 0.85, 0.28)
		"drop": m.albedo_color = Color(0.4, 0.8, 1.0)
		_: m.albedo_color = Color.WHITE
	_mats[k] = m
	return m

func _rot3() -> float:
	return atan2(-vel.y * 0.8, vel.x) if spin == 0.0 else _rot

func _update3d(delta: float) -> void:
	if spin != 0.0:
		_rot += spin * delta
	var stage: Stage3D = Game.arena.stage
	if bb != null:
		bb.place(global_position, 26.0)
		bb.set_body(Vector2.ONE, _rot3())
	elif mesh3 != null:
		var r := radius
		if kind == "flame":
			var k := clampf(_age / life, 0.0, 1.0)
			r = radius * (0.9 + k * 0.5) * (1.0 - k * 0.55)
		mesh3.position = stage.to3(global_position, 24.0)
		mesh3.scale = Vector3.ONE * r * Stage3D.S

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
	global_position += vel * delta
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
			_hit[id] = true
			var r: Dictionary = Game.player.roll_damage(damage, crit_bonus)
			var kb: float = knockback * Game.player.kb_mult * Game.phase_mod("kb")
			var dir := vel.normalized()
			e.take_hit(r.dmg, dir, kb, r.crit, {stun = stun, slow = slow, tags = weapon_id})
			Sfx.play_hit(r.crit)
			Juice.burst(global_position, color, 5, 150.0, 0.3, 3.0, 120.0, dir)
			if pierce > 0:
				pierce -= 1
			else:
				_expire(true)
				return

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
		Juice.burst(global_position, Color(0.85, 0.85, 0.8, 0.8), 3, 60.0, 0.25, 2.0)
	queue_free()
