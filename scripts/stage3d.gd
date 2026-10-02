class_name Stage3D
extends Node3D
## 3D-Bühne im Stil von Cult of the Lamb: Perspektivkamera schräg von oben, 3D-Wände/Tische mit Licht und
## Schatten, aufrechte 2D-Figuren (Billboard3D). Die Spiellogik läuft weiterhin in 2D-Koordinaten (Arena in
## einem SubViewport, dessen Bild als Boden dient: Bodengrafik, Pfützen, Ringe, Decals).
## Umrechnung: 2D (x, y) Pixel  ->  3D (x * S, 0, y * S).

const S := 0.01
const WORLD := Vector2(1600, 1020)
const GSCALE := 1.5
const CAM_ELEV := 0.95          # Kamerahöhenwinkel (rad, ~54 Grad)
const PLAY := Rect2(70, 125, 1460, 825)

var ground: SubViewport
var sprites: Node3D
var props: Node3D
var fx3: Node3D
var camera: StageCamera
var sun: DirectionalLight3D
var env: Environment
var floor_mat: StandardMaterial3D
var text_layer: Control
var overlay: Control
var _tint := Color.WHITE
var _wall_mats: Array = []
var _desks: Array = []
var _lights: Array = []

func _ready() -> void:
	ground = SubViewport.new()
	ground.size = Vector2i(int(WORLD.x * GSCALE), int(WORLD.y * GSCALE))
	ground.transparent_bg = false
	ground.disable_3d = true
	ground.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if OS.get_cmdline_user_args().has("--lowground"):
		ground.size = Vector2i(int(WORLD.x), int(WORLD.y))
	ground.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	ground.gui_disable_input = true
	add_child(ground)
	call_deferred("_apply_canvas_scale")
	sprites = Node3D.new()
	add_child(sprites)
	props = Node3D.new()
	add_child(props)
	fx3 = Node3D.new()
	add_child(fx3)
	_build_environment()
	_build_floor()
	camera = StageCamera.new()
	add_child(camera)
	camera.current = true
	# Tilt-Shift + Vignette (Diorama-Look), unterhalb von HUD und Overlay
	var post := CanvasLayer.new()
	post.layer = 2
	add_child(post)
	var pr := ColorRect.new()
	pr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pm := ShaderMaterial.new()
	pm.shader = load("res://effects/tiltshift.gdshader")
	pr.material = pm
	post.add_child(pr)
	post.visible = not OS.get_cmdline_user_args().has("--notilt")
	# Screen-Space-Ebene: Gesundheitsbalken, Warnsymbole, schwebende Zahlen
	var cl := CanvasLayer.new()
	cl.layer = 3
	add_child(cl)
	overlay = StageOverlay.new()
	overlay.stage = self
	cl.add_child(overlay)
	text_layer = Control.new()
	text_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(text_layer)

func _apply_canvas_scale() -> void:
	ground.canvas_transform = Transform2D(0.0, Vector2(GSCALE, GSCALE), 0.0, Vector2.ZERO)

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.06, 0.1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.95, 0.86)
	env.ambient_light_energy = 0.38
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.05
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62.0, -28.0, 0.0)
	sun.light_energy = 0.46
	sun.light_color = Color(1.0, 0.94, 0.84)
	sun.shadow_enabled = not OS.get_cmdline_user_args().has("--noshadow")
	sun.shadow_blur = 2.0
	sun.directional_shadow_max_distance = 28.0
	add_child(sun)

func _build_floor() -> void:
	var m := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(WORLD.x * S, WORLD.y * S)
	m.mesh = pm
	floor_mat = StandardMaterial3D.new()
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	floor_mat.roughness = 1.0
	floor_mat.metallic_specular = 0.0
	floor_mat.albedo_texture = ground.get_texture()
	floor_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.material_override = floor_mat
	m.position = Vector3(WORLD.x * S * 0.5, 0.0, WORLD.y * S * 0.5)
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(m)

# ---------------------------------------------------------------- Umrechnung
func to3(p2: Vector2, lift_px: float = 0.0) -> Vector3:
	return Vector3(p2.x * S, lift_px * S, p2.y * S)

func world_to_screen(p2: Vector2, lift_px: float = 0.0) -> Vector2:
	var p := to3(p2, lift_px)
	if camera.is_position_behind(p):
		return Vector2(-1000, -1000)
	return camera.unproject_position(p)

## Pixel pro Welt-Pixel auf dem Bildschirm (ungefähr, nahe der Kameramitte)
func px_scale() -> float:
	return 1.1

func mouse_to_world() -> Vector2:
	var mp := get_viewport().get_mouse_position()
	var o := camera.project_ray_origin(mp)
	var d := camera.project_ray_normal(mp)
	if absf(d.y) < 0.0001:
		return Vector2.ZERO
	var t := -o.y / d.y
	var p := o + d * t
	return Vector2(p.x / S, p.z / S)

func set_tint(c: Color) -> void:
	_tint = c
	floor_mat.albedo_color = c
	sun.light_color = Color(1.0, 0.94, 0.84) * c
	env.ambient_light_color = Color(1.0, 0.95, 0.86) * c
	for m in _wall_mats:
		m.albedo_color = m.get_meta("base") * c

# ---------------------------------------------------------------- Aufbau Requisiten
func _wall_texture(kind: String, size_px: Vector2) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(size_px * 2.0)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var art := WallArt.new()
	art.kind = kind
	art.size = size_px
	art.scale = Vector2(2, 2)
	vp.add_child(art)
	add_child(vp)
	return vp.get_texture()

func _textured_quad(size: Vector2, pos: Vector3, yaw_deg: float, tex: Texture2D) -> void:
	var mi := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	mi.mesh = qm
	var mt := StandardMaterial3D.new()
	mt.albedo_texture = tex
	mt.roughness = 1.0
	mt.metallic_specular = 0.0
	mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mi.material_override = mt
	mi.position = pos
	mi.rotation_degrees.y = yaw_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	props.add_child(mi)
	_wall_mats.append(mt)
	mt.set_meta("base", Color.WHITE)

func _box(size: Vector3, pos: Vector3, color: Color, shadows: bool = true, tint_with_phase: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var mt := StandardMaterial3D.new()
	mt.albedo_color = color
	mt.roughness = 0.85
	mi.material_override = mt
	mi.position = pos
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if tint_with_phase:
		mt.set_meta("base", color)
		_wall_mats.append(mt)
	props.add_child(mi)
	return mi

func build_props(obstacles: Array) -> void:
	var P := PLAY
	# Rückwand
	var wall_h := 2.1
	_box(Vector3(WORLD.x * S + 4.0, wall_h, 0.4), Vector3(WORLD.x * S * 0.5, wall_h * 0.5, P.position.y * S - 0.2), Color(0.34, 0.38, 0.55), true, true)
	# Seitenwände und niedrige Frontkante
	var depth := (P.end.y - P.position.y) * S
	_box(Vector3(0.4, 1.5, depth + 0.4), Vector3(P.position.x * S - 0.2, 0.75, (P.position.y + P.end.y) * S * 0.5), Color(0.28, 0.32, 0.48), true, true)
	_box(Vector3(0.4, 1.5, depth + 0.4), Vector3(P.end.x * S + 0.2, 0.75, (P.position.y + P.end.y) * S * 0.5), Color(0.28, 0.32, 0.48), true, true)
	_box(Vector3(WORLD.x * S, 0.3, 0.3), Vector3(WORLD.x * S * 0.5, 0.15, P.end.y * S + 0.15), Color(0.2, 0.22, 0.34), true, true)
	# Gemalte Wandtexturen (Fenster, Türen, Spinde, Pinnwand, Risse, Spinnweben)
	var back_tex := _wall_texture("back", Vector2(1600, 210))
	_textured_quad(Vector2(WORLD.x * S, 2.1), Vector3(WORLD.x * S * 0.5, 1.05, P.position.y * S + 0.004), 0.0, back_tex)
	var side_tex := _wall_texture("side", Vector2(825, 150))
	var mid_z := (P.position.y + P.end.y) * S * 0.5
	_textured_quad(Vector2(depth, 1.5), Vector3(P.position.x * S + 0.004, 0.75, mid_z), 90.0, side_tex)
	_textured_quad(Vector2(depth, 1.5), Vector3(P.end.x * S - 0.004, 0.75, mid_z), -90.0, side_tex)
	# Schulbänke (3D, werfen Schatten)
	for r in obstacles:
		_build_desk(r)

func _build_desk(r: Rect2) -> void:
	var top_y := 0.52
	var first := props.get_child_count()
	var r2 := Rect2(r.position + Vector2(0, 14), r.size - Vector2(0, 14))
	var c := (r2.position + r2.size * 0.5) * S
	var w := r2.size.x * S
	var d := r2.size.y * S
	_box(Vector3(w, 0.07, d), Vector3(c.x, top_y, c.y), Color(0.66, 0.45, 0.24))
	_box(Vector3(w + 0.04, 0.025, d + 0.04), Vector3(c.x, top_y - 0.045, c.y), Color(0.4, 0.26, 0.12))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_box(Vector3(0.06, top_y, 0.06), Vector3(c.x + sx * (w * 0.5 - 0.1), top_y * 0.5, c.y + sz * (d * 0.5 - 0.08)), Color(0.35, 0.35, 0.42))
	# Heft und Stift (Deko)
	_box(Vector3(0.34, 0.015, 0.22), Vector3(c.x - w * 0.25, top_y + 0.045, c.y), Color(0.92, 0.92, 0.97), false)
	_box(Vector3(0.36, 0.03, 0.03), Vector3(c.x + w * 0.2, top_y + 0.05, c.y - 0.05), Color(1.0, 0.8, 0.1), false)
	var mats: Array = []
	for i in range(first, props.get_child_count()):
		var mt: StandardMaterial3D = props.get_child(i).material_override
		if not OS.get_cmdline_user_args().has("--nodesktrans"):
			mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		mats.append(mt)
	_desks.append({rect = r2, mats = mats, alpha = 1.0})

## Hübsche Aufsatz-Meshes für Mülleimer / Tafel (von den Objekt-Skripten genutzt)
func make_mesh_node(mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mt := StandardMaterial3D.new()
	mt.albedo_color = color
	mt.roughness = 0.8
	mi.material_override = mt
	props.add_child(mi)
	return mi

func _process(delta: float) -> void:
	_update_occlusion(delta)

## Bänke werden transparent, wenn Mr. Scrubbs hinter ihnen steht (Sichtlinie bleibt frei)
func _update_occlusion(delta: float) -> void:
	var pl = Game.player
	if pl == null:
		return
	var pp: Vector2 = pl.global_position
	for d in _desks:
		var r: Rect2 = d.rect
		var behind: bool = pp.x > r.position.x - 30.0 and pp.x < r.end.x + 30.0 and pp.y > r.position.y - 130.0 and pp.y < r.end.y + 4.0
		var target := 0.3 if behind else 1.0
		if absf(d.alpha - target) > 0.01:
			d.alpha = lerpf(d.alpha, target, 1.0 - exp(-12.0 * delta))
			for m in d.mats:
				var c: Color = m.albedo_color
				c.a = d.alpha
				m.albedo_color = c

## Kurzer farbiger Lichtblitz (Mündungsfeuer, Explosionen) – kleiner Pool, daher günstig
func pulse_light(p2: Vector2, color: Color, energy: float = 1.6, range_: float = 2.4, dur: float = 0.25) -> void:
	var l: OmniLight3D = null
	for x in _lights:
		if not x.visible:
			l = x
			break
	if l == null:
		if _lights.size() >= 5:
			return
		l = OmniLight3D.new()
		l.shadow_enabled = false
		l.light_energy = 0.0
		l.visible = false
		add_child(l)
		_lights.append(l)
	l.visible = true
	l.light_color = color
	l.omni_range = range_
	l.position = to3(p2, 40.0)
	l.light_energy = energy
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(func(): l.visible = false)

class StageOverlay extends Control:
	var stage: Stage3D
	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if stage == null or stage.camera == null:
			return
		for n in get_tree().get_nodes_in_group("overlay"):
			if is_instance_valid(n) and n.is_inside_tree() and n.has_method("draw_overlay"):
				n.draw_overlay(self, stage.world_to_screen(n.global_position))
