extends Node2D
## Gameplay: auto-run platforming (levels, endless, gem rush) and the balloon
## mini-game. Physics runs at a fixed 120 Hz; everything is drawn in _draw().

signal ended(info: Dictionary)
signal toast(text: String)

const T := WorldData.T
const VH := WorldData.VH
const GRAV := 1500.0
const DT := 1.0 / 120.0

var mode := ""          # "level", "endless", "rush", "balloons"
var w := 0
var l := 0
var running := false
var paused := false
var L: Dictionary = {}
var P: Dictionary = {}
var gen: LevelGen
var cam := 0.0
var time := 0.0
var time_left := INF
var dist := 0
var pressed := false
var particles: Array = []
var floaters: Array = []
var balloons: Array = []
var b_score := 0
var b_spawn := 0.0
var _acc := 0.0
var _font: Font
var _hud_box := StyleBoxFlat.new()

func _ready() -> void:
	_font = ThemeDB.fallback_font
	_hud_box.bg_color = Color(0, 0, 0, .3)
	_hud_box.set_corner_radius_all(15)

func vw() -> float:
	return get_viewport_rect().size.x

# ----------------------------------------------------------------- starting

func start_level(world: int, level: int) -> void:
	mode = "level"
	w = world
	l = level
	L = LevelGen.build_level(w, l)
	_setup_run()
	P.speed = WorldData.world(w).speed
	time_left = 90.0 + l * 5
	toast.emit("%d-%d  %s" % [w + 1, l + 1, WorldData.world(w).name])
	Sfx.music_start(w)

func start_mini(kind: String) -> void:
	mode = kind
	if kind == "balloons":
		_start_balloons()
		return
	w = 0
	gen = LevelGen.new(randi(), 0, .25 if kind == "rush" else 0.0)
	gen.start()
	L = gen.L
	for i in 8:
		_endless_next()
	_setup_run()
	P.speed = 150.0
	time_left = 60.0 if kind == "rush" else INF
	dist = 0
	toast.emit("Chrono gemmes !" if kind == "rush" else "Course infinie !")
	Sfx.music_start(2 if kind == "rush" else 0)

func retry() -> void:
	if mode == "level":
		start_level(w, l)
	else:
		start_mini(mode)

func next_level():
	var nw := w
	var nl := l + 1
	if nl >= WorldData.LEVELS_PER_WORLD:
		nw += 1
		nl = 0
	if nw >= WorldData.WORLDS.size():
		return null
	return [nw, nl]

func _endless_next() -> void:
	gen.diff = clampf(gen.cx * T / 40000.0, 0.0, 1.0) if mode == "endless" else .25
	gen.world = int(gen.cx / 150) % 6
	if mode == "rush":
		gen.chunk(gen.pick(["flat", "gap", "up", "down", "ledges", "plats", "spring", "wall", "clouds"]))
		gen.gem_line(gen.cx - 6, gen.g - 1, 3)
	else:
		gen.next()

func _setup_run() -> void:
	var y0: float = L.solids[0].y
	P = {"x": 3.0 * T, "y": y0 - 22, "w": 18.0, "h": 22.0, "vx": 0.0, "vy": 0.0, "onG": true,
		"ground": null, "jump_hold": 0.0, "dbl": true, "coyote": 0.0, "buffer": 0.0, "spin": 0.0,
		"inv": 0.0, "hurt_t": 0.0, "hearts": 3, "gems": 0, "speed": 150.0,
		"check": Vector2(3.0 * T, y0)}
	cam = 0.0
	time = 0.0
	particles.clear()
	floaters.clear()
	running = true
	paused = false
	pressed = false
	_acc = 0.0
	visible = true

func end_run() -> void:
	running = false
	paused = false
	Sfx.music_stop()

func set_paused(p: bool) -> void:
	paused = p
	Sfx.music_pause(p)

# -------------------------------------------------------------------- input

func _unhandled_input(ev: InputEvent) -> void:
	if not running or paused:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			if mode == "balloons":
				_balloon_tap(make_input_local(ev).position)
			else:
				press()
		else:
			release()
		get_viewport().set_input_as_handled()
	elif ev is InputEventKey and not ev.echo and (ev.keycode == KEY_SPACE or ev.keycode == KEY_UP):
		if ev.pressed:
			press()
		else:
			release()
		get_viewport().set_input_as_handled()

func press() -> void:
	if not running or paused or mode == "balloons":
		return
	pressed = true
	if not _try_jump():
		P.buffer = .12

func release() -> void:
	pressed = false
	if not P.is_empty():
		P.jump_hold = 0.0

func _try_jump() -> bool:
	if P.onG or P.coyote > 0:
		P.coyote = 0.0
		P.buffer = 0.0
		P.vy = -480.0
		P.onG = false
		P.ground = null
		P.jump_hold = .26
		Sfx.play("jump")
		_puff(P.x + P.w / 2, P.y + P.h, 4)
		return true
	elif P.dbl:
		P.vy = -410.0
		P.dbl = false
		P.jump_hold = .12
		P.spin = 0.0001
		Sfx.play("dbl")
		_puff(P.x + P.w / 2, P.y + P.h, 6)
		return true
	return false

# ------------------------------------------------------------------ physics

func _process(delta: float) -> void:
	if running and not paused:
		_acc += minf(delta, .05)
		while _acc >= DT:
			step(DT)
			_acc -= DT
			if not running:
				break
	else:
		_acc = 0.0
	queue_redraw()

static func _overlap(a: Dictionary, b: Dictionary) -> bool:
	return a.x < b.x + b.w and a.x + a.w > b.x and a.y < b.y + b.h and a.y + a.h > b.y

func step(dt: float) -> void:
	time += dt
	if mode == "balloons":
		_step_balloons(dt)
		return
	if time_left != INF:
		time_left -= dt
		if time_left <= 0:
			time_left = 0.0
			if mode == "rush":
				_finish_rush()
			else:
				_fail("Temps écoulé !")
			return
	for m in L.movers:
		var v := sin(time * m.sp + m.ph)
		var nx: float = m.ox + v * m.ax
		var ny: float = m.oy + v * m.ay
		m.dx = nx - m.x
		m.dy = ny - m.y
		m.x = nx
		m.y = ny
	for s in L.solids:
		if s.fall and s.ft >= 0:
			s.ft += dt
			if s.ft > .35:
				s.vy += GRAV * .6 * dt
				s.y += s.vy * dt
	# player
	if P.inv > 0: P.inv -= dt
	if P.hurt_t > 0: P.hurt_t -= dt
	if P.ground != null and P.ground.mover:
		P.x += P.ground.dx
		P.y += P.ground.dy
	P.vx = P.speed
	var gmul := 1.0
	if P.jump_hold > 0 and pressed and P.vy < 0:
		gmul = .42
		P.jump_hold -= dt
	P.vy = minf(P.vy + GRAV * gmul * dt, 900.0)
	if P.spin != 0:
		P.spin += dt * 16
		if P.spin > TAU:
			P.spin = 0.0
	var near: Array = []
	var x0: float = P.x - 80
	var x1: float = P.x + 120
	for s in L.solids:
		if s.x < x1 and s.x + s.w > x0:
			near.append(s)
	# horizontal
	P.x += P.vx * dt
	var blocked = null
	for s in near:
		if s.one:
			continue
		if _overlap(P, s) and P.vx > 0:
			P.x = s.x - P.w
			blocked = s
	if blocked != null and P.onG:
		var rise: float = (P.y + P.h) - blocked.y
		if rise > 0 and rise <= T + 2:   # auto-vault small steps
			P.vy = -330.0
			P.onG = false
			P.ground = null
			P.jump_hold = 0.0
	# vertical
	var prev_bottom: float = P.y + P.h
	P.y += P.vy * dt
	var was_g: bool = P.onG
	P.onG = false
	var landed = null
	for s in near:
		if not _overlap(P, s):
			continue
		if P.vy >= 0 and prev_bottom <= s.y + 8 + maxf(s.dy, 0.0):
			P.y = s.y - P.h
			P.vy = 0.0
			P.onG = true
			landed = s
		elif not s.one and P.vy < 0 and P.y >= s.y + s.h - 14:
			P.y = s.y + s.h
			P.vy = 0.0
			P.jump_hold = 0.0
	if landed == null and was_g and P.ground != null and P.ground.mover:
		var s: Dictionary = P.ground
		if P.x + P.w > s.x and P.x < s.x + s.w and absf((P.y + P.h) - s.y) < 6:
			P.y = s.y - P.h
			P.vy = 0.0
			P.onG = true
			landed = s
	P.ground = landed
	if P.onG:
		P.coyote = .09
	elif P.coyote > 0:
		P.coyote -= dt
	if P.buffer > 0:
		P.buffer -= dt
		if P.onG:
			_try_jump()
	if P.onG:
		P.dbl = true
		if not was_g:
			P.spin = 0.0
			_puff(P.x + P.w / 2, P.y + P.h, 3)
		if landed.fall and landed.ft < 0:
			landed.ft = 0.0
	# springs
	for s in L.springs:
		if P.vy >= 0 and _overlap(P, s) and prev_bottom <= s.y + 10:
			P.vy = -760.0
			P.onG = false
			P.ground = null
			P.dbl = true
			P.jump_hold = 0.0
			s.c = .25
			Sfx.play("spring")
		if s.c > 0:
			s.c -= dt
	# gems & crystals
	var pcx: float = P.x + P.w / 2
	var pcy: float = P.y + P.h / 2
	for gm in L.gems:
		if not gm.got and absf(gm.x - pcx) < 18 and absf(gm.y - pcy) < 20:
			gm.got = true
			P.gems += 1
			Sfx.play("gem")
			_sparkle(gm.x, gm.y, Color("#4cc9f0"), 6)
	for c in L.crystals:
		if not c.got and absf(c.x - pcx) < 22 and absf(c.y - pcy) < 24:
			c.got = true
			Sfx.play("crystal")
			_sparkle(c.x, c.y, Color("#f78fb3"), 16)
			_floater(c.x, c.y - 20, "Cristal !")
	# enemies
	for e in L.enemies:
		if not e.alive:
			e.dt += dt
			continue
		if e.k == "bat":
			e.x -= e.sp * dt
			e.y = e.by + sin(time * 3 + e.ph) * T * .9
		else:
			e.x += e.dir * e.sp * dt
			if e.x < e.min:
				e.x = e.min
				e.dir = 1.0
			if e.x > e.max:
				e.x = e.max
				e.dir = -1.0
		if absf(e.x - P.x) > 60:
			continue
		if _overlap(P, e):
			if e.k != "spiky" and P.vy > 0 and prev_bottom <= e.y + 10:
				e.alive = false
				e.dt = 0.0
				P.vy = -520.0 if pressed else -380.0
				P.dbl = true
				P.jump_hold = .15 if pressed else 0.0
				Sfx.play("stomp")
				_sparkle(e.x + e.w / 2, e.y + e.h / 2, Color.WHITE, 10)
				P.gems += 2
				_floater(e.x, e.y - 10, "+2")
			else:
				_hurt()
				if not running:
					return
	# hazards
	for h in L.hazards:
		if absf(h.x - P.x) > 80:
			continue
		if h.k == "fire":
			var ph: float = fmod(time + h.ph, h.per) / h.per
			h.act = minf(1.0, (ph - .55) * 10) if ph > .55 else 0.0
			if h.act <= 0:
				continue
			var hh: float = h.h * h.act
			if _overlap(P, {"x": h.x, "y": h.base - hh, "w": h.w, "h": hh}):
				_hurt()
			continue
		if _overlap(P, {"x": h.x + 3, "y": h.y + 3, "w": h.w - 6, "h": h.h - 3}):
			_hurt()
			if P.inv > 1.4:
				P.vy = -380.0
		if not running:
			return
	if not running:
		return
	# checkpoints
	for c in L.checks:
		if not c.on and P.x > c.x:
			c.on = true
			P.check = Vector2(c.x, c.y)
			Sfx.play("check")
			_floater(c.x, c.y - 50, "Point de passage")
	# falling into a pit
	if P.y > VH + 40:
		P.hearts -= 1
		Sfx.play("hurt")
		if mode == "rush":
			P.hearts = 3
			time_left = maxf(0.0, time_left - 5)
			_floater(P.x, 200, "-5 s")
		if P.hearts <= 0:
			_fail("Plus de cœurs !")
			return
		_respawn()
	# goal
	if mode == "level" and P.x + P.w > L.goal_x:
		_win()
		return
	# endless generation & cleanup
	if mode == "endless" or mode == "rush":
		while gen.cx * T < P.x + vw() * 2:
			_endless_next()
		if fmod(time, 2.0) < dt:
			var lim: float = P.x - vw()
			for key in ["solids", "gems", "enemies", "hazards", "springs", "pits", "decor", "movers"]:
				L[key] = L[key].filter(func(o): return o.x + o.get("w", 0.0) > lim)
			L.spots.clear()
		dist = int(P.x / T)
		if mode == "endless":
			P.speed = 150.0 + minf(70.0, dist / 25.0)
	cam = P.x - vw() * .3
	_step_particles(dt)

func _step_particles(dt: float) -> void:
	for p in particles:
		p.x += p.vx * dt
		p.y += p.vy * dt
		p.vy += 600 * dt
		p.life -= dt
	particles = particles.filter(func(p): return p.life > 0)
	for f in floaters:
		f.y -= 30 * dt
		f.life -= dt
	floaters = floaters.filter(func(f): return f.life > 0)

func _hurt() -> void:
	if P.inv > 0:
		return
	if mode == "rush":
		time_left = maxf(0.0, time_left - 3)
		_floater(P.x, P.y - 20, "-3 s")
		P.inv = 1.5
		P.hurt_t = .5
		Sfx.play("hurt")
		return
	P.hearts -= 1
	P.inv = 1.6
	P.hurt_t = .5
	Sfx.play("hurt")
	Input.vibrate_handheld(60)
	if P.hearts <= 0:
		_fail("Plus de cœurs !")

func _respawn() -> void:
	var x: float = P.check.x
	var y: float = P.check.y
	if mode != "level":
		var best = null
		var lastg = null
		for s in L.solids:
			if s.k == "ground" and s.x + s.w > P.x - vw() and s.x < P.x + vw() * 1.5:
				lastg = s
				if s.x > P.x - T * 4 and (best == null or s.x < best.x):
					best = s
		if best == null:
			best = lastg
		x = best.x + T
		y = best.y
	P.x = x
	P.y = y - P.h - 2
	P.vy = 0.0
	P.onG = false
	P.ground = null
	P.inv = 2.0
	P.dbl = true
	for s in L.solids:
		if s.fall:
			s.ft = -1.0
			s.vy = 0.0
			s.y = s.oy

# ------------------------------------------------------------------ results

func _win() -> void:
	end_run()
	Sfx.play("win")
	var got := 0
	for c in L.crystals:
		if c.got:
			got += 1
	var bonus := int(time_left / 5)
	Save.add_gems(P.gems + bonus)
	var key := Save.level_key(w, l)
	Save.data.levels[key] = maxi(Save.level_crystals(w, l), got)
	Save.persist()
	var last_one: bool = next_level() == null
	ended.emit({"title": "Niveau terminé !", "stars": got,
		"l1": "+%d gemmes · bonus temps +%d" % [P.gems, bonus],
		"l2": "Tu as terminé tout le jeu, bravo !" if last_one else "", "won": true})

func _fail(msg: String) -> void:
	end_run()
	Sfx.play("lose")
	if mode == "endless":
		var rec := Save.set_best("endless", dist)
		Save.add_gems(P.gems)
		ended.emit({"title": "Nouveau record !" if rec else msg, "stars": -1,
			"l1": "Distance : %d m (record %d m)" % [dist, Save.best("endless")],
			"l2": "+%d gemmes" % P.gems, "won": false})
		return
	var half: int = P.gems / 2
	Save.add_gems(half)
	ended.emit({"title": msg, "stars": -1, "l1": "Gemmes gardées : %d" % half,
		"l2": "Réessaie, tu y es presque !", "won": false})

func _finish_rush() -> void:
	end_run()
	Sfx.play("win")
	var rec := Save.set_best("rush", P.gems)
	Save.add_gems(P.gems)
	ended.emit({"title": "Nouveau record !" if rec else "Temps écoulé !", "stars": -1,
		"l1": "%d gemmes ramassées" % P.gems, "l2": "Record : %d" % Save.best("rush"), "won": false})

func _finish_balloons() -> void:
	end_run()
	Sfx.play("win")
	var rec := Save.set_best("balloons", b_score)
	var earned := b_score / 2
	Save.add_gems(earned)
	ended.emit({"title": "Nouveau record !" if rec else "Fini !", "stars": -1,
		"l1": "Score : %d (record %d)" % [b_score, Save.best("balloons")],
		"l2": "+%d gemmes" % earned, "won": false})

# ------------------------------------------------------------------ effects

func _puff(x: float, y: float, n: int) -> void:
	for i in n:
		particles.append({"x": x, "y": y, "vx": randf_range(-60, 60), "vy": -randf() * 80, "life": .35,
			"c": Color(1, 1, 1, .8), "r": 3.0})

func _sparkle(x: float, y: float, c: Color, n: int) -> void:
	for i in n:
		var a := randf() * TAU
		var s := 60 + randf() * 140
		particles.append({"x": x, "y": y, "vx": cos(a) * s, "vy": sin(a) * s - 80, "life": .5 + randf() * .3,
			"c": c, "r": 2.5})

func _floater(x: float, y: float, t: String) -> void:
	floaters.append({"x": x, "y": y, "t": t, "life": 1.1})

# ------------------------------------------------------------------ balloons

func _start_balloons() -> void:
	balloons.clear()
	b_score = 0
	b_spawn = 0.0
	time = 0.0
	particles.clear()
	floaters.clear()
	time_left = 30.0
	P = {"gems": 0, "hearts": 3, "x": 0.0}
	running = true
	paused = false
	visible = true
	toast.emit("Éclate-ballons !")
	Sfx.music_start(5)

func _step_balloons(dt: float) -> void:
	time_left -= dt
	if time_left <= 0:
		time_left = 0.0
		_finish_balloons()
		return
	b_spawn -= dt
	if b_spawn <= 0:
		b_spawn = maxf(.25, .7 - time * .012)
		var r := randf()
		var k := "gold" if r < .12 else ("storm" if r < .3 else "color")
		balloons.append({"x": 30 + randf() * (vw() - 60), "y": VH + 30, "k": k,
			"vy": -(50 + randf() * 50 + time * 2), "hue": randf(), "ph": randf() * 6,
			"r": 16.0 if k == "gold" else 20.0, "pop": false})
	for b in balloons:
		b.y += b.vy * dt
		b.x += sin(time * 2 + b.ph) * 20 * dt
	balloons = balloons.filter(func(b): return b.y > -50 and not b.pop)
	_step_particles(dt)

func _balloon_tap(p: Vector2) -> void:
	for i in range(balloons.size() - 1, -1, -1):
		var b: Dictionary = balloons[i]
		if Vector2(b.x, b.y).distance_to(p) < b.r + 12:
			b.pop = true
			if b.k == "storm":
				b_score = maxi(0, b_score - 5)
				Sfx.play("hurt")
				_floater(b.x, b.y, "-5")
				_sparkle(b.x, b.y, Color("#555555"), 10)
			else:
				var v := 5 if b.k == "gold" else 1
				b_score += v
				Sfx.play("pop")
				_floater(b.x, b.y, "+%d" % v)
				_sparkle(b.x, b.y, Color("#ffd43b") if b.k == "gold" else Color.from_hsv(b.hue, .65, .95), 10)
			return

# ================================================================= drawing

func _draw() -> void:
	if P.is_empty() or (not running and L.is_empty() and mode != "balloons"):
		return
	if mode == "balloons":
		_draw_balloons()
	elif not L.is_empty():
		_draw_level()

func _text(pos: Vector2, t: String, size: int, col: Color, center := true, outline := true) -> void:
	var al := HORIZONTAL_ALIGNMENT_CENTER if center else HORIZONTAL_ALIGNMENT_LEFT
	var p := pos - Vector2(200, 0) if center else pos
	var wd := 400.0 if center else -1.0
	if outline:
		draw_string_outline(_font, p, t, al, wd, size, 4, Color(0.11, 0.1, 0.18, .85))
	draw_string(_font, p, t, al, wd, size, col)

func _grad_rect(r: Rect2, top: Color, bottom: Color) -> void:
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))

func _cloud(x: float, y: float, col: Color) -> void:
	draw_circle(Vector2(x, y), 18, col)
	draw_circle(Vector2(x + 20, y - 8), 22, col)
	draw_circle(Vector2(x + 42, y), 16, col)

func _draw_bg(wi: int) -> void:
	var W := WorldData.world(wi)
	var VW := vw()
	_grad_rect(Rect2(0, 0, VW, VH), W.sky[0], W.sky[1])
	if wi == 2:
		draw_circle(Vector2(VW * .75, 80), 40, Color(1, .94, .7, .8))
	if wi == 1 or wi == 4:
		var c := Color(.7, .63, 1, .5) if wi == 1 else Color(1, .55, .23, .35)
		for i in 14:
			var x := fposmod(i * 137 - cam * .1, VW + 60) - 30
			draw_colored_polygon(PackedVector2Array([Vector2(x, 0), Vector2(x + 10, 30 + (i % 3) * 18), Vector2(x + 20, 0)]), c)
	if wi in [0, 2, 3, 5]:
		for i in 6:
			_cloud(fposmod(i * 211 - cam * .15, VW + 160) - 80, 40 + (i * 53) % 90, Color(1, 1, 1, .8))
	# far layer
	var pts := PackedVector2Array([Vector2(0, VH)])
	var x := 0.0
	while x <= VW + 20:
		var wx := x + cam * .25
		var y: float
		if wi == 3:
			y = 200 - absf(fposmod(wx / 90.0, 2.0) - 1) * 90
		elif wi == 4:
			y = 220 - absf(sin(wx / 140.0)) * 80
		else:
			y = 220 + sin(wx / 120.0) * 30 + sin(wx / 47.0) * 10
		pts.append(Vector2(x, y))
		x += 20
	pts.append(Vector2(VW + 20, VH))
	draw_colored_polygon(pts, W.far)
	pts = PackedVector2Array([Vector2(0, VH)])
	x = 0.0
	while x <= VW + 20:
		var wx := x + cam * .5
		pts.append(Vector2(x, 260 + sin(wx / 90.0) * 22 + sin(wx / 31.0) * 6))
		x += 16
	pts.append(Vector2(VW + 20, VH))
	draw_colored_polygon(pts, W.near)
	if wi == 2:
		var cc := Color("#c98a4a")
		for i in 5:
			var cxp := fposmod(i * 260 - cam * .5, VW + 100) - 50
			draw_rect(Rect2(cxp, 230, 10, 40), cc)
			draw_rect(Rect2(cxp - 10, 240, 10, 6), cc)
			draw_rect(Rect2(cxp - 10, 228, 6, 16), cc)
			draw_rect(Rect2(cxp + 10, 236, 10, 6), cc)
			draw_rect(Rect2(cxp + 14, 226, 6, 16), cc)

func _draw_solid(s: Dictionary, W: Dictionary) -> void:
	var x := roundf(s.x - cam)
	var y := roundf(s.y)
	match s.k:
		"ground":
			draw_rect(Rect2(x, y, s.w, s.h), W.body)
			var i := 0.0
			while i < s.w:
				var j := float(T)
				while j < s.h:
					if int((i + j + s.x) / T) % 3 == 0:
						draw_rect(Rect2(x + i + 6, y + j + 6, 6, 6), W.body2)
					j += T
				i += T
			draw_rect(Rect2(x, y, s.w, 8), W.top)
			draw_rect(Rect2(x, y + 8, s.w, 3), Color(0, 0, 0, .12))
		"block":
			draw_rect(Rect2(x, y, s.w, s.h), W.body2)
			var i := 0.0
			while i < s.w:
				var j := 0.0
				while j < s.h:
					draw_rect(Rect2(x + i + 2, y + j + 2, T - 4, T - 4), W.body)
					j += T
				i += T
			draw_rect(Rect2(x, y, s.w, 5), W.top)
		"cloud":
			var i := 0.0
			while i < s.w:
				draw_circle(Vector2(x + i + 6, y + 4), 9, Color.WHITE)
				i += 12
			draw_rect(Rect2(x, y + 6, s.w, 5), Color("#e7dcff"))
		"fall":
			var sh := randf_range(-1.5, 1.5) if (s.ft >= 0 and s.ft < .35) else 0.0
			draw_rect(Rect2(x + sh, y, s.w, s.h), Color("#bfe6ff") if s.w0 == 3 else Color("#c4884b"))
			draw_rect(Rect2(x + sh + s.w / 2 - 1, y, 2, s.h), Color(0, 0, 0, .2))
			draw_rect(Rect2(x + sh, y + s.h - 3, s.w, 3), Color(0, 0, 0, .2))
		"mover":
			draw_rect(Rect2(x, y, s.w, s.h), Color("#7c5cff"))
			draw_rect(Rect2(x + 4, y + 3, s.w - 8, 3), Color("#ffc83d"))
		_:
			draw_rect(Rect2(x, y, s.w, s.h), Color("#9c6b3e"))
			draw_rect(Rect2(x, y, s.w, 4), W.top)
			draw_rect(Rect2(x + 4, y + s.h, 3, 6), Color("#7a5230"))
			draw_rect(Rect2(x + s.w - 7, y + s.h, 3, 6), Color("#7a5230"))

func _draw_enemy(e: Dictionary) -> void:
	var x: float = e.x - cam
	var y: float = e.y
	if not e.alive:
		if e.dt > .4:
			return
		draw_rect(Rect2(x, y + e.h - 6, e.w, 6), Color(.36, .23, .54, 1 - e.dt / .4))
		return
	match e.k:
		"walker":   # Grignot, the beetle
			var lg := sin(time * 14) * 2
			draw_rect(Rect2(x + 3, y + e.h - 4 + lg, 4, 4), Color("#3b2a55"))
			draw_rect(Rect2(x + e.w - 7, y + e.h - 4 - lg, 4, 4), Color("#3b2a55"))
			PipArt.ellipse(self, Vector2(x + e.w / 2, y + e.h / 2 + 1), e.w / 2, e.h / 2 - 1, Color("#7a4fd1"))
			PipArt.ellipse(self, Vector2(x + e.w / 2 + 2, y + e.h / 2 - 3), 6, 3, Color("#a98bf0"))
			draw_circle(Vector2(x + 4, y + 7), 3.5, Color.WHITE)
			draw_circle(Vector2(x + 3.5, y + 7.5), 1.8, Color("#1d1b2f"))
			draw_line(Vector2(x + 3, y + 3), Vector2(x - 2, y - 3), Color("#3b2a55"), 1.5)
		"spiky":    # Piquant, the urchin
			var c := Vector2(x + e.w / 2, y + e.h / 2)
			var pts := PackedVector2Array()
			for i in 16:
				var a := time * 2 + i * PI / 8
				pts.append(c + Vector2(cos(a), sin(a)) * (7.0 if i % 2 else 13.0))
			draw_colored_polygon(pts, Color("#2b8a3e"))
			draw_circle(c, 7, Color("#69db7c"))
			draw_rect(Rect2(c.x - 4, c.y - 2, 2, 3), Color("#1d1b2f"))
			draw_rect(Rect2(c.x - 1, c.y - 2, 2, 3), Color("#1d1b2f"))
		"bat":
			var f := sin(time * 18) * 6
			var dark := Color("#2d1f40")
			draw_colored_polygon(PackedVector2Array([Vector2(x + e.w / 2, y + 6), Vector2(x - 6, y + f), Vector2(x + 2, y + 10)]), dark)
			draw_colored_polygon(PackedVector2Array([Vector2(x + e.w / 2, y + 6), Vector2(x + e.w + 6, y + f), Vector2(x + e.w - 2, y + 10)]), dark)
			draw_circle(Vector2(x + e.w / 2, y + 7), 7, Color("#4a3570"))
			draw_rect(Rect2(x + e.w / 2 - 4, y + 5, 2, 2), Color("#ffd43b"))
			draw_rect(Rect2(x + e.w / 2 + 2, y + 5, 2, 2), Color("#ffd43b"))

func _current_world() -> int:
	if mode == "level":
		return w
	for s in L.solids:
		if s.x + s.w > cam + vw() * .5:
			return s.w0
	return 0

func _draw_level() -> void:
	var VW := vw()
	var wi := _current_world()
	_draw_bg(wi)
	var vx0 := cam - T
	var vx1 := cam + VW + T
	for p in L.pits:
		if p.x + p.w < vx0 or p.x > vx1:
			continue
		var W := WorldData.world(p.w0)
		if W.pit != null:
			var x: float = p.x - cam
			draw_rect(Rect2(x, VH - 26, p.w, 26), W.pit)
			var i := 0.0
			while i < p.w:
				draw_rect(Rect2(x + i, VH - 26 + sin(time * 4 + i) * 3, 6, 3), Color("#ffd43b"))
				i += 12
	for d in L.decor:
		if d.x < vx0 or d.x > vx1:
			continue
		var x: float = d.x - cam
		match int(d.w0):
			0, 5:
				draw_circle(Vector2(x, d.y - 4), 3, [Color("#ff8fab"), Color("#ffd43b"), Color.WHITE][d.t])
				draw_rect(Rect2(x - 1, d.y - 2, 2, 3), Color("#2f9e44"))
			1:
				draw_colored_polygon(PackedVector2Array([Vector2(x - 5, d.y), Vector2(x, d.y - 14), Vector2(x + 5, d.y)]), Color("#b197fc"))
			3:
				draw_rect(Rect2(x - 4, d.y - 6, 8, 6), Color.WHITE)
			_:
				draw_rect(Rect2(x - 3, d.y - 5, 6, 5), Color(0, 0, 0, .25))
	for s in L.solids:
		if s.x + s.w < vx0 or s.x > vx1:
			continue
		_draw_solid(s, WorldData.world(s.w0))
	for s in L.springs:
		if s.x < vx0 or s.x > vx1:
			continue
		var x: float = s.x - cam
		var c := 6.0 if s.c > 0 else 0.0
		draw_rect(Rect2(x, s.y + c, s.w, 5), Color("#ff6b6b"))
		for i in 4:
			draw_line(Vector2(x + 3, s.y + 5 + c + i * (7 - c) / 4), Vector2(x + s.w - 3, s.y + 5 + c + (i + .5) * (7 - c) / 4), Color("#cccccc"), 2)
		draw_rect(Rect2(x, s.y + 10, s.w, 2), Color("#555555"))
	for h in L.hazards:
		if h.x < vx0 or h.x > vx1:
			continue
		var x: float = h.x - cam
		if h.k == "spike":
			for i in 3:
				draw_colored_polygon(PackedVector2Array([Vector2(x + i * 8, h.y + h.h), Vector2(x + i * 8 + 4, h.y), Vector2(x + i * 8 + 8, h.y + h.h)]), Color("#cfd4e0"))
		else:
			draw_rect(Rect2(x - 3, h.base - 6, h.w + 6, 6), Color("#555555"))
			var ph: float = fmod(time + h.ph, h.per) / h.per
			if h.act > 0:
				var hh: float = h.h * h.act
				var pts := PackedVector2Array([Vector2(x - 2, h.base - 6)])
				var cols := PackedColorArray([Color("#ff4d1f")])
				for i in 5:
					pts.append(Vector2(x + i * h.w / 4, h.base - hh + (i % 2) * 10 + sin(time * 30 + i) * 4))
					cols.append(Color(1, .8, .3, .6))
				pts.append(Vector2(x + h.w + 2, h.base - 6))
				cols.append(Color("#ff4d1f"))
				draw_polygon(pts, cols)
			elif ph > .4:
				draw_rect(Rect2(x + 2, h.base - 10, h.w - 4, 4), Color(1, .47, .16, .7))
	for gm in L.gems:
		if gm.got or gm.x < vx0 or gm.x > vx1:
			continue
		var p := Vector2(gm.x - cam, gm.y + sin(time * 4 + gm.x * .05) * 2)
		var sx := absf(cos(time * 3 + gm.x * .02)) * .5 + .5
		draw_set_transform(p, 0.0, Vector2(sx, 1))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -8.5), Vector2(8.5, 0), Vector2(0, 8.5), Vector2(-8.5, 0)]), Color("#4cc9f0"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, -8.5), Vector2(3.5, -5), Vector2(0, -1.5), Vector2(-3.5, -5)]), Color("#bff0ff"))
		draw_colored_polygon(PackedVector2Array([Vector2(0, 8.5), Vector2(3.5, 5), Vector2(0, 1.5), Vector2(-3.5, 5)]), Color("#2a8fb5"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for c in L.crystals:
		if c.got or c.x < vx0 or c.x > vx1:
			continue
		var p := Vector2(c.x - cam, c.y + sin(time * 3) * 3)
		draw_circle(p, 18 + sin(time * 5) * 2, Color(.97, .56, .7, .25))
		PipArt.crystal(self, p, 1.0, Color("#f78fb3"))
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, -14), p + Vector2(4, -4), p + Vector2(0, 10), p + Vector2(-4, -4)]), Color("#ffd6e7"))
	for c in L.checks:
		var x: float = c.x - cam
		if x < -30 or x > VW + 30:
			continue
		draw_rect(Rect2(x - 2, c.y - 46, 4, 46), Color("#6b4a2b"))
		draw_circle(Vector2(x, c.y - 50), 8, Color("#ffd43b") if c.on else Color("#555566"))
		if c.on:
			draw_circle(Vector2(x, c.y - 50), 16 + sin(time * 6) * 2, Color(1, .83, .23, .3))
	if L.goal_x > 0:
		var x: float = L.goal_x - cam
		var y: float = L.goal_y
		if x > -80 and x < VW + 80:
			var c := Vector2(x + 20, y - 40)
			draw_colored_polygon(PipArt.ellipse_pts(c, 18, 34), Color.from_hsv(fmod(time / 3.0, 1.0), .5, 1.0, .5))
			var ring := PipArt.ellipse_pts(c, 24, 40, 0.0, 28)
			ring.append(ring[0])
			draw_polyline(ring, Color("#7c5cff"), 8, true)
			for i in 6:
				var a := time * 2 + i
				draw_rect(Rect2(c.x + cos(a) * 14, c.y + sin(a * 1.3) * 28, 2, 2), Color.WHITE)
	for e in L.enemies:
		if e.x < vx0 or e.x > vx1:
			continue
		_draw_enemy(e)
	if not (P.inv > 0 and int(time * 16) % 2 == 0):
		PipArt.draw_pip(self, Vector2(P.x - cam + P.w / 2, P.y + P.h - 11),
			{"t": time, "run": P.onG, "air": not P.onG, "spin": P.spin, "hurt": P.hurt_t > 0})
	for p in particles:
		var c: Color = p.c
		c.a *= clampf(p.life * 2, 0, 1)
		draw_rect(Rect2(p.x - cam - p.r / 2, p.y - p.r / 2, p.r, p.r), c)
	for f in floaters:
		_text(Vector2(f.x - cam, f.y), f.t, 13, Color(1, 1, 1, clampf(f.life * 2, 0, 1)))
	_draw_hud()

func _draw_hud() -> void:
	var VW := vw()
	_hud_box.draw(get_canvas_item(), Rect2(8, 8, 250 if mode == "level" else 200, 30))
	if mode != "rush":
		for i in 3:
			PipArt.heart(self, 26 + i * 22, 14, Color("#ff6b6b") if i < P.hearts else Color(0, 0, 0, .3))
	var gx := 24.0 if mode == "rush" else 96.0
	draw_colored_polygon(PackedVector2Array([Vector2(gx, 14.5), Vector2(gx + 8.5, 23), Vector2(gx, 31.5), Vector2(gx - 8.5, 23)]), Color("#4cc9f0"))
	_text(Vector2(gx + 12, 30), str(P.gems), 18, Color.WHITE, false, false)
	if mode == "level":
		for i in 3:
			var got: bool = i < L.crystals.size() and L.crystals[i].got
			PipArt.crystal(self, Vector2(166 + i * 26, 24), .65, Color("#f78fb3") if got else Color(1, 1, 1, .25))
		var pr := clampf(P.x / L.goal_x, 0, 1)
		draw_rect(Rect2(VW / 2 - 80, 42, 160, 6), Color(0, 0, 0, .3))
		draw_rect(Rect2(VW / 2 - 80, 42, 160 * pr, 6), Color("#ffc83d"))
	if mode == "endless":
		_text(Vector2(gx + 60, 30), "%d m" % dist, 18, Color.WHITE, false, false)
	if time_left != INF:
		var t := int(ceil(time_left))
		_text(Vector2(VW / 2, 32), str(t), 24, Color("#ff6b6b") if t <= 10 else Color.WHITE)

func _draw_balloons() -> void:
	var VW := vw()
	_grad_rect(Rect2(0, 0, VW, VH), Color("#6ec6ff"), Color("#ffe1f0"))
	cam = time * 20
	for i in 6:
		_cloud(fposmod(i * 211 - cam * .5, VW + 160) - 80, 40 + (i * 53) % 200, Color(1, 1, 1, .8))
	for b in balloons:
		draw_polyline(PipArt.quad(Vector2(b.x, b.y + b.r), Vector2(b.x + 6, b.y + b.r + 14), Vector2(b.x, b.y + b.r + 28)), Color(0, 0, 0, .3), 1.0)
		if b.k == "storm":
			var g := Color("#555b6e")
			draw_circle(Vector2(b.x - 8, b.y), 12, g)
			draw_circle(Vector2(b.x + 8, b.y), 12, g)
			draw_circle(Vector2(b.x, b.y - 8), 13, g)
			draw_colored_polygon(PackedVector2Array([Vector2(b.x + 1, b.y), Vector2(b.x - 5, b.y + 12), Vector2(b.x, b.y + 10),
				Vector2(b.x - 2, b.y + 20), Vector2(b.x + 6, b.y + 6), Vector2(b.x + 1, b.y + 8)]), Color("#ffd43b"))
		else:
			var col := Color("#ffd43b") if b.k == "gold" else Color.from_hsv(b.hue, .65, .95)
			PipArt.ellipse(self, Vector2(b.x, b.y), b.r * .85, b.r, col)
			PipArt.ellipse(self, Vector2(b.x - b.r * .35, b.y - b.r * .4), b.r * .2, b.r * .3, Color(1, 1, 1, .45), -.4)
	PipArt.draw_pip(self, Vector2(VW / 2, VH - 24), {"t": time, "scale": 1.6})
	for p in particles:
		var c: Color = p.c
		c.a *= clampf(p.life * 2, 0, 1)
		draw_rect(Rect2(p.x - p.r / 2, p.y - p.r / 2, p.r, p.r), c)
	for f in floaters:
		_text(Vector2(f.x, f.y), f.t, 15, Color("#1d1b2f"), true, false)
	_text(Vector2(16, 32), "Score : %d" % b_score, 20, Color("#1d1b2f"), false, false)
	_text(Vector2(VW / 2, 32), str(int(ceil(time_left))), 24, Color("#d6336c") if time_left <= 5 else Color("#1d1b2f"), true, false)
