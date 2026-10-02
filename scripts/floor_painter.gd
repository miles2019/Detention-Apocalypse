class_name FloorPainter
extends Node2D
## Malt den statischen Boden (Fliesen, Fugen, Farbspritzer, Papierhaufen) einmalig in einen SubViewport.

func _draw() -> void:
	# Hintergrund
	draw_rect(Rect2(Vector2.ZERO, Arena.WORLD), Color(0.07, 0.08, 0.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Große, gedeckte Schulfliesen mit Fugen
	var chap: Dictionary = Game.chapter_data()
	var pal: Dictionary = chap.floor
	var style: String = chap.style
	var ts := 100.0
	var row := 0
	var y := Arena.PLAY.position.y
	while y < Arena.PLAY.end.y:
		var col := 0
		var x := Arena.PLAY.position.x
		while x < Arena.PLAY.end.x:
			var base: Color = pal.a if (row + col) % 2 == 0 else pal.b
			var v := rng.randf_range(-0.025, 0.025)
			draw_rect(Rect2(x, y, minf(ts, Arena.PLAY.end.x - x), minf(ts, Arena.PLAY.end.y - y)), Color(base.r + v, base.g + v, base.b + v))
			x += ts
			col += 1
		y += ts
		row += 1
	var gx := Arena.PLAY.position.x
	while gx <= Arena.PLAY.end.x:
		draw_line(Vector2(gx, Arena.PLAY.position.y), Vector2(gx, Arena.PLAY.end.y), pal.grout, 3.0)
		gx += ts
	var gy := Arena.PLAY.position.y
	while gy <= Arena.PLAY.end.y:
		draw_line(Vector2(Arena.PLAY.position.x, gy), Vector2(Arena.PLAY.end.x, gy), pal.grout, 3.0)
		gy += ts
	# Wasserflecken / abgeplatzte Stellen (bläulich-grau)
	for i in 7:
		var c := Vector2(rng.randf_range(Arena.PLAY.position.x, Arena.PLAY.end.x), rng.randf_range(Arena.PLAY.position.y, Arena.PLAY.end.y))
		_blob(c, rng.randf_range(60.0, 130.0), Color(0.36, 0.4, 0.5, 0.45), rng)
	# Farbspritzer der Mutation (Schleim, Farbe, Chemikalien)
	var paint := [Color(0.35, 0.78, 0.3, 0.6), Color(0.62, 0.3, 0.7, 0.55), Color(0.2, 0.65, 0.65, 0.55), Color(0.85, 0.75, 0.2, 0.5), Color(0.9, 0.4, 0.55, 0.5), Color(0.55, 0.35, 0.2, 0.5)]
	for i in (22 if style != "yard" else 8):
		var p := Vector2(rng.randf_range(Arena.PLAY.position.x + 30, Arena.PLAY.end.x - 30), rng.randf_range(Arena.PLAY.position.y + 20, Arena.PLAY.end.y - 20))
		_blob(p, rng.randf_range(22.0, 62.0), paint[rng.randi() % paint.size()], rng)
		for k in 6:
			var dp := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(50.0, 110.0)
			draw_circle(dp, rng.randf_range(3.0, 8.0), paint[rng.randi() % paint.size()])
	if style == "yard":
		for i in 7:
			var gp := Vector2(rng.randf_range(Arena.PLAY.position.x, Arena.PLAY.end.x), rng.randf_range(Arena.PLAY.position.y, Arena.PLAY.end.y))
			_blob(gp, rng.randf_range(80.0, 170.0), Color(0.3, 0.55, 0.28, 0.9), rng)
		# Basketballfeld und Hüpfkästchen
		draw_rect(Rect2(1120, 420, 380, 280), Color(1, 1, 1, 0.5), false, 5.0)
		draw_arc(Vector2(1310, 560), 60.0, 0, TAU, 32, Color(1, 1, 1, 0.5), 5.0)
		draw_line(Vector2(1310, 420), Vector2(1310, 700), Color(1, 1, 1, 0.5), 5.0)
		for k in 6:
			draw_rect(Rect2(540 + (k % 2) * 40, 440 + k * 40, 40, 40), Color(1, 0.9, 0.3, 0.7), false, 4.0)
	if style == "library":
		# roter Teppich und Parkett-Holzlinien
		draw_rect(Rect2(560, Arena.PLAY.position.y + 20, 480, Arena.PLAY.size.y - 40), Color(0.55, 0.12, 0.14, 0.75))
		draw_rect(Rect2(576, Arena.PLAY.position.y + 36, 448, Arena.PLAY.size.y - 72), Color(0.45, 0.08, 0.1, 0.5), false, 4.0)
	elif style == "lab":
		for i in 40:
			var p := Vector2(Arena.PLAY.position.x + 50.0 + (i % 14) * 100.0, Arena.PLAY.position.y + 50.0 + (i / 14) * 100.0)
			draw_line(p + Vector2(-6, 0), p + Vector2(6, 0), Color(0.3, 0.45, 0.4, 0.5), 2.0)
			draw_line(p + Vector2(0, -6), p + Vector2(0, 6), Color(0.3, 0.45, 0.4, 0.5), 2.0)
	# Papierhaufen, Dosen, Kratzer
	for i in (16 if style != "yard" else 0):
		var pp := Vector2(rng.randf_range(Arena.PLAY.position.x + 40, Arena.PLAY.end.x - 40), rng.randf_range(Arena.PLAY.position.y + 30, Arena.PLAY.end.y - 30))
		_paper_pile(pp, rng)
	for i in 70:
		var q := Vector2(rng.randf_range(Arena.PLAY.position.x, Arena.PLAY.end.x), rng.randf_range(Arena.PLAY.position.y, Arena.PLAY.end.y))
		draw_line(q, q + Vector2(rng.randf_range(-24, 24), rng.randf_range(-8, 8)), Color(0.25, 0.23, 0.2, 0.3), 2.0)
	draw_rect(Arena.PLAY, Color(0.1, 0.1, 0.14), false, 6.0)

func _blob(center: Vector2, r: float, color: Color, rng: RandomNumberGenerator) -> void:
	var pts := PackedVector2Array()
	var n := 16
	for i in n:
		var a := TAU * i / n
		var rr := r * rng.randf_range(0.65, 1.25)
		pts.append(center + Vector2(cos(a) * rr, sin(a) * rr * 0.85))
	draw_colored_polygon(pts, color)

func _paper_pile(p: Vector2, rng: RandomNumberGenerator) -> void:
	for i in rng.randi_range(4, 9):
		var o := p + Vector2(rng.randf_range(-26, 26), rng.randf_range(-12, 12))
		var ang := rng.randf_range(-0.8, 0.8)
		var w := rng.randf_range(16.0, 26.0)
		var h := w * 0.72
		var pts := PackedVector2Array([Vector2(-w, -h), Vector2(w, -h * 0.9), Vector2(w * 0.9, h), Vector2(-w * 0.95, h * 0.85)])
		var xf := Transform2D(ang, o)
		draw_colored_polygon(xf * pts, Color(0.9, 0.9, 0.88))
		draw_polyline(xf * PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.2, 0.2, 0.22), 1.5)

