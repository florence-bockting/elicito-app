extends Node2D
## One simulated BART trial from the prior predictive distribution.
##
## The balloon grows with every pump. It either pops (the trial ended in a
## burst) or the participant stops and banks. Colour shows the planned
## number of pumps ω (blue = cautious, red = risky); the faint ring shows
## the size the balloon would reach at ω pumps. If the draw carries a
## "reward_per_pump", a second line shows the money: what is in the
## temporary bank while pumping, then banked (green) or lost (red).

signal finished(draw: Dictionary)

const BASE_R := 9.0
const GROW := 1.5  # radius per pump
const PUMP_TIME := 0.14
const STRING_END := 66.0  # strings are tied to a fixed point below the balloon
const C_CAUTIOUS := Color("#4a90c2")
const C_MID := Color("#f2b84b")
const C_RISKY := Color("#e5604f")
const OMEGA_RISKY := 10.0  # ω at which the colour is fully red

var radius := BASE_R:
	set(v):
		radius = v
		queue_redraw()

var draw_data: Dictionary = {}
var _color := C_CAUTIOUS
var _popped := false
var _tween: Tween

@onready var _pop: CPUParticles2D = $Pop
@onready var _label: Label = $Label
@onready var _money: Label = $Money


## Animate one draw: {"pumps": int, "burst": bool, "omega": float, ...}.
func play(draw: Dictionary, delay := 0.0, speed := 1.0) -> void:
	draw_data = draw
	_popped = false
	radius = BASE_R
	_label.text = ""
	_label.modulate = Color.WHITE
	_money.text = ""
	_money.modulate = Color(0.42, 0.42, 0.42)
	var omega := float(draw.get("omega", 0.0))
	_color = risk_color(omega)
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_interval(delay)
	for i in int(draw.get("pumps", 0)):
		_tween.tween_property(self, "radius", BASE_R + (i + 1) * GROW, PUMP_TIME / speed) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tween.tween_callback(_show_count.bind(i + 1))
	_tween.tween_callback(_finish.bind(bool(draw.get("burst", false))))


## Blue (cautious) -> amber -> red (risky), by the planned number of pumps.
static func risk_color(omega: float) -> Color:
	var t := clampf(omega / OMEGA_RISKY, 0.0, 1.0)
	return C_CAUTIOUS.lerp(C_MID, t * 2.0) if t < 0.5 else C_MID.lerp(C_RISKY, t * 2.0 - 1.0)


## One-line summary of a whole replay, shown above the grid.
func summarize(draws: Array) -> String:
	if draws.is_empty():
		return ""
	var pumps: Array[int] = []
	var popped := 0
	for d in draws:
		pumps.append(int(d.get("pumps", 0)))
		if bool(d.get("burst", false)):
			popped += 1
	pumps.sort()
	@warning_ignore("integer_division")
	var median := pumps[pumps.size() / 2]
	return "%d of %d balloons popped · median %d pumps · range %d to %d" % [
		popped, draws.size(), median, pumps[0], pumps[-1]
	]


func _show_count(n: int) -> void:
	_label.text = str(n)
	if _reward() > 0.0:
		_money.text = _money_text(n * _reward())


func _reward() -> float:
	return float(draw_data.get("reward_per_pump", 0.0))


func _money_text(amount: float) -> String:
	return "%s%.2f" % [draw_data.get("currency", "€"), amount]


func _finish(burst: bool) -> void:
	var n := int(draw_data.get("pumps", 0))
	if burst:
		_popped = true
		_pop.color = _color
		_pop.restart()
		_label.text = "pop! %d" % n
		_label.modulate = C_RISKY
		if _reward() > 0.0:
			_money.text = "lost " + _money_text(n * _reward())
			_money.modulate = C_RISKY
		queue_redraw()
	else:
		_label.text = "kept %d" % n
		_label.modulate = Color("#2e6b3a")
		if _reward() > 0.0:
			_money.text = "+" + _money_text(n * _reward())
			_money.modulate = Color("#2e6b3a")
	finished.emit(draw_data)


func _draw() -> void:
	var omega := float(draw_data.get("omega", 0.0))
	if omega > 0.0:
		draw_arc(Vector2.ZERO, BASE_R + omega * GROW, 0.0, TAU, 40, Color(_color, 0.22), 1.0, true)
	if _popped:
		draw_line(Vector2(0, STRING_END - 14.0), Vector2(0, STRING_END), Color(0.3, 0.3, 0.3, 0.5), 1.0, true)
		return
	var bottom := radius * 1.12
	var string_pts := PackedVector2Array()
	for i in 9:
		var t := i / 8.0
		string_pts.append(Vector2(sin(t * PI * 2.0) * 2.5, lerpf(bottom + 4.0, STRING_END, t)))
	draw_polyline(string_pts, Color(0.3, 0.3, 0.3, 0.8), 1.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 1.12))
	draw_circle(Vector2.ZERO, radius, _color)
	draw_circle(Vector2(-radius * 0.35, -radius * 0.4), radius * 0.22, Color(1, 1, 1, 0.45))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_colored_polygon(
		PackedVector2Array([Vector2(0, bottom - 1), Vector2(-4, bottom + 5), Vector2(4, bottom + 5)]),
		_color.darkened(0.2)
	)
