class_name PhaseManager
extends Node
## Unterrichtsphasen: Glocke, Fachwechsel, Farbwechsel, Regeländerung (über Game.phase_mods).

const ORDER := ["Physik", "Sport", "Chemie"]
const PHASE_LENGTH := 34.0

var current := ""
var time_left := 0.0
var _idx := 0
var _acid_t := 2.0
var _tint_tw: Tween

func begin_wave(wave_n: int) -> void:
	_idx = (wave_n - 1) % ORDER.size()
	_activate_phase(ORDER[_idx], 1.0)

func begin_boss() -> void:
	_idx = 1
	_activate_phase("Sport", 0.0)

func _activate_phase(id: String, delay: float) -> void:
	current = id
	time_left = PHASE_LENGTH
	_acid_t = 2.5
	var ph: PhaseData = Db.phases[id]
	# Glocke -> Fach-Jingle -> Durchsage, dazu Farbwechsel und Banner
	Sfx.play("bell", 1.0, -2.0)
	get_tree().create_timer(delay + 0.9).timeout.connect(func():
		if Game.arena == null:
			return
		Sfx.play("phase_" + id, 1.0, -2.0)
		Game.arena.announcer.say(ph.announcement, "phase")
	)
	Game.set_phase(id)
	Juice.shake(0.3)
	Juice.ring(Game.player.global_position, 260.0, Color.WHITE, 0.5, 8.0)
	if _tint_tw:
		_tint_tw.kill()
	var tint = Game.arena.tint
	_tint_tw = create_tween()
	tint.color = Color(1.4, 1.4, 1.4)
	_tint_tw.tween_property(tint, "color", ph.tint, 0.7)

func _process(delta: float) -> void:
	if Game.state != Game.State.IN_RUN or current == "":
		return
	time_left -= delta
	if time_left <= 0.0:
		_idx = (_idx + 1) % ORDER.size()
		_activate_phase(ORDER[_idx], 0.0)
	# Chemie: Säurepfützen entstehen
	if Game.phase_mods.get("acid", false):
		_acid_t -= delta
		if _acid_t <= 0.0:
			_acid_t = randf_range(2.2, 3.4)
			var pl = Game.player
			var pos: Vector2 = Game.arena.clamp_to_arena(pl.global_position + Vector2.from_angle(randf() * TAU) * randf_range(60.0, 340.0))
			Hazard.spawn(pos, {kind = "acid", radius = 62.0, telegraph = 1.3, duration = 6.0, tick_player = 5.0, tick_enemy = 8.0,
				color = Color(0.5, 1.0, 0.3), pattern = "bubbles", from_enemy = true})
