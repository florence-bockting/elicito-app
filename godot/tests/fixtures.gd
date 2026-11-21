class_name TestFixtures
extends RefCounted
## Server results for the integration tests, shaped like the real ones.


static func draws(n: int) -> Array:
	var out := []
	for i in n:
		out.append({"pumps": i % 7, "burst": i % 3 == 0, "omega": 3.5, "gammap": 0.5, "beta": 1.0})
	return out


static func single_result() -> Dictionary:
	return {
		"type": "result",
		"backend": "mock",
		"priors": {"gammap": [0.3, 0.8], "beta": [0.5, 1.5]},
		"loss_history": [1.0, 0.5, 0.2],
		"expert": {"pumps": [3.1, 3.6, 4.0, 4.4, 4.9], "omega": [3.2, 3.7, 4.5, 5.3, 5.8]},
		"simulated_quantiles": {"pumps": [3.0, 3.6, 4.0, 4.5, 5.0], "omega": [3.2, 3.8, 4.5, 5.2, 5.8]},
		"probs": {"pumps": [0.1, 0.25, 0.5, 0.75, 0.9], "omega": [0.1, 0.25, 0.5, 0.75, 0.9]},
		"bound_history": {
			"gammap": {"lower": [0.1, 0.25, 0.3], "upper": [1.2, 0.9, 0.8]},
			"beta": {"lower": [0.2, 0.4, 0.5], "upper": [2.0, 1.6, 1.5]},
		},
		"replay": draws(24),
		"elapsed": 1.0,
	}


static func panel_result(names: Array) -> Dictionary:
	var priors := {}
	var replays := {}
	var history := {}
	var simulated := {}
	for name in names:
		priors[name] = {"gammap": [0.3, 0.8], "beta": [0.5, 1.5]}
		replays[name] = draws(12)
		history[name] = {"gammap": {"lower": [0.1, 0.2], "upper": [0.9, 0.8]}}
		simulated[name] = {"pumps": [1, 2, 3, 4, 5], "omega": [2, 3, 4, 5, 6]}
	return {
		"type": "result",
		"panel": true,
		"backend": "mock",
		"expert_priors": priors,
		"panel_priors": {"gammap": [0.3, 0.8], "beta": [0.5, 1.5]},
		"population": {},
		"tau": {},
		"loss_history": [1.0, 0.4],
		"probs": {"pumps": [0.1, 0.25, 0.5, 0.75, 0.9], "omega": [0.1, 0.25, 0.5, 0.75, 0.9]},
		"replay": draws(24),
		"expert_replays": replays,
		"expert_bound_history": history,
		"expert_simulated": simulated,
		"elapsed": 2.0,
	}
