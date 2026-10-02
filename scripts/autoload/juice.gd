extends Node
## JuiceService: zentrale Fassade für Screen-Shake, Hit-Stop, Floating Text und Partikel.
## Spieler, Gegner, Waffen und UI lösen Effekte nur über diesen Service aus.

var shaker := ScreenShake.new()
var _burst_budget := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(delta: float) -> void:
	var strength: float = 0.0 if Game.settings.reduced_motion else Game.settings.shake
	shaker.update(delta, strength)

func fx_parent() -> Node:
	if Game.arena != null and is_instance_valid(Game.arena):
		return Game.arena.fx_layer
	return get_tree().current_scene

func shake(amount: float, dir: Vector2 = Vector2.ZERO) -> void:
	shaker.add(amount, dir)

func zoom_pop(amount: float) -> void:
	if not Game.settings.reduced_motion:
		shaker.kick_zoom(amount)

func hitstop(duration: float = 0.06, scale: float = 0.03) -> void:
	HitStop.freeze(get_tree(), duration, scale)

func slowmo(duration: float = 0.25, scale: float = 0.3) -> void:
	HitStop.freeze(get_tree(), duration, scale)

func float_text(pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 18, pop: bool = false, rise: float = 46.0) -> void:
	FloatingText.spawn(pos, 40.0, text, color, size, pop, rise)

func float_text_at(pos: Vector2, lift_px: float, text: String, color: Color = Color.WHITE, size: int = 18, pop: bool = false, rise: float = 46.0) -> void:
	FloatingText.spawn(pos, lift_px, text, color, size, pop, rise)

func ring(pos: Vector2, r: float, color: Color, dur: float = 0.4, width: float = 6.0, fill: bool = false) -> void:
	RingFX.spawn(fx_parent(), pos, r, color, dur, width, fill)

## Einmaliger Partikelspritzer (3D-Partikel). Menge wird bei vielen gleichzeitigen Effekten gedrosselt.
func burst(pos: Vector2, color: Color, amount: int = 8, speed: float = 160.0, life: float = 0.45, size: float = 3.0,
		spread: float = 180.0, dir: Vector2 = Vector2.RIGHT, gravity: float = 0.0, shape: String = "square", lift: float = 22.0) -> void:
	if Game.arena == null or not is_instance_valid(Game.arena):
		return
	var stage: Stage3D = Game.arena.stage
	if get_tree().get_node_count_in_group("burst") > 40:
		amount = maxi(1, amount / 3)
	var p := CPUParticles3D.new()
	p.add_to_group("burst")
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.mesh = _quad_mesh(shape == "circle")
	if dir == Vector2.UP:
		p.direction = Vector3.UP
	else:
		p.direction = Vector3(dir.x, 0.45, dir.y).normalized()
	p.spread = clampf(spread, 5.0, 180.0)
	p.initial_velocity_min = speed * 0.5 * Stage3D.S
	p.initial_velocity_max = speed * Stage3D.S
	p.gravity = Vector3(0, -maxf(gravity, 260.0) * Stage3D.S, 0)
	p.damping_min = speed * 0.4 * Stage3D.S
	p.damping_max = speed * 0.9 * Stage3D.S
	p.scale_amount_min = size * 1.4
	p.scale_amount_max = size * 2.6
	var curve := Curve.new()
	curve.add_point(Vector2(0, 1))
	curve.add_point(Vector2(1, 0))
	p.scale_amount_curve = curve
	p.color = color
	if shape == "circle":
		# Rauch-Puffs lösen sich über die Lebenszeit auf (Alpha-Rampe steuert den Shader)
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 1.0))
		ramp.set_color(1, Color(1, 1, 1, 0.0))
		p.color_ramp = ramp
		p.scale_amount_min = size * 2.4
		p.scale_amount_max = size * 4.2
		p.scale_amount_curve = null
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stage.fx3.add_child(p)
	p.position = stage.to3(pos, lift)
	p.emitting = true
	get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)

## Stylisierter Rauch-Shader (aus dem Smoke-Projekt) als gemeinsames Material
var _smoke_mat: ShaderMaterial
func smoke_material() -> ShaderMaterial:
	if _smoke_mat == null:
		_smoke_mat = ShaderMaterial.new()
		_smoke_mat.shader = load("res://effects/smoke3d.gdshader")
		var nz := FastNoiseLite.new()
		nz.noise_type = FastNoiseLite.TYPE_CELLULAR
		nz.frequency = 0.045
		nz.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		var nt := NoiseTexture2D.new()
		nt.width = 128
		nt.height = 128
		nt.seamless = true
		nt.noise = nz
		_smoke_mat.set_shader_parameter("noise_tex", nt)
	return _smoke_mat

var _qmesh: QuadMesh
var _qmesh_c: QuadMesh
func _quad_mesh(round_shape: bool) -> QuadMesh:
	var m: QuadMesh = _qmesh_c if round_shape else _qmesh
	if m == null:
		m = QuadMesh.new()
		m.size = Vector2(Stage3D.S, Stage3D.S)
		if round_shape:
			m.material = smoke_material()
			_qmesh_c = m
			return m
		var mt := StandardMaterial3D.new()
		mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mt.vertex_color_use_as_albedo = true
		mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		mt.billboard_keep_scale = true
		mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if round_shape:
			mt.albedo_texture = circle_tex()
		m.material = mt
		if round_shape:
			_qmesh_c = m
		else:
			_qmesh = m
	return m

var _ctex: Texture2D
func _circle_tex() -> Texture2D:
	if _ctex == null:
		var g := GradientTexture2D.new()
		g.width = 16
		g.height = 16
		g.fill = GradientTexture2D.FILL_RADIAL
		g.fill_from = Vector2(0.5, 0.5)
		g.fill_to = Vector2(1.0, 0.5)
		var grad := Gradient.new()
		grad.set_color(0, Color(1, 1, 1, 1))
		grad.set_color(1, Color(1, 1, 1, 0))
		grad.add_point(0.6, Color(1, 1, 1, 1))
		g.gradient = grad
		_ctex = g
	return _ctex

func circle_tex() -> Texture2D:
	return _circle_tex()
