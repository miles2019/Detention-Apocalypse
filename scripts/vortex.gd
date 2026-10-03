class_name Vortex
extends Node2D
## Sogfeld (Magnet-Kanone): zieht Gegner und Aufsammelbares zur Mitte, macht Tick-Schaden und implodiert am Ende.
## Gedacht als Vorlage für Flächenangriffe: erst bündeln, dann draufhalten.

var radius := 150.0
var damage := 6.0
var duration := 2.6
var color := Color(0.45, 0.7, 1.0)
var _t := 0.0
var _tick := 0.0
var _mat: ShaderMaterial

static func spawn(pos: Vector2, props: Dictionary) -> Vortex:
	var v := Vortex.new()
	for k in props:
		v.set(k, props[k])
	v.global_position = pos
	Game.arena.floor_fx.add_child(v)
	return v

func _ready() -> void:
	z_index = 2
	var cr := ColorRect.new()
	cr.size = Vector2(radius, radius) * 2.0
	cr.position = -Vector2(radius, radius)
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://effects/vortex.gdshader")
	_mat.set_shader_parameter("tint", color)
	cr.material = _mat
	add_child(cr)
	Sfx.play("phase_Physik", 1.5, -6.0)
	Game.arena.stage.pulse_light(global_position, color, 1.6, 3.0, 0.4)

func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / duration, 0.0, 1.0)
	_mat.set_shader_parameter("fade", minf(1.0, _t * 6.0) * (1.0 - pow(k, 6.0)))
	_mat.set_shader_parameter("spin", 6.0 + k * 10.0)
	_tick -= delta
	var do_tick := _tick <= 0.0
	if do_tick:
		_tick = 0.4
	var pl = Game.player
	for e in Game.arena.enemies_near(global_position, radius):
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = global_position - e.global_position
		var d := to.length()
		if d > radius + e.data.radius:
			continue
		var heavy: float = 0.35 if (e.data.elite or e.affix != "") else 1.0
		if d > 14.0:
			e.kb_vel += to / d * 1500.0 * delta * heavy
		if do_tick and pl != null:
			var res: Dictionary = pl.roll_damage(damage, 0.0)
			e.take_hit(res.dmg, Vector2.ZERO, 0.0, res.crit, {tags = "magnet", quiet = true})
	# auch Münzen und Erfahrung werden angezogen
	if do_tick:
		for pk in Game.arena.pickup_layer.get_children():
			if pk is Pickup and pk.global_position.distance_to(global_position) < radius:
				pk.forced = true
		Juice.burst(global_position + Vector2.from_angle(randf() * TAU) * radius * 0.8, color.lightened(0.3), 3, 60.0, 0.4, 2.5)
	if _t >= duration:
		_implode()

func _implode() -> void:
	var pl = Game.player
	Juice.ring(global_position, radius * 0.7, color.lightened(0.4), 0.3, 8.0, true)
	Juice.burst(global_position, color.lightened(0.5), 18, 300.0, 0.5, 4.0, 360.0, Vector2.UP, 0.0, "circle", 16.0)
	Juice.shake(0.3)
	Sfx.play("explosion", 1.6, -6.0)
	Game.arena.stage.pulse_light(global_position, color.lightened(0.3), 2.4, 3.4, 0.25)
	if pl != null:
		for e in Game.arena.enemies_near(global_position, radius * 0.6):
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position) < radius * 0.55 + e.data.radius:
				var res: Dictionary = pl.roll_damage(damage * 3.0, 0.0)
				e.take_hit(res.dmg, (e.global_position - global_position).normalized(), 260.0, res.crit, {tags = "magnet"})
	queue_free()
