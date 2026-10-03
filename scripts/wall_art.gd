class_name WallArt
extends Node2D
## Gemalte Wandtextur (wird einmal in einen SubViewport gerendert): Sockel, Fenster mit Brettern und
## Monster-Silhouetten, Türen, Spinde, Pinnwand, Spinnweben, Risse, Schleim-Tropfen.
## kind: "back" (1600x210 px Weltmaß) oder "side" (825x150).

var kind := "back"
var style := "classroom"
var size := Vector2(1600, 210)

# Wandfarben der Kapitel 4-9
const THEMES := {"cafeteria": Color(0.92, 0.8, 0.6), "gym": Color(0.8, 0.84, 0.88), "computer": Color(0.42, 0.46, 0.6),
	"art": Color(0.94, 0.92, 0.88), "toilet": Color(0.8, 0.9, 0.92), "bus": Color(0.95, 0.76, 0.2)}

func _draw() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 if kind == "back" else 11
	var w := size.x
	var h := size.y
	var base := Color(0.87, 0.84, 0.64)
	if style == "yard":
		base = Color(0.78, 0.45, 0.34)
	if style == "lab":
		base = Color(0.82, 0.9, 0.86)
	elif THEMES.has(style):
		base = THEMES[style]
	elif style == "library":
		base = Color(0.5, 0.36, 0.28)
	draw_rect(Rect2(0, 0, w, h), base)
	# Schmutz-Verläufe
	for i in 24:
		draw_rect(Rect2(rng.randf_range(0, w), rng.randf_range(0, h * 0.7), rng.randf_range(30, 120), rng.randf_range(10, 40)), Color(0.7, 0.66, 0.46, 0.18))
	# Zierleiste oben + Sockel unten
	draw_rect(Rect2(0, 0, w, 16), Color(0.28, 0.5, 0.52))
	draw_rect(Rect2(0, 16, w, 5), Color(0.2, 0.36, 0.4))
	draw_rect(Rect2(0, h * 0.72, w, h * 0.28), Color(0.3, 0.46, 0.46))
	draw_rect(Rect2(0, h * 0.72, w, 5), Color(0.55, 0.7, 0.66))
	if style == "yard":
		_yard(rng)
	elif style == "lab":
		_lab(rng)
	elif style == "library":
		_library(rng)
	elif THEMES.has(style):
		_themed(rng)
	elif kind == "back":
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
	# Düsterer Verlauf: oben (Decke), unten (Bodenkontakt) und an den Seiten
	var dk := 0.62 if style != "yard" else 0.2
	for y in 44:
		draw_rect(Rect2(0, y, w, 1), Color(0.02, 0.02, 0.06, dk * (1.0 - float(y) / 44.0)))
	for y in 30:
		draw_rect(Rect2(0, h - 1 - y, w, 1), Color(0.02, 0.02, 0.06, dk * 0.55 * (1.0 - float(y) / 30.0)))
	for x in 140:
		var fa := dk * 0.8 * pow(1.0 - float(x) / 140.0, 1.6)
		draw_rect(Rect2(x, 0, 1, h), Color(0.02, 0.02, 0.06, fa))
		draw_rect(Rect2(w - 1 - x, 0, 1, h), Color(0.02, 0.02, 0.06, fa))
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

func _yard(rng: RandomNumberGenerator) -> void:
	var w := size.x
	var h := size.y
	# Backsteine
	var row := 0
	var y := 22.0
	while y < h:
		var x := -20.0 if row % 2 == 0 else 0.0
		while x < w:
			draw_rect(Rect2(x + 1, y + 1, 38, 12), Color(0.8 + rng.randf_range(-0.06, 0.06), 0.46 + rng.randf_range(-0.05, 0.05), 0.34))
			x += 40.0
		y += 14.0
		row += 1
	# zwei Fensterreihen
	for r in 2:
		for c in 9:
			var wx := 60.0 + c * 170.0
			var wy := 34.0 + r * 80.0
			if r == 1 and c in [4]:
				continue
			draw_rect(Rect2(wx - 4, wy - 4, 78, 62), Color(0.95, 0.93, 0.85))
			draw_rect(Rect2(wx, wy, 70, 54), Color(0.45, 0.7, 0.85))
			draw_line(Vector2(wx + 35, wy), Vector2(wx + 35, wy + 54), Color(0.95, 0.93, 0.85), 4.0)
			draw_line(Vector2(wx, wy + 27), Vector2(wx + 70, wy + 27), Color(0.95, 0.93, 0.85), 4.0)
	# Doppeltür mit Schild
	var dx := 800.0 - 55.0
	draw_rect(Rect2(dx - 6, 100, 122, 110), Color(0.3, 0.2, 0.15))
	draw_rect(Rect2(dx, 106, 52, 104), Color(0.35, 0.55, 0.65))
	draw_rect(Rect2(dx + 58, 106, 52, 104), Color(0.35, 0.55, 0.65))
	draw_rect(Rect2(700, 62, 200, 30), Color(0.95, 0.9, 0.7))
	draw_string(ThemeDB.fallback_font, Vector2(730, 86), "SCHULE", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.2, 0.15, 0.1))

func _lab(rng: RandomNumberGenerator) -> void:
	var w := size.x
	var h := size.y
	# Fliesen-Raster an der Wand
	var gx := 0.0
	while gx < w:
		draw_line(Vector2(gx, 22), Vector2(gx, h * 0.72), Color(0.6, 0.72, 0.68, 0.5), 2.0)
		gx += 50.0
	# Vitrinen mit Kolben
	var cabinets := 4 if kind == "back" else 2
	for c in cabinets:
		var x := 40.0 + c * (w / float(cabinets)) if kind == "back" else 60.0 + c * 330.0
		draw_rect(Rect2(x, 44, 170, 104), Color(0.35, 0.45, 0.5))
		draw_rect(Rect2(x + 6, 50, 158, 92), Color(0.75, 0.9, 0.95, 0.85))
		draw_line(Vector2(x + 6, 96), Vector2(x + 164, 96), Color(0.35, 0.45, 0.5), 3.0)
		for k in 6:
			var cx := x + 22 + k * 25.0
			var col: Color = [Color(0.4, 0.9, 0.4), Color(0.9, 0.4, 0.8), Color(0.4, 0.7, 1.0), Color(1.0, 0.8, 0.3)][rng.randi() % 4]
			draw_circle(Vector2(cx, 82), 9, col)
			draw_rect(Rect2(cx - 3, 66, 6, 10), Color(0.8, 0.9, 0.95))
			draw_circle(Vector2(cx, 130), 8, col)
	if kind == "back":
		# Periodensystem-Poster und Warnschilder
		draw_rect(Rect2(700, 44, 200, 88), Color(0.95, 0.95, 0.9))
		for r in 4:
			for c in 9:
				draw_rect(Rect2(706 + c * 21, 50 + r * 20, 18, 17), [Color(0.9, 0.5, 0.5), Color(0.5, 0.8, 0.9), Color(0.9, 0.9, 0.4), Color(0.6, 0.9, 0.6)][(r + c) % 4])
		for sx in [1100.0, 1400.0]:
			var tri := PackedVector2Array([Vector2(sx, 50), Vector2(sx - 30, 104), Vector2(sx + 30, 104)])
			draw_colored_polygon(tri, Color(1.0, 0.85, 0.1))
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(0.1, 0.1, 0.1), 3.0)
			draw_string(ThemeDB.fallback_font, Vector2(sx - 7, 96), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(0.1, 0.1, 0.1))

func _library(rng: RandomNumberGenerator) -> void:
	var w := size.x
	var h := size.y
	# Bücherregale über die gesamte Wand
	var shelf_cols := int(w / 120.0)
	for c in shelf_cols:
		var x := c * 120.0
		draw_rect(Rect2(x + 4, 24, 112, h * 0.7), Color(0.35, 0.22, 0.14))
		for row in 4:
			var y := 30.0 + row * 34.0
			draw_rect(Rect2(x + 8, y + 28, 104, 4), Color(0.25, 0.15, 0.1))
			var bx := x + 10.0
			while bx < x + 108.0:
				var bw := rng.randf_range(7.0, 14.0)
				var bh := rng.randf_range(18.0, 27.0)
				var col := Color.from_hsv(rng.randf(), rng.randf_range(0.4, 0.8), rng.randf_range(0.5, 0.85))
				draw_rect(Rect2(bx, y + 28.0 - bh, bw, bh), col)
				bx += bw + 1.0
	# Gemälde und Fenster mit Mond
	if kind == "back":
		draw_rect(Rect2(380, 40, 120, 90), Color(0.7, 0.55, 0.2))
		draw_rect(Rect2(388, 48, 104, 74), Color(0.2, 0.3, 0.45))
		draw_circle(Vector2(440, 82), 18, Color(0.95, 0.95, 0.7))
		draw_rect(Rect2(1050, 40, 120, 90), Color(0.7, 0.55, 0.2))
		draw_rect(Rect2(1058, 48, 104, 74), Color(0.35, 0.5, 0.35))

# ---------------- Rest

## Wände der Kapitel 4-9: wenige, klar lesbare Motive je Raum
func _themed(rng: RandomNumberGenerator) -> void:
	var w := size.x
	var h := size.y
	var f := ThemeDB.fallback_font
	match style:
		"cafeteria":
			# Essensausgabe mit Speiseplan
			var n := 3 if kind == "back" else 2
			for c in n:
				var x := 120.0 + c * (w - 240.0) / float(maxi(1, n - 1)) - 110.0 if n > 1 else 100.0
				draw_rect(Rect2(x, 46, 220, 96), Color(0.3, 0.22, 0.16))
				draw_rect(Rect2(x + 8, 54, 204, 80), Color(0.16, 0.14, 0.16))
				for k in 4:
					draw_rect(Rect2(x + 18 + k * 50, 104, 34, 22), [Color(0.9, 0.5, 0.2), Color(0.5, 0.75, 0.3), Color(0.85, 0.3, 0.3), Color(0.95, 0.85, 0.5)][k])
				draw_rect(Rect2(x, 142, 220, 8), Color(0.75, 0.76, 0.8))
			if kind == "back":
				draw_rect(Rect2(700, 30, 200, 64), Color(0.14, 0.3, 0.22))
				draw_string(f, Vector2(716, 56), "HEUTE:", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.95, 0.95, 0.85))
				draw_string(f, Vector2(716, 82), "EINTOPF (LEBT)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.85, 0.4))
		"gym":
			# Sprossenwände und Basketballkorb
			var bars := 5 if kind == "back" else 3
			for c in bars:
				var x2 := 70.0 + c * (w - 140.0) / float(bars) + 20.0
				draw_rect(Rect2(x2, 30, 110, 118), Color(0.62, 0.42, 0.22))
				for k in 9:
					draw_line(Vector2(x2 + 6, 38 + k * 12.5), Vector2(x2 + 104, 38 + k * 12.5), Color(0.86, 0.68, 0.4), 4.0)
			if kind == "back":
				draw_rect(Rect2(750, 34, 100, 70), Color(0.96, 0.96, 0.96))
				draw_rect(Rect2(778, 60, 44, 32), Color(0.9, 0.3, 0.2), false, 4.0)
				draw_arc(Vector2(800, 112), 20.0, 0, PI, 12, Color(0.95, 0.45, 0.15), 5.0)
		"computer":
			# Server-Schränke, Kabel, Poster
			var racks := 6 if kind == "back" else 3
			for c in racks:
				var x3 := 50.0 + c * (w - 100.0) / float(racks)
				draw_rect(Rect2(x3, 36, 120, 112), Color(0.14, 0.16, 0.22))
				for k in 7:
					draw_rect(Rect2(x3 + 8, 44 + k * 14, 104, 9), Color(0.22, 0.25, 0.34))
					draw_circle(Vector2(x3 + 16 + rng.randi_range(0, 6) * 14, 48.5 + k * 14), 2.6, [Color(0.3, 1.0, 0.4), Color(1.0, 0.3, 0.3), Color(1.0, 0.85, 0.3)][rng.randi() % 3])
			for i in 5:
				var a := Vector2(rng.randf_range(0, w), 22)
				draw_polyline(PackedVector2Array([a, a + Vector2(rng.randf_range(-40, 40), 60), a + Vector2(rng.randf_range(-70, 70), h * 0.7)]), Color(0.1, 0.1, 0.14), 4.0)
			if kind == "back":
				draw_rect(Rect2(690, 44, 220, 54), Color(0.05, 0.1, 0.3))
				draw_string(f, Vector2(704, 78), "FATAL ERROR 0xF", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.9, 0.95, 1.0))
		"art":
			# Bilderrahmen und Farbspritzer
			var cols := [Color("ff5fa8"), Color("5fd0ff"), Color("ffd84a"), Color("8be05a"), Color("c78bff"), Color("ff8a4a")]
			var frames := 8 if kind == "back" else 4
			for c in frames:
				var x4 := 50.0 + c * (w - 100.0) / float(frames)
				var fw := rng.randf_range(80, 130)
				var fh := rng.randf_range(60, 96)
				var fy := rng.randf_range(34, 50)
				draw_rect(Rect2(x4, fy, fw, fh), Color(0.5, 0.34, 0.16))
				draw_rect(Rect2(x4 + 7, fy + 7, fw - 14, fh - 14), cols[rng.randi() % cols.size()].lightened(0.4))
				draw_circle(Vector2(x4 + fw * rng.randf_range(0.3, 0.7), fy + fh * rng.randf_range(0.35, 0.65)), fh * 0.22, cols[rng.randi() % cols.size()])
			for i in 30:
				draw_circle(Vector2(rng.randf_range(0, w), rng.randf_range(24, h)), rng.randf_range(3, 12), cols[rng.randi() % cols.size()])
		"toilet":
			# Kacheln, Spiegel, Kritzeleien
			var gx := 0.0
			while gx < w:
				draw_line(Vector2(gx, 22), Vector2(gx, h), Color(0.55, 0.7, 0.74, 0.7), 2.0)
				gx += 34.0
			var gy := 22.0
			while gy < h:
				draw_line(Vector2(0, gy), Vector2(w, gy), Color(0.55, 0.7, 0.74, 0.7), 2.0)
				gy += 34.0
			if kind == "back":
				for c in 5:
					var dx := 100.0 + c * 300.0
					draw_rect(Rect2(dx, 60, 150, 150), Color(0.98, 0.93, 0.55))
					draw_rect(Rect2(dx + 8, 68, 134, 142), Color(0.9, 0.84, 0.45))
					draw_circle(Vector2(dx + 122, 140), 6.0, Color(0.5, 0.5, 0.55))
					draw_string(f, Vector2(dx + 50, 110), str(c + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(0.4, 0.3, 0.1))
				draw_string(f, Vector2(410, 50), "KABINE 3: NICHT ÖFFNEN!!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0.8, 0.15, 0.15))
			else:
				for c in 3:
					draw_rect(Rect2(90.0 + c * 250.0, 40, 130, 80), Color(0.72, 0.9, 0.96))
					draw_rect(Rect2(90.0 + c * 250.0, 40, 130, 80), Color(0.5, 0.55, 0.6), false, 4.0)
		"bus":
			# Fensterreihe mit vorbeiziehender Landschaft
			var wins := 9 if kind == "back" else 5
			for c in wins:
				var x5 := 30.0 + c * (w - 60.0) / float(wins)
				var ww := (w - 60.0) / float(wins) - 22.0
				draw_rect(Rect2(x5, 34, ww, 96), Color(0.15, 0.15, 0.18))
				draw_rect(Rect2(x5 + 6, 40, ww - 12, 84), Color(0.55, 0.8, 0.95))
				draw_rect(Rect2(x5 + 6, 96, ww - 12, 28), Color(0.4, 0.62, 0.35))
				draw_line(Vector2(x5 + 6, 68), Vector2(x5 + ww - 6, 60), Color(1, 1, 1, 0.5), 3.0)
			draw_rect(Rect2(0, h * 0.72, w, 8), Color(0.12, 0.12, 0.14))
			if kind == "back":
				draw_string(f, Vector2(690, 30), "LINIE 13 - ENDSTATION", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.15, 0.1, 0.05))
