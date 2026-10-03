class_name SpriteBatch
extends Node3D
## Gebatchte Billboards: Alle Gegner/Münzen/XP werden mit EINEM MultiMesh (plus eins für Schatten) gezeichnet.
## Textur-Atlas wird einmal gebaut. Handles (BatchSprite) haben die gleiche API wie Billboard3D.

const ATLAS_SIZE := 2048
const MAX_INSTANCES := 320
const MAX_TEX_H := 240.0

static var _atlas_tex: ImageTexture
static var _regions: Dictionary = {}     # Pfad -> {idx, uv: Rect2, aspect}
static var _region_list: Array = []

var _sprites: Array = []
var _mm_s: MultiMesh
var _mm_sh: MultiMesh
var _inst_s: MultiMeshInstance3D
var _inst_sh: MultiMeshInstance3D
var _buf_s := PackedFloat32Array()
var _buf_sh := PackedFloat32Array()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000      # nach allen Rigs, die ihre Handles aktualisieren
	_build_atlas()
	_inst_sh = _make_instance("res://effects/batch_shadow.gdshader", -1)
	_mm_sh = _inst_sh.multimesh
	_inst_s = _make_instance("res://effects/batch_sprite.gdshader", 0)
	_mm_s = _inst_s.multimesh
	_buf_s.resize(MAX_INSTANCES * 20)
	_buf_sh.resize(MAX_INSTANCES * 20)

func _make_instance(shader_path: String, priority: int) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.use_custom_data = true
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	qm.center_offset = Vector3(0, 0.5, 0)
	var mat := ShaderMaterial.new()
	mat.shader = load(shader_path)
	mat.set_shader_parameter("atlas", _atlas_tex)
	var arr := PackedVector4Array()
	arr.resize(64)
	for i in _region_list.size():
		var r: Rect2 = _region_list[i]
		arr[i] = Vector4(r.position.x, r.position.y, r.size.x, r.size.y)
	mat.set_shader_parameter("regions", arr)
	qm.material = mat
	mm.mesh = qm
	mm.instance_count = MAX_INSTANCES
	mm.visible_instance_count = 0
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.custom_aabb = AABB(Vector3(-3, -2, -3), Vector3(24, 8, 18))
	add_child(mi)
	return mi

static func _build_atlas() -> void:
	if _atlas_tex != null:
		return
	var paths: Array = []
	for id in Db.enemies:
		var e: EnemyData = Db.enemies[id]
		for t in e.textures:
			if not paths.has(t):
				paths.append(t)
		if e.tex_alt != "" and not paths.has(e.tex_alt):
			paths.append(e.tex_alt)
	for extra in ["res://assets/icons/i_24.png", "res://assets/items/sandwich.png", "circle"]:
		paths.append(extra)
	var atlas := Image.create(ATLAS_SIZE, ATLAS_SIZE, false, Image.FORMAT_RGBA8)
	atlas.fill(Color(0, 0, 0, 0))
	var x := 4
	var y := 4
	var row_h := 0
	for p in paths:
		var img: Image
		if p == "circle":
			img = Juice.circle_tex().get_image()
		else:
			img = (load(p) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGBA8)
		var aspect := float(img.get_width()) / float(img.get_height())
		if img.get_height() > MAX_TEX_H:
			var s := MAX_TEX_H / float(img.get_height())
			img.resize(int(img.get_width() * s), int(MAX_TEX_H), Image.INTERPOLATE_LANCZOS)
		var w := img.get_width()
		var h := img.get_height()
		if x + w + 4 > ATLAS_SIZE:
			x = 4
			y += row_h + 4
			row_h = 0
		atlas.blit_rect(img, Rect2i(0, 0, w, h), Vector2i(x, y))
		var uv := Rect2(float(x) / ATLAS_SIZE, float(y) / ATLAS_SIZE, float(w) / ATLAS_SIZE, float(h) / ATLAS_SIZE)
		_regions[p] = {idx = _region_list.size(), aspect = aspect}
		_region_list.append(uv)
		x += w + 4
		row_h = maxi(row_h, h)
	atlas.generate_mipmaps()
	_atlas_tex = ImageTexture.create_from_image(atlas)

static func region_key(tex: Texture2D) -> String:
	if tex == null:
		return ""
	if tex == Juice.circle_tex():
		return "circle"
	return tex.resource_path

## Neues Handle; null, wenn die Textur nicht im Atlas ist (Aufrufer nutzt dann Billboard3D)
func add(tex: Texture2D, height_px: float, with_shadow: bool = true) -> BatchSprite:
	var key := region_key(tex)
	if not _regions.has(key) or _sprites.size() >= MAX_INSTANCES:
		return null
	var h := BatchSprite.new()
	h.batch = self
	h.height_px = height_px
	h.shadow = with_shadow
	h.set_tex(tex)
	_sprites.append(h)
	return h

func remove(h: BatchSprite) -> void:
	h.alive = false
	var i := _sprites.find(h)
	if i >= 0:
		# Swap-and-pop hält das Array kompakt
		_sprites[i] = _sprites[_sprites.size() - 1]
		_sprites.pop_back()

func _process(_delta: float) -> void:
	var n := 0
	var m := 0
	var tilt := -Stage3D.CAM_ELEV * 0.82
	var tilt_basis := Basis(Vector3.RIGHT, tilt)
	var shadow_pre := Basis(Vector3.UP, -0.38) * Basis(Vector3.RIGHT, -PI / 2.0)
	for h in _sprites:
		if not h.visible:
			continue
		var hh: float = h.height_px * Stage3D.S
		var ww: float = hh * h.aspect
		var b: Basis = tilt_basis * Basis(Vector3.BACK, h.rot) * Basis.from_scale(Vector3(ww * h.scale2.x, hh * h.scale2.y, 1.0))
		_write(_buf_s, n, b, h.pos, h.tint, h.region, h.flash, h.fx)
		n += 1
		if h.shadow:
			var op: float = 0.62 * h.tint.a * (1.0 - clampf(h.lift / 90.0, 0.0, 0.65))
			var sb: Basis = shadow_pre * Basis.from_scale(Vector3(ww * h.scale2.x * (1.0 + h.lift * 0.004), hh * 0.95 * h.scale2.y, 1.0))
			_write(_buf_sh, m, sb, Vector3(h.pos.x, 0.006, h.pos.z), Color(1, 1, 1, op), h.region, 0.0)
			m += 1
	_mm_s.visible_instance_count = n
	_mm_sh.visible_instance_count = m
	if n > 0:
		RenderingServer.multimesh_set_buffer(_mm_s.get_rid(), _buf_s)
	if m > 0:
		RenderingServer.multimesh_set_buffer(_mm_sh.get_rid(), _buf_sh)

func _write(buf: PackedFloat32Array, i: int, b: Basis, o: Vector3, col: Color, region: int, flash: float, fx: float = 0.0) -> void:
	var k := i * 20
	buf[k] = b.x.x
	buf[k + 1] = b.y.x
	buf[k + 2] = b.z.x
	buf[k + 3] = o.x
	buf[k + 4] = b.x.y
	buf[k + 5] = b.y.y
	buf[k + 6] = b.z.y
	buf[k + 7] = o.y
	buf[k + 8] = b.x.z
	buf[k + 9] = b.y.z
	buf[k + 10] = b.z.z
	buf[k + 11] = o.z
	buf[k + 12] = col.r
	buf[k + 13] = col.g
	buf[k + 14] = col.b
	buf[k + 15] = col.a
	buf[k + 16] = float(region)
	buf[k + 17] = flash
	buf[k + 18] = fx
	buf[k + 19] = 0.0
