class_name Tooltip
extends CanvasLayer
## Hover-Infokarte für Waffen, Items, Werte und Sets. Registrierung über UIKit.tip(control, titel, text).

var _panel: PanelContainer
var _title: Label
var _body: Label
var _owner: Control

func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UIKit.sbox("panel_black", 12))
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(v)
	_title = UIKit.label("", 18, UIKit.GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	v.add_child(_title)
	_body = UIKit.label("", 14, Color(0.95, 0.94, 0.88))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(330, 0)
	v.add_child(_body)

func show_tip(c: Control, title: String, body: String) -> void:
	_owner = c
	_title.text = title
	_title.visible = title != ""
	_body.text = body
	_panel.visible = true
	_panel.reset_size()
	_place()

func hide_tip(c: Control) -> void:
	if _owner == c:
		_owner = null
		_panel.visible = false

func _place() -> void:
	var vs := get_viewport().get_visible_rect().size
	var m := get_viewport().get_mouse_position()
	var sz := _panel.size
	var p := m + Vector2(20, 18)
	if p.x + sz.x > vs.x - 8.0:
		p.x = m.x - sz.x - 16.0
	if p.y + sz.y > vs.y - 8.0:
		p.y = vs.y - sz.y - 8.0
	_panel.position = Vector2(maxf(8.0, p.x), maxf(8.0, p.y))

func _process(_delta: float) -> void:
	if not _panel.visible:
		return
	if _owner == null or not is_instance_valid(_owner) or not _owner.is_visible_in_tree() \
			or not _owner.get_global_rect().has_point(_owner.get_global_mouse_position()):
		_owner = null
		_panel.visible = false
		return
	_panel.reset_size()
	_place()
