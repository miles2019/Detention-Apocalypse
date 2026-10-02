class_name SwingFX
extends Node2D
## Schwungbogen des Wischmopps (rein visuell).

var radius := 100.0
var arc := deg_to_rad(150.0)
var dir_angle := 0.0
var color := Color(1, 1, 0.8)
var dur := 0.22
var _t := 0.0

static func spawn(parent: Node, pos: Vector2, angle: float, r: float, arc_deg: float, col: Color) -> void:
	var fx := SwingFX.new()
	fx.global_position = pos
	fx.radius = r
	fx.arc = deg_to_rad(arc_deg)
	fx.dir_angle = angle
	fx.color = col
	fx.z_index = 25
	parent.add_child(fx)

func _process(delta: float) -> void:
	_t += delta
	if _t >= dur:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := clampf(_t / dur, 0.0, 1.0)
	var sweep := arc * minf(1.0, k * 2.2)
	var a0 := dir_angle - arc * 0.5
	var c := color
	c.a = 1.0 - k
	draw_arc(Vector2.ZERO, radius * 0.85, a0, a0 + sweep, 24, c, 14.0 * (1.0 - k * 0.6))
	c.a *= 0.6
	draw_arc(Vector2.ZERO, radius * 0.6, a0, a0 + sweep, 24, c, 5.0)
