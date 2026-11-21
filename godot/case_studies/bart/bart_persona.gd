class_name BartPersona
extends ExpertPersona
## A BART persona: the range of risk propensity γ⁺ and consistency β of
## the participants this expert knows. The user never sees these numbers;
## they only produce the persona's suggested answers.

const BURST := 0.15  # chance that one pump pops the balloon
const MAX_PUMPS := 20  # the model never returns more pumps than this

@export_group("Prior of the participants")
@export var gammap_low: float = 0.0
@export var gammap_high: float = 0.0
@export var beta_low: float = 0.0
@export var beta_high: float = 0.0
@export_group("")


func traits() -> Array[Dictionary]:
	return [
		{"name": "Risk attitude", "level": risk_level()},
		{"name": "Consistency", "level": consistency_level()},
	]


## How risky the plan is, 0..1: the middle of the persona's plan ω, where
## 10 pumps or more counts as fully risky.
func risk_level() -> float:
	var omega := -0.5 * (gammap_low + gammap_high) / log(1.0 - BURST)
	return clampf(omega / 10.0, 0.05, 1.0)


## How strictly the plan is followed, 0..1: the middle of β, where
## β = 3 or more counts as fully consistent.
func consistency_level() -> float:
	return clampf(0.5 * (beta_low + beta_high) / 3.0, 0.05, 1.0)


## Simulate `n` participants drawn from this persona's prior, one trial each.
## Returns {"pumps": [...], "omega": [...]}, keyed like the elicito targets.
func simulate(n: int, seed: int = 1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed  # same seed -> same "answer" every time
	var pumps := PackedFloat64Array()
	var omegas := PackedFloat64Array()
	for i in n:
		var gammap := rng.randf_range(gammap_low, gammap_high)
		var beta := rng.randf_range(beta_low, beta_high)
		var omega := -gammap / log(1.0 - BURST)
		omegas.append(omega)
		pumps.append(_one_trial(omega, beta, rng))
	return {"pumps": pumps, "omega": omegas}


## At decision k the participant stops with probability sigmoid(beta * (k - omega));
## otherwise they pump, and the balloon may pop.
static func _one_trial(omega: float, beta: float, rng: RandomNumberGenerator) -> int:
	var count := 0
	for k in range(1, MAX_PUMPS + 2):
		var p_stop := 1.0 / (1.0 + exp(-beta * (k - omega)))
		if rng.randf() < p_stop:
			return count  # stops and banks
		count += 1
		if rng.randf() < BURST:
			return count  # pop!
		if count >= MAX_PUMPS:
			return count
	return count
