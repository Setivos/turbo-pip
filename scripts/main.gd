extends Node
## Menus, navigation (incl. Android back button), shop, chests and result screens.
## The whole UI is built in code so the project stays text-only and easy to diff.

const GOLD := Color("#ffc83d")
const MINT := Color("#38d9a9")
const CORAL := Color("#ff6b6b")
const VIOLET := Color("#7c5cff")
const INK := Color("#1d1b2f")
const CREAM := Color("#fff7e6")
const PipView := preload("res://scripts/pip_view.gd")

@onready var game: Node2D = $Game

var ui := CanvasLayer.new()
var root := Control.new()
var screens := {}
var stack: Array = []           # navigation history: [name, arg]
var gem_labels: Array[Label] = []
var pause_btn: Button
var toast_lbl: Label
var _toast_tween: Tween
var sound_btn: Button

# dynamic containers
var world_row: HBoxContainer
var level_grid: GridContainer
var level_title: Label
var mini_best := {}
var chest_grid: GridContainer
var chest_pot: Label
var chest_cash: Button
var chest_new: Button
var chest := {"pot": 0, "over": true, "items": [], "opened": 0}
var skin_grid: GridContainer
var res_title: Label
var res_l1: Label
var res_l2: Label
var res_stars: Control
var res_next: Button
var _stars := -1

func _ready() -> void:
	get_tree().set_auto_accept_quit(true)
	ui.layer = 10
	add_child(ui)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font_size = 18
	th.set_color("font_color", "Label", CREAM)
	root.theme = th
	ui.add_child(root)
	game.visible = false
	game.ended.connect(_on_game_ended)
	game.toast.connect(toast)
	_build_title()
	_build_worlds()
	_build_levels()
	_build_minis()
	_build_chests()
	_build_shop()
	_build_pause()
	_build_result()
	_build_hud()
	go("title")

# ================================================================ helpers

func _style(col: Color, pressed := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(16)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8 + (4 if pressed else 0)
	sb.content_margin_bottom = 8
	sb.border_width_bottom = 1 if pressed else 5
	sb.border_color = col.darkened(.4)
	return sb

func btn(text: String, col: Color, cb: Callable, font_size := 18) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _style(col))
	b.add_theme_stylebox_override("hover", _style(col.lightened(.08)))
	b.add_theme_stylebox_override("pressed", _style(col, true))
	var fc := INK if col.get_luminance() > .5 else Color.WHITE
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, fc)
	b.add_theme_font_size_override("font_size", font_size)
	b.custom_minimum_size = Vector2(130 if font_size >= 18 else 0, 0)
	b.pressed.connect(func():
		Sfx.play("click")
		cb.call())
	return b

func lbl(text: String, size := 18, col := CREAM, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color("#9a5414"))
	return l

func row(sep := 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", sep)
	return h

func gem_icon(sz := 14.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(sz, sz)
	c.draw.connect(func():
		var h := sz / 2.0
		c.draw_colored_polygon(PackedVector2Array([Vector2(h, 0), Vector2(sz, h), Vector2(h, sz), Vector2(0, h)]), Color("#4cc9f0")))
	return c

func crystal_row(get_count: Callable, sc := 0.6) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(3 * 26 * sc / .6, 30 * sc / .6)
	c.draw.connect(func():
		var n: int = get_count.call()
		for i in 3:
			var col := Color("#f78fb3") if i < n else Color(1, 1, 1, .2)
			PipArt.crystal(c, Vector2((i + .5) * c.size.x / 3.0, c.size.y / 2.0), sc, col))
	return c

## Creates a screen: background + centred column + optional top bar with back button.
func make_screen(name: String, back_text := "", overlay := false) -> VBoxContainer:
	var s := Control.new()
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.visible = false
	if overlay:
		var dim := ColorRect.new()
		dim.color = Color(.08, .07, .14, .62)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		s.add_child(dim)
	else:
		var bg := TextureRect.new()
		var gt := GradientTexture2D.new()
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0, .6, 1])
		gr.colors = PackedColorArray([Color("#2b2350"), INK, Color("#152d3f")])
		gt.gradient = gr
		gt.fill_from = Vector2(0, 0)
		gt.fill_to = Vector2(1, 1)
		bg.texture = gt
		bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg.stretch_mode = TextureRect.STRETCH_SCALE
		bg.set_anchors_preset(Control.PRESET_FULL_RECT)
		s.add_child(bg)
	var col := VBoxContainer.new()
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.offset_top = 44 if back_text != "" else 8
	col.offset_bottom = -8
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8)
	s.add_child(col)
	if back_text != "":
		var bar := HBoxContainer.new()
		bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
		bar.offset_left = 10
		bar.offset_right = -10
		bar.offset_top = 6
		var b := btn("‹ " + back_text, Color(1, 1, 1, .14), back, 15)
		b.add_theme_color_override("font_color", CREAM)
		bar.add_child(b)
		var sp := Control.new()
		sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.add_child(sp)
		var pill := PanelContainer.new()
		var ps := StyleBoxFlat.new()
		ps.bg_color = Color(0, 0, 0, .35)
		ps.set_corner_radius_all(14)
		ps.content_margin_left = 12
		ps.content_margin_right = 12
		ps.content_margin_top = 4
		ps.content_margin_bottom = 4
		pill.add_theme_stylebox_override("panel", ps)
		var ph := row(6)
		var gi := gem_icon()
		gi.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		ph.add_child(gi)
		var gl := lbl("0", 16)
		gem_labels.append(gl)
		ph.add_child(gl)
		pill.add_child(ph)
		bar.add_child(pill)
		s.add_child(bar)
	root.add_child(s)
	screens[name] = s
	return col

func refresh_gems() -> void:
	for g in gem_labels:
		g.text = str(int(Save.data.gems))

var _toast_y := 0.0
func toast(text: String) -> void:
	toast_lbl.text = text
	if _toast_tween:
		_toast_tween.kill()
	toast_lbl.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.4)
	_toast_tween.tween_property(toast_lbl, "modulate:a", 0.0, .3)

# ================================================================ navigation

func show_only(name: String) -> void:
	for k in screens:
		screens[k].visible = (k == name)
	refresh_gems()

func go(name: String, arg = null) -> void:
	stack.append([name, arg])
	_show_top()

func back() -> void:
	if stack.size() > 1:
		stack.pop_back()
	_show_top()

func _show_top() -> void:
	var e: Array = stack.back()
	match e[0]:
		"worlds": _render_worlds()
		"levels": _render_levels(e[1])
		"minis": _render_minis()
		"chests": _new_chests(false)
		"shop": _render_shop()
	game.visible = false
	pause_btn.visible = false
	show_only(e[0])

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		if game.running and not game.paused:
			_pause()

func _on_back() -> void:
	if game.running:
		if game.paused:
			_quit_run()
		else:
			_pause()
	elif screens.result.visible:
		_quit_run()
	elif stack.size() > 1:
		Sfx.play("click")
		back()
	else:
		get_tree().quit()

# ================================================================ screens

func _build_title() -> void:
	var c := make_screen("title")
	var pv := PipView.new()
	pv.pip_scale = 3.0
	pv.custom_minimum_size = Vector2(160, 96)
	pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(pv)
	c.add_child(lbl("TURBO PIP", 52, GOLD, 10))
	var sub := lbl("Cours, saute, attrape toutes les gemmes !", 15)
	sub.modulate.a = .8
	c.add_child(sub)
	var r := row()
	r.add_child(btn("Aventure", MINT, func(): go("worlds")))
	r.add_child(btn("Mini-jeux", VIOLET, func(): go("minis")))
	r.add_child(btn("Boutique", GOLD, func(): go("shop")))
	c.add_child(r)
	var r2 := row()
	sound_btn = btn("", Color(1, 1, 1, .14), _toggle_sound, 15)
	sound_btn.add_theme_color_override("font_color", CREAM)
	r2.add_child(sound_btn)
	c.add_child(r2)
	_sound_label()
	var hint := lbl("Touche l'écran pour sauter · Maintiens pour sauter plus haut · Touche en l'air pour un double saut", 12)
	hint.modulate.a = .7
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(hint)

func _sound_label() -> void:
	sound_btn.text = "Son : " + ("oui" if Save.data.sound else "non")

func _toggle_sound() -> void:
	Save.data.sound = not Save.data.sound
	Save.persist()
	_sound_label()

func _build_worlds() -> void:
	var c := make_screen("worlds", "Retour")
	c.add_child(lbl("Choisis un monde", 30, GOLD, 6))
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, 196)
	world_row = row(12)
	sc.add_child(world_row)
	c.add_child(sc)

func _render_worlds() -> void:
	for ch in world_row.get_children():
		ch.queue_free()
	for i in WorldData.WORLDS.size():
		var W: Dictionary = WorldData.WORLDS[i]
		var open := Save.is_unlocked(i, 0)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(170, 180)
		var col: Color = W.near if open else Color(.3, .3, .35)
		b.add_theme_stylebox_override("normal", _style(col))
		b.add_theme_stylebox_override("hover", _style(col.lightened(.06)))
		b.add_theme_stylebox_override("pressed", _style(col, true))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 12
		v.offset_right = -12
		v.offset_bottom = -14
		v.alignment = BoxContainer.ALIGNMENT_END
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var num := lbl(str(i + 1), 34)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		num.modulate.a = .5
		num.size_flags_vertical = Control.SIZE_EXPAND_FILL
		num.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		v.add_child(num)
		for t in [[W.name, 19], [W.short if open else "Verrouillé", 13], ["Cristaux %d/%d" % [Save.world_crystals(i), WorldData.LEVELS_PER_WORLD * 3], 13]]:
			var l := lbl(t[0], t[1])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.add_theme_constant_override("outline_size", 4)
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, .35))
			v.add_child(l)
		for ch in v.get_children():
			ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(v)
		var wi := i
		b.pressed.connect(func():
			if not open:
				Sfx.play("hurt")
				toast("Termine le monde précédent")
				return
			Sfx.play("click")
			go("levels", wi))
		world_row.add_child(b)

func _build_levels() -> void:
	var c := make_screen("levels", "Mondes")
	level_title = lbl("", 28, GOLD, 6)
	c.add_child(level_title)
	level_grid = GridContainer.new()
	level_grid.columns = 4
	level_grid.add_theme_constant_override("h_separation", 14)
	level_grid.add_theme_constant_override("v_separation", 14)
	level_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(level_grid)

func _render_levels(w: int) -> void:
	var W := WorldData.world(w)
	level_title.text = "Monde %d · %s" % [w + 1, W.name]
	for ch in level_grid.get_children():
		ch.queue_free()
	for l in WorldData.LEVELS_PER_WORLD:
		var open := Save.is_unlocked(w, l)
		var col: Color = W.near if open else Color(1, 1, 1, .1)
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(120, 96)
		b.add_theme_stylebox_override("normal", _style(col))
		b.add_theme_stylebox_override("hover", _style(col.lightened(.06)))
		b.add_theme_stylebox_override("pressed", _style(col, true))
		b.modulate.a = 1.0 if open else .45
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := lbl("%d-%d" % [w + 1, l + 1], 26, CREAM)
		t.add_theme_constant_override("outline_size", 5)
		t.add_theme_color_override("font_outline_color", Color(0, 0, 0, .4))
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(t)
		var lw := w
		var ll := l
		var cr := crystal_row(func(): return Save.level_crystals(lw, ll))
		cr.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(cr)
		b.add_child(v)
		b.pressed.connect(func():
			if not open:
				Sfx.play("hurt")
				toast("Niveau verrouillé")
				return
			Sfx.play("click")
			_start(func(): game.start_level(lw, ll)))
		level_grid.add_child(b)

func _build_minis() -> void:
	var c := make_screen("minis", "Retour")
	c.add_child(lbl("Mini-jeux", 30, GOLD, 6))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var defs := [
		["endless", "Course infinie", "Va le plus loin possible. Ça accélère !"],
		["rush", "Chrono gemmes", "60 secondes pour rafler un max de gemmes."],
		["balloons", "Éclate-ballons", "Touche les ballons, évite les nuages d'orage."],
		["chests", "Coffres mystères", "20 gemmes la partie. Ouvre des coffres, évite le piège."],
	]
	for d in defs:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(240, 92)
		var col := Color(1, 1, 1, .1)
		b.add_theme_stylebox_override("normal", _style(col))
		b.add_theme_stylebox_override("hover", _style(Color(1, 1, 1, .16)))
		b.add_theme_stylebox_override("pressed", _style(col, true))
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.offset_left = 14
		v.offset_right = -14
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var t := lbl(d[1], 18, GOLD)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		var p := lbl(d[2], 13)
		p.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var bl := lbl("", 13, MINT)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		mini_best[d[0]] = bl
		for x in [t, p, bl]:
			x.mouse_filter = Control.MOUSE_FILTER_IGNORE
			v.add_child(x)
		b.add_child(v)
		var kind: String = d[0]
		b.pressed.connect(func():
			Sfx.play("click")
			if kind == "chests":
				go("chests")
			else:
				_start(func(): game.start_mini(kind)))
		grid.add_child(b)
	c.add_child(grid)

func _render_minis() -> void:
	for k in mini_best:
		var v := Save.best(k)
		mini_best[k].text = ("Record : %d%s" % [v, " m" if k == "endless" else ""]) if v > 0 else ""

# ------------------------------------------------------------- chests

func _build_chests() -> void:
	var c := make_screen("chests", "Retour")
	c.add_child(lbl("Coffres mystères", 28, GOLD, 6))
	chest_pot = lbl("Gain : 0 gemmes", 20)
	c.add_child(chest_pot)
	chest_grid = GridContainer.new()
	chest_grid.columns = 3
	chest_grid.add_theme_constant_override("h_separation", 12)
	chest_grid.add_theme_constant_override("v_separation", 10)
	chest_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(chest_grid)
	var r := row()
	chest_cash = btn("Encaisser", MINT, _cash_chests)
	chest_new = btn("Jouer (20)", GOLD, func(): _new_chests(true))
	r.add_child(chest_cash)
	r.add_child(chest_new)
	c.add_child(r)

func _new_chests(pay: bool) -> void:
	if pay:
		if int(Save.data.gems) < 20:
			toast("Il faut 20 gemmes")
			Sfx.play("hurt")
			return
		Save.add_gems(-20)
		refresh_gems()
	var items := [5, 8, 10, 12, 15, 20, 30, 50, "trap"]
	items.shuffle()
	chest = {"pot": 0, "over": not pay, "items": items, "opened": 0}
	for ch in chest_grid.get_children():
		ch.queue_free()
	for i in items.size():
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(84, 54)
		b.add_theme_stylebox_override("normal", _style(Color("#b06a35")))
		b.add_theme_stylebox_override("hover", _style(Color("#bd7640")))
		b.add_theme_stylebox_override("pressed", _style(Color("#b06a35"), true))
		b.add_theme_stylebox_override("disabled", _style(Color("#4a3f66")))
		b.add_theme_font_size_override("font_size", 20)
		b.add_theme_color_override("font_disabled_color", CREAM)
		b.modulate.a = 1.0 if pay else .5
		var idx := i
		b.pressed.connect(func(): _open_chest(idx, b))
		chest_grid.add_child(b)
	chest_pot.text = "Gain : 0 gemmes"
	chest_cash.visible = pay
	chest_new.text = "Nouvelle partie (20)" if pay else "Jouer (20)"

func _open_chest(i: int, b: Button) -> void:
	if chest.over or b.disabled:
		return
	var v = chest.items[i]
	b.disabled = true
	if typeof(v) == TYPE_STRING:
		b.add_theme_stylebox_override("disabled", _style(CORAL))
		b.text = "X"
		chest.pot = 0
		chest.over = true
		Sfx.play("hurt")
		toast("Piège ! Tout est perdu")
		chest_cash.visible = false
		_reveal_chests()
	else:
		b.text = "+%d" % v
		chest.pot += v
		chest.opened += 1
		Sfx.play("gem")
		if chest.opened == 8:
			toast("Tous les coffres !")
			_cash_chests()
	chest_pot.text = "Gain : %d gemmes" % chest.pot

func _cash_chests() -> void:
	if chest.over:
		return
	Save.add_gems(chest.pot)
	refresh_gems()
	if chest.pot > 0:
		Sfx.play("win")
	toast("+%d gemmes" % chest.pot)
	chest.over = true
	chest_cash.visible = false
	_reveal_chests()

func _reveal_chests() -> void:
	var kids := chest_grid.get_children()
	for i in kids.size():
		var b: Button = kids[i]
		if not b.disabled:
			b.disabled = true
			b.modulate.a = .5
			var v = chest.items[i]
			b.text = "X" if typeof(v) == TYPE_STRING else str(v)

# ------------------------------------------------------------- shop

func _build_shop() -> void:
	var c := make_screen("shop", "Retour")
	c.add_child(lbl("Boutique de tenues", 28, GOLD, 6))
	skin_grid = GridContainer.new()
	skin_grid.columns = 3
	skin_grid.add_theme_constant_override("h_separation", 12)
	skin_grid.add_theme_constant_override("v_separation", 12)
	skin_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(skin_grid)

func _render_shop() -> void:
	for ch in skin_grid.get_children():
		ch.queue_free()
	for s in WorldData.SKINS:
		var own: bool = Save.data.owned.has(s.id)
		var sel: bool = Save.data.skin == s.id
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(150, 118)
		var st := _style(Color(1, 1, 1, .1))
		if sel:
			st.set_border_width_all(3)
			st.border_color = GOLD
		b.add_theme_stylebox_override("normal", st)
		b.add_theme_stylebox_override("hover", st)
		b.add_theme_stylebox_override("pressed", st)
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pv := PipView.new()
		pv.skin = s.id
		pv.pip_scale = 1.7
		pv.running_anim = false
		pv.custom_minimum_size = Vector2(60, 52)
		pv.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(pv)
		var n := lbl(s.name, 16)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(n)
		var info := lbl(("Équipé" if sel else "Équiper") if own else "%d gemmes" % s.price, 14, MINT if own else Color("#4cc9f0"))
		info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(info)
		b.add_child(v)
		var sid: String = s.id
		var price: int = s.price
		b.pressed.connect(func():
			if own:
				Save.data.skin = sid
				Save.persist()
				Sfx.play("click")
			elif int(Save.data.gems) >= price:
				Save.data.owned.append(sid)
				Save.data.skin = sid
				Save.add_gems(-price)
				Sfx.play("win")
				refresh_gems()
			else:
				Sfx.play("hurt")
				toast("Pas assez de gemmes")
				return
			_render_shop())
		skin_grid.add_child(b)

# ------------------------------------------------------------- in-game

func _build_hud() -> void:
	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.focus_mode = Control.FOCUS_NONE
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0, 0, 0, .35)
	st.set_corner_radius_all(23)
	for k in ["normal", "hover", "pressed"]:
		pause_btn.add_theme_stylebox_override(k, st)
	pause_btn.add_theme_font_size_override("font_size", 20)
	pause_btn.custom_minimum_size = Vector2(46, 46)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.offset_left = -56
	pause_btn.offset_right = -10
	pause_btn.offset_top = 8
	pause_btn.offset_bottom = 54
	pause_btn.visible = false
	pause_btn.pressed.connect(func():
		Sfx.play("click")
		_pause())
	root.add_child(pause_btn)
	toast_lbl = lbl("", 36, GOLD, 8)
	toast_lbl.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_lbl.offset_top = 64
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_lbl.modulate.a = 0
	root.add_child(toast_lbl)

func _build_pause() -> void:
	var c := make_screen("pause", "", true)
	c.add_child(lbl("Pause", 34, GOLD, 6))
	var r := row()
	r.add_child(btn("Reprendre", MINT, _resume))
	r.add_child(btn("Recommencer", GOLD, func(): _start(game.retry)))
	r.add_child(btn("Quitter", CORAL, _quit_run))
	c.add_child(r)

func _build_result() -> void:
	var c := make_screen("result", "", true)
	res_title = lbl("", 34, GOLD, 6)
	c.add_child(res_title)
	res_stars = crystal_row(func(): return _stars, 1.5)
	res_stars.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	c.add_child(res_stars)
	res_l1 = lbl("", 21)
	res_l2 = lbl("", 21)
	c.add_child(res_l1)
	c.add_child(res_l2)
	var r := row()
	res_next = btn("Niveau suivant", MINT, func():
		var n = game.next_level()
		if n != null:
			_start(func(): game.start_level(n[0], n[1])))
	r.add_child(res_next)
	r.add_child(btn("Rejouer", GOLD, func(): _start(game.retry)))
	r.add_child(btn("Menu", Color(1, 1, 1, .14), _quit_run))
	c.add_child(r)

func _start(starter: Callable) -> void:
	show_only("")
	game.visible = true
	pause_btn.visible = true
	starter.call()

func _pause() -> void:
	if not game.running:
		return
	game.set_paused(true)
	show_only("pause")

func _resume() -> void:
	game.set_paused(false)
	show_only("")

func _quit_run() -> void:
	game.end_run()
	_show_top()

func _on_game_ended(info: Dictionary) -> void:
	pause_btn.visible = false
	res_title.text = info.title
	_stars = info.stars
	res_stars.visible = info.stars >= 0
	res_stars.queue_redraw()
	res_l1.text = info.l1
	res_l2.text = info.l2
	res_l2.visible = info.l2 != ""
	res_next.visible = game.mode == "level" and info.won and game.next_level() != null
	show_only("result")
