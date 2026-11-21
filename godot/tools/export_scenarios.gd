extends SceneTree
## Writes res://case_studies/<id>/precomputed/scenarios.json for every case
## study in the catalog: the answers that server/tools/precompute.py fits
## with elicito, so the app can show real fits without a server (web).
##
##   godot --headless --path godot -s res://tools/export_scenarios.gd
##
## The answers are exactly what "Fill in the persona's answer" places, so a
## user who plays a persona gets the fit of that very answer. Panels: every
## combination of two or more of the visible personas.

const CATALOG := "res://case_studies/catalog.tres"


func _initialize() -> void:
	var catalog: CaseStudyCatalog = load(CATALOG)
	for case_study in catalog.case_studies:
		var path := scenarios_path(case_study)
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		var file := FileAccess.open(path, FileAccess.WRITE)
		file.store_string(JSON.stringify(scenarios(case_study), "  ") + "\n")
		print("wrote ", path)
	quit(0)


static func scenarios_path(case_study: CaseStudy) -> String:
	return "res://case_studies/%s/precomputed/scenarios.json" % case_study.id


static func scenarios(case_study: CaseStudy) -> Dictionary:
	var single := []
	for p in case_study.personas + case_study.precompute_personas:
		single.append({"name": p.display_name, "answers": case_study.persona_answers(p)})
	var names := case_study.personas.map(func(p: ExpertPersona) -> String: return p.display_name)
	var panels := []
	for members in _combinations(names):
		if members.size() >= 2:
			panels.append({"members": members})
	return {"case_study": case_study.id, "replay_n": case_study.replay_n, "single": single, "panels": panels}


## All non-empty subsets, in order.
static func _combinations(items: Array) -> Array:
	var out := []
	for mask in range(1, 1 << items.size()):
		var subset := []
		for i in items.size():
			if mask & (1 << i):
				subset.append(items[i])
		out.append(subset)
	return out
