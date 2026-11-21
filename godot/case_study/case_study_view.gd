class_name CaseStudyView
extends TabContainer
## One case study, as four tabs: the statistical model, the training
## personas, the elicitation and the fitted model. It wires the tabs
## together: they never talk to each other directly.

var case_study: CaseStudy
var session: SessionLog

@onready var model_text: RichTextLabel = %ModelText
@onready var personas_page: PersonasPage = %PersonasPage
@onready var elicitation_page: ElicitationPage = %ElicitationPage
@onready var fit_view: FitView = %FitView


func _ready() -> void:
	set_tab_title(get_tab_idx_from_control(model_text), "Statistical model")
	set_tab_title(get_tab_idx_from_control(personas_page), "Training personas")
	set_tab_title(get_tab_idx_from_control(elicitation_page), "Expert knowledge elicitation")
	set_tab_title(get_tab_idx_from_control(fit_view), "Fitted model")


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

	personas_page.play_requested.connect(func(p: ExpertPersona) -> void:
		elicitation_page.play_as(p)
		show_page(elicitation_page))
	elicitation_page.fits_reset.connect(fit_view.clear)
	elicitation_page.fit_finished.connect(_on_fit_finished)


func show_page(page: Control) -> void:
	current_tab = get_tab_idx_from_control(page)


func _on_fit_finished(result: Dictionary, experts: Array) -> void:
	if experts.is_empty():
		fit_view.show_single(result)
	else:
		fit_view.show_panel(result, experts)
	show_page(fit_view)
