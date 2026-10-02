class_name FloorPainter
extends Node2D
## Malt den statischen Boden (Fliesen, Fugen, Farbspritzer, Papierhaufen) einmalig in einen SubViewport.

func _draw() -> void:
	# Hintergrund
	draw_rect(Rect2(Vector2.ZERO, Arena.WORLD), Color(0.07, 0.08, 0.1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Große, gedeckte Schulfliesen mit Fugen
	var ts := 100.0
	var row := 0
	var y := Arena.PLAY.position.y
	while y < Arena.PLAY.end.y:
		var col := 0
		var x := Arena.PLAY.position.x
		while x < Arena.PLAY.end.x:
			var base := Color(0.60, 0.56, 0.45) if (row + col) % 2 == 0 else Color(0.54, 0.53, 0.45)
			var v := rng.randf_range(-0.025, 0.025)
			draw_rect(Rect2(x, y, minf(ts, Arena.PLAY.end.x - x), minf(ts, Arena.PLAY.end.y - y)), Color(base.r + v, base.g + v, base.b + v))
			x += ts
			col += 1
		y += ts
		row += 1
	var gx := Arena.PLAY.position.x
	while gx <= Arena.PLAY.end.x:
		draw_line(Vector2(gx, Arena.PLAY.position.y), Vector2(gx, Arena.PLAY.end.y), Color(0.3, 0.28, 0.24, 0.55), 3.0)
		gx += ts
	var gy := Arena.PLAY.position.y
	while gy <= Arena.PLAY.end.y:
		draw_line(Vector2(Arena.PLAY.position.x, gy), Vector2(Arena.PLAY.end.x, gy), Color(0.3, 0.28, 0.24, 0.55), 3.0)
		gy += ts
	# Wasserflecken / abgeplatzte Stellen (bläulich-grau)
	for i in 7:
		var c := Vector2(rng.randf_range(Arena.PLAY.position.x, Arena.PLAY.end.x), rng.randf_range(Arena.PLAY.position.y, Arena.PLAY.end.y))
		_blob(c, rng.randf_range(60.0, 130.0), Color(0.36, 0.4, 0.5, 0.45), rng)
	# Farbspritzer der Mutation (Schleim, Farbe, Chemikalien)
	var paint := [Color(0.35, 0.78, 0.3, 0.6), Color(0.62, 0.3, 0.7, 0.55), Color(0.2, 0.65, 0.65, 0.55), Color(0.85, 0.75, 0.2, 0.5), Color(0.9, 0.4, 0.55, 0.5), Color(0.55, 0.35, 0.2, 0.5)]
	for i in 22:
		var p := Vector2(rng.randf_range(Arena.PLAY.position.x + 30, Arena.PLAY.end.x - 30), rng.randf_range(Arena.PLAY.position.y + 20, Arena.PLAY.end.y - 20))
		_blob(p, rng.randf_range(22.0, 62.0), paint[rng.randi() % paint.size()], rng)
		for k in 6:
			var dp := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(50.0, 110.0)
			draw_circle(dp, rng.randf_range(3.0, 8.0), paint[rng.randi() % paint.size()])
	# Papierhaufen, Dosen, Kratzer
	for i in 16:
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

