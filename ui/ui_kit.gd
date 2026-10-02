class_name UIKit
extends RefCounted
## UI-Helfer im Look eines überdrehten Schulsekretariats – gebaut auf dem "Vector UI Pack (dobo_ui)":
## 9-Patch-Styleboxen aus assets/ui/scaled (erzeugt von tools/build_ui_assets.gd), Notizbuch-Modals, Item-Slots,
## Fortschrittsbalken. Zentrales Theme: UIKit.make_theme() (auch als resources/ui_theme.tres gespeichert).

const INK := Color("2a2a3d")
const PAPER := Color("f4ead0")
const PAPER_DARK := Color("e3d3a8")
const RED := Color("c0392b")
const NAVY := Color("22305c")
const GOLD := Color("f2c230")
const GREEN := Color("2e9e4f")
const SCALED := "res://assets/ui/scaled/%s.png"
const ICON := "res://assets/ui/Icons/%s.png"

# Rand in skalierten Pixeln: links, oben, rechts, unten (muss zu tools/build_ui_assets.gd passen)
const MARG := {
	btn = Vector4(17, 17, 17, 20), container_cream = Vector4(16, 16, 16, 18), card_cream = Vector4(16, 40, 16, 16),
	card_shop = Vector4(16, 16, 16, 20), panel = Vector4(8, 16, 8, 16), notebook = Vector4(100, 96, 100, 30),
	notebook2 = Vector4(100, 96, 100, 30), modal_dark = Vector4(24, 72, 24, 30), modal_simple = Vector4(100, 96, 100, 30),
	slot = Vector4(18, 18, 18, 22), bar_back = Vector4(12, 12, 12, 12), bar = Vector4(9, 9, 9, 9), header = Vector4(20, 20, 20, 22),
	label_wood = Vector4(20, 20, 20, 20),
}

static var _cache := {}

static func _margins(name: String) -> Vector4:
	for k in MARG:
		if name.begins_with(k):
			return MARG[k]
	return Vector4(16, 16, 16, 16)

## Gecachte 9-Patch-Stylebox. Nicht verändern (geteilte Instanz) – für Varianten sbox_new() nutzen.
static func sbox(name: String, content: float = 12.0, mod: Color = Color.WHITE) -> StyleBoxTexture:
	var key := "%s|%.1f|%s" % [name, content, mod.to_html()]
	if _cache.has(key):
		return _cache[key]
	var sb := sbox_new(name, content, mod)
	_cache[key] = sb
	return sb

static func sbox_new(name: String, content: float = 12.0, mod: Color = Color.WHITE) -> StyleBoxTexture:
	var sb := StyleBoxTexture.new()
	sb.texture = load(SCALED % name)
	var m := _margins(name)
	sb.texture_margin_left = m.x
	sb.texture_margin_top = m.y
	sb.texture_margin_right = m.z
	sb.texture_margin_bottom = m.w
	sb.content_margin_left = maxf(content, m.x * 0.6)
	sb.content_margin_right = maxf(content, m.z * 0.6)
	sb.content_margin_top = maxf(content, m.y * 0.6)
	sb.content_margin_bottom = maxf(content, m.w * 0.6)
	sb.modulate_color = mod
	return sb

static func tex_icon(name: String) -> Texture2D:
	return Db.tex(ICON % name)

## Passende Pack-Farbvariante zu einer Farbe
static func variant_for(c: Color) -> String:
	if c.s < 0.18:
		return "cream" if c.v > 0.7 else "black"
	var h := c.h
	if h < 0.04 or h > 0.94: return "red"
	if h < 0.2: return "yellow" if c.v > 0.7 else "cream"
	if h < 0.46: return "green"
	if h < 0.58: return "blue"
	if h < 0.75: return "purple"
	return "pink"

## Allgemeines Panel – wählt je nach Hintergrundfarbe Pergament-Container oder dunkles Farb-Panel.
static func box(bg: Color = PAPER, _border: Color = Color("5a4630"), _border_w: int = 4, _radius: int = 8, margin: int = 12, _shadow: bool = true) -> StyleBox:
	var a := bg.a
	var mod := Color(1, 1, 1, a)
	if bg.get_luminance() > 0.55:
		return sbox("container_cream", margin, mod)
	if bg.s < 0.25:
		return sbox("panel_black", margin, mod)
	var v := variant_for(bg)
	if v == "pink" or v == "cream" or v == "yellow" and bg.v < 0.6:
		v = "black"
	var pname := "panel_" + v
	if not FileAccess.file_exists(SCALED % pname):
		pname = "panel_black"
	return sbox(pname, margin, mod)

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

## Button aus dem Pack (Farbe wählbar). Beim Drücken wird er eingedrückt wie ein Formularstempel.
static func button(text: String, min_size: Vector2 = Vector2(320, 58), font_size: int = 24, accent: Color = PAPER) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.add_theme_font_size_override("font_size", font_size)
	var v := variant_for(accent)
	var dark := v in ["red", "blue", "purple", "black", "green"]
	var fc := Color.WHITE if dark else INK
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", fc)
	b.add_theme_color_override("font_pressed_color", fc)
	b.add_theme_color_override("font_disabled_color", Color(0.7, 0.7, 0.72))
	if dark:
		b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.6))
		b.add_theme_constant_override("outline_size", 4)
	var normal := sbox("btn_" + v, 8)
	var hover_v := "yellow" if v == "cream" else v
	var hover := sbox_new("btn_" + hover_v, 8, Color(1.08, 1.08, 1.08) if v != "cream" else Color.WHITE)
	var pressed := sbox_new("btn_" + v, 8, Color(0.82, 0.82, 0.82))
	pressed.content_margin_top += 4.0
	pressed.content_margin_bottom -= 4.0
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", sbox("btn_black", 8, Color(0.8, 0.8, 0.8)))
	b.add_theme_stylebox_override("focus", hover)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_entered.connect(func(): if not b.disabled: Sfx.play("hover", 1.0, -10.0))
	b.pressed.connect(func(): Sfx.play("click"))
	return b

## Notizbuch-Fenster (Pack-Modal): gibt {root, content} zurück. Titel steht im orangen Kopfbalken.
static func notebook(title: String, size: Vector2, variant: String = "notebook") -> Dictionary:
	var root := Control.new()
	root.custom_minimum_size = size
	root.size = size
	var panel := Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sb := sbox(variant, 10)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(panel)
	var m := _margins(variant)
	var t := label(title, 34, Color("5a2d0c"), HORIZONTAL_ALIGNMENT_CENTER)
	t.position = Vector2(m.x + 20.0, 38.0)
	t.size = Vector2(size.x - 2.0 * m.x - 40.0, 48.0)
	root.add_child(t)
	var content := VBoxContainer.new()
	content.position = Vector2(m.x * 0.35, m.y + 14.0)
	content.size = Vector2(size.x - m.x * 0.7, size.y - m.y - m.w - 22.0)
	content.add_theme_constant_override("separation", 10)
	root.add_child(content)
	return {root = root, content = content, title = t}

## Fortschrittsbalken (HUD): Hintergrund + Füllung proportional, per draw_style_box
static func draw_bar(ci: CanvasItem, rect: Rect2, frac: float, fill: String = "bar_green", ghost: float = -1.0) -> void:
	ci.draw_style_box(sbox("bar_back", 4), rect.grow(3))
	var inner := rect
	if ghost > frac:
		var gw := maxf(rect.size.x * clampf(ghost, 0.0, 1.0), 18.0)
		ci.draw_style_box(sbox("bar_cream", 4, Color(1, 1, 1, 0.8)), Rect2(inner.position, Vector2(gw, inner.size.y)))
	var w := inner.size.x * clampf(frac, 0.0, 1.0)
	if w > 4.0:
		ci.draw_style_box(sbox(fill, 4), Rect2(inner.position, Vector2(maxf(w, 18.0), inner.size.y)))

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

## Zentrales Theme (Buttons, Panels, Label-Farben, Slider). Wird in Main als Root-Theme gesetzt.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button", sbox("btn_cream", 8))
	t.set_stylebox("hover", "Button", sbox_new("btn_yellow", 8))
	t.set_stylebox("pressed", "Button", sbox_new("btn_cream", 8, Color(0.82, 0.82, 0.82)))
	t.set_stylebox("disabled", "Button", sbox("btn_black", 8, Color(0.8, 0.8, 0.8)))
	t.set_stylebox("focus", "Button", sbox("btn_yellow", 8))
	t.set_color("font_color", "Button", INK)
	t.set_color("font_hover_color", "Button", INK)
	t.set_color("font_pressed_color", "Button", INK)
	t.set_color("font_disabled_color", "Button", Color(0.7, 0.7, 0.72))
	t.set_font_size("font_size", "Button", 22)
	t.set_stylebox("panel", "PanelContainer", sbox("container_cream", 14))
	t.set_stylebox("panel", "Panel", sbox("container_cream", 14))
	t.set_color("font_color", "Label", INK)
	t.set_font_size("font_size", "Label", 18)
	t.set_stylebox("slider", "HSlider", sbox("bar_back", 4))
	t.set_stylebox("grabber_area", "HSlider", sbox("bar_green", 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", sbox("bar_green", 4))
	t.set_icon("grabber", "HSlider", load(SCALED % "knob_yellow"))
	t.set_icon("grabber_highlight", "HSlider", load(SCALED % "knob_blue"))
	t.set_icon("grabber_disabled", "HSlider", load(SCALED % "knob_yellow"))
	t.set_stylebox("background", "ProgressBar", sbox("bar_back", 4))
	t.set_stylebox("fill", "ProgressBar", sbox("bar_green", 4))
	t.set_stylebox("slider", "HSlider", sbox("bar_back", 4))
	t.set_stylebox("grabber_area", "HSlider", sbox("bar_green", 4))
	t.set_stylebox("grabber_area_highlight", "HSlider", sbox("bar_green", 4))
	t.set_icon("grabber", "HSlider", load(SCALED % "knob_yellow"))
	t.set_icon("grabber_highlight", "HSlider", load(SCALED % "knob_blue"))
	t.set_icon("grabber_disabled", "HSlider", load(SCALED % "knob_yellow"))
	t.set_stylebox("background", "ProgressBar", sbox("bar_back", 4))
	t.set_stylebox("fill", "ProgressBar", sbox("bar_green", 4))
	t.set_color("font_color", "CheckBox", INK)
	t.set_color("font_hover_color", "CheckBox", INK)
	t.set_color("font_pressed_color", "CheckBox", INK)
	return t
