class_name ConvergencePlot
extends Control
## How the fitted prior moved during training: one panel per parameter,
## training steps across, and the Uniform's lower and upper bound as two
## lines with the prior's range shaded between them. Flat lines at the end
## mean the fit has settled. A panel fit draws one band per expert.

const C_BG := Color("#fffdf8")
const C_AXIS := Color(0.12, 0.16, 0.27, 0.55)
const C_TEXT := Color("#3b3b3b")
const C_TITLE := Color("#1f2a44")
const C_SINGLE := Color("#e5604f")
const PAD := 12.0
const GAP := 28.0  # between the parameter panels
const LEFT := 44.0  # room for the y labels

## Display names, e.g. {"gammap": "γ⁺ risk propensity"}.
var labels: Dictionary = {}
## [{"name", "color", "history": {param: {"lower": [...], "upper": [...]}}}]
var series: Array = []


func _init() -> void:
	custom_minimum_size = Vector2(360, 230)


func show_single(history: Dictionary) -> void:
	series = [{"name": "", "color": C_SINGLE, "history": history}]
	queue_redraw()


func show_series(new_series: Array) -> void:
	series = new_series
	queue_redraw()


func clear() -> void:
	series = []
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _parameters() -> Array:
	if series.is_empty():
		return []
	return series[0].history.keys()  # as the server lists them, like the priors tab


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var fs := get_theme_font_size("font_size", "Label") - 3
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	var params := _parameters()
	if params.is_empty():
		draw_string(font, Vector2(PAD, size.y * 0.5), "Fit the prior to see how it converged.", HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, C_AXIS)
		return
	var w := (size.x - 2.0 * PAD - GAP * (params.size() - 1)) / params.size()
	for k in params.size():
		_draw_param(params[k], Rect2(PAD + k * (w + GAP), PAD, w, size.y - 2.0 * PAD), font, fs)


func _draw_param(param: String, area: Rect2, font: Font, fs: int) -> void:
	var title_h := fs + 10.0
	var axis_h := fs + 22.0
	var plot := Rect2(area.position.x + LEFT, area.position.y + title_h, area.size.x - LEFT, area.size.y - title_h - axis_h)
	draw_string(font, Vector2(area.position.x, area.position.y + fs + 2), str(labels.get(param, param)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, C_TITLE)

	var lo := INF
	var hi := -INF
	var n := 0
	for s in series:
		var h: Dictionary = s.history.get(param, {})
		for v in h.get("lower", []):
			lo = minf(lo, float(v))
		for v in h.get("upper", []):
			hi = maxf(hi, float(v))
		n = maxi(n, h.get("lower", []).size())
	if n < 2 or not is_finite(lo) or not is_finite(hi):
		return
	if is_equal_approx(lo, hi):
		hi = lo + 1.0
	var span := hi - lo
	lo = maxf(0.0, lo - 0.05 * span)
	hi += 0.05 * span

	var to_pt := func(i: int, v: float) -> Vector2:
		return Vector2(plot.position.x + plot.size.x * i / float(n - 1), plot.end.y - plot.size.y * (v - lo) / (hi - lo))

	# axes: 4 y ticks, steps along x
	for t in 4:
		var v := lo + (hi - lo) * t / 3.0
		var y: float = to_pt.call(0, v).y
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), Color(C_AXIS, 0.15))
		draw_string(font, Vector2(area.position.x, y + fs * 0.35), "%.2f" % v, HORIZONTAL_ALIGNMENT_RIGHT, LEFT - 6.0, fs, C_TEXT)
	draw_line(Vector2(plot.position.x, plot.end.y), Vector2(plot.end.x, plot.end.y), C_AXIS, 1.5)
	draw_string(font, Vector2(plot.position.x, plot.end.y + fs + 4), "1", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TEXT)
	draw_string(font, Vector2(plot.end.x - 60, plot.end.y + fs + 4), str(n), HORIZONTAL_ALIGNMENT_RIGHT, 60, fs, C_TEXT)
	draw_string(font, Vector2(plot.position.x, plot.end.y + 2 * fs + 10), "training step", HORIZONTAL_ALIGNMENT_CENTER, plot.size.x, fs, C_AXIS)

	for s in series:
		var h: Dictionary = s.history.get(param, {})
		var lower: Array = h.get("lower", [])
		var upper: Array = h.get("upper", [])
		var m := mini(lower.size(), upper.size())
		if m < 2:
			continue
		var top := PackedVector2Array()
		var bottom := PackedVector2Array()
		for i in m:
			top.append(to_pt.call(i, float(upper[i])))
			bottom.append(to_pt.call(i, float(lower[i])))
		var band := top.duplicate()
		for i in range(m - 1, -1, -1):
			band.append(bottom[i])
		var color: Color = s.color
		if Geometry2D.triangulate_polygon(band).size() > 0:
			draw_colored_polygon(band, Color(color, 0.12))
		draw_polyline(top, color, 2.0, true)
		draw_polyline(bottom, color, 2.0, true)
		draw_circle(top[m - 1], 3.0, color)
		draw_circle(bottom[m - 1], 3.0, color)
