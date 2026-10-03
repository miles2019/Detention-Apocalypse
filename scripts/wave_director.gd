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
var _elapsed := 0.0
var _limit := 60.0
const MAX_ALIVE := 34
var _wave_n := 1

func start_wave(n: int) -> void:
	var chap: Dictionary = Game.chapter_data()
	var def: Dictionary = Game.wave_def(n)
	_wave_n = n
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
	hp_mult = (1.0 + 0.1 * float(n - 1)) * chap.hp_scale * (1.0 + 0.25 * float(Game.difficulty))
	if Game.endless:
		hp_mult = (1.0 + 0.13 * float(n - 1)) * (1.0 + 0.25 * float(Game.difficulty))
	_interval = def.duration / float(maxi(1, queue.size()))
	_timer = 0.8
	_elapsed = 0.0
	_limit = def.duration * 1.5
	active = true
	_pending = 0
	_emit_progress()

func _process(delta: float) -> void:
	if not active or Game.state != Game.State.IN_RUN:
		return
	_timer -= delta
	_elapsed += delta
	if _elapsed > _limit and queue.is_empty():
		# Wellen-Zeitlimit: übrige Fernkämpfer rücken vor (kein endloses Verstecken)
		for e in Game.enemies:
			if is_instance_valid(e) and not e.hunt:
				e.hunt = true
				e.speed_boost = maxf(e.speed_boost, 1.35)
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
	# Elite-Affixe: ab Welle 2 erscheinen gelegentlich modifizierte Gegner (höchstens 3 gleichzeitig)
	var affix := ""
	var d: EnemyData = Db.enemies[id]
	if _wave_n >= 2 and not d.elite and id != "locker":
		var chance := minf(0.2, 0.035 + 0.018 * float(_wave_n) + 0.03 * float(Game.difficulty))
		var champs := 0
		for e in Game.enemies:
			if is_instance_valid(e) and e.affix != "":
				champs += 1
		if champs < 3 and randf() < chance:
			var keys: Array = Db.affixes.keys()
			affix = keys[randi() % keys.size()]
	Game.arena.spawn_with_marker(id, pos, hp_mult, func(): _pending -= 1, affix)
