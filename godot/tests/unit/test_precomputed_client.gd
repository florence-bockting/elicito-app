extends GutTest
## PrecomputedClient with a small hand-made fits file: picking the closest
## stored answer, renaming panel experts, replaying progress.

var bart: CaseStudy = load("res://case_studies/bart/bart.tres")
var client: PrecomputedClient

const LOW := {"pumps": [0.5, 1.0, 1.5, 2.0, 2.5], "omega": [1.0, 1.5, 2.0, 2.5, 3.0]}
const HIGH := {"pumps": [4.0, 5.0, 6.0, 7.0, 8.0], "omega": [7.0, 8.0, 9.0, 10.0, 11.0]}


func before_each() -> void:
	client = add_child_autofree(PrecomputedClient.new())
	var low_result := TestFixtures.single_result()
	low_result["priors"] = {"gammap": [0.1, 0.3], "beta": [0.2, 0.6]}
	var high_result := TestFixtures.single_result()
	high_result["priors"] = {"gammap": [1.0, 2.0], "beta": [2.0, 4.0]}
	var panel := TestFixtures.panel_result(["Low expert", "High expert"])
	panel["answers"] = {"Low expert": LOW, "High expert": HIGH}
	var independent := TestFixtures.panel_result(["Low expert", "High expert"])
	independent["pooling"] = "independent"
	independent["panel_priors"] = {}
	client.add_fits(bart, {
		"elicito_version": "0.9.0",
		"single": [
			{"name": "Low expert", "answers": LOW, "result": low_result},
			{"name": "High expert", "answers": HIGH, "result": high_result},
		],
		"panels": [{"members": ["Low expert", "High expert"], "result": panel}],
		"independent_panels": [{"members": ["Low expert", "High expert"], "result": independent}],
	})


func test_it_is_always_connected_and_ignores_settings() -> void:
	assert_true(client.connected)
	assert_false(client.supports_settings)
	assert_eq(client.backend, "precomputed")


func test_exact_answer_gets_its_own_fit() -> void:
	watch_signals(client)
	assert_ne(client.request_fit("bart", LOW), "")
	await wait_for_signal(client.fit_finished, 5.0)
	var result: Dictionary = get_signal_parameters(client, "fit_finished")[0]
	assert_eq(result.priors.gammap, [0.1, 0.3])
	assert_true(result.precomputed.exact)
	assert_signal_emitted(client, "progress")
	assert_false(client.is_busy())


func test_other_answers_get_the_closest_fit() -> void:
	var near_high := {"pumps": [4.0, 5.0, 6.0, 7.0, 9.0], "omega": [6.0, 8.0, 9.0, 10.0, 12.0]}
	watch_signals(client)
	client.request_fit("bart", near_high)
	await wait_for_signal(client.fit_finished, 5.0)
	var result: Dictionary = get_signal_parameters(client, "fit_finished")[0]
	assert_eq(result.precomputed.scenario, "High expert")
	assert_false(result.precomputed.exact)
	assert_string_contains(FitSummary.precomputed_note(result), "high expert")


func test_panel_experts_keep_their_names() -> void:
	watch_signals(client)
	client.request_fit_panel("bart", {"Ana": HIGH, "Ben": LOW})
	await wait_for_signal(client.fit_finished, 5.0)
	var result: Dictionary = get_signal_parameters(client, "fit_finished")[0]
	assert_eq(result.experts, ["Ana", "Ben"])
	assert_eq(result.expert_priors.keys(), ["Ana", "Ben"])
	assert_eq(result.precomputed.members, {"Ana": "High expert", "Ben": "Low expert"})
	assert_has(result.expert_replays, "Ana")
	assert_eq(result.answers.Ana, HIGH, "the answers that were fitted")
	# the warm-up came first, then the training with its loss
	var first: Array = get_signal_parameters(client, "progress", 0)
	assert_eq(first[0], "Warm-up")


func test_independent_panel_uses_its_own_stored_fit() -> void:
	watch_signals(client)
	client.request_fit_panel("bart", {"Ana": HIGH, "Ben": LOW}, 24, {}, "independent")
	await wait_for_signal(client.fit_finished, 5.0)
	var result: Dictionary = get_signal_parameters(client, "fit_finished")[0]
	assert_eq(result.pooling, "independent")
	assert_eq(result.expert_priors.keys(), ["Ana", "Ben"])
	var first: Array = get_signal_parameters(client, "progress", 0)
	assert_ne(first[0], "Warm-up", "no warm-up without pooling")


func test_too_many_experts_fail_politely() -> void:
	watch_signals(client)
	assert_eq(client.request_fit_panel("bart", {"A": LOW, "B": HIGH, "C": LOW}), "")
	assert_signal_emitted(client, "fit_failed")


func test_unknown_case_study_fails() -> void:
	watch_signals(client)
	assert_eq(client.request_fit("nope", LOW), "")
	assert_signal_emitted(client, "fit_failed")
