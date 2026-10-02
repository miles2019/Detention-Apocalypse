class_name Locker
extends Node2D
## Spind: Mr. Scrubbs kann sich bis zu 3 Sekunden verstecken (Gegner verlieren das Ziel).
## Zustände: verfügbar -> aktiviert (belegt) -> Cooldown -> wieder verfügbar.

enum S { AVAILABLE, OCCUPIED, COOLDOWN }
const MAX_HIDE := 3.0
const COOLDOWN := 8.0

var state := S.AVAILABLE
var timer := 0.0
var wobble := 0.0
var _pivot: Node3D
var _body_mat: StandardMaterial3D
var _t := randf() * 10.0

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("reactive")
	add_to_group("overlay")
	# Versteck-Spind: 3D-Platzhalterbox (Spind-Monster mit Armen sind Gegner, siehe Db "locker")
	var stage: Stage3D = Game.arena.stage
	_pivot = Node3D.new()
	stage.props.add_child(_pivot)
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, 1.05, 0.5)
	var body := stage.make_mesh_node(bm, Color(0.42, 0.55, 0.7))
	_body_mat = body.material_override
	body.get_parent().remove_child(body)
	_pivot.add_child(body)
	body.position.y = 0.525
	for i in 3:
		var vm := BoxMesh.new()
		vm.size = Vector3(0.36, 0.025, 0.02)
		var v := stage.make_mesh_node(vm, Color(0.12, 0.15, 0.2))
		v.get_parent().remove_child(v)
		_pivot.add_child(v)
		v.position = Vector3(0, 0.85 - i * 0.06, 0.255)
	var hm := BoxMesh.new()
	hm.size = Vector3(0.04, 0.16, 0.04)
	var h := stage.make_mesh_node(hm, Color(0.85, 0.85, 0.9))
	h.get_parent().remove_child(h)
	_pivot.add_child(h)
	h.position = Vector3(0.2, 0.55, 0.27)
	var dm := BoxMesh.new()
	dm.size = Vector3(0.015, 0.95, 0.02)
	var d := stage.make_mesh_node(dm, Color(0.15, 0.2, 0.28))
	d.get_parent().remove_child(d)
	_pivot.add_child(d)
	d.position = Vector3(0.0, 0.52, 0.255)

func _exit_tree() -> void:
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.queue_free()

func interact(player: Node) -> void:
	if state == S.AVAILABLE and not player.is_hiding:
		_enter(player)
	elif state == S.OCCUPIED and player.is_hiding:
		leave()

func _enter(player: Node) -> void:
	state = S.OCCUPIED
	timer = MAX_HIDE
	player.is_hiding = true
	player.current_locker = self
	player.global_position = global_position + Vector2(0, 6)
	Game.stats.hides += 1
	Game.stats.objects_used += 1
	wobble = 1.0
	Sfx.play("locker")
	Juice.float_text(global_position + Vector2(0, -110), "Versteckt!", Color(0.7, 0.9, 1), 16)

func leave() -> void:
	var pl = Game.player
	if state != S.OCCUPIED or pl == null:
		return
	state = S.COOLDOWN
	timer = COOLDOWN
	pl.is_hiding = false
	pl.current_locker = null
	pl.global_position = global_position + Vector2(0, 34)
	pl.ambush_t = 1.5
	pl.iframes = maxf(pl.iframes, 0.3)
	wobble = 1.2
	Sfx.play("locker", 1.3)
	Juice.ring(global_position + Vector2(0, 10), 60.0, Color(1, 0.9, 0.5), 0.3, 4.0)
	Juice.float_text(pl.global_position + Vector2(0, -90), "Überraschungsangriff!", Color(1, 0.85, 0.3), 18, true)
	pl.rig.squash(0.8, 1.3)

func react(pos: Vector2, strength: float) -> void:
	var d := pos.distance_to(global_position)
	if d < 520.0:
		wobble = maxf(wobble, strength * (1.0 - d / 520.0) * 1.2)
		if wobble > 0.4 and randf() < 0.5:
			Sfx.play("locker", 1.8, -16.0)

func _process(delta: float) -> void:
	_t += delta
	wobble = maxf(0.0, wobble - delta * 2.0)
	if state == S.OCCUPIED:
		timer -= delta
		wobble = maxf(wobble, 0.25)
		if timer <= 0.0:
			leave()
	elif state == S.COOLDOWN:
		timer -= delta
		if timer <= 0.0:
			state = S.AVAILABLE
			wobble = 0.8
			Sfx.play("click", 1.2, -6.0)
	_pivot.position = Game.arena.stage.to3(global_position)
	_pivot.basis = Basis(Vector3.FORWARD, sin(_t * 50.0) * 0.05 * wobble)
	_body_mat.albedo_color = Color(0.28, 0.33, 0.4) if state == S.COOLDOWN else Color(0.42, 0.55, 0.7)
	queue_redraw()

func _draw() -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a) * 34.0, sin(a) * 10.0 + 2.0))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.3))

## Bildschirmebene: Augen im Schlitz, Restzeit, Cooldown-Ring, Tasten-Hinweis
func draw_overlay(c: Control, sp: Vector2) -> void:
	var pl = Game.player
	var k := 1.1
	var f := ThemeDB.fallback_font
	if state == S.OCCUPIED:
		for ex in [-6.0, 6.0]:
			c.draw_circle(sp + Vector2(ex, -62) * k, 4.0, Color.WHITE)
			c.draw_circle(sp + Vector2(ex + 1, -62) * k, 1.8, Color.BLACK)
		var fr := clampf(timer / MAX_HIDE, 0.0, 1.0)
		c.draw_rect(Rect2(sp.x - 26, sp.y - 122, 52, 9), Color(0, 0, 0, 0.7))
		c.draw_rect(Rect2(sp.x - 25, sp.y - 121, 50 * fr, 7), Color(0.5, 0.9, 1.0))
	elif state == S.COOLDOWN:
		var f2 := 1.0 - clampf(timer / COOLDOWN, 0.0, 1.0)
		c.draw_arc(sp + Vector2(0, -60), 14.0, -PI / 2.0, -PI / 2.0 + TAU * f2, 20, Color(1, 1, 1, 0.8), 4.0)
		c.draw_string(f, sp + Vector2(-9, -84), "zZ", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.85, 1.0))
	elif pl != null and not pl.is_hiding and pl.global_position.distance_to(global_position) < 90.0:
		var cc := sp + Vector2(0, -122 + sin(_t * 6.0) * 3.0)
		c.draw_circle(cc, 13.0, Color(0.1, 0.1, 0.15, 0.85))
		c.draw_arc(cc, 13.0, 0, TAU, 20, Color.WHITE, 2.0)
		c.draw_string(f, cc + Vector2(-5, 6), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color.WHITE)
