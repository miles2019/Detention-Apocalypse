class_name TrailPool
extends MultiMeshInstance3D
## Ringpuffer kurzlebiger Billboard-Partikel in EINEM MultiMesh (Projektil-Schweife, Mündungs-/Trefferblitze).
## Ersatz für GPUParticles3D.emit_particle, das der Compatibility-Renderer nicht unterstützt.

var capacity := 400
var life := 0.5
var shrink := true            # schrumpft über die Lebenszeit auf 0 (Schweif) statt nur auszublenden (Blitz)
var _pos := PackedVector3Array()
var _col := PackedColorArray()
var _age := PackedFloat32Array()
var _size := PackedFloat32Array()
var _head := 0
var _alive := 0
var _buf := PackedFloat32Array()

func setup(cap: int, life_: float, shrink_: bool, mat: Material) -> void:
	capacity = cap
	life = life_
	shrink = shrink_
	_pos.resize(cap)
	_col.resize(cap)
	_age.resize(cap)
	_age.fill(999.0)
	_size.resize(cap)
	_buf.resize(cap * 16)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var qm := QuadMesh.new()
	qm.size = Vector2(1, 1)
	qm.material = mat
	mm.mesh = qm
	mm.instance_count = cap
	mm.visible_instance_count = 0
	multimesh = mm
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	custom_aabb = AABB(Vector3(-3, -2, -3), Vector3(24, 8, 18))
	process_mode = Node.PROCESS_MODE_PAUSABLE

func emit(p: Vector3, color: Color, size: float) -> void:
	_pos[_head] = p
	_col[_head] = color
	_age[_head] = 0.0
	_size[_head] = size
	_head = (_head + 1) % capacity
	_alive = mini(capacity, _alive + 1)

func _process(delta: float) -> void:
	if _alive == 0:
		if multimesh.visible_instance_count != 0:
			multimesh.visible_instance_count = 0
		return
	var n := 0
	var still := 0
	# Ausrichtung zur Kamera (die Kamera dreht sich praktisch nicht, daher eine Basis für alle)
	var cam := get_viewport().get_camera_3d()
	var bx := Vector3.RIGHT
	var by := Vector3.UP
	if cam != null:
		bx = cam.global_basis.x
		by = cam.global_basis.y
	var bz := bx.cross(by)
	for i in capacity:
		var a := _age[i]
		if a >= life:
			continue
		a += delta
		_age[i] = a
		if a >= life:
			continue
		still += 1
		var t := a / life
		var s := _size[i] * ((1.0 - t) if shrink else (0.6 + 0.4 * (1.0 - t)))
		var p := _pos[i]
		var c := _col[i]
		var k := n * 16
		_buf[k] = bx.x * s
		_buf[k + 1] = by.x * s
		_buf[k + 2] = bz.x * s
		_buf[k + 3] = p.x
		_buf[k + 4] = bx.y * s
		_buf[k + 5] = by.y * s
		_buf[k + 6] = bz.y * s
		_buf[k + 7] = p.y
		_buf[k + 8] = bx.z * s
		_buf[k + 9] = by.z * s
		_buf[k + 10] = bz.z * s
		_buf[k + 11] = p.z
		_buf[k + 12] = c.r
		_buf[k + 13] = c.g
		_buf[k + 14] = c.b
		_buf[k + 15] = c.a * (1.0 - t)
		n += 1
	_alive = still
	multimesh.visible_instance_count = n
	if n > 0:
		RenderingServer.multimesh_set_buffer(multimesh.get_rid(), _buf)
