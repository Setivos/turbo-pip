extends Node
## Autoload "Sfx": tiny synthesizer. Every sound is generated in code at start-up,
## so the project ships with no audio files.

const RATE := 22050
const STEP := 0.17   # music step length (s)

var _sounds := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _music := AudioStreamPlayer.new()
var _music_cache := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music.volume_db = -6.0
	add_child(_music)
	# [freq, duration, wave, volume, slide, delay]
	_sounds = {
		"jump": _render([[330, .14, "square", .08, 330, 0]]),
		"dbl": _render([[520, .1, "triangle", .1, 400, 0], [780, .1, "triangle", .07, 300, .05]]),
		"gem": _render([[1200, .06, "square", .06, 0, 0], [1600, .08, "square", .05, 0, .05]]),
		"crystal": _render([[880, .12, "triangle", .1, 0, 0], [1100, .12, "triangle", .1, 0, .07], [1320, .12, "triangle", .1, 0, .14], [1760, .12, "triangle", .1, 0, .21]]),
		"stomp": _render([[220, .12, "square", .12, -150, 0]]),
		"hurt": _render([[300, .3, "sawtooth", .12, -220, 0]]),
		"spring": _render([[200, .25, "triangle", .14, 700, 0]]),
		"win": _render([[523, .16, "square", .08, 0, 0], [659, .16, "square", .08, 0, .12], [784, .16, "square", .08, 0, .24], [1046, .16, "square", .08, 0, .36], [784, .16, "square", .08, 0, .48], [1046, .2, "square", .08, 0, .6]]),
		"lose": _render([[400, .2, "triangle", .1, 0, 0], [330, .2, "triangle", .1, 0, .15], [260, .2, "triangle", .1, 0, .3], [200, .25, "triangle", .1, 0, .45]]),
		"pop": _render([[900, .08, "square", .08, -500, 0]]),
		"click": _render([[660, .05, "square", .05, 0, 0]]),
		"check": _render([[660, .1, "triangle", .1, 0, 0], [990, .15, "triangle", .1, 0, .1]]),
	}

func play(name: String) -> void:
	if not Save.data.sound or not _sounds.has(name):
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _sounds[name]
	p.play()

func music_start(world: int) -> void:
	music_stop()
	if not Save.data.sound:
		return
	world = posmod(world, 6)
	if not _music_cache.has(world):
		_music_cache[world] = _render_music(world)
	_music.stream = _music_cache[world]
	_music.stream_paused = false
	_music.play()

func music_stop() -> void:
	_music.stop()

func music_pause(paused: bool) -> void:
	_music.stream_paused = paused

# ---------------------------------------------------------------------------

static func _osc(wave: String, p: float) -> float:
	match wave:
		"square":
			return 1.0 if p < 0.5 else -1.0
		"triangle":
			return 4.0 * absf(p - 0.5) - 1.0
		"sawtooth":
			return 2.0 * p - 1.0
		_:
			return sin(p * TAU)

static func _add_tone(buf: PackedFloat32Array, f: float, dur: float, wave: String, vol: float, slide: float, start: float, wrap: bool) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var s0 := int(start * RATE)
	var f1 := maxf(30.0, f + slide)
	var phase := 0.0
	var size := buf.size()
	for i in n:
		var u := float(i) / n
		var freq := f * pow(f1 / f, u) if slide != 0.0 else f
		phase += freq / RATE
		var env := vol * pow(0.001 / vol, u)
		var idx := s0 + i
		if idx >= size:
			if not wrap:
				break
			idx %= size
		buf[idx] += _osc(wave, fmod(phase, 1.0)) * env
	return buf

static func _to_wav(buf: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i] * 2.6, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = buf.size()
	return w

func _render(tones: Array) -> AudioStreamWAV:
	var total := 0.0
	for t in tones:
		total = maxf(total, t[1] + t[5])
	var buf := PackedFloat32Array()
	buf.resize(int((total + 0.03) * RATE))
	for t in tones:
		buf = _add_tone(buf, t[0], t[1], t[2], t[3], t[4], t[5], false)
	return _to_wav(buf, false)

func _render_music(world: int) -> AudioStreamWAV:
	var scales := [[0, 4, 7, 9], [0, 3, 7, 10], [0, 2, 7, 9], [0, 4, 9, 11], [0, 3, 6, 10], [0, 4, 7, 11]]
	var bases := [262.0, 196.0, 233.0, 294.0, 174.0, 330.0]
	var sc: Array = scales[world]
	var base: float = bases[world]
	var pat := [0, 1, 2, 3, 2, 1, 0, 2]
	var steps := 32
	var buf := PackedFloat32Array()
	buf.resize(int(steps * STEP * RATE))
	for s in steps:
		var n: int = sc[pat[s % 8]] + (5 if s % 32 >= 16 else 0)
		buf = _add_tone(buf, base * pow(2.0, n / 12.0), .16, "triangle", .035, 0, s * STEP, true)
		if s % 4 == 0:
			buf = _add_tone(buf, base / 2.0 * pow(2.0, sc[(s >> 3) % 4] / 12.0), .3, "sine", .05, 0, s * STEP, true)
	return _to_wav(buf, true)
