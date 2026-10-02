class_name Pickup
extends Area2D
## Aufsammelbares: XP-Kugel, Pausengeld, Heilung (Pausenbrot), seltener A+-Drop.

var kind := "xp"
var value := 1
var _vel := Vector2.ZERO
var _age := 0.0
var _speed := 0.0
var _bb: Billboard3D
var _pop := 0.0
var _lift := 0.0
var _collected := false
var _swirl := 1.0

static func spawn(k: String, v: int, pos: Vector2, scatter: float = 90.0) -> void:
	if Game.arena == null:
		return
	var p := Pickup.new()
	p.kind = k
	p.value = v
	p.global_position = pos
	p._vel = Vector2.from_angle(randf() * TAU) * randf_range(scatter * 0.4, scatter)
	p._swirl = 1.0 if randf() < 0.5 else -1.0
	Game.arena.pickup_layer.add_child(p)

func _ready() -> void:
	collision_layer = 8
	collision_mask = 0
	monitoring = false
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 12.0
	cs.shape = sh
	add_child(cs)
	z_index = 4
	match kind:
		"xp":
			_make_sprite("", 16.0)
		"coin":
			_make_sprite(Db.i_icon(24), 26.0)
		"heal":
			_make_sprite("res://assets/items/sandwich.png", 34.0)
		"rare":
			_make_sprite(Db.i_icon(4), 46.0)
			_add_light_column()
			Sfx.play("rare")
			Juice.float_text_at(global_position, 50, "SELTENER DROP!", Color(1, 0.9, 0.3), 20, true)
	create_tween().tween_property(self, "_pop", 1.0, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _make_sprite(path: String, h: float) -> void:
	var stage: Stage3D = Game.arena.stage
	_bb = Billboard3D.new()
	stage.sprites.add_child(_bb)
	var t: Texture2D = Db.tex(path) if path != "" else Juice.circle_tex()
	_bb.setup(t, h, false)
	_bb.sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if kind == "xp":
		_bb.set_tint(Color(0.45, 1.0, 0.85))
		_bb.mat.set_shader_parameter("tint", Color(0.45, 1.0, 0.85))

func _add_light_column() -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(0.4, 2.0)
	mi.mesh = qm
	var g := GradientTexture2D.new()
	g.width = 8
	g.height = 64
	g.fill_from = Vector2(0, 1)
	g.fill_to = Vector2(0, 0)
	var gr := Gradient.new()
	gr.set_color(0, Color(1, 0.9, 0.3, 0.7))
	gr.set_color(1, Color(1, 0.9, 0.3, 0.0))
	g.gradient = gr
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mt.albedo_texture = g
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mt
	mi.position.y = 1.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bb.add_child(mi)

func _physics_process(delta: float) -> void:
	_age += delta
	_vel = _vel.lerp(Vector2.ZERO, 1.0 - exp(-7.0 * delta))
	global_position += _vel * delta
	_lift = 0.0
	if kind == "rare":
		_lift = 30.0 + sin(_age * 4.0) * 5.0
	elif kind == "xp":
		_lift = 10.0 + sin(_age * 6.0) * 2.0
	elif _age < 0.6:
		_lift = absf(sin(_age / 0.3 * PI)) * (26.0 if _age < 0.3 else 11.0)    # zweimal sichtbar hüpfen
	if _bb != null:
		_bb.place(global_position, _lift)
		_bb.set_body(Vector2.ONE * _pop, sin(_age * 3.0) * 0.12 if kind == "rare" else 0.0)
	var pl = Game.player
	if pl != null and not _collected:
		var d := global_position.distance_to(pl.global_position + Vector2(0, -14))
		var attract: bool = d < pl.magnet or Game.arena.collect_all
		if kind == "rare":
			attract = d < pl.magnet * 0.6 or Game.arena.collect_all
		if attract and _age > 0.3:
			_speed = move_toward(_speed, 760.0, 1500.0 * delta)
			var dir = (pl.global_position + Vector2(0, -14) - global_position).normalized()
			var perp := Vector2(-dir.y, dir.x) * _swirl
			var curve := clampf(d / 160.0, 0.0, 1.0)
			global_position += (dir + perp * 0.55 * curve).normalized() * _speed * delta
		if d < 15.0 and _age > 0.25:
			collect(pl)
	queue_redraw()

func collect(pl: Node) -> void:
	if _collected:
		return
	_collected = true
	if _bb != null:
		_bb.queue_free()
	match kind:
		"xp":
			Game.add_xp(value)
			Sfx.play("xp", randf_range(0.9, 1.3), -8.0)
			Juice.burst(global_position, Color(0.5, 1, 0.9), 3, 70.0, 0.25, 2.0)
		"coin":
			Game.add_money(value)
			Sfx.play("coin", randf_range(0.95, 1.15), -4.0)
			Juice.float_text_at(global_position, 20, "+%d" % value, Color(1, 0.85, 0.2), 16)
			Juice.burst(global_position, Color(1, 0.85, 0.2), 4, 90.0, 0.3, 2.5)
		"heal":
			pl.heal(float(value))
		"rare":
			Game.pending_levelups += 1
			Juice.float_text_at(global_position, 40, "A+ ! Gratis-Upgrade", Color(1, 0.9, 0.3), 20, true)
			Juice.burst(global_position, Color(1, 0.9, 0.3), 16, 240.0, 0.6, 4.0)
			Game.stamp_requested.emit("A+", Color(0.9, 0.2, 0.2))
			Game._check_levelup()
	queue_free()

func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		pts.append(Vector2(cos(a) * 9.0, sin(a) * 3.5))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.28))

func _exit_tree() -> void:
	if _bb != null and is_instance_valid(_bb):
		_bb.queue_free()
