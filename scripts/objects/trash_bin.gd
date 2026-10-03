class_name TrashBin
extends Node2D
## Mülleimer: kann angestoßen werden und rollt wie eine Bowlingkugel durch Gegner.
## Zustände: verfügbar -> rollend (aktiviert) -> Cooldown -> verfügbar. Placeholder: 3D-Zylinder.

enum S { AVAILABLE, ROLLING, COOLDOWN }

var state := S.AVAILABLE
var vel := Vector2.ZERO
var timer := 0.0
var spin := 0.0
var _hit_cd := {}
var _wob := 0.0
var _pivot: Node3D
var _mat: StandardMaterial3D

func _ready() -> void:
	add_to_group("reactive")
	add_to_group("overlay")
	var stage: Stage3D = Game.arena.stage
	_pivot = Node3D.new()
	stage.props.add_child(_pivot)
	# Mülleimer-Modell (siehe CREDITS.md); ohne Modell bleibt der Zylinder-Platzhalter
	var model := ModelLib.instance(ModelLib.TRASH, "")
	if model != null:
		var msize: Vector3 = model.get_meta("size")
		var ms := 0.46 / maxf(msize.y, 0.0001)
		model.scale = Vector3(ms, ms, ms)
		model.position.y = -0.21
		_pivot.add_child(model)
		_mat = model.get_surface_override_material(0)
		for si in model.mesh.get_surface_count():
			model.set_surface_override_material(si, _mat)
		_mat.albedo_color = Color(0.5, 0.55, 0.6)
		return
	var cm := CylinderMesh.new()
	cm.top_radius = 0.19
	cm.bottom_radius = 0.16
	cm.height = 0.42
	var body := stage.make_mesh_node(cm, Color(0.5, 0.55, 0.6))
	_mat = body.material_override
	body.get_parent().remove_child(body)
	_pivot.add_child(body)
	body.position.y = 0.0
	var lid := CylinderMesh.new()
	lid.top_radius = 0.21
	lid.bottom_radius = 0.21
	lid.height = 0.05
	var lm := stage.make_mesh_node(lid, Color(0.38, 0.42, 0.48))
	lm.get_parent().remove_child(lm)
	_pivot.add_child(lm)
	lm.position.y = 0.23
	for i in 3:
		var rib := stage.make_mesh_node(BoxMesh.new(), Color(0.2, 0.22, 0.26))
		rib.mesh.size = Vector3(0.03, 0.34, 0.03)
		rib.get_parent().remove_child(rib)
		_pivot.add_child(rib)
		var a := TAU * i / 3.0
		rib.position = Vector3(cos(a) * 0.178, 0.0, sin(a) * 0.178)

func _exit_tree() -> void:
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.queue_free()

func kick(dir: Vector2, power: float) -> void:
	if state != S.AVAILABLE:
		return
	state = S.ROLLING
	vel = dir.normalized() * power
	_hit_cd.clear()
	Sfx.play("kick")
	Juice.shake(0.15, dir)
	Juice.burst(global_position, Color(0.8, 0.8, 0.8), 6, 120.0, 0.3, 3.0, 90.0, dir)
	Game.stats.objects_used += 1
	Juice.float_text_at(global_position, 50, "Strike!", Color(1, 0.85, 0.3), 16, true)

func try_kick_by_projectile(proj: Node) -> void:
	if state == S.AVAILABLE and proj.global_position.distance_to(global_position) < 28.0:
		kick(proj.vel, 460.0)

func react(pos: Vector2, strength: float) -> void:
	if pos.distance_to(global_position) < 300.0:
		_wob = maxf(_wob, strength * 0.5)

func _process(delta: float) -> void:
	_wob = maxf(0.0, _wob - delta * 2.0)
	var pl = Game.player
	match state:
		S.AVAILABLE:
			if pl != null and pl.global_position.distance_to(global_position) < 38.0 and pl.velocity.length() > 90.0:
				var to = (global_position - pl.global_position).normalized()
				if to.dot(pl.velocity.normalized()) > 0.25:
					kick(to, 560.0)
		S.ROLLING:
			global_position += vel * delta
			vel *= exp(-0.8 * delta)
			spin += vel.length() * delta * 0.03
			var res = Game.arena.bounce_off(global_position, vel, 20.0)
			if res != null:
				global_position = res.pos
				vel = res.vel * 0.85
				Sfx.play("kick", 1.4, -6.0)
			var now := Time.get_ticks_msec()
			for e in Game.enemies.duplicate():
				if not is_instance_valid(e) or e.dead:
					continue
				if global_position.distance_to(e.global_position) < 24.0 + e.data.radius:
					var id = e.get_instance_id()
					if _hit_cd.get(id, 0) < now:
						_hit_cd[id] = now + 500
						var dir := vel.normalized()
						var res2: Dictionary = Game.player.roll_damage(26.0 * Game.player.dmg_mult, 0.0)
						e.take_hit(res2.dmg, dir, 540.0 * Game.phase_mod("kb"), res2.crit, {tags = "bin"})
						Sfx.play_hit(res2.crit)
						Juice.shake(0.2, dir)
			if vel.length() < 45.0:
				state = S.COOLDOWN
				timer = 3.5
		S.COOLDOWN:
			timer -= delta
			if timer <= 0.0:
				state = S.AVAILABLE
				Sfx.play("click", 0.8, -6.0)
	# 3D-Darstellung
	var stage: Stage3D = Game.arena.stage
	if state == S.ROLLING:
		var yaw := Basis(Vector3.UP, -vel.angle())
		_pivot.basis = yaw * Basis(Vector3.RIGHT, PI / 2.0) * Basis(Vector3.UP, spin)
		_pivot.position = stage.to3(global_position, 0.0) + Vector3(0, 0.19, 0)
	else:
		_pivot.basis = Basis(Vector3.FORWARD, sin(Time.get_ticks_msec() * 0.05) * 0.06 * _wob)
		_pivot.position = stage.to3(global_position, 0.0) + Vector3(0, 0.21, 0)
	_mat.albedo_color = Color(0.3, 0.33, 0.37) if state == S.COOLDOWN else Color(0.5, 0.55, 0.6)
	queue_redraw()

func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * 20.0, sin(a) * 7.0 + 2.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.3))

func draw_overlay(c: Control, sp: Vector2) -> void:
	if state == S.COOLDOWN:
		c.draw_arc(sp + Vector2(0, -52), 8.0, -PI / 2, -PI / 2 + TAU * (1.0 - timer / 3.5), 16, Color(1, 1, 1, 0.8), 3.0)
