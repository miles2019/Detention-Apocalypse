class_name Chalkboard
extends Node2D
## Tafel: wird von Spieler-Projektilen getroffen, dreht sich um und reflektiert als Streufeuer.
## Zustände: verfügbar -> aktiviert (dreht sich) -> Cooldown -> verfügbar. Placeholder: 3D-Boxen.

enum S { AVAILABLE, ACTIVE, COOLDOWN }

var state := S.AVAILABLE
var facing := 1.0          # 1 = Vorderseite zeigt nach rechts (+x)
var timer := 0.0
var _wob := 0.0
var _text := "2+2=?"
var _pivot: Node3D
var _label: Label3D
var _face_mat: StandardMaterial3D
var _t := 0.0
const SIZE := Vector2(26, 120)

func _ready() -> void:
	add_to_group("reactive")
	add_to_group("overlay")
	var stage: Stage3D = Game.arena.stage
	_pivot = Node3D.new()
	stage.props.add_child(_pivot)
	var frame := BoxMesh.new()
	frame.size = Vector3(0.08, 1.0, 1.25)
	var fm := _mesh(stage, frame, Color(0.55, 0.35, 0.18))
	fm.position.y = 0.62
	var face := BoxMesh.new()
	face.size = Vector3(0.02, 0.86, 1.1)
	var fc := _mesh(stage, face, Color(0.12, 0.3, 0.23))
	fc.position = Vector3(0.05 * facing, 0.62, 0.0)
	_face_mat = fc.material_override
	for sz in [-0.5, 0.5]:
		var leg := BoxMesh.new()
		leg.size = Vector3(0.06, 0.2, 0.06)
		var lm := _mesh(stage, leg, Color(0.3, 0.2, 0.1))
		lm.position = Vector3(0.0, 0.1, sz)
	_label = Label3D.new()
	_label.text = _text
	_label.font_size = 64
	_label.pixel_size = 0.0045
	_label.modulate = Color(0.95, 0.95, 0.88)
	_label.shaded = false
	_label.position = Vector3(0.07 * facing, 0.62, 0.0)
	_label.rotation_degrees.y = 90.0 * facing
	_pivot.add_child(_label)

func _mesh(stage: Stage3D, mesh: Mesh, color: Color) -> MeshInstance3D:
	var mi := stage.make_mesh_node(mesh, color)
	mi.get_parent().remove_child(mi)
	_pivot.add_child(mi)
	return mi

func _exit_tree() -> void:
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.queue_free()

func react(pos: Vector2, strength: float) -> void:
	if pos.distance_to(global_position) < 500.0:
		_wob = maxf(_wob, strength * 0.7)

func try_hit(proj: Node) -> bool:
	if state != S.AVAILABLE:
		return false
	var local = proj.global_position - (global_position + Vector2(0, -SIZE.y * 0.5))
	if absf(local.x) > SIZE.x * 0.5 + proj.radius or absf(local.y) > SIZE.y * 0.5 + proj.radius:
		return false
	var n := Vector2(facing, 0.0)
	if proj.vel.dot(n) >= 0.0:
		return false      # trifft die Rückseite: ignorieren
	state = S.ACTIVE
	timer = 0.4
	Game.stats.objects_used += 1
	var rv: Vector2 = proj.vel - 2.0 * proj.vel.dot(n) * n
	for off in [-0.38, 0.0, 0.38]:
		Projectile.create(Game.arena.fx_layer, global_position + Vector2(facing * 22.0, -SIZE.y * 0.5), rv.rotated(off), {
			team = "player", kind = proj.kind, damage = proj.damage * 0.8, radius = proj.radius, life = 1.4,
			knockback = proj.knockback, color = proj.color, tex = proj.tex, tex_scale = proj.tex_scale,
			weapon_id = proj.weapon_id, spin = proj.spin,
		})
	Sfx.play("locker", 1.5, -8.0)
	Sfx.play("click", 0.8)
	Juice.shake(0.2, rv)
	_text = "2+2=5"
	_label.text = _text
	_wob = 1.0
	Juice.float_text(global_position + Vector2(0, -SIZE.y - 18), "Streufeuer!", Color(0.7, 1, 0.7), 16, true)
	proj._expire(true)
	return true

func _process(delta: float) -> void:
	_t += delta
	_wob = maxf(0.0, _wob - delta * 2.0)
	var yaw := 0.0
	match state:
		S.ACTIVE:
			timer -= delta
			yaw = (1.0 - timer / 0.4) * TAU
			if timer <= 0.0:
				state = S.COOLDOWN
				timer = 3.0
		S.COOLDOWN:
			timer -= delta
			if timer <= 0.0:
				state = S.AVAILABLE
				_text = "2+2=?"
				_label.text = _text
	var stage: Stage3D = Game.arena.stage
	_pivot.position = stage.to3(global_position + Vector2(0, -SIZE.y * 0.5), 0.0)
	_pivot.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, sin(_t * 50.0) * 0.04 * _wob)
	_face_mat.albedo_color = Color(0.06, 0.15, 0.12) if state == S.COOLDOWN else Color(0.12, 0.3, 0.23)
	queue_redraw()

func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * 12.0, sin(a) * 40.0 - SIZE.y * 0.5))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.22))

func draw_overlay(c: Control, sp: Vector2) -> void:
	if state == S.COOLDOWN:
		c.draw_arc(sp + Vector2(0, -SIZE.y * 0.5 * 0.0 - 110), 8.0, -PI / 2, -PI / 2 + TAU * (1.0 - timer / 3.0), 16, Color(1, 1, 1, 0.8), 3.0)
