class_name VisualRig
extends Node2D
## Wiederverwendbare Figuren-Hülle: 2D-Logik (Squash/Stretch, Hüpfhöhe, Blitz) + 3D-Darstellung als
## aufrechtes Sprite3D (Billboard3D) in der Stage3D. Der Schatten/Aura-Ring wird flach auf den Boden gezeichnet.

var body: Node2D
var sprite: Sprite2D
var shadow: Node2D
var shadow_w := 40.0
var aura_color := Color(0, 0, 0, 0)
var bb      # Billboard3D (Spieler, Sonderfälle) oder BatchSprite (Gegner, Drops)
var stunned := false : set = _set_stunned
var hop := 0.0 : set = _set_hop
var base_height := 50.0
var _tw: Tween
var _flash_tw: Tween
var _aura_t := 0.0
var size_mul := 1.0
var _flash_val := 0.0
var _flash_col := Color.WHITE
var _last_tint := Color(-1, 0, 0, 0)
var _last_flash := -1.0
var _last_vis := true

func setup(tex: Texture2D, height: float, shadow_width: float, batched: bool = false) -> void:
	base_height = height
	shadow_w = shadow_width
	shadow = Node2D.new()
	shadow.draw.connect(_draw_shadow)
	add_child(shadow)
	body = Node2D.new()
	add_child(body)
	sprite = Sprite2D.new()      # nur Platzhalter für Größe/Textur-Logik, wird nicht gezeichnet
	sprite.visible = false
	body.add_child(sprite)
	sprite.texture = tex
	var stage: Stage3D = Game.arena.stage if Game.arena != null else null
	if stage != null:
		if batched:
			bb = stage.batch.add(tex, height, true)
		if bb == null:
			bb = Billboard3D.new()
			stage.sprites.add_child(bb)
			bb.setup(tex, height)
	set_process(true)

func set_texture(tex: Texture2D) -> void:
	sprite.texture = tex
	if bb:
		bb.set_tex(tex)

func _draw_shadow() -> void:
	var pts := PackedVector2Array()
	var k := 1.0 - clampf(hop / 60.0, 0.0, 0.5)
	for i in 20:
		var a := TAU * i / 20.0
		pts.append(Vector2(cos(a) * shadow_w * 0.5, sin(a) * shadow_w * 0.2 + 2.0) * k)
	shadow.draw_colored_polygon(pts, Color(0, 0, 0, 0.13))
	if aura_color.a > 0.0:
		var pulse := 0.5 + 0.5 * sin(_aura_t * 5.0)
		var c := aura_color
		c.a = 0.4 + pulse * 0.4
		var rr := shadow_w * 0.7 + pulse * 3.0
		var ring := PackedVector2Array()
		for i in 33:
			var a2 := TAU * i / 32.0
			ring.append(Vector2(cos(a2) * rr, sin(a2) * rr * 0.4 + 2.0))
		shadow.draw_polyline(ring, c, 3.0)
		# Elite-Aura zusätzlich als Zacken (Form statt nur Farbe)
		for i in 4:
			var a3 := TAU * i / 4.0 + _aura_t
			var d := Vector2(cos(a3), sin(a3) * 0.4)
			shadow.draw_line(d * rr, d * (rr + 9.0), c, 3.0)

func _process(delta: float) -> void:
	if aura_color.a > 0.0:
		_aura_t += delta
		shadow.queue_redraw()
	if bb != null:
		var flip := scale.x
		var vis := is_visible_in_tree()
		if vis != _last_vis:
			_last_vis = vis
			bb.visible = vis
		bb.place(global_position, hop)
		bb.set_body(Vector2(body.scale.x * flip, body.scale.y) * size_mul, body.rotation * flip)
		var tc := Color(sprite.modulate.r, sprite.modulate.g, sprite.modulate.b, modulate.a)
		if tc != _last_tint:
			_last_tint = tc
			bb.set_tint(tc)
		if _flash_val != _last_flash:
			_last_flash = _flash_val
			bb.set_flash(_flash_val, _flash_col)

func _exit_tree() -> void:
	if bb != null and is_instance_valid(bb):
		bb.queue_free()

func _set_stunned(v: bool) -> void:
	if v == stunned:
		return
	stunned = v
	if bb:
		bb.set_stunned(v)

func _set_hop(v: float) -> void:
	hop = v
	if body:
		body.position.y = -v

func flash(duration: float = 0.12, color: Color = Color.WHITE) -> void:
	_flash_col = color
	if _flash_tw:
		_flash_tw.kill()
	_flash_val = 1.0
	_flash_tw = create_tween()
	_flash_tw.tween_property(self, "_flash_val", 0.0, duration)

func set_tint(c: Color) -> void:
	sprite.modulate = c

## Status-Shader am Sprite (nur gebatchte Figuren): 0 = keiner, 1 = brennt, 2 = nass, 3 = gefroren
func set_fx(code: int) -> void:
	if bb is BatchSprite:
		bb.fx = float(code)

## Kurzer Squash/Stretch-Impuls (Skalierung relativ zu 1), federt elastisch zurück
func squash(sx: float, sy: float, time: float = 0.28) -> void:
	if _tw:
		_tw.kill()
	body.scale = Vector2(sx, sy)
	_tw = create_tween()
	_tw.tween_property(body, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func pop_in(time: float = 0.35) -> void:
	if _tw:
		_tw.kill()
	body.scale = Vector2(0.1, 0.1)
	_tw = create_tween()
	_tw.tween_property(body, "scale", Vector2.ONE, time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func lean(rot: float, k: float = 12.0, delta: float = 0.016) -> void:
	body.rotation = lerpf(body.rotation, rot, 1.0 - exp(-k * delta))
