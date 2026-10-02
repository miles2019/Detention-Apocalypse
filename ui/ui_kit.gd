class_name UIKit
extends RefCounted
## UI-Helfer im Look eines überdrehten Schulsekretariats: Papier, Stempel, Kreide.

const INK := Color("2a2a3d")
const PAPER := Color("f4ead0")
const PAPER_DARK := Color("e3d3a8")
const RED := Color("c0392b")
const NAVY := Color("22305c")
const GOLD := Color("f2c230")
const GREEN := Color("2e9e4f")

static func box(bg: Color = PAPER, border: Color = Color("5a4630"), border_w: int = 4, radius: int = 8, margin: int = 12, shadow: bool = true) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_border_width_all(border_w)
	s.border_color = border
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 8
		s.shadow_offset = Vector2(3, 5)
	return s

static func label(text: String, size: int = 18, color: Color = INK, align: int = HORIZONTAL_ALIGNMENT_LEFT, outline: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align as HorizontalAlignment
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if outline:
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1))
		l.add_theme_constant_override("outline_size", maxi(3, size / 5))
	return l

static func icon(path: String, size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Db.tex(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = size
	t.size = size
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t

## Button im Stil eines Formularstempels: beim Drücken wird er eingedrückt.
static func button(text: String, min_size: Vector2 = Vector2(320, 58), font_size: int = 24, accent: Color = PAPER) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", Color.BLACK)
	b.add_theme_color_override("font_pressed_color", Color.BLACK)
	b.add_theme_color_override("font_disabled_color", Color(0.45, 0.42, 0.38))
	b.add_theme_stylebox_override("normal", box(accent, Color("5a4630"), 4, 6, 10))
	var hover := box(accent.lightened(0.18), Color("a8431f"), 4, 6, 10)
	b.add_theme_stylebox_override("hover", hover)
	var pressed := box(accent.darkened(0.12), Color("5a4630"), 4, 6, 10, false)
	pressed.content_margin_top = 14
	pressed.content_margin_left = 13
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", box(accent.darkened(0.25), Color("7d7466"), 4, 6, 10, false))
	b.add_theme_stylebox_override("focus", hover)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_entered.connect(func(): if not b.disabled: Sfx.play("hover", 1.0, -10.0))
	b.pressed.connect(func(): Sfx.play("click"))
	return b

## Rotierter Stempel-Text mit Rahmen. Wird mit Pop-Animation eingeblendet.
static func stamp(text: String, color: Color = RED, size: int = 44, rot_deg: float = -9.0) -> PanelContainer:
	var p := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, 0.06)
	s.set_border_width_all(5)
	s.border_color = color
	s.set_corner_radius_all(8)
	s.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", s)
	var l := label(text, size, color, HORIZONTAL_ALIGNMENT_CENTER)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.rotation = deg_to_rad(rot_deg)
	p.reset_size()
	p.pivot_offset = p.size * 0.5
	return p

static func pop_in(c: Control, delay: float = 0.0, overshoot: float = 1.0) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.01, 0.01) if overshoot > 0.0 else Vector2.ONE
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(delay)
	tw.tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## Stempel wuchtig auf eine Fläche "schlagen": von groß nach normal + Sound + Shake
static func slam_stamp(c: Control, delay: float = 0.0, sound: bool = true) -> void:
	c.pivot_offset = c.size * 0.5
	c.modulate.a = 0.0
	c.scale = Vector2(2.4, 2.4)
	var tw := c.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_interval(delay)
	tw.tween_callback(func():
		c.modulate.a = 1.0
	)
	tw.tween_property(c, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	if sound:
		tw.tween_callback(func(): Sfx.play("stamp"); Juice.shake(0.3))
	tw.tween_property(c, "scale", Vector2(1.08, 1.08), 0.05)
	tw.tween_property(c, "scale", Vector2.ONE, 0.1)

static func dim(alpha: float = 0.6) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color(0.03, 0.03, 0.08, alpha)
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	return r

static func full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
