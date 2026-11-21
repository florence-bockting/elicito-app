class_name LossPlot
extends Control
## Live training curve. Points stream in during a fit; log scale, since
## elicito's loss usually drops by orders of magnitude.

const C_BG := Color("#fffdf8")
const C_LINE := Color("#e5604f")
const C_AXIS := Color(0.12, 0.16, 0.27, 0.5)

var points := PackedFloat64Array()


func _init() -> void:
	custom_minimum_size = Vector2(240, 120)


func clear() -> void:
	points.clear()
	queue_redraw()


func add_point(v: float) -> void:
	if is_finite(v) and v > 0.0:
		points.append(v)
		queue_redraw()


func set_points(values: Array) -> void:
	points.clear()
	for v in values:
		if is_finite(float(v)) and float(v) > 0.0:
			points.append(float(v))
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var fs := get_theme_font_size("font_size", "Label") - 3
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	var plot := Rect2(8, 22, size.x - 16, size.y - 30)
	draw_line(Vector2(plot.position.x, plot.end.y), Vector2(plot.end.x, plot.end.y), C_AXIS)
	draw_string(font, Vector2(8, 16), "training loss (log scale)", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_AXIS)
	if points.size() < 2:
		return
	var lo := INF
	var hi := -INF
	for v in points:
		lo = minf(lo, log(v))
		hi = maxf(hi, log(v))
	if is_equal_approx(lo, hi):
		hi = lo + 1.0
	var pts := PackedVector2Array()
	for i in points.size():
		var x := plot.position.x + plot.size.x * i / (points.size() - 1)
		var y := plot.end.y - plot.size.y * (log(points[i]) - lo) / (hi - lo)
		pts.append(Vector2(x, y))
	draw_polyline(pts, C_LINE, 2.0, true)
	draw_circle(pts[pts.size() - 1], 3.5, C_LINE)
	draw_string(font, Vector2(plot.end.x - 160, 16), "%.4f" % points[points.size() - 1], HORIZONTAL_ALIGNMENT_RIGHT, 160, fs, C_LINE)
