class_name Trap
extends Node2D
## Bananenschale: liegt am Boden, der erste Gegner rutscht aus – betäubt, schlittert in seine Laufrichtung
## und reißt dabei andere Gegner um.

var damage := 18.0
var life := 14.0
var _t := 0.0
var _bb: Billboard3D
var _done := false

static func spawn(pos: Vector2, dmg: float) -> Trap:
	var t := Trap.new()
	t.damage = dmg
	t.global_position = pos
	Game.arena.floor_fx.add_child(t)
	return t

func _ready() -> void:
	add_to_group("trap")
	var stage: Stage3D = Game.arena.stage
	_bb = Billboard3D.new()
	stage.sprites.add_child(_bb)
	_bb.setup(Db.tex(Db.p_icon(2)), 26.0, false)
	_bb.place(global_position, 0.0)
	_bb.set_body(Vector2(0.2, 0.2), 0.0)
	var tw := create_tween()
	tw.tween_method(func(k: float): if _bb != null: _bb.set_body(Vector2(k, k), sin(k * 9.0) * 0.3), 0.2, 1.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _exit_tree() -> void:
	if _bb != null and is_instance_valid(_bb):
		_bb.queue_free()

func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	if _t > life:
		queue_free()
		return
	if _t < 0.35:
		return
	for e in Game.arena.enemies_near(global_position, 44.0):
		if is_instance_valid(e) and not e.dead and e.spawn_t <= 0.0 and e.global_position.distance_to(global_position) < 20.0 + e.data.radius:
			_slip(e)
			return

func _slip(e: Node) -> void:
	_done = true
	var dir: Vector2 = e.velocity.normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.from_angle(randf() * TAU)
	var res: Dictionary = Game.player.roll_damage(damage, 0.0)
	var boss: bool = e.data.behavior == "boss"
	e.take_hit(res.dmg, dir, 0.0, res.crit, {tags = "banana", stun = 0.6 if boss else 1.4, launch = damage * 0.7})
	if not boss:
		e.kb_vel += dir * 560.0
	e.rig.squash(1.4, 0.6, 0.5)
	Sfx.play("splat", 1.5, -4.0)
	Sfx.play_hit(res.crit)
	Juice.float_text_at(global_position, 50.0, "Ausgerutscht!", Color(1.0, 0.92, 0.3), 16, true)
	Juice.burst(global_position, Color(1.0, 0.9, 0.3), 8, 200.0, 0.4, 3.5, 100.0, dir)
	Game.stats.objects_used += 1
	# Schale fliegt im Bogen davon
	var tw := create_tween()
	tw.tween_method(func(k: float):
		if _bb != null:
			_bb.place(global_position - dir * 60.0 * k, sin(k * PI) * 70.0)
			_bb.set_body(Vector2.ONE * (1.0 - k * 0.6), k * 12.0)
			_bb.set_tint(Color(1, 1, 1, 1.0 - k)), 0.0, 1.0, 0.5)
	tw.tween_callback(queue_free)
