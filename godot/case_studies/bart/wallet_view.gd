class_name WalletView
extends Control
## A wallet that fills with coins while the replay plays: one coin per
## banked pump. Next to it, just two numbers: money gained and money lost
## in pops.

const C_GAIN := Color("#2e6b3a")
const C_LOST := Color("#e5604f")
const C_TEXT := Color("#6b6b6b")
const C_LEATHER := Color("#8b5a2b")
const C_FLAP := Color("#74461f")
const C_STITCH := Color("#c79a6b")
const C_COIN := Color("#f2c14e")
const C_COIN_RIM := Color("#c9962a")
const C_COIN_SHINE := Color("#fbe3a0")
const COINS_PER_STACK := 10
const MAX_STACKS := 8  # more coins than this show as "+N"
const STACK_GAP := 34.0
const WALLET_W := 130.0
const TEXT_W := 170.0
const COUNT_TIME := 0.45  # seconds for the numbers to count up

## Compact: a half-size wallet with the two numbers beside it, for the
## one-row-per-expert panel replay.
var compact := false:
	set(value):
		compact = value
		custom_minimum_size = Vector2(300, 74) if compact else Vector2(420, 130)
		queue_redraw()
var reward := 0.05
var currency := "€"
var gained := 0.0
var lost := 0.0
var coins := 0

var _gained_shown := 0.0
var _lost_shown := 0.0
var _coins_shown := 0.0
var _tween: Tween


func _init() -> void:
	custom_minimum_size = Vector2(420, 130)


func reset(reward_per_pump: float, currency_symbol: String) -> void:
	reward = reward_per_pump
	currency = currency_symbol
	gained = 0.0
	lost = 0.0
	coins = 0
	_gained_shown = 0.0
	_lost_shown = 0.0
	_coins_shown = 0.0
	if _tween:
		_tween.kill()
	queue_redraw()


## Count one finished trial: banked pumps become coins, a pop is a loss.
func add_trial(draw: Dictionary) -> void:
	var pumps := int(draw.get("pumps", 0))
	if bool(draw.get("burst", false)):
		lost += pumps * reward
	else:
		gained += pumps * reward
		coins += pumps
	_animate()


func _animate() -> void:
	if not is_inside_tree():
		_gained_shown = gained
		_lost_shown = lost
		_coins_shown = coins
		return
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_gained_shown, _gained_shown, gained, COUNT_TIME)
	_tween.tween_method(_set_lost_shown, _lost_shown, lost, COUNT_TIME)
	_tween.tween_method(_set_coins_shown, _coins_shown, float(coins), COUNT_TIME)


func _set_gained_shown(v: float) -> void:
	_gained_shown = v
	queue_redraw()


func _set_lost_shown(v: float) -> void:
	_lost_shown = v
	queue_redraw()


func _set_coins_shown(v: float) -> void:
	_coins_shown = v
	queue_redraw()


func money(amount: float) -> String:
	return "%s%.2f" % [currency, amount]


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _draw() -> void:
	var font := get_theme_font("font", "Label")
	var fs := get_theme_font_size("font_size", "Label")
	var k := 0.5 if compact else 1.0  # drawing scale
	var max_stacks := 5 if compact else MAX_STACKS
	var mid_y := size.y * 0.5
	var wallet_w := WALLET_W * k
	var gap := STACK_GAP * k
	var coins_w := 30.0 * k + max_stacks * gap
	# wallet | coin stacks | numbers; centred when full size, left-aligned when compact
	var ox := 4.0 if compact else maxf(16.0, (size.x - (wallet_w + coins_w + TEXT_W)) * 0.5)

	# the numbers
	var tx := ox + wallet_w + coins_w + 10.0 * k
	if compact:
		draw_string(font, Vector2(tx, mid_y - 4), money(_gained_shown) + " gained", HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 1, C_GAIN)
		draw_string(font, Vector2(tx, mid_y + 20), money(_lost_shown) + " lost", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 1, C_LOST)
	else:
		draw_string(font, Vector2(tx, mid_y - 30), "Gained", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, C_TEXT)
		draw_string(font, Vector2(tx, mid_y - 2), money(_gained_shown), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 11, C_GAIN)
		draw_string(font, Vector2(tx, mid_y + 24), "Lost in pops", HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, C_TEXT)
		draw_string(font, Vector2(tx, mid_y + 52), money(_lost_shown), HORIZONTAL_ALIGNMENT_LEFT, -1, fs + 11, C_LOST)

	# the wallet, with a couple of coins peeking out once it has money
	var wallet := Rect2(ox, mid_y - 36 * k, wallet_w, 84 * k)
	if _coins_shown >= 1.0:
		_coin(Vector2(wallet.position.x + 44 * k, wallet.position.y + 2 * k), true, k)
		_coin(Vector2(wallet.position.x + 70 * k, wallet.position.y - 2 * k), true, k)
	var body := StyleBoxFlat.new()
	body.bg_color = C_LEATHER
	body.set_corner_radius_all(int(12 * k))
	draw_style_box(body, wallet)
	var flap := StyleBoxFlat.new()
	flap.bg_color = C_FLAP
	flap.corner_radius_top_left = int(12 * k)
	flap.corner_radius_top_right = int(12 * k)
	flap.corner_radius_bottom_left = int(4 * k)
	flap.corner_radius_bottom_right = int(4 * k)
	draw_style_box(flap, Rect2(wallet.position, Vector2(wallet.size.x, 34 * k)))
	var inset := wallet.grow(-6 * k)
	for seg in [[inset.position, Vector2(inset.end.x, inset.position.y)], [Vector2(inset.position.x, inset.end.y), inset.end]]:
		draw_dashed_line(seg[0], seg[1], C_STITCH, 1.5 * k, 4.0 * k)
	var clasp := Vector2(wallet.end.x - 12 * k, wallet.position.y + 30 * k)
	draw_circle(clasp, 7.0 * k, C_COIN)
	draw_circle(clasp, 7.0 * k, C_COIN_RIM, false, 1.5 * k)

	# coin stacks between the wallet and the numbers
	var n := int(_coins_shown)
	var first_x := wallet.end.x + 30.0 * k
	var shown := mini(n, max_stacks * COINS_PER_STACK)
	var base_y := wallet.end.y - 4.0 * k
	for i in shown:
		@warning_ignore("integer_division")
		var stack := i / COINS_PER_STACK
		var level := i % COINS_PER_STACK
		var top := level == COINS_PER_STACK - 1 or i == shown - 1
		_coin(Vector2(first_x + stack * gap, base_y - level * 6.0 * k), top, k)
	if n > shown:
		draw_string(font, Vector2(first_x + (max_stacks - 1) * gap - 10 * k, base_y - 72 * k), "+%d" % (n - shown), HORIZONTAL_ALIGNMENT_LEFT, -1, fs - (6 if compact else 2), C_COIN_RIM)


## A coin seen at an angle: a squashed disc; the top coin of a stack shows its face.
func _coin(center: Vector2, show_face: bool, k := 1.0) -> void:
	draw_set_transform(center + Vector2(0, 3 * k), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 13.0 * k, C_COIN_RIM)  # the coin's edge
	draw_set_transform(center, 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 13.0 * k, C_COIN)
	if show_face:
		draw_circle(Vector2.ZERO, 9.0 * k, C_COIN_RIM, false, 1.5 * k)
		draw_circle(Vector2(-4, -4) * k, 3.0 * k, C_COIN_SHINE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
