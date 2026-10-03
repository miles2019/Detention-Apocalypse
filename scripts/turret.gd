class_name Turret
extends Node2D
## Leckes Wasserrohr / Sprinkleranlage: steht an Ort und Stelle und spritzt selbstständig auf Gegner (macht sie nass).

var damage := 6.0
var life := 9.0
var jets := 1
var reach := 380.0
var weapon_id := "pipe"
var color := Color(0.4, 0.8, 1.0)
var icon := ""
var _t := 0.0
var _cd := 0.3
var _bb: Billboard3D
var _rot := 0.0

static func spawn(pos: Vector2, props: Dictionary) -> Turret:
	var t := Turret.new()
	for k in props:
		t.set(k, props[k])
	t.global_position = pos
	Game.arena.entities.add_child(t)
	return t

func _ready() -> void:
	add_to_group("turret")
	var stage: Stage3D = Game.arena.stage
	_bb = Billboard3D.new()
	stage.sprites.add_child(_bb)
	_bb.setup(Db.tex(icon), 46.0, true)
	_bb.place(global_position, 0.0)
	_bb.set_body(Vector2(0.1, 0.1), -0.8)
	var tw := create_tween()
	tw.tween_method(func(k: float): if _bb != null: _bb.set_body(Vector2(k, k), -0.8), 0.1, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play("locker", 1.6, -6.0)
	Juice.burst(global_position, color, 10, 160.0, 0.4, 3.0, 180.0, Vector2.UP, 200.0)
	Juice.ring(global_position, 50.0, color, 0.3, 4.0)

func _exit_tree() -> void:
	if _bb != null and is_instance_valid(_bb):
		_bb.queue_free()

func _physics_process(delta: float) -> void:
	_t += delta
	if _t >= life:
		Juice.burst(global_position, color, 8, 140.0, 0.4, 3.0)
		queue_free()
		return
	_cd -= delta
	_rot += delta * 2.4
	# wackelt unter Druck, blinkt kurz vor dem Ende
	_bb.set_body(Vector2(1.0, 1.0 + sin(_t * 30.0) * 0.04), -0.8 + sin(_t * 9.0) * 0.08)
	if life - _t < 1.5:
		_bb.set_tint(Color(1, 1, 1, 0.5 + 0.5 * absf(sin(_t * 14.0))))
	if _cd > 0.0:
		return
	var from := global_position + Vector2(0, -30)
	if jets > 1:
		# Sprinkler: rotierende Strahlen in alle Richtungen
		_cd = 0.3
		for i in jets:
			_shoot(from, Vector2.from_angle(_rot + TAU * i / float(jets)))
		Sfx.play("shoot_water", 1.5, -14.0)
		return
	var t = Game.nearest_enemy(global_position, reach)
	if t == null:
		_cd = 0.12
		return
	_cd = 0.38
	_shoot(from, ((t.global_position + Vector2(0, -t.data.height * 0.4)) - from).normalized())
	Sfx.play("shoot_water", 1.4, -12.0)

func _shoot(from: Vector2, dir: Vector2) -> void:
	Projectile.create(Game.arena.fx_layer, from, dir * 620.0, {
		team = "player", kind = "drop", damage = damage, radius = 7.0, life = reach / 620.0 * 1.2, knockback = 90.0,
		weapon_id = weapon_id, color = color,
	})

func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * 20.0, sin(a) * 8.0 + 2.0))
	draw_colored_polygon(pts, Color(0.3, 0.7, 1.0, 0.25))
