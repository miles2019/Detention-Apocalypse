class_name Billboard3D
extends Node3D
## Aufrechtes 2D-Sprite in der 3D-Welt (wie bei Cult of the Lamb): immer zur Kamera geneigt.
## Fußpunkt = Ursprung. Squash/Stretch, Drehung, Blitz und Tönung laufen über das Shader-Material.

var sprite: Sprite3D
var mat: ShaderMaterial
var tex_h := 100.0
var _stars: Array = []
var _star_t := 0.0
var _top := 60.0

static var _shader: Shader
static var _shadow_shader: Shader
var shadow_pivot: Node3D
var shadow: Sprite3D
var _shadow_mat: ShaderMaterial
var _lift := 0.0
static var _star_tex: Texture2D

func setup(tex: Texture2D, height_px: float, with_shadow: bool = true) -> void:
	if _shader == null:
		_shader = load("res://effects/flash3d.gdshader")
		_shadow_shader = load("res://effects/shadow3d.gdshader")
	sprite = Sprite3D.new()
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sprite.rotation.x = -Stage3D.CAM_ELEV * 0.82   # leicht zur Kamera geneigt, damit die Figuren nicht gestaucht wirken
	add_child(sprite)
	mat = ShaderMaterial.new()
	mat.shader = _shader
	sprite.material_override = mat
	_top = height_px
	if with_shadow:
		# Silhouetten-Schatten: flach liegendes Abbild des Sprites, vom Fußpunkt nach hinten-rechts geworfen
		shadow_pivot = Node3D.new()
		shadow_pivot.rotation.y = -0.38
		add_child(shadow_pivot)
		shadow = Sprite3D.new()
		shadow.shaded = false
		shadow.double_sided = true
		shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shadow.rotation.x = -PI / 2.0
		shadow_pivot.add_child(shadow)
		_shadow_mat = ShaderMaterial.new()
		_shadow_mat.shader = _shadow_shader
		shadow.material_override = _shadow_mat
	set_tex(tex, height_px)

func set_tex(tex: Texture2D, height_px: float = -1.0) -> void:
	if height_px > 0.0:
		_top = height_px
	var s := _top * Stage3D.S / float(tex.get_height())
	sprite.texture = tex
	sprite.pixel_size = s
	sprite.centered = true
	sprite.offset = Vector2(0, tex.get_height() * 0.5)
	mat.set_shader_parameter("tex", tex)
	if shadow != null:
		shadow.texture = tex
		shadow.pixel_size = s
		shadow.centered = true
		shadow.offset = Vector2(0, tex.get_height() * 0.5)
		_shadow_mat.set_shader_parameter("tex", tex)

func place(p2: Vector2, lift_px: float = 0.0) -> void:
	position = Vector3(p2.x * Stage3D.S, lift_px * Stage3D.S, p2.y * Stage3D.S)
	_lift = lift_px
	if shadow_pivot != null:
		shadow_pivot.position.y = -lift_px * Stage3D.S + 0.006
		_shadow_mat.set_shader_parameter("opacity", 0.62 * (1.0 - clampf(lift_px / 90.0, 0.0, 0.65)))

var _last_body := Vector3(-99, 0, 0)
func set_body(scale2: Vector2, rot: float) -> void:
	var nb := Vector3(scale2.x, scale2.y, rot)
	if nb.is_equal_approx(_last_body):
		return
	_last_body = nb
	sprite.scale = Vector3(scale2.x, scale2.y, 1.0)
	sprite.rotation.z = rot
	if shadow != null:
		shadow.scale = Vector3(scale2.x * (1.0 + _lift * 0.004), 0.95 * scale2.y, 1.0)

func set_flash(v: float, color: Color = Color.WHITE) -> void:
	mat.set_shader_parameter("flash", v)
	mat.set_shader_parameter("flash_color", color)

var _last_tint := Color(-1, 0, 0, 0)
func set_tint(c: Color) -> void:
	if c == _last_tint:
		return
	_last_tint = c
	mat.set_shader_parameter("tint", c)
	if _shadow_mat != null:
		_shadow_mat.set_shader_parameter("opacity", 0.62 * c.a * (1.0 - clampf(_lift / 90.0, 0.0, 0.65)))

func set_light(c: Color) -> void:
	mat.set_shader_parameter("light_tint", c)

## Kleines Kind-Sprite (z.B. gehaltene Waffe), erbt Squash/Flip des Eltern-Sprites.
func add_child_sprite(tex: Texture2D, height_px: float) -> Sprite3D:
	var s := Sprite3D.new()
	s.shaded = false
	s.double_sided = true
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_OPAQUE_PREPASS
	s.texture = tex
	s.pixel_size = height_px * Stage3D.S / float(tex.get_height())
	sprite.add_child(s)
	return s

## Kreisende Sterne und Schulnoten über dem Kopf (Betäubung)
func set_stunned(on: bool) -> void:
	if on and _stars.is_empty():
		for i in 3:
			var s := Sprite3D.new()
			s.shaded = false
			s.double_sided = true
			s.texture = _make_star()
			s.pixel_size = 0.0007 if i != 1 else 0.0007
			s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
			sprite.add_child(s)
			_stars.append(s)
	elif not on and not _stars.is_empty():
		for s in _stars:
			s.queue_free()
		_stars.clear()

func _process(delta: float) -> void:
	if _stars.is_empty():
		return
	_star_t += delta * 5.0
	var top := _top * Stage3D.S / maxf(0.001, sprite.pixel_size) * sprite.pixel_size
	for i in _stars.size():
		var a := _star_t + TAU * i / 3.0
		_stars[i].position = Vector3(cos(a) * 0.2, top + 0.08 + sin(a) * 0.05, 0.02)
		_stars[i].rotation.z = a

static func _make_star() -> Texture2D:
	if _star_tex != null:
		return _star_tex
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var pts := PackedVector2Array()
	for j in 10:
		var r := 30.0 if j % 2 == 0 else 13.0
		var aa := TAU * j / 10.0 - PI / 2.0
		pts.append(Vector2(32, 32) + Vector2(cos(aa), sin(aa)) * r)
	for y in 64:
		for x in 64:
			var inside := Geometry2D.is_point_in_polygon(Vector2(x, y), pts)
			if inside:
				img.set_pixel(x, y, Color(1.0, 0.9, 0.2))
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
	_star_tex = ImageTexture.create_from_image(img)
	return _star_tex
