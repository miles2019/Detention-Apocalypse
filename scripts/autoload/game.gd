extends Node
## GameManager: Spielzustand, Run-Daten, Signale. UI sendet Signale, hier wird der Zustand geändert.

enum State { MAIN_MENU, CHARACTER_SELECT, IN_RUN, WAVE_TRANSITION, LEVEL_UP, SHOP, BOSS_INTRO, PAUSE, RUN_RESULT, HUB }

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
signal cinematic_bars(on: bool)
signal boss_title(name: String, title: String, intro: String)
signal stage_clear
signal station_activated(kind: String)

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
var rule_block := ""            # vom Rektor verhängte Regel: "melee" | "ranged" | ""
var event_mods := {}            # aktive Wellen-Event-Modifikatoren
var chapter := 1
var modal_open := false
var difficulty := 0
var run_won := false
var last_rewards := {}
var stats := {}
var chain := 0
var endless := false
var lv_rerolls := 2
var lv_bans := 2
var lv_locks := 1
var banned: Array = []
var locked_upgrade := ""
var endless_rank := 0
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
	rule_block = ""
	event_mods = {}
	endless = false
	lv_rerolls = 2
	lv_bans = 2
	lv_locks = 1
	banned = []
	locked_upgrade = ""
	endless_rank = 0
	enemies.clear()
	stats = {kills = 0, damage_dealt = 0.0, damage_taken = 0.0, objects_used = 0, dodges = 0,
		max_chain = 0, money_earned = 0, events = 0, flawless = 0, elites = 0, champions = 0, bosses = 0, sold = 0, smashed = 0, revived = false, time = 0.0, crits = 0, synergies = 0, waves = 0}

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
	var cm: float = player.char_data.xp if player != null else 1.0
	v = int(round(float(v) * (1.0 + Save.bonus("xp")) * phase_mod("xp") * cm))
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
		if player != null and arena != null:
			Juice.ring(player.global_position, 200.0, Color(1, 0.9, 0.4), 0.5, 10.0, true)
			Juice.burst(player.global_position, Color(1, 0.9, 0.4), 22, 300.0, 0.9, 4.0, 180.0, Vector2.UP, 200.0, "circle", 30.0)
			Juice.float_text_at(player.global_position, 100.0, "LEVEL UP!", Color(1, 0.9, 0.4), 28, true)
			arena.stage.pulse_light(player.global_position, Color(1, 0.9, 0.5), 2.0, 3.5, 0.4)
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
	Save.add_stat("chain_max", chain)
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
	var v: float = phase_mods.get(key, default)
	if event_mods.has(key):
		v *= event_mods[key]
	return v

func chapter_data() -> Dictionary:
	return Db.chapters[chapter]

## Wellen-Definition (Kapitel oder prozedural im Endlos-Modus)
func wave_def(n: int) -> Dictionary:
	if endless:
		return DbExtra.endless_wave(n)
	var w: Array = Db.chapters[chapter].waves
	return w[clampi(n - 1, 0, w.size() - 1)]

## Gegnerschaden wächst im Endlos-Modus ab Welle 6 langsam mit
func endless_dmg() -> float:
	return (1.0 + 0.04 * float(maxi(0, wave - 5))) if endless else 1.0

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
	_award(won)
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
		if modal_open:
			return
		if state == State.IN_RUN or state == State.WAVE_TRANSITION or state == State.HUB:
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

## Run-Ende: Meta-Belohnungen berechnen, Challenges und Freischaltungen verbuchen, speichern.
func _award(won: bool) -> void:
	var diff_mul := 1.0 + 0.3 * float(difficulty)
	var chap: Dictionary = Db.chapters[chapter]
	var passes := int((float(stats.waves) * 2.0 + float(stats.kills) / 30.0 + (8.0 * chap.reward if won else 0.0)) * diff_mul)
	var marken := int(stats.elites + stats.champions / 3 + (3 if won else 0))
	if endless:
		marken += stats.bosses * 2
		endless_rank = Save.add_endless_score(wave, stats.kills, stats.time, player.char_data.name if player != null else "?")
	var unlocks: Array = []
	Save.data.runs += 1
	Save.data.total_kills += stats.kills
	Save.data.total_dodges += stats.dodges
	Save.data.total_coins += stats.money_earned
	Save.add_stat("kills", stats.kills)
	Save.add_stat("dodges", stats.dodges)
	Save.add_stat("coins", stats.money_earned)
	Save.add_stat("level_max", level)
	var best: Dictionary = Save.data.best
	best.wave = maxi(best.wave, stats.waves)
	best.kills = maxi(best.kills, stats.kills)
	if won:
		Save.data.wins += 1
		best.time = minf(best.time, stats.time)
		Save.data.chapter_clears[str(chapter)] = int(Save.data.chapter_clears.get(str(chapter), 0)) + 1
		Save.add_stat("chapter%d" % chapter, 1)
		if chapter < 3 and not Save.chapter_unlocked(chapter + 1):
			Save.unlock_chapter(chapter + 1)
			unlocks.append("Kapitel %d freigeschaltet: %s" % [chapter + 1, Db.chapters[chapter + 1].name])
	Save.data.passes += passes
	Save.data.marken += marken
	last_rewards = {passes = passes, marken = marken, unlocks = unlocks}
	Save.save_game()
