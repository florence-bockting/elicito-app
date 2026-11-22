extends GutTest
## The practice round: each step unlocks Next only after the action it
## teaches, and the coin question is checked against the true chances.

var tutorial: RouletteTutorial


func before_each() -> void:
	tutorial = load("res://elicitation/roulette_tutorial.tscn").instantiate()
	add_child_autofree(tutorial)


func test_next_waits_for_each_action() -> void:
	assert_eq(tutorial.step, RouletteTutorial.Step.DROP)
	assert_true(tutorial.next_button.disabled)
	tutorial.practice.add_chip(5)
	assert_false(tutorial.next_button.disabled, "dropping a chip completes step 1")
	assert_string_contains(tutorial.feedback.text, "5%")

	tutorial.next_button.pressed.emit()
	assert_true(tutorial.next_button.disabled)
	tutorial.practice.add_chip(5)
	assert_true(tutorial.next_button.disabled, "adding is not taking back")
	tutorial.practice.remove_chip(5)
	assert_false(tutorial.next_button.disabled)

	tutorial.next_button.pressed.emit()
	for i in 5:
		tutorial.practice.add_chip(3)
	assert_false(tutorial.next_button.disabled, "a stack of 5 completes step 3")


func test_coin_answer_is_checked_against_the_truth() -> void:
	tutorial.go_to(RouletteTutorial.Step.COIN)
	assert_eq(tutorial.practice.placed(), 0, "the coin question starts empty")
	assert_true(tutorial.check_button.visible)
	assert_true(tutorial.check_button.disabled)
	for k in [4, 5, 6]:
		for i in 6:
			tutorial.practice.add_chip(k)
	tutorial.practice.add_chip(5)
	tutorial.practice.add_chip(5)
	assert_false(tutorial.check_button.disabled)
	tutorial.check_button.pressed.emit()
	assert_false(tutorial.next_button.disabled)
	assert_string_contains(tutorial.feedback.text, "more certain than the coin")
	var ghost := tutorial.practice.ghost_counts
	var total := 0
	for c in ghost:
		total += c
	assert_eq(total, 20, "the true chances shown as 20 chips")
	assert_eq(ghost[3], ghost[7], "and symmetric")

	tutorial.practice.remove_chip(5)
	assert_true(tutorial.next_button.disabled, "a changed answer needs a new check")
	assert_eq(tutorial.practice.ghost_counts.size(), 0)


func test_skip_and_finish_report_how_it_ended() -> void:
	watch_signals(tutorial)
	tutorial.skip_button.pressed.emit()
	assert_signal_emitted_with_parameters(tutorial, "finished", [true])
	tutorial.go_to(RouletteTutorial.Step.CERTAINTY)
	assert_false(tutorial.next_button.disabled)
	assert_true(tutorial.examples.visible)
	tutorial.next_button.pressed.emit()
	assert_signal_emitted_with_parameters(tutorial, "finished", [false])
