extends GutTest
## Main: start options, the gallery, and opening a case study.

const MainScript := preload("res://app/main.gd")


func test_parse_options() -> void:
	assert_eq(MainScript.parse_options(["case=bart", "embed=1"]), {"case": "bart", "embed": true})
	assert_eq(MainScript.parse_options(["server=ws%3A%2F%2Fexample.org%2Fws"]), {"server": "ws://example.org/ws"})
	assert_eq(MainScript.parse_options(["embed"]), {"embed": true})
	assert_eq(MainScript.parse_options([]), {})


func test_gallery_opens_a_case_study() -> void:
	var main: Control = add_child_autofree(load("res://app/main.tscn").instantiate())
	main.client.reconnect = false
	await wait_process_frames(1)
	assert_is(main.current, Gallery)
	var cards: Array = main.current.get_node("%Cards").get_children()
	assert_eq(cards.size(), main.catalog.case_studies.size())
	var chosen: CaseStudy = cards[0].case_study
	cards[0].opened.emit(chosen)
	await wait_process_frames(1)
	assert_is(main.current, CaseStudyView)
	assert_string_contains(main.title_label.text, chosen.title)
	main.current.session.path = ""  # nothing saved in this test


func test_precomputed_on_the_web_unless_a_server_is_named() -> void:
	assert_true(MainScript.wants_precomputed({}, true))
	assert_false(MainScript.wants_precomputed({"server": "ws://x/ws"}, true))
	assert_false(MainScript.wants_precomputed({}, false))
	assert_true(MainScript.wants_precomputed({"backend": "precomputed"}, false))


func test_switching_to_precomputed_fits_reopens_the_case_study() -> void:
	var main: Control = add_child_autofree(load("res://app/main.tscn").instantiate())
	main.client.reconnect = false
	await wait_process_frames(1)
	assert_true(main.offline_button.visible, "offered while no server answers")
	main.open_case_study(main.catalog.case_studies[0])
	main.current.session.path = ""
	main.offline_button.pressed.emit()
	await wait_process_frames(2)
	assert_is(main.client, PrecomputedClient)
	assert_is(main.current, CaseStudyView)
	assert_eq(main.current.elicitation_page.client, main.client)
	assert_false(main.offline_button.visible)
	assert_string_contains(main.status_label.text, "precomputed")
	main.current.session.path = ""
