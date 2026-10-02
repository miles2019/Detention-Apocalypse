extends Node
## Prozedurale Platzhalter-Sounds + Audio-Busse (Music / SFX / Voice).
## Später einfach durch echte AudioStreams ersetzen: sounds["name"] = load("res://audio/xyz.ogg").

const RATE := 22050
const MUSIC_RATE := 16000

var sounds := {}
var _players: Array = []
var _idx := 0
var _music: AudioStreamPlayer
var _music_tracks := {}
var _current_track := ""
var _music_thread: Thread
var _want_track := ""
var _rng := RandomNumberGenerator.new()
var _hit_step := 0
var _hit_last_ms := 0
const PENTA := [1.0, 1.122, 1.26, 1.498, 1.682, 2.0]

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.seed = 1234
	for n in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(n) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")
	for i in 16:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music = AudioStreamPlayer.new()
	_music.bus = "Music"
	add_child(_music)
	_build_sounds()
	apply_volumes()
	_music_thread = Thread.new()
	_music_thread.start(_gen_music_all)

func apply_volumes() -> void:
	var s: Dictionary = Game.settings
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(0.0001, s.master)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, s.music)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, s.sfx)))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voice"), linear_to_db(maxf(0.0001, s.voice)))

func play(sound: String, pitch: float = 1.0, vol_db: float = 0.0, bus: String = "SFX") -> void:
	if not sounds.has(sound):
		return
	var p: AudioStreamPlayer = _players[_idx]
	_idx = (_idx + 1) % _players.size()
	p.stream = sounds[sound]
	p.pitch_scale = pitch
	p.volume_db = vol_db
	p.bus = bus
	p.play()

func play_voice(sound: String) -> void:
	play(sound, 1.0, 0.0, "Voice")

## Treffer-Sound, dessen Tonhöhe bei schnellen Serien eine Pentatonik-Kette bildet
func play_hit(crit: bool = false) -> void:
	var now := Time.get_ticks_msec()
	if now - _hit_last_ms > 450:
		_hit_step = 0
	_hit_last_ms = now
	var pitch: float = PENTA[_hit_step % PENTA.size()] * (1.0 + _rng.randf_range(-0.03, 0.03))
	_hit_step += 1
	play("hit_crit" if crit else "hit", pitch, -2.0 if not crit else 0.0)

func play_music(track: String) -> void:
	if track == _current_track and _music.playing:
		return
	_current_track = track
	if not _music_tracks.has(track):
		if _music_thread != null:
			_want_track = track     # Musik wird im Hintergrund erzeugt, startet danach automatisch
			return
		_music_tracks[track] = _make_music(track)
	_music.stream = _music_tracks[track]
	_music.play()

func _gen_music_all() -> void:
	var out := {}
	for t in ["menu", "run"]:
		out[t] = _make_music(t)
	_music_done.call_deferred(out)

func _music_done(out: Dictionary) -> void:
	_music_tracks.merge(out)
	_music_thread.wait_to_finish()
	_music_thread = null
	if _want_track != "" and _want_track == _current_track:
		_music.stream = _music_tracks[_want_track]
		_music.play()
	_want_track = ""

func stop_music() -> void:
	_current_track = ""
	_want_track = ""
	_music.stop()

# ---------------------------------------------------------------- Synthese
func _wave(kind: String, ph: float) -> float:
	var x := fposmod(ph, 1.0)
	match kind:
		"sine": return sin(x * TAU)
		"square": return 1.0 if x < 0.5 else -1.0
		"pulse": return 1.0 if x < 0.25 else -1.0
		"saw": return x * 2.0 - 1.0
		"tri": return absf(x * 4.0 - 2.0) - 1.0
	return 0.0

func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b

## Ton mit Frequenz-Glide und Hüllkurve, additiv in Buffer geschrieben
func _tone(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, kind: String, vol: float, decay: float = 3.0, vib: float = 0.0) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var ph := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		if vib > 0.0:
			f *= 1.0 + sin(float(i) / RATE * 38.0) * vib
		ph += f / RATE
		var env := pow(1.0 - t, decay) * minf(1.0, float(i) / (RATE * 0.004))
		b[idx] += _wave(kind, ph) * vol * env

func _noise(b: PackedFloat32Array, start: float, dur: float, vol: float, lp: float = 0.5, decay: float = 3.0) -> void:
	var s0 := int(start * RATE)
	var n := int(dur * RATE)
	var last := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / n
		last = lerpf(last, _rng.randf_range(-1.0, 1.0), lp)
		b[idx] += last * vol * pow(1.0 - t, decay)

func _to_stream(b: PackedFloat32Array, rate: int = RATE, loop: bool = false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i], -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = b.size()
	return w

func _build_sounds() -> void:
	var b: PackedFloat32Array
	# --- Treffer
	b = _buf(0.12); _noise(b, 0, 0.08, 0.5, 0.5, 2.5); _tone(b, 0, 0.1, 260, 120, "square", 0.3, 3.0)
	sounds["hit"] = _to_stream(b)
	b = _buf(0.3); _noise(b, 0, 0.1, 0.5, 0.7, 2.0); _tone(b, 0, 0.25, 700, 1500, "square", 0.3, 2.0); _tone(b, 0.05, 0.22, 1400, 2200, "sine", 0.3, 2.5)
	sounds["hit_crit"] = _to_stream(b)
	b = _buf(0.35); _noise(b, 0, 0.06, 0.6, 0.4, 2.0); _tone(b, 0, 0.3, 150, 60, "saw", 0.5, 2.0)
	sounds["hit_player"] = _to_stream(b)
	b = _buf(0.35); _tone(b, 0, 0.3, 500, 80, "saw", 0.35, 1.5); _noise(b, 0, 0.12, 0.4, 0.3, 2.0)
	sounds["death"] = _to_stream(b)
	b = _buf(0.5); _tone(b, 0, 0.14, 988, 1319, "sine", 0.35, 1.0); _tone(b, 0.07, 0.4, 1319, 1319, "sine", 0.3, 2.5)
	sounds["stun"] = _to_stream(b)
	# --- Pickups / Belohnung
	b = _buf(0.12); _tone(b, 0, 0.1, 1100, 1700, "sine", 0.28, 2.0)
	sounds["xp"] = _to_stream(b)
	b = _buf(0.25); _tone(b, 0, 0.07, 988, 988, "square", 0.22, 1.0); _tone(b, 0.06, 0.2, 1319, 1319, "square", 0.22, 2.5)
	sounds["coin"] = _to_stream(b)
	b = _buf(0.6); for k in 3: _tone(b, k * 0.09, 0.3, [523.0, 659.0, 784.0][k], [523.0, 659.0, 784.0][k], "sine", 0.3, 2.0)
	sounds["heal"] = _to_stream(b)
	b = _buf(1.2)
	for k in 5: _tone(b, k * 0.1, 0.5, [523.0, 659.0, 784.0, 1047.0, 1319.0][k], [523.0, 659.0, 784.0, 1047.0, 1319.0][k], "square", 0.17, 2.0)
	for k in 5: _tone(b, k * 0.1, 0.6, [523.0, 659.0, 784.0, 1047.0, 1319.0][k] * 2.0, [523.0, 659.0, 784.0, 1047.0, 1319.0][k] * 2.0, "sine", 0.18, 2.5)
	sounds["rare"] = _to_stream(b)
	b = _buf(0.7); for k in 4: _tone(b, k * 0.08, 0.35, [440.0, 554.0, 659.0, 880.0][k], [440.0, 554.0, 659.0, 880.0][k], "tri", 0.4, 2.0)
	sounds["levelup"] = _to_stream(b)
	b = _buf(0.25); _noise(b, 0, 0.03, 0.7, 0.9, 1.0); _tone(b, 0, 0.12, 700, 300, "square", 0.25, 3.0); _tone(b, 0.07, 0.15, 1000, 1000, "sine", 0.2, 3.0)
	sounds["buy"] = _to_stream(b)
	b = _buf(0.3); _tone(b, 0, 0.12, 120, 100, "square", 0.3, 1.0); _tone(b, 0.1, 0.18, 100, 80, "square", 0.3, 2.0)
	sounds["denied"] = _to_stream(b)
	b = _buf(0.4); _noise(b, 0, 0.35, 0.6, 0.15, 1.2); _tone(b, 0, 0.3, 300, 900, "saw", 0.1, 2.0)
	sounds["erase"] = _to_stream(b)
	b = _buf(0.3); _noise(b, 0, 0.1, 0.8, 0.25, 2.5); _tone(b, 0, 0.25, 110, 55, "sine", 0.7, 2.5)
	sounds["stamp"] = _to_stream(b)
	b = _buf(0.12); _noise(b, 0, 0.04, 0.5, 0.8, 2.0); _tone(b, 0, 0.08, 1800, 1200, "square", 0.12, 3.0)
	sounds["click"] = _to_stream(b)
	b = _buf(0.15); _tone(b, 0, 0.1, 600, 800, "sine", 0.2, 2.0)
	sounds["hover"] = _to_stream(b)
	# --- Schulglocke, Fach-Jingles, Durchsagen
	b = _buf(1.8)
	for p in [[880.0, 0.5], [1760.0, 0.3], [2640.0, 0.2], [3520.0, 0.12]]:
		_tone(b, 0, 1.7, p[0], p[0], "sine", p[1], 1.6)
	_tone(b, 0.45, 1.3, 880, 880, "sine", 0.35, 1.6)
	sounds["bell"] = _to_stream(b)
	b = _buf(0.7); for k in 4: _tone(b, k * 0.07, 0.15, [1200.0, 1800.0, 1500.0, 2000.0][k], [1200.0, 1800.0, 1500.0, 2000.0][k], "tri", 0.3, 3.0); _tone(b, 0.35, 0.3, 400, 120, "square", 0.2, 2.0)
	sounds["phase_Physik"] = _to_stream(b)
	b = _buf(0.9); _tone(b, 0, 0.2, 2300, 2300, "sine", 0.3, 1.0, 0.06); _tone(b, 0.22, 0.4, 2300, 2100, "sine", 0.3, 1.5, 0.06); _noise(b, 0.0, 0.5, 0.05, 0.2, 1.0)
	for k in 3: _tone(b, 0.5 + k * 0.1, 0.1, 160, 90, "sine", 0.5, 2.0)
	sounds["phase_Sport"] = _to_stream(b)
	b = _buf(0.9); for k in 8: _tone(b, k * 0.07, 0.15, _rng.randf_range(200, 420), _rng.randf_range(500, 900), "sine", 0.25, 2.0)
	_noise(b, 0, 0.8, 0.18, 0.25, 1.0)
	sounds["phase_Chemie"] = _to_stream(b)
	b = _buf(0.9); _tone(b, 0, 0.35, 659, 659, "sine", 0.4, 2.0); _tone(b, 0.35, 0.55, 523, 523, "sine", 0.4, 2.5); _tone(b, 0, 0.35, 659 * 2, 659 * 2, "sine", 0.12, 2.0)
	sounds["chime"] = _to_stream(b)
	# Rektor-Gemurmel: abgehackte Saegezahn-Silben
	b = _buf(1.1)
	var t := 0.05
	while t < 0.95:
		var f := _rng.randf_range(90, 150)
		_tone(b, t, 0.08, f, f * _rng.randf_range(0.8, 1.3), "saw", 0.3, 1.5)
		_tone(b, t, 0.08, f * 2.0, f * 2.2, "square", 0.08, 1.5)
		t += _rng.randf_range(0.08, 0.14)
	sounds["rektor"] = _to_stream(b)
	b = _buf(0.5); _tone(b, 0, 0.18, 880, 880, "square", 0.25, 1.0); _tone(b, 0.2, 0.25, 880, 880, "square", 0.25, 1.5)
	sounds["warn"] = _to_stream(b)
	b = _buf(1.4); _tone(b, 0, 1.2, 200, 1800, "saw", 0.2, 1.0); _tone(b, 0, 1.2, 205, 1810, "square", 0.15, 1.0); for k in 3: _tone(b, 0.7 + k * 0.1, 0.5, [523.0, 659.0, 784.0][k] * 2.0, [523.0, 659.0, 784.0][k] * 2.0, "sine", 0.3, 2.0)
	sounds["evolution"] = _to_stream(b)
	b = _buf(1.0); _tone(b, 0, 0.9, 220, 50, "saw", 0.5, 1.2); _noise(b, 0, 0.4, 0.4, 0.2, 1.5)
	sounds["boss_roar"] = _to_stream(b)
	# --- Waffen
	b = _buf(0.2); _tone(b, 0, 0.15, 900, 300, "square", 0.22, 2.0)
	sounds["shoot_water"] = _to_stream(b)
	b = _buf(0.4); _noise(b, 0, 0.35, 0.35, 0.25, 0.8)
	sounds["shoot_flame"] = _to_stream(b)
	b = _buf(0.3); _noise(b, 0, 0.25, 0.35, 0.3, 1.2); _tone(b, 0, 0.25, 160, 380, "tri", 0.18, 2.0)
	sounds["shoot_mop"] = _to_stream(b)
	b = _buf(0.5); _tone(b, 0, 0.45, 80, 45, "sine", 0.8, 2.0); _tone(b, 0, 0.3, 160, 90, "square", 0.2, 3.0)
	sounds["shoot_mega"] = _to_stream(b)
	b = _buf(0.3); _tone(b, 0, 0.25, 1400, 1800, "tri", 0.25, 2.0); _tone(b, 0.05, 0.2, 2100, 2100, "sine", 0.12, 3.0)
	sounds["shoot_compass"] = _to_stream(b)
	b = _buf(0.1); _tone(b, 0, 0.06, 500, 900, "sine", 0.28, 2.0)
	sounds["shoot_pea"] = _to_stream(b)
	b = _buf(0.15); _noise(b, 0, 0.03, 0.5, 0.9, 1.0); _tone(b, 0, 0.08, 1500, 800, "square", 0.18, 3.0)
	sounds["shoot_stapler"] = _to_stream(b)
	b = _buf(0.35); _tone(b, 0, 0.3, 200, 500, "sine", 0.4, 2.0); _noise(b, 0, 0.1, 0.2, 0.4, 2.0)
	sounds["shoot_chalk"] = _to_stream(b)
	b = _buf(0.8); _noise(b, 0, 0.7, 0.4, 0.2, 1.0); _tone(b, 0, 0.6, 90, 200, "saw", 0.3, 1.5)
	sounds["shoot_steam"] = _to_stream(b)
	b = _buf(0.45); _noise(b, 0, 0.1, 0.5, 0.5, 2.0); _tone(b, 0, 0.4, 260, 90, "saw", 0.4, 1.5)
	sounds["explosion"] = _to_stream(b)
	b = _buf(0.25); _noise(b, 0, 0.2, 0.35, 0.3, 1.5); _tone(b, 0, 0.2, 300, 600, "sine", 0.2, 2.0)
	sounds["dash"] = _to_stream(b)
	b = _buf(0.7)
	for p in [[420.0, 0.4], [630.0, 0.3], [1100.0, 0.2], [1700.0, 0.15]]:
		_tone(b, 0, 0.6, p[0], p[0] * 0.98, "sine", p[1], 2.5)
	_noise(b, 0, 0.05, 0.5, 0.8, 2.0)
	sounds["locker"] = _to_stream(b)
	b = _buf(0.35); _noise(b, 0, 0.1, 0.5, 0.2, 2.0); _tone(b, 0, 0.3, 120, 70, "sine", 0.7, 2.0)
	sounds["kick"] = _to_stream(b)
	b = _buf(0.3); _tone(b, 0, 0.25, 600, 1200, "sine", 0.3, 1.5); _tone(b, 0.05, 0.2, 800, 1600, "sine", 0.2, 1.5)
	sounds["perfect"] = _to_stream(b)
	b = _buf(0.3); _tone(b, 0, 0.1, 300, 150, "square", 0.2, 1.0); _noise(b, 0, 0.2, 0.2, 0.1, 2.0)
	sounds["splat"] = _to_stream(b)

# ---------------------------------------------------------------- Musik
func _make_music(track: String) -> AudioStreamWAV:
	# 4 Takte Chiptune; "run" = treibend, "menu" = ruhiger
	var bpm := 138.0 if track == "run" else 92.0
	var step := 60.0 / bpm / 2.0   # Achtel
	var steps := 32
	var dur := step * steps
	var b := PackedFloat32Array()
	b.resize(int(dur * MUSIC_RATE))
	var root := [110.0, 110.0, 130.8, 98.0]   # Am, Am, C, G (Bass je Takt)
	var arp_a := [1.0, 1.5, 2.0, 1.5, 1.2, 1.8, 2.4, 1.8]
	for bar in 4:
		for s in 8:
			var t0 := (bar * 8 + s) * step
			var f: float = root[bar]
			if track == "run":
				_m_note(b, t0, step * 0.9, f * (1.0 if s % 2 == 0 else 2.0), "pulse", 0.2)
				_m_note(b, t0, step * 0.7, f * 4.0 * arp_a[s] * 0.5, "tri", 0.1)
				if s % 2 == 0:
					_m_note(b, t0, 0.1, 120.0, "sine", 0.35, true)
				else:
					_m_hat(b, t0, 0.04, 0.08)
			else:
				if s % 2 == 0:
					_m_note(b, t0, step * 1.8, f, "sine", 0.28)
				_m_note(b, t0, step * 1.2, f * 4.0 * arp_a[s] * 0.5, "tri", 0.09)
	return _to_stream(b, MUSIC_RATE, true)

func _m_note(b: PackedFloat32Array, start: float, dur: float, freq: float, kind: String, vol: float, kick: bool = false) -> void:
	var s0 := int(start * MUSIC_RATE)
	var n := int(dur * MUSIC_RATE)
	var ph := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / n
		var f := freq * (1.0 + (1.0 - t) * 1.5) if kick else freq
		ph += f / MUSIC_RATE
		b[idx] += _wave(kind, ph) * vol * pow(1.0 - t, 1.5) * minf(1.0, float(i) / 40.0)

func _m_hat(b: PackedFloat32Array, start: float, dur: float, vol: float) -> void:
	var s0 := int(start * MUSIC_RATE)
	var n := int(dur * MUSIC_RATE)
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		b[idx] += _rng.randf_range(-1.0, 1.0) * vol * (1.0 - float(i) / n)
