extends GutTest
## The shipped precomputed fits still belong to the app's personas. If this
## fails, a persona or the chip logic changed: export the scenarios again
## and rerun server/tools/precompute.py (see its docstring).

var catalog: CaseStudyCatalog = load("res://case_studies/catalog.tres")


func test_every_persona_answer_has_its_exact_fit() -> void:
	for case_study in catalog.case_studies:
		if case_study.precomputed_fits == "":
			continue
		assert_true(ResourceLoader.exists(case_study.precomputed_fits), case_study.precomputed_fits)
		var fits: Dictionary = (load(case_study.precomputed_fits) as JSON).data
		var stored := {}
		for entry in fits.single:
			stored[entry.name] = entry.answers
		for p in case_study.personas + case_study.precompute_personas:
			assert_has(stored, p.display_name, "%s: %s was fitted" % [case_study.id, p.display_name])
			var answers := case_study.persona_answers(p)
			for target_name in answers:
				var a: Array = answers[target_name]
				var b: Array = stored[p.display_name][target_name]
				for i in a.size():
					assert_almost_eq(float(b[i]), float(a[i]), 1e-6, "%s %s %s" % [case_study.id, p.display_name, target_name])


func test_every_pair_of_personas_has_a_panel_fit() -> void:
	for case_study in catalog.case_studies:
		if case_study.precomputed_fits == "":
			continue
		var fits: Dictionary = (load(case_study.precomputed_fits) as JSON).data
		var n := case_study.personas.size()
		assert_eq(fits.panels.size(), (1 << n) - 1 - n, "all panels of two or more personas")
