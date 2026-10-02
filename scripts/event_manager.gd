class_name EventManager
extends Node
## Wellen-Events (Durchsagen des Rektors mit echter Regeländerung): Hitzefrei, Vokabeltest, Pausenaufsicht,
## Räumungsübung, Stromausfall. Logik hier, Anzeige im HUD (Game.announce / stamp) und in der Stage (Licht/FX).

var active := ""
var time_left := 0.0
var duration := 0.0
var _scheduled := ""
var _sched_t := 0.0
var _last := ""
var _fire_t := 0.0

func begin_wave(n: int) -> void:
	end_all()
	_scheduled = ""
	var chance := 0.5 + 0.1 * float(Game.chapter - 1)
	if n >= 2 and randf() < chance:
		var ids: Array = Db.events.keys()
		ids.erase(_last)
		_scheduled = ids[randi() % ids.size()]
		_sched_t = randf_range(10.0, 18.0)

func schedule_now(id: String) -> void:
	_scheduled = id
	_sched_t = 0.0

func _process(delta: float) -> void:
	if Game.state != Game.State.IN_RUN:
		return
	if _scheduled != "":
		_sched_t -= delta
		if _sched_t <= 0.0 and (Game.enemies.size() >= 3 or _scheduled == "pausenaufsicht"):
			var id := _scheduled
			_scheduled = ""
			start(id)
	if active == "":
		return
	time_left -= delta
	if active == "raeumung":
		_fire_t -= delta
		if _fire_t <= 0.0:
			_fire_t = 2.2
			_spawn_fire()
	if time_left <= 0.0:
		_end()

func start(id: String) -> void:
	print("[EVENT] start ", id)
	if active != "":
		_end()
	var e: Dictionary = Db.events[id]
	active = id
	_last = id
	duration = maxf(e.duration, 4.0)
	time_left = duration
	Game.event_mods = e.mods.duplicate()
	Game.arena.announcer.say(e.text, "event")
	Game.stamp_requested.emit(e.name, e.color)
	Sfx.play("warn", 0.8)
	Sfx.play("bell", 0.7, -6.0)
	Juice.shake(0.35)
	Juice.zoom_pop(0.04)
	var stage: Stage3D = Game.arena.stage
	match id:
		"hitzefrei":
			stage.set_post_tint(Color(1.12, 0.92, 0.78))
			stage.set_event_fx("heat")
		"vokabeltest":
			stage.set_post_tint(Color(1.05, 1.05, 0.85))
			stage.set_event_fx("letters")
		"pausenaufsicht":
			for i in 2:
				Game.arena.spawn_with_marker("brute", Game.arena.random_spawn_pos(), Game.arena.director.hp_mult, func(): pass)
		"raeumung":
			_fire_t = 0.6
		"stromausfall":
			stage.set_blackout(true)

func _spawn_fire() -> void:
	var pl = Game.player
	for i in 8:
		var p := Vector2(randf_range(Arena.PLAY.position.x + 80, Arena.PLAY.end.x - 80), randf_range(Arena.PLAY.position.y + 80, Arena.PLAY.end.y - 80))
		if pl != null and p.distance_to(pl.global_position) < 150.0 and i < 7:
			continue
		Hazard.spawn(p, {kind = "fire", radius = 105.0, telegraph = 1.8, duration = 7.0, tick_player = 6.0, tick_enemy = 10.0,
			color = Color(1.0, 0.55, 0.15), pattern = "bubbles", from_enemy = true})
		return

func _end() -> void:
	if active == "":
		return
	Game.stats.events += 1
	Save.add_stat("events", 1)
	active = ""
	Game.event_mods = {}
	var stage: Stage3D = Game.arena.stage
	stage.set_post_tint(Color.WHITE)
	stage.set_blackout(false)
	stage.set_event_fx("")

func end_all() -> void:
	if active != "":
		_end()
