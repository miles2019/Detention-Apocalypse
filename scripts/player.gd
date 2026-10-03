class_name Player
extends CharacterBody2D
## Mr. Scrubbs: Bewegung, Zielen, Ausweichen, Waffen, Statuswerte, Schaden.

const BASE_SPEED := 235.0
const SPAWN_FEET := Vector2(0, 0)

var max_hp := 100.0
var hp := 100.0
var speed_bonus := 0.0
var atk_speed := 1.0
var dmg_mult := 1.0
var crit := 0.05
var crit_mult := 2.0
var extra_proj := 0
var kb_mult := 1.0
var magnet := 95.0
var slots := 4
var weapons: Array = []
var items := {}
var subject_counts := {}
var char_data := {}
var area_mult := 1.0
var kb_base := 1.0
var _kills_music := 0
var paint_t := 0.0             # steht auf eigener Farbe (Sprühdose): schneller
var still_t := 0.0             # Zeit ohne Bewegung (Zwille)
var _kills_heal := 0

var rig: VisualRig
var aim_dir := Vector2.RIGHT
var manual_aim := false
var iframes := 0.0
var dash_t := 0.0
var dash_cd := 0.0
var dash_inv := 0.0
var dash_dir := Vector2.RIGHT
var stun_t := 0.0
var slow_mult := 1.0
var slow_t := 0.0
var knock_vel := Vector2.ZERO
var move_input := Vector2.ZERO
var dead := false
var combo_n := 0
var combo_t := 0.0
var aim_point := Vector2.ZERO
var companion: Node = null

var _idle_t := 0.0
var _step_t := 0.0
var _after_t := 0.0
var _face := 1.0
var _held: Sprite3D
var _hand: Sprite3D
var _hand_tw: Tween
var _syn_seen := {}
var _lunge := Vector2.ZERO

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = 11.0
	cs.shape = sh
	cs.position = Vector2(0, -11)
	add_child(cs)
	rig = VisualRig.new()
	add_child(rig)
	char_data = Save.character()
	rig.setup(Db.tex(char_data.tex), char_data.height, 44.0)
	rig.set_tint(char_data.tint)
	# gehaltene Waffe (schwingt beim Laufen nach) und Waffen-Popup bei Schüssen: Sprite3D-Kinder der Figur
	_held = rig.bb.add_child_sprite(Db.tex(Db.w_icon(43)), 36.0)
	_held.position = Vector3(0.2, 0.2, 0.03)
	_hand = rig.bb.add_child_sprite(Db.tex(Db.w_icon(43)), 36.0)
	_hand.visible = false
	_hand.position = Vector3(0.0, 0.3, 0.05)
	add_to_group("player")
	Game.player = self
	# Meta-Fortschritt aus dem Skilltree (Alte Tafel)
	max_hp = float(char_data.hp) + Save.bonus("max_hp")
	speed_bonus += Save.bonus("speed")
	dmg_mult = float(char_data.dmg) + Save.bonus("dmg")
	area_mult = float(char_data.area)
	slots = int(char_data.slots)
	crit += Save.bonus("crit")
	magnet += Save.bonus("magnet")
	slots += int(Save.bonus("slots"))
	# Mutatoren
	if Game.mut("two_slots"):
		slots = 2
	if Game.mut("glass"):
		max_hp = maxf(20.0, round(max_hp * 0.5))
	var start: String = Save.data.start_weapon
	if String(char_data.start_weapon) != "":
		start = char_data.start_weapon
	if not Game.arena.hub_mode:
		equip(start if Db.weapons.has(start) else "mop")
	hp = max_hp
	if not Game.arena.hub_mode:
		Game.add_money(int(Save.bonus("start_money")))
	if Save.data.ag_selected != "" and Db.ags.has(Save.data.ag_selected):
		companion = Companion.new()
		companion.kind = Save.data.ag_selected
		companion.owner_player = self
		Game.arena.entities.add_child(companion)
		if companion.kind == "hamster":
			magnet += 80.0

func _physics_process(delta: float) -> void:
	if dead:
		return
	# Timer
	iframes = maxf(0.0, iframes - delta)
	dash_t = maxf(0.0, dash_t - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	combo_t = maxf(0.0, combo_t - delta)
	paint_t = maxf(0.0, paint_t - delta)
	if velocity.length() < 25.0:
		var before_still := still_t
		still_t = minf(2.0, still_t + delta)
		if before_still < 2.0 and still_t >= 2.0 and _has_param("still"):
			Juice.ring(global_position, 46.0, Color(1.0, 0.6, 0.4), 0.3, 4.0)
			Juice.float_text_at(global_position, 90.0, "Ruhige Hand!", Color(1.0, 0.7, 0.5), 15)
	else:
		still_t = 0.0
	if combo_t <= 0.0 and combo_n > 0:
		combo_n = 0
	dash_inv = maxf(0.0, dash_inv - delta)
	stun_t = maxf(0.0, stun_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	if slow_t <= 0.0:
		slow_mult = 1.0
	knock_vel = knock_vel.lerp(Vector2.ZERO, 1.0 - exp(-9.0 * delta))
	rig.stunned = stun_t > 0.0
	Game.stats.time += delta
	_update_aim()
	# Eingabe
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if stun_t > 0.0:
		input = Vector2.ZERO
	move_input = input
	if Input.is_action_just_pressed("dash") and dash_cd <= 0.0 and stun_t <= 0.0:
		_start_dash(input)
	var sp := move_speed()
	if dash_t > 0.0:
		velocity = dash_dir * 720.0
	else:
		var accel := 2600.0 if input != Vector2.ZERO else 3000.0
		velocity = velocity.move_toward(input * sp, accel * delta)
	var total := velocity
	if dash_t <= 0.0:
		total += knock_vel
	var keep := velocity
	velocity = total
	move_and_slide()
	velocity = keep if dash_t <= 0.0 else velocity
	_update_visual(delta)
	if Input.is_action_just_pressed("interact"):
		_interact()
	for w in weapons:
		w.update(delta)

func move_speed() -> float:
	var s := BASE_SPEED * float(char_data.speed) * (1.0 + speed_bonus + 0.10 * float(syn_tier("Sport")))
	return s * slow_mult * Game.phase_mod("speed") * (1.25 if paint_t > 0.0 else 1.0)

func _has_param(key: String) -> bool:
	for w in weapons:
		if w.data.params.get(key, false):
			return true
	return false

func _update_aim() -> void:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down", 0.3)
	if stick.length() > 0.3:
		aim_dir = stick.normalized()
		manual_aim = true
		aim_point = global_position + aim_dir * 320.0
		return
	var mw: Vector2 = Game.arena.stage.mouse_to_world()
	aim_point = mw
	var m: Vector2 = mw - global_position
	if m.length() > 6.0:
		aim_dir = m.normalized()
	manual_aim = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and Game.state == Game.State.IN_RUN

## Zielrichtung für Waffen: manuell (Maus gedrückt / rechter Stick) oder automatisch auf nahe Gegner
func fire_dir(reach: float):
	var from := global_position + Vector2(0, -24)
	if manual_aim:
		return aim_dir
	var t = Game.nearest_enemy(global_position, reach * 1.1)
	if t != null:
		var to: Vector2 = (t.global_position + Vector2(0, -t.data.height * 0.4)) - from
		return to.normalized()
	return null

func _update_visual(delta: float) -> void:
	var moving := velocity.length() > 20.0
	if absf(move_input.x) > 0.2:
		_face = signf(move_input.x)
	elif manual_aim and absf(aim_dir.x) > 0.2:
		_face = signf(aim_dir.x)
	rig.scale.x = lerpf(rig.scale.x, _face, 1.0 - exp(-18.0 * delta))
	# Anlauf-Neigung & Gegengewicht beim Stoppen
	var lean_target := clampf(velocity.x / 235.0, -1.0, 1.0) * 0.14 * _face
	rig.lean(lean_target, 14.0, delta)
	var stretch := clampf(velocity.length() / 235.0, 0.0, 1.0)
	if dash_t > 0.0:
		rig.body.scale = rig.body.scale.lerp(Vector2(1.35, 0.8), 1.0 - exp(-30.0 * delta))
		# Fake-Sprung: nur das Sprite hebt ab, der Schatten bleibt am Boden und schrumpft
		rig.hop = sin(clampf(1.0 - dash_t / 0.17, 0.0, 1.0) * PI) * 26.0
	elif rig.body.scale.distance_to(Vector2.ONE) < 0.2 or true:
		var bob := 0.0
		if moving:
			bob = absf(sin(Time.get_ticks_msec() * 0.016)) * 4.0
		rig.hop = bob
		if rig._tw == null or not rig._tw.is_running():
			rig.body.scale = rig.body.scale.lerp(Vector2(1.0 - stretch * 0.04, 1.0 + stretch * 0.05), 1.0 - exp(-12.0 * delta))
	# Mopp-Nachschwingen
	var sway := -velocity.x * 0.0016 - velocity.y * 0.0006
	_held.rotation.z = lerpf(_held.rotation.z, 0.7 - sway - sin(Time.get_ticks_msec() * 0.003) * 0.03, 1.0 - exp(-10.0 * delta))
	# Staub beim Laufen
	if moving and dash_t <= 0.0:
		_step_t -= delta
		if _step_t <= 0.0:
			_step_t = 0.17
			Juice.burst(global_position, Color(0.9, 0.9, 0.85, 0.6), 2, 40.0, 0.35, 2.5, 60.0, -velocity.normalized())
		_idle_t = 0.0
	else:
		_idle_t += delta
		# Mr. Scrubbs wischt automatisch, wenn er kurz stillsteht
		if _idle_t > 1.4:
			_idle_t = 0.0
			_held.rotation.z = 1.3
			Juice.burst(global_position + Vector2(18 * _face, -2), Color(1, 1, 1, 0.7), 4, 50.0, 0.4, 2.5, 120.0, Vector2.UP)
	# Nachbilder beim Ausweichen
	if dash_t > 0.0:
		_after_t -= delta
		if _after_t <= 0.0:
			_after_t = 0.035
			_afterimage()
	# Unverwundbarkeits-Blinken
	rig.visible = true
	rig.modulate.a = 0.45 if (iframes > 0.0 and int(Time.get_ticks_msec() / 70) % 2 == 0) else 1.0

func _afterimage() -> void:
	var stage: Stage3D = Game.arena.stage
	var g := Billboard3D.new()
	stage.sprites.add_child(g)
	g.setup(rig.sprite.texture, rig.base_height, false)
	g.place(global_position, 0.0)
	g.set_body(Vector2(_face, 1.0), 0.0)
	g.set_tint(Color(0.6, 0.85, 1.0, 0.6))
	g.set_body(Vector2(_face, 1.0), 0.0)
	g.sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var tw := g.create_tween()
	tw.tween_method(func(a: float): g.set_tint(Color(0.6, 0.85, 1.0, a)), 0.5, 0.0, 0.25)
	tw.tween_callback(g.queue_free)

func _start_dash(input: Vector2) -> void:
	dash_dir = input if input != Vector2.ZERO else aim_dir
	dash_t = 0.17
	dash_inv = 0.26
	dash_cd = 0.85 * (1.0 - Save.bonus("dash_cd")) * (0.75 if syn_tier("Sport") >= 2 else 1.0)
	Sfx.play("dash", randf_range(0.95, 1.1), -4.0)
	Juice.burst(global_position, Color(0.95, 0.95, 0.9, 0.8), 12, 150.0, 0.55, 4.5, 70.0, -dash_dir, 0.0, "circle", 6.0)
	# Perfektes Ausweichen: kurz vor einer Gefahr
	var danger := false
	for p in get_tree().get_nodes_in_group("enemy_proj"):
		if is_instance_valid(p) and p.global_position.distance_to(global_position + Vector2(0, -20)) < 95.0:
			danger = true
	for e in Game.enemies:
		if is_instance_valid(e) and not e.dead and e.is_attacking() and e.global_position.distance_to(global_position) < 130.0:
			danger = true
	if danger:
		Game.stats.dodges += 1
		Juice.slowmo(0.3, 0.3)
		Juice.float_text_at(global_position, 80, "Sportlich!", Color(0.6, 0.9, 1.0), 20, true)
		Juice.ring(global_position, 70.0, Color(0.6, 0.9, 1.0), 0.3, 4.0)
		Sfx.play("perfect")

func _interact() -> void:
	var best: Node = null
	var bd := 120.0
	for o in get_tree().get_nodes_in_group("interactable"):
		var d: float = o.global_position.distance_to(global_position)
		if d < bd:
			bd = d
			best = o
	if best != null:
		best.interact(self)

# ---------------------------------------------------------------- Status
func is_targetable() -> bool:
	return not dead

func apply_slow(mult: float, t: float) -> void:
	slow_mult = minf(slow_mult, mult)
	slow_t = maxf(slow_t, t)

func knock(v: Vector2) -> void:
	knock_vel = v

func stun(t: float) -> void:
	if Game.god_mode or dash_inv > 0.0:
		return
	stun_t = maxf(stun_t, t)
	Sfx.play("stun")
	Juice.float_text_at(global_position, 90, "Betäubt!", Color(1, 0.9, 0.3), 18, true)

func roll_damage(base: float, crit_bonus: float) -> Dictionary:
	var c := crit + crit_bonus + (0.10 if syn("Mathe") else 0.0)
	var is_crit := randf() < c
	var d := base * ((crit_mult + (0.5 if syn_tier("Mathe") >= 2 else 0.0)) if is_crit else 1.0)
	return {dmg = d, crit = is_crit}

func take_damage(amount: float, from_pos: Vector2, area: bool = false) -> bool:
	if dead or Game.god_mode or iframes > 0.0 or dash_inv > 0.0:
		return false
	amount *= Game.phase_mod("enemy_dmg")
	amount *= 1.0 + 0.15 * float(Game.difficulty)
	amount *= Game.endless_dmg()
	hp -= amount
	iframes = 0.75
	Game.stats.damage_taken += amount
	var dir := (global_position - from_pos).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	knock_vel = dir * 240.0
	rig.flash(0.16, Color(1, 0.3, 0.3))
	rig.squash(1.25, 0.8)
	Juice.shake(0.4, dir)
	Juice.hitstop(0.06)
	Sfx.play("hit_player")
	Juice.float_text_at(global_position, 80, "-%d" % int(round(amount)), Color(1, 0.35, 0.3), 22, true)
	Juice.burst(global_position + Vector2(0, -24), Color(1, 0.3, 0.3), 8, 170.0, 0.4, 3.5, 180.0, dir)
	Game.player_hurt.emit()
	if hp <= 0.0:
		_die()
	return true

func heal(v: float) -> void:
	if dead:
		return
	var before := hp
	hp = minf(max_hp, hp + v)
	if hp > before:
		Sfx.play("heal", 1.0, -4.0)
		Juice.float_text_at(global_position, 80, "+%d" % int(round(hp - before)), Color(0.45, 1, 0.5), 20, true)
		# Heilung: grüne Kreuz-Partikel
		Juice.burst(global_position + Vector2(0, -26), Color(0.45, 1, 0.5), 8, 90.0, 0.6, 3.0, 180.0, Vector2.UP, -30.0, "circle")
		rig.squash(0.9, 1.15)
		Game.player_hurt.emit()

func _die() -> void:
	if Save.bonus("revive") > 0.0 and not Game.stats.revived:
		Game.stats.revived = true
		hp = max_hp * 0.5
		iframes = 2.5
		Juice.float_text_at(global_position, 90.0, "Entschuldigungszettel!", Color(1, 0.95, 0.5), 22, true)
		Game.stamp_requested.emit("Entschuldigt!", Color(0.2, 0.7, 0.3))
		Juice.ring(global_position, 160.0, Color(1, 0.95, 0.5), 0.5, 8.0, true)
		Sfx.play("levelup")
		for e in Game.enemies:
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(global_position) < 200.0:
				e.kb_vel += (e.global_position - global_position).normalized() * 600.0
		return
	dead = true
	rig.flash(0.3, Color(1, 0.2, 0.2))
	Juice.slowmo(0.7, 0.2)
	Juice.shake(0.8)
	Sfx.play("death", 0.7)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(rig.body, "rotation", 1.6, 0.6).set_trans(Tween.TRANS_BACK)
	await get_tree().create_timer(1.0, true, false, true).timeout
	Game.end_run(false)

# ---------------------------------------------------------------- Waffen & Upgrades
func combo_mult() -> float:
	return minf(2.6, 1.0 + 0.12 * float(combo_n))

func combo_hit() -> void:
	combo_n += 1
	combo_t = 1.8
	if combo_n >= 4 and combo_n % 4 == 0:
		Juice.float_text_at(global_position, 100.0, "x%.1f" % combo_mult(), Color(0.7, 1.0, 0.7), 18, true)

func get_weapon(id: String) -> WeaponRunner:
	for w in weapons:
		if w.data.id == id:
			return w
	return null

func has_slot_for(id: String) -> bool:
	return get_weapon(id) != null or weapons.size() < slots

func equip(id: String) -> bool:
	var ex := get_weapon(id)
	if ex != null:
		if ex.level < ex.data.max_level:
			ex.level += 1
			Juice.float_text_at(global_position, 90, "%s Stufe %d" % [ex.data.display_name, ex.level], Color(1, 0.9, 0.4), 18, true)
		_after_inventory()
		return true
	if weapons.size() >= slots:
		return false
	var w := WeaponRunner.new(Db.weapons[id], self)
	weapons.append(w)
	Save.discover("weapons", id)
	_held.texture = Db.tex(weapons[0].data.icon)
	_held.pixel_size = 36.0 * Stage3D.S / float(_held.texture.get_height())
	_after_inventory()
	return true

func add_item(id: String) -> void:
	items[id] = items.get(id, 0) + 1
	apply_upgrade(id)
	_after_inventory()

func apply_upgrade(id: String) -> void:
	match id:
		"atk_speed": atk_speed *= 1.15
		"move_speed": speed_bonus += 0.10
		"max_hp":
			max_hp += 20.0
			hp += 20.0
		"crit": crit += 0.10
		"proj": extra_proj += 1
		"magnet": magnet += 60.0
		"dmg": dmg_mult += 0.12
		"heal": heal(max_hp * 0.35)
		"goggles":
			max_hp += 20.0
			hp += 20.0
			dmg_mult += 0.08
		"flask": dmg_mult += 0.15
	if id in Db.upgrades and id not in ["heal"]:
		var u: UpgradeData = Db.upgrades[id]
		if u.subject != "":
			pass
	Game.inventory_changed.emit()

func _after_inventory() -> void:
	subject_counts.clear()
	for w in weapons:
		subject_counts[w.data.subject] = subject_counts.get(w.data.subject, 0) + 1
	for id in items:
		var u: UpgradeData = Db.upgrades[id]
		subject_counts[u.subject] = subject_counts.get(u.subject, 0) + items[id]
	for s in subject_counts:
		var tier := syn_tier(s)
		var key := "%s%d" % [s, tier]
		if tier >= 1 and Db.sets.has(s) and not _syn_seen.has(key):
			_syn_seen[key] = true
			Game.stats.synergies += 1
			Game.stamp_requested.emit(("Gruppenarbeit: %s!" if tier == 1 else "Leistungskurs: %s!") % s, Db.subject_color(s))
			Game.announce.emit("Fach-Set %s Stufe %d aktiv: %s" % [s, tier, synergy_text(s, tier)], "info")
			Sfx.play("levelup", 1.2)
	kb_mult = kb_base * (1.2 if syn_tier("Hausmeister") >= 1 else 1.0)
	Game.inventory_changed.emit()

func syn(subject: String) -> bool:
	return subject_counts.get(subject, 0) >= 2

## Set-Stufe eines Fachs: 0 = inaktiv, 1 = ab 2 Teilen, 2 = ab 4 Teilen
func syn_tier(subject: String) -> int:
	var n: int = subject_counts.get(subject, 0)
	return 2 if n >= 4 else (1 if n >= 2 else 0)

func synergy_text(s: String, tier: int = 1) -> String:
	if not Db.sets.has(s):
		return ""
	return Db.sets[s][clampi(tier - 1, 0, 1)]

## Rückkaufwert einer Waffe im Kiosk
func sell_value(w: WeaponRunner) -> int:
	if w.data.evolution:
		return 22
	var base := maxf(float(w.data.price), 8.0)
	return maxi(3, int(round((base + float(w.level - 1) * base * 0.6) * 0.5)))

## Waffe verkaufen (mindestens eine Waffe bleibt immer im Spind). Gibt den Erlös zurück, 0 = nicht möglich.
func sell_weapon(w: WeaponRunner) -> int:
	if weapons.size() <= 1 or not weapons.has(w):
		return 0
	var v := sell_value(w)
	w.free_visuals()
	weapons.erase(w)
	Game.money += v
	Game.money_changed.emit(Game.money)
	Game.stats.sold += 1
	_held.texture = Db.tex(weapons[0].data.icon)
	_held.pixel_size = 36.0 * Stage3D.S / float(_held.texture.get_height())
	_after_inventory()
	return v

## Evolution: gibt das passende Rezept zurück, wenn beide Waffen Stufe >= 2 haben
func check_evolution() -> Dictionary:
	for r in Db.evolutions:
		var a := get_weapon(r.a)
		var b := get_weapon(r.b)
		if a != null and b != null and a.level >= 2 and b.level >= 2:
			return r
	return {}

func evolve(recipe: Dictionary) -> void:
	var a := get_weapon(recipe.a)
	var b := get_weapon(recipe.b)
	if a == null or b == null:
		return
	a.free_visuals()
	b.free_visuals()
	weapons.erase(a)
	weapons.erase(b)
	Save.discover("evolutions", recipe.result)
	var w := WeaponRunner.new(Db.weapons[recipe.result], self)
	w.first_use = true
	w.timer = 0.2
	weapons.append(w)
	_after_inventory()

func debug_give_evolution() -> void:
	for id in ["bunsen", "water"]:
		equip(id)
		equip(id)

## Kills: Fach-Synergie Chemie 2 -> Säureimpuls
func on_kill(pos: Vector2, tags: String) -> void:
	if syn("Chemie") and tags != "pulse":
		var big := syn_tier("Chemie") >= 2
		var pr := 125.0 if big else 85.0
		for e in Game.enemies.duplicate():
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(pos) < pr:
				e.take_hit(18.0 if big else 10.0, (e.global_position - pos).normalized(), 120.0, false, {tags = "pulse"})
		Juice.ring(pos, pr, Color(0.5, 1, 0.3, 0.8), 0.3, 4.0)
	# Musik-Set Stufe 2: jeder 10. Kill löst eine Schockwelle aus
	if syn_tier("Musik") >= 2 and tags != "pulse":
		_kills_music += 1
		if _kills_music >= 10:
			_kills_music = 0
			Shockwave.create(Juice.fx_parent(), global_position + Vector2(0, -14), {
				team = "player", max_radius = 210.0 * area_mult, duration = 0.4, damage = 22.0 * dmg_mult, knockback = 420.0,
				stun = 0.8, stun_chance = 0.5, color = Db.subject_color("Musik"), weapon_id = "set_musik"})
			Juice.float_text_at(global_position, 100.0, "Zugabe!", Db.subject_color("Musik"), 20, true)
			Sfx.play("shoot_mega", 1.2, -4.0)
	# Hausmeister-Set Stufe 2: Aufräumen heilt
	if syn_tier("Hausmeister") >= 2:
		_kills_heal += 1
		if _kills_heal >= 6:
			_kills_heal = 0
			heal(3.0)

# ---------------------------------------------------------------- Kosmetik
func show_weapon(d: WeaponData, dir: Vector2) -> void:
	if d.kind == "ring":
		return
	_hand.texture = Db.tex(d.icon)
	_hand.pixel_size = 40.0 * Stage3D.S / float(_hand.texture.get_height())
	_hand.visible = true
	var sd := Vector2(dir.x, dir.y * 0.8)
	var ang := atan2(-sd.y, sd.x)
	_hand.position = Vector3(sd.x * 0.3, 0.3 - sd.y * 0.3, 0.05)
	_hand.rotation.z = ang + (-PI / 4.0 if d.kind != "melee" else 0.0)
	_hand.scale = Vector3(0.5, 0.5, 1.0)
	_hand.modulate = Color.WHITE
	if _hand_tw:
		_hand_tw.kill()
	_hand_tw = create_tween()
	_hand_tw.tween_property(_hand, "scale", Vector3(1.1, 1.1, 1.0), 0.06).set_trans(Tween.TRANS_BACK)
	if d.kind == "melee":
		_hand.rotation.z = ang + 1.2
		_hand_tw.parallel().tween_property(_hand, "rotation:z", ang - 1.2, 0.16)
	_hand_tw.tween_property(_hand, "modulate:a", 0.0, 0.18).set_delay(0.08)
	_hand_tw.tween_callback(func(): _hand.visible = false)

func recoil(dir: Vector2, amt: float) -> void:
	knock_vel -= dir * amt
	rig.squash(0.95, 1.06, 0.15)

func lunge(dir: Vector2, amt: float) -> void:
	knock_vel += dir * amt * 2.0
	rig.squash(1.15, 0.9, 0.2)

func squash_body(sx: float, sy: float) -> void:
	rig.squash(sx, sy, 0.3)

