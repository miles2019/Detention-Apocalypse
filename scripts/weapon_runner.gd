class_name WeaponRunner
extends RefCounted
## Laufzeit-Instanz einer Waffe: Level, Cooldown und die Angriffslogik je Waffentyp.
## Typen: melee | slam | flame | bullet | ring | lob | steam | ball | cone | orbit

var data: WeaponData
var level := 1
var timer := 0.4
var player: Node
var first_use := false
var current_cd := 1.0
var _blades: Array = []
var _blade_angle := 0.0
var _blade_hit := {}

const MELEE_KINDS := ["melee", "slam", "fissure"]

func _init(d: WeaponData, p: Node) -> void:
	data = d
	player = p
	current_cd = cooldown()

func prm(key: String, default = null):
	return data.params.get(key, default)

func dmg() -> float:
	var m := 1.0
	if prm("combo", false):
		m = player.combo_mult()
	if prm("still", false):
		m *= 1.0 + minf(2.0, player.still_t)
	return data.damage * (1.0 + 0.3 * float(level - 1)) * player.dmg_mult * m

func cooldown() -> float:
	return data.cooldown * pow(0.9, float(level - 1)) / player.atk_speed

func count() -> int:
	var n := data.count
	if data.kind in ["bullet", "flame"]:
		n += player.extra_proj
		if level >= 3:
			n += 1
	return n

func cd_ratio() -> float:
	if data.kind == "orbit":
		return 1.0
	return clampf(1.0 - timer / maxf(0.01, current_cd), 0.0, 1.0)

func free_visuals() -> void:
	for b in _blades:
		if is_instance_valid(b):
			b.queue_free()
	_blades.clear()

func update(delta: float) -> void:
	if data.kind == "orbit":
		_update_orbit(delta)
		return
	timer -= delta
	if timer > 0.0:
		return
	if player.stun_t > 0.0:
		return
	# Schulregel des Rektors: Waffenklasse blockiert
	var block: String = Game.rule_block
	if block != "" and ((block == "melee" and data.kind in MELEE_KINDS) or (block == "ranged" and not data.kind in MELEE_KINDS)):
		timer = 0.2
		return
	var dir = player.fire_dir(data.reach)
	if dir == null and data.kind in ["mine", "turret"]:
		dir = player.aim_dir
	if dir == null:
		timer = 0.05
		return
	_fire(dir)
	current_cd = cooldown() * randf_range(0.96, 1.04)
	timer = current_cd

func _muzzle(dir: Vector2) -> Vector2:
	return player.global_position + Vector2(0, -26) + dir * 20.0

func _fire(dir: Vector2) -> void:
	Sfx.play(data.fire_sfx, randf_range(0.94, 1.08), -4.0)
	player.show_weapon(data, dir)
	match data.kind:
		"melee": _fire_melee(dir)
		"slam": _fire_slam()
		"flame": _fire_flame(dir)
		"bullet": _fire_bullet(dir)
		"ring": _fire_ring()
		"lob": _fire_lob(dir)
		"steam": _fire_steam(dir)
		"ball": _fire_ball(dir)
		"cone": _fire_cone(dir)
		"mine": _fire_mine(dir)
		"vortex": _fire_vortex(dir)
		"boomerang": _fire_boomerang(dir)
		"turret": _fire_turret(dir)
		"fissure": _fire_fissure(dir)
	first_use = false

# ---------------------------------------------------------------- Nahkampf
func _fire_melee(dir: Vector2) -> void:
	var origin: Vector2 = player.global_position + Vector2(0, -22)
	var reach := data.reach
	var arc := deg_to_rad(data.spread)
	SwingFX.spawn(Juice.fx_parent(), origin, dir.angle(), reach, data.spread, data.color)
	player.lunge(dir, 60.0)
	var hits := 0
	for e in Game.enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = (e.global_position + Vector2(0, -e.data.height * 0.4)) - origin
		if to.length() > reach + e.data.radius:
			continue
		if absf(angle_difference(dir.angle(), to.angle())) > arc * 0.5:
			continue
		var r: Dictionary = player.roll_damage(dmg(), 0.0)
		if prm("pull", false):
			e.take_hit(r.dmg, to.normalized(), 0.0, r.crit, {tags = "melee", stun = prm("stun", 0.6)})
			e.kb_vel += (origin - e.global_position).normalized() * 380.0
		else:
			e.take_hit(r.dmg, to.normalized(), data.knockback * player.kb_mult * Game.phase_mod("kb"), r.crit, {tags = "melee",
				shred = 1 if prm("shred", false) else 0, launch = r.dmg * 0.6 if prm("launch", false) else 0.0})
		if prm("combo", false):
			player.combo_hit()
		Sfx.play_hit(r.crit)
		hits += 1
	if hits > 0:
		Juice.shake(0.16 + 0.03 * minf(hits, 5), dir)
		Juice.burst(origin + dir * reach * 0.8, Color(1, 1, 0.8), 6, 180.0, 0.3, 3.0, 90.0, dir)
	if prm("reflect", false):
		# Baseballschläger: gegnerische Geschosse im Bogen fliegen als eigene zurück
		for p in player.get_tree().get_nodes_in_group("enemy_proj"):
			if not is_instance_valid(p) or p._dead:
				continue
			var tp: Vector2 = p.global_position - origin
			if tp.length() < reach + 30.0 and absf(angle_difference(dir.angle(), tp.angle())) < arc * 0.5 + 0.2:
				p.remove_from_group("enemy_proj")
				p.team = "player"
				p.vel = dir * maxf(p.vel.length() * 1.6, 520.0)
				p.damage = dmg() * 1.5
				p.life = p._age + 1.6
				p.weapon_id = data.id
				p.color = data.color
				p._hit.clear()
				Juice.float_text_at(p.global_position, 40.0, "Homerun!", Color(1.0, 0.85, 0.4), 18, true)
				Juice.ring(p.global_position, 40.0, Color(1, 0.9, 0.5), 0.25, 5.0)
				Juice.hitstop(0.04)
				Sfx.play("kick", 1.3)
				Game.stats.objects_used += 1
	if prm("sweep", false):
		# Besen: kehrt alles Aufsammelbare im Bogen zu dir
		for pk in Game.arena.pickup_layer.get_children():
			if pk is Pickup:
				var tk: Vector2 = pk.global_position - origin
				if tk.length() < reach * 1.7 and absf(angle_difference(dir.angle(), tk.angle())) < arc * 0.5:
					pk.forced = true
		Juice.burst(origin + dir * reach * 0.6, Color(0.9, 0.85, 0.7, 0.8), 10, 220.0, 0.5, 4.0, data.spread * 0.5, dir, 0.0, "circle", 4.0)

func _fire_slam() -> void:
	var origin: Vector2 = player.global_position
	var reach: float = data.reach * (1.0 + 0.1 * float(level - 1)) * player.area_mult
	Juice.ring(origin, reach, data.color, 0.35, 10.0, true)
	Game.arena.blast(origin, reach, true, 2)
	Juice.burst(origin, Color(0.85, 0.8, 0.7), 18, 240.0, 0.6, 5.0, 180.0, Vector2.UP, 0.0, "circle", 8.0)
	Juice.shake(0.55)
	Juice.zoom_pop(0.03)
	Game.arena.room_react(origin, 1.0)
	Game.arena.stage.pulse_light(origin, Color(1.0, 0.85, 0.6), 1.5, 2.8, 0.25)
	player.squash_body(1.3, 0.75)
	for e in Game.enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var d: float = e.global_position.distance_to(origin)
		if d < reach + e.data.radius:
			var r: Dictionary = player.roll_damage(dmg(), 0.0)
			var dir: Vector2 = (e.global_position - origin).normalized()
			e.take_hit(r.dmg, dir, data.knockback * player.kb_mult * Game.phase_mod("kb"), r.crit, {tags = "melee", stun = 0.4})
			Sfx.play_hit(r.crit)

# ---------------------------------------------------------------- Feuer / Projektile
func _fire_flame(dir: Vector2) -> void:
	var n := count()
	var life := data.reach / data.speed
	var base_pos := _muzzle(dir)
	for i in n:
		var a := dir.angle() + deg_to_rad(randf_range(-data.spread, data.spread) * 0.5)
		var v := Vector2.from_angle(a) * data.speed * randf_range(0.75, 1.15)
		Projectile.create(Juice.fx_parent(), base_pos, v, {
			team = "player", kind = "flame", damage = dmg(), pierce = 99, life = life * randf_range(0.8, 1.1),
			radius = 9.0, knockback = data.knockback, weapon_id = data.id, color = Color(1.0, 0.55, 0.15), grow = 14.0,
		})
	Juice.burst(base_pos, Color(1, 0.7, 0.2), 4, 120.0, 0.3, 3.0, 40.0, dir)
	Game.arena.stage.pulse_light(base_pos + dir * 60.0, Color(1.0, 0.6, 0.2), 1.5, 2.2, 0.28)
	var spot: Vector2 = player.global_position + dir * data.reach * 0.75
	Game.arena.decal(spot, Color(0.1, 0.05, 0.02, 0.35), 14.0, 2.5)

func _fire_bullet(dir: Vector2) -> void:
	var n := count()
	var spd := data.speed * Game.phase_mod("proj_speed")
	var bnc := data.bounce + int(Game.phase_mod("bounce", 0.0))
	var prc := data.pierce
	# Fach-Set Physik: mehr Abpraller/Tempo, ab Stufe 2 zusätzlicher Durchschlag
	var phys: int = player.syn_tier("Physik")
	if phys >= 1:
		bnc += 1
		spd *= 1.15
	if phys >= 2:
		prc += 1
	var base_pos := _muzzle(dir)
	for i in n:
		var off := 0.0
		if n > 1:
			off = deg_to_rad(data.spread) * (float(i) / float(n - 1) - 0.5) * 2.0
		else:
			off = deg_to_rad(randf_range(-data.spread, data.spread) * 0.25)
		var v := Vector2.from_angle(dir.angle() + off) * spd
		var props := {
			team = "player", damage = dmg(), pierce = prc, bounce = bnc,
			life = data.reach / data.speed * 1.4, knockback = data.knockback, weapon_id = data.id,
			color = data.color, chain = prm("chain", 0), sticky = prm("sticky", 0.0), combo = prm("combo", false),
			snipe = prm("snipe", false), seek = prm("seek", false), explode = prm("explode", 0.0), cloud = prm("cloud", false),
		}
		match data.id:
			"water", "gum", "gumsalvo":
				props.kind = "drop"
				props.radius = 7.0
			"blowpipe", "calculator":
				props.kind = "pea"
				props.radius = 5.0
			"compass":
				props.kind = "bullet"
				props.radius = 12.0
				props.tex = Db.tex(data.icon)
				props.tex_scale = 0.5
				props.spin = 14.0
				props.life = 2.6
			_:
				props.kind = "bullet"
				props.radius = 8.0
				if data.proj_icon != "":
					props.tex = Db.tex(data.proj_icon)
					props.tex_scale = data.proj_scale
		if data.id == "tennis":
			props.radius = 10.0
			props.life = 3.2
			props.spin = 12.0
		Projectile.create(Juice.fx_parent(), base_pos, v, props)
	if prm("snipe", false):
		# Scharfschuss: Leuchtspur durch den Raum, kräftiger Rückstoß
		ChainFX.spawn(base_pos, base_pos + dir * data.reach, data.color)
		Juice.shake(0.3, dir)
		Juice.zoom_pop(0.02)
		Game.arena.stage.flash_at(base_pos + dir * 16.0, 28.0, Color(1, 1, 0.8), 3.0)
		player.recoil(dir, 90.0)
	Juice.burst(base_pos, data.color, 4, 140.0, 0.25, 2.5, 50.0, dir, 0.0, "circle")
	Game.arena.stage.flash_at(base_pos + dir * 12.0, 28.0, data.color.lightened(0.5), 1.0)
	if data.cooldown >= 0.45:
		Game.arena.stage.pulse_light(base_pos, data.color, 0.9, 1.8, 0.12)
	player.recoil(dir, 40.0 if not data.id in ["blowpipe", "calculator", "gumsalvo"] else 18.0)

func _fire_ball(dir: Vector2) -> void:
	var big: bool = prm("homing", false)
	var base_pos := _muzzle(dir)
	Projectile.create(Juice.fx_parent(), base_pos, dir * data.speed, {
		team = "player", kind = "ball", damage = dmg(), pierce = 9999, bounce = 9, life = 7.0 if not big else 9.0,
		radius = 20.0 if not big else 28.0, knockback = data.knockback, weapon_id = data.id, color = data.color,
		tex = Db.tex(Db.p_icon(3)), tex_scale = 0.8 if not big else 1.15, spin = 9.0, rehit = 0.5,
		homing = big, stun = prm("stun", 0.0), steer_speed = data.speed,
	})
	Juice.shake(0.2, dir)
	player.recoil(dir, 70.0)

# ---------------------------------------------------------------- Flächen
func _fire_ring() -> void:
	var mul := Game.phase_mod("explosion")
	var origin: Vector2 = player.global_position + Vector2(0, -14)
	var stun_all: float = prm("stun_all", 0.0)
	var stun_chance := 0.25 + (0.3 if player.syn("Musik") else 0.0)
	var stun := 0.9
	if stun_all > 0.0:
		stun_chance = 1.0
		stun = stun_all
	var radius: float = data.reach * mul * (1.0 + 0.1 * float(level - 1)) * player.area_mult
	Shockwave.create(Juice.fx_parent(), origin, {
		team = "player", max_radius = radius, duration = 0.4, damage = 0.0 if prm("no_damage", false) else dmg(),
		knockback = data.knockback, stun = stun, stun_chance = stun_chance, color = data.color, weapon_id = data.id,
	})
	Juice.shake(0.25)
	Juice.zoom_pop(0.03)
	Game.arena.room_react(origin, 0.6)
	player.squash_body(1.2, 0.85)
	if prm("letters", false):
		var words := ["A", "B", "F", "6", "Fehler!", "ungenügend", "Sitzen!", "Diktat"]
		for i in 9:
			var a := TAU * i / 9.0
			Juice.float_text_at(origin + Vector2.from_angle(a) * radius * 0.7, 20.0, words[randi() % words.size()], data.color.lightened(0.3), 20, true, 70.0)

func _fire_lob(dir: Vector2) -> void:
	var target = Game.nearest_enemy(player.global_position, data.reach * 1.2)
	var pos: Vector2 = player.global_position + dir * 200.0
	if target != null:
		pos = target.global_position + target.velocity * 0.35
	var rad: float = 70.0 * (1.0 + 0.1 * float(level - 1)) * player.area_mult
	if prm("puddle", "") == "fire":
		# Suppenkelle: Einschlag + brennende Suppenpfütze
		Hazard.spawn(pos, {
			kind = "impact", radius = rad, telegraph = 0.5, burst_enemy = dmg(), kb = data.knockback, color = data.color, pattern = "bubbles",
			fly_tex = Db.tex(data.icon), fly_from = _muzzle(dir), from_enemy = false, sound = "splat",
			follow_up = {kind = "fire", radius = rad * 0.85, telegraph = 0.0, duration = 3.5, tick_enemy = 7.0 * player.dmg_mult * (1.0 + 0.3 * float(level - 1)),
				slow_enemy = 0.7, color = Color(1.0, 0.6, 0.2), pattern = "bubbles", from_enemy = false},
		})
		return
	Hazard.spawn(pos, {
		kind = "chalk", radius = rad, telegraph = 0.5, duration = 3.0, burst_enemy = dmg(),
		kb = data.knockback, slow_enemy = 0.5, color = Color(1.0, 0.85, 0.45), pattern = "stripes",
		fly_tex = Db.tex(data.proj_icon), fly_from = _muzzle(dir), from_enemy = false, sound = "explosion",
	})

func _fire_steam(dir: Vector2) -> void:
	var cloud := SteamCloud.new()
	cloud.dir = dir
	cloud.damage = dmg()
	cloud.knockback = data.knockback
	cloud.big = first_use
	cloud.global_position = _muzzle(dir)
	Juice.fx_parent().add_child(cloud)
	Juice.shake(0.35, dir)
	Juice.zoom_pop(0.04)

func _fire_cone(dir: Vector2) -> void:
	var origin: Vector2 = player.global_position + Vector2(0, -22)
	var reach: float = data.reach * (1.0 + 0.06 * float(level - 1)) * player.area_mult
	var half := deg_to_rad(data.spread)
	var blind: float = prm("blind", 0.0)
	var slow: float = prm("slow", 0.0)
	SwingFX.spawn(Juice.fx_parent(), origin, dir.angle(), reach, data.spread * 2.0, data.color)
	if prm("foam", false):
		Juice.burst(origin + dir * reach * 0.5, Color(0.95, 1, 1, 0.9), 12, 200.0, 0.55, 4.5, data.spread, dir, 0.0, "circle")
	if blind > 0.0:
		Juice.burst(origin + dir * reach * 0.6, Color(1.0, 0.95, 0.5), 10, 240.0, 0.35, 4.0, data.spread, dir, 0.0, "circle")
		Game.arena.stage.pulse_light(origin + dir * reach * 0.5, Color(1.0, 0.95, 0.6), 2.6, 3.4, 0.3)
		Juice.shake(0.2, dir)
	var hits := 0
	for e in Game.enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = (e.global_position + Vector2(0, -e.data.height * 0.4)) - origin
		if to.length() > reach + e.data.radius:
			continue
		if absf(angle_difference(dir.angle(), to.angle())) > half:
			continue
		var r: Dictionary = player.roll_damage(dmg(), 0.0)
		e.take_hit(r.dmg, to.normalized(), data.knockback * player.kb_mult * Game.phase_mod("kb"), r.crit, {stun = blind, slow = slow, tags = data.id})
		hits += 1
	if hits > 0:
		Sfx.play_hit(false)
	var tip: Vector2 = origin + dir * reach * 0.8
	if prm("fire", false):
		Hazard.spawn(tip, {kind = "fire", radius = 62.0, telegraph = 0.0, duration = 3.5, tick_enemy = 9.0 * player.dmg_mult,
			color = Color(1.0, 0.5, 0.15), pattern = "bubbles", from_enemy = false})
	if prm("clean", false):
		_clean_cone(origin, dir, reach, half)
	if prm("paint", false):
		var cols := [Color("ff5fa8"), Color("5fd0ff"), Color("ffd84a"), Color("8be05a"), Color("c78bff")]
		Hazard.spawn(player.global_position + dir * reach * 0.75, {kind = "paint", radius = 62.0 * player.area_mult * (1.0 + 0.1 * float(level - 1)),
			telegraph = 0.0, duration = 5.0, tick_enemy = 4.0 * player.dmg_mult * (1.0 + 0.3 * float(level - 1)), slow_enemy = 0.6,
			color = cols[randi() % cols.size()], pattern = "paint", from_enemy = false})

## Turbo-Schrubbkanone: entfernt Säure/Klebe im Kegel und verwandelt sie in heilende, rutschige Zonen
func _clean_cone(origin: Vector2, dir: Vector2, reach: float, half: float) -> void:
	for h in Game.arena.floor_fx.get_children():
		if not (h is Hazard):
			continue
		if h.kind != "acid" and h.kind != "sticky":
			continue
		var to: Vector2 = h.global_position - origin
		if to.length() > reach + h.radius or absf(angle_difference(dir.angle(), to.angle())) > half + 0.4:
			continue
		var p: Vector2 = h.global_position
		h.queue_free()
		Hazard.spawn(p, {kind = "heal", radius = 52.0, telegraph = 0.0, duration = 5.0, slow_enemy = 0.55,
			color = Color(0.5, 1.0, 0.85), pattern = "waves", from_enemy = false})
		Juice.float_text_at(p, 20.0, "Sauber!", Color(0.7, 1, 0.9), 16)

# ---------------------------------------------------------------- Orbit (Geometrie-Todesstern)
func _update_orbit(delta: float) -> void:
	var n: int = int(prm("blades", 4)) + (level - 1)
	var stage: Stage3D = Game.arena.stage
	while _blades.size() < n:
		var b := Billboard3D.new()
		stage.sprites.add_child(b)
		b.setup(Db.tex(Db.w_icon(47)), 36.0, false)
		_blades.append(b)
	_blade_angle += delta * 3.6
	var radius := data.reach
	var origin: Vector2 = player.global_position
	var now := Time.get_ticks_msec()
	for i in _blades.size():
		var a := _blade_angle + TAU * i / float(_blades.size())
		var p := origin + Vector2.from_angle(a) * radius
		_blades[i].place(p, 26.0)
		_blades[i].set_body(Vector2.ONE, a * 3.0)
		for e in Game.enemies:
			if not is_instance_valid(e) or e.dead:
				continue
			if p.distance_to(e.global_position + Vector2(0, -e.data.height * 0.3)) < 30.0 + e.data.radius:
				var id: int = e.get_instance_id()
				if _blade_hit.get(id, 0) < now:
					_blade_hit[id] = now + 350
					var r: Dictionary = player.roll_damage(dmg(), 0.0)
					e.take_hit(r.dmg, (e.global_position - origin).normalized(), 180.0 * player.kb_mult, r.crit, {tags = "orbit"})
					Sfx.play_hit(r.crit)
	if _blades.size() > 0 and randf() < 0.1:
		Juice.burst(origin + Vector2.from_angle(_blade_angle) * radius, Color(1, 0.9, 0.4), 2, 80.0, 0.25, 2.0)

# ---------------------------------------------------------------- Fallen, Sog, Bumerang, Geschütz, Erdspalte
func _fire_mine(dir: Vector2) -> void:
	var traps: Array = player.get_tree().get_nodes_in_group("trap")
	if traps.size() >= 5 + level:
		traps[0].queue_free()
	var pos: Vector2 = Game.arena.clamp_to_arena(player.global_position - dir * 26.0)
	Trap.spawn(pos, dmg())
	Juice.burst(pos, data.color, 5, 110.0, 0.3, 3.0)

func _fire_vortex(dir: Vector2) -> void:
	var target = Game.nearest_enemy(player.global_position, data.reach * 1.1)
	var pos: Vector2 = player.global_position + dir * minf(data.reach * 0.6, 220.0)
	if target != null and not player.manual_aim:
		pos = target.global_position
	elif player.manual_aim:
		pos = player.global_position + (player.aim_point - player.global_position).limit_length(data.reach)
	pos = Game.arena.clamp_to_arena(pos)
	ChainFX.spawn(_muzzle(dir), pos, data.color)
	Vortex.spawn(pos, {radius = 150.0 * player.area_mult * (1.0 + 0.08 * float(level - 1)), damage = dmg(), duration = 2.6 + 0.3 * float(level - 1), color = data.color})
	player.recoil(dir, 50.0)
	Juice.shake(0.18, dir)

func _fire_boomerang(dir: Vector2) -> void:
	var n: int = 1 + player.extra_proj + (1 if level >= 3 else 0)
	var base_pos := _muzzle(dir)
	for i in n:
		var off := 0.0
		if n > 1:
			off = deg_to_rad(26.0) * (float(i) / float(n - 1) - 0.5) * 2.0
		Projectile.create(Juice.fx_parent(), base_pos, dir.rotated(off) * data.speed, {
			team = "player", kind = "ball", damage = dmg(), pierce = 9999, life = 1.5, radius = 16.0, knockback = data.knockback,
			weapon_id = data.id, color = data.color, tex = Db.tex(data.icon), tex_scale = 0.5, spin = 18.0, boomer = true,
			steer_speed = data.speed, rehit = 0.6,
		})
	Juice.burst(base_pos, data.color, 5, 150.0, 0.25, 2.5, 60.0, dir)
	player.recoil(dir, 30.0)

func _fire_turret(dir: Vector2) -> void:
	var jets: int = int(prm("jets", 1))
	var turrets: Array = player.get_tree().get_nodes_in_group("turret")
	var cap := 2 if jets <= 1 else 1
	if turrets.size() >= cap:
		turrets[0].queue_free()
	var pos: Vector2 = Game.arena.clamp_to_arena(player.global_position + dir * 46.0)
	Turret.spawn(pos, {damage = dmg(), life = (9.0 + 2.0 * float(level - 1)) * (2.0 if jets > 1 else 1.0), jets = jets, reach = data.reach,
		weapon_id = data.id, color = data.color, icon = data.icon})
	Game.stats.objects_used += 1

func _fire_fissure(dir: Vector2) -> void:
	var origin: Vector2 = player.global_position
	var n := 5 + (level - 1)
	player.lunge(dir, 40.0)
	player.squash_body(1.35, 0.7)
	Juice.shake(0.5, dir)
	Juice.zoom_pop(0.03)
	Game.arena.room_react(origin, 1.2)
	for i in n:
		var p: Vector2 = Game.arena.clamp_to_arena(origin + dir * (60.0 + i * 72.0) + dir.orthogonal() * (14.0 if i % 2 == 0 else -14.0))
		Game.arena.decal(p, Color(0.08, 0.06, 0.05, 0.6), 24.0 + (i % 2) * 8.0, 5.0)
		Hazard.spawn(p, {kind = "quake", radius = 56.0 * player.area_mult, telegraph = 0.1 + 0.08 * i, burst_enemy = dmg(), kb = data.knockback,
			stun_enemy = 0.5, blast_power = 2, color = data.color, pattern = "stripes", from_enemy = false, sound = "kick" if i > 0 else "explosion"})
