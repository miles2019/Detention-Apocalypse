class_name ArenaProp
extends Node2D
## Nutzbare Umgebung: Feuerlöscher (friert Gegner ein, löscht Feuer) und Chemieschrank (explodiert, Kettenreaktion).
## Auslöser: anrempeln, Interagieren, eigene Projektile oder Explosionen in der Nähe. Pro Welle einmal nutzbar.
## Placeholder: 3D-Primitive.

var kind := "extinguisher"     # extinguisher | cabinet
var used := false
var fuse := -1.0
var _pivot: Node3D
var _wob := 0.0
var _t := 0.0
var _by_player := true
var _glow: StandardMaterial3D

const R := 22.0

func _ready() -> void:
	add_to_group("reactive")
	add_to_group("interactable")
	var stage: Stage3D = Game.arena.stage
	_pivot = Node3D.new()
	stage.props.add_child(_pivot)
	_pivot.position = stage.to3(global_position, 0.0)
	# Feuerlöscher-Modell aus dem Styloo-Paket (siehe CREDITS.md); ohne Modell greifen die Grundformen darunter
	var model: MeshInstance3D = ModelLib.instance(ModelLib.STYLOO % "chem_fireextinguisher", "") if kind == "extinguisher" else null
	if model != null:
		var msize: Vector3 = model.get_meta("size")
		var ms := 0.56 / maxf(msize.y, 0.0001)
		model.scale = Vector3(ms, ms, ms)
		_pivot.add_child(model)
		_glow = model.get_surface_override_material(0)
		return
	if kind == "extinguisher":
		var cm := CylinderMesh.new()
		cm.top_radius = 0.085
		cm.bottom_radius = 0.095
		cm.height = 0.42
		var body := _mesh(stage, cm, Color(0.86, 0.14, 0.12))
		body.position.y = 0.23
		_glow = body.material_override
		var top := BoxMesh.new()
		top.size = Vector3(0.09, 0.09, 0.09)
		_mesh(stage, top, Color(0.12, 0.12, 0.14)).position.y = 0.49
		var hose := BoxMesh.new()
		hose.size = Vector3(0.16, 0.03, 0.03)
		_mesh(stage, hose, Color(0.12, 0.12, 0.14)).position = Vector3(0.1, 0.5, 0.0)
		var band := CylinderMesh.new()
		band.top_radius = 0.097
		band.bottom_radius = 0.097
		band.height = 0.07
		_mesh(stage, band, Color(0.95, 0.95, 0.9)).position.y = 0.27
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.5, 0.7, 0.28)
		var body2 := _mesh(stage, bm, Color(0.8, 0.86, 0.82))
		body2.position.y = 0.35
		_glow = body2.material_override
		var door := BoxMesh.new()
		door.size = Vector3(0.42, 0.5, 0.02)
		_mesh(stage, door, Color(0.55, 0.8, 0.75)).position = Vector3(0.0, 0.38, 0.145)
		var stripe := BoxMesh.new()
		stripe.size = Vector3(0.5, 0.07, 0.29)
		_mesh(stage, stripe, Color(1.0, 0.8, 0.1)).position.y = 0.06
		for k in 3:
			var fm := CylinderMesh.new()
			fm.top_radius = 0.03
			fm.bottom_radius = 0.06
			fm.height = 0.15
			_mesh(stage, fm, [Color(0.4, 0.95, 0.4), Color(0.95, 0.4, 0.8), Color(0.4, 0.7, 1.0)][k]).position = Vector3(-0.16 + k * 0.16, 0.78, 0.0)

func _mesh(stage: Stage3D, mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := stage.make_mesh_node(mesh, color)
	mi.get_parent().remove_child(mi)
	_pivot.add_child(mi)
	return mi

func _exit_tree() -> void:
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.queue_free()

func react(pos: Vector2, strength: float) -> void:
	if pos.distance_to(global_position) < 300.0:
		_wob = maxf(_wob, strength * 0.6)

func interact(_pl: Node) -> void:
	trigger()

## Neue Welle: Objekt steht wieder bereit
func reset() -> void:
	if not used:
		return
	used = false
	fuse = -1.0
	_pivot.visible = true
	_pivot.scale = Vector3(0.01, 0.01, 0.01)
	var tw := _pivot.create_tween()
	tw.tween_property(_pivot, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func trigger(delay: float = 0.0, by_player: bool = true) -> void:
	if used:
		return
	used = true
	_by_player = by_player
	fuse = maxf(delay, 0.05) if kind == "extinguisher" else maxf(delay, 0.55)
	_wob = 1.5
	Sfx.play("warn", 1.5 if kind == "cabinet" else 1.9, -6.0)

func try_hit(proj: Node) -> void:
	if not used and proj.global_position.distance_to(global_position + Vector2(0, -18)) < R + proj.radius:
		trigger()

func _process(delta: float) -> void:
	_t += delta
	_wob = maxf(0.0, _wob - delta * 2.0)
	if not used:
		var pl = Game.player
		if pl != null and pl.global_position.distance_to(global_position) < 30.0 and pl.velocity.length() > 90.0:
			trigger()
	elif fuse > 0.0:
		fuse -= delta
		# Zündschnur: blinkt immer schneller
		var blink := sin(_t * 40.0) > 0.0
		_glow.emission_enabled = blink
		_glow.emission = Color(1, 0.9, 0.5)
		_glow.emission_energy_multiplier = 1.5
		if fuse <= 0.0:
			_glow.emission_enabled = false
			_go()
	if _pivot.visible:
		_pivot.basis = Basis(Vector3.FORWARD, sin(_t * 45.0) * 0.07 * _wob) * Basis.from_scale(_pivot.scale)
	queue_redraw()

func _go() -> void:
	var arena: Arena = Game.arena
	var pos := global_position
	_pivot.visible = false
	if _by_player:
		Game.stats.objects_used += 1
	if kind == "extinguisher":
		var r := 185.0
		Sfx.play("shoot_steam", 1.3)
		Sfx.play("splat", 1.6, -6.0)
		Juice.shake(0.35)
		Juice.ring(pos, r, Color(0.75, 0.92, 1.0), 0.45, 10.0, true)
		for k in 3:
			Juice.burst(pos + Vector2(0, -20), Color(0.95, 0.98, 1.0, 0.95), 16, 330.0, 0.9, 6.0, 360.0, Vector2.UP, 0.0, "circle", 14.0)
		arena.stage.pulse_light(pos, Color(0.7, 0.9, 1.0), 2.2, 3.6, 0.4)
		arena.decal(pos, Color(0.9, 0.95, 1.0, 0.4), r * 0.8, 4.0)
		Juice.float_text_at(pos, 60.0, "Eingefroren!", Color(0.75, 0.92, 1.0), 22, true)
		var n := 0
		for e in Game.enemies.duplicate():
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(pos) < r + e.data.radius:
				e.freeze(1.2 if e.data.behavior == "boss" else 3.0)
				n += 1
		if n >= 5:
			Game.stamp_requested.emit("Eiszeit!", Color(0.3, 0.6, 0.9))
		# löscht Feuer und Säure
		for h in arena.floor_fx.get_children():
			if h is Hazard and (h.kind == "fire" or h.kind == "acid") and h.global_position.distance_to(pos) < r + 60.0:
				h.queue_free()
	else:
		var r2 := 150.0 * Game.phase_mod("explosion")
		Sfx.play("explosion", 0.85)
		Juice.shake(0.75)
		Juice.zoom_pop(0.05)
		Juice.hitstop(0.05)
		Juice.ring(pos, r2, Color(0.6, 1.0, 0.35), 0.4, 12.0, true)
		Juice.burst(pos + Vector2(0, -20), Color(0.6, 1.0, 0.35), 26, 380.0, 0.7, 5.0, 360.0, Vector2.UP, 200.0)
		Juice.burst(pos + Vector2(0, -20), Color(0.3, 0.3, 0.3, 0.9), 12, 200.0, 1.0, 7.0, 360.0, Vector2.UP, 0.0, "circle", 20.0)
		arena.stage.pulse_light(pos, Color(0.7, 1.0, 0.4), 3.2, 4.5, 0.4)
		arena.splat(pos, Color(0.1, 0.1, 0.08, 0.6), 46.0)
		arena.room_react(pos, 1.6)
		Juice.float_text_at(pos, 60.0, "BUMM!", Color(0.7, 1.0, 0.4), 26, true)
		var pl = Game.player
		var mult: float = pl.dmg_mult if pl != null else 1.0
		for e in Game.enemies.duplicate():
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(pos) < r2 + e.data.radius:
				e.take_hit(48.0 * mult, (e.global_position - pos).normalized(), 520.0, false, {tags = "area"})
		if pl != null and pl.global_position.distance_to(pos) < 105.0:
			if pl.take_damage(12.0, pos, true):
				pl.knock((pl.global_position - pos).normalized() * 420.0)
		Hazard.spawn(pos, {kind = "acid", radius = 84.0, telegraph = 0.0, duration = 6.0, tick_player = 5.0, tick_enemy = 10.0,
			color = Color(0.5, 1.0, 0.3), pattern = "bubbles", from_enemy = true})
		arena.blast(pos, r2, _by_player, 3, self)

func _draw() -> void:
	if used and fuse <= 0.0:
		return
	var pts := PackedVector2Array()
	var w := 16.0 if kind == "extinguisher" else 30.0
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * w, sin(a) * w * 0.4 + 2.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.3))
