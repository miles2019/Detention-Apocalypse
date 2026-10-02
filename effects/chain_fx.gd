class_name ChainFX
extends Node2D
## Blitz-/Klammer-Verbindung zwischen zwei Gegnern (kurzer Aufleuchter) plus 3D-Funken an beiden Enden.

var a := Vector2.ZERO
var b := Vector2.ZERO
var color := Color(1, 1, 0.6)
var _t := 0.0
var _pts := PackedVector2Array()

static func spawn(from: Vector2, to: Vector2, col: Color) -> void:
	if Game.arena == null:
		return
	var f := ChainFX.new()
	f.a = from
	f.b = to
	f.color = col.lightened(0.4)
	f.z_index = 30
	Game.arena.fx_layer.add_child(f)
	Juice.burst(to, col.lightened(0.3), 4, 120.0, 0.25, 2.5)
	# Zickzack-Pfad
	var steps := 6
	var n := (to - from).orthogonal().normalized()
	f._pts.append(from)
	for i in range(1, steps):
		var p := from.lerp(to, float(i) / steps) + n * randf_range(-10.0, 10.0)
		f._pts.append(p)
	f._pts.append(to)

func _process(delta: float) -> void:
	_t += delta
	if _t > 0.22:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := 1.0 - _t / 0.22
	var c := color
	c.a = k
	draw_polyline(_pts, c, 4.0 * k + 1.0)
	draw_polyline(_pts, Color(1, 1, 1, k), 1.5)
