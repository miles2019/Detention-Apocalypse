class_name RoomMechanic
extends Node
## Feste Raum-Mechanik je Kapitel (chapter.mechanic): Kurzschlüsse im Computerraum, überlaufende Becken in der
## Schultoilette, Kurvenfahrten im Schulbus. Mensa, Sporthalle und Kunstraum bringen ihre Regel über Objekte mit
## (Getränkeautomat, Medizinbälle, Farbeimer – siehe Arena._build_objects).

var kind := ""
var _t := 6.0
var _curve_dir := 0.0
var _curve_t := -1.0

func _process(delta: float) -> void:
	if kind == "" or Game.state != Game.State.IN_RUN or Game.player == null:
		return
	var arena: Arena = Game.arena
	if _curve_t > 0.0:
		_curve_t -= delta
		if _curve_t <= 0.0:
			_do_curve(arena)
	_t -= delta
	if _t > 0.0:
		return
	match kind:
		"computer":
			_t = randf_range(4.5, 6.5)
			_short_circuit(arena)
		"toilet":
			_t = randf_range(7.0, 9.5)
			_flood(arena)
		"bus":
			_t = randf_range(11.0, 14.0)
			_announce_curve()
		_:
			_t = 999.0

## Computerraum: zwei bis drei Stromfelder, eines davon nahe beim Spieler
func _short_circuit(arena: Arena) -> void:
	var pl = Game.player
	for i in 2 + (1 if Game.wave >= 3 else 0):
		var base: Vector2 = pl.global_position if i == 0 else Vector2(randf_range(200, 1400), randf_range(240, 860))
		var pos: Vector2 = arena.clamp_to_arena(base + Vector2.from_angle(randf() * TAU) * randf_range(40.0, 150.0))
		Hazard.spawn(pos, {kind = "shock", radius = 74.0, telegraph = 1.2, duration = 2.6, tick_player = 6.0, tick_enemy = 8.0,
			color = Color(1.0, 0.92, 0.3), pattern = "stripes", from_enemy = true})
	arena.room_react(pl.global_position, 0.8)
	Sfx.play("phase_Physik", 1.8, -10.0)

## Schultoilette: ein Becken läuft über – große Pfütze, die alle bremst und Gegner nass macht
func _flood(arena: Arena) -> void:
	var pl = Game.player
	var pos: Vector2 = arena.clamp_to_arena(pl.global_position + Vector2.from_angle(randf() * TAU) * randf_range(80.0, 300.0))
	Hazard.spawn(pos, {kind = "water", radius = 135.0, telegraph = 1.0, duration = 6.5, slow_player = 0.75, slow_enemy = 0.8,
		color = Color(0.4, 0.75, 1.0), pattern = "waves", from_enemy = true})
	Sfx.play("splat", 0.7, -6.0)

## Schulbus: erst die Warnung, eine Sekunde später rutscht alles zur Seite
func _announce_curve() -> void:
	_curve_dir = 1.0 if randf() < 0.5 else -1.0
	_curve_t = 1.1
	Game.stamp_requested.emit("KURVE  >>>" if _curve_dir > 0.0 else "<<<  KURVE", Color(1.0, 0.75, 0.2))
	Sfx.play("warn", 0.7)

func _do_curve(arena: Arena) -> void:
	var pl = Game.player
	var push := Vector2(_curve_dir, 0.0)
	pl.knock(push * 520.0)
	for e in Game.enemies:
		if is_instance_valid(e) and not e.dead:
			e.kb_vel += push * (620.0 if e.data.behavior != "boss" else 260.0)
	for b in arena.bins:
		if is_instance_valid(b):
			b.kick(push, 520.0)
	Juice.shake(0.6, push)
	Sfx.play("kick", 0.6)
	arena.room_react(pl.global_position, 1.5)
	arena.camera.roll = 0.07 * _curve_dir
	var tw := arena.create_tween()
	tw.tween_property(arena.camera, "roll", 0.0, 0.9).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
