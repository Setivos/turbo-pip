class_name PipArt
extends RefCounted
## Procedural drawing helpers: Pip (the hero), ellipses, crystals, hearts.

static func ellipse_pts(c: Vector2, rx: float, ry: float, rot := 0.0, seg := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cr := cos(rot)
	var sr := sin(rot)
	for i in seg:
		var a := TAU * i / seg
		var x := cos(a) * rx
		var y := sin(a) * ry
		pts.append(c + Vector2(x * cr - y * sr, x * sr + y * cr))
	return pts

static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot := 0.0) -> void:
	ci.draw_colored_polygon(ellipse_pts(c, rx, ry, rot), col)

static func quad(a: Vector2, b: Vector2, c: Vector2, n := 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	return pts

static func skin_colors(id: String, t: float) -> Dictionary:
	var s: Dictionary = WorldData.SKINS[0]
	for k in WorldData.SKINS:
		if k.id == id:
			s = k
	if s.body != null:
		return s
	var h := fmod(t * 90.0, 360.0) / 360.0
	return {"body": Color.from_hsv(h, 0.6, 0.97), "dark": Color.from_hsv(h, 0.75, 0.55),
		"scarf": Color.from_hsv(fmod(h + 0.5, 1.0), 0.55, 1.0)}

## Draws Pip centred on `pos`. opt keys: t, scale, run, air, spin, hurt, skin
static func draw_pip(ci: CanvasItem, pos: Vector2, opt: Dictionary) -> void:
	var t: float = opt.get("t", 0.0)
	var sc: float = opt.get("scale", 1.0)
	var c := skin_colors(opt.get("skin", Save.data.skin), t)
	var run := sin(t * 22.0) if opt.get("run", false) else 0.0
	var spin: float = opt.get("spin", 0.0)
	# feet (not rotated)
	ci.draw_set_transform(pos, 0.0, Vector2(sc, sc))
	if opt.get("air", false):
		ellipse(ci, Vector2(-5, 10), 4, 3, c.dark)
		ellipse(ci, Vector2(6, 9), 4, 3, c.dark)
	else:
		ellipse(ci, Vector2(-5 + run * 4, 11), 4.5, 3, c.dark)
		ellipse(ci, Vector2(5 - run * 4, 11), 4.5, 3, c.dark)
	ci.draw_set_transform(pos, spin, Vector2(sc, sc))
	# scarf tail
	ci.draw_polyline(quad(Vector2(-6, 2), Vector2(-14, sin(t * 16) * 3), Vector2(-20, 4 + sin(t * 16 + 1) * 4)), c.scarf, 4.0, true)
	# body
	ci.draw_circle(Vector2.ZERO, 11, c.body)
	ellipse(ci, Vector2(-3, -5), 5, 3, Color(1, 1, 1, .25), -0.5)
	ellipse(ci, Vector2(0, 4), 10.5, 3, c.scarf)
	# leaf sprout
	ci.draw_polyline(quad(Vector2(0, -10), Vector2(1, -15), Vector2(3, -17), 5), Color("#2f9e44"), 2.0, true)
	ellipse(ci, Vector2(6, -17), 5, 2.6, Color("#69db7c"), -0.4 + sin(t * 6) * 0.15)
	# eyes
	var ink := Color("#1d1b2f")
	if opt.get("hurt", false):
		ci.draw_line(Vector2(1, -5), Vector2(5, -1), ink, 2)
		ci.draw_line(Vector2(5, -5), Vector2(1, -1), ink, 2)
	elif int(t * 10) % 40 == 0:
		ci.draw_rect(Rect2(1, -3, 4, 1.5), ink)
		ci.draw_rect(Rect2(6.5, -3, 3.5, 1.5), ink)
	else:
		ellipse(ci, Vector2(3, -3), 2, 3, ink)
		ellipse(ci, Vector2(8, -3), 1.8, 2.8, ink)
		ci.draw_rect(Rect2(3, -5, 1, 1), Color.WHITE)
		ci.draw_rect(Rect2(8, -5, 1, 1), Color.WHITE)
	ci.draw_circle(Vector2(9, 1.5), 2, Color(1, 0.47, 0.55, 0.5))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

static func crystal(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, -14) * s, c + Vector2(10, -4) * s, c + Vector2(6, 12) * s,
		c + Vector2(-6, 12) * s, c + Vector2(-10, -4) * s]), col)

static func heart(ci: CanvasItem, x: float, y: float, col: Color) -> void:
	ci.draw_circle(Vector2(x - 4.5, y + 4), 4.8, col)
	ci.draw_circle(Vector2(x + 4.5, y + 4), 4.8, col)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(x - 9.2, y + 5.5), Vector2(x + 9.2, y + 5.5), Vector2(x, y + 16)]), col)
