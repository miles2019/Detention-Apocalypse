extends SceneTree
func _init() -> void:
	var f: FontFile = load("res://assets/fonts/Kaph-Regular.ttf")
	var missing := ""
	for ch in "ÄÖÜäöüß§%·–…—„“!?:;/()+-=*#0123456789abcXYZ€&@":
		if not f.has_char(ch.unicode_at(0)):
			missing += ch
	print("FEHLENDE ZEICHEN: [", missing, "]")
	quit()
