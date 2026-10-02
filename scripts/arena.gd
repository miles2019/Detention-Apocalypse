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
var collect_all := false
var boss: Enemy = null
var events: EventManager
var chapter := {}
var _wave_damage_mark := 0.0
var hub_mode := false
var _grid := {}
const CELL := 64.0

const HUB_STATIONS := [
	{kind = "skills", pos = Vector2(380, 340), title = "Alte Tafel", hint = "Dauerhafte Verbesserungen kaufen", accent = Color(0.5, 0.9, 0.6)},
	{kind = "workbench", pos = Vector2(800, 310), title = "Werkbank", hint = "Startwaffen & Rezeptbuch", accent = Color(1.0, 0.75, 0.3)},
	{kind = "board", pos = Vector2(1220, 340), title = "Schwarzes Brett", hint = "Challenges & Belohnungen", accent = Color(1.0, 0.9, 0.4)},
	{kind = "ag", pos = Vector2(360, 700), title = "AG-Schaukasten", hint = "Begleiter freischalten", accent = Color(0.6, 0.85, 1.0)},
	{kind = "director", pos = Vector2(800, 560), title = "Direktorenschild", hint = "Kapitel wählen & Unterricht beginnen", accent = Color(1.0, 0.4, 0.35)},
	{kind = "photo", pos = Vector2(1240, 700), title = "Spindwand", hint = "Klassenfoto: Charakter wählen", accent = Color(0.5, 0.9, 0.9)},
]
var _lamps: Array = []
var _lamp_flicker := 0.0
var _transition_t := 0.0
var _boss_fight := false

func _ready() -> void:
	Game.arena = self
	chapter = Game.chapter_data()
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
	if hub_mode:
		stage.build_hub()
		_build_stations()
	else:
		stage.build_props(obstacles, chapter.style)
		_build_objects()
		_build_lamps()
	player = Player.new()
	player.global_position = Vector2(800, 820) if hub_mode else Vector2(800, 700)
	entities.add_child(player)
	camera = stage.camera
	if hub_mode:
		camera.base_zoom = 0.95
		camera.clamp_min = Vector2(760, 470)
		camera.clamp_max = Vector2(840, 600)
	camera.target = player
	camera.snap()
	director = WaveDirector.new()
	add_child(director)
	director.wave_cleared.connect(_on_wave_cleared)
	phases = PhaseManager.new()
	add_child(phases)
	announcer = Announcer.new()
	add_child(announcer)
	events = EventManager.new()
	add_child(events)
	_build_floor_sprite()

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
	obstacles = _layout(chapter.style)
	for r in obstacles:
		_add_rect_shape(body, Rect2(r.position + Vector2(0, 14), r.size - Vector2(0, 14)))

func _layout(style: String) -> Array:
	match style:
		"yard":
			var out: Array = []
			for st in HUB_STATIONS:
				out.append(Rect2(st.pos - Vector2(55, 34), Vector2(110, 44)))
			return out
		"lab":
			return [Rect2(330, 350, 160, 64), Rect2(720, 350, 160, 64), Rect2(1110, 350, 160, 64),
				Rect2(330, 650, 160, 64), Rect2(720, 650, 160, 64), Rect2(1110, 650, 160, 64)]
		"library":
			return [Rect2(300, 300, 44, 250), Rect2(560, 480, 44, 280), Rect2(996, 480, 44, 280), Rect2(1256, 300, 44, 250),
				Rect2(700, 420, 200, 64)]
		_:
			return [Rect2(330, 340, 170, 64), Rect2(1100, 340, 170, 64), Rect2(330, 650, 170, 64), Rect2(1100, 650, 170, 64), Rect2(715, 470, 170, 64)]

func _build_stations() -> void:
	for st in HUB_STATIONS:
		var s := Station.new()
		s.kind = st.kind
		s.title = st.title
		s.hint = st.hint
		s.accent = st.accent
		s.global_position = st.pos
		entities.add_child(s)

func _add_rect_shape(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.position + r.size * 0.5
	body.add_child(cs)

func _build_objects() -> void:
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
## Statischer Boden: einmal in einen SubViewport gemalt und als ein einziges Sprite gezeichnet (Performance)
func _build_floor_sprite() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(WORLD * Stage3D.GSCALE)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var painter := FloorPainter.new()
	painter.scale = Vector2.ONE * Stage3D.GSCALE
	vp.add_child(painter)
	stage.add_child(vp)
	var sp := Sprite2D.new()
	sp.texture = vp.get_texture()
	sp.centered = false
	sp.scale = Vector2.ONE / Stage3D.GSCALE
	sp.z_index = -20
	add_child(sp)

# ---------------------------------------------------------------- Logik
## Räumliches Raster der Gegner (einmal pro Physik-Frame): Separation und Treffer fragen nur Nachbarzellen ab
func _physics_process(_delta: float) -> void:
	_grid.clear()
	for e in Game.enemies:
		if is_instance_valid(e) and not e.dead:
			var k := Vector2i(int(floorf(e.global_position.x / CELL)), int(floorf(e.global_position.y / CELL)))
			if _grid.has(k):
				_grid[k].append(e)
			else:
				_grid[k] = [e]

func enemies_near(p: Vector2, r: float) -> Array:
	var out: Array = []
	var x0 := int(floorf((p.x - r) / CELL))
	var x1 := int(floorf((p.x + r) / CELL))
	var y0 := int(floorf((p.y - r) / CELL))
	var y1 := int(floorf((p.y + r) / CELL))
	for cx in range(x0, x1 + 1):
		for cy in range(y0, y1 + 1):
			var l = _grid.get(Vector2i(cx, cy))
			if l != null:
				out.append_array(l)
	return out

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
	_wave_damage_mark = Game.stats.damage_taken
	director.start_wave(Game.wave)
	phases.begin_wave(Game.wave)
	events.begin_wave(Game.wave)
	announcer.on_wave_start(Game.wave)
	Game.change_state(Game.State.IN_RUN)

func _on_wave_cleared() -> void:
	Game.stats.waves += 1
	collect_all = true
	events.end_all()
	if Game.stats.damage_taken <= _wave_damage_mark:
		Game.stats.flawless += 1
		Save.add_stat("flawless_waves", 1)
		Juice.float_text_at(player.global_position, 100.0, "Fehlerfrei!", Color(0.6, 1, 0.7), 22, true)
	var wh := int(Save.bonus("wave_heal"))
	if wh > 0:
		player.heal(float(wh))
	_transition_t = 0.0
	Game.add_money(6 + 2 * Game.wave)
	Sfx.play("bell", 1.1, -2.0)
	Juice.slowmo(0.45, 0.25)
	Juice.zoom_pop(0.06)
	Juice.ring(player.global_position, 380.0, Color(1, 0.95, 0.6), 0.6, 10.0, true)
	for k in 3:
		Juice.burst(player.global_position + Vector2(randf_range(-120, 120), randf_range(-40, 40)), [Color(1, 0.4, 0.4), Color(0.4, 0.8, 1.0), Color(1, 0.9, 0.3)][k], 18, 330.0, 1.0, 4.5, 180.0, Vector2.UP, 220.0, "circle", 40.0)
	Game.stamp_requested.emit("Pause!", Color(0.2, 0.5, 0.9))
	Game.announce.emit("Es klingelt zur Pause. Wer jetzt noch steht, bekommt Pausengeld.", "info")
	Game.change_state(Game.State.WAVE_TRANSITION)

func after_shop() -> void:
	if Game.wave >= Game.TOTAL_WAVES:
		start_boss_intro()
	else:
		start_next_wave()

## Boss-Auftritt als kleine Kamerafahrt: Zoom auf den Einschlag, Titelkarte, Rückzug in die Kampfansicht
func start_boss_intro() -> void:
	_boss_fight = true
	collect_all = false
	events.end_all()
	Game.wave += 1
	Game.wave_changed.emit(Game.wave, Game.TOTAL_WAVES)
	var d: EnemyData = Db.enemies[chapter.boss]
	boss = Enemy.create(d, Vector2(800, 330), chapter.hp_scale * (1.0 + 0.25 * float(Game.difficulty)))
	boss.spawn_t = 0.0
	boss.process_mode = Node.PROCESS_MODE_ALWAYS
	phases.begin_boss()
	Game.change_state(Game.State.BOSS_INTRO)
	Game.cinematic_bars.emit(true)
	boss.rig.hop = 560.0
	boss.rig.bb.visible = false
	camera.focus = Vector2(800, 330)
	camera.base_zoom = 1.9
	camera.roll = 0.08
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	# 1) Boss stürzt von oben herab
	tw.tween_callback(func():
		Sfx.play("boss_roar", 0.7, -2.0)
		boss.rig.bb.visible = true)
	tw.tween_property(boss.rig, "hop", 0.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 2) Einschlag: Erschütterung, Staubring, Blitz
	tw.tween_callback(func():
		Juice.shake(1.0)
		Juice.zoom_pop(0.1)
		Juice.ring(boss.global_position, 260.0, Color(1, 0.9, 0.7), 0.5, 12.0, true)
		Juice.burst(boss.global_position, Color(0.9, 0.85, 0.75), 30, 380.0, 0.8, 6.0, 360.0, Vector2.UP, 0.0, "circle", 10.0)
		stage.pulse_light(boss.global_position, Color(1, 0.9, 0.7), 3.0, 5.0, 0.5)
		boss.rig.squash(1.7, 0.5, 0.6)
		boss.rig.flash(0.25)
		Sfx.play("explosion", 0.6)
		room_react(boss.global_position, 2.0)
		Game.boss_title.emit(chapter.boss_name, chapter.boss_title, chapter.intro))
	# 3) langsame Kamerafahrt zum Gesicht, Dutch-Angle löst sich
	tw.set_parallel(true)
	tw.tween_property(camera, "base_zoom", 1.35, 2.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(camera, "roll", 0.0, 2.0).set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(func():
		announcer.on_boss_intro()
		Sfx.play("boss_roar", 1.0)
		Juice.shake(0.5))
	tw.set_parallel(false)
	tw.tween_interval(1.1)
	# 4) Rückzug in die Spielansicht
	tw.tween_callback(func():
		camera.focus = Vector2(800, 520)
		Game.cinematic_bars.emit(false))
	tw.tween_property(camera, "base_zoom", 0.78, 0.9).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.5)
	tw.tween_callback(_end_boss_intro)

func _end_boss_intro() -> void:
	camera.focus = null
	camera.roll = 0.0
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_ignore_time_scale(true)
	tw.tween_property(camera, "base_zoom", 1.0, 0.7).set_trans(Tween.TRANS_CUBIC)
	if boss != null and is_instance_valid(boss):
		boss.active = true
		boss.process_mode = Node.PROCESS_MODE_INHERIT
	Game.change_state(Game.State.IN_RUN)

## Kurzer Kamera-Fokus (z.B. Boss-Phase 2): heranzoomen, halten, zurück
func cinematic_focus(pos: Vector2, zoom: float, hold: float) -> void:
	Game.cinematic_bars.emit(true)
	camera.focus = pos
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(camera, "base_zoom", zoom, 0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_callback(func():
		camera.focus = null
		Game.cinematic_bars.emit(false))
	tw.tween_property(camera, "base_zoom", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC)

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

func splat(pos: Vector2, color: Color, r: float) -> void:
	# dauerhafter Farbfleck (Decal) mit Obergrenze für Performance
	var nodes := get_tree().get_nodes_in_group("splat")
	if nodes.size() > 70:
		nodes[0].queue_free()
	var d := FloorDecal.new()
	d.r = r
	d.color = color
	d.life = 14.0
	d.add_to_group("splat")
	d.global_position = pos
	floor_fx.add_child(d)

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
	var _acc := 0.0
	func _process(delta: float) -> void:
		_t += delta
		_acc += delta
		if _t >= life:
			queue_free()
			return
		if _acc > 0.2:
			_acc = 0.0
			queue_redraw()
	func _draw() -> void:
		var c := color
		c.a *= 1.0 - _t / life
		draw_circle(Vector2.ZERO, r, c)
