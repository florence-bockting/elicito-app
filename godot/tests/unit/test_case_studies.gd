extends GutTest
## Every case study in the catalog keeps the contract the app relies on.

var catalog: CaseStudyCatalog = load("res://case_studies/catalog.tres")


func test_catalog_is_not_empty_and_ids_are_unique() -> void:
	assert_gt(catalog.case_studies.size(), 0)
	var ids := catalog.case_studies.map(func(c: CaseStudy) -> String: return c.id)
	for id in ids:
		assert_eq(ids.count(id), 1, "id %s is unique" % id)
	assert_eq(catalog.find("bart").id, "bart")
	assert_null(catalog.find("nope"))


func test_gallery_fields() -> void:
	for c in catalog.case_studies:
		assert_ne(c.title, "", c.id)
		assert_ne(c.summary, "", c.id)
		assert_not_null(c.thumbnail, c.id)


func test_targets_and_personas_fit_together() -> void:
	for c in catalog.case_studies:
		assert_gt(c.targets.size(), 0, c.id)
		for p in c.personas:
			var answers := p.simulate(200)
			for spec in c.targets:
				assert_true(answers.has(spec.name), "%s: persona %s answers %s" % [c.id, p.display_name, spec.name])
			assert_gt(p.traits().size(), 0)


func test_predictions_scene_extends_predictions_view() -> void:
	for c in catalog.case_studies:
		assert_not_null(c.predictions_scene, c.id)
		var view: Node = autofree(c.predictions_scene.instantiate())
		assert_is(view, PredictionsView, c.id)


func test_personas_tab_shows_the_case_study_intro() -> void:
	var bart := catalog.find("bart")
	var page: PersonasPage = add_child_autofree(load("res://case_study/personas_page.tscn").instantiate())
	page.setup(bart)
	assert_eq(page.get_node("%PersonasIntro").text, bart.personas_intro)
	assert_string_contains(bart.personas_intro, "three training personas")


func test_parameter_labels_name_symbols() -> void:
	var bart := catalog.find("bart")
	assert_eq(bart.parameter_symbol("gammap"), "γ⁺")
	assert_eq(bart.parameter_symbol("unknown"), "unknown")
