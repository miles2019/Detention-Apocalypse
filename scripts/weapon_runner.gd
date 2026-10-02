class_name WeaponRunner
extends RefCounted
## Laufzeit-Instanz einer Waffe: Level, Cooldown und die eigentliche Angriffslogik je Waffentyp.

var data: WeaponData
var level := 1
var timer := 0.4
var player: Node
var first_use := false
var current_cd := 1.0

func _init(d: WeaponData, p: Node) -> void:
	data = d
	player = p
	current_cd = cooldown()

func dmg() -> float:
	return data.damage * (1.0 + 0.3 * float(level - 1)) * player.dmg_mult

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
	return clampf(1.0 - timer / maxf(0.01, current_cd), 0.0, 1.0)

func update(delta: float) -> void:
	timer -= delta
	if timer > 0.0:
		return
	if player.stun_t > 0.0:
		return
	var dir = player.fire_dir(data.reach)
	if dir == null:
		timer = 0.05
		return
	_fire(dir)
	current_cd = cooldown() * randf_range(0.96, 1.04)
	timer = current_cd

func _arena() -> Node:
	return Game.arena

func _muzzle(dir: Vector2) -> Vector2:
	return player.global_position + Vector2(0, -26) + dir * 20.0

func _fire(dir: Vector2) -> void:
	Sfx.play(data.fire_sfx, randf_range(0.94, 1.08), -4.0)
	player.show_weapon(data, dir)
	match data.kind:
		"melee": _fire_melee(dir)
		"flame": _fire_flame(dir)
		"bullet": _fire_bullet(dir)
		"ring": _fire_ring()
		"lob": _fire_lob(dir)
		"steam": _fire_steam(dir)
	first_use = false

func _fire_melee(dir: Vector2) -> void:
	var origin: Vector2 = player.global_position + Vector2(0, -22)
	var reach := data.reach * (1.0 + 0.0)
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
		e.take_hit(r.dmg, to.normalized(), data.knockback * player.kb_mult * Game.phase_mod("kb"), r.crit, {tags = "melee"})
		Sfx.play_hit(r.crit)
		hits += 1
	if hits > 0:
		Juice.shake(0.16 + 0.03 * minf(hits, 5), dir)
		Juice.burst(origin + dir * reach * 0.8, Color(1, 1, 0.8), 6, 180.0, 0.3, 3.0, 90.0, dir)

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
			crit_bonus = 0.0,
		})
	Juice.burst(base_pos, Color(1, 0.7, 0.2), 4, 120.0, 0.3, 3.0, 40.0, dir)
	Game.arena.stage.pulse_light(base_pos + dir * 60.0, Color(1.0, 0.6, 0.2), 1.5, 2.2, 0.28)
	# kleine Brandspur am Boden
	var spot: Vector2 = player.global_position + dir * data.reach * 0.75
	Game.arena.decal(spot, Color(0.1, 0.05, 0.02, 0.35), 14.0, 2.5)

func _fire_bullet(dir: Vector2) -> void:
	var n := count()
	var spd := data.speed * Game.phase_mod("proj_speed")
	var bnc := data.bounce + int(Game.phase_mod("bounce", 0.0))
	var base_pos := _muzzle(dir)
	for i in n:
		var off := 0.0
		if n > 1:
			off = deg_to_rad(data.spread) * (float(i) / float(n - 1) - 0.5) * 2.0
		else:
			off = deg_to_rad(randf_range(-data.spread, data.spread) * 0.25)
		var v := Vector2.from_angle(dir.angle() + off) * spd
		var props := {
			team = "player", damage = dmg(), pierce = data.pierce, bounce = bnc,
			life = data.reach / data.speed * 1.4, knockback = data.knockback, weapon_id = data.id,
			color = data.color,
		}
		match data.id:
			"water":
				props.kind = "drop"; props.radius = 7.0
			"blowpipe":
				props.kind = "pea"; props.radius = 5.0
			"compass":
				props.kind = "bullet"; props.radius = 12.0; props.tex = Db.tex(data.icon); props.tex_scale = 0.5
				props.spin = 14.0; props.life = 2.6
			_:
				props.kind = "bullet"; props.radius = 8.0
				if data.proj_icon != "":
					props.tex = Db.tex(data.proj_icon)
					props.tex_scale = data.proj_scale
		Projectile.create(Juice.fx_parent(), base_pos, v, props)
	Juice.burst(base_pos, data.color, 3, 100.0, 0.2, 2.5, 50.0, dir)
	player.recoil(dir, 40.0 if data.id != "blowpipe" else 18.0)

func _fire_ring() -> void:
	var mul := Game.phase_mod("explosion")
	var origin: Vector2 = player.global_position + Vector2(0, -14)
	var stun_chance := 0.25 + (0.3 if player.syn("Musik") else 0.0)
	Shockwave.create(Juice.fx_parent(), origin, {
		team = "player", max_radius = data.reach * mul * (1.0 + 0.1 * float(level - 1)), duration = 0.4, damage = dmg(),
		knockback = data.knockback, stun = 0.9, stun_chance = stun_chance, color = data.color, weapon_id = data.id,
	})
	Juice.shake(0.25)
	Juice.zoom_pop(0.03)
	Game.arena.room_react(origin, 0.6)
	player.squash_body(1.2, 0.85)

func _fire_lob(dir: Vector2) -> void:
	var mul := Game.phase_mod("explosion")
	var target = Game.nearest_enemy(player.global_position, data.reach * 1.2)
	var pos: Vector2 = player.global_position + dir * 200.0
	if target != null:
		pos = target.global_position + target.velocity * 0.35
	Hazard.spawn(pos, {
		kind = "chalk", radius = 70.0 * (1.0 + 0.1 * float(level - 1)), telegraph = 0.5, duration = 3.0, burst_enemy = dmg(),
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
