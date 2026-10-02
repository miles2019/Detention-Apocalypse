class_name ScreenShake
extends RefCounted
## Trauma-basierter, richtungsabhängiger Screen-Shake. Wird von Juice getickt.

var trauma := 0.0
var dir := Vector2.ZERO
var offset := Vector2.ZERO
var zoom_kick := 0.0
var _t := 0.0

func add(amount: float, direction: Vector2 = Vector2.ZERO) -> void:
	trauma = minf(1.0, trauma + amount)
	if direction != Vector2.ZERO:
		dir = direction.normalized()

func kick_zoom(amount: float) -> void:
	zoom_kick = clampf(zoom_kick + amount, -0.4, 0.4)

func update(delta: float, strength: float) -> void:
	_t += delta * 60.0
	trauma = maxf(0.0, trauma - delta * 1.8)
	zoom_kick = lerpf(zoom_kick, 0.0, 1.0 - exp(-6.0 * delta))
	var s := trauma * trauma * 14.0 * strength
	var rnd := Vector2(sin(_t * 1.7) + sin(_t * 3.1) * 0.5, cos(_t * 2.3) + sin(_t * 2.9) * 0.5)
	# Treffer-Richtung bevorzugen
	var biased := rnd * 0.5 + dir * sin(_t * 2.6) * 1.2
	offset = biased * s
