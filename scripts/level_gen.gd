class_name LevelGen
extends RefCounted
## Procedural level builder. A level is a list of "chunks" (gap, wall, enemy...)
## chosen from the current world's feature set, with seeded randomness so each
## numbered level is always the same.

const T := WorldData.T
const ROWS := WorldData.ROWS

var rng := RandomNumberGenerator.new()
var world := 0
var diff := 0.0
var cx := 0      # current tile column
var g := 12      # current ground row
var last := ""
var L := {
	"solids": [], "gems": [], "crystals": [], "enemies": [], "hazards": [], "springs": [],
	"movers": [], "checks": [], "spots": [], "pits": [], "decor": [],
	"goal_x": -1.0, "goal_y": 0.0, "width": 0.0,
}

func _init(sd: int, w: int, d: float) -> void:
	rng.seed = sd
	world = w
	diff = d

func r() -> float:
	return rng.randf()

func ri(a, b) -> int:
	return int(a) + int(floor(r() * (int(b) - int(a) + 1)))

func pick(a: Array):
	return a[mini(int(r() * a.size()), a.size() - 1)]

func _solid(x: float, y: float, w: float, h: float, k: String, one := false) -> Dictionary:
	return {"x": x, "y": y, "w": w, "h": h, "k": k, "one": one, "fall": false, "ft": -1.0,
		"vy": 0.0, "dx": 0.0, "dy": 0.0, "mover": false, "w0": world, "oy": y}

func ground(x0: int, x1: int, row: int) -> void:
	if x1 <= x0:
		return
	L.solids.append(_solid(x0 * T, row * T, (x1 - x0) * T, (ROWS - row) * T + 60, "ground"))
	if r() < .35:
		L.decor.append({"x": (x0 + r() * (x1 - x0)) * T, "y": row * T, "t": ri(0, 2), "w0": world})

func block(tx: float, ty: float, tw: float, th: float) -> void:
	L.solids.append(_solid(tx * T, ty * T, tw * T, th * T, "block"))

func ledge(tx: float, ty: float, tw: float, kind := "ledge") -> Dictionary:
	var s := _solid(tx * T, ty * T, tw * T, 10, kind, true)
	L.solids.append(s)
	return s

func gem(tx: float, ty: float) -> void:
	L.gems.append({"x": tx * T + T / 2.0, "y": ty * T + T / 2.0, "got": false})

func gem_line(tx: float, ty: float, n: int) -> void:
	for i in n:
		gem(tx + i, ty)

func gem_arc(tx: float, ty: float, n: int, h: float) -> void:
	for i in n:
		var u := 0.5 if n == 1 else float(i) / (n - 1)
		gem(tx + i, ty - round(sin(u * PI) * h))

func pit(x0: float, x1: float) -> void:
	L.pits.append({"x": x0 * T, "w": (x1 - x0) * T, "w0": world})

func flat(n: int, gems := true) -> int:
	var x := cx
	ground(x, x + n, g)
	if gems and r() < .7:
		if r() < .5:
			gem_line(x + 1, g - 1, mini(n - 2, 5))
		else:
			gem_arc(x + 1, g - 1, mini(n - 2, 5), 2)
	cx += n
	return x

func _enemy(k: String, x: float, y: float, w: float, h: float) -> Dictionary:
	return {"k": k, "x": x, "y": y, "w": w, "h": h, "min": 0.0, "max": 0.0, "dir": -1.0,
		"sp": 0.0, "alive": true, "dt": 0.0, "by": 0.0, "ph": 0.0}

func chunk(type: String) -> void:
	var d := diff
	match type:
		"flat":
			flat(ri(4, 8))
		"gap":
			flat(ri(2, 4), false)
			var w := ri(2, 2 + round(d * 3))
			var x := cx
			pit(x, x + w)
			gem_arc(x - 1, g - 2, w + 2, 2)
			L.spots.append({"x": x + w / 2.0, "row": g - 6})
			cx += w
			if r() < .5:
				g = clampi(g + pick([-1, 1]), 10, 13)
			flat(ri(3, 5), false)
		"up":
			flat(3, false)
			g = clampi(g - ri(1, 2), 9, 13)
			flat(ri(4, 6))
		"down":
			flat(3, false)
			g = clampi(g + ri(1, 2), 9, 13)
			flat(ri(4, 6))
		"wall":
			var x := flat(ri(8, 10), false)
			var h := ri(2, 2 + round(d))
			var w := ri(1, 2)
			block(x + 4, g - h, w, h)
			gem_line(x + 4, g - h - 1, w)
			gem_arc(x + 2, g - h - 1, w + 4, 1)
		"walker":
			var x := flat(ri(8, 11))
			var e := _enemy("walker", (x + 6) * T, g * T - 18, 22, 18)
			e.min = (x + 2) * T
			e.max = (x + 8) * T
			e.sp = 35 + d * 25
			L.enemies.append(e)
		"spiky":
			flat(2, false)
			var x := flat(ri(10, 12), false)
			var e := _enemy("spiky", (x + 6) * T, g * T - 20, 20, 20)
			e.min = (x + 5) * T
			e.max = (x + 7) * T
			e.sp = 20 + d * 15
			L.enemies.append(e)
			gem_arc(x + 3, g - 2, 5, 2)
		"spikes":
			var x := flat(ri(8, 10), false)
			var n := ri(1, 1 + round(d * 2))
			for i in n:
				L.hazards.append({"k": "spike", "x": (x + 4 + i) * T, "y": g * T - 12, "w": T, "h": 12})
			gem_arc(x + 3, g - 2, n + 2, 2)
		"ledges":
			var x := flat(ri(9, 12), false)
			var y1 := g - 3
			ledge(x + 2, y1, 3)
			gem_line(x + 2, y1 - 1, 3)
			if r() < .6:
				ledge(x + 6, y1 - 2, 3)
				gem_line(x + 6, y1 - 3, 3)
				L.spots.append({"x": x + 7.5, "row": y1 - 5})
		"plats":
			flat(2, false)
			var w := ri(6, 8 + round(d * 2))
			var x := cx
			pit(x, x + w)
			var n := 2 if w >= 8 else 1
			for i in n:
				var px := x + w / 2 - 1 if n == 1 else (x + 1 if i == 0 else x + w - 4)
				var py := g - ri(1, 2) - i
				ledge(px, py, 3)
				gem_line(px, py - 1, 3)
			L.spots.append({"x": x + w / 2.0, "row": g - 6})
			cx += w
			flat(ri(3, 4), false)
		"spring":
			var x := flat(ri(9, 11), false)
			L.springs.append({"x": (x + 3) * T + 2, "y": g * T - 12, "w": T - 4, "h": 12, "c": 0.0})
			for i in 5:
				gem(x + 4 + i, g - 6 - (1 if i == 2 else 0))
			L.spots.append({"x": x + 5, "row": g - 8})
		"tunnel":
			var x := flat(ri(9, 12), false)
			var n := cx - x
			block(x + 1, g - 5, n - 2, 2)
			gem_line(x + 2, g - 1, n - 4)
		"bat":
			var x := flat(ri(8, 10), false)
			var e := _enemy("bat", (x + 6) * T, (g - 3) * T, 20, 14)
			e.by = (g - 3) * T - 4
			e.ph = r() * 6
			e.sp = 20
			L.enemies.append(e)
			gem_line(x + 2, g - 1, 3)
		"fire":
			var x := flat(ri(8, 10), false)
			L.hazards.append({"k": "fire", "x": (x + 5) * T + 4, "y": (g - 3) * T, "w": T - 8, "h": 3 * T,
				"base": g * T, "ph": r() * 2.6, "per": 2.6, "act": 0.0})
			gem_arc(x + 3, g - 4, 5, 1)
		"falling":
			flat(2, false)
			var n := ri(2, 3)
			var w := n * 3 + 1
			var x := cx
			pit(x, x + w)
			for i in n:
				var s := ledge(x + 1 + i * 3, g - 1, 2, "fall")
				s.fall = true
				s.oy = s.y
				gem_line(x + 1 + i * 3, g - 2, 2)
			cx += w
			flat(ri(3, 4), false)
		"moving":
			flat(2, false)
			var w := ri(7, 8)
			var x := cx
			pit(x, x + w)
			var s := _solid((x + w / 2.0 - 1) * T, (g - 1) * T, 2 * T, 12, "mover", true)
			s.mover = true
			s.ox = s.x
			s.ax = 0.0
			s.ay = 2.0 * T
			s.ph = r() * 6
			s.sp = 1.6 + d * .6
			L.solids.append(s)
			L.movers.append(s)
			gem_line(x + w / 2.0 - 1, g - 4, 2)
			L.spots.append({"x": x + w / 2.0, "row": g - 7})
			cx += w
			flat(ri(3, 4), false)
		"clouds":
			flat(2, false)
			var n := ri(3, 4)
			var x0 := cx
			var x := x0
			for i in n:
				x += ri(2, 2 + round(d * 2))
				var row := clampi(g + ri(-2, 1), 8, 12)
				ledge(x, row, 3, "cloud")
				gem_line(x, row - 1, 3)
				x += 3
			x += ri(2, 3)
			pit(x0, x)
			L.spots.append({"x": (x0 + x) / 2.0, "row": g - 6})
			cx = x
			flat(ri(3, 4), false)

func checkpoint() -> void:
	var x := flat(6, false)
	L.checks.append({"x": (x + 3) * T, "y": g * T, "on": false})

func start() -> void:
	flat(10, false)

func goal() -> void:
	var x := flat(8, false)
	L.goal_x = (x + 4) * T
	L.goal_y = g * T
	ground(cx, cx + 40, g)
	cx += 40

func next() -> void:
	var f: Array = WorldData.world(world).feat
	var type: String = pick(f)
	if last == type and r() < .6:
		type = pick(f)
	last = type
	chunk(type)

static func build_level(w: int, l: int) -> Dictionary:
	var d := clampf(float(l) / (WorldData.LEVELS_PER_WORLD - 1) * .6 + w * .08, 0.0, 1.0)
	var G := LevelGen.new(1000 + w * 97 + l * 13, w, d)
	G.start()
	var length := 110 + l * 18 + w * 10
	var placed := false
	while G.cx < length:
		G.next()
		if not placed and G.cx > length / 2:
			G.checkpoint()
			placed = true
	G.goal()
	# three hidden crystals, spread along the level, placed on reachable "spots"
	var lv := G.L
	var spots: Array = lv.spots.filter(func(s): return s.x > 12)
	for k in 3:
		var target := length * (k + .6) / 3.4
		var best = null
		var bd := 1e9
		for s in spots:
			var dd := absf(s.x - target)
			var taken := false
			for c in lv.crystals:
				if absf(c.x - s.x * T) < 5 * T:
					taken = true
			if dd < bd and not taken:
				bd = dd
				best = s
		if best != null:
			lv.crystals.append({"x": best.x * T, "y": best.row * T + T / 2.0, "got": false})
		else:
			lv.crystals.append({"x": target * T, "y": 6.0 * T, "got": false})
	lv.width = G.cx * T
	return lv
