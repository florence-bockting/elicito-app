class_name FitProgress
extends VBoxContainer
## Status of the running fit: a message, a progress bar over all phases,
## and the training loss. Warm-up runs (and elicito's search for a
## starting point) only move the bar; the loss shows the real training.

const C_OK := Color("#2e6b3a")
const C_BAD := Color("#c0392b")
const C_MUTED := Color("#6b6b6b")

var _phase := 0  # phase of the last training update

@onready var status_label: Label = %FitStatus
@onready var progress_bar: ProgressBar = %Progress
@onready var loss_plot: LossPlot = %LossPlot


func set_status(text: String, color := C_MUTED) -> void:
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


## A new fit: empty bar, no loss until the real training starts.
func start(message: String) -> void:
	_phase = 0
	loss_plot.clear()
	loss_plot.visible = false
	progress_bar.value = 0
	set_status(message)


func on_progress(stage: String, done: int, total: int, loss: Variant, phase: int, phases: int) -> void:
	var frac := float(done) / maxi(total, 1)
	progress_bar.value = 100.0 * (phase - 1 + frac) / maxi(phases, 1)
	var step := "Step %d of %d · " % [phase, phases] if phases > 1 else ""
	if stage == "Training":
		if phase != _phase:  # a new training run, e.g. the next expert of an independent panel
			loss_plot.clear()
		_phase = phase
		set_status("%sTraining the prior… %d / %d simulations" % [step, done, total])
		if loss != null:
			loss_plot.visible = true
			loss_plot.add_point(float(loss))
	elif stage == "Warm-up":
		set_status("%sWarm-up: measuring how much the experts disagree… %d%%" % [step, roundi(frac * 100.0)])
	else:
		set_status("%sFinding a starting point… %d%%" % [step, roundi(frac * 100.0)])


func on_heartbeat(elapsed: float) -> void:
	if progress_bar.value == 0:
		set_status("Waiting for elicito… %d s" % int(elapsed))


func finish(loss_history: Array, message: String) -> void:
	progress_bar.value = 100
	loss_plot.visible = true
	loss_plot.set_points(loss_history)
	set_status(message, C_OK)


func fail(message: String) -> void:
	set_status(message, C_BAD)
