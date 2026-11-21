class_name ChipRoulette
extends Control
## Trial-roulette elicitation widget (the "chips and bins" method).
##
## The expert spreads a fixed number of probability chips over bins:
## left click drops a chip into a column, right click takes one back.
## The widget shows the running CDF, a box plot of the expert's quantiles,
## and, after a fit, the quantiles that the fitted prior implies.

signal histogram_changed(counts: PackedInt32Array)

const PAD_L := 46.0
const PAD_R := 18.0
const PAD_T := 66.0  # room for the two box-plot rows
const PAD_B := 36.0
const DROP_TIME := 0.28

const C_BG := Color("#fffdf8")
const C_COL_ALT := Color(0.12, 0.16, 0.27, 0.035)
const C_HOVER := Color(0.95, 0.72, 0.29, 0.16)
const C_AXIS := Color(0.12, 0.16, 0.27, 0.55)
const C_TEXT := Color("#3b3b3b")
const C_CHIP := Color("#f2b84b")
const C_CHIP_EDGE := Color("#c98a1b")
const C_EXPERT := Color("#1f2a44")
const C_MODEL := Color("#e5604f")
const C_OK := Color("#2e6b3a")
const NOTICE_TIME := 2.5  # seconds a notice stays visible

@export var spec: TargetSpec:
	set = set_spec

var counts := PackedInt32Array()
var model_quantiles := PackedFloat64Array()
var ghost_counts := PackedInt32Array()  # a persona's answer, drawn faintly

var _hover_bin := -1
var _drops: Array = []  # chips in their drop animation (dicts: bin, level, p)
var _chip_box: StyleBoxFlat
var _chip_box_extra: StyleBoxFlat  # chips beyond the ghost's count in a column
var _notice := ""  # short message, e.g. when no chips are left


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(420, 300)
	_chip_box = StyleBoxFlat.new()
	_chip_box.bg_color = C_CHIP
	_chip_box.border_color = C_CHIP_EDGE
	_chip_box.set_border_width_all(1)
	_chip_box.set_corner_radius_all(4)
	_chip_box_extra = _chip_box.duplicate()
	_chip_box_extra.bg_color = C_MODEL.lightened(0.35)
	_chip_box_extra.border_color = C_MODEL.darkened(0.2)


func set_spec(value: TargetSpec) -> void:
	spec = value
	counts.resize(spec.bin_count() if spec else 0)
	counts.fill(0)
	model_quantiles = PackedFloat64Array()
	_drops.clear()
	queue_redraw()


# ---------------------------------------------------------------- state API

func placed() -> int:
	var n := 0
	for c in counts:
		n += c
	return n


func chips_left() -> int:
	return spec.chips - placed()


func is_complete() -> bool:
	return spec != null and chips_left() == 0


## Quantiles of the current histogram at `spec.probs` (empty if no chips).
func quantiles() -> PackedFloat64Array:
	return QuantileMath.quantiles_from_histogram(counts, spec.bin_edges(), spec.probs)


func add_chip(bin: int) -> bool:
	if bin < 0 or bin >= counts.size() or chips_left() <= 0:
		return false
	counts[bin] += 1
	_animate_drop(bin, counts[bin] - 1)
	_changed()
	return true


func remove_chip(bin: int) -> bool:
	if bin < 0 or bin >= counts.size() or counts[bin] == 0:
		return false
	counts[bin] -= 1
	_drops = _drops.filter(func(d: Dictionary) -> bool: return not (d.bin == bin and d.level >= counts[bin]))
	_changed()
	return true


func set_counts(new_counts: PackedInt32Array) -> void:
	assert(new_counts.size() == counts.size(), "wrong number of bins")
	counts = new_counts.duplicate()
	_drops.clear()
	_changed()


func reset() -> void:
	counts.fill(0)
	_drops.clear()
	_changed()


## Show faint "ghost" chips, e.g. a persona's answer (empty array hides them).
func set_ghost(new_ghost: PackedInt32Array) -> void:
	ghost_counts = new_ghost
	queue_redraw()


## Overlay the quantiles implied by the fitted prior (empty array clears it).
func set_model_quantiles(q: PackedFloat64Array) -> void:
	model_quantiles = q
	queue_redraw()


func _changed() -> void:
	model_quantiles = PackedFloat64Array()  # the old fit no longer matches
	queue_redraw()
	histogram_changed.emit(counts)


# ---------------------------------------------------------------- input

func _gui_input(event: InputEvent) -> void:
	if spec == null:
		return
	if event is InputEventMouseMotion:
		var b := _bin_at(event.position)
		if b != _hover_bin:
			_hover_bin = b
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed:
		var b := _bin_at(event.position)
		if b < 0:
			return
		if event.button_index == MOUSE_BUTTON_LEFT:
			if not add_chip(b) and chips_left() == 0:
				_show_notice("No chips left: right-click a column to take one back")
			accept_event()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			remove_chip(b)
			accept_event()


func _show_notice(text: String) -> void:
	_notice = text
	queue_redraw()
	get_tree().create_timer(NOTICE_TIME).timeout.connect(func() -> void:
		if _notice == text:  # a newer notice may have replaced it
			_notice = ""
			queue_redraw())


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _hover_bin != -1:
		_hover_bin = -1
		queue_redraw()
	elif what == NOTIFICATION_RESIZED:
		queue_redraw()


func _bin_at(pos: Vector2) -> int:
	var plot := _plot_rect()
	if pos.x < plot.position.x or pos.x >= plot.end.x or pos.y < PAD_T * 0.5 or pos.y > plot.end.y:
		return -1
	return clampi(int((pos.x - plot.position.x) / _col_width()), 0, counts.size() - 1)


func _animate_drop(bin: int, level: int) -> void:
	if not is_inside_tree():
		return
	var drop := {"bin": bin, "level": level, "p": 0.0}
	_drops.append(drop)
	var tween := create_tween()
	tween.tween_method(
		func(v: float) -> void:
			drop.p = v
			queue_redraw(),
		0.0, 1.0, DROP_TIME
	).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void:
		_drops.erase(drop)
		queue_redraw())


# ---------------------------------------------------------------- geometry

func _plot_rect() -> Rect2:
	return Rect2(PAD_L, PAD_T, maxf(size.x - PAD_L - PAD_R, 10.0), maxf(size.y - PAD_T - PAD_B, 10.0))


func _col_width() -> float:
	return _plot_rect().size.x / maxi(counts.size(), 1)


func _x_of(value: float) -> float:
	var plot := _plot_rect()
	var t := (value - spec.axis_min) / (spec.axis_max - spec.axis_min)
	return plot.position.x + clampf(t, 0.0, 1.0) * plot.size.x


func _chip_rect(bin: int, level: int) -> Rect2:
	var plot := _plot_rect()
	var w := _col_width()
	var h := plot.size.y / spec.chips
	var gap := minf(3.0, w * 0.12)
	return Rect2(
		plot.position.x + bin * w + gap, plot.end.y - (level + 1) * h + 1.0, w - 2.0 * gap, h - 2.0
	)


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	if spec == null:
		return
	var font := get_theme_font("font", "Label")
	var fs := get_theme_font_size("font_size", "Label") - 2
	var plot := _plot_rect()
	var w := _col_width()

	draw_rect(Rect2(Vector2.ZERO, size), C_BG)

	# columns
	for i in counts.size():
		var col := Rect2(plot.position.x + i * w, plot.position.y, w, plot.size.y)
		if i == _hover_bin:
			draw_rect(col, C_HOVER)
		elif i % 2 == 1:
			draw_rect(col, C_COL_ALT)

	# y axis: probability, 100% = all chips in one column
	for k in 5:
		var frac := k / 4.0
		var y := plot.end.y - frac * plot.size.y
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(C_AXIS, 0.12))
		draw_string(font, Vector2(4, y + fs * 0.35), "%d%%" % int(frac * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_AXIS)

	# ghost chips: outlines the expert's real chips will cover
	var ghost_on := ghost_counts.size() == counts.size()
	if ghost_on:
		for i in ghost_counts.size():
			for level in ghost_counts[i]:
				var r := _chip_rect(i, level)
				draw_rect(r, Color(C_EXPERT, 0.10))
				draw_rect(r, Color(C_EXPERT, 0.6), false, 1.5)

	# chips
	var dropping := {}
	for d in _drops:
		dropping[Vector2i(d.bin, d.level)] = true
	for i in counts.size():
		for level in counts[i]:
			if not dropping.has(Vector2i(i, level)):
				# with a ghost shown, chips above the ghost's stack are extra: draw them red
				var extra := ghost_on and level >= ghost_counts[i]
				draw_style_box(_chip_box_extra if extra else _chip_box, _chip_rect(i, level))
	for d in _drops:
		var target := _chip_rect(d.bin, d.level)
		var start_y := plot.position.y - target.size.y
		draw_style_box(_chip_box, Rect2(Vector2(target.position.x, lerpf(start_y, target.position.y, d.p)), target.size))

	# with a ghost shown: "yours/ghost" above every column that has chips
	if ghost_on:
		var chip_h := plot.size.y / spec.chips
		for i in counts.size():
			if counts[i] == 0 and ghost_counts[i] == 0:
				continue
			var color := C_OK if counts[i] == ghost_counts[i] else (C_MODEL if counts[i] > ghost_counts[i] else C_AXIS)
			var top := plot.end.y - maxi(counts[i], ghost_counts[i]) * chip_h
			draw_string(font, Vector2(plot.position.x + i * w, top - 4), "%d/%d" % [counts[i], ghost_counts[i]], HORIZONTAL_ALIGNMENT_CENTER, w, fs - 1, color)

	# running CDF
	if placed() > 0:
		var cdf := QuantileMath.cdf(counts)
		var pts := PackedVector2Array([Vector2(plot.position.x, plot.end.y)])
		for i in cdf.size():
			pts.append(Vector2(plot.position.x + (i + 1) * w, plot.end.y - cdf[i] * plot.size.y))
		draw_polyline(pts, Color(C_EXPERT, 0.45), 2.0, true)

	_draw_x_axis(font, fs, plot, w)

	# box plots: the expert's answers and what the fitted prior implies
	var row_you := 20.0
	var row_fit := 46.0
	draw_string(font, Vector2(4, row_you + fs * 0.35), "you", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_EXPERT)
	draw_string(font, Vector2(4, row_fit + fs * 0.35), "prior", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_MODEL)
	if is_complete():
		var q := quantiles()
		for v in q:
			draw_dashed_line(Vector2(_x_of(v), plot.position.y), Vector2(_x_of(v), plot.end.y), Color(C_EXPERT, 0.35), 1.0, 4.0)
		_draw_box(q, row_you, C_EXPERT)
	else:
		var msg := "%d of %d chips left" % [chips_left(), spec.chips]
		draw_string(font, Vector2(plot.position.x, row_you + fs * 0.35), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(C_EXPERT, 0.6))
	if model_quantiles.size() >= 3:
		_draw_box(model_quantiles, row_fit, C_MODEL)
	else:
		draw_string(font, Vector2(plot.position.x, row_fit + fs * 0.35), "fit the prior to compare", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(C_MODEL, 0.55))

	# top-right: a notice, or a readout of the column under the mouse
	if _notice != "":
		draw_string(font, Vector2(plot.end.x - 420, row_you + fs * 0.35), _notice, HORIZONTAL_ALIGNMENT_RIGHT, 420, fs, C_MODEL)
	elif _hover_bin >= 0:
		var c := counts[_hover_bin]
		var label := "%d chip%s · %d%%" % [c, "" if c == 1 else "s", roundi(100.0 * c / spec.chips)]
		if c > 0:
			label += " · right-click takes one back"
		draw_string(font, Vector2(plot.end.x - 420, row_you + fs * 0.35), label, HORIZONTAL_ALIGNMENT_RIGHT, 420, fs, C_TEXT)


func _draw_x_axis(font: Font, fs: int, plot: Rect2, w: float) -> void:
	draw_line(Vector2(plot.position.x, plot.end.y), Vector2(plot.end.x, plot.end.y), C_AXIS, 1.5)
	var step := maxi(1, ceili(28.0 / w))
	if spec.discrete:
		for i in range(0, counts.size(), step):
			var x := plot.position.x + (i + 0.5) * w
			draw_string(font, Vector2(x - 20, plot.end.y + fs + 6), spec.format_value(spec.bin_center(i)), HORIZONTAL_ALIGNMENT_CENTER, 40, fs, C_TEXT)
	else:
		var edges := spec.bin_edges()
		for i in range(0, edges.size(), step):
			var x := plot.position.x + i * w
			draw_string(font, Vector2(x - 20, plot.end.y + fs + 6), spec.format_value(edges[i]), HORIZONTAL_ALIGNMENT_CENTER, 40, fs, C_TEXT)
	if spec.unit != "":
		draw_string(font, Vector2(plot.end.x - 200, size.y - 2), spec.unit, HORIZONTAL_ALIGNMENT_RIGHT, 200, fs, C_AXIS)


## Whiskers from the first to the last quantile, a box from the second to the
## second last, and a tick at the middle one (the median for 5 quantiles).
func _draw_box(q: PackedFloat64Array, y: float, color: Color) -> void:
	var n := q.size()
	var x0 := _x_of(q[0])
	var x1 := _x_of(q[n - 1])
	var b0 := _x_of(q[1])
	var b1 := _x_of(q[n - 2])
	var mid := _x_of(q[int(n / 2.0)])
	draw_line(Vector2(x0, y), Vector2(x1, y), color, 2.0)
	draw_line(Vector2(x0, y - 5), Vector2(x0, y + 5), color, 2.0)
	draw_line(Vector2(x1, y - 5), Vector2(x1, y + 5), color, 2.0)
	draw_rect(Rect2(b0, y - 7, maxf(b1 - b0, 2.0), 14), Color(color, 0.25))
	draw_rect(Rect2(b0, y - 7, maxf(b1 - b0, 2.0), 14), color, false, 1.5)
	draw_line(Vector2(mid, y - 8), Vector2(mid, y + 8), color, 3.0)
