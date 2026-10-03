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
var stress := false
var endless_arg := false
var also_arg := ""
var nav_test := false
var _nav_phase := 0
var _nav_tt := 0.0
var _nav_units: Array = []
var fast := false
var _fast_t := 0.0
var stop_wave := 0
var char_arg := ""
var feat_test := false
var smash_test := false
var _feat_done := false
var _smash_t := 0.0
var _stuck := {}
var _stuck_log := 0.0
var _stress_t := 0.0
var _ft := []
var _ft_t := 0.0
var _last_us := 0
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
		elif a == "--stress":
			stress = true
		elif a == "--proj":
			proj_shots = true
		elif a == "--hub":
			hub_test = true
		elif a == "--locker":
			locker_test = true
		elif a == "--ui":
			ui_test = true
		elif a == "--fast":
			fast = true
		elif a.begins_with("--stopwave="):
			stop_wave = int(a.substr(11))
		elif a == "--navtest":
			nav_test = true
		elif a.begins_with("--also="):
			also_arg = a.substr(7)
		elif a == "--endless":
			endless_arg = true
		elif a.begins_with("--char="):
			char_arg = a.substr(7)
		elif a == "--feat":
			feat_test = true
		elif a == "--smash":
			smash_test = true
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
	if stress:
		# echte Framezeit per Uhr messen (delta wird durch Hitstop/Zeitlupe verfälscht)
		var now_us := Time.get_ticks_usec()
		var real_dt := float(now_us - _last_us) / 1000000.0 if _last_us > 0 else 0.016
		_last_us = now_us
		_ft.append(real_dt)
		_ft_t += real_dt
		if _ft_t > 8.0:
			_ft.sort()
			var avg := 0.0
			for x in _ft:
				avg += x
			avg /= _ft.size()
			print("[PERF] frames=%d avg=%.1fms p95=%.1fms p99=%.1fms max=%.1fms enemies=%d proc=%.1f phys=%.1f dc=%d obj=%d nodes=%d" % [_ft.size(), avg * 1000.0, _ft[int(_ft.size() * 0.95)] * 1000.0, _ft[int(_ft.size() * 0.99)] * 1000.0, _ft[-1] * 1000.0, Game.enemies.size(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME), Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
			_ft.clear()
			_ft_t = 0.0
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
				Game.endless = endless_arg
				if char_arg != "":
					if not Save.data.chars_unlocked.has(char_arg):
						Save.data.chars_unlocked.append(char_arg)
					Save.data.character = char_arg
				if start_weapon != "":
					Save.data.start_weapon = start_weapon
				main._start_run()
				for wid in also_arg.split(",", false):
					Game.player.equip(wid)
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
				if feat_test and not _feat_done:
					# Neu würfeln und Bannen einmal durchspielen
					_feat_done = true
					main.levelup._reroll()
					main.levelup._ban(1)
					print("[AUTOTEST] levelup: rerolls=%d bans=%d banned=%s" % [Game.lv_rerolls, Game.lv_bans, str(Game.banned)])
					get_tree().create_timer(0.6, true, false, true).timeout.connect(func():
						shot("levelup_tools")
						main.levelup._pick(0))
				else:
					main.levelup._pick(randi() % main.levelup._options.size())
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
			if idx == 4 and endless_arg:
				Save.data.endless = true
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
		for i in 5:
			if i < main.shop._offers.size() and not feat_test:
				main.shop._buy(i)
		if feat_test:
			# Merken: erste Waffe merken, neu würfeln – sie muss im Angebot bleiben
			var keep_id: String = main.shop._offers[0].id
			main.shop._toggle_lock(0)
			main.shop._roll()
			var still := false
			for of in main.shop._offers:
				if of.id == keep_id:
					still = true
			print("[AUTOTEST] merken: %s bleibt nach Neu-Würfeln im Angebot: %s, Angebote=%d" % [keep_id, str(still), main.shop._offers.size()])
			main.shop._build_cards()
			# Hover-Info prüfen: Maus auf die erste Angebotskarte bewegen
			var mm := InputEventMouseMotion.new()
			mm.position = Vector2(180, 250)
			mm.global_position = mm.position
			get_viewport().warp_mouse(mm.position)
			Input.parse_input_event(mm)
			get_tree().create_timer(0.5, true, false, true).timeout.connect(func(): shot("tooltip"))
			get_tree().create_timer(0.9, true, false, true).timeout.connect(func():
				var pl = Game.player
				var before: int = Game.money
				var n0: int = pl.weapons.size()
				if n0 > 1:
					main.shop._sell(pl.weapons[0], main.shop._reroll_btn)
				print("[AUTOTEST] verkauf: waffen %d -> %d, geld %d -> %d" % [n0, pl.weapons.size(), before, Game.money])
				# letzte Waffe darf nicht verkauft werden
				while pl.weapons.size() > 1:
					pl.sell_weapon(pl.weapons[0])
				print("[AUTOTEST] letzte waffe verkaufbar: %s (erwartet 0)" % str(pl.sell_weapon(pl.weapons[0])))
				main.shop._refresh_inventory()
				main._open_stats())
			get_tree().create_timer(1.5, true, false, true).timeout.connect(func():
				shot("stats")
				main.stats.close())
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
	if stress and Game.arena != null:
		_stress_t -= delta
		if _stress_t <= 0.0 and Game.enemies.size() < 70:
			_stress_t = 0.12
			var ids := ["bird", "frog", "rat", "nerd", "sheep", "football", "zombie"]
			Game.arena.spawn_enemy(ids[randi() % ids.size()], Game.arena.random_spawn_pos(), 3.0)
	# Wegfindungs-Kontrolle: wie viele Gegner kommen trotz Laufwunsch nicht vom Fleck?
	_stuck_log += delta
	if _stuck_log > 1.0:
		_stuck_log = 0.0
		var stuck_n := 0
		for e in Game.enemies:
			if not is_instance_valid(e) or e.dead:
				continue
			var id: int = e.get_instance_id()
			var last: Vector2 = _stuck.get(id, Vector2(-999, -999))
			if e.atk == "idle" and e.stun_t <= 0.0 and e.spawn_t <= 0.0 and e.global_position.distance_to(pl.global_position) > 120.0 and e.global_position.distance_to(last) < 6.0 and e.data.behavior in ["chase", "charge", "hop", "slam", "boss"]:
				stuck_n += 1
				print("[NAV]   %s bei %s affix=%s hunt=%s side=%.2f navv=%s vel=%s" % [e.data.id, str(e.global_position.round()), e.affix, str(e.hunt), e._side_t, str(e._nav_v), str(e.velocity.round())])
			_stuck[id] = e.global_position
		if stuck_n > 0:
			print("[NAV] festhängende Gegner: %d von %d" % [stuck_n, Game.enemies.size()])
	if fast and Game.state == Game.State.IN_RUN:
		# Schnelldurchlauf: Wellen stark verkürzen, Gegner regelmäßig abräumen
		_fast_t += delta
		var dq: Array = Game.arena.director.queue
		while dq.size() > 5:
			dq.pop_back()
		if _fast_t > 2.0:
			_fast_t = 0.0
			for e in Game.enemies.duplicate():
				if is_instance_valid(e) and not e.dead and e.active:
					e.take_hit(99999.0, Vector2.DOWN, 0.0, false)
		if stop_wave > 0 and Game.wave >= stop_wave and Game.god_mode:
			Game.god_mode = false
			pl.take_damage(99999.0, pl.global_position + Vector2(10, 0))
	if nav_test:
		# Wegfindungstest: Spieler steht still hinter einem Hindernis, Gegner müssen von der anderen Seite herumlaufen
		_nav_tt += delta
		if _nav_phase == 0 and _nav_tt > 2.0:
			_nav_phase = 1
			_nav_tt = 0.0
			Game.arena.director.active = false
			Game.arena.director.queue.clear()
			for e in Game.enemies.duplicate():
				e.queue_free()
			Game.enemies.clear()
			pl.weapons.clear()
			var ob: Rect2 = Game.arena.obstacles[Game.arena.obstacles.size() - 1]
			pl.global_position = Vector2(ob.get_center().x, ob.end.y + 50.0)
			var k := 0
			for id in ["bird", "rat", "frog", "sheep", "locker", "brute", "football", "zombie"]:
				var e: Enemy = Game.arena.spawn_enemy(id, Vector2(ob.get_center().x - 60.0 + k * 18.0, ob.position.y - 40.0 - (k % 2) * 30.0))
				e.spawn_t = 0.0
				_nav_units.append({e = e, id = id, t = -1.0})
				k += 1
			print("[NAVTEST] Hindernis %s, Spieler %s" % [str(ob), str(pl.global_position)])
		elif _nav_phase == 1:
			for u in _nav_units:
				if u.t < 0.0 and is_instance_valid(u.e) and u.e.global_position.distance_to(pl.global_position) < 70.0:
					u.t = _nav_tt
			if _nav_tt > 4.0 and _nav_tt < 4.1:
				shot("navtest")
			if _nav_tt > 16.0:
				_nav_phase = 2
				for u in _nav_units:
					var where := str(u.e.global_position.round()) if is_instance_valid(u.e) else "-"
					print("[NAVTEST] %s: %s" % [u.id, ("angekommen nach %.1f s" % u.t) if u.t >= 0.0 else ("NICHT angekommen, steht bei " + where)])
				get_tree().quit()
		_release_all()
		return
	if smash_test and Game.arena != null:
		_smash_t += delta
		if _smash_t > 5.0 and _smash_t < 100.0:
			_smash_t = 100.0
			print("[AUTOTEST] Hindernisse vorher: %d" % Game.arena.obstacles.size())
			for pr in Game.arena.props_list:
				pr.trigger()
			Game.arena.blast(Vector2(415, 372), 120.0, true, 3)
			get_tree().create_timer(0.25, true, false, true).timeout.connect(func(): shot("smash"))
			get_tree().create_timer(1.2, true, false, true).timeout.connect(func():
				shot("smash_after")
				print("[AUTOTEST] Hindernisse nachher: %d, zertrümmert=%d" % [Game.arena.obstacles.size(), Game.stats.smashed]))
	if weapons_test:
		_wp_t += delta
		if _wp_t > 3.5:
			_wp_t = 0.0
			var ids: Array = Db.weapons.keys()
			if _wp_idx < ids.size():
				var id: String = ids[_wp_idx]
				_wp_idx += 1
				pl.slots = 20
				for ow in pl.weapons:
					ow.free_visuals()
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
