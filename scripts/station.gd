class_name Station
extends Node2D
## Interaktionsstation im Schulhof-Hub (3D-Platzhalterprop + Label3D). E drücken öffnet das zugehörige Menü.
## kind: skills (Alte Tafel) | workbench | board | ag | director | photo

var kind := "skills"
var title := ""
var hint := ""
var accent := Color.WHITE
var badge := false
var _pivot: Node3D
var _label: Label3D
var _icon: Billboard3D
var _t := randf() * 6.0
var _near := false
var _badge_t := 0.0

const ICONS := {
	skills = "res://assets/icons/i_03.png", workbench = "res://assets/weapons/w_44.png", board = "res://assets/icons/i_01.png",
	ag = "res://assets/icons/i_20.png", director = "res://assets/icons/i_04.png", photo = "res://assets/icons/i_27.png",
}

func _ready() -> void:
	add_to_group("interactable")
	add_to_group("overlay")
	var stage: Stage3D = Game.arena.stage
	_pivot = Node3D.new()
	stage.props.add_child(_pivot)
	match kind:
		"skills": _build_chalkboard(stage)
		"workbench": _build_workbench(stage)
		"board": _build_board(stage)
		"ag": _build_cabinet(stage)
		"director": _build_sign(stage)
		"photo": _build_lockers(stage)
	_label = Label3D.new()
	_label.text = title
	_label.font_size = 46
	_label.pixel_size = 0.0036
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.shaded = false
	_label.modulate = Color(1, 0.96, 0.8)
	_label.outline_size = 14
	_label.outline_modulate = Color(0.1, 0.07, 0.05)
	_label.position = Vector3(0, 1.9, 0)
	_pivot.add_child(_label)
	_icon = Billboard3D.new()
	stage.sprites.add_child(_icon)
	_icon.setup(Db.tex(ICONS[kind]), 34.0, false)
	_icon.sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pivot.position = stage.to3(global_position)

func _exit_tree() -> void:
	if _pivot != null and is_instance_valid(_pivot):
		_pivot.queue_free()
	if _icon != null and is_instance_valid(_icon):
		_icon.queue_free()

func _box(stage: Stage3D, size: Vector3, pos: Vector3, color: Color) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var mi := stage.make_mesh_node(bm, color)
	mi.get_parent().remove_child(mi)
	_pivot.add_child(mi)
	mi.position = pos

func _build_chalkboard(stage: Stage3D) -> void:
	_box(stage, Vector3(1.5, 1.0, 0.08), Vector3(0, 0.95, 0), Color(0.45, 0.3, 0.15))
	_box(stage, Vector3(1.38, 0.88, 0.09), Vector3(0, 0.95, 0.01), Color(0.1, 0.26, 0.2))
	for sx in [-0.6, 0.6]:
		_box(stage, Vector3(0.07, 0.5, 0.07), Vector3(sx, 0.25, 0), Color(0.3, 0.2, 0.1))
	# gekritzelter Baum auf der Tafel
	for i in 5:
		_box(stage, Vector3(0.3, 0.02, 0.01), Vector3(-0.3 + (i % 3) * 0.3, 1.2 - (i / 3) * 0.28, 0.06), Color(0.9, 0.9, 0.85))

func _build_workbench(stage: Stage3D) -> void:
	_box(stage, Vector3(1.6, 0.1, 0.8), Vector3(0, 0.6, 0), Color(0.6, 0.4, 0.2))
	for sx in [-0.7, 0.7]:
		for sz in [-0.3, 0.3]:
			_box(stage, Vector3(0.1, 0.6, 0.1), Vector3(sx, 0.3, sz), Color(0.35, 0.22, 0.12))
	_box(stage, Vector3(0.4, 0.16, 0.3), Vector3(-0.4, 0.72, 0), Color(0.85, 0.2, 0.2))
	_box(stage, Vector3(0.5, 0.04, 0.2), Vector3(0.3, 0.67, 0.1), Color(0.7, 0.7, 0.75))

func _build_board(stage: Stage3D) -> void:
	_box(stage, Vector3(1.5, 1.0, 0.08), Vector3(0, 0.95, 0), Color(0.45, 0.3, 0.15))
	_box(stage, Vector3(1.38, 0.88, 0.09), Vector3(0, 0.95, 0.01), Color(0.78, 0.6, 0.35))
	for i in 5:
		_box(stage, Vector3(0.28, 0.34, 0.01), Vector3(-0.5 + i * 0.25, 0.95 + (i % 2) * 0.18 - 0.08, 0.07), Color(0.95, 0.95, 0.9) if i % 2 == 0 else Color(1.0, 0.95, 0.5))
	for sx in [-0.6, 0.6]:
		_box(stage, Vector3(0.07, 0.45, 0.07), Vector3(sx, 0.22, 0), Color(0.3, 0.2, 0.1))

func _build_cabinet(stage: Stage3D) -> void:
	_box(stage, Vector3(1.2, 1.3, 0.5), Vector3(0, 0.65, 0), Color(0.4, 0.3, 0.25))
	_box(stage, Vector3(1.05, 1.15, 0.08), Vector3(0, 0.7, 0.22), Color(0.7, 0.9, 0.95))
	_box(stage, Vector3(1.1, 0.12, 0.52), Vector3(0, 1.36, 0), Color(0.55, 0.38, 0.25))

func _build_sign(stage: Stage3D) -> void:
	_box(stage, Vector3(0.12, 1.5, 0.12), Vector3(0, 0.75, 0), Color(0.35, 0.22, 0.12))
	_box(stage, Vector3(1.3, 0.45, 0.08), Vector3(0, 1.35, 0.05), Color(0.75, 0.15, 0.15))
	_box(stage, Vector3(1.2, 0.35, 0.09), Vector3(0, 1.35, 0.06), Color(0.95, 0.85, 0.5))
	_box(stage, Vector3(0.5, 0.2, 0.1), Vector3(0.45, 0.95, 0.05), Color(0.2, 0.5, 0.8))

func _build_lockers(stage: Stage3D) -> void:
	for i in 3:
		_box(stage, Vector3(0.45, 1.1, 0.4), Vector3(-0.5 + i * 0.5, 0.55, 0), Color(0.2, 0.55, 0.55))
		_box(stage, Vector3(0.3, 0.02, 0.02), Vector3(-0.5 + i * 0.5, 0.95, 0.21), Color(0.05, 0.12, 0.14))
		_box(stage, Vector3(0.03, 0.12, 0.03), Vector3(-0.38 + i * 0.5, 0.6, 0.21), Color(0.85, 0.85, 0.9))

func interact(_player: Node) -> void:
	Sfx.play("stamp", 1.1, -6.0)
	Juice.ring(global_position, 90.0, accent, 0.4, 6.0, true)
	Juice.zoom_pop(0.03)
	Game.station_activated.emit(kind)

func _process(delta: float) -> void:
	_t += delta
	_badge_t -= delta
	var pl = Game.player
	_near = pl != null and pl.global_position.distance_to(global_position) < 120.0
	if _badge_t <= 0.0:
		_badge_t = 1.0
		badge = HubInfo.station_badge(kind)
	var bob := 8.0 + sin(_t * 2.5) * 4.0
	_icon.place(global_position, 150.0 + bob)
	_icon.set_body(Vector2.ONE * (1.15 if _near else 1.0), sin(_t * 1.5) * 0.08)
	_label.scale = Vector3.ONE * (1.15 if _near else 1.0)
	queue_redraw()

func _draw() -> void:
	# Bodenmarkierung (flach) – pulsiert, wenn Spieler nah ist
	var pts := PackedVector2Array()
	var r := 70.0 + (sin(_t * 4.0) * 4.0 if _near else 0.0)
	for i in 28:
		var a := TAU * i / 28.0
		pts.append(Vector2(cos(a) * r, sin(a) * r * 0.7 + 4.0))
	var c := accent
	c.a = 0.35 if _near else 0.18
	draw_colored_polygon(pts, c)
	pts.append(pts[0])
	draw_polyline(pts, Color(accent.r, accent.g, accent.b, 0.8 if _near else 0.4), 3.0)

func draw_overlay(c: Control, sp: Vector2) -> void:
	var f := ThemeDB.fallback_font
	if badge:
		var bp := sp + Vector2(0, -190 + sin(_t * 5.0) * 4.0)
		c.draw_circle(bp, 13.0, Color(0.9, 0.15, 0.15))
		c.draw_arc(bp, 13.0, 0, TAU, 16, Color.WHITE, 2.0)
		c.draw_string(f, bp + Vector2(-3.5, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
	if _near:
		var pr := Rect2(sp.x - 150, sp.y + 14, 300, 54)
		c.draw_style_box(UIKit.box(Color(0.1, 0.1, 0.16, 0.92), accent, 3, 10, 4), pr)
		c.draw_string(f, pr.position + Vector2(14, 24), "[E]  " + title, HORIZONTAL_ALIGNMENT_LEFT, 280, 16, Color.WHITE)
		c.draw_string(f, pr.position + Vector2(14, 44), hint, HORIZONTAL_ALIGNMENT_LEFT, 280, 11, Color(0.8, 0.85, 0.95))
