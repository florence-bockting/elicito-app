extends GutTest
## RouletteFeedback: the plain-language summary, hints and practice verdict.


func _spec() -> TargetSpec:
	var s := TargetSpec.new()
	s.axis_min = -0.5
	s.axis_max = 10.5
	s.discrete = true
	s.chips = 20
	return s


func _counts(pairs: Dictionary) -> PackedInt32Array:
	var c := PackedInt32Array()
	c.resize(11)
	for k in pairs:
		c[k] = pairs[k]
	return c


func test_no_summary_or_hint_while_chips_are_left() -> void:
	var s := _spec()
	var c := _counts({5: 3})
	assert_eq(RouletteFeedback.summary(s, c), "")
	assert_eq(RouletteFeedback.hint(s, c), "")


func test_summary_names_the_most_likely_value_and_the_range() -> void:
	var text := RouletteFeedback.summary(_spec(), _counts({3: 2, 4: 5, 5: 6, 6: 5, 7: 2}))
	assert_string_contains(text, "5[/color]")
	assert_string_contains(text, "between 4 and 6")
	assert_string_contains(text, "fairly certain")


func test_certainty_grows_with_the_spread() -> void:
	var s := _spec()
	assert_eq(RouletteFeedback.certainty(s, _counts({5: 20})), "very certain")
	var flat := PackedInt32Array([2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1])
	assert_eq(RouletteFeedback.certainty(s, flat), "very uncertain")


func test_hints_for_one_column_gaps_flat_and_edges() -> void:
	var s := _spec()
	assert_string_contains(RouletteFeedback.hint(s, _counts({5: 20})), "one column")
	assert_string_contains(RouletteFeedback.hint(s, _counts({2: 10, 8: 10})), "empty column")
	assert_string_contains(RouletteFeedback.hint(s, PackedInt32Array([2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1])), "evenly")
	assert_string_contains(RouletteFeedback.hint(s, _counts({9: 6, 10: 14})), "top end of the axis")
	assert_eq(RouletteFeedback.hint(s, _counts({0: 6, 1: 8, 2: 6})), "", "the low end is often a natural limit")
	assert_eq(RouletteFeedback.hint(s, _counts({3: 2, 4: 5, 5: 6, 6: 5, 7: 2})), "", "a plain bell needs no hint")


func test_practice_verdict_flags_overconfidence_and_lean() -> void:
	var s := _spec()
	var truth := PackedFloat64Array()
	for k in 11:
		var c := 1.0
		for i in k:
			c = c * (10 - i) / (i + 1)
		truth.append(c / 1024.0)
	var sure := RouletteFeedback.practice_verdict(s, _counts({4: 6, 5: 8, 6: 6}), truth)
	assert_string_contains(sure, "more certain than the coin")
	var leaning := RouletteFeedback.practice_verdict(s, _counts({2: 4, 3: 6, 4: 6, 5: 4}), truth)
	assert_string_contains(leaning, "lean to the left")
	var good := RouletteFeedback.practice_verdict(s, _counts({2: 1, 3: 2, 4: 4, 5: 6, 6: 4, 7: 2, 8: 1}), truth)
	assert_string_contains(good, "Excellent")


func test_example_spreads_use_exactly_all_chips_without_holes() -> void:
	var flat := []
	flat.resize(11)
	flat.fill(1.0)
	var c := RouletteFeedback.spread(flat, 0, 11, 20)
	var total := 0
	for x in c:
		total += x
		assert_gt(x, 0, "no empty column in an even spread")
	assert_eq(total, 20)
