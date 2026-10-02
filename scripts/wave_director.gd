class_name WaveDirector
extends Node
## Steuert Spawns einer Welle und meldet das Wellenende. Keine UI-Logik.

signal wave_cleared

var active := false
var queue: Array = []
var hp_mult := 1.0
var _timer := 0.0
var _interval := 1.0
var _pending := 0
const MAX_ALIVE := 34

func start_wave(n: int) -> void:
	var def: Dictionary = Db.waves[n - 1]
	queue.clear()
	var late: Array = []
	for id in def.groups:
		for i in def.groups[id]:
			if Db.enemies[id].elite:
				late.append(id)
			else:
				queue.append(id)
	queue.shuffle()
	# Elite-Gegner erscheinen in der zweiten Wellenhälfte
	for id in late:
		queue.insert(int(queue.size() * randf_range(0.45, 0.8)), id)
	hp_mult = 1.0 + 0.1 * float(n - 1)
	_interval = def.duration / float(maxi(1, queue.size()))
	_timer = 0.8
	active = true
	_pending = 0
	_emit_progress()

func _process(delta: float) -> void:
	if not active or Game.state != Game.State.IN_RUN:
		return
	_timer -= delta
	var alive := Game.enemies.size() + _pending
	if not queue.is_empty():
		if alive < 5:
			_timer = minf(_timer, 0.25)
		if _timer <= 0.0 and alive < MAX_ALIVE:
			_spawn(queue.pop_front())
			_timer = _interval * randf_range(0.6, 1.2)
			_emit_progress()
	elif alive == 0:
		active = false
		wave_cleared.emit()

func _emit_progress() -> void:
	Game.wave_progress.emit(Game.enemies.size() + _pending, queue.size())

func _spawn(id: String) -> void:
	var pos: Vector2 = Game.arena.random_spawn_pos()
	_pending += 1
	Game.arena.spawn_with_marker(id, pos, hp_mult, func(): _pending -= 1)
