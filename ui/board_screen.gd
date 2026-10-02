class_name BoardScreen
extends HubModal
## Schwarzes Brett: langfristige Challenges mit Fortschrittsbalken und Belohnungen.

var _list: VBoxContainer

func _init() -> void:
	title = "Schwarzes Brett"
	window_size = Vector2(1040, 650)

func build() -> void:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, window_size.y - 240.0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(sc)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	sc.add_child(_list)

func open() -> void:
	_fill()
	super.open()

func _fill() -> void:
	for c in _list.get_children():
		c.queue_free()
	var ids: Array = Db.challenges.keys()
	# abholbereite zuerst
	ids.sort_custom(func(a, b): return int(Save.challenge_done(a) and not Save.challenge_claimed(a)) > int(Save.challenge_done(b) and not Save.challenge_claimed(b)))
	for id in ids:
		_list.add_child(_row(id))

func _row(id: String) -> Control:
	var c: Dictionary = Db.challenges[id]
	var prog := Save.challenge_progress(id)
	var done := Save.challenge_done(id)
	var claimed := Save.challenge_claimed(id)
	var p := card_panel(Vector2(940, 78))
	if claimed:
		p.modulate = Color(0.75, 0.8, 0.75)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	h.add_child(UIKit.icon(UIKit.ICON % ("tickV1" if claimed else "warningCircle"), Vector2(44, 44)))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	v.add_child(UIKit.label(c.name, 19, UIKit.NAVY))
	v.add_child(UIKit.label(c.desc, 13, UIKit.INK))
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(420, 16)
	bar.max_value = c.goal
	bar.value = minf(prog, c.goal)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("background", UIKit.sbox("bar_back", 4))
	bar.add_theme_stylebox_override("fill", UIKit.sbox("bar_green" if done else "bar_cyan", 4))
	v.add_child(bar)
	var rw := "+%d Pässe" % c.passes
	if c.marken > 0:
		rw += ", +%d Marken" % c.marken
	h.add_child(UIKit.label("%d / %d" % [int(minf(prog, c.goal)), int(c.goal)], 15, UIKit.INK))
	var b: Button
	if claimed:
		b = UIKit.button("Erledigt", Vector2(190, 44), 16, Color("d8e8d0"))
		b.disabled = true
	elif done:
		b = UIKit.button("Abholen: " + rw, Vector2(190, 44), 14, Color("c8f0b8"))
		b.pressed.connect(func():
			if Save.claim_challenge(id):
				Sfx.play("rare", 1.0, -4.0)
				Juice.shake(0.3)
				refresh()
				_fill())
	else:
		b = UIKit.button(rw, Vector2(190, 44), 14, Color("f7efc8"))
		b.disabled = true
	h.add_child(b)
	return p
