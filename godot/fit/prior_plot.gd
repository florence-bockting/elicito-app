class_name PriorPlot
extends Control
## Draws the fitted Uniform priors, one panel per parameter.
##
## The latest fit is filled; earlier fits stay as faint outlines, so the
## expert sees how revising the chips moved the prior.

const C_BG := Color("#fffdf8")
const C_AXIS := Color(0.12, 0.16, 0.27, 0.55)
const C_TEXT := Color("#3b3b3b")
const C_FIT := Color("#e5604f")
const C_TITLE := Color("#1f2a44")
const C_PANEL := Color("#1f2a44")  # the whole panel, in panel mode
const PAD_L := 16.0
const PAD_R := 16.0
const PAD_T := 34.0  # room for the legend
const MAX_HISTORY := 5  # earlier fits drawn as outlines

## Display names, e.g. {"gammap": "γ⁺ risk propensity"}.
var labels: Dictionary = {}
## Fitted priors, oldest first: each is {"gammap": [lo, hi], "beta": [lo, hi]}.
var fits: Array[Dictionary] = []
## Panel mode: one {"name", "color", "priors"} per expert, and the panel's
## population prior as a histogram density per parameter.
var panel_experts: Array = []
var population: Dictionary = {}


func _init() -> void:
	custom_minimum_size = Vector2(420, 230)


func add_fit(priors: Dictionary) -> void:
	panel_experts = []
	population = {}
	fits.append(priors)
	queue_redraw()


func clear() -> void:
	fits.clear()
	panel_experts = []
	population = {}
	queue_redraw()


## Compare a panel: each expert's prior in their colour, and the panel's
## population prior (all experts together, with their disagreement) in grey.
func show_panel(experts: Array, panel_population: Dictionary) -> void:
	fits.clear()
	panel_experts = experts
	population = panel_population
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


## Panel order: as the server lists the parameters (gammap before beta).
func _parameters() -> Array:
	return fits[-1].keys() if not fits.is_empty() else []


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var fs := get_theme_font_size("font_size", "Label") - 2
	draw_rect(Rect2(Vector2.ZERO, size), C_BG)
	if not panel_experts.is_empty():
		_draw_panel_mode(font, fs)
		return
	if fits.is_empty():
		draw_string(font, Vector2(PAD_L, size.y * 0.5), "Fit the prior to see it here.", HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 2, C_AXIS)
		return

	# legend
	var x := PAD_L
	draw_rect(Rect2(x, 12, 14, 10), Color(C_FIT, 0.35))
	draw_rect(Rect2(x, 12, 14, 10), C_FIT, false, 1.5)
	draw_string(font, Vector2(x + 20, 21), "latest fit (#%d)" % fits.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TEXT)
	x += 150
	if fits.size() > 1:
		draw_rect(Rect2(x, 12, 14, 10), Color(C_FIT, 0.45), false, 1.0)
		draw_string(font, Vector2(x + 20, 21), "earlier fits", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TEXT)
		x += 120

	var params := _parameters()
	var panel_h := (size.y - PAD_T) / maxi(params.size(), 1)
	for k in params.size():
		_draw_panel(params[k], Rect2(PAD_L, PAD_T + k * panel_h, size.x - PAD_L - PAD_R, panel_h), font, fs)


## One parameter: Uniform densities as rectangles on a shared axis.
func _draw_panel(param: String, area: Rect2, font: Font, fs: int) -> void:
	var title_h := fs + 8.0
	var axis_h := fs + 10.0
	var plot := Rect2(area.position.x, area.position.y + title_h, area.size.x, area.size.y - title_h - axis_h - 6.0)

	# everything shown in this panel, newest fit last
	var shown: Array = []
	for i in range(maxi(0, fits.size() - 1 - MAX_HISTORY), fits.size()):
		if fits[i].has(param):
			shown.append(fits[i][param])
	var x_max := 0.0
	var dens_max := 0.0
	for b in shown:
		x_max = maxf(x_max, b[1])
		dens_max = maxf(dens_max, 1.0 / maxf(b[1] - b[0], 1e-6))
	x_max = _nice_ceiling(x_max * 1.1)

	var to_x := func(v: float) -> float: return plot.position.x + clampf(v / x_max, 0.0, 1.0) * plot.size.x
	var to_rect := func(b: Array) -> Rect2:
		var h: float = plot.size.y * (1.0 / maxf(b[1] - b[0], 1e-6)) / dens_max
		var x0: float = to_x.call(b[0])
		var x1: float = to_x.call(b[1])
		return Rect2(x0, plot.end.y - h, maxf(x1 - x0, 2.0), h)

	var latest: Array = fits[-1].get(param, [])
	var title := "%s" % labels.get(param, param)
	if latest.size() == 2:
		title += "  ~ Uniform(%.2f, %.2f)" % [latest[0], latest[1]]
	draw_string(font, Vector2(area.position.x, area.position.y + fs + 2), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 1, C_TITLE)

	# earlier fits: faint outlines, older = fainter
	var first := maxi(0, fits.size() - 1 - MAX_HISTORY)
	for i in range(first, fits.size() - 1):
		if fits[i].has(param):
			var age := float(fits.size() - 1 - i)
			draw_rect(to_rect.call(fits[i][param]), Color(C_FIT, 0.5 / age), false, 1.0)
	# latest fit: filled
	if latest.size() == 2:
		var r: Rect2 = to_rect.call(latest)
		draw_rect(r, Color(C_FIT, 0.3))
		draw_rect(r, C_FIT, false, 2.0)

	# x axis with 5 ticks
	draw_line(Vector2(plot.position.x, plot.end.y), Vector2(plot.end.x, plot.end.y), C_AXIS, 1.5)
	for t in 6:
		var v := x_max * t / 5.0
		var tx: float = to_x.call(v)
		draw_line(Vector2(tx, plot.end.y), Vector2(tx, plot.end.y + 4), C_AXIS)
		draw_string(font, Vector2(tx - 30, plot.end.y + fs + 6), _fmt(v), HORIZONTAL_ALIGNMENT_CENTER, 60, fs - 1, C_TEXT)


## Rounds up to 1, 2 or 5 times a power of ten, so axis ticks are readable.
static func _nice_ceiling(v: float) -> float:
	if v <= 0.0:
		return 1.0
	var p := pow(10.0, floor(log(v) / log(10.0)))
	for m in [1.0, 2.0, 5.0, 10.0]:
		if v <= m * p:
			return m * p
	return 10.0 * p


static func _fmt(v: float) -> String:
	return str(snappedf(v, 0.01))


# ---------------------------------------------------------------- panel mode

func _draw_panel_mode(font: Font, fs: int) -> void:
	# legend: the panel, then every expert in their colour
	var x := PAD_L
	draw_rect(Rect2(x, 12, 14, 10), Color(C_PANEL, 0.18))
	draw_rect(Rect2(x, 12, 14, 10), C_PANEL, false, 1.5)
	draw_string(font, Vector2(x + 20, 21), "whole panel", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TEXT)
	x += 110
	for e in panel_experts:
		draw_rect(Rect2(x, 14, 14, 6), e.color)
		draw_string(font, Vector2(x + 20, 21), e.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, C_TEXT)
		x += 30 + font.get_string_size(e.name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var params: Array = population.keys()
	var panel_h := (size.y - PAD_T) / maxi(params.size(), 1)
	for k in params.size():
		_draw_panel_param(params[k], Rect2(PAD_L, PAD_T + k * panel_h, size.x - PAD_L - PAD_R, panel_h), font, fs)


## One parameter: a row per expert with their prior range (like a forest
## plot), and below it the whole panel's population prior as a histogram.
func _draw_panel_param(param: String, area: Rect2, font: Font, fs: int) -> void:
	var title_h := fs + 8.0
	var axis_h := fs + 10.0
	var plot := Rect2(area.position.x, area.position.y + title_h, area.size.x, area.size.y - title_h - axis_h - 6.0)
	var pop: Dictionary = population[param]
	var edges: Array = pop.edges
	var dens: Array = pop.density
	var x_max: float = edges[-1]
	var to_x := func(v: float) -> float: return plot.position.x + clampf(v / x_max, 0.0, 1.0) * plot.size.x

	draw_string(font, Vector2(area.position.x, area.position.y + fs + 2), str(labels.get(param, param)), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 1, C_TITLE)

	# expert rows on top, the panel's histogram underneath
	var row_h := minf(16.0, plot.size.y * 0.6 / maxi(panel_experts.size(), 1))
	var hist := Rect2(plot.position.x, plot.position.y + row_h * panel_experts.size() + 4.0, plot.size.x, 0.0)
	hist.end = Vector2(plot.end.x, plot.end.y)

	for i in panel_experts.size():
		var e: Dictionary = panel_experts[i]
		var b: Array = e.priors.get(param, [])
		if b.size() != 2:
			continue
		var y := plot.position.y + (i + 0.5) * row_h
		var x0: float = to_x.call(b[0])
		var x1: float = maxf(to_x.call(b[1]), x0 + 3.0)
		draw_line(Vector2(x0, y), Vector2(x1, y), e.color, maxf(row_h * 0.5, 3.0))

	var d_max := 0.0
	for d in dens:
		d_max = maxf(d_max, d)
	if d_max > 0.0 and hist.size.y > 4.0:
		var pts := PackedVector2Array([Vector2(hist.position.x, hist.end.y)])
		for i in dens.size():
			var top: float = hist.end.y - hist.size.y * dens[i] / d_max
			pts.append(Vector2(to_x.call(edges[i]), top))
			pts.append(Vector2(to_x.call(edges[i + 1]), top))
		pts.append(Vector2(hist.end.x, hist.end.y))
		draw_colored_polygon(pts, Color(C_PANEL, 0.14))
		draw_polyline(pts, Color(C_PANEL, 0.7), 1.5)

	draw_line(Vector2(plot.position.x, plot.end.y), Vector2(plot.end.x, plot.end.y), C_AXIS, 1.5)
	for t in 6:
		var v := x_max * t / 5.0
		var tx: float = to_x.call(v)
		draw_line(Vector2(tx, plot.end.y), Vector2(tx, plot.end.y + 4), C_AXIS)
		draw_string(font, Vector2(tx - 30, plot.end.y + fs + 6), _fmt(v), HORIZONTAL_ALIGNMENT_CENTER, 60, fs - 1, C_TEXT)
