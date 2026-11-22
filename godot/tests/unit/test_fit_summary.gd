extends GutTest

var case_study: CaseStudy = load("res://case_studies/bart/bart.tres")


func test_match_error_is_relative_to_the_axis() -> void:
	assert_almost_eq(FitSummary.match_error([1, 2, 3], [1, 2, 3], 10.0), 0.0, 1e-9)
	assert_almost_eq(FitSummary.match_error([0, 0], [1, 3], 10.0), 0.2, 1e-9)
	assert_eq(FitSummary.match_error([], [], 10.0), INF)


func test_verdicts() -> void:
	assert_string_contains(FitSummary.verdict(0.01), "close match")
	assert_string_contains(FitSummary.verdict(0.05), "rough match")
	assert_string_contains(FitSummary.verdict(0.2), "poor match")


func test_match_line_names_every_question() -> void:
	var answers := {"pumps": [2, 3, 4, 5, 6], "omega": [3, 4, 5, 6, 7]}
	var line := FitSummary.match_line(case_study, answers, answers)
	for spec in case_study.targets:
		assert_string_contains(line, spec.title + ": ")


func test_describe_single() -> void:
	var text := FitSummary.describe_single(case_study, {"priors": {"gammap": [0.3, 0.8]}, "backend": "mock"})
	assert_string_contains(text, "γ⁺ risk propensity ~ Uniform(0.30, 0.80)")
	assert_string_contains(text, "Mock backend")


func test_describe_panel() -> void:
	var result := {
		"expert_priors": {"Ana": {"gammap": [0.1, 0.4]}},
		"population": {"gammap": {"q05": 0.12, "q95": 0.9}},
	}
	var text := FitSummary.describe_panel(case_study, result, [{"name": "Ana", "color": Color.RED}])
	assert_string_contains(text, "Panel of 1 experts")
	assert_string_contains(text, "γ⁺ 0.10–0.40")
	assert_string_contains(text, "0.12 to 0.90")
