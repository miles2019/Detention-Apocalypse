class_name Shockwave
extends Node2D
## Expandierende Druckwelle mit Wirkung (Megafon, Pfeife der Sportlehrerin).

var team := "player"
var max_radius := 170.0
var duration := 0.4
var damage := 10.0
var knockback := 400.0
var stun := 0.0
var stun_chance := 0.0
var color := Color(0.8, 0.55, 1.0)
var thickness := 18.0
var weapon_id := ""
var _t := 0.0
var _hit := {}

static func create(parent: Node, pos: Vector2, props: Dictionary) -> Shockwave:
	var s := Shockwave.new()
	s.global_position = pos
	for k in props:
		s.set(k, props[k])
	s.z_index = 22
	parent.add_child(s)
	return s

func _radius_at(k: float) -> float:
	return max_radius * (1.0 - pow(1.0 - k, 2.5))

func _physics_process(delta: float) -> void:
	_t += delta
	var k := clampf(_t / duration, 0.0, 1.0)
	var r := _radius_at(k)
	if team == "player":
		for e in Game.enemies:
			if not is_instance_valid(e) or e.dead or _hit.has(e.get_instance_id()):
				continue
			var d := global_position.distance_to(e.global_position)
			if d <= r + e.data.radius and d >= r - thickness - e.data.radius - 10.0:
				_hit[e.get_instance_id()] = true
				var res: Dictionary = Game.player.roll_damage(damage, 0.0)
				var dir = (e.global_position - global_position).normalized()
				var st := stun if randf() < stun_chance else 0.0
				e.take_hit(res.dmg, dir, knockback * Game.player.kb_mult * Game.phase_mod("kb"), res.crit, {stun = st, tags = weapon_id})
				Sfx.play_hit(res.crit)
	else:
		var pl = Game.player
		if pl != null and not _hit.has(1) and pl.is_targetable():
			var d := global_position.distance_to(pl.global_position)
			if d <= r + 10.0 and d >= r - thickness - 14.0:
				_hit[1] = true
				var dir = (pl.global_position - global_position).normalized()
				if pl.take_damage(damage, global_position, true):
					pl.knock(dir * knockback)
					if stun > 0.0:
						pl.stun(stun)
	if _t >= duration:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var r := _radius_at(k)
	var c := color
	c.a = 1.0 - k * k
	draw_arc(Vector2.ZERO, maxf(2.0, r), 0.0, TAU, 56, c, thickness * (1.0 - k * 0.6))
	draw_arc(Vector2.ZERO, maxf(2.0, r - thickness * 0.3), 0.0, TAU, 56, Color(1, 1, 1, c.a * 0.8), 3.0)
	# Schallwellen als dünne Bögen (Form statt nur Farbe)
	for i in 3:
		var cc := c
		cc.a *= 0.5
		draw_arc(Vector2.ZERO, maxf(2.0, r * (0.5 + 0.17 * i)), 0.0, TAU, 40, cc, 2.0)
