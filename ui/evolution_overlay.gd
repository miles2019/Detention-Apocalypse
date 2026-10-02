class_name EvolutionOverlay
extends Control
## Fusionsmoment: Aktion friert ein, beide Basiswaffen werden zusammengezogen, Fachsymbole + Partikel,
## Durchsage, Stempel "Evolution genehmigt", neue Waffe erscheint.

signal finished

var _a: TextureRect
var _b: TextureRect
var _res: TextureRect
var _flash: ColorRect
var _title: Label
var _icons: Array = []
var _particles: CPUParticles2D

func _ready() -> void:
	UIKit.full(self)
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(UIKit.dim(0.85))
	_a = UIKit.icon("", Vector2(180, 180))
	_b = UIKit.icon("", Vector2(180, 180))
	_res = UIKit.icon("", Vector2(260, 260))
	for t in [_a, _b, _res]:
		add_child(t)
	_title = UIKit.label("", 40, Color(1, 0.9, 0.4), HORIZONTAL_ALIGNMENT_CENTER, true)
	_title.position = Vector2(240, 90)
	_title.custom_minimum_size = Vector2(800, 0)
	_title.size = Vector2(800, 60)
	add_child(_title)
	_flash = ColorRect.new()
	UIKit.full(_flash)
	_flash.color = Color(1, 1, 1, 0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	_particles = CPUParticles2D.new()
	_particles.emitting = false
	_particles.one_shot = true
	_particles.explosiveness = 1.0
	_particles.amount = 70
	_particles.lifetime = 1.0
	_particles.spread = 180.0
	_particles.initial_velocity_min = 200.0
	_particles.initial_velocity_max = 520.0
	_particles.scale_amount_min = 4.0
	_particles.scale_amount_max = 9.0
	_particles.color = Color(1, 0.9, 0.4)
	_particles.position = Vector2(640, 360)
	add_child(_particles)

func play(recipe: Dictionary) -> void:
	var wa: WeaponData = Db.weapons[recipe.a]
	var wb: WeaponData = Db.weapons[recipe.b]
	var wr: WeaponData = Db.weapons[recipe.result]
	for c in _icons:
		c.queue_free()
	_icons.clear()
	_a.texture = Db.tex(wa.icon)
	_b.texture = Db.tex(wb.icon)
	_res.texture = Db.tex(wr.icon)
	_a.position = Vector2(180, 270)
	_b.position = Vector2(920, 270)
	_a.modulate = Color.WHITE
	_b.modulate = Color.WHITE
	_a.scale = Vector2.ONE
	_b.scale = Vector2.ONE
	_res.visible = false
	_title.text = "Fusion: %s + %s" % [wa.display_name, wb.display_name]
	_title.modulate.a = 1.0
	visible = true
	# 1) Aktion friert ein (Zeit steht), Warnton
	Sfx.play("warn", 0.7)
	Juice.shake(0.2)
	var tw := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(0.5)
	# 2) Beide Waffen werden zusammengezogen
	tw.tween_callback(func(): Sfx.play("evolution"))
	tw.set_parallel(true)
	tw.tween_property(_a, "position", Vector2(550, 270), 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(_b, "position", Vector2(550, 270), 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.tween_property(_a, "rotation", TAU, 0.8)
	tw.tween_property(_b, "rotation", -TAU, 0.8)
	_a.pivot_offset = Vector2(90, 90)
	_b.pivot_offset = Vector2(90, 90)
	# 3) Fachsymbole kreisen
	for i in 6:
		var sym := UIKit.icon(Db.subject_icon(wr.subject), Vector2(48, 48))
		add_child(sym)
		_icons.append(sym)
		var ang := TAU * i / 6.0
		sym.position = Vector2(640, 360) + Vector2.from_angle(ang) * 260.0
		var tws := sym.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tws.tween_property(sym, "position", Vector2(616, 336) + Vector2.from_angle(ang + 2.5) * 20.0, 0.8).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(func():
		# 4) Blitz, Partikel, neue Waffe
		_flash.color.a = 1.0
		create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(_flash, "color:a", 0.0, 0.6)
		_a.visible = false
		_b.visible = false
		for c in _icons:
			c.visible = false
		_res.visible = true
		_res.position = Vector2(510, 230)
		_res.pivot_offset = Vector2(130, 130)
		_res.scale = Vector2(0.2, 0.2)
		create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).tween_property(_res, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_particles.restart()
		_particles.emitting = true
		Sfx.play("rare")
		Sfx.play("explosion")
		Juice.shake(0.7)
		_title.text = "%s!" % wr.display_name
		Game.announce.emit("Durchsage: Die Fusion zur %s wurde ordnungsgemäß genehmigt." % wr.display_name, "info")
	)
	tw.set_parallel(false)
	tw.tween_interval(0.7)
	tw.tween_callback(func():
		# 5) Stempel "Evolution genehmigt"
		var st := UIKit.stamp("Evolution genehmigt", UIKit.RED, 54, -8.0)
		add_child(st)
		st.reset_size()
		st.position = Vector2(640, 560) - st.size * 0.5
		UIKit.slam_stamp(st, 0.0)
		var d := wr.desc
		var dl := UIKit.label(d, 20, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, true)
		dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dl.position = Vector2(340, 500)
		dl.custom_minimum_size = Vector2(600, 0)
		add_child(dl)
		_icons.append(st)
		_icons.append(dl)
	)
	tw.tween_interval(1.8)
	tw.tween_callback(func():
		visible = false
		for c in _icons:
			c.queue_free()
		_icons.clear()
		_a.visible = true
		_b.visible = true
		finished.emit())
