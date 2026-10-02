class_name WallArt
extends Node2D
## Gemalte Wandtextur (wird einmal in einen SubViewport gerendert): Sockel, Fenster mit Brettern und
## Monster-Silhouetten, Türen, Spinde, Pinnwand, Spinnweben, Risse, Schleim-Tropfen.
## kind: "back" (1600x210 px Weltmaß) oder "side" (825x150).

var kind := "back"
var size := Vector2(1600, 210)

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if kind == "back" else 11
	var w := size.x
	var h := size.y
	draw_rect(Rect2(0, 0, w, h), Color(0.87, 0.84, 0.64))
	# Schmutz-Verläufe
	for i in 24:
		draw_rect(Rect2(rng.randf_range(0, w), rng.randf_range(0, h * 0.7), rng.randf_range(30, 120), rng.randf_range(10, 40)), Color(0.7, 0.66, 0.46, 0.18))
	# Zierleiste oben + Sockel unten
	draw_rect(Rect2(0, 0, w, 16), Color(0.28, 0.5, 0.52))
	draw_rect(Rect2(0, 16, w, 5), Color(0.2, 0.36, 0.4))
	draw_rect(Rect2(0, h * 0.72, w, h * 0.28), Color(0.3, 0.46, 0.46))
	draw_rect(Rect2(0, h * 0.72, w, 5), Color(0.55, 0.7, 0.66))
	if kind == "back":
		_back(rng)
	else:
		_side(rng)
	# Schleim-Tropfen von oben
	for i in (7 if kind == "back" else 4):
		var x := rng.randf_range(20, w - 20)
		var l := rng.randf_range(30, 80)
		var pts := PackedVector2Array([Vector2(x - 10, 20), Vector2(x + 12, 20), Vector2(x + 6, 20 + l * 0.6), Vector2(x + 2, 20 + l), Vector2(x - 4, 20 + l * 0.7)])
		draw_colored_polygon(pts, Color(0.28, 0.2, 0.14, 0.85))
	# Risse
	for i in (4 if kind == "back" else 2):
		var c := Vector2(rng.randf_range(100, w - 100), rng.randf_range(40, h * 0.5))
		var pts2 := PackedVector2Array([c])
		var cur := c
		for k in 6:
			cur += Vector2(rng.randf_range(-22, 22), rng.randf_range(-14, 18))
			pts2.append(cur)
		draw_polyline(pts2, Color(0.12, 0.1, 0.1), 3.0)
	# Spinnweben in den Ecken
	_web(Vector2(w - 8, 18), -1.0)
	_web(Vector2(8, 18), 1.0)

func _web(corner: Vector2, dir: float) -> void:
	var c := Color(0.95, 0.95, 0.95, 0.85)
	for i in 5:
		var a := dir * (PI / 2.0) * i / 4.0
		var p := corner + Vector2(cos(a) * dir * 50.0, sin(a) * 50.0) if dir > 0 else corner + Vector2(-cos(a) * 50.0, sin(a) * 50.0)
		draw_line(corner, p, c, 1.5)
	for r in [14.0, 28.0, 42.0]:
		var pts := PackedVector2Array()
		for i in 5:
			var a2 := (PI / 2.0) * i / 4.0
			pts.append(corner + Vector2(dir * cos(a2) * r, sin(a2) * r))
		draw_polyline(pts, c, 1.2)

func _back(rng: RandomNumberGenerator) -> void:
	# Säulen
	for px in [380.0, 800.0, 1190.0]:
		draw_rect(Rect2(px - 14, 0, 28, size.y), Color(0.82, 0.78, 0.58))
		draw_rect(Rect2(px - 14, 0, 28, size.y), Color(0.45, 0.42, 0.3), false, 2.0)
		draw_rect(Rect2(px - 14, 18, 28, 8), Color(0.28, 0.5, 0.52))
	# Fenster mit Brettern und Monster-Silhouetten
	var wx := [90.0, 420.0, 840.0, 1230.0]
	for i in wx.size():
		var x: float = wx[i]
		var ww := 300.0 if i != 1 else 330.0
		draw_rect(Rect2(x - 6, 44, ww + 12, 96), Color(0.62, 0.45, 0.38))
		draw_rect(Rect2(x, 50, ww, 84), Color(0.1, 0.12, 0.15))
		draw_rect(Rect2(x + ww * 0.5 - 3, 50, 6, 84), Color(0.62, 0.45, 0.38))
		if i % 2 == 1:
			# Monster-Silhouette hinter Glas
			var mx := x + ww * 0.3
			draw_circle(Vector2(mx, 100), 22, Color(0.04, 0.12, 0.12))
			draw_circle(Vector2(mx + 40, 90), 16, Color(0.04, 0.12, 0.12))
			for k in 4:
				draw_line(Vector2(mx - 10 + k * 9, 120), Vector2(mx - 16 + k * 9, 140), Color(0.04, 0.12, 0.12), 3.0)
			draw_circle(Vector2(mx - 6, 96), 3, Color(0.7, 1, 0.5))
		if i % 2 == 0:
			# vernagelt
			var pts := PackedVector2Array([Vector2(x - 10, 70), Vector2(x + ww + 10, 56), Vector2(x + ww + 10, 76), Vector2(x - 10, 90)])
			draw_colored_polygon(pts, Color(0.55, 0.38, 0.2))
			draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.25, 0.15, 0.08), 2.0)
			var pts2 := PackedVector2Array([Vector2(x - 10, 108), Vector2(x + ww + 10, 96), Vector2(x + ww + 10, 114), Vector2(x - 10, 126)])
			draw_colored_polygon(pts2, Color(0.5, 0.34, 0.18))
			draw_polyline(PackedVector2Array([pts2[0], pts2[1], pts2[2], pts2[3], pts2[0]]), Color(0.25, 0.15, 0.08), 2.0)
	# Wandtafel mit Schriftzug
	draw_rect(Rect2(560, 44, 240, 92), Color(0.5, 0.34, 0.17))
	draw_rect(Rect2(566, 50, 228, 80), Color(0.12, 0.28, 0.22))
	draw_string(ThemeDB.fallback_font, Vector2(574, 82), "NACHSITZEN: 100x", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.93, 0.93, 0.85, 0.9))
	draw_string(ThemeDB.fallback_font, Vector2(574, 108), "\"Ich wische nicht\"", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.93, 0.93, 0.85, 0.8))
	# Pinnwand
	draw_rect(Rect2(1480, 50, 80, 70), Color(0.55, 0.38, 0.2))
	draw_rect(Rect2(1485, 55, 70, 60), Color(0.78, 0.6, 0.35))
	draw_rect(Rect2(1492, 62, 26, 32), Color(0.95, 0.95, 0.9))
	draw_rect(Rect2(1524, 66, 26, 28), Color(0.95, 0.9, 0.4))
	# Tür
	draw_rect(Rect2(20, 50, 56, 112), Color(0.6, 0.32, 0.2))
	draw_rect(Rect2(28, 58, 40, 50), Color(0.5, 0.75, 0.8))
	draw_line(Vector2(28, 58), Vector2(68, 108), Color(1, 1, 1, 0.5), 2.0)
	# Spinde (flach gemalt, links an der Wand)
	for i in 3:
		var lx := 1380.0 + i * 54.0
		draw_rect(Rect2(lx, 56, 50, 104), Color(0.2, 0.5, 0.5))
		draw_rect(Rect2(lx, 56, 50, 104), Color(0.08, 0.2, 0.22), false, 3.0)
		for v in 3:
			draw_line(Vector2(lx + 12, 66 + v * 5), Vector2(lx + 38, 66 + v * 5), Color(0.05, 0.12, 0.14), 2.0)
		draw_circle(Vector2(lx + 40, 118), 3, Color(0.85, 0.85, 0.9))

func _side(rng: RandomNumberGenerator) -> void:
	# Spindreihe + Tür
	for i in 9:
		var lx := 20.0 + i * 54.0
		draw_rect(Rect2(lx, 40, 50, 100), Color(0.2, 0.5, 0.5))
		draw_rect(Rect2(lx, 40, 50, 100), Color(0.08, 0.2, 0.22), false, 3.0)
		for v in 3:
			draw_line(Vector2(lx + 12, 50 + v * 5), Vector2(lx + 38, 50 + v * 5), Color(0.05, 0.12, 0.14), 2.0)
		draw_circle(Vector2(lx + 40, 100), 3, Color(0.85, 0.85, 0.9))
	draw_rect(Rect2(540, 38, 90, 112), Color(0.6, 0.32, 0.2))
	draw_rect(Rect2(554, 48, 62, 52), Color(0.5, 0.75, 0.8))
	draw_line(Vector2(554, 48), Vector2(616, 100), Color(1, 1, 1, 0.5), 2.0)
	draw_rect(Rect2(680, 50, 100, 64), Color(0.55, 0.38, 0.2))
	draw_rect(Rect2(686, 56, 88, 52), Color(0.78, 0.6, 0.35))
	draw_rect(Rect2(694, 62, 28, 34), Color(0.95, 0.95, 0.9))
