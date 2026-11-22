class_name ElicitationPage
extends HBoxContainer
## The "Expert knowledge elicitation" tab: the expert places chips on each
## question (side by side), as themselves or as a persona, and sends the
## answers to elicito. "Next: Inspect prior" then opens the fitted model.
## Panels of several experts have their own tab (ExpertPanelPage).
##
## CaseStudyView hands in what the page needs with setup(); the page
## reports finished fits with `fit_finished` and never reaches outside.

## A fit of this page's expert came back.
signal fit_finished(result: Dictionary)
## The user switched to another role, so earlier fits no longer belong to
## the current expert.
signal fits_reset
## "Next: Inspect prior" was clicked.
signal next_requested

const C_OK := Color("#2e6b3a")
const C_BAD := Color("#c0392b")

var case_study: CaseStudy
var client: ElicitoClient
var settings_dialog: SettingsDialog
var session: SessionLog
var roulettes: Dictionary = {}  # target name -> ChipRoulette
var _titles: Dictionary = {}  # target name -> Label above its roulette
var _feedback: Dictionary = {}  # target name -> RichTextLabel below its roulette
var practice_done := false
var _practice_closed := false  # finished or skipped: opening it again starts over
var persona: ExpertPersona = null  # null = the user answers as themselves
var persona_chips: Dictionary = {}  # target name -> PackedInt32Array
var fitting := false  # this page is waiting for its own fit (the client is shared)
var fit_count := 0
var has_result := false  # a fit of the current expert(s) is in the Fitted model tab

@onready var intro_label: RichTextLabel = %Intro
@onready var roulette_help: FoldableContainer = %RouletteHelp
@onready var tutorial: RouletteTutorial = %RouletteTutorial
@onready var steps_text: RichTextLabel = %StepsText
@onready var persona_picker: OptionButton = %PersonaPicker
@onready var autofill_button: Button = %AutofillButton
@onready var briefing_card: PanelContainer = %BriefingCard
@onready var briefing_portrait: TextureRect = %BriefingPortrait
@onready var briefing_text: RichTextLabel = %BriefingText
@onready var questions: HBoxContainer = %Questions
@onready var hint_label: Label = %Hint
@onready var fit_button: Button = %FitButton
@onready var next_button: Button = %NextButton
@onready var settings_button: Button = %SettingsButton
@onready var fit_progress: FitProgress = %FitProgress
@onready var save_button: Button = %SaveButton
@onready var open_button: Button = %OpenButton
@onready var saved_label: Label = %SavedLabel


## Call once, after the page is in the tree.
func setup(case_study_: CaseStudy, client_: ElicitoClient, settings_dialog_: SettingsDialog, session_: SessionLog) -> void:
	case_study = case_study_
	client = client_
	settings_dialog = settings_dialog_
	session = session_
	intro_label.text = case_study.intro_text()
	_build_questions()
	tutorial.finished.connect(_on_practice_finished)
	tutorial.step_changed.connect(func(i: int, title: String) -> void: session.log_event("practice_step", {"step": i, "title": title}))
	roulette_help.folding_changed.connect(_on_practice_folding_changed)
	_build_persona_picker()

	client.connection_changed.connect(func(_c: bool, _b: String) -> void: _refresh())
	client.progress.connect(func(stage: String, done: int, total: int, loss: Variant, phase: int, phases: int) -> void:
		if fitting:
			fit_progress.on_progress(stage, done, total, loss, phase, phases))
	client.heartbeat.connect(func(elapsed: float) -> void:
		if fitting:
			fit_progress.on_heartbeat(elapsed))
	# the client is shared with the Expert panel tab: handle only our own fit
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
	settings_button.pressed.connect(settings_dialog.open)
	settings_dialog.settings_changed.connect(func(settings: Dictionary) -> void:
		session.log_event("settings_changed", settings)
		_update_settings_button())
	_update_settings_button()

	fit_button.pressed.connect(_on_fit_pressed)
	next_button.pressed.connect(next_requested.emit)
	save_button.pressed.connect(save_session)
	open_button.pressed.connect(_open_sessions_folder)
	_update_steps()


## Answer as this persona (null = as yourself), e.g. from a persona card.
func play_as(p: ExpertPersona) -> void:
	var index := 0 if p == null else case_study.personas.find(p) + 1
	persona_picker.select(index)
	_on_persona_selected(index)


## Who the current answers belong to, e.g. "the realistic expert".
func expert_label() -> String:
	return "the %s" % persona.display_name.to_lower() if persona else "your own answers"


func all_answered() -> bool:
	return roulettes.values().all(func(r: ChipRoulette) -> bool: return r.is_complete())


func save_session() -> void:
	var path := session.save()
	saved_label.text = ("Saved log: " + path.get_file()) if path != "" else "Could not save the session log"
	saved_label.tooltip_text = path


# ---------------------------------------------------------------- building

## One column per question, side by side, in the order of
## `case_study.targets`.
func _build_questions() -> void:
	for spec in case_study.targets:
		var page := VBoxContainer.new()
		page.name = spec.name
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page.add_theme_constant_override("separation", 6)

		var head := HBoxContainer.new()
		var title := Label.new()
		title.text = spec.title
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 18)
		title.add_theme_color_override("font_color", Color("#1f2a44"))
		head.add_child(title)
		var clear := Button.new()
		clear.text = "Clear"
		clear.tooltip_text = "Take all chips off this question."
		head.add_child(clear)
		page.add_child(head)

		var question := Label.new()
		question.text = spec.question
		question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(question)
		var roulette := ChipRoulette.new()
		roulette.spec = spec
		roulette.custom_minimum_size = Vector2(300, 330)
		roulette.size_flags_vertical = Control.SIZE_EXPAND_FILL
		roulette.show_prior = false  # the fitted prior is shown in the next tab
		roulette.histogram_changed.connect(_on_histogram_changed.bind(spec.name))
		clear.pressed.connect(roulette.reset)
		page.add_child(roulette)
		var fb := RichTextLabel.new()
		fb.bbcode_enabled = true
		fb.fit_content = true
		fb.add_theme_font_size_override("normal_font_size", 14)
		fb.add_theme_color_override("default_color", Color(0.23, 0.23, 0.23))
		page.add_child(fb)
		questions.add_child(page)
		roulettes[spec.name] = roulette
		_titles[spec.name] = title
		_feedback[spec.name] = fb


func _build_persona_picker() -> void:
	persona_picker.clear()
	persona_picker.add_item("Myself (my own beliefs)")
	for p in case_study.personas:
		persona_picker.add_item(p.display_name)
	persona_picker.item_selected.connect(_on_persona_selected)
	autofill_button.pressed.connect(_on_autofill_pressed)
	_on_persona_selected(0)


# ---------------------------------------------------------------- state

func _refresh() -> void:
	if case_study == null:
		return
	for spec in case_study.targets:
		_titles[spec.name].text = ("✓ " if roulettes[spec.name].is_complete() else "") + spec.title
		_feedback[spec.name].text = feedback_text(spec)
	var todo: Array[String] = []
	for spec in case_study.targets:
		var r: ChipRoulette = roulettes[spec.name]
		if not r.is_complete():
			todo.append("%s (%d chips left)" % [spec.title, r.chips_left()])
	var can_fit := client.connected and not client.is_outdated() and not client.is_busy() and not fitting
	next_button.disabled = fitting or not has_result
	next_button.tooltip_text = "" if has_result else "Fit the prior first."
	fit_button.disabled = not can_fit or not todo.is_empty()
	fit_button.tooltip_text = "Another fit is still running." if client.is_busy() and not fitting else ""
	fit_button.text = "Fitting…" if fitting else ("Fit prior with elicito" if fit_count == 0 else "Refit prior")
	if todo.is_empty():
		hint_label.text = "All answered. Fit the prior, or keep adjusting."
	else:
		hint_label.text = "Left-click drops a chip, right-click takes one back. To do: " + ", ".join(todo)


## The workflow above the persona menu.
func _update_steps() -> void:
	steps_text.text = (
		"[b]Elicitation workflow[/b]\n"
		+ "1. [color=#a8540f]Choose a persona:[/color] in the [color=#a8540f]Persona[/color] menu, pick a training persona, or [color=#a8540f]Myself[/color] for your own beliefs.\n"
		+ "2. [color=#a8540f]Place your chips:[/color] put all %d chips on each diagram (new to this? try [color=#a8540f]Practice the roulette task[/color] first). For a persona, [color=#a8540f]Fill in example expectations[/color] places the chips for you.\n" % _chips()
		+ "3. [color=#a8540f]Fit the prior:[/color] click [color=#a8540f]Fit prior with elicito[/color] on the right. elicito learns prior distributions that reproduce your answers.\n"
		+ "4. Click [color=#a8540f]Next: Inspect prior[/color] to see the result."
	)


## What the chips on one question say, plus a hint when something looks
## unintended (empty until all chips are placed).
func feedback_text(spec: TargetSpec) -> String:
	var counts: PackedInt32Array = roulettes[spec.name].counts
	var text := RouletteFeedback.summary(spec, counts)
	var tip := RouletteFeedback.hint(spec, counts)
	if tip != "":
		text += "\n[color=#6b6b6b]%s[/color]" % tip
	return text


func _on_practice_finished(skipped: bool) -> void:
	practice_done = practice_done or not skipped
	_practice_closed = true
	roulette_help.folded = true
	if practice_done:
		roulette_help.title = "Practice the roulette task ✓"
	session.log_event("practice_closed", {"skipped": skipped})


## Opening the practice again after it was closed starts it over.
func _on_practice_folding_changed(is_folded: bool) -> void:
	if not is_folded and _practice_closed:
		_practice_closed = false
		tutorial.restart()


func _chips() -> int:
	return case_study.targets[0].chips if case_study and not case_study.targets.is_empty() else 20


func _update_settings_button() -> void:
	if client.supports_settings:
		settings_button.disabled = false
		settings_button.text = "Training settings: " + settings_dialog.summary()
		settings_button.tooltip_text = "Change how elicito trains the prior: epochs, seed, number of runs and more."
	else:
		settings_button.disabled = true
		settings_button.text = "Training settings: elicito's defaults"
		settings_button.tooltip_text = "The precomputed fits used elicito's default settings. Start the elicito server to change them."


func _answers() -> Dictionary:
	var out := {}
	for target_name in roulettes:
		out[target_name] = Array(roulettes[target_name].quantiles())
	return out


func _histograms() -> Dictionary:
	var out := {}
	for target_name in roulettes:
		out[target_name] = Array(roulettes[target_name].counts)
	return out


func _persona_name() -> String:
	return persona.display_name if persona else "myself"


# ---------------------------------------------------------------- personas

func _on_persona_selected(index: int) -> void:
	persona = null if index == 0 else case_study.personas[index - 1]
	persona_chips = case_study.persona_chips(persona) if persona else {}
	autofill_button.visible = persona != null
	briefing_card.visible = persona != null
	if persona:
		briefing_portrait.texture = persona.portrait
		briefing_text.text = "[color=#a8540f]You are the %s.[/color] %s" % [persona.display_name.to_lower(), persona.briefing]
		var style := StyleBoxFlat.new()
		style.bg_color = persona.color.lerp(Color.WHITE, 0.85)
		style.border_color = persona.color
		style.border_width_left = 5
		style.set_content_margin_all(10)
		briefing_card.add_theme_stylebox_override("panel", style)
	for r in roulettes.values():
		r.reset()
	fit_count = 0
	has_result = false
	fits_reset.emit()
	session.log_event("persona_selected", {"persona": _persona_name()})
	_refresh()


## "Fill in example expectations": places the persona's chips on every
## question.
func _on_autofill_pressed() -> void:
	for target_name in roulettes:
		if persona_chips.has(target_name):
			roulettes[target_name].set_counts(persona_chips[target_name])
	session.log_event("autofill", {"persona": _persona_name()})
	_refresh()


# ---------------------------------------------------------------- fitting

func _on_histogram_changed(counts: PackedInt32Array, target_name: String) -> void:
	session.log_event("chips", {"target": target_name, "counts": Array(counts)})
	_refresh()


func _on_fit_pressed() -> void:
	if client.is_busy():
		fit_progress.fail("Another fit is still running. Try again when it is done.")
		return
	var settings := settings_dialog.to_request()
	var request_id := client.request_fit(case_study.id, _answers(), case_study.replay_n, settings)
	if request_id == "":
		return
	session.log_event("fit_requested", {"request_id": request_id, "persona": _persona_name(), "expert": _answers(), "histograms": _histograms(), "settings": settings})
	fit_progress.start("Sending your answers to elicito…")
	fitting = true
	_refresh()


func _on_fit_finished(result: Dictionary) -> void:
	fitting = false
	var elapsed := float(result.get("elapsed", 0.0))
	fit_count += 1
	var simulated: Dictionary = result.get("simulated_quantiles", {})
	for target_name in roulettes:
		if simulated.has(target_name):
			roulettes[target_name].set_model_quantiles(PackedFloat64Array(simulated[target_name]))
	var message := "Fit #%d done in %.1f s." % [fit_count, elapsed]
	if result.has("precomputed"):
		var info: Dictionary = result.precomputed
		message = "Precomputed fit loaded." if info.get("exact", false) else (
			"Precomputed fit of the %s's answers loaded (the closest to yours)." % str(info.get("scenario", "")).to_lower())
	fit_progress.finish(result.get("loss_history", []), message + " Click Next: Inspect prior to see it.")
	var history: Array = result.get("loss_history", [])
	session.log_event("fit_result", {
		"request_id": result.get("request_id"),
		"backend": result.get("backend"),
		"hyperparameters": result.get("hyperparameters"),
		"priors": result.get("priors"),
		"final_loss": history[-1] if not history.is_empty() else null,
		"simulated_quantiles": simulated,
		"replay": result.get("replay"),
		"saved_eliobj": result.get("saved_eliobj"),
	})
	has_result = true
	fit_finished.emit(result)
	save_session()
	_refresh()


func _on_fit_failed(message: String) -> void:
	fitting = false
	fit_progress.fail("Fit failed: %s" % message)
	session.log_event("fit_failed", {"message": message})
	_refresh()


func _open_sessions_folder() -> void:
	DirAccess.make_dir_recursive_absolute("user://sessions")
	OS.shell_open(ProjectSettings.globalize_path("user://sessions"))
