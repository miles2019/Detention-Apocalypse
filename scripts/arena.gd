class_name Arena
extends Node2D
## Klassenzimmer-Arena: Boden, Wände, Hindernisse, interaktive Objekte, Kamera, Wellenablauf.

const WORLD := Vector2(1600, 1020)
const PLAY := Rect2(70, 125, 1460, 825)

var play_rect := PLAY
var obstacles: Array = []
var floor_fx: Node2D
var pickup_layer: Node2D
var entities: Node2D
var fx_layer: Node2D
var camera: StageCamera
var tint: TintProxy
var stage: Stage3D
var player: Player
var director: WaveDirector
var phases: PhaseManager
var announcer: Announcer
var boards: Array = []
var bins: Array = []
var lockers: Array = []
var collect_all := false
var boss: Enemy = null
var _lamps: Array = []
var _lamp_flicker := 0.0
var _transition_t := 0.0
var _boss_fight := false

func _ready() -> void:
	Game.arena = self
	y_sort_enabled = false
	tint = TintProxy.new()
	tint.stage = stage
	add_child(tint)
	floor_fx = Node2D.new()
	floor_fx.z_index = -5
	add_child(floor_fx)
	pickup_layer = Node2D.new()
	pickup_layer.z_index = -3
	add_child(pickup_layer)
	entities = Node2D.new()
	entities.y_sort_enabled = true
	add_child(entities)
	fx_layer = Node2D.new()
	fx_layer.z_index = 50
	add_child(fx_layer)
	_build_walls_and_obstacles()
	stage.build_props(obstacles)
	_build_objects()
	_build_lamps()
	player = Player.new()
	player.global_position = Vector2(800, 700)
	entities.add_child(player)
	camera = stage.camera
	camera.target = player
	camera.snap()
	director = WaveDirector.new()
	add_child(director)
	director.wave_cleared.connect(_on_wave_cleared)
	phases = PhaseManager.new()
	add_child(phases)
	announcer = Announcer.new()
	add_child(announcer)
	queue_redraw()

func _exit_tree() -> void:
	if Game.arena == self:
		Game.arena = null
		Game.player = null
		Game.enemies.clear()

# ---------------------------------------------------------------- Aufbau
func _build_walls_and_obstacles() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	add_child(body)
	var walls := [
		Rect2(-100, -100, WORLD.x + 200, PLAY.position.y + 100),
		Rect2(-100, PLAY.end.y, WORLD.x + 200, 200),
		Rect2(-100, 0, PLAY.position.x + 100, WORLD.y),
		Rect2(PLAY.end.x, 0, 200, WORLD.y),
	]
	for r in walls:
		_add_rect_shape(body, r)
	# Schultische (Platzhalter-Grafik wird im Boden gezeichnet)
	obstacles = [
		Rect2(330, 340, 170, 64), Rect2(1100, 340, 170, 64),
		Rect2(330, 650, 170, 64), Rect2(1100, 650, 170, 64),
		Rect2(715, 470, 170, 64),
	]
	for r in obstacles:
		_add_rect_shape(body, Rect2(r.position + Vector2(0, 14), r.size - Vector2(0, 14)))

func _add_rect_shape(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.position + r.size * 0.5
	body.add_child(cs)

func _build_objects() -> void:
	for x in [250.0, 800.0, 1350.0]:
		var l := Locker.new()
		l.position = Vector2(x, 205)
		entities.add_child(l)
		lockers.append(l)
	for pos in [Vector2(520, 880), Vector2(1100, 580)]:
		var b := TrashBin.new()
		b.position = pos
		entities.add_child(b)
		bins.append(b)
	var b1 := Chalkboard.new()
	b1.position = Vector2(105, 640)
	b1.facing = 1.0
	entities.add_child(b1)
	boards.append(b1)
	var b2 := Chalkboard.new()
	b2.position = Vector2(1495, 640)
	b2.facing = -1.0
	entities.add_child(b2)
	boards.append(b2)

func _build_lamps() -> void:
	for pos in [Vector2(420, 420), Vector2(1180, 420), Vector2(420, 800), Vector2(1180, 800), Vector2(800, 620)]:
		var s := Sprite2D.new()
		s.texture = Juice.circle_tex()
		s.scale = Vector2(26, 26)
		s.position = pos
		s.modulate = Color(1.0, 0.95, 0.75, 0.16)
		s.z_index = 40
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = mat
		add_child(s)
		_lamps.append(s)

# ---------------------------------------------------------------- Boden (einmal gezeichnet)
func _draw() -> void:
	var font := ThemeDB.fallback_font
	# Hintergrund
	draw_rect(Rect2(Vector2.ZERO, WORLD), Color(0.09, 0.1, 0.14))
	# Linoleum-Schachbrett
	var ts := 82.0
	var y := PLAY.position.y
	var row := 0
	while y < PLAY.end.y:
		var x := PLAY.position.x
		var col := 0
		while x < PLAY.end.x:
			var c := Color(0.78, 0.8, 0.66) if (row + col) % 2 == 0 else Color(0.7, 0.74, 0.6)
			draw_rect(Rect2(x, y, minf(ts, PLAY.end.x - x), minf(ts, PLAY.end.y - y)), c)
			x += ts
			col += 1
		y += ts
		row += 1
	# Schmutz / Kratzer / Schleimspuren des Meteoriten
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 60:
		var p := Vector2(rng.randf_range(PLAY.position.x, PLAY.end.x), rng.randf_range(PLAY.position.y, PLAY.end.y))
		draw_line(p, p + Vector2(rng.randf_range(-24, 24), rng.randf_range(-8, 8)), Color(0.4, 0.42, 0.34, 0.25), 2.0)
	for i in 9:
		var p2 := Vector2(rng.randf_range(PLAY.position.x + 60, PLAY.end.x - 60), rng.randf_range(PLAY.position.y + 40, PLAY.end.y - 40))
		draw_circle(p2, rng.randf_range(18, 38), Color(0.4, 0.9, 0.3, 0.13))
		draw_circle(p2 + Vector2(6, -3), 9, Color(0.5, 1.0, 0.4, 0.14))
	# Spielfeld-Begrenzung
	draw_rect(PLAY, Color(0.1, 0.1, 0.14), false, 6.0)
	# Wände und Tische sind 3D-Objekte (Stage3D.build_props)

# ---------------------------------------------------------------- Logik
func _process(delta: float) -> void:
	_lamp_flicker = maxf(0.0, _lamp_flicker - delta * 1.5)
	for l in _lamps:
		var a := 0.16
		if _lamp_flicker > 0.0:
			a *= 0.35 + 0.65 * (1.0 if int(Time.get_ticks_msec() / 60) % 2 == 0 else 0.0)
		l.modulate.a = lerpf(l.modulate.a, a, 0.4)
	if Game.state == Game.State.WAVE_TRANSITION:
		_transition_t += delta
		if _transition_t > 2.4 and Game.pending_levelups == 0:
			_transition_t = 0.0
			collect_all = false
			Game.change_state(Game.State.SHOP)

func start_next_wave() -> void:
	Game.wave += 1
	collect_all = false
	_boss_fight = false
	Game.wave_changed.emit(Game.wave, Game.TOTAL_WAVES)
	director.start_wave(Game.wave)
	phases.begin_wave(Game.wave)
	announcer.on_wave_start(Game.wave)
	Game.change_state(Game.State.IN_RUN)

func _on_wave_cleared() -> void:
	Game.stats.waves += 1
	collect_all = true
	_transition_t = 0.0
	Game.add_money(6 + 2 * Game.wave)
	Sfx.play("bell", 1.1, -2.0)
	Game.stamp_requested.emit("Pause!", Color(0.2, 0.5, 0.9))
	Game.announce.emit("Es klingelt zur Pause. Wer jetzt noch steht, bekommt Pausengeld.", "info")
	Game.change_state(Game.State.WAVE_TRANSITION)

func after_shop() -> void:
	if Game.wave >= Game.TOTAL_WAVES:
		start_boss_intro()
	else:
		start_next_wave()

func start_boss_intro() -> void:
	_boss_fight = true
	collect_all = false
	Game.wave += 1
	Game.wave_changed.emit(Game.wave, Game.TOTAL_WAVES)
	var d: EnemyData = Db.enemies["coach"]
	boss = Enemy.create(d, Vector2(800, 330), 1.0)
	boss.spawn_t = 0.0
	phases.begin_boss()
	Game.change_state(Game.State.BOSS_INTRO)
	announcer.on_boss_intro()
	Sfx.play("boss_roar", 0.9, -2.0)
	boss.rig.pop_in(0.7)
	camera.focus = Vector2(800, 520)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(camera, "base_zoom", 0.72, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	Game.stamp_requested.emit("BOSS: Frau Eisenhart", Color(0.85, 0.2, 0.2))
	get_tree().create_timer(3.4, true).timeout.connect(_end_boss_intro)

func _end_boss_intro() -> void:
	camera.focus = null
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(camera, "base_zoom", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC)
	if boss != null and is_instance_valid(boss):
		boss.active = true
	Game.change_state(Game.State.IN_RUN)

# ---------------------------------------------------------------- Spawns & Helfer
func random_spawn_pos() -> Vector2:
	for i in 20:
		var side := randi() % 4
		var p := Vector2.ZERO
		match side:
			0: p = Vector2(randf_range(PLAY.position.x + 40, PLAY.end.x - 40), PLAY.position.y + 40)
			1: p = Vector2(randf_range(PLAY.position.x + 40, PLAY.end.x - 40), PLAY.end.y - 40)
			2: p = Vector2(PLAY.position.x + 40, randf_range(PLAY.position.y + 40, PLAY.end.y - 40))
			3: p = Vector2(PLAY.end.x - 40, randf_range(PLAY.position.y + 40, PLAY.end.y - 40))
		if Game.player != null and p.distance_to(Game.player.global_position) < 380.0:
			continue
		var ok := true
		for r in obstacles:
			if r.grow(40).has_point(p):
				ok = false
		if ok:
			return p
	return PLAY.get_center()

func spawn_with_marker(id: String, pos: Vector2, hp_mult: float, done: Callable) -> void:
	Hazard.spawn(pos, {radius = 30.0, telegraph = 0.8, color = Color(1, 1, 1), from_enemy = false, kind = "marker",
		on_activate = func():
			done.call()
			spawn_enemy(id, pos, hp_mult)})

func spawn_enemy(id: String, pos: Vector2, hp_mult: float = 1.0) -> Enemy:
	var e := Enemy.create(Db.enemies[id], pos, hp_mult)
	Juice.burst(pos, Color(1, 1, 1, 0.8), 8, 130.0, 0.35, 3.0)
	return e

func clamp_to_arena(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, PLAY.position.x + 30, PLAY.end.x - 30), clampf(p.y, PLAY.position.y + 30, PLAY.end.y - 30))

func decal(pos: Vector2, color: Color, r: float, life: float) -> void:
	var d := FloorDecal.new()
	d.r = r
	d.color = color
	d.life = life
	d.global_position = pos
	floor_fx.add_child(d)

func room_react(pos: Vector2, strength: float) -> void:
	_lamp_flicker = maxf(_lamp_flicker, strength)
	for o in get_tree().get_nodes_in_group("reactive"):
		o.react(pos, strength)

## Prallt Projektile an Wänden und Hindernissen ab. Gibt {pos, vel} oder null zurück.
func bounce_off(pos: Vector2, vel: Vector2, r: float):
	var changed := false
	var v := vel
	var p := pos
	var rect := PLAY
	if p.x - r < rect.position.x:
		p.x = rect.position.x + r
		v.x = absf(v.x)
		changed = true
	elif p.x + r > rect.end.x:
		p.x = rect.end.x - r
		v.x = -absf(v.x)
		changed = true
	if p.y - r < rect.position.y:
		p.y = rect.position.y + r
		v.y = absf(v.y)
		changed = true
	elif p.y + r > rect.end.y:
		p.y = rect.end.y - r
		v.y = -absf(v.y)
		changed = true
	for ob in obstacles:
		var g: Rect2 = Rect2(ob.position + Vector2(0, 14), ob.size - Vector2(0, 14)).grow(r * 0.5)
		if g.has_point(p):
			var dl := p.x - g.position.x
			var dr := g.end.x - p.x
			var dt := p.y - g.position.y
			var db := g.end.y - p.y
			var m := minf(minf(dl, dr), minf(dt, db))
			if m == dl:
				p.x = g.position.x
				v.x = -absf(v.x)
			elif m == dr:
				p.x = g.end.x
				v.x = absf(v.x)
			elif m == dt:
				p.y = g.position.y
				v.y = -absf(v.y)
			else:
				p.y = g.end.y
				v.y = absf(v.y)
			changed = true
	if changed:
		return {pos = p, vel = v}
	return null

class TintProxy extends Node:
	var stage: Stage3D
	var color := Color.WHITE : set = _set_color
	func _set_color(c: Color) -> void:
		color = c
		if stage != null:
			stage.set_tint(c)

class FloorDecal extends Node2D:
	var r := 12.0
	var color := Color(0, 0, 0, 0.3)
	var life := 2.0
	var _t := 0.0
	func _process(delta: float) -> void:
		_t += delta
		if _t >= life:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var c := color
		c.a *= 1.0 - _t / life
		draw_circle(Vector2.ZERO, r, c)
