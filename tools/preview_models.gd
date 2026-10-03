extends SceneTree
## Vorschau: rendert alle .glb eines Ordners in ein Raster (Blickwinkel wie im Spiel) und speichert ein Bild.
## Aufruf: godot --path . -s tools/preview_models.gd -- <res-Ordner> <Ausgabedatei> [Filter]
var _frames := 0
var _items: Array = []
var _world: Node3D
var _out := ""
const COLS := 8

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var dir: String = args[0]
	_out = args[1]
	var filt: String = args[2] if args.size() > 2 else ""
	_world = Node3D.new()
	get_root().add_child(_world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.25, 0.27, 0.33)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color.WHITE
	e.ambient_light_energy = 0.7
	env.environment = e
	_world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(-50), deg_to_rad(30), 0)), Vector3.ZERO)
	_world.add_child(sun)
	var files: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".glb") and (filt == "" or f.contains(filt)):
			files.append(f)
	files.sort()
	var i := 0
	for f in files:
		var ps: PackedScene = load(dir + "/" + f)
		if ps == null:
			print("NICHT LADBAR ", f)
			continue
		var node: Node3D = ps.instantiate()
		var holder := Node3D.new()
		_world.add_child(holder)
		holder.add_child(node)
		_items.append({holder = holder, node = node, col = i % COLS, row = i / COLS, name = f.get_basename()})
		i += 1
	var rows := (i + COLS - 1) / COLS
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(13.0, rows * 3.6)
	_world.add_child(cam)
	var mid := Vector3((COLS - 1) * 1.5, 0.6, (rows - 1) * 1.6)
	cam.transform = Transform3D(Basis(), mid + Vector3(0.0, 14.0, 10.0)).looking_at(mid, Vector3.UP)
	cam.current = true

func _process(_d: float) -> bool:
	_frames += 1
	if _frames == 2:
		for it in _items:
			var st := {tris = 0, meshes = 0}
			var ab := _bounds(it.node, Transform3D(), st)
			var m: float = maxf(ab.size.x, maxf(ab.size.y, ab.size.z))
			var s := 2.2 / maxf(m, 0.0001)
			it.holder.scale = Vector3.ONE * s
			var c := ab.get_center()
			it.holder.position = Vector3(it.col * 3.0, 0.0, it.row * 3.2) - Vector3(c.x, ab.position.y, c.z) * s
			var l := Label3D.new()
			l.text = it.name
			l.font_size = 40
			l.pixel_size = 0.006
			l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			l.no_depth_test = true
			l.position = Vector3(it.col * 3.0, -0.2, it.row * 3.2 + 1.35)
			_world.add_child(l)
			print("%-28s groesse=%s teile=%d dreiecke=%d" % [it.name, str(ab.size.snapped(Vector3(0.01, 0.01, 0.01))), st.meshes, st.tris])
	if _frames == 14:
		get_root().get_texture().get_image().save_png(_out)
		quit()
	return false

func _bounds(n: Node, parent: Transform3D, st: Dictionary) -> AABB:
	var xf := parent
	if n is Node3D:
		xf = parent * n.transform
	var out := AABB()
	var first := true
	if n is MeshInstance3D and n.mesh != null:
		out = xf * n.mesh.get_aabb()
		first = false
		st.meshes += 1
		for s in n.mesh.get_surface_count():
			var arr: Array = n.mesh.surface_get_arrays(s)
			var idx = arr[Mesh.ARRAY_INDEX]
			st.tris += (idx.size() if idx != null and idx.size() > 0 else arr[Mesh.ARRAY_VERTEX].size()) / 3
	for c in n.get_children():
		var b := _bounds(c, xf, st)
		if b.size != Vector3.ZERO:
			out = b if first else out.merge(b)
			first = false
	return out
