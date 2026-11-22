class_name FitSummary
extends RefCounted
## Texts about a fit: the fitted priors, and how well they reproduce the
## expert's answers. Static helpers, so they are easy to test.

const C_GOOD := "#2e6b3a"
const C_ROUGH := "#b9770e"
const C_POOR := "#c0392b"
const MOCK_NOTE := "[color=#c0392b]Mock backend: these numbers are not an elicito fit.[/color]"


## Mean absolute difference of two quantile vectors, relative to the axis.
static func match_error(expert_q: Array, model_q: Array, axis_range: float) -> float:
	var n := mini(expert_q.size(), model_q.size())
	if n == 0 or axis_range <= 0.0:
		return INF
	var total := 0.0
	for i in n:
		total += absf(float(expert_q[i]) - float(model_q[i]))
	return total / n / axis_range


## "close match", "rough match" or "poor match", as BBCode.
static func verdict(error: float) -> String:
	if error > 0.08:
		return "[color=%s]poor match[/color] (the model can't produce this answer)" % C_POOR
	if error > 0.03:
		return "[color=%s]rough match[/color]" % C_ROUGH
	return "[color=%s]close match[/color]" % C_GOOD


## One line per expert: how closely the prior reproduces each answer.
static func match_line(case_study: CaseStudy, answers: Dictionary, simulated: Dictionary) -> String:
	var parts: Array[String] = []
	for spec in case_study.targets:
		if answers.has(spec.name) and simulated.has(spec.name):
			var err := match_error(answers[spec.name], simulated[spec.name], spec.axis_max - spec.axis_min)
			parts.append("%s: %s" % [spec.title, verdict(err)])
	return " · ".join(parts)


## BBCode: where a precomputed fit comes from, or "" for a live fit.
static func precomputed_note(result: Dictionary) -> String:
	if not result.has("precomputed"):
		return ""
	var info: Dictionary = result.precomputed
	var how := "[color=%s]Precomputed with elicito[/color]" % C_ROUGH
	if info.get("exact", false):
		return how + " for exactly these answers (no elicito server running)."
	if info.has("scenario"):
		return how + ": the fit of the [color=#a8540f]%s[/color]'s answers, the closest stored answers to yours. Start the elicito server to fit your own answers." % str(info.scenario).to_lower()
	var pairs: Array[String] = []
	var members: Dictionary = info.get("members", {})
	for requested in members:
		if requested != members[requested]:
			pairs.append("%s → %s" % [requested, str(members[requested]).to_lower()])
	return how + ": the panel fit of the closest stored experts (%s). Start the elicito server to fit your own answers." % ", ".join(pairs)


## BBCode: the fitted prior of one expert.
static func describe_single(case_study: CaseStudy, result: Dictionary) -> String:
	var lines: Array[String] = ["[b]Fitted prior[/b]"]
	var priors: Dictionary = result.get("priors", {})
	for p in priors:
		var bounds: Array = priors[p]
		lines.append("  %s ~ Uniform(%.2f, %.2f)" % [case_study.parameter_labels.get(p, p), bounds[0], bounds[1]])
	if result.get("backend") == "mock":
		lines.append("\n" + MOCK_NOTE)
	if result.has("precomputed"):
		lines.append("\n" + precomputed_note(result))
	return "\n".join(lines)


## BBCode: each expert's prior, then the panel's. `experts`: [{"name", "color"}].
static func describe_panel(case_study: CaseStudy, result: Dictionary, experts: Array) -> String:
	var priors: Dictionary = result.get("expert_priors", {})
	var independent: bool = result.get("pooling", "partial") == "independent"
	var lines: Array[String] = ["[b]Panel of %d experts[/b] · %s" % [experts.size(), "independent fits" if independent else "partial pooling"]]
	for e in experts:
		if not priors.has(e.name):
			continue
		var parts: Array[String] = []
		for p in priors[e.name]:
			var b: Array = priors[e.name][p]
			parts.append("%s %.2f–%.2f" % [case_study.parameter_symbol(p), b[0], b[1]])
		lines.append("  [color=#%s]%s[/color]  %s" % [e.color.to_html(false), e.name, ", ".join(parts)])
	lines.append("")
	lines.append("[b]The panel as a whole[/b] (90%% of its prior%s)" % (", an equal mix of the experts' priors" if independent else ""))
	var population: Dictionary = result.get("population", {})
	for p in population:
		lines.append("  %s: %.2f to %.2f" % [case_study.parameter_labels.get(p, p), population[p].q05, population[p].q95])
	if result.get("backend") == "mock":
		lines.append("\n" + MOCK_NOTE)
	if result.has("precomputed"):
		lines.append("\n" + precomputed_note(result))
	return "\n".join(lines)
