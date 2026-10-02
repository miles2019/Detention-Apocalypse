class_name RingFX
extends Node2D
## Expandierender Ring / Druckwelle (rein visuell).

var radius := 100.0
var color := Color.WHITE
var width := 6.0
var dur := 0.4
var filled := false
var _t := 0.0

static func spawn(parent: Node, pos: Vector2, r: float, col: Color, d: float = 0.4, w: float = 6.0, fill: bool = false) -> RingFX:
	var fx := RingFX.new()
	fx.radius = r
	fx.color = col
	fx.dur = d
	fx.width = w
	fx.filled = fill
	fx.global_position = pos
	fx.z_index = 20
	parent.add_child(fx)
	return fx

func _process(delta: float) -> void:
	_t += delta
	if _t >= dur:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / dur, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - k, 3.0)
	var r := radius * e
	var c := color
	c.a = color.a * (1.0 - k)
	if filled:
		var fc := c
		fc.a *= 0.35
		draw_circle(Vector2.ZERO, r, fc)
	draw_arc(Vector2.ZERO, maxf(1.0, r), 0.0, TAU, 48, c, maxf(1.0, width * (1.0 - k * 0.7)))
