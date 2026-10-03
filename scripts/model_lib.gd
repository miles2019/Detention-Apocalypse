class_name ModelLib
extends RefCounted
## Lädt Objekte aus den FBX-Paketen (assets/models) und fasst alle Teil-Meshes eines Objekts zu EINEM Mesh
## zusammen (eine Oberfläche je Material) – das spart Draw-Calls. Das Ergebnis ist normiert:
## Mitte auf X/Z im Ursprung, Unterkante auf y = 0, Originalmaßstab (Größe steht in "size").
## Quellen und Lizenzen: siehe CREDITS.md.

const CLASSROOM := "res://assets/models/classroom.fbx"
const TRASH := "res://assets/models/trash_can.fbx"

static var _cache := {}

## Gibt {mesh: ArrayMesh, size: Vector3} zurück; leeres Dictionary, wenn das Objekt fehlt.
static func fetch(file: String, node_name: String) -> Dictionary:
	var key := file + "|" + node_name
	if _cache.has(key):
		return _cache[key]
	var out := {}
	var ps: PackedScene = load(file) if ResourceLoader.exists(file) else null
	if ps != null:
		var root: Node = ps.instantiate()
		var target: Node = root if (node_name == "" or root.name == node_name) else root.find_child(node_name, true, false)
		if target != null:
			out = _merge(target)
		root.free()
	if out.is_empty():
		push_warning("ModelLib: Objekt '%s' in %s nicht gefunden" % [node_name, file])
	_cache[key] = out
	return out

static func _merge(target: Node) -> Dictionary:
	var parts: Array = []
	_collect(target, Transform3D(), parts)
	if parts.is_empty():
		return {}
	var box := AABB()
	var first := true
	for p in parts:
		var ab: AABB = p.xf * p.mesh.get_aabb()
		box = ab if first else box.merge(ab)
		first = false
	var shift := Transform3D(Basis(), Vector3(-box.get_center().x, -box.position.y, -box.get_center().z))
	var tools := {}        # Material -> SurfaceTool
	var order: Array = []
	var flipped := false
	for p in parts:
		var m: Mesh = p.mesh
		var xf: Transform3D = shift * p.xf
		if xf.basis.determinant() < 0.0:
			flipped = true
		for s in m.get_surface_count():
			var mat: Material = m.surface_get_material(s)
			if not tools.has(mat):
				tools[mat] = SurfaceTool.new()
				order.append(mat)
			tools[mat].append_from(m, s, xf)
	var am := ArrayMesh.new()
	for mat in order:
		var st: SurfaceTool = tools[mat]
		st.commit(am)
		var mm: StandardMaterial3D
		if mat is StandardMaterial3D:
			mm = mat.duplicate()
		else:
			mm = StandardMaterial3D.new()
			mm.albedo_color = Color(0.7, 0.7, 0.72)
		mm.roughness = 0.85
		mm.metallic = 0.0
		if flipped:
			mm.cull_mode = BaseMaterial3D.CULL_DISABLED
		am.surface_set_material(am.get_surface_count() - 1, mm)
	return {mesh = am, size = box.size}

static func _collect(n: Node, parent: Transform3D, parts: Array) -> void:
	var xf := parent
	if n is Node3D:
		xf = parent * n.transform
	if n is MeshInstance3D and n.mesh != null:
		parts.append({mesh = n.mesh, xf = xf})
	for c in n.get_children():
		_collect(c, xf, parts)

## Fertige Instanz mit eigenen Material-Kopien (für Ausblenden/Abdunkeln einzelner Objekte)
static func instance(file: String, node_name: String) -> MeshInstance3D:
	var d := fetch(file, node_name)
	if d.is_empty():
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = d.mesh
	for s in d.mesh.get_surface_count():
		mi.set_surface_override_material(s, d.mesh.surface_get_material(s).duplicate())
	mi.set_meta("size", d.size)
	return mi
