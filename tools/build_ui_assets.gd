extends SceneTree
## Einmal-Werkzeug: skaliert die großen Vector-UI-Pack-Texturen auf spielgerechte Größe (für 9-Patch-Styleboxen)
## und erzeugt resources/ui_theme.tres.
## Ausführen:  godot --headless --path . --script res://tools/build_ui_assets.gd

const SRC := "res://assets/ui/"
const OUT := "res://assets/ui/scaled/"

# name: [Quelle, Skalierung, Rand links, oben, rechts, unten (in skalierten Pixeln)]
const SPECS := {
	"btn_cream": ["Buttons/button_cream.png", 0.30, 17, 17, 17, 20],
	"btn_yellow": ["Buttons/button_yellow.png", 0.30, 17, 17, 17, 20],
	"btn_green": ["Buttons/button_green.png", 0.30, 17, 17, 17, 20],
	"btn_red": ["Buttons/button_red.png", 0.30, 17, 17, 17, 20],
	"btn_blue": ["Buttons/button_blue.png", 0.30, 17, 17, 17, 20],
	"btn_pink": ["Buttons/button_pink.png", 0.30, 17, 17, 17, 20],
	"btn_purple": ["Buttons/button_purple.png", 0.30, 17, 17, 17, 20],
	"btn_cyan": ["Buttons/button_cyan.png", 0.30, 17, 17, 17, 20],
	"btn_white": ["Buttons/button_white.png", 0.30, 17, 17, 17, 20],
	"btn_black": ["Buttons/button_black.png", 0.30, 17, 17, 17, 20],
	"container_cream": ["Containers/container_default.png", 0.32, 16, 16, 16, 18],
	"card_cream": ["Cards/card_cream.png", 0.5, 16, 40, 16, 16],
	"card_shop": ["Cards/cardShop_default.png", 0.4, 16, 16, 16, 20],
	"panel_blue": ["Panels/panel_blue.png", 0.4, 8, 16, 8, 16],
	"panel_black": ["Panels/panel_black.png", 0.4, 8, 16, 8, 16],
	"panel_red": ["Panels/panel_red.png", 0.4, 8, 16, 8, 16],
	"panel_green": ["Panels/panel_green.png", 0.4, 8, 16, 8, 16],
	"panel_yellow": ["Panels/panel_yellow.png", 0.4, 8, 16, 8, 16],
	"panel_purple": ["Panels/panel_purple.png", 0.4, 8, 16, 8, 16],
	"panel_cream": ["Panels/panel_cream.png", 0.4, 8, 16, 8, 16],
	"notebook": ["Modals/notebookModal_v1.png", 0.45, 100, 96, 100, 30],
	"notebook2": ["Modals/notebookModal_v2.png", 0.45, 100, 96, 100, 30],
	"modal_dark": ["Modals/modal_base.png", 0.45, 24, 72, 24, 30],
	"modal_simple": ["Modals/modalSimple_v2.png", 0.45, 100, 96, 100, 30],
	"slot_blue": ["ItemSlots/itemSlot_blue.png", 0.4, 18, 18, 18, 22],
	"slot_yellow": ["ItemSlots/itemSlot_yellow.png", 0.4, 18, 18, 18, 22],
	"slot_green": ["ItemSlots/itemSlot_green.png", 0.4, 18, 18, 18, 22],
	"slot_red": ["ItemSlots/itemSlot_red.png", 0.4, 18, 18, 18, 22],
	"slot_purple": ["ItemSlots/itemSlot_purple.png", 0.4, 18, 18, 18, 22],
	"bar_back": ["ProgressBars/progressBarBase_black.png", 0.3, 12, 12, 12, 12],
	"bar_green": ["ProgressBars/progressBar_green.png", 0.3, 9, 9, 9, 9],
	"bar_red": ["ProgressBars/progressBar_red.png", 0.3, 9, 9, 9, 9],
	"bar_blue": ["ProgressBars/progressBar_blue.png", 0.3, 9, 9, 9, 9],
	"bar_cyan": ["ProgressBars/progressBar_cyan.png", 0.3, 9, 9, 9, 9],
	"bar_cream": ["ProgressBars/progressBar_cream.png", 0.3, 9, 9, 9, 9],
	"header_blue": ["Headers/header_blue.png", 0.32, 20, 20, 20, 22],
	"header_red": ["Headers/header_red.png", 0.32, 20, 20, 20, 22],
	"header_cream": ["Headers/header_cream.png", 0.32, 20, 20, 20, 22],
	"label_wood": ["Labels/wood_label.png", 0.3, 20, 20, 20, 20],
	"knob_yellow": ["Buttons/buttonCircle_yellow.png", 0.13, 8, 8, 8, 8],
	"knob_blue": ["Buttons/buttonCircle_blue.png", 0.13, 8, 8, 8, 8],
}

func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for n in SPECS:
		var s: Array = SPECS[n]
		var path: String = SRC + s[0]
		if not FileAccess.file_exists(path):
			print("FEHLT: ", path)
			continue
		var tex: Texture2D = load(path)
		var img: Image = tex.get_image()
		if img.is_compressed():
			img.decompress()
		img.resize(int(img.get_width() * s[1]), int(img.get_height() * s[1]), Image.INTERPOLATE_LANCZOS)
		img.save_png(OUT + n + ".png")
		print("ok ", n, " ", img.get_width(), "x", img.get_height())
	quit()
