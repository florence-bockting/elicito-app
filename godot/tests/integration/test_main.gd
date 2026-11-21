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
