extends GutTest
## The BART case study end to end, with a fake elicito server: answering,
## fitting one expert, fitting the expert panel, the code for the posterior,
## and what each tab then shows.

var bart: BartCaseStudy = load("res://case_studies/bart/bart.tres")
var client: FakeClient
var view: CaseStudyView
var page: ElicitationPage


func before_each() -> void:
	client = add_child_autofree(FakeClient.new())
	var settings: SettingsDialog = add_child_autofree(SettingsDialog.new())
	view = add_child_autofree(load("res://case_study/case_study_view.tscn").instantiate())
	view.setup(bart, client, settings)
	page = view.elicitation_page


func after_each() -> void:
	if view and view.session.path != "":
		DirAccess.remove_absolute(view.session.path)


func _answer_every_question(a: int, b: int) -> void:
	for r: ChipRoulette in page.roulettes.values():
		var counts := PackedInt32Array()
		counts.resize(r.counts.size())
		counts[a] = r.spec.chips / 2
		counts[b] = r.spec.chips - counts[a]
		r.set_counts(counts)


func test_tabs() -> void:
	assert_eq(view.get_tab_count(), 6)
	assert_eq(view.get_tab_title(2), "Expert knowledge elicitation")
	assert_eq(view.get_tab_title(4), "Expert panel")
	assert_eq(view.get_tab_title(5), "Where to go next")
	assert_eq(view.fit_view.get_tab_title(2), "Predictions")
	assert_eq(page.roulettes.size(), 2, "one chip roulette per question")


func test_next_button_below_the_model() -> void:
	assert_eq(view.current_tab, 0, "starts on the statistical model")
	assert_eq(view.next_button.text, "Next: Training personas →")
	view.next_button.pressed.emit()
	assert_eq(view.get_current_tab_control(), view.personas_page)


func test_next_button_below_the_personas() -> void:
	view.show_page(view.personas_page)
	assert_eq(view.personas_page.next_button.text, "Next: Elicit knowledge →")
	view.personas_page.next_button.pressed.emit()
	assert_eq(view.get_current_tab_control(), view.elicitation_page)


func test_fit_needs_every_answer_and_a_current_server() -> void:
	assert_true(page.fit_button.disabled, "nothing answered yet")
	_answer_every_question(3, 5)
	assert_true(page.all_answered())
	assert_false(page.fit_button.disabled)
	client.server_version = 1
	client.connection_changed.emit(true, "mock")
	assert_true(page.fit_button.disabled, "an old server would ignore new features")


func test_one_expert_from_answers_to_balloons() -> void:
	assert_true(page.next_button.disabled, "nothing to inspect before a fit")
	_answer_every_question(3, 5)
	page.fit_button.pressed.emit()
	assert_eq(client.sent.size(), 1)
	assert_eq(client.sent[0].type, "fit")
	assert_eq(client.sent[0].expert.keys(), ["omega", "pumps"])
	assert_has(client.sent[0], "settings")
	assert_true(page.fit_button.disabled, "one fit at a time")

	client.answer(TestFixtures.single_result())
	await wait_process_frames(2)
	assert_ne(view.get_current_tab_control(), view.fit_view, "the user moves on with Next")
	assert_false(page.next_button.disabled)
	page.next_button.pressed.emit()
	assert_eq(view.get_current_tab_control(), view.fit_view, "the fitted model opens")
	assert_eq(view.fit_view.get_current_tab_control(), view.fit_view.diagnostics_page)
	assert_eq(view.fit_view.convergence_plot.series.size(), 1)
	assert_string_contains(view.fit_view.match_caption.text, "close match")
	assert_string_contains(view.fit_view.prior_text.text, "Uniform(0.30, 0.80)")
	assert_false(page.roulettes["pumps"].show_prior, "the prior is shown in the next tab, not over the chips")
	assert_eq(view.session.count("fit_result"), 1)
	assert_eq(page.fit_button.text, "Refit prior")

	var predictions: BartPredictions = view.fit_view.predictions
	assert_eq(predictions.replay_grid.get_child_count(), 0, "balloons wait for their tab")
	view.fit_view.current_tab = 2
	await wait_process_frames(2)
	assert_eq(predictions.replay_grid.get_child_count(), 24)
	assert_true(predictions.earnings_row.visible, "the wallet shows the money")


func test_progress_shows_loss_only_for_the_training() -> void:
	_answer_every_question(3, 5)
	page.fit_button.pressed.emit()
	var progress := page.fit_progress
	client.progress.emit("Warm-up", 5, 10, null, 1, 2)
	assert_false(progress.loss_plot.visible)
	assert_almost_eq(progress.progress_bar.value, 25.0, 1e-6)
	assert_string_contains(progress.status_label.text, "Step 1 of 2")
	client.progress.emit("Training", 2, 10, 0.8, 2, 2)
	assert_true(progress.loss_plot.visible)
	assert_almost_eq(progress.progress_bar.value, 60.0, 1e-6)


func test_failed_fit_frees_the_button() -> void:
	_answer_every_question(3, 5)
	page.fit_button.pressed.emit()
	client.fail("boom")
	assert_false(page.fit_button.disabled)
	assert_string_contains(page.fit_progress.status_label.text, "boom")


func test_play_as_from_a_persona_card() -> void:
	var risky: ExpertPersona = bart.personas[2]
	view.personas_page.play_requested.emit(risky)
	assert_eq(view.get_current_tab_control(), page)
	assert_eq(page.persona, risky)
	assert_true(page.briefing_card.visible)
	page.autofill_button.pressed.emit()
	assert_true(page.all_answered(), "the persona's answer fills every question")


func test_switching_role_starts_a_new_fit_history() -> void:
	_answer_every_question(3, 5)
	page.fit_button.pressed.emit()
	client.answer(TestFixtures.single_result())
	assert_eq(view.fit_view.prior_plot.fits.size(), 1)
	page.play_as(bart.personas[0])
	assert_eq(view.fit_view.prior_plot.fits.size(), 0)


func test_expert_panel_of_the_personas() -> void:
	var pp := view.panel_page
	assert_eq(pp.chosen().size(), bart.personas.size(), "all personas start ticked")
	assert_false(pp.fit_button.disabled)
	assert_false(pp.results.visible, "no results before the fit")
	pp.set_chosen([bart.personas[0]])
	assert_true(pp.fit_button.disabled, "a panel needs two experts")
	pp.set_chosen([bart.personas[0], bart.personas[2]])

	pp.fit_button.pressed.emit()
	assert_eq(client.sent[-1].type, "fit_panel")
	assert_eq(client.sent[-1].experts.keys(), ["Mila", "Jonas"])
	assert_eq(client.sent[-1].experts["Mila"], bart.persona_answers(bart.personas[0]), "the personas' example answers")
	assert_true(page.fit_button.disabled, "one fit at a time")
	client.answer(TestFixtures.panel_result(["Mila", "Jonas"]))
	await wait_process_frames(2)
	assert_true(pp.results.visible, "the results show in the panel tab")
	assert_eq(pp.results.convergence_plot.series.size(), 2)
	assert_string_contains(pp.results.prior_text.text, "Panel of 2 experts")
	assert_eq(view.fit_view.prior_plot.fits.size(), 0, "the Fitted model tab is for one expert")

	view.show_page(pp)
	pp.results.current_tab = 2
	await wait_process_frames(3)
	var rows: PanelReplay = pp.results.predictions.panel_replay
	assert_eq(rows.get_child_count(), 2, "one row per expert")
	var first_row := rows.get_child(0)
	assert_eq(first_row.get_child(1).get_child_count(), 12, "12 balloons per expert")
	assert_true(first_row.get_child(2) is WalletView and first_row.get_child(2).compact)

	pp.next_button.pressed.emit()
	assert_eq(view.get_current_tab_control(), view.next_steps)
	assert_string_contains(view.next_steps.source_picker.get_item_text(view.next_steps.source_picker.selected), "Expert panel (Mila, Jonas)")
	assert_string_contains(view.next_steps.code("pymc"), "pm.Uniform(\"gammap\", lower=0.3, upper=0.8)")


func test_independent_panel() -> void:
	var pp := view.panel_page
	pp.independent_check.button_pressed = true
	assert_eq(pp.pooling, "independent")
	assert_string_contains(pp.pooling_text.text, "One fit per expert")
	pp.fit_button.pressed.emit()
	assert_eq(client.sent[-1].pooling, "independent")
	var result := TestFixtures.panel_result(["Mila", "Sam", "Jonas"])
	result["pooling"] = "independent"
	result["panel_priors"] = {}
	result["expert_priors"]["Sam"] = {"gammap": [0.5, 0.9], "beta": [0.6, 1.2]}
	client.answer(result)
	await wait_process_frames(2)
	assert_string_contains(pp.results.prior_text.text, "independent fits")
	var ns := view.next_steps
	assert_eq(ns.source_picker.item_count, 3, "one prior per expert, no shared one")
	assert_string_contains(ns.source_picker.get_item_text(ns.source_picker.selected), "Mila (expert panel, independent fit)")
	ns.select_source("panel:Sam")
	assert_string_contains(ns.code("pymc"), "lower=0.5, upper=0.9")


func test_posterior_code_uses_the_latest_fit() -> void:
	var ns := view.next_steps
	assert_string_contains(ns.code("pymc"), "lower=0.0, upper=10.0", "the book's priors before any fit")
	assert_string_contains(ns.prior_line.text, "placeholders")
	_answer_every_question(3, 5)
	page.fit_button.pressed.emit()
	var result := TestFixtures.single_result()
	client.answer(result)
	var g: Array = result.priors.gammap
	assert_string_contains(ns.code("pymc"), "pm.Uniform(\"gammap\", lower=%s" % BartCaseStudy._num(minf(g[0], g[1])))
	assert_string_contains(ns.code("brms"), "nlpar = \"gammap\"")
	assert_string_contains(ns.code("brms"), "log(1 - 0.15)")
	assert_true(ns.source_picker.get_item_text(ns.source_picker.selected).begins_with("Your fit"))
	page.play_as(bart.personas[1])
	assert_string_contains(ns.prior_line.text, "placeholders", "a new role drops the old fit")