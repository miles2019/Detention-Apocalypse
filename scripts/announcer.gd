class_name Announcer
extends Node
## Rektor-Durchsagen. Ereignislogik hier, Anzeige (Banner/Untertitel) im HUD.

var _last_chaos := -100.0
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	Game.chain_event.connect(_on_chain)

func say(text: String, kind: String = "info", play_sound: bool = true) -> void:
	if play_sound:
		Sfx.play("chime", 1.0, -4.0, "Voice")
		get_tree().create_timer(0.55).timeout.connect(func(): Sfx.play("rektor", randf_range(0.9, 1.1), -2.0, "Voice"))
	Game.announce.emit(text, kind)

func line(key: String) -> String:
	var arr: Array = Db.lines.get(key, [""])
	return arr[_rng.randi() % arr.size()]

func on_wave_start(n: int) -> void:
	if n == 1:
		say(line("wave_1"), "wave")
	elif _rng.randf() < 0.6:
		say(line("wave"), "wave")

func on_boss_intro() -> void:
	var key := "boss_%d" % Game.chapter
	say(line(key if Db.lines.has(key) else "boss"), "boss")

func _on_chain(count: int) -> void:
	if count >= 5 and Game.stats.time - _last_chaos > 40.0 and Game.state == Game.State.IN_RUN:
		_last_chaos = Game.stats.time
		say(line("chaos"), "chaos")
