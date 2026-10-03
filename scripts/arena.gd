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
var _obst: Array = []           # zerstörbare Hindernisse: {rect, shape, hp}
var props_list: Array = []      # Feuerlöscher / Chemieschränke
var boss_fight := false
var boss_name := ""
var boss_title_txt := ""
var _boss_wave_done := -1
# Wegfindung: Flussfeld (Breitensuche vom Spieler aus) auf einem groben Raster, getrennt für kleine und große Gegner
const NAV := 32.0
const NAV_PAD := [18.0, 28.0]
var _nav_w := 0
var _nav_h := 0
var _nav_blocked: Array = [PackedByteArray(), PackedByteArray()]
var _nav_dist: Array = [PackedInt32Array(), PackedInt32Array()]
var _nav_rects: Array = [[], []]
var _nav_cell := Vector2i(-99, -99)
var _nav_t := 0.0
var _nav_big_used := false
var _nav_dirty := true

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
		var cs := _add_rect_shape(body, Rect2(r.position + Vector2(0, 14), r.size - Vector2(0, 14)))
		_obst.append({rect = r, shape = cs, hp = 5 if (r.size.x < 80.0 or r.size.y > 150.0) else 3})
	_nav_rebuild()

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
				Rect2(690, 405, 220, 92)]
		_:
			return [Rect2(330, 340, 170, 64), Rect2(1100, 340, 170, 64), Rect2(330, 650, 170, 64), Rect2(1100, 650, 170, 64), Rect2(705, 455, 190, 88)]

func _build_stations() -> void:
	for st in HUB_STATIONS:
		var s := Station.new()
		s.kind = st.kind
		s.title = st.title
		s.hint = st.hint
		s.accent = st.accent
		s.global_position = st.pos
		entities.add_child(s)

func _add_rect_shape(body: StaticBody2D, r: Rect2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	cs.position = r.position + r.size * 0.5
	body.add_child(cs)
	return cs

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
	# Feuerlöscher und Chemieschränke je nach Raum
	var spots: Array = []
	match chapter.style:
		"lab":
			spots = [["cabinet", Vector2(170, 215)], ["cabinet", Vector2(1430, 215)], ["cabinet", Vector2(800, 905)],
				["extinguisher", Vector2(150, 890)], ["extinguisher", Vector2(1450, 890)]]
		"library":
			spots = [["extinguisher", Vector2(150, 890)], ["extinguisher", Vector2(1450, 890)], ["cabinet", Vector2(800, 905)]]
		_:
			spots = [["extinguisher", Vector2(150, 200)], ["extinguisher", Vector2(1450, 200)],
				["cabinet", Vector2(170, 890)], ["cabinet", Vector2(1430, 890)]]
	for sp in spots:
		var pr := ArenaProp.new()
		pr.kind = sp[0]
		pr.position = sp[1]
		entities.add_child(pr)
		props_list.append(pr)

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
	_nav_update(_delta)

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

# ---------------------------------------------------------------- Wegfindung (Flussfeld)
func _nav_rebuild() -> void:
	_nav_w = int(ceil(PLAY.size.x / NAV))
	_nav_h = int(ceil(PLAY.size.y / NAV))
	for k in 2:
		var pad: float = NAV_PAD[k]
		var rects: Array = []
		for r in obstacles:
			# Fußpunkt-Sperrzone: Kollisionsrechteck, um den Körperradius erweitert (Körpermitte liegt über den Füßen)
			var c := Rect2(r.position + Vector2(0, 14), r.size - Vector2(0, 14))
			rects.append(Rect2(c.position.x - pad, c.position.y - 2.0, c.size.x + pad * 2.0, c.size.y + pad * 2.0 + 2.0))
		_nav_rects[k] = rects
		var b := PackedByteArray()
		b.resize(_nav_w * _nav_h)
		for y in _nav_h:
			for x in _nav_w:
				var p := PLAY.position + Vector2((x + 0.5) * NAV, (y + 0.5) * NAV)
				for rr in rects:
					if rr.has_point(p):
						b[y * _nav_w + x] = 1
						break
		_nav_blocked[k] = b
	_nav_dirty = true

func _nav_cell_of(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int((p.x - PLAY.position.x) / NAV), 0, _nav_w - 1), clampi(int((p.y - PLAY.position.y) / NAV), 0, _nav_h - 1))

func _nav_update(delta: float) -> void:
	_nav_t -= delta
	if hub_mode or player == null or _nav_w == 0:
		return
	var c := _nav_cell_of(player.global_position)
	if (c != _nav_cell or _nav_dirty) and _nav_t <= 0.0:
		_nav_t = 0.12
		_nav_cell = c
		_nav_dirty = false
		_nav_bfs(0, c)
		if _nav_big_used:
			_nav_bfs(1, c)

func _nav_bfs(k: int, start: Vector2i) -> void:
	var n := _nav_w * _nav_h
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(-1)
	var b: PackedByteArray = _nav_blocked[k]
	var q := PackedInt32Array()
	q.resize(n)
	var head := 0
	var tail := 0
	var s := start.y * _nav_w + start.x
	dist[s] = 0
	q[tail] = s
	tail += 1
	var w := _nav_w
	while head < tail:
		var c := q[head]
		head += 1
		var d := dist[c] + 1
		var cx := c % w
		if cx > 0 and dist[c - 1] < 0 and b[c - 1] == 0:
			dist[c - 1] = d
			q[tail] = c - 1
			tail += 1
		if cx < w - 1 and dist[c + 1] < 0 and b[c + 1] == 0:
			dist[c + 1] = d
			q[tail] = c + 1
			tail += 1
		if c >= w and dist[c - w] < 0 and b[c - w] == 0:
			dist[c - w] = d
			q[tail] = c - w
			tail += 1
		if c < n - w and dist[c + w] < 0 and b[c + w] == 0:
			dist[c + w] = d
			q[tail] = c + w
			tail += 1
	_nav_dist[k] = dist

## Richtung (Einheitsvektor) entlang des Flussfelds zum Spieler; ZERO, wenn kein Weg bekannt ist
func nav_dir(from: Vector2, big: bool = false) -> Vector2:
	var k := 1 if big else 0
	if big and not _nav_big_used:
		_nav_big_used = true
		_nav_dirty = true
	var dist: PackedInt32Array = _nav_dist[k]
	if dist.is_empty():
		return Vector2.ZERO
	var c := _nav_cell_of(from)
	var here := dist[c.y * _nav_w + c.x]
	var best_score := here * 10 if here >= 0 else 1 << 30
	var best := Vector2i(-1, -1)
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx := c.x + dx
			var ny := c.y + dy
			if nx < 0 or ny < 0 or nx >= _nav_w or ny >= _nav_h:
				continue
			var dj := dist[ny * _nav_w + nx]
			if dj < 0:
				continue
			var score := dj * 10
			if dx != 0 and dy != 0:
				# nicht diagonal um Ecken schneiden
				if dist[c.y * _nav_w + nx] < 0 or dist[ny * _nav_w + c.x] < 0:
					continue
				score += 4
			if score < best_score:
				best_score = score
				best = Vector2i(nx, ny)
	if best.x < 0:
		return Vector2.ZERO
	var target := PLAY.position + Vector2((best.x + 0.5) * NAV, (best.y + 0.5) * NAV)
	return (target - from).normalized()

## Freie Sichtlinie (Fußpunkt zu Fußpunkt) an allen Hindernissen vorbei?
func los(a: Vector2, b: Vector2, big: bool = false) -> bool:
	for rr in _nav_rects[1 if big else 0]:
		if _seg_hits(a, b, rr):
			return false
	return true

func _seg_hits(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d := b - a
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		var o: float = a[axis]
		var dd: float = d[axis]
		var mn: float = r.position[axis]
		var mx: float = r.end[axis]
		if absf(dd) < 0.0001:
			if o < mn or o > mx:
				return false
		else:
			var ta := (mn - o) / dd
			var tb := (mx - o) / dd
			if ta > tb:
				var tmp := ta
				ta = tb
				tb = tmp
			t0 = maxf(t0, ta)
			t1 = minf(t1, tb)
			if t0 > t1:
				return false
	return true

# ---------------------------------------------------------------- Zerstörbare Umgebung
func _circle_hits_rect(c: Vector2, radius: float, r: Rect2) -> bool:
	var q := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return q.distance_squared_to(c) <= radius * radius

## Bosse walzen Hindernisse nieder: alles im Radius wird sofort zerstört. Gibt die Anzahl zurück.
func smash_obstacles(center: Vector2, radius: float, dir: Vector2, by_player: bool = false) -> int:
	var n := 0
	for o in _obst.duplicate():
		var c := Rect2(o.rect.position + Vector2(0, 14), o.rect.size - Vector2(0, 14))
		if _circle_hits_rect(center, radius, c):
			_destroy_obstacle(o, dir, by_player)
			n += 1
	return n

## Explosionen und Wuchtangriffe beschädigen Tische/Regale und lösen Feuerlöscher/Chemieschränke aus
func blast(center: Vector2, radius: float, by_player: bool, power: int = 1, source: Node = null) -> void:
	if hub_mode:
		return
	for o in _obst.duplicate():
		if _circle_hits_rect(center, radius * 0.8, o.rect):
			o.hp -= power
			if o.hp <= 0:
				_destroy_obstacle(o, (o.rect.get_center() - center).normalized(), by_player)
			else:
				stage.shake_desk(o.rect)
				Juice.burst(o.rect.get_center(), Color(0.66, 0.45, 0.24), 6, 160.0, 0.4, 3.5, 360.0, Vector2.UP, 200.0)
	for pr in props_list:
		if is_instance_valid(pr) and pr != source and not pr.used and pr.global_position.distance_to(center) < radius + 70.0:
			pr.trigger(0.35, by_player)
	if power >= 3:
		for bn in bins:
			if is_instance_valid(bn) and bn.global_position.distance_to(center) < radius + 40.0:
				bn.kick((bn.global_position - center).normalized(), 560.0)

func _destroy_obstacle(o: Dictionary, dir: Vector2, by_player: bool) -> void:
	_obst.erase(o)
	obstacles.erase(o.rect)
	if is_instance_valid(o.shape):
		o.shape.queue_free()
	var c: Vector2 = o.rect.get_center()
	stage.destroy_desk(o.rect, dir)
	Sfx.play("explosion", 1.45, -3.0)
	Sfx.play("kick", 0.7)
	Juice.shake(0.5, dir)
	Juice.burst(c + Vector2(0, -20), Color(0.66, 0.45, 0.24), 24, 340.0, 0.75, 5.0, 360.0, Vector2.UP, 320.0)
	Juice.burst(c + Vector2(0, -10), Color(0.92, 0.9, 0.82, 0.9), 10, 170.0, 0.8, 6.0, 360.0, Vector2.UP, 0.0, "circle", 14.0)
	Juice.ring(c, 115.0, Color(1.0, 0.9, 0.7), 0.3, 6.0)
	splat(c, Color(0.25, 0.17, 0.1, 0.5), 36.0)
	Juice.float_text_at(c, 60.0, "KRACH!", Color(1.0, 0.85, 0.5), 22, true)
	room_react(c, 1.2)
	stage.pulse_light(c, Color(1.0, 0.85, 0.6), 1.4, 2.6, 0.2)
	Game.stats.smashed += 1
	if by_player:
		Game.stats.objects_used += 1
	# Splitter treffen Mutanten in der Nähe
	var mult: float = player.dmg_mult if player != null else 1.0
	for e in Game.enemies.duplicate():
		if is_instance_valid(e) and not e.dead and e.data.behavior != "boss" and e.global_position.distance_to(c) < 125.0 + e.data.radius:
			e.take_hit(18.0 * mult, (e.global_position - c).normalized(), 320.0, false, {tags = "debris"})
	_nav_rebuild()

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
	boss_fight = false
	for pr in props_list:
		if is_instance_valid(pr):
			pr.reset()
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
	if Game.endless:
		# Endlos: alle 5 Wellen ein Boss, danach geht es weiter
		if Game.wave % 5 == 0 and _boss_wave_done != Game.wave:
			start_boss_intro()
		else:
			start_next_wave()
	elif Game.wave >= Game.TOTAL_WAVES:
		start_boss_intro()
	else:
		start_next_wave()

## Endlos-Modus: Boss besiegt -> Pause, Kiosk, nächste Welle
func endless_boss_done() -> void:
	if Game.state != Game.State.IN_RUN:
		return
	_boss_wave_done = Game.wave
	boss_fight = false
	boss = null
	collect_all = true
	_transition_t = 0.0
	Game.add_money(18 + 2 * Game.wave)
	Sfx.play("bell", 1.1, -2.0)
	Game.stamp_requested.emit("Nachsitzen verlängert!", Color(0.2, 0.5, 0.9))
	Game.announce.emit("Das war noch nicht alles, Herr Kollege. Der Stundenplan ist heute unendlich.", "info")
	Game.change_state(Game.State.WAVE_TRANSITION)

## Boss-Auftritt als kleine Kamerafahrt: Zoom auf den Einschlag, Titelkarte, Rückzug in die Kampfansicht
func start_boss_intro() -> void:
	boss_fight = true
	collect_all = false
	events.end_all()
	var boss_id: String = chapter.boss
	var hp_scale: float = chapter.hp_scale
	if Game.endless:
		var round_n := int(Game.wave / 5)
		boss_id = ["coach", "etz", "zorn"][(round_n - 1) % 3]
		hp_scale = 1.0 + 0.45 * float(round_n - 1)
	else:
		Game.wave += 1
	boss_name = chapter.boss_name
	boss_title_txt = chapter.boss_title
	for n in Db.chapters:
		if n > 0 and Db.chapters[n].boss == boss_id:
			boss_name = Db.chapters[n].boss_name
			boss_title_txt = Db.chapters[n].boss_title
	Game.wave_changed.emit(Game.wave, Game.TOTAL_WAVES)
	var d: EnemyData = Db.enemies[boss_id]
	boss = Enemy.create(d, Vector2(800, 330), hp_scale * (1.0 + 0.25 * float(Game.difficulty)))
	smash_obstacles(Vector2(800, 330), 90.0, Vector2.DOWN)
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
		Game.boss_title.emit(boss_name, boss_title_txt, chapter.intro))
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

func spawn_with_marker(id: String, pos: Vector2, hp_mult: float, done: Callable, affix: String = "") -> void:
	Hazard.spawn(pos, {radius = 30.0 if affix == "" else 46.0, telegraph = 0.8, color = Color(1, 1, 1) if affix == "" else Color(1.0, 0.8, 0.2), from_enemy = false, kind = "marker",
		on_activate = func():
			done.call()
			spawn_enemy(id, pos, hp_mult, affix)})

func spawn_enemy(id: String, pos: Vector2, hp_mult: float = 1.0, affix: String = "") -> Enemy:
	var e := Enemy.create(Db.enemies[id], pos, hp_mult, false, affix)
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
