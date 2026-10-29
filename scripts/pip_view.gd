extends Control
## Animated Pip preview used in menus (title screen, shop cards).

var skin := ""          # empty = currently equipped skin
var pip_scale := 1.0
var running_anim := true
var _t := 0.0

func _process(delta: float) -> void:
	if is_visible_in_tree():
		_t += delta
		queue_redraw()

func _draw() -> void:
	var s := skin if skin != "" else String(Save.data.skin)
	PipArt.draw_pip(self, size / 2.0 + Vector2(0, 2 * pip_scale), {"t": _t, "scale": pip_scale, "run": running_anim, "skin": s})
