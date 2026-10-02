class_name HubHUD
extends CanvasLayer
## Schulhof-Anzeige: Währungen, Steuerungshinweis, Willkommensbanner.

var _c: Control
var _t := 0.0

func _ready() -> void:
	layer = 5
	process_mode = Node.PROCESS_MODE_ALWAYS
	_c = Control.new()
	UIKit.full(_c)
	_c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_c.draw.connect(_draw_hud)
	add_child(_c)

func _process(delta: float) -> void:
	if visible:
		_t += delta
		_c.queue_redraw()

func _txt(pos: Vector2, text: String, size: int, color: Color = Color.WHITE) -> void:
	var f := ThemeDB.fallback_font
	_c.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(3, size / 5), Color(0.05, 0.05, 0.1))
	_c.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _draw_hud() -> void:
	var c := _c
	c.draw_style_box(UIKit.sbox("panel_blue", 10), Rect2(14, 14, 330, 92))
	c.draw_texture_rect(UIKit.tex_icon("coins"), Rect2(26, 22, 36, 36), false)
	_txt(Vector2(72, 48), "Fehlstunden-Pässe: %d" % Save.data.passes, 20, Color(1, 0.92, 0.5))
	c.draw_texture_rect(UIKit.tex_icon("gem"), Rect2(26, 60, 36, 36), false)
	_txt(Vector2(72, 86), "Nachsitzen-Marken: %d" % Save.data.marken, 20, Color(0.7, 0.95, 1.0))
	# Titel
	_txt(Vector2(520, 44), "Schulhof", 34, Color("fff1c8"))
	# Hinweisleiste
	var hint := Rect2(290, 674, 700, 36)
	c.draw_style_box(UIKit.sbox("panel_black", 8, Color(1, 1, 1, 0.85)), hint)
	var f := ThemeDB.fallback_font
	c.draw_string(f, Vector2(hint.position.x + 20, hint.position.y + 25), "WASD: Bewegen   ·   %s: Ausweichen   ·   %s: Interagieren   ·   Esc: Pause" % [Game.key_label("dash"), Game.key_label("interact")], HORIZONTAL_ALIGNMENT_LEFT, 680, 15, Color(0.9, 0.92, 1.0))
	if Save.data.runs == 0:
		var pulse := 0.5 + 0.5 * sin(_t * 4.0)
		_txt(Vector2(380, 640), "Willkommen! Geh zum Direktorenschild, um zu starten.", 20, Color(1.0, 0.9, 0.4, 0.7 + pulse * 0.3))
