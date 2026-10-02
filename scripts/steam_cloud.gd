class_name SteamCloud
extends Node2D
## Evolutionswaffe "Dampf-Kanone": wachsende, langsam treibende Dampfwolke,
## die Gegner anhaltend schädigt und radial wegdrückt (neue Spielweise: Gegner-Zonenkontrolle).

var dir := Vector2.RIGHT
var damage := 10.0
var knockback := 300.0
var big := false
var radius := 40.0
var _t := 0.0
var _tick := 0.0
var _life := 3.4
var _puffs: Array = []

func _ready() -> void:
	z_index = 18
	if big:
		_life = 4.4
	for i in 9:
		_puffs.append({a = randf() * TAU, d = randf(), s = randf_range(0.7, 1.2), r = randf_range(-1.0, 1.0)})

func _process(delta: float) -> void:
	_t += delta
	var speed := 150.0 * pow(maxf(0.0, 1.0 - _t / 1.6), 1.5)
	global_position += dir * speed * delta
	var mul := Game.phase_mod("explosion")
	var target_r := (150.0 if big else 105.0) * mul
	radius = lerpf(radius, target_r, 1.0 - exp(-2.2 * delta))
	_tick -= delta
	if _tick <= 0.0:
		_tick = 0.22
		_pulse()
	if _t >= _life:
		queue_free()
	queue_redraw()

func _pulse() -> void:
	var hits := 0
	for e in Game.enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var d = e.global_position.distance_to(global_position)
		if d < radius + e.data.radius:
			var res: Dictionary = Game.player.roll_damage(damage, 0.0)
			var push = (e.global_position - global_position).normalized()
			if push == Vector2.ZERO:
				push = Vector2.RIGHT
			e.take_hit(res.dmg, push, knockback * Game.player.kb_mult * Game.phase_mod("kb") * 0.55, res.crit, {tags = "steam", slow = 0.35})
			hits += 1
	if hits > 0:
		Sfx.play("splat", 1.4, -8.0)
		Juice.shake(0.12)

func _draw() -> void:
	var k := clampf(_t / _life, 0.0, 1.0)
	var fade := 1.0 - pow(k, 3.0)
	var tex: Texture2D = Db.tex(Db.p_icon(9))
	draw_circle(Vector2.ZERO, radius, Color(0.9, 0.95, 1.0, 0.16 * fade))
	for p in _puffs:
		var a: float = p.a + _t * p.r * 0.8
		var pos = Vector2(cos(a), sin(a)) * radius * (0.25 + 0.55 * p.d)
		var sz: float = radius * 0.9 * p.s
		draw_set_transform(pos, a * 0.3, Vector2.ONE * (sz / float(tex.get_width())))
		draw_texture(tex, -tex.get_size() * 0.5, Color(1, 1, 1, 0.75 * fade))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_arc(Vector2.ZERO, radius, 0, TAU, 40, Color(1, 1, 1, 0.5 * fade), 3.0)
