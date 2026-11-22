class_name RouletteTutorial
extends VBoxContainer
## A short hands-on practice round for the roulette (chips-and-bins) task,
## on a question with a known answer: how many heads in 10 coin flips.
##
## Built along common tutorial guidelines: one mechanic per step, learning by
## doing instead of reading, immediate feedback on every action, a safe place
## to make mistakes, and the option to skip or go back at any time. The last
## practice step scores the answer against the true chances, so the expert
## sees whether they tend to be too certain or too unsure.

## The practice ended: `skipped` is true when the user left early.
signal finished(skipped: bool)
## For the session log.
signal step_changed(index: int, title: String)

const HIGHLIGHT := RouletteFeedback.HIGHLIGHT
const GOOD := RouletteFeedback.GOOD
const FLIPS := 10

enum Step { DROP, TAKE_BACK, STACK, COIN, CERTAINTY }

const TITLES := ["Drop a chip", "Take it back", "Stack them up", "Your turn: 10 coin flips", "Sure or unsure?"]

var step := Step.DROP
var practice_spec: TargetSpec
var truth := PackedFloat64Array()  # P(k heads), k = 0…10
var _done := false
var _checked := false
var _last_total := 0

@onready var step_label: Label = %StepLabel
@onready var skip_button: Button = %SkipButton
@onready var instruction: RichTextLabel = %Instruction
@onready var feedback: RichTextLabel = %Feedback
@onready var practice: ChipRoulette = %Practice
@onready var practice_box: Control = %PracticeBox
@onready var clear_button: Button = %ClearButton
@onready var examples: HBoxContainer = %Examples
@onready var back_button: Button = %BackButton
@onready var check_button: Button = %CheckButton
@onready var next_button: Button = %NextButton


func _ready() -> void:
	practice_spec = _coin_spec()
	truth = _binomial(FLIPS, 0.5)
	practice.spec = practice_spec
	practice.show_prior = false
	practice.histogram_changed.connect(_on_chips_changed)
	clear_button.pressed.connect(practice.reset)
	skip_button.pressed.connect(func() -> void: finished.emit(true))
	back_button.pressed.connect(func() -> void: go_to(step - 1))
	next_button.pressed.connect(_on_next)
	check_button.pressed.connect(check_answer)
	_build_examples()
	go_to(Step.DROP)


## Starts over at the first step.
func restart() -> void:
	go_to(Step.DROP)


func go_to(index: int) -> void:
	step = clampi(index, 0, TITLES.size() - 1) as Step
	_done = false
	_checked = false
	practice.set_ghost(PackedInt32Array())
	if step == Step.DROP or step == Step.COIN:
		practice.reset()
	_last_total = practice.placed()
	step_label.text = "Practice %d of %d · %s" % [step + 1, TITLES.size(), TITLES[step]]
	instruction.text = _instruction()
	feedback.text = ""
	practice_box.visible = step != Step.CERTAINTY
	examples.visible = step == Step.CERTAINTY
	check_button.visible = step == Step.COIN
	back_button.disabled = step == Step.DROP
	if step == Step.CERTAINTY:
		_set_done("")
	_refresh()
	step_changed.emit(step, TITLES[step])


## Compares the coin-flip answer with the true chances and shows them.
func check_answer() -> void:
	if step != Step.COIN or not practice.is_complete():
		return
	_checked = true
	practice.set_ghost(_truth_chips())
	_set_done(RouletteFeedback.practice_verdict(practice_spec, practice.counts, truth))


func _on_next() -> void:
	if step == Step.CERTAINTY:
		finished.emit(false)
	else:
		go_to(step + 1)


func _on_chips_changed(counts: PackedInt32Array) -> void:
	var total := practice.placed()
	var removed := total < _last_total
	_last_total = total
	match step:
		Step.DROP:
			if total >= 1:
				var b := RouletteFeedback.used_bins(counts)[0]
				_set_done("That chip says: a [color=%s]5%%[/color] chance of %s heads. The grey line climbs to 100%% because all chips placed so far sit there." % [HIGHLIGHT, practice_spec.format_value(practice_spec.bin_center(b))])
		Step.TAKE_BACK:
			if removed:
				_set_done("Chips are never final: move them around until the picture matches what you believe.")
		Step.STACK:
			var top := RouletteFeedback._max(counts)
			if top >= 5:
				_set_done("That column holds [color=%s]%d%%[/color] of your belief: the taller the stack, the more likely you think that value is." % [HIGHLIGHT, top * 5])
			elif not _done:
				feedback.text = "%d of 5 chips in one column." % top
		Step.COIN:
			if _checked:  # changed after checking: compare again
				_checked = false
				_done = false
				practice.set_ghost(PackedInt32Array())
				feedback.text = "Changed your answer? Click [color=%s]Check my answer[/color] again." % HIGHLIGHT
			elif practice.chips_left() > 0:
				feedback.text = "%d chips to go." % practice.chips_left()
			else:
				feedback.text = "All 20 chips placed. Click [color=%s]Check my answer[/color]." % HIGHLIGHT
	_refresh()


func _set_done(text: String) -> void:
	_done = true
	if text != "":
		feedback.text = "[color=%s]✓[/color] %s" % [GOOD, text]
	_refresh()


func _refresh() -> void:
	next_button.disabled = not _done
	next_button.text = "Start the real questions →" if step == Step.CERTAINTY else "Next →"
	check_button.disabled = not practice.is_complete()


func _instruction() -> String:
	match step:
		Step.DROP:
			return "In the roulette task you answer by placing [color=%s]chips[/color]. Each of the 20 chips is 5%% of your belief.\n[color=%s]Left-click[/color] any column in the diagram to drop a chip there." % [HIGHLIGHT, HIGHLIGHT]
		Step.TAKE_BACK:
			return "Changed your mind? [color=%s]Right-click[/color] a column to take a chip back." % HIGHLIGHT
		Step.STACK:
			return "Put [color=%s]5 chips[/color] or more into one column. Several chips on a value make it more likely." % HIGHLIGHT
		Step.COIN:
			return "A fair coin is flipped 10 times. How many times will it land heads?\nUse all [color=%s]20 chips[/color] to show how likely each number is, then click [color=%s]Check my answer[/color]. Here, unlike in the real questions, the right answer is known." % [HIGHLIGHT, HIGHLIGHT]
		_:
			return "How you spread the chips says how sure you are. In the real questions there is no right answer to check: place the chips to match what you know, and read the feedback below each diagram."
	return ""


# ---------------------------------------------------------------- data

static func _coin_spec() -> TargetSpec:
	var s := TargetSpec.new()
	s.name = "practice"
	s.title = "Practice: 10 coin flips"
	s.unit = "heads in 10 flips"
	s.axis_min = -0.5
	s.axis_max = FLIPS + 0.5
	s.bin_width = 1.0
	s.discrete = true
	s.chips = 20
	return s


static func _binomial(n: int, p: float) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	for k in n + 1:
		var c := 1.0
		for i in k:
			c = c * (n - i) / (i + 1)
		out.append(c * pow(p, k) * pow(1.0 - p, n - k))
	return out


## The true chances as 20 chips, symmetric for a fair coin.
func _truth_chips() -> PackedInt32Array:
	var chips := PackedInt32Array()
	var given := 0
	for pk in truth:
		var c := int(floor(pk * practice_spec.chips))
		chips.append(c)
		given += c
	# hand out the rest where it is missing most: the middle alone, or a
	# symmetric pair of columns, so the picture stays symmetric
	var last := truth.size() - 1
	var mid := last / 2
	while given < practice_spec.chips:
		var best := mid
		var best_gap := -INF
		for k in mid + 1:
			if k != mid and practice_spec.chips - given < 2:
				continue
			var gap := truth[k] * practice_spec.chips - chips[k]
			if gap > best_gap:
				best_gap = gap
				best = k
		chips[best] += 1
		given += 1
		if best != mid:
			chips[last - best] += 1
			given += 1
	return chips


func _build_examples() -> void:
	var n := practice_spec.bin_count()
	var flat := []
	flat.resize(n)
	flat.fill(1.0)
	var cases := [
		["Very certain", "Almost all chips on one value.", RouletteFeedback.spread([3.0, 14.0, 3.0], 4, n, 20)],
		["Somewhat certain", "Chips spread over a few values.", RouletteFeedback.spread([1.0, 3.0, 5.0, 6.0, 4.0, 1.0], 2, n, 20)],
		["Very uncertain", "Chips spread over all values.", RouletteFeedback.spread(flat, 0, n, 20)],
	]
	for c in cases:
		var box := VBoxContainer.new()
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.add_theme_constant_override("separation", 2)
		var title := Label.new()
		title.text = c[0]
		title.add_theme_font_size_override("font_size", 15)
		title.add_theme_color_override("font_color", Color("#1f2a44"))
		box.add_child(title)
		var caption := Label.new()
		caption.text = c[1]
		caption.add_theme_font_size_override("font_size", 13)
		caption.add_theme_color_override("font_color", Color("#6b6b6b"))
		box.add_child(caption)
		var r := ChipRoulette.new()
		r.spec = practice_spec
		r.show_prior = false
		r.custom_minimum_size = Vector2(200, 170)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE  # an example, not an answer
		r.set_counts(c[2])
		box.add_child(r)
		examples.add_child(box)
