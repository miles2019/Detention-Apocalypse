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
const P_TOP := 1.25        # Oberkante des Spielfelds in 3D (PLAY.position.y * S)

var ground: SubViewport
var sprites: Node3D
var batch: SpriteBatch
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
var _post_mat: ShaderMaterial
var _blackout := 0.0
var _fx_phase: CPUParticles3D
var _fx_event: CPUParticles3D
var _post_tw: Tween
var _trail_s: TrailPool
var _trail_b: TrailPool
var _flash_fx: TrailPool

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
	batch = SpriteBatch.new()
	add_child(batch)
	props = Node3D.new()
	add_child(props)
	fx3 = Node3D.new()
	add_child(fx3)
	_build_environment()
	_build_emitters()
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
	_post_mat = pm
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

## Partikel-Pools für Projektil-Schweife und Mündungs-/Trefferblitze (je ein MultiMesh, sehr günstig)
func _build_emitters() -> void:
	_trail_s = TrailPool.new()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://effects/trail_smoke.gdshader")
	sm.set_shader_parameter("noise_tex", Juice.smoke_material().get_shader_parameter("noise_tex"))
	_trail_s.setup(420, 0.42, true, sm)
	add_child(_trail_s)
	_trail_b = TrailPool.new()
	_trail_b.setup(160, 0.6, true, sm)
	add_child(_trail_b)
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.vertex_color_use_as_albedo = true
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.albedo_texture = Juice.circle_tex()
	mt.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_flash_fx = TrailPool.new()
	_flash_fx.setup(80, 0.16, false, mt)
	add_child(_flash_fx)

func emit_trail(p2: Vector2, lift_px: float, color: Color, big: bool = false) -> void:
	if big:
		_trail_b.emit(to3(p2, lift_px), color, 0.34)
	else:
		_trail_s.emit(to3(p2, lift_px), color, 0.17)

## Mündungs-/Trefferblitz: kurz aufleuchtender Lichtball
func flash_at(p2: Vector2, lift_px: float, color: Color, size: float = 1.0) -> void:
	_flash_fx.emit(to3(p2, lift_px), color, 0.3 + 0.16 * size)

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
	sun.rotation_degrees = Vector3(-50.0, 16.0, 0.0)
	sun.shadow_opacity = 0.9
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 1.0
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
func _wall_texture(kind: String, size_px: Vector2, style: String = "classroom") -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(size_px * 2.0)
	vp.disable_3d = true
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var art := WallArt.new()
	art.kind = kind
	art.style = style
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

func build_props(obstacles: Array, style: String = "classroom") -> void:
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
	var back_tex := _wall_texture("back", Vector2(1600, 210), style)
	_textured_quad(Vector2(WORLD.x * S, 2.1), Vector3(WORLD.x * S * 0.5, 1.05, P.position.y * S + 0.004), 0.0, back_tex)
	var side_tex := _wall_texture("side", Vector2(825, 150), style)
	var mid_z := (P.position.y + P.end.y) * S * 0.5
	_textured_quad(Vector2(depth, 1.5), Vector3(P.position.x * S + 0.004, 0.75, mid_z), 90.0, side_tex)
	_textured_quad(Vector2(depth, 1.5), Vector3(P.end.x * S - 0.004, 0.75, mid_z), -90.0, side_tex)
	# Schulbänke (3D, werfen Schatten)
	for r in obstacles:
		if style == "library" and (r.size.x < 80.0 or r.size.y > 150.0):
			_build_shelf(r)
		else:
			_build_desk(r, style)

func _build_desk(r: Rect2, style: String = "classroom") -> void:
	if style == "classroom" and _build_model_desk(r):
		return
	if style == "lab" and _build_lab_table(r):
		return
	if style in ["cafeteria", "gym", "computer", "art", "toilet", "bus"]:
		_build_room_obstacle(r, style)
		return
	if style == "library" and _build_office_desk(r):
		return
	var top_y := 0.52
	var first := props.get_child_count()
	var r2 := Rect2(r.position + Vector2(0, 14), r.size - Vector2(0, 14))
	var c := (r2.position + r2.size * 0.5) * S
	var w := r2.size.x * S
	var d := r2.size.y * S
	var top_col := Color(0.66, 0.45, 0.24)
	if style == "lab":
		top_col = Color(0.85, 0.9, 0.9)
	elif style == "library":
		top_col = Color(0.45, 0.28, 0.16)
	_box(Vector3(w, 0.07, d), Vector3(c.x, top_y, c.y), top_col)
	if style == "lab":
		# bunte Kolben auf dem Labortisch
		for k in 3:
			var cm := CylinderMesh.new()
			cm.top_radius = 0.04
			cm.bottom_radius = 0.07
			cm.height = 0.16
			var fl := make_mesh_node(cm, [Color(0.4, 0.9, 0.4), Color(0.9, 0.4, 0.8), Color(0.4, 0.7, 1.0)][k])
			fl.position = Vector3(c.x - w * 0.3 + k * 0.3, top_y + 0.11, c.y + 0.05)
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
	var nodes: Array = []
	for i in range(first, props.get_child_count()):
		nodes.append(props.get_child(i))
	_desks.append({rect = r2, mats = mats, alpha = 1.0, src = r, nodes = nodes})

## Klassenzimmer-Möbel aus dem Low-Poly-Paket (siehe CREDITS.md): zwei Schülertische mit Stühlen nebeneinander,
## bei tiefen Hindernissen ein Lehrerpult. Gibt false zurück, wenn die Modelle fehlen (dann greifen die Platzhalter).
func _build_model_desk(r: Rect2) -> bool:
	var r2 := Rect2(r.position + Vector2(0, 14), r.size - Vector2(0, 14))
	var c := (r2.position + r2.size * 0.5) * S
	var w := r2.size.x * S
	var nodes: Array = []
	if r.size.y > 70.0:
		var td := _place_model(ModelLib.CLASSROOM, "Teacher_desk", Vector3(c.x, 0.0, c.y), w * 0.97, 0.0)
		if td == null:
			return false
		nodes.append(td)
		var top: float = td.get_meta("top")
		var book := _place_model(ModelLib.CLASSROOM, "libro_quaderno2", Vector3(c.x - w * 0.22, top, c.y + 0.05), 0.38, 0.3)
		if book != null:
			nodes.append(book)
	else:
		for side in [-1.0, 1.0]:
			var x: float = c.x + side * w * 0.25
			var desk := _place_model(ModelLib.CLASSROOM, "student_desk", Vector3(x, 0.0, c.y), w * 0.49, 0.0)
			if desk == null:
				return false
			nodes.append(desk)
			var chair := _place_model(ModelLib.CLASSROOM, "student_chair", Vector3(x, 0.0, c.y - 0.2), w * 0.21, PI)
			if chair != null:
				nodes.append(chair)
		var top2: float = nodes[0].get_meta("top")
		var book2 := _place_model(ModelLib.CLASSROOM, "libro_quaderno2", Vector3(c.x - w * 0.25, top2, c.y + 0.04), 0.3, -0.25)
		if book2 != null:
			nodes.append(book2)
	var mats: Array = []
	for n in nodes:
		var mi: MeshInstance3D = n
		for s in mi.mesh.get_surface_count():
			var mt: StandardMaterial3D = mi.get_surface_override_material(s)
			if not OS.get_cmdline_user_args().has("--nodesktrans"):
				mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			mats.append(mt)
	_desks.append({rect = r2, mats = mats, alpha = 1.0, src = r, nodes = nodes})
	return true

## Labortisch (Styloo-Paket) mit Kolben und Globus als Deko
func _build_lab_table(r: Rect2) -> bool:
	var r2 := Rect2(r.position + Vector2(0, 14), r.size - Vector2(0, 14))
	var c := (r2.position + r2.size * 0.5) * S
	var w := r2.size.x * S
	var table := _place_model(ModelLib.STYLOO % "chem_table", "", Vector3(c.x, 0.0, c.y), w * 0.98, 0.0)
	if table == null:
		return false
	var nodes: Array = [table]
	var top: float = table.get_meta("top")
	var flask := _place_model(ModelLib.STYLOO % "chem_vial_002", "", Vector3(c.x - w * 0.3, top, c.y), 0.13, 0.0)
	if flask != null:
		nodes.append(flask)
	if int(r.position.x + r.position.y) % 3 == 0:
		var globe := _place_model(ModelLib.STYLOO % "chem_globe_1", "", Vector3(c.x + w * 0.28, top, c.y), 0.2, 0.6)
		if globe != null:
			nodes.append(globe)
	_register_models(r, r2, nodes, false)
	return true

## Schreibtisch des Rektors als großer Tisch in der Bibliothek
func _build_office_desk(r: Rect2) -> bool:
	var r2 := Rect2(r.position + Vector2(0, 14), r.size - Vector2(0, 14))
	var c := (r2.position + r2.size * 0.5) * S
	var desk := _place_fit(ModelLib.STYLOO % "office_desk", Vector3(c.x, 0.0, c.y), Vector3(r2.size.x * S * 0.98, 0.62, r2.size.y * S * 1.05), 0.0)
	if desk == null:
		return false
	var nodes: Array = [desk]
	var plant := _place_model(ModelLib.STYLOO % "office_plant", "", Vector3(c.x + r2.size.x * S * 0.36, 0.62, c.y), 0.2, 0.0)
	if plant != null:
		nodes.append(plant)
	_register_models(r, r2, nodes, false)
	return true

## Hindernisse der Kapitel 4-9: Mensatische, Sprungkästen, PC-Tische, Staffeleien/Statue, Kabinenwände/Waschbecken, Bussitze.
## Modelle aus dem Styloo-Paket, wo vorhanden; sonst einfache Grundformen.
func _build_room_obstacle(r: Rect2, style: String) -> void:
	var r2 := Rect2(r.position + Vector2(0, 14), r.size - Vector2(0, 14))
	var c := (r2.position + r2.size * 0.5) * S
	var w := r2.size.x * S
	var d := r2.size.y * S
	var first := props.get_child_count()
	var tall := false
	match style:
		"cafeteria":
			if _place_fit(ModelLib.STYLOO % "cafe_table", Vector3(c.x, 0.0, c.y), Vector3(w * 0.98, 0.5, d * 1.05), 0.0) == null:
				_box(Vector3(w, 0.5, d), Vector3(c.x, 0.25, c.y), Color(0.45, 0.3, 0.2))
			for side in [-1.0, 1.0]:
				_place_model(ModelLib.STYLOO % "cafe_chair", "", Vector3(c.x + side * w * 0.26, 0.0, c.y - d * 0.5 - 0.04), 0.3, 0.0)
		"gym":
			# Sprungkasten: gestapelte Holzrahmen mit Lederpolster
			for k in 3:
				_box(Vector3(w * (1.0 - 0.07 * k), 0.17, d * (1.0 - 0.1 * k)), Vector3(c.x, 0.085 + k * 0.17, c.y), Color(0.78, 0.6, 0.36) if k % 2 == 0 else Color(0.7, 0.52, 0.3))
			_box(Vector3(w * 0.84, 0.07, d * 0.78), Vector3(c.x, 0.545, c.y), Color(0.45, 0.2, 0.16))
		"computer":
			if _place_fit(ModelLib.STYLOO % "pc_table", Vector3(c.x, 0.0, c.y), Vector3(w * 0.98, 0.5, d * 1.05), 0.0) == null:
				_box(Vector3(w, 0.5, d), Vector3(c.x, 0.25, c.y), Color(0.9, 0.9, 0.92))
			for side in [-1.0, 1.0]:
				var scr := _place_model(ModelLib.STYLOO % "pc_screen", "", Vector3(c.x + side * w * 0.24, 0.5, c.y - d * 0.1), w * 0.36, 0.0)
				if scr == null:
					_box(Vector3(w * 0.34, 0.28, 0.04), Vector3(c.x + side * w * 0.24, 0.66, c.y), Color(0.12, 0.14, 0.2))
		"art":
			if r.size.x > 150.0:
				if _place_fit(ModelLib.STYLOO % "art_table", Vector3(c.x, 0.0, c.y), Vector3(w * 0.98, 0.55, d * 1.05), 0.0) == null:
					_box(Vector3(w, 0.55, d), Vector3(c.x, 0.275, c.y), Color(0.25, 0.25, 0.28))
			elif r.size.x > 80.0:
				if _place_model(ModelLib.STYLOO % "art_statue", "", Vector3(c.x, 0.0, c.y), w * 0.95, 0.0) == null:
					_box(Vector3(w * 0.8, 0.9, d * 0.8), Vector3(c.x, 0.45, c.y), Color(0.9, 0.9, 0.88))
			else:
				tall = true
				if _place_fit(ModelLib.STYLOO % "art_easel", Vector3(c.x, 0.0, c.y), Vector3(w * 0.95, 1.1, d * 1.1), 0.0) == null:
					_box(Vector3(w * 0.8, 1.1, 0.06), Vector3(c.x, 0.55, c.y), Color(0.95, 0.5, 0.15))
				# Leinwand mit Farbklecks
				_box(Vector3(w * 0.7, 0.5, 0.03), Vector3(c.x, 0.72, c.y + 0.06), Color(0.96, 0.95, 0.9))
				_box(Vector3(w * 0.34, 0.24, 0.035), Vector3(c.x - w * 0.08, 0.75, c.y + 0.063), [Color("ff5fa8"), Color("5fd0ff"), Color("ffd84a"), Color("8be05a")][int(r.position.x) % 4])
		"toilet":
			if r.size.x < 60.0:
				tall = true
				# Kabinenwand
				_box(Vector3(w * 1.2, 1.15, d), Vector3(c.x, 0.65, c.y), Color(0.98, 0.93, 0.55))
				_box(Vector3(w * 1.4, 0.08, d), Vector3(c.x, 1.25, c.y), Color(0.75, 0.7, 0.35))
				for sz in [-1.0, 1.0]:
					_box(Vector3(0.05, 0.16, 0.05), Vector3(c.x, 0.08, c.y + sz * d * 0.42), Color(0.5, 0.52, 0.56))
				_place_model(ModelLib.STYLOO % "wc_basictoilet", "", Vector3(c.x + 1.25, 0.0, P_TOP + 0.5), 0.36, 0.0)
			else:
				_box(Vector3(w, 0.42, d * 0.9), Vector3(c.x, 0.21, c.y), Color(0.86, 0.9, 0.92))
				if _place_fit(ModelLib.STYLOO % "wc_sink", Vector3(c.x, 0.42, c.y), Vector3(w * 1.02, 0.12, d), 0.0) == null:
					_box(Vector3(w * 1.02, 0.08, d), Vector3(c.x, 0.46, c.y), Color(1, 1, 1))
				# Spiegel
				_box(Vector3(w * 0.9, 0.5, 0.03), Vector3(c.x, 0.95, c.y - d * 0.5), Color(0.7, 0.88, 0.95))
		"bus":
			# Sitzbank mit Lehne
			var up := r.position.y < 500.0
			_box(Vector3(w, 0.3, d * 0.85), Vector3(c.x, 0.15, c.y), Color(0.24, 0.42, 0.6))
			_box(Vector3(w, 0.5, 0.1), Vector3(c.x, 0.55, c.y + (-d * 0.4 if up else d * 0.4)), Color(0.2, 0.36, 0.54))
			_box(Vector3(w * 0.96, 0.05, d * 0.7), Vector3(c.x, 0.32, c.y), Color(0.3, 0.5, 0.7))
	var nodes: Array = []
	var mats: Array = []
	for i in range(first, props.get_child_count()):
		var mi: MeshInstance3D = props.get_child(i)
		nodes.append(mi)
		var found := false
		for s in mi.mesh.get_surface_count():
			var sm: Material = mi.get_surface_override_material(s)
			if sm is StandardMaterial3D:
				sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
				mats.append(sm)
				found = true
		if not found and mi.material_override is StandardMaterial3D:
			# Grundformen: eigenes Material, nicht mit der Phasen-Tönung der Wände koppeln
			mi.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			mats.append(mi.material_override)
	var entry := {rect = r2 if not tall else Rect2(r.position, r.size), mats = mats, alpha = 1.0, src = r, nodes = nodes}
	if tall:
		entry["tall"] = true
	_desks.append(entry)

## Modell-Knoten als Hindernis-Optik anmelden (Ausblenden hinter dem Spieler, Zertrümmern)
func _register_models(src: Rect2, rect: Rect2, nodes: Array, tall: bool) -> void:
	var mats: Array = []
	for n in nodes:
		var mi: MeshInstance3D = n
		for s in mi.mesh.get_surface_count():
			var mt: StandardMaterial3D = mi.get_surface_override_material(s)
			if not OS.get_cmdline_user_args().has("--nodesktrans"):
				mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			mats.append(mt)
	var entry := {rect = rect, mats = mats, alpha = 1.0, src = src, nodes = nodes}
	if tall:
		entry["tall"] = true
	_desks.append(entry)

## Modell ungleichmäßig auf eine Zielgröße (Breite, Höhe, Tiefe) einpassen
func _place_fit(file: String, pos: Vector3, target: Vector3, yaw: float) -> MeshInstance3D:
	var mi := ModelLib.instance(file, "")
	if mi == null:
		return null
	var size: Vector3 = mi.get_meta("size")
	mi.scale = Vector3(target.x / maxf(size.x, 0.0001), target.y / maxf(size.y, 0.0001), target.z / maxf(size.z, 0.0001))
	mi.position = pos
	mi.rotation.y = yaw
	mi.set_meta("top", pos.y + target.y)
	props.add_child(mi)
	return mi

## Modell so skalieren, dass es "width" breit ist; steht mit der Unterkante auf pos.y. Meta "top" = Oberkante.
func _place_model(file: String, node_name: String, pos: Vector3, width: float, yaw: float) -> MeshInstance3D:
	var mi := ModelLib.instance(file, node_name)
	if mi == null:
		return null
	var size: Vector3 = mi.get_meta("size")
	var s := width / maxf(size.x, 0.0001)
	mi.scale = Vector3(s, s, s)
	mi.position = pos
	mi.rotation.y = yaw
	mi.set_meta("top", pos.y + size.y * s)
	# Holztöne des Pakets sind recht dunkel/stumpf – an die warme Palette des Spiels angleichen
	for si in mi.mesh.get_surface_count():
		var mt: StandardMaterial3D = mi.get_surface_override_material(si)
		var col := mt.albedo_color
		if col.r > col.b * 1.15 and col.s > 0.15 and col.v < 0.9:
			mt.albedo_color = Color(0.74, 0.5, 0.29).lerp(col, 0.25)
	props.add_child(mi)
	return mi

## Schulhof-Hub: Backsteinfassade, Hecken, Bäume, Basketballkorb, Bänke
func build_hub() -> void:
	var P := PLAY
	var facade := _wall_texture("back", Vector2(1600, 210), "yard")
	_box(Vector3(WORLD.x * S + 4.0, 2.1, 0.4), Vector3(WORLD.x * S * 0.5, 1.05, P.position.y * S - 0.2), Color(0.7, 0.4, 0.32), true, true)
	_textured_quad(Vector2(WORLD.x * S, 2.1), Vector3(WORLD.x * S * 0.5, 1.05, P.position.y * S + 0.004), 0.0, facade)
	var depth := (P.end.y - P.position.y) * S
	for sx in [P.position.x * S - 0.15, P.end.x * S + 0.15]:
		_box(Vector3(0.3, 0.7, depth + 0.4), Vector3(sx, 0.35, (P.position.y + P.end.y) * S * 0.5), Color(0.25, 0.5, 0.25), true, true)
	_box(Vector3(WORLD.x * S, 0.4, 0.3), Vector3(WORLD.x * S * 0.5, 0.2, P.end.y * S + 0.15), Color(0.25, 0.5, 0.25), true, true)
	# Bäume
	for tp in [Vector2(160, 250), Vector2(1440, 250), Vector2(150, 880), Vector2(1450, 880)]:
		var c: Vector2 = tp * S
		_box(Vector3(0.18, 1.0, 0.18), Vector3(c.x, 0.5, c.y), Color(0.42, 0.28, 0.16))
		var sm := SphereMesh.new()
		sm.radius = 0.62
		sm.height = 1.1
		var cr := make_mesh_node(sm, Color(0.3, 0.62, 0.3))
		cr.position = Vector3(c.x, 1.45, c.y)
	# Basketballkorb
	var hc := Vector2(1450, 560) * S
	_box(Vector3(0.08, 1.7, 0.08), Vector3(hc.x, 0.85, hc.y), Color(0.5, 0.5, 0.55))
	_box(Vector3(0.05, 0.5, 0.7), Vector3(hc.x - 0.1, 1.6, hc.y), Color(0.95, 0.95, 0.95))
	var rm := TorusMesh.new()
	rm.inner_radius = 0.13
	rm.outer_radius = 0.17
	var ring := make_mesh_node(rm, Color(0.95, 0.4, 0.15))
	ring.position = Vector3(hc.x - 0.35, 1.4, hc.y)
	# Bänke
	for bp in [Vector2(560, 880), Vector2(1040, 880)]:
		var b: Vector2 = bp * S
		_box(Vector3(1.0, 0.07, 0.3), Vector3(b.x, 0.42, b.y), Color(0.6, 0.4, 0.2))
		_box(Vector3(1.0, 0.3, 0.06), Vector3(b.x, 0.62, b.y - 0.15), Color(0.55, 0.36, 0.18))
		for lx in [-0.4, 0.4]:
			_box(Vector3(0.06, 0.4, 0.26), Vector3(b.x + lx, 0.2, b.y), Color(0.3, 0.3, 0.35))

var _spine_tex: ImageTexture

func _spines() -> ImageTexture:
	if _spine_tex != null:
		return _spine_tex
	var img := Image.create(256, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.3, 0.19, 0.12))
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for row in 4:
		var y := 6 + row * 30
		img.fill_rect(Rect2i(0, y + 26, 256, 4), Color(0.2, 0.12, 0.08))
		var x := 4
		while x < 250:
			var bw := rng.randi_range(7, 14)
			var bh := rng.randi_range(17, 25)
			var col := Color.from_hsv(rng.randf(), rng.randf_range(0.45, 0.85), rng.randf_range(0.5, 0.88))
			img.fill_rect(Rect2i(x, y + 26 - bh, bw, bh), col)
			img.fill_rect(Rect2i(x, y + 26 - bh, bw, 2), col.lightened(0.25))
			x += bw + 1
	_spine_tex = ImageTexture.create_from_image(img)
	return _spine_tex

func _build_shelf(r: Rect2) -> void:
	var c := (r.position + r.size * 0.5) * S
	var w := r.size.x * S
	var d := r.size.y * S
	var h := 1.35
	var first := props.get_child_count()
	_box(Vector3(w, h, d), Vector3(c.x, h * 0.5, c.y), Color(0.38, 0.24, 0.15))
	# Buchrücken: eine Textur-Quad je Längsseite
	for side in [1.0, -1.0]:
		var mi := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(d, h * 0.85)
		mi.mesh = qm
		var mt := StandardMaterial3D.new()
		mt.albedo_texture = _spines()
		mt.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		mt.roughness = 1.0
		mt.metallic_specular = 0.0
		mi.material_override = mt
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(c.x + side * (w * 0.5 + 0.004), h * 0.5, c.y)
		mi.rotation_degrees.y = 90.0 * side
		props.add_child(mi)
	var mats: Array = []
	for i in range(first, props.get_child_count()):
		var mt2: StandardMaterial3D = props.get_child(i).material_override
		mt2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
		mats.append(mt2)
	var nodes: Array = []
	for i in range(first, props.get_child_count()):
		nodes.append(props.get_child(i))
	_desks.append({rect = Rect2(r.position, r.size), mats = mats, alpha = 1.0, tall = true, src = r, nodes = nodes})

## Tisch/Regal zerbricht: Einzelteile fliegen auseinander und verschwinden
func destroy_desk(src: Rect2, dir: Vector2) -> void:
	for d in _desks:
		if d.src == src:
			_desks.erase(d)
			for n in d.nodes:
				if not is_instance_valid(n):
					continue
				var mi: MeshInstance3D = n
				var fly := Vector3(dir.x * 0.9 + randf_range(-0.7, 0.7), randf_range(0.5, 1.3), dir.y * 0.9 + randf_range(-0.7, 0.7))
				var tw := mi.create_tween().set_parallel(true)
				tw.tween_property(mi, "position", mi.position + fly, 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(mi, "rotation", Vector3(randf_range(-4, 4), randf_range(-4, 4), randf_range(-4, 4)), 0.55)
				tw.tween_property(mi, "scale", Vector3(0.05, 0.05, 0.05), 0.3).set_delay(0.3)
				tw.chain().tween_callback(mi.queue_free)
			return

## Tisch wackelt (beschädigt, aber noch nicht kaputt)
func shake_desk(src: Rect2) -> void:
	for d in _desks:
		if d.src == src:
			for n in d.nodes:
				if is_instance_valid(n):
					var mi: MeshInstance3D = n
					var base := mi.position
					var tw := mi.create_tween()
					tw.tween_property(mi, "position", base + Vector3(randf_range(-0.05, 0.05), 0.06, randf_range(-0.05, 0.05)), 0.05)
					tw.tween_property(mi, "position", base, 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
			return

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
	_update_post()
	_follow_fx(_fx_phase)
	_follow_fx(_fx_event)

func _update_post() -> void:
	var pl = Game.player
	if _post_mat == null or pl == null:
		return
	if _blackout > 0.001:
		var sp := world_to_screen(pl.global_position, 30.0)
		var vs := get_viewport().get_visible_rect().size
		_post_mat.set_shader_parameter("center", Vector2(sp.x / vs.x, sp.y / vs.y))
	_post_mat.set_shader_parameter("blackout", _blackout)

func _follow_fx(p: CPUParticles3D) -> void:
	if p != null and camera != null:
		p.position.x = camera.position.x
		p.position.z = camera.position.z - 4.8

## Bildschirm-Tönung (Hitzefrei, Vokabeltest) sanft einblenden
func set_post_tint(c: Color) -> void:
	if _post_mat == null:
		return
	if _post_tw:
		_post_tw.kill()
	_post_tw = create_tween()
	var cur: Color = _post_mat.get_shader_parameter("post_tint") if _post_mat.get_shader_parameter("post_tint") != null else Color.WHITE
	_post_tw.tween_method(func(k: float): _post_mat.set_shader_parameter("post_tint", cur.lerp(c, k)), 0.0, 1.0, 0.8)

## Stromausfall: alles dunkel bis auf einen Lichtkreis um Mr. Scrubbs
func set_blackout(on: bool) -> void:
	var tw := create_tween()
	tw.tween_property(self, "_blackout", 1.0 if on else 0.0, 0.7)

func set_phase_fx(id: String) -> void:
	if _fx_phase == null:
		_fx_phase = _make_fx()
	_config_fx(_fx_phase, id)
	# Nebel / Stimmung je Fach
	env.fog_enabled = true
	match id:
		"Chemie":
			env.fog_light_color = Color(0.45, 0.8, 0.45)
			env.fog_density = 0.028
		"Physik":
			env.fog_light_color = Color(0.6, 0.72, 0.95)
			env.fog_density = 0.012
		"Sport":
			env.fog_light_color = Color(1.0, 0.8, 0.55)
			env.fog_density = 0.01
		_:
			env.fog_enabled = false

func set_event_fx(id: String) -> void:
	if _fx_event == null:
		_fx_event = _make_fx()
	_config_fx(_fx_event, id)

func _make_fx() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(7.0, 0.05, 4.0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var qm := QuadMesh.new()
	qm.size = Vector2(0.06, 0.06)
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.vertex_color_use_as_albedo = true
	mt.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mt.albedo_texture = Juice.circle_tex()
	qm.material = mt
	p.mesh = qm
	add_child(p)
	return p

func _config_fx(p: CPUParticles3D, id: String) -> void:
	p.emitting = id != ""
	p.local_coords = false
	p.explosiveness = 0.0
	p.lifetime = 4.0
	p.spread = 25.0
	p.direction = Vector3.UP
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.5
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.6
	p.amount = 40
	p.color = Color(1, 1, 1, 0.5)
	match id:
		"Chemie":    # grüne Blasen steigen auf
			p.amount = 55
			p.lifetime = 3.5
			p.color = Color(0.55, 1.0, 0.45, 0.65)
			p.initial_velocity_min = 0.35
			p.initial_velocity_max = 0.8
			p.scale_amount_min = 0.8
			p.scale_amount_max = 2.6
		"Physik":    # kalte Funken / Staubkörner schweben
			p.amount = 35
			p.color = Color(0.75, 0.88, 1.0, 0.55)
			p.direction = Vector3(0.3, 0.6, 0.0)
			p.spread = 80.0
			p.initial_velocity_min = 0.1
			p.initial_velocity_max = 0.35
			p.gravity = Vector3(0, 0.05, 0)
		"Sport":     # warmer Staub zieht seitlich durch den Raum
			p.amount = 45
			p.lifetime = 2.6
			p.color = Color(1.0, 0.85, 0.55, 0.5)
			p.direction = Vector3(1.0, 0.1, 0.1)
			p.spread = 10.0
			p.initial_velocity_min = 1.2
			p.initial_velocity_max = 2.2
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.2
		"heat":      # Hitze-Flimmern
			p.amount = 60
			p.lifetime = 2.0
			p.color = Color(1.0, 0.6, 0.25, 0.5)
			p.initial_velocity_min = 0.8
			p.initial_velocity_max = 1.6
		"letters":   # Zettel regnen herab
			p.amount = 30
			p.lifetime = 3.5
			p.color = Color(1.0, 1.0, 0.95, 0.9)
			p.emission_box_extents = Vector3(7.0, 0.05, 4.0)
			p.direction = Vector3.DOWN
			p.spread = 20.0
			p.initial_velocity_min = 0.3
			p.initial_velocity_max = 0.6
			p.scale_amount_min = 3.0
			p.scale_amount_max = 5.0
	if id == "letters":
		p.position.y = 3.0
	else:
		p.position.y = 0.0

## Bänke werden transparent, wenn Mr. Scrubbs hinter ihnen steht (Sichtlinie bleibt frei)
func _update_occlusion(delta: float) -> void:
	var pl = Game.player
	if pl == null:
		return
	var pp: Vector2 = pl.global_position
	for d in _desks:
		var r: Rect2 = d.rect
		var reach_y: float = 190.0 if d.get("tall", false) else 130.0
		var behind: bool = pp.x > r.position.x - 30.0 and pp.x < r.end.x + 30.0 and pp.y > r.position.y - reach_y and pp.y < r.end.y + 4.0
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
				if n.has_method("wants_overlay") and not n.wants_overlay():
					continue
				n.draw_overlay(self, stage.world_to_screen(n.global_position))
