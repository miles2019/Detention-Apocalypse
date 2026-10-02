extends Node
## Main: verbindet UI-Screens mit den Spielzuständen aus Game. UI sendet Signale, Game ändert den Zustand.

var world: Node
var ui: CanvasLayer
var hud: HUD
var menu: MainMenu
var charsel: CharSelect
var settings: SettingsScreen
var levelup: LevelUpScreen
var shop: ShopScreen
var pause: PauseScreen
var result: ResultScreen
var evo: EvolutionOverlay
var arena: Arena
var stage: Stage3D
var _pending_recipe := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.content_scale_factor = Game.settings.get("ui_scale", 1.0)
	world = Node.new()
	world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(world)
	hud = HUD.new()
	add_child(hud)
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
	for s in [menu, charsel, shop, levelup, pause, result, settings, evo]:
		ui.add_child(s)
		s.visible = false
	menu.start_pressed.connect(func(): Game.change_state(Game.State.CHARACTER_SELECT))
	menu.settings_pressed.connect(func(): settings.visible = true)
	menu.quit_pressed.connect(func(): get_tree().quit())
	charsel.back_pressed.connect(func(): Game.change_state(Game.State.MAIN_MENU))
	charsel.confirmed.connect(func(_id): _start_run())
	settings.closed.connect(func(): settings.visible = false)
	levelup.chosen.connect(_on_upgrade_chosen)
	shop.closed.connect(_on_shop_closed)
	shop.evolution_requested.connect(_on_evolution)
	evo.finished.connect(_on_evolution_done)
	pause.resume_pressed.connect(func(): Game.change_state(Game.state_before_pause))
	pause.settings_pressed.connect(func(): settings.visible = true)
	pause.quit_to_menu_pressed.connect(_to_menu)
	result.restart_pressed.connect(_start_run)
	result.menu_pressed.connect(_to_menu)
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
	charsel.visible = s == S.CHARACTER_SELECT
	shop.visible = s == S.SHOP
	levelup.visible = s == S.LEVEL_UP
	pause.visible = s == S.PAUSE
	result.visible = s == S.RUN_RESULT
	hud.visible = s in [S.IN_RUN, S.WAVE_TRANSITION, S.BOSS_INTRO, S.LEVEL_UP, S.PAUSE]
	if s != S.PAUSE and s != S.MAIN_MENU:
		settings.visible = false
	match s:
		S.MAIN_MENU, S.CHARACTER_SELECT:
			Sfx.play_music("menu")
		S.SHOP:
			Sfx.play_music("menu")
			shop.open()
		S.IN_RUN, S.BOSS_INTRO, S.WAVE_TRANSITION:
			Sfx.play_music("run")
		S.RUN_RESULT:
			Sfx.stop_music()
	if s != S.IN_RUN and s != S.WAVE_TRANSITION:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _free_world() -> void:
	if arena != null and is_instance_valid(arena):
		arena.queue_free()
		arena = null
	if stage != null and is_instance_valid(stage):
		stage.queue_free()
		stage = null

func _start_run() -> void:
	_free_world()
	HitStop.reset()
	Game.reset_run()
	Game.player = null
	stage = Stage3D.new()
	world.add_child(stage)
	arena = Arena.new()
	arena.stage = stage
	stage.ground.add_child(arena)
	hud.reset()
	Game.money_changed.emit(0)
	Game.xp_changed.emit(0, Game.xp_needed(), 1)
	arena.start_next_wave()

func _to_menu() -> void:
	HitStop.reset()
	_free_world()
	Game.boss_changed.emit(0.0, 1.0, false)
	Game.change_state(Game.State.MAIN_MENU)

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
