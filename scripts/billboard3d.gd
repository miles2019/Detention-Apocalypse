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
static var _star_tex: Texture2D

func setup(tex: Texture2D, height_px: float) -> void:
	if _shader == null:
		_shader = load("res://effects/flash3d.gdshader")
	sprite = Sprite3D.new()
	sprite.shaded = false
	sprite.double_sided = true
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	sprite.rotation.x = -Stage3D.CAM_ELEV * 0.82   # leicht zur Kamera geneigt, damit die Figuren nicht gestaucht wirken
	add_child(sprite)
	mat = ShaderMaterial.new()
	mat.shader = _shader
	sprite.material_override = mat
	_top = height_px
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

func place(p2: Vector2, lift_px: float = 0.0) -> void:
	position = Vector3(p2.x * Stage3D.S, lift_px * Stage3D.S, p2.y * Stage3D.S)

func set_body(scale2: Vector2, rot: float) -> void:
	sprite.scale = Vector3(scale2.x, scale2.y, 1.0)
	sprite.rotation.z = rot

func set_flash(v: float, color: Color = Color.WHITE) -> void:
	mat.set_shader_parameter("flash", v)
	mat.set_shader_parameter("flash_color", color)

func set_tint(c: Color) -> void:
	mat.set_shader_parameter("tint", c)

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
