class_name CaseStudyView
extends TabContainer
## One case study, as tabs: the statistical model, the training personas,
## the elicitation, the fitted model, the expert panel and where to go next.
## It wires the tabs together: they never talk to each other directly.

var case_study: CaseStudy
var session: SessionLog

@onready var model_page: Control = %ModelPage
@onready var model_text: RichTextLabel = %ModelText
@onready var next_button: Button = %NextButton
@onready var personas_page: PersonasPage = %PersonasPage
@onready var elicitation_page: ElicitationPage = %ElicitationPage
@onready var fit_view: FitView = %FitView
@onready var panel_page: ExpertPanelPage = %ExpertPanelPage
@onready var next_steps: NextStepsPage = %NextStepsPage


func _ready() -> void:
	set_tab_title(get_tab_idx_from_control(model_page), "Statistical model")
	set_tab_title(get_tab_idx_from_control(personas_page), "Training personas")
	set_tab_title(get_tab_idx_from_control(elicitation_page), "Expert knowledge elicitation")
	set_tab_title(get_tab_idx_from_control(fit_view), "Fitted model")
	set_tab_title(get_tab_idx_from_control(panel_page), "Expert panel")
	set_tab_title(get_tab_idx_from_control(next_steps), "Where to go next")


## Call once, after the view is in the tree.
func setup(case_study_: CaseStudy, client: ElicitoClient, settings_dialog: SettingsDialog) -> void:
	case_study = case_study_
	session = SessionLog.new(case_study.id)
	session.log_event("session_start", {"targets": case_study.targets.map(func(t: TargetSpec) -> String: return t.name), "server": client.url})

	model_text.text = case_study.model_text
	personas_page.setup(case_study)
	set_tab_hidden(get_tab_idx_from_control(personas_page), case_study.personas.is_empty())
	elicitation_page.setup(case_study, client, settings_dialog, session)
	fit_view.setup(case_study)
	panel_page.setup(case_study, client, settings_dialog, session)
	set_tab_hidden(get_tab_idx_from_control(panel_page), case_study.personas.size() < 2)
	next_steps.setup(case_study)
	set_tab_hidden(get_tab_idx_from_control(next_steps), case_study.posterior_languages().is_empty())

	personas_page.play_requested.connect(func(p: ExpertPersona) -> void:
		elicitation_page.play_as(p)
		show_page(elicitation_page))
	elicitation_page.fits_reset.connect(func() -> void:
		fit_view.clear()
		next_steps.remove_source("single"))
	# below the model: on to the next tab (the personas, or the elicitation)
	var next := next_tab(get_tab_idx_from_control(model_page))
	next_button.text = "Next: %s →" % get_tab_title(next)
	next_button.pressed.connect(func() -> void: current_tab = next)
	# below the personas: on to the elicitation
	personas_page.next_button.text = "Next: Elicit knowledge →"
	personas_page.next_requested.connect(func() -> void: show_page(elicitation_page))
	elicitation_page.next_requested.connect(func() -> void: show_page(fit_view))
	elicitation_page.fit_finished.connect(_on_fit_finished)
	panel_page.panel_fitted.connect(_on_panel_fitted)
	panel_page.next_requested.connect(func() -> void: show_page(next_steps))


## The first visible tab after `index`.
func next_tab(index: int) -> int:
	for i in range(index + 1, get_tab_count()):
		if not is_tab_hidden(i):
			return i
	return index


func show_page(page: Control) -> void:
	current_tab = get_tab_idx_from_control(page)


func _on_fit_finished(result: Dictionary) -> void:
	fit_view.show_single(result)
	next_steps.set_source("single", "Your fit (%s)" % elicitation_page.expert_label(), result.get("priors", {}))


## The panel's priors for "Where to go next": each expert's, and with
## partial pooling also the shared one (shown first).
func _on_panel_fitted(result: Dictionary, experts: Array) -> void:
	next_steps.remove_sources_with_prefix("panel")
	var independent: bool = result.get("pooling", "partial") == "independent"
	var how := "independent fit" if independent else "partial pooling"
	var priors: Dictionary = result.get("expert_priors", {})
	for e in experts:
		if priors.has(e.name):
			next_steps.set_source("panel:" + e.name, "%s (expert panel, %s)" % [e.name, how], priors[e.name])
	var names := experts.map(func(e: Dictionary) -> String: return e.name)
	if not independent and not result.get("panel_priors", {}).is_empty():
		next_steps.set_source("panel", "Expert panel (%s), shared prior" % ", ".join(names), result.panel_priors)
	else:
		next_steps.select_source("panel:" + str(names[0]))
