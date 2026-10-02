class_name BatchSprite
extends RefCounted
## Leichtgewichtiges Handle für ein gebatchtes Billboard. API wie Billboard3D (place/set_body/set_tint/set_flash/set_tex).

var batch: SpriteBatch
var region := 0
var aspect := 1.0
var height_px := 50.0
var pos := Vector3.ZERO
var lift := 0.0
var scale2 := Vector2.ONE
var rot := 0.0
var tint := Color.WHITE
var flash := 0.0
var visible := true
var shadow := true
var alive := true

func set_tex(tex: Texture2D, height: float = -1.0) -> void:
	var key := SpriteBatch.region_key(tex)
	if not SpriteBatch._regions.has(key):
		return
	var r: Dictionary = SpriteBatch._regions[key]
	region = r.idx
	aspect = r.aspect
	if height > 0.0:
		height_px = height

func place(p2: Vector2, lift_px: float = 0.0) -> void:
	pos = Vector3(p2.x * Stage3D.S, lift_px * Stage3D.S, p2.y * Stage3D.S)
	lift = lift_px

func set_body(s: Vector2, r: float) -> void:
	scale2 = s
	rot = r

func set_tint(c: Color) -> void:
	tint = c

func set_flash(v: float, _color: Color = Color.WHITE) -> void:
	flash = v

func set_stunned(_on: bool) -> void:
	pass       # Betäubungs-Sterne zeichnet der Gegner in der Overlay-Ebene

func queue_free() -> void:
	if alive and batch != null:
		batch.remove(self)
