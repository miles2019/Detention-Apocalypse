extends Node
## GameManager: Spielzustand, Run-Daten, Signale. UI sendet Signale, hier wird der Zustand geändert.

enum State { MAIN_MENU, CHARACTER_SELECT, IN_RUN, WAVE_TRANSITION, LEVEL_UP, SHOP, BOSS_INTRO, PAUSE, RUN_RESULT }

signal state_changed(old_state: int, new_state: int)
signal money_changed(value: int)
signal xp_changed(xp: int, need: int, level: int)
signal levelup_requested
signal wave_changed(wave: int, total: int)
signal wave_progress(alive: int, remaining: int)
signal phase_changed(phase_id: String)
signal announce(text: String, kind: String)
signal stamp_requested(text: String, color: Color)
signal chain_event(count: int)
signal player_hurt
signal run_ended(won: bool)
signal inventory_changed
signal boss_changed(hp: float, max_hp: float, active: bool)
signal synergy_changed(subject: String, count: int)

const TOTAL_WAVES := 5
const PAUSING_STATES := [State.LEVEL_UP, State.SHOP, State.BOSS_INTRO, State.PAUSE, State.RUN_RESULT]

var state: int = State.MAIN_MENU
var state_before_pause: int = State.IN_RUN
var levelup_return: int = State.IN_RUN
var player: Node = null
var arena: Node = null
var enemies: Array = []
var money := 0
var xp := 0
var level := 1
var wave := 0
var phase_id := ""
var phase_mods := {}
var pending_levelups := 0
var god_mode := false
var run_won := false
var stats := {}
var chain := 0
var _last_kill_ms := 0
var settings := {master = 0.8, music = 0.55, sfx = 0.9, voice = 0.9, shake = 1.0, ui_scale = 1.0, reduced_motion = false}
const ACTIONS := {
	move_left = "Links", move_right = "Rechts", move_up = "Hoch", move_down = "Runter",
	interact = "Interagieren", dash = "Ausweichen",
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	load_settings()
	reset_run()

# ---------------------------------------------------------------- Eingaben
func _setup_input() -> void:
	var defaults := {
		move_left = [KEY_A, KEY_LEFT], move_right = [KEY_D, KEY_RIGHT],
		move_up = [KEY_W, KEY_UP], move_down = [KEY_S, KEY_DOWN],
		interact = [KEY_E], dash = [KEY_SPACE, KEY_SHIFT], pause = [KEY_ESCAPE],
	}
	for a in defaults:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.25)
		for k in defaults[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_joy_button("interact", JOY_BUTTON_X)
	_joy_button("dash", JOY_BUTTON_A)
	_joy_button("pause", JOY_BUTTON_START)
	for a in ["aim_left", "aim_right", "aim_up", "aim_down"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a, 0.25)
	_joy_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_joy_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_joy_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_joy_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)

func _joy_axis(action: String, axis: int, value: float) -> void:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)

func _joy_button(action: String, btn: int) -> void:
	var ev := InputEventJoypadButton.new()
	ev.button_index = btn
	InputMap.action_add_event(action, ev)

func rebind(action: String, event: InputEventKey) -> void:
	# Ersetzt alle Tastatur-Events der Aktion durch das neue
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			InputMap.action_erase_event(action, e)
	var ev := InputEventKey.new()
	ev.physical_keycode = event.physical_keycode
	InputMap.action_add_event(action, ev)
	save_settings()

func key_label(action: String) -> String:
	for e in InputMap.action_get_events(action):
		if e is InputEventKey:
			return OS.get_keycode_string(e.physical_keycode)
	return "-"

# ---------------------------------------------------------------- Settings
func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("user://settings.cfg") != OK:
		return
	for k in settings:
		settings[k] = cfg.get_value("settings", k, settings[k])
	for a in ACTIONS:
		var code: int = cfg.get_value("keys", a, 0)
		if code != 0:
			var ev := InputEventKey.new()
			ev.physical_keycode = code
			for e in InputMap.action_get_events(a):
				if e is InputEventKey:
					InputMap.action_erase_event(a, e)
			InputMap.action_add_event(a, ev)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	for k in settings:
		cfg.set_value("settings", k, settings[k])
	for a in ACTIONS:
		for e in InputMap.action_get_events(a):
			if e is InputEventKey:
				cfg.set_value("keys", a, e.physical_keycode)
				break
	cfg.save("user://settings.cfg")

# ---------------------------------------------------------------- Run
func reset_run() -> void:
	money = 0
	xp = 0
	level = 1
	wave = 0
	phase_id = ""
	phase_mods = {}
	pending_levelups = 0
	chain = 0
	run_won = false
	enemies.clear()
	stats = {kills = 0, damage_dealt = 0.0, damage_taken = 0.0, objects_used = 0, dodges = 0,
		max_chain = 0, money_earned = 0, time = 0.0, crits = 0, hides = 0, synergies = 0, waves = 0}

func xp_needed(lv: int = -1) -> int:
	if lv < 0:
		lv = level
	return 14 + lv * 9

func add_money(v: int) -> void:
	money += v
	if v > 0:
		stats.money_earned += v
	money_changed.emit(money)

func spend_money(v: int) -> bool:
	if money < v:
		return false
	money -= v
	money_changed.emit(money)
	return true

func add_xp(v: int) -> void:
	xp += v
	while xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		pending_levelups += 1
	xp_changed.emit(xp, xp_needed(), level)
	_check_levelup()

func _check_levelup() -> void:
	if pending_levelups > 0 and (state == State.IN_RUN or state == State.WAVE_TRANSITION):
		levelup_return = state
		change_state(State.LEVEL_UP)
		levelup_requested.emit()

func register_kill() -> void:
	stats.kills += 1
	var now := Time.get_ticks_msec()
	if now - _last_kill_ms < 900:
		chain += 1
	else:
		chain = 1
	_last_kill_ms = now
	stats.max_chain = max(stats.max_chain, chain)
	if chain >= 2:
		chain_event.emit(chain)

func nearest_enemy(pos: Vector2, max_dist: float = 99999.0, exclude: Array = []) -> Node:
	var best: Node = null
	var bd := max_dist
	for e in enemies:
		if not is_instance_valid(e) or e.dead or exclude.has(e):
			continue
		var d: float = pos.distance_to(e.global_position)
		if d < bd:
			bd = d
			best = e
	return best

func phase_mod(key: String, default: float = 1.0) -> float:
	return phase_mods.get(key, default)

func change_state(s: int) -> void:
	if s == state:
		return
	var old := state
	state = s
	get_tree().paused = PAUSING_STATES.has(s)
	state_changed.emit(old, s)
	if s == State.IN_RUN:
		_check_levelup()

func end_run(won: bool) -> void:
	if state == State.RUN_RESULT:
		return
	run_won = won
	pending_levelups = 0
	run_ended.emit(won)
	change_state(State.RUN_RESULT)

func set_phase(id: String) -> void:
	phase_id = id
	phase_mods = Db.phases[id].mods if Db.phases.has(id) else {}
	phase_changed.emit(id)

# ---------------------------------------------------------------- Eingabe global
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if state == State.IN_RUN or state == State.WAVE_TRANSITION:
			state_before_pause = state
			change_state(State.PAUSE)
		elif state == State.PAUSE:
			change_state(state_before_pause)
		return
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo and player != null:
		match event.keycode:
			KEY_F1: add_money(50)
			KEY_F2: add_xp(xp_needed())
			KEY_F3:
				for e in enemies.duplicate():
					if is_instance_valid(e) and not e.dead and e.data.behavior != "boss":
						e.take_hit(9999.0, Vector2.RIGHT, 100.0, false)
			KEY_F4: god_mode = not god_mode
			KEY_F5: player.debug_give_evolution()
