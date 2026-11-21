class_name MatchPlot
extends Control
## Does the fitted prior reproduce the answers? One square panel per
## question: each dot is one quantile, the expert's answer across and what
## the fitted prior implies up. Dots on the diagonal are a perfect match.

const C_BG := Color("#fffdf8")
const C_AXIS := Color(0.12, 0.16, 0.27, 0.55)
const C_TEXT := Color("#3b3b3b")
const C_TITLE := Color("#1f2a44")
const C_SINGLE := Color("#e5604f")
const PAD := 12.0
const GAP := 40.0
const LEFT := 40.0

## [{"name", "title"}], in question order.
var targets: Array = []
## [{"name", "color", "expert": {target: [q...]}, "model": {target: [q...]}}]
var series: Array = []
## Quantile levels per target, e.g. {"pumps": [0.1, 0.25, 0.5, 0.75, 0.9]}.
var probs: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(360, 300)


func show_single(expert: Dictionary, model: Dictionary, quantile_levels: Dictionary) -> void:
	series = [{"name": "", "color": C_SINGLE, "expert": expert, "model": model}]
	probs = quantile_levels
	queue_redraw()


func show_series(new_series: Array, quantile_levels: Dictionary) -> void:
	series = new_series
	probs = quantile_levels
	queue_redraw()


func clear() -> void:
	series = []
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var fs := get_theme_font_size("font_size", "Label") - 3
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	if series.is_empty() or targets.is_empty():
		draw_string(font, Vector2(PAD, size.y * 0.5), "Fit the prior to compare it with the answers.", HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, C_AXIS)
		return
	var n := targets.size()
	var side := minf((size.x - 2.0 * PAD - GAP * (n - 1)) / n, size.y - 2.0 * PAD + LEFT)
	var used := n * side + (n - 1) * GAP
	var x0 := (size.x - used) * 0.5
	for k in n:
		_draw_target(targets[k], Rect2(x0 + k * (side + GAP), PAD, side, side), font, fs)


func _draw_target(target: Dictionary, area: Rect2, font: Font, fs: int) -> void:
	var tname: String = target.name
	var title_h := fs + 10.0
	var axis_h := 2 * fs + 14.0
	var plot := Rect2(area.position.x + LEFT, area.position.y + title_h, area.size.x - LEFT, area.size.y - title_h - axis_h)
	plot.size = Vector2.ONE * minf(plot.size.x, plot.size.y)  # square, so the diagonal is 45°
	draw_string(font, Vector2(area.position.x, area.position.y + fs + 2), str(target.title), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, C_TITLE)

	var lo := INF
	var hi := -INF
	for s in series:
		for key in ["expert", "model"]:
			for v in s[key].get(tname, []):
				lo = minf(lo, float(v))
				hi = maxf(hi, float(v))
	if not is_finite(lo):
		return
	if is_equal_approx(lo, hi):
		hi = lo + 1.0
	var span := hi - lo
	var step := _nice_step((span * 1.2) / 4.0)
	lo = floorf(maxf(0.0, lo - 0.1 * span) / step) * step
	hi = ceilf((hi + 0.1 * span) / step) * step
	var to_pt := func(ex: float, mo: float) -> Vector2:
		return Vector2(plot.position.x + plot.size.x * (ex - lo) / (hi - lo), plot.end.y - plot.size.y * (mo - lo) / (hi - lo))

	# frame, grid and the diagonal of a perfect match
	draw_rect(plot, Color(C_AXIS, 0.4), false, 1.0)
	var ticks := roundi((hi - lo) / step)
	for t in ticks + 1:
		var v := lo + step * t
		var p: Vector2 = to_pt.call(v, v)
		draw_line(Vector2(p.x, plot.position.y), Vector2(p.x, plot.end.y), Color(C_AXIS, 0.12))
		draw_line(Vector2(plot.position.x, p.y), Vector2(plot.end.x, p.y), Color(C_AXIS, 0.12))
		draw_string(font, Vector2(p.x - 30, plot.end.y + fs + 4), _fmt(v), HORIZONTAL_ALIGNMENT_CENTER, 60, fs, C_TEXT)
		draw_string(font, Vector2(plot.position.x - LEFT, p.y + fs * 0.35), _fmt(v), HORIZONTAL_ALIGNMENT_RIGHT, LEFT - 6.0, fs, C_TEXT)
	draw_dashed_line(to_pt.call(lo, lo), to_pt.call(hi, hi), C_AXIS, 1.5, 6.0)
	draw_string(font, Vector2(plot.position.x, plot.end.y + 2 * fs + 10), "expert's answer →", HORIZONTAL_ALIGNMENT_CENTER, plot.size.x, fs, C_AXIS)
	draw_string(font, Vector2(plot.end.x - 200, area.position.y + fs + 2), "↑ implied by the prior", HORIZONTAL_ALIGNMENT_RIGHT, 200, fs, C_AXIS)

	# one dot per quantile, joined in order
	var levels: Array = probs.get(tname, [])
	for s in series:
		var ex: Array = s.expert.get(tname, [])
		var mo: Array = s.model.get(tname, [])
		var m := mini(ex.size(), mo.size())
		var pts := PackedVector2Array()
		for i in m:
			pts.append(to_pt.call(float(ex[i]), float(mo[i])))
		if m >= 2:
			draw_polyline(pts, Color(s.color, 0.45), 1.5, true)
		for i in m:
			draw_circle(pts[i], 5.0, s.color)
			draw_circle(pts[i], 5.0, Color.WHITE, false, 1.0)
			if series.size() == 1 and i < levels.size():
				draw_string(font, pts[i] + Vector2(8, -6), "%d%%" % roundi(float(levels[i]) * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, C_TEXT)


## 1, 2 or 5 times a power of ten, at least `raw`.
static func _nice_step(raw: float) -> float:
	if raw <= 0.0:
		return 1.0
	var p := pow(10.0, floor(log(raw) / log(10.0)))
	for m in [1.0, 2.0, 5.0, 10.0]:
		if raw <= m * p:
			return m * p
	return 10.0 * p


static func _fmt(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v
