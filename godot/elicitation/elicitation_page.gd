class_name ElicitationPage
extends HBoxContainer
## The "Expert knowledge elicitation" tab: the expert places chips on each
## question, as themselves or as a persona, and sends the answers to
## elicito. With "Multiple experts" the answers are collected into a panel
## first.
##
## CaseStudyView hands in what the page needs with setup(); the page
## reports finished fits with `fit_finished` and never reaches outside.

## A fit came back. `experts` is empty for one expert; for a panel it lists
## {"name", "color", "answers"} in panel order.
signal fit_finished(result: Dictionary, experts: Array)
## The user switched to another role in single-expert mode, so earlier
## fits no longer belong to the current expert.
signal fits_reset

const C_OK := Color("#2e6b3a")
const C_BAD := Color("#c0392b")

var case_study: CaseStudy
var client: ElicitoClient
var settings_dialog: SettingsDialog
var session: SessionLog
var roulettes: Dictionary = {}  # target name -> ChipRoulette
var persona: ExpertPersona = null  # null = the user answers as themselves
var persona_chips: Dictionary = {}  # target name -> PackedInt32Array
var multi_mode := false
var panel := ExpertPanel.new()
var fitting := false
var fit_count := 0

@onready var intro_label: Label = %Intro
@onready var steps_text: RichTextLabel = %StepsText
@onready var persona_picker: OptionButton = %PersonaPicker
@onready var show_me_toggle: CheckButton = %ShowMeToggle
@onready var autofill_button: Button = %AutofillButton
@onready var multi_check: CheckBox = %MultiCheck
@onready var expert_name: LineEdit = %ExpertName
@onready var add_expert_button: Button = %AddExpertButton
@onready var briefing_card: PanelContainer = %BriefingCard
@onready var briefing_portrait: TextureRect = %BriefingPortrait
@onready var briefing_text: RichTextLabel = %BriefingText
@onready var tabs: TabContainer = %Tabs
@onready var hint_label: Label = %Hint
@onready var reset_button: Button = %ResetButton
@onready var fit_button: Button = %FitButton
@onready var settings_button: Button = %SettingsButton
@onready var fit_progress: FitProgress = %FitProgress
@onready var panel_box: ExpertPanelBox = %ExpertPanelBox
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
	panel_box.show_panel(panel)
	panel.changed.connect(_refresh)
	_build_questions()
	_build_persona_picker()

	client.connection_changed.connect(func(_c: bool, _b: String) -> void: _refresh())
	client.progress.connect(fit_progress.on_progress)
	client.heartbeat.connect(fit_progress.on_heartbeat)
	client.fit_finished.connect(_on_fit_finished)
	client.fit_failed.connect(_on_fit_failed)
	settings_button.pressed.connect(settings_dialog.open)
	settings_dialog.settings_changed.connect(func(settings: Dictionary) -> void:
		session.log_event("settings_changed", settings)
		_update_settings_button())
	_update_settings_button()

	fit_button.pressed.connect(_on_fit_pressed)
	reset_button.pressed.connect(_on_reset_pressed)
	tabs.tab_changed.connect(func(_i: int) -> void: _refresh())
	add_expert_button.pressed.connect(add_expert)
	expert_name.text_submitted.connect(func(_t: String) -> void:
		if not add_expert_button.disabled:
			add_expert())
	multi_check.toggled.connect(set_multi_mode)
	save_button.pressed.connect(save_session)
	open_button.pressed.connect(_open_sessions_folder)
	set_multi_mode(false)


## Answer as this persona (null = as yourself), e.g. from a persona card.
func play_as(p: ExpertPersona) -> void:
	var index := 0 if p == null else case_study.personas.find(p) + 1
	persona_picker.select(index)
	_on_persona_selected(index)


## "Multiple experts": show the panel controls and switch the Fit button.
func set_multi_mode(on: bool) -> void:
	multi_mode = on
	multi_check.set_pressed_no_signal(on)
	expert_name.visible = on
	add_expert_button.visible = on
	panel_box.visible = on
	_update_steps()
	expert_name.placeholder_text = panel.default_name(persona)
	session.log_event("multiple_experts", {"on": on})
	_refresh()


## Saves the current chips as one expert of the panel and clears the board
## for the next expert.
func add_expert() -> void:
	var typed := expert_name.text.strip_edges()
	var added := panel.add(typed if typed != "" else panel.default_name(persona), _answers(), _histograms(), persona)
	session.log_event("panel_add", {"name": added, "persona": _persona_name(), "answers": _answers(), "histograms": _histograms()})
	expert_name.clear()
	for r in roulettes.values():
		r.reset()
	fit_progress.set_status("%s added to the expert panel." % added, C_OK)
	expert_name.placeholder_text = panel.default_name(persona)
	_refresh()


func all_answered() -> bool:
	return roulettes.values().all(func(r: ChipRoulette) -> bool: return r.is_complete())


func save_session() -> void:
	var path := session.save()
	saved_label.text = ("Saved log: " + path.get_file()) if path != "" else "Could not save the session log"
	saved_label.tooltip_text = path


# ---------------------------------------------------------------- building

func _build_questions() -> void:
	for spec in case_study.targets:
		var page := VBoxContainer.new()
		page.name = spec.name
		page.add_theme_constant_override("separation", 6)
		var question := Label.new()
		question.text = spec.question
		question.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(question)
		var roulette := ChipRoulette.new()
		roulette.spec = spec
		roulette.custom_minimum_size = Vector2(420, 230)
		roulette.size_flags_vertical = Control.SIZE_EXPAND_FILL
		roulette.histogram_changed.connect(_on_histogram_changed.bind(spec.name))
		page.add_child(roulette)
		tabs.add_child(page)
		roulettes[spec.name] = roulette


func _build_persona_picker() -> void:
	persona_picker.clear()
	persona_picker.add_item("Myself (my own beliefs)")
	for p in case_study.personas:
		persona_picker.add_item(p.display_name)
	persona_picker.item_selected.connect(_on_persona_selected)
	show_me_toggle.toggled.connect(_on_show_me_toggled)
	autofill_button.pressed.connect(_on_autofill_pressed)
	_on_persona_selected(0)


# ---------------------------------------------------------------- state

func _refresh() -> void:
	if case_study == null:
		return
	for i in case_study.targets.size():
		var spec := case_study.targets[i]
		tabs.set_tab_title(i, ("✓ " if roulettes[spec.name].is_complete() else "") + spec.title)
	var todo: Array[String] = []
	for spec in case_study.targets:
		var r: ChipRoulette = roulettes[spec.name]
		if not r.is_complete():
			todo.append("%s (%d chips left)" % [spec.title, r.chips_left()])
	var can_fit := client.connected and not client.is_outdated() and not fitting
	add_expert_button.disabled = fitting or not todo.is_empty()
	panel_box.set_editable(not fitting)
	if multi_mode:
		fit_button.disabled = not can_fit or panel.size() < 2
		fit_button.text = "Fitting…" if fitting else "Fit expert panel (%d)" % panel.size()
		fit_button.tooltip_text = "" if panel.size() >= 2 else "Add at least two experts to the panel first."
		if not todo.is_empty():
			hint_label.text = "Place this expert's chips, then click \"Add to expert panel\". To do: " + ", ".join(todo)
		else:
			hint_label.text = "Done: click \"Add to expert panel\" (above), then choose the next expert."
	else:
		fit_button.disabled = not can_fit or not todo.is_empty()
		fit_button.tooltip_text = ""
		fit_button.text = "Fitting…" if fitting else ("Fit prior with elicito" if fit_count == 0 else "Refit prior")
		if todo.is_empty():
			hint_label.text = "All answered. Fit the prior, or keep adjusting."
		else:
			hint_label.text = "Left-click drops a chip, right-click takes one back. To do: " + ", ".join(todo)


## The step-by-step instructions above "Play as", for the current mode.
func _update_steps() -> void:
	if multi_mode:
		steps_text.text = (
			"[b]Several experts:[/b] 1. Under [b]Play as[/b], choose an expert (yourself or a persona). "
			+ "2. Place their chips on every question, or click [i]Fill in the persona's answer[/i]. "
			+ "3. Check the name and click [b]Add to expert panel[/b]. Repeat for the next expert. "
			+ "4. With two or more experts, click [b]Fit expert panel[/b]."
		)
	else:
		steps_text.text = (
			"[b]One expert:[/b] 1. Under [b]Play as[/b], choose yourself or a persona. "
			+ "2. Place all chips on every question, or click [i]Fill in the persona's answer[/i]. "
			+ "3. Click [b]Fit prior[/b]; the result opens in [b]Fitted model[/b]. "
			+ "[color=#6b6b6b]To compare experts, tick [b]Multiple experts[/b].[/color]"
		)


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
	return persona.display_name if persona else ExpertPanel.MYSELF


# ---------------------------------------------------------------- personas

func _on_persona_selected(index: int) -> void:
	persona = null if index == 0 else case_study.personas[index - 1]
	persona_chips = case_study.persona_chips(persona) if persona else {}
	show_me_toggle.set_pressed_no_signal(false)
	show_me_toggle.visible = persona != null
	autofill_button.visible = persona != null
	briefing_card.visible = persona != null
	if persona:
		briefing_portrait.texture = persona.portrait
		briefing_text.text = "[b]You are the %s.[/b] %s" % [persona.display_name.to_lower(), persona.briefing]
		var style := StyleBoxFlat.new()
		style.bg_color = persona.color.lerp(Color.WHITE, 0.85)
		style.border_color = persona.color
		style.border_width_left = 5
		style.set_content_margin_all(10)
		briefing_card.add_theme_stylebox_override("panel", style)
	for r in roulettes.values():
		r.reset()
		r.set_ghost(PackedInt32Array())
	if not multi_mode:  # a panel's results stay while the next experts are chosen
		fit_count = 0
		fits_reset.emit()
	expert_name.clear()
	expert_name.placeholder_text = panel.default_name(persona)
	session.log_event("persona_selected", {"persona": _persona_name()})
	_refresh()


func _on_show_me_toggled(on: bool) -> void:
	for target_name in roulettes:
		var ghost: PackedInt32Array = persona_chips.get(target_name, PackedInt32Array()) if on else PackedInt32Array()
		roulettes[target_name].set_ghost(ghost)
	session.log_event("show_me", {"on": on})  # peeking is part of the record


## Places the persona's suggested chips on every question.
func _on_autofill_pressed() -> void:
	for target_name in roulettes:
		if persona_chips.has(target_name):
			roulettes[target_name].set_counts(persona_chips[target_name])
	session.log_event("autofill", {"persona": _persona_name()})
	_refresh()


# ---------------------------------------------------------------- fitting

func _on_reset_pressed() -> void:
	var r: ChipRoulette = roulettes.get(str(tabs.get_current_tab_control().name))
	if r:
		r.reset()


func _on_histogram_changed(counts: PackedInt32Array, target_name: String) -> void:
	session.log_event("chips", {"target": target_name, "counts": Array(counts)})
	_refresh()


func _on_fit_pressed() -> void:
	var settings := settings_dialog.to_request()
	var request_id := ""
	if multi_mode:
		var experts := panel.answers_by_name()
		request_id = client.request_fit_panel(case_study.id, experts, case_study.replay_n, settings)
		if request_id == "":
			return
		session.log_event("panel_fit_requested", {"request_id": request_id, "experts": experts, "settings": settings})
		fit_progress.start("Sending %d experts to elicito…" % experts.size())
	else:
		request_id = client.request_fit(case_study.id, _answers(), case_study.replay_n, settings)
		if request_id == "":
			return
		session.log_event("fit_requested", {"request_id": request_id, "persona": _persona_name(), "expert": _answers(), "histograms": _histograms(), "settings": settings})
		fit_progress.start("Sending your answers to elicito…")
	fitting = true
	_refresh()


func _on_fit_finished(result: Dictionary) -> void:
	fitting = false
	var elapsed := float(result.get("elapsed", 0.0))
	if result.get("panel", false):
		var panel_message := "Panel fitted in %.0f s." % elapsed
		if result.has("precomputed"):
			panel_message = "Precomputed panel fit loaded."
		fit_progress.finish(result.get("loss_history", []), panel_message + " Results are in the Fitted model tab.")
		session.log_event("panel_result", {
			"request_id": result.get("request_id"),
			"backend": result.get("backend"),
			"expert_priors": result.get("expert_priors"),
			"panel_priors": result.get("panel_priors"),
			"tau": result.get("tau"),
			"replay": result.get("replay"),
			"saved_eliobj": result.get("saved_eliobj"),
		})
		var experts := []
		for e in panel.experts:
			experts.append({"name": e.name, "color": e.color, "answers": e.answers})
		fit_finished.emit(result, experts)
	else:
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
		fit_progress.finish(result.get("loss_history", []), message + " Results are in the Fitted model tab.")
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
		fit_finished.emit(result, [])
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
