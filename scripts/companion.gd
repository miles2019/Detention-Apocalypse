class_name Companion
extends Node2D
## AG-Begleiter: folgt Mr. Scrubbs und hat eine kleine Spezialfähigkeit (Hamster/Hund/Kröte).

var kind := "hamster"
var owner_player: Node
var bb: Billboard3D
var _t := 0.0
var _timer := 5.0
var _vel := Vector2.ZERO
var _hop := 0.0

func _ready() -> void:
	var d: Dictionary = Db.ags[kind]
	global_position = owner_player.global_position + Vector2(-40, 20)
	bb = Billboard3D.new()
	Game.arena.stage.sprites.add_child(bb)
	bb.setup(Db.tex(d.tex), d.height)
	bb.set_tint(d.tint)
	_timer = {hamster = 6.0, hund = 8.0, kroete = 12.0}[kind]

func _exit_tree() -> void:
	if bb != null and is_instance_valid(bb):
		bb.queue_free()

func _process(delta: float) -> void:
	if owner_player == null or not is_instance_valid(owner_player):
		return
	_t += delta
	var target: Vector2 = owner_player.global_position + Vector2(-46.0, 14.0)
	var to := target - global_position
	var sp := minf(to.length() * 6.0, 320.0)
	_vel = _vel.lerp(to.normalized() * sp, 1.0 - exp(-8.0 * delta))
	global_position += _vel * delta
	_hop = absf(sin(_t * 9.0)) * 6.0 if _vel.length() > 20.0 else 0.0
	bb.place(global_position, _hop)
	bb.set_body(Vector2(-1.0 if _vel.x < 0.0 else 1.0, 1.0), sin(_t * 9.0) * 0.08 if _vel.length() > 20.0 else 0.0)
	if Game.state != Game.State.IN_RUN:
		return
	_timer -= delta
	if _timer <= 0.0:
		_ability()

func _ability() -> void:
	match kind:
		"hamster":
			_timer = 6.0
			Pickup.spawn("coin", 1, global_position + Vector2(randf_range(-30, 30), randf_range(-10, 30)), 60.0)
			Juice.float_text_at(global_position, 40.0, "Hamster bringt Geld!", Color(1, 0.9, 0.4), 14)
		"hund":
			_timer = 9.0
			Sfx.play("shoot_mega", 1.7, -4.0)
			Juice.float_text_at(global_position, 50.0, "WUFF!", Color(1, 0.9, 0.6), 22, true)
			Shockwave.create(Juice.fx_parent(), global_position, {
				team = "player", max_radius = 210.0, duration = 0.35, damage = 0.0, knockback = 120.0, stun = 1.0,
				stun_chance = 1.0, color = Color(1.0, 0.85, 0.5), weapon_id = "hund",
			})
		"kroete":
			_timer = 14.0
			Sfx.play("splat", 0.9, -4.0)
			owner_player.heal(6.0)
			for h in Game.arena.floor_fx.get_children():
				if h is Hazard and h.kind == "acid" and h.global_position.distance_to(global_position) < 160.0:
					h.queue_free()
					Juice.float_text_at(h.global_position, 20.0, "Mampf!", Color(0.6, 1, 0.5), 16)
					break
