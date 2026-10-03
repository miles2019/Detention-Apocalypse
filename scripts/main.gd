extends Node
## Main: verbindet UI-Screens mit den Spielzuständen aus Game. UI sendet Signale, Game ändert den Zustand.
## Ablauf: Hauptmenü -> Schulhof (HUB) -> Direktorenschild -> Run -> Zeugnis -> Schulhof.

var world: Node
var ui: CanvasLayer
var hud: HUD
var hubhud: HubHUD
var menu: MainMenu
var charsel: CharSelect
var settings: SettingsScreen
var levelup: LevelUpScreen
var shop: ShopScreen
var pause: PauseScreen
var result: ResultScreen
var evo: EvolutionOverlay
var skills: SkillScreen
var workbench: WorkbenchScreen
var board: BoardScreen
var ags: AGScreen
var director: DirectorScreen
var stats: StatsScreen
var tooltip: Tooltip
var _stats_resume := false
var arena: Arena
var stage: Stage3D
var _pending_recipe := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.content_scale_factor = Game.settings.get("ui_scale", 1.0)
	var kaph: Font = load("res://assets/fonts/Kaph-Regular.ttf")
	ThemeDB.fallback_font = kaph
	get_tree().root.theme = UIKit.make_theme()
	world = Node.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	hud = HUD.new()
	add_child(hud)
	hubhud = HubHUD.new()
	add_child(hubhud)
	ui = CanvasLayer.new()
	ui.layer = 10
	add_child(ui)
	menu = MainMenu.new()
	charsel = CharSelect.new()
	shop = ShopScreen.new()
	levelup = LevelUpScreen.new()
	pause = PauseScreen.new()
	result = ResultScreen.new()
	settings = SettingsScreen.new()
	evo = EvolutionOverlay.new()
	skills = SkillScreen.new()
	workbench = WorkbenchScreen.new()
	board = BoardScreen.new()
	ags = AGScreen.new()
	director = DirectorScreen.new()
	stats = StatsScreen.new()
	for s in [menu, charsel, shop, levelup, pause, result, settings, evo, skills, workbench, board, ags, director, stats]:
		ui.add_child(s)
		s.visible = false
	tooltip = Tooltip.new()
	add_child(tooltip)
	UIKit.tooltip = tooltip
	stats.closed.connect(_on_stats_closed)
	shop.stats_requested.connect(_open_stats)
	pause.stats_pressed.connect(_open_stats)
	menu.start_pressed.connect(_enter_hub)
	menu.settings_pressed.connect(func(): settings.visible = true)
	menu.quit_pressed.connect(func(): get_tree().quit())
	charsel.back_pressed.connect(_close_charsel)
	charsel.confirmed.connect(_on_char_confirmed)
	settings.closed.connect(func(): settings.visible = false)
	levelup.chosen.connect(_on_upgrade_chosen)
	shop.closed.connect(_on_shop_closed)
	shop.evolution_requested.connect(_on_evolution)
	evo.finished.connect(_on_evolution_done)
	pause.resume_pressed.connect(func(): Game.change_state(Game.state_before_pause))
	pause.settings_pressed.connect(func(): settings.visible = true)
	pause.quit_to_menu_pressed.connect(_on_pause_quit)
	result.restart_pressed.connect(_start_run)
	result.menu_pressed.connect(_enter_hub)
	director.start_requested.connect(_start_from_director)
	Game.station_activated.connect(_on_station)
	Game.state_changed.connect(_on_state)
	Game.levelup_requested.connect(func(): levelup.open())
	Game.run_ended.connect(func(won: bool): result.open(won))
	_on_state(-1, Game.state)
	if OS.get_cmdline_user_args().has("--autotest"):
		var at: GDScript = load("res://scripts/autotest.gd")
		var node: Node = at.new()
		node.main = self
		add_child(node)

func _on_state(_old: int, s: int) -> void:
	var S := Game.State
	menu.visible = s == S.MAIN_MENU
	if s != S.HUB or not Game.modal_open:
		charsel.visible = s == S.CHARACTER_SELECT or (charsel.visible and s == S.HUB and Game.modal_open)
	shop.visible = s == S.SHOP
	levelup.visible = s == S.LEVEL_UP
	pause.visible = s == S.PAUSE
	result.visible = s == S.RUN_RESULT
	hud.visible = s in [S.IN_RUN, S.WAVE_TRANSITION, S.BOSS_INTRO, S.LEVEL_UP] or (s == S.PAUSE and Game.state_before_pause != S.HUB)
	hubhud.visible = s == S.HUB or (s == S.PAUSE and Game.state_before_pause == S.HUB)
	if s != S.PAUSE and s != S.MAIN_MENU:
		settings.visible = false
	if s != S.PAUSE and s != S.SHOP:
		stats.visible = false
		_stats_resume = false
	match s:
		S.MAIN_MENU, S.CHARACTER_SELECT, S.HUB:
			Sfx.play_music("menu")
		S.SHOP:
			Sfx.play_music("menu")
			shop.open()
		S.IN_RUN, S.BOSS_INTRO, S.WAVE_TRANSITION:
			Sfx.play_music("run")
		S.RUN_RESULT:
			Sfx.stop_music()
		S.PAUSE:
			pause.set_quit_text("Run abbrechen" if Game.state_before_pause != S.HUB else "Zum Hauptmenü")
	var playing := s == S.IN_RUN or s == S.WAVE_TRANSITION
	if not playing:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _free_world() -> void:
	if arena != null and is_instance_valid(arena):
		arena.queue_free()
		arena = null
	if stage != null and is_instance_valid(stage):
		stage.queue_free()
		stage = null

## Schulhof betreten (Hub): begehbare Arena mit Stationen
func _enter_hub() -> void:
	HitStop.reset()
	_free_world()
	Game.modal_open = false
	get_tree().paused = false
	Game.reset_run()
	Game.player = null
	Game.chapter = 0
	Game.difficulty = 0
	stage = Stage3D.new()
	world.add_child(stage)
	arena = Arena.new()
	arena.stage = stage
	arena.hub_mode = true
	stage.ground.add_child(arena)
	Game.boss_changed.emit(0.0, 1.0, false)
	Game.change_state(Game.State.HUB)

func _start_from_director() -> void:
	Game.chapter = int(Save.data.chapter_selected)
	Game.difficulty = int(Save.data.difficulty)
	Game.endless = bool(Save.data.endless)
	_start_run()

func _start_run() -> void:
	if Game.chapter < 1:
		Game.chapter = 1
	var keep_chapter := Game.chapter
	var keep_diff := Game.difficulty
	var keep_endless := Game.endless
	_free_world()
	HitStop.reset()
	Game.modal_open = false
	Game.reset_run()
	Game.chapter = keep_chapter
	Game.difficulty = keep_diff
	Game.endless = keep_endless
	Game.player = null
	stage = Stage3D.new()
	world.add_child(stage)
	arena = Arena.new()
	arena.stage = stage
	stage.ground.add_child(arena)
	hud.reset()
	Game.money_changed.emit(Game.money)
	Game.xp_changed.emit(0, Game.xp_needed(), 1)
	arena.start_next_wave()

func _on_pause_quit() -> void:
	if Game.state_before_pause == Game.State.HUB:
		HitStop.reset()
		_free_world()
		Game.change_state(Game.State.MAIN_MENU)
	else:
		# Run abbrechen: Zeugnis mit bisherigen Belohnungen
		Game.state_before_pause = Game.State.IN_RUN
		Game.end_run(false)

func _on_station(kind: String) -> void:
	if Game.modal_open:
		return
	match kind:
		"skills": skills.open()
		"workbench": workbench.open()
		"board": board.open()
		"ag": ags.open()
		"director": director.open()
		"photo":
			Game.modal_open = true
			get_tree().paused = true
			charsel.visible = true

func _close_charsel() -> void:
	if Game.state == Game.State.HUB:
		charsel.visible = false
		Game.modal_open = false
		get_tree().paused = false
	else:
		Game.change_state(Game.State.MAIN_MENU)

## Schülerakte öffnen (Tab, Pausemenü, Kiosk). Im laufenden Kampf wird dafür pausiert.
func _open_stats() -> void:
	if stats.visible or Game.player == null:
		return
	var S := Game.State
	if Game.state == S.IN_RUN or Game.state == S.WAVE_TRANSITION:
		_stats_resume = true
		Game.state_before_pause = Game.state
		Game.change_state(S.PAUSE)
	elif Game.state != S.PAUSE and Game.state != S.SHOP:
		return
	if Game.state == S.PAUSE and Game.state_before_pause == S.HUB:
		return
	stats.open()

func _on_stats_closed() -> void:
	if _stats_resume:
		_stats_resume = false
		if Game.state == Game.State.PAUSE:
			Game.change_state(Game.state_before_pause)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_TAB:
		if not stats.visible and not settings.visible and not evo.visible:
			_open_stats()
			get_viewport().set_input_as_handled()

func _on_char_confirmed(_id: String) -> void:
	if Game.state == Game.State.HUB:
		_close_charsel()
		# Schulhof neu betreten, damit die gewählte Figur erscheint
		_enter_hub()
		if Game.player != null:
			Juice.float_text_at(Game.player.global_position, 90.0, "ANWESEND!", Color(0.5, 1.0, 0.6), 24, true)
	else:
		_start_run()

func _on_upgrade_chosen(id: String) -> void:
	if Game.state != Game.State.LEVEL_UP:
		return
	if Game.player != null:
		Game.player.apply_upgrade(id)
		Sfx.play("levelup", 1.3, -4.0)
	Game.pending_levelups = maxi(0, Game.pending_levelups - 1)
	if Game.pending_levelups > 0:
		levelup.open()
	else:
		Game.change_state(Game.levelup_return)

func _on_shop_closed() -> void:
	if arena != null and is_instance_valid(arena):
		arena.after_shop()

func _on_evolution(recipe: Dictionary) -> void:
	_pending_recipe = recipe
	evo.play(recipe)
	Juice.shake(0.2)

func _on_evolution_done() -> void:
	if not _pending_recipe.is_empty() and Game.player != null:
		Game.player.evolve(_pending_recipe)
		Game.stamp_requested.emit("Evolution genehmigt", UIKit.RED)
	_pending_recipe = {}
	shop.evolution_done()
