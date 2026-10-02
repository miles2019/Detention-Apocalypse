extends Node
## Entwickler-Bot (nur mit "-- --autotest"): spielt den Run automatisch durch, loggt und speichert Screenshots.
## Nutzung: godot --path . -- --autotest --god --speed=3 --shots=C:/tmp/shots [--boss] [--evo]

var main: Node
var shots_dir := ""
var god := false
var boss_only := false
var evo_test := false
var ui_test := false
var locker_test := false
var hub_test := false
var start_weapon := ""
var proj_shots := false
var _proj_cd := 0.0
var _hub_i := 0
var _hub_t := 0.0
var chapter_arg := 1
var weapons_test := false
var event_arg := ""
var _wp_idx := 0
var _wp_t := 0.0
var _lk: Node = null
var again := false
var _ui_step := 0
var _again_done := false
var _t := 0.0
var _state_t := 0.0
var _last_state := -1
var _shot_t := 0.0
var _log_t := 0.0
var _shot_n := 0
var _acted := false
var _dash_t := 2.0
var _total := 0.0
var _max_time := 900.0
var _logged_wave := -1

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			shots_dir = a.substr(8)
		elif a == "--god":
			god = true
		elif a == "--boss":
			boss_only = true
		elif a == "--evo":
			evo_test = true
		elif a.begins_with("--chapter="):
			chapter_arg = int(a.substr(10))
		elif a == "--weapons":
			weapons_test = true
		elif a.begins_with("--event="):
			event_arg = a.substr(8)
		elif a.begins_with("--start="):
			start_weapon = a.substr(8)
		elif a == "--proj":
			proj_shots = true
		elif a == "--hub":
			hub_test = true
		elif a == "--locker":
			locker_test = true
		elif a == "--ui":
			ui_test = true
		elif a == "--again":
			again = true
		elif a.begins_with("--speed="):
			Engine.time_scale = float(a.substr(8))
		elif a.begins_with("--max="):
			_max_time = float(a.substr(6))
	if shots_dir != "":
		DirAccess.make_dir_recursive_absolute(shots_dir)
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("[AUTOTEST] gestartet god=%s boss=%s evo=%s" % [god, boss_only, evo_test])

func shot(tag: String) -> void:
	if shots_dir == "":
		return
	_shot_n += 1
	var img := get_viewport().get_texture().get_image()
	img.save_png("%s/%02d_%s.png" % [shots_dir, _shot_n, tag])
	print("[AUTOTEST] screenshot %s" % tag)

func _process(delta: float) -> void:
	var real_delta := delta / maxf(0.01, Engine.time_scale)
	_total += real_delta
	if _total > _max_time:
		print("[AUTOTEST] Zeitlimit erreicht")
		get_tree().quit()
		return
	if Game.state != _last_state:
		print("[AUTOTEST] Zustand -> %d (Welle %d, HP %s)" % [Game.state, Game.wave, str(Game.player.hp) if Game.player else "-"])
		_last_state = Game.state
		_state_t = 0.0
		_acted = false
		_release_all()
	_state_t += real_delta
	var S := Game.State
	match Game.state:
		S.MAIN_MENU:
			if _state_t > 1.2 and not _acted:
				_acted = true
				shot("menu")
				if hub_test:
					Save.data.passes = 60
					Save.data.marken = 12
					main._enter_hub()
				else:
					Game.change_state(S.CHARACTER_SELECT)
		S.CHARACTER_SELECT:
			if _state_t > 0.8 and not _acted:
				_acted = true
				shot("charselect")
				Game.chapter = chapter_arg
				if start_weapon != "":
					Save.data.start_weapon = start_weapon
				main._start_run()
				if god:
					Game.god_mode = true
				if event_arg != "":
					Game.arena.events.schedule_now(event_arg)
				if god:
					Game.god_mode = true
				if boss_only:
					Game.arena.director.active = false
					Game.arena.director.queue.clear()
					for e in Game.enemies.duplicate():
						e.queue_free()
					Game.enemies.clear()
					Game.wave = 5
					Game.player.equip("water")
					Game.player.equip("blowpipe")
					Game.arena.start_boss_intro()
		S.HUB:
			_hub(real_delta)
		S.IN_RUN, S.WAVE_TRANSITION, S.BOSS_INTRO:
			_play(real_delta)
		S.LEVEL_UP:
			if _state_t > 0.7 and not _acted:
				_acted = true
				shot("levelup")
				main.levelup._pick(randi() % 3)
		S.SHOP:
			_shop()
		S.PAUSE:
			if ui_test and _ui_step == 1 and _state_t > 0.8:
				_ui_step = 2
				shot("pause")
				main.settings.visible = true
				get_tree().create_timer(0.6, true, false, true).timeout.connect(func():
					shot("settings")
					main.settings.visible = false
					Game.change_state(Game.state_before_pause))
		S.RUN_RESULT:
			if _state_t > 3.5 and not _acted:
				_acted = true
				shot("result")
				print("[AUTOTEST] Ende. Gewonnen=%s Stats=%s" % [Game.run_won, str(Game.stats)])
				if again and not _again_done:
					_again_done = true
					_total = _max_time - 25.0
					main.result.restart_pressed.emit()
					return
				get_tree().create_timer(0.5, true, false, true).timeout.connect(func(): get_tree().quit())

func _hub(delta: float) -> void:
	if not hub_test:
		return
	_hub_t += delta
	var kinds := ["skills", "workbench", "board", "ag", "director"]
	var modals := [main.skills, main.workbench, main.board, main.ags, main.director]
	if _hub_i == 0 and _hub_t > 1.8:
		shot("hub")
		_hub_i = 1
		_hub_t = 0.0
		return
	if _hub_i >= 1 and _hub_i <= kinds.size():
		var idx := _hub_i - 1
		if not Game.modal_open and _hub_t > 0.6:
			main._on_station(kinds[idx])
			_hub_t = 0.0
		elif Game.modal_open and _hub_t > 1.0:
			shot("hub_" + kinds[idx])
			if idx == 4:
				Save.data.chapter_selected = chapter_arg
				if god:
					Game.god_mode = true
				main.director.start_requested.emit()
				main.director.close()
				_hub_i = 99
				if boss_only:
					pass
				return
			modals[idx].close()
			_hub_i += 1
			_hub_t = 0.0

func _shop() -> void:
	if _state_t > 0.9 and not _acted:
		_acted = true
		shot("shop_wave%d" % Game.wave)
		if evo_test and Game.wave == 1:
			Game.player.debug_give_evolution()
			var r: Dictionary = Game.player.check_evolution()
			print("[AUTOTEST] Evolution-Rezept: ", r)
			Game.add_money(100)
			main.shop.evolution_requested.emit(r)
			for dt in [0.9, 1.9, 3.0, 4.2]:
				get_tree().create_timer(dt * Engine.time_scale / 3.0 + 0.0, true, false, true).timeout.connect(func(): shot("evo"))
			return
		Game.add_money(30)
		for i in 4:
			if i < main.shop._offers.size():
				main.shop._buy(i)
		get_tree().create_timer(1.8, true, false, true).timeout.connect(func():
			if Game.state == Game.State.SHOP:
				shot("shop_after")
				main.shop.closed.emit())
	if _state_t > 6.0 and _acted and Game.state == Game.State.SHOP and evo_test and Game.wave == 1 and not main.evo.visible:
		main.shop.closed.emit()

func _release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)

func _play(delta: float) -> void:
	var pl = Game.player
	if pl == null:
		return
	if Game.wave != _logged_wave:
		_logged_wave = Game.wave
		print("[AUTOTEST] Welle %d, Phase %s" % [Game.wave, Game.phase_id])
	_shot_t += delta
	_log_t += delta
	if proj_shots:
		_proj_cd -= delta
		var n := 0
		for c in Game.arena.fx_layer.get_children():
			if c is Projectile:
				n += 1
		if n >= 2 and _proj_cd <= 0.0:
			_proj_cd = 2.5
			shot("proj")
	if weapons_test:
		_wp_t += delta
		if _wp_t > 3.5:
			_wp_t = 0.0
			var ids: Array = Db.weapons.keys()
			if _wp_idx < ids.size():
				var id: String = ids[_wp_idx]
				_wp_idx += 1
				pl.slots = 20
				pl.weapons.clear()
				pl.equip(id)
				print("[AUTOTEST] Waffe ", id)
				shot("weapon_" + id)
			else:
				get_tree().quit()
	if locker_test:
		if _lk == null and _total > 6.0:
			_lk = Game.arena.spawn_enemy("locker", pl.global_position + Vector2(160, 40))
		elif _lk != null and is_instance_valid(_lk) and _total > 10.0 and not _lk.dead:
			shot("locker_alive")
			_lk.take_hit(9999.0, Vector2.LEFT, 100.0, false)
			get_tree().create_timer(0.5, true, false, true).timeout.connect(func(): shot("locker_dead"))
	if ui_test and _ui_step == 0 and _state_t > 5.0 and Game.state == Game.State.IN_RUN:
		_ui_step = 1
		Game.change_state(Game.State.PAUSE)
		return
	if _shot_t > 4.0:
		_shot_t = 0.0
		shot("run_w%d_%s" % [Game.wave, Game.phase_id])
	if _log_t > 10.0:
		_log_t = 0.0
		if Game.arena.boss != null and is_instance_valid(Game.arena.boss):
			var b = Game.arena.boss
			print("[AUTOTEST] boss hp=%d atk=%s t=%.2f active=%s stun=%.2f spawn=%.2f pat=%s" % [b.hp, b.atk, b.atk_t, b.active, b.stun_t, b.spawn_t, b._pattern])
		print("[AUTOTEST] director pending=", Game.arena.director._pending, " queue=", Game.arena.director.queue.size(), " active=", Game.arena.director.active, " enemies=", Game.enemies.size())
		print("[AUTOTEST] t=%.0f welle=%d hp=%d/%d enemies=%d lvl=%d geld=%d fps=%d dc=%d obj=%d prim=%d" % [Game.stats.time, Game.wave, pl.hp, pl.max_hp, Game.enemies.size(), Game.level, Game.money, Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)])
	if boss_only and Game.arena.boss != null and is_instance_valid(Game.arena.boss) and not Game.arena.boss.dead:
		var bb = Game.arena.boss
		if _total > 22.0 and not bb.phase2:
			bb.take_hit(500.0, Vector2.DOWN, 0.0, true)
		if _total > 42.0:
			bb.take_hit(9999.0, Vector2.DOWN, 0.0, false)
	# Kiten: von Gegnern weg, wenn nah; sonst zum nächsten hin
	var want := Vector2.ZERO
	var near_n := 0
	var centroid := Vector2.ZERO
	for e in Game.enemies:
		if is_instance_valid(e) and not e.dead:
			var d: float = e.global_position.distance_to(pl.global_position)
			if d < 170.0:
				near_n += 1
				centroid += e.global_position
	if near_n > 0:
		centroid /= near_n
		want = (pl.global_position - centroid).normalized()
	else:
		var t = Game.nearest_enemy(pl.global_position)
		if t != null:
			want = (t.global_position - pl.global_position).normalized()
		else:
			want = (Vector2(800, 560) - pl.global_position).normalized() * 0.5
	# Wände meiden
	var rect: Rect2 = Game.arena.PLAY
	var p: Vector2 = pl.global_position
	if p.x < rect.position.x + 90.0: want.x = absf(want.x) + 0.4
	if p.x > rect.end.x - 90.0: want.x = -absf(want.x) - 0.4
	if p.y < rect.position.y + 90.0: want.y = absf(want.y) + 0.4
	if p.y > rect.end.y - 90.0: want.y = -absf(want.y) - 0.4
	_set_move(want)
	_dash_t -= delta
	if _dash_t <= 0.0 and near_n > 2:
		_dash_t = 3.0
		Input.action_press("dash")
		get_tree().create_timer(0.05, true, false, true).timeout.connect(func(): Input.action_release("dash"))

func _set_move(v: Vector2) -> void:
	_act("move_left", v.x < -0.3)
	_act("move_right", v.x > 0.3)
	_act("move_up", v.y < -0.3)
	_act("move_down", v.y > 0.3)

func _act(a: String, on: bool) -> void:
	if on:
		Input.action_press(a)
	else:
		Input.action_release(a)
