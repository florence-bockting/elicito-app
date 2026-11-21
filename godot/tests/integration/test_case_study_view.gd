extends GutTest
## The BART case study end to end, with a fake elicito server: answering,
## fitting one expert, fitting a panel, and what each tab then shows.

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
	assert_eq(view.get_tab_count(), 4)
	assert_eq(view.get_tab_title(2), "Expert knowledge elicitation")
	assert_eq(view.fit_view.get_tab_title(2), "Predictions")
	assert_eq(page.roulettes.size(), 2, "one chip roulette per question")


func test_fit_needs_every_answer_and_a_current_server() -> void:
	assert_true(page.fit_button.disabled, "nothing answered yet")
	_answer_every_question(3, 5)
	assert_true(page.all_answered())
	assert_false(page.fit_button.disabled)
	client.server_version = 1
	client.connection_changed.emit(true, "mock")
	assert_true(page.fit_button.disabled, "an old server would ignore new features")


func test_one_expert_from_answers_to_balloons() -> void:
	_answer_every_question(3, 5)
	page.fit_button.pressed.emit()
	assert_eq(client.sent.size(), 1)
	assert_eq(client.sent[0].type, "fit")
	assert_eq(client.sent[0].expert.keys(), ["pumps", "omega"])
	assert_has(client.sent[0], "settings")
	assert_true(page.fit_button.disabled, "one fit at a time")

	client.answer(TestFixtures.single_result())
	await wait_process_frames(2)
	assert_eq(view.get_current_tab_control(), view.fit_view, "the fitted model opens")
	assert_eq(view.fit_view.get_current_tab_control(), view.fit_view.diagnostics_page)
	assert_eq(view.fit_view.convergence_plot.series.size(), 1)
	assert_string_contains(view.fit_view.match_caption.text, "close match")
	assert_string_contains(view.fit_view.prior_text.text, "Uniform(0.30, 0.80)")
	assert_eq(page.roulettes["pumps"].model_quantiles.size(), 5, "the fit is drawn over the chips")
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
	client.fit_failed.emit("boom")
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


func test_panel_of_two_experts() -> void:
	page.multi_check.button_pressed = true
	assert_true(page.panel_box.visible and page.add_expert_button.visible)
	assert_string_contains(page.steps_text.text, "Add to expert panel")
	assert_eq(page.persona_picker.item_count, bart.personas.size() + 1, "no panel entry in Play as")

	page.play_as(bart.personas[0])
	page.autofill_button.pressed.emit()
	page.add_expert_button.pressed.emit()
	assert_eq(page.panel.experts[0].name, "Mila")
	assert_false(page.all_answered(), "the board is cleared for the next expert")
	assert_true(page.fit_button.disabled, "a panel needs two experts")

	page.play_as(null)
	_answer_every_question(2, 6)
	page.expert_name.text = "Ana"
	page.add_expert_button.pressed.emit()
	assert_eq(page.panel.experts[1].name, "Ana")
	assert_eq(page.fit_button.text, "Fit expert panel (2)")

	page.fit_button.pressed.emit()
	assert_eq(client.sent[-1].type, "fit_panel")
	assert_eq(client.sent[-1].experts.keys(), ["Mila", "Ana"])
	client.answer(TestFixtures.panel_result(["Mila", "Ana"]))
	await wait_process_frames(2)
	assert_eq(view.fit_view.convergence_plot.series.size(), 2)
	assert_eq(view.fit_view.match_plot.series.size(), 2)
	assert_string_contains(view.fit_view.prior_text.text, "Panel of 2 experts")

	view.fit_view.current_tab = 2
	await wait_process_frames(3)
	var rows: PanelReplay = view.fit_view.predictions.panel_replay
	assert_eq(rows.get_child_count(), 2, "one row per expert")
	var first_row := rows.get_child(0)
	assert_eq(first_row.get_child(1).get_child_count(), 12, "12 balloons per expert")
	assert_true(first_row.get_child(2) is WalletView and first_row.get_child(2).compact)

	page.multi_check.button_pressed = false
	assert_false(page.panel_box.visible)
