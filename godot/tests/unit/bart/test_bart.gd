extends GutTest
## The BART case study: payoff texts, personas, balloons.

var bart: BartCaseStudy = load("res://case_studies/bart/bart.tres")


func test_intro_shows_the_payoff() -> void:
	var intro := bart.intro_text()
	assert_string_contains(intro, "€0.05")
	assert_string_contains(intro, "15%")
	assert_false(intro.contains("{reward}"))


func test_risk_taker_pumps_more_than_the_cautious_expert() -> void:
	var cautious: BartPersona = bart.personas[0]
	var risky: BartPersona = bart.personas[2]
	var a := cautious.simulate(3000)
	var b := risky.simulate(3000)
	assert_eq(a.pumps.size(), 3000)
	var mean_a := 0.0
	var mean_b := 0.0
	for v in a.pumps:
		mean_a += v / 3000.0
	for v in b.pumps:
		mean_b += v / 3000.0
	assert_gt(mean_b, mean_a + 1.5)
	assert_gt(risky.risk_level(), cautious.risk_level())


func test_same_seed_same_answer() -> void:
	var p: BartPersona = bart.personas[1]
	assert_eq(p.simulate(10, 7).pumps, p.simulate(10, 7).pumps)


func test_balloon_summary_counts_pops() -> void:
	var balloon: Node = autofree(load("res://case_studies/bart/balloon.tscn").instantiate())
	var text: String = balloon.summarize([{"pumps": 2, "burst": true}, {"pumps": 5, "burst": false}, {"pumps": 4, "burst": false}])
	assert_true(text.begins_with("1 of 3"), text)
