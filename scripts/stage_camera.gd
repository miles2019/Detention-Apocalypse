class_name StageCamera
extends Camera3D
## Schräg von oben blickende Folgekamera (feste Neigung), mit Shake/Zoom-Pop aus dem Juice-Service.
## API-kompatibel zur früheren 2D-Kamera: target, focus, base_zoom, snap().

const BASE_DIST := 8.8

var target: Node2D
var focus = null
var base_zoom := 1.0
var roll := 0.0
var clamp_min := Vector2(520.0, 330.0)
var clamp_max := Vector2(1080.0, 700.0)
var _pos := Vector2(800, 600)
var _lead := Vector2.ZERO

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	fov = 36.0
	near = 0.3
	far = 80.0
	rotation = Vector3(-Stage3D.CAM_ELEV, 0.0, 0.0)

func snap() -> void:
	if target != null:
		_pos = _clamped(target.global_position)
		_apply(0.0)

func _clamped(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, clamp_min.x, clamp_max.x), clampf(p.y, clamp_min.y, clamp_max.y))

func _apply(_delta: float) -> void:
	var dist := BASE_DIST / maxf(0.3, base_zoom + Juice.shaker.zoom_kick)
	var p3 := Vector3(_pos.x * Stage3D.S, 0.0, _pos.y * Stage3D.S)
	position = p3 + Vector3(0.0, sin(Stage3D.CAM_ELEV), cos(Stage3D.CAM_ELEV)) * dist
	rotation = Vector3(-Stage3D.CAM_ELEV, 0.0, roll)
	var off := Juice.shaker.offset * Stage3D.S
	h_offset = off.x
	v_offset = off.y

func _process(delta: float) -> void:
	var goal: Vector2
	if focus != null:
		goal = focus
	elif target != null:
		var aim: Vector2 = Game.player.aim_dir if Game.player != null else Vector2.ZERO
		_lead = _lead.lerp(aim * 40.0, 1.0 - exp(-3.0 * delta))
		goal = _clamped(target.global_position + _lead)
	else:
		return
	_pos = _pos.lerp(goal, 1.0 - exp(-8.0 * delta))
	_apply(delta)
