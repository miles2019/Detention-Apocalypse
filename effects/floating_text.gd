class_name FloatingText
extends Label
## Schwebende Zahl / Kurztext. Poppt kurz auf, steigt auf und verblasst.

static var active := 0

static func spawn(parent: Node, pos: Vector2, text: String, color: Color = Color.WHITE, size: int = 18, pop: bool = false, rise: float = 46.0) -> void:
	if active > 70 or Game.arena == null:
		return
	var stage: Stage3D = Game.arena.stage
	parent = stage.text_layer
	pos = stage.world_to_screen(pos)
	var f := FloatingText.new()
	f.text = text
	f.add_theme_font_size_override("font_size", size)
	f.add_theme_color_override("font_color", color)
	f.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
	f.add_theme_constant_override("outline_size", maxi(3, size / 5))
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(f)
	f.reset_size()
	f.position = pos - f.size * 0.5
	f.pivot_offset = f.size * 0.5
	active += 1
	var tw := f.create_tween()
	if pop:
		f.scale = Vector2(0.3, 0.3)
		tw.tween_property(f, "scale", Vector2(1.35, 1.35), 0.09).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(f, "scale", Vector2.ONE, 0.08)
	tw.set_parallel(true)
	tw.tween_property(f, "position:y", f.position.y - rise, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(f, "modulate:a", 0.0, 0.3).set_delay(0.45)
	tw.chain().tween_callback(f.queue_free)

func _exit_tree() -> void:
	active = maxi(0, active - 1)
