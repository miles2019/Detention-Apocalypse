class_name HitStop
extends RefCounted
## Hit-Stop / Zeitlupe über Engine.time_scale. Echtzeit-Timer, daher kein Hängenbleiben.

static var _token := 0

static func freeze(tree: SceneTree, duration: float, scale: float = 0.03) -> void:
	if Game.settings.reduced_motion:
		return
	_token += 1
	var my := _token
	Engine.time_scale = scale
	await tree.create_timer(duration, true, false, true).timeout
	if my == _token:
		Engine.time_scale = 1.0

static func reset() -> void:
	_token += 1
	Engine.time_scale = 1.0
