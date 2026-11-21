class_name FitView
extends TabContainer
## The "Fitted model" tab: Diagnostics, Priors and Predictions of the last
## fit. CaseStudyView calls setup() once, then show_single() or
## show_panel() after each fit. The predictions start playing the first
## time their tab is visible.

const PANEL_CAPTION := "Each dot is one quantile: the expert's answer across, what their fitted prior implies up. On the dashed diagonal = exact match."
const SINGLE_CAPTION := "Each dot is one quantile: your answer across, what the fitted prior implies up. On the dashed diagonal = exact match."

var case_study: CaseStudy
var predictions: PredictionsView
var _play_pending := false

@onready var diagnostics_page: Control = %DiagnosticsScroll
@onready var priors_page: Control = %PriorsScroll
@onready var predictions_page: ScrollContainer = %PredictionsScroll
@onready var final_loss: LossPlot = %FinalLoss
@onready var convergence_plot: ConvergencePlot = %ConvergencePlot
@onready var match_plot: MatchPlot = %MatchPlot
@onready var match_caption: RichTextLabel = %MatchCaption
@onready var prior_plot: PriorPlot = %PriorPlot
@onready var prior_text: RichTextLabel = %PriorText


func _ready() -> void:
	set_tab_title(get_tab_idx_from_control(diagnostics_page), "Diagnostics")
	set_tab_title(get_tab_idx_from_control(priors_page), "Priors")
	set_tab_title(get_tab_idx_from_control(predictions_page), "Predictions")
	tab_changed.connect(func(_i: int) -> void: _play_if_visible())
	visibility_changed.connect(_play_if_visible)


func setup(case_study_: CaseStudy) -> void:
	case_study = case_study_
	prior_plot.labels = case_study.parameter_labels
	convergence_plot.labels = case_study.parameter_labels
	var targets := []
	for spec in case_study.targets:
		targets.append({"name": spec.name, "title": spec.title})
	match_plot.targets = targets
	if case_study.predictions_scene:
		predictions = case_study.predictions_scene.instantiate()
		predictions.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		predictions_page.add_child(predictions)
		predictions.setup(case_study)


## Forget all fits, e.g. when the user starts over with another role.
func clear() -> void:
	prior_plot.clear()
	prior_text.text = "The fitted prior will appear here."


## A fit of one expert; the prior plot keeps the earlier fits of this role.
func show_single(result: Dictionary) -> void:
	var simulated: Dictionary = result.get("simulated_quantiles", {})
	var answers: Dictionary = result.get("expert", {})
	final_loss.set_points(result.get("loss_history", []))
	convergence_plot.show_single(result.get("bound_history", {}))
	match_plot.show_single(answers, simulated, result.get("probs", {}))
	match_caption.text = SINGLE_CAPTION + "\n" + FitSummary.match_line(case_study, answers, simulated)
	if result.get("backend") == "mock":
		match_caption.text += "\n" + FitSummary.MOCK_NOTE
	prior_plot.add_fit(result.get("priors", {}))
	prior_text.text = FitSummary.describe_single(case_study, result)
	if predictions:
		predictions.show_single(result.get("replay", []))
	_open()


## A panel fit. `experts`: [{"name", "color", "answers"}], in panel order.
func show_panel(result: Dictionary, experts: Array) -> void:
	var priors: Dictionary = result.get("expert_priors", {})
	var histories: Dictionary = result.get("expert_bound_history", {})
	var simulated: Dictionary = result.get("expert_simulated", {})
	var replays: Dictionary = result.get("expert_replays", {})
	var plotted := []
	var convergence := []
	var matches := []
	var rows := []
	var lines: Array[String] = [PANEL_CAPTION]
	for e in experts:
		if not priors.has(e.name):
			continue
		plotted.append({"name": e.name, "color": e.color, "priors": priors[e.name]})
		if histories.has(e.name):
			convergence.append({"name": e.name, "color": e.color, "history": histories[e.name]})
		if simulated.has(e.name):
			matches.append({"name": e.name, "color": e.color, "expert": e.answers, "model": simulated[e.name]})
			lines.append("[color=#%s][b]%s[/b][/color] %s" % [e.color.to_html(false), e.name, FitSummary.match_line(case_study, e.answers, simulated[e.name])])
		if replays.has(e.name):
			rows.append({"name": e.name, "color": e.color, "draws": replays[e.name]})
	final_loss.set_points(result.get("loss_history", []))
	convergence_plot.show_series(convergence)
	match_plot.show_series(matches, result.get("probs", {}))
	match_caption.text = "\n".join(lines)
	prior_plot.show_panel(plotted, result.get("population", {}))
	prior_text.text = FitSummary.describe_panel(case_study, result, experts)
	if predictions:
		predictions.show_panel(rows)
	_open()


## Shows Diagnostics first; the predictions wait until their tab is opened.
func _open() -> void:
	current_tab = get_tab_idx_from_control(diagnostics_page)
	_play_pending = true
	_play_if_visible()


func _play_if_visible() -> void:
	if _play_pending and predictions and predictions_page.is_visible_in_tree():
		_play_pending = false
		predictions.play()
