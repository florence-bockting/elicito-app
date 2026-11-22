class_name ExpertPanelPage
extends HBoxContainer
## The "Expert panel" tab: the training personas answer together, and
## elicito learns a prior for each of them, either with partial pooling (one
## joint fit: the experts' priors share a common part) or independently (one
## fit per expert, nothing shared). The results appear in this tab, below
## the experts.
##
## CaseStudyView hands in what the page needs with setup(); the page
## reports finished panel fits with `panel_fitted`.

## A panel fit of this page came back. `experts` lists {"name", "color",
## "answers"} in panel order.
signal panel_fitted(result: Dictionary, experts: Array)
## "Next: Where to go next" was clicked.
signal next_requested

const C_OK := Color("#2e6b3a")
const HIGHLIGHT := "#a8540f"

var case_study: CaseStudy
var client: ElicitoClient
var settings_dialog: SettingsDialog
var session: SessionLog
var panel := ExpertPanel.new()
var checks: Dictionary = {}  # persona display name -> CheckBox
var fitting := false  # this page is waiting for its own fit (the client is shared)
var pooling := "partial"  # or "independent"
var has_result := false

@onready var intro: RichTextLabel = %PanelIntro
@onready var experts_box: VBoxContainer = %Experts
@onready var results_title: Label = %ResultsTitle
@onready var results: FitView = %PanelFitView
@onready var fit_button: Button = %PanelFitButton
@onready var fit_progress: FitProgress = %PanelFitProgress
@onready var hint_label: Label = %PanelHint
@onready var next_button: Button = %PanelNextButton
@onready var scroll: ScrollContainer = %PanelScroll
@onready var partial_check: CheckBox = %PartialCheck
@onready var independent_check: CheckBox = %IndependentCheck
@onready var pooling_text: RichTextLabel = %PoolingText


## Call once, after the page is in the tree.
func setup(case_study_: CaseStudy, client_: ElicitoClient, settings_dialog_: SettingsDialog, session_: SessionLog) -> void:
	case_study = case_study_
	client = client_
	settings_dialog = settings_dialog_
	session = session_
	intro.text = _intro_text()
	results.setup(case_study)
	_build_experts()

	client.connection_changed.connect(func(_c: bool, _b: String) -> void: _refresh())
	client.progress.connect(func(stage: String, done: int, total: int, loss: Variant, phase: int, phases: int) -> void:
		if fitting:
			fit_progress.on_progress(stage, done, total, loss, phase, phases))
	client.heartbeat.connect(func(elapsed: float) -> void:
		if fitting:
			fit_progress.on_heartbeat(elapsed))
	# the client is shared with the elicitation tab: handle only our own fit
	client.fit_finished.connect(func(result: Dictionary) -> void:
		if fitting:
			_on_fit_finished(result)
		else:
			_refresh())
	client.fit_failed.connect(func(message: String) -> void:
		if fitting:
			_on_fit_failed(message)
		else:
			_refresh())
	partial_check.toggled.connect(func(on: bool) -> void:
		if on:
			set_pooling("partial"))
	independent_check.toggled.connect(func(on: bool) -> void:
		if on:
			set_pooling("independent"))
	set_pooling("partial")
	fit_button.pressed.connect(fit_panel)
	next_button.pressed.connect(next_requested.emit)
	fit_progress.set_status("Choose at least two experts, then fit the panel.")
	_refresh()


## The ticked personas, in the order of the case study.
func chosen() -> Array[ExpertPersona]:
	var out: Array[ExpertPersona] = []
	for p in case_study.personas:
		if checks[p.display_name].button_pressed:
			out.append(p)
	return out


func set_chosen(personas: Array) -> void:
	for p in case_study.personas:
		checks[p.display_name].button_pressed = p in personas
	_refresh()


## "partial" or "independent": how elicito combines the experts.
func set_pooling(value: String) -> void:
	pooling = value
	partial_check.set_pressed_no_signal(value == "partial")
	independent_check.set_pressed_no_signal(value == "independent")
	if value == "partial":
		pooling_text.text = "One joint fit. Each expert gets their own prior, but the priors share a common part: experts are pulled a little toward the panel, and elicito estimates how much they disagree."
	else:
		pooling_text.text = "One fit per expert, one after another. Each prior comes from that expert's answers alone; the panel as a whole is an equal mix of the experts' priors."
	_refresh()


func fit_panel() -> void:
	if client.is_busy():
		fit_progress.fail("Another fit is still running. Try again when it is done.")
		return
	panel.clear()
	for p in chosen():
		panel.add(p.character_name if p.character_name != "" else p.display_name, case_study.persona_answers(p), case_study.persona_chips(p), p)
	var experts := panel.answers_by_name()
	var settings := settings_dialog.to_request()
	var request_id := client.request_fit_panel(case_study.id, experts, case_study.replay_n, settings, pooling)
	if request_id == "":
		return
	session.log_event("panel_fit_requested", {"request_id": request_id, "experts": experts, "settings": settings, "pooling": pooling})
	if pooling == "independent":
		fit_progress.start("Sending %d experts to elicito, to be fitted one after another…" % experts.size())
	else:
		fit_progress.start("Sending %d experts to elicito…" % experts.size())
	fitting = true
	_refresh()


# ---------------------------------------------------------------- building

func _intro_text() -> String:
	return (
		"[b]Several experts, one fit[/b]\n"
		+ "Real elicitations rarely rely on a single expert. Here the training personas form a panel: each one answers the same questions, and elicito learns a prior for each of them. "
		+ "On the right, choose how: with [color=%s]partial pooling[/color] the experts' priors share a common part; [color=%s]independently[/color], each prior comes from that expert alone.\n" % [HIGHLIGHT, HIGHLIGHT]
		+ "Below are the answers each persona gives (the same as [color=%s]Fill in example expectations[/color]). Untick a persona to leave them out; a panel needs at least two." % HIGHLIGHT
	)


## One row per persona: tick box, portrait, name and their two answers.
func _build_experts() -> void:
	for p in case_study.personas:
		var card := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = p.color.lerp(Color.WHITE, 0.88)
		style.border_color = p.color
		style.border_width_left = 5
		style.set_corner_radius_all(6)
		style.set_content_margin_all(10)
		card.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)

		var who := VBoxContainer.new()
		who.custom_minimum_size = Vector2(190, 0)
		var check := CheckBox.new()
		check.text = p.character_name if p.character_name != "" else p.display_name
		check.button_pressed = true
		check.add_theme_font_size_override("font_size", 17)
		check.toggled.connect(func(_on: bool) -> void: _refresh())
		who.add_child(check)
		var portrait := TextureRect.new()
		portrait.texture = p.portrait
		portrait.custom_minimum_size = Vector2(64, 64)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		who.add_child(portrait)
		var role := Label.new()
		role.text = p.display_name
		role.add_theme_font_size_override("font_size", 13)
		role.add_theme_color_override("font_color", Color("#6b6b6b"))
		who.add_child(role)
		row.add_child(who)

		var chips := case_study.persona_chips(p)
		for spec in case_study.targets:
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var title := Label.new()
			title.text = spec.title
			title.add_theme_font_size_override("font_size", 13)
			title.add_theme_color_override("font_color", Color("#1f2a44"))
			col.add_child(title)
			var r := ChipRoulette.new()
			r.spec = spec
			r.show_prior = false
			r.custom_minimum_size = Vector2(200, 130)
			r.mouse_filter = Control.MOUSE_FILTER_IGNORE  # shown, not edited
			if chips.has(spec.name):
				r.set_counts(chips[spec.name])
			col.add_child(r)
			row.add_child(col)
		experts_box.add_child(card)
		checks[p.display_name] = check


func _refresh() -> void:
	if case_study == null:
		return
	var n := chosen().size()
	var can_fit := client.connected and not client.is_outdated() and not client.is_busy() and not fitting
	fit_button.disabled = not can_fit or n < 2
	fit_button.text = "Fitting…" if fitting else "Fit expert panel with elicito (%d)" % n
	fit_button.tooltip_text = "Tick at least two experts." if n < 2 else ("Another fit is still running." if client.is_busy() and not fitting else "")
	for c in checks.values():
		c.disabled = fitting
	partial_check.disabled = fitting
	independent_check.disabled = fitting
	hint_label.text = "Tick at least two experts." if n < 2 else "%d experts in the panel." % n
	next_button.disabled = fitting
	results_title.visible = has_result
	results.visible = has_result


# ---------------------------------------------------------------- fitting

func _on_fit_finished(result: Dictionary) -> void:
	fitting = false
	var message := "Panel fitted in %.0f s." % float(result.get("elapsed", 0.0))
	if result.has("precomputed"):
		message = "Precomputed panel fit loaded."
	fit_progress.finish(result.get("loss_history", []), message + " The results are below the experts.")
	session.log_event("panel_result", {
		"request_id": result.get("request_id"),
		"backend": result.get("backend"),
		"expert_priors": result.get("expert_priors"),
		"panel_priors": result.get("panel_priors"),
		"tau": result.get("tau"),
		"pooling": result.get("pooling", "partial"),
		"saved_eliobj": result.get("saved_eliobj"),
	})
	var experts := []
	for e in panel.experts:
		experts.append({"name": e.name, "color": e.color, "answers": e.answers})
	has_result = true
	_refresh()
	results.show_panel(result, experts)
	panel_fitted.emit(result, experts)
	# bring the results into view
	await get_tree().process_frame
	if is_inside_tree():
		scroll.ensure_control_visible(results_title)


func _on_fit_failed(message: String) -> void:
	fitting = false
	fit_progress.fail("Fit failed: %s" % message)
	session.log_event("fit_failed", {"message": message})
	_refresh()
