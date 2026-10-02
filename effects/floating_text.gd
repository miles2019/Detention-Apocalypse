class_name FloatingText
extends Label3D
## Schwebende Zahl / Kurztext als Billboard-Label3D im 3D-Raum: poppt kurz auf, steigt auf und verblasst.

static var active := 0

static func spawn(pos: Vector2, lift_px: float, text: String, color: Color = Color.WHITE, size: int = 18, pop: bool = false, rise: float = 46.0) -> void:
	if active > 60 or Game.arena == null:
		return
	var stage: Stage3D = Game.arena.stage
	var f := FloatingText.new()
	f.text = text
	f.font_size = int(size * 2.6)
	f.pixel_size = 0.0034
	f.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	f.no_depth_test = true
	f.shaded = false
	f.modulate = color
	f.outline_modulate = Color(0.05, 0.05, 0.1)
	f.outline_size = maxi(8, size)
	f.render_priority = 20
	f.outline_render_priority = 19
	stage.fx3.add_child(f)
	f.position = stage.to3(pos, lift_px)
	active += 1
	var tw := f.create_tween()
	if pop:
		f.scale = Vector3(0.3, 0.3, 0.3)
		tw.tween_property(f, "scale", Vector3(1.35, 1.35, 1.35), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(f, "scale", Vector3.ONE, 0.08)
	tw.set_parallel(true)
	tw.tween_property(f, "position:y", f.position.y + rise * Stage3D.S, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.tween_property(f, "outline_modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(f.queue_free)

func _exit_tree() -> void:
	active = maxi(0, active - 1)
