class_name CaseStudy
extends Resource
## One case study of the app: the texts, the questions for the expert, the
## training personas and the scene that shows what a fitted prior implies.
##
## A new case study is a folder in res://case_studies/ with a .tres file of
## this type (or a subclass), listed in res://case_studies/catalog.tres, and
## a matching case study on the server with the same `id`.

## Must match the case study's id on the server.
@export var id: String = ""
@export var title: String = ""
## One sentence for the gallery card.
@export_multiline var summary: String = ""
## Picture for the gallery card.
@export var thumbnail: Texture2D
## The page of this case study in the elicito documentation.
@export var docs_url: String = ""

@export_group("Texts")
## BBCode shown at the top of the elicitation tab: the scenario and the
## task. See intro_text().
@export_multiline var intro: String = ""
## BBCode for the "Statistical model" tab: the task, likelihood,
## parameters and prior specification.
@export_multiline var model_text: String = ""
## Plain text for the "Training personas" tab, above the persona cards
## (empty = a general sentence).
@export_multiline var personas_intro: String = ""
## BBCode for the "Training personas" tab, below the persona cards.
@export_multiline var personas_text: String = ""
## Display names for the server's parameter keys, e.g. {"gammap": "γ⁺ risk propensity"}.
@export var parameter_labels: Dictionary = {}

@export_group("Elicitation")
@export var targets: Array[TargetSpec] = []
## Roles the user can play (empty = only "Myself").
@export var personas: Array[ExpertPersona] = []

## Extra experts, never shown, whose answers are also fitted in advance
## for the web version (see tools/export_scenarios.gd).
@export var precompute_personas: Array[ExpertPersona] = []

@export_group("Predictions")
## The "Predictions" tab of a fitted model. Its root must extend
## PredictionsView; it shows simulated outcomes of the fitted prior.
@export var predictions_scene: PackedScene
## Simulated outcomes the server sends with a fit.
@export var replay_n: int = 24
## Fits made in advance with elicito, for when no server is running (the
## web version). Written by server/tools/precompute.py; see PrecomputedClient.
@export_file("*.json") var precomputed_fits: String = ""


## The intro for the elicitation tab. Subclasses fill in placeholders.
func intro_text() -> String:
	return intro


func target(target_name: String) -> TargetSpec:
	for t in targets:
		if t.name == target_name:
			return t
	return null


## A persona's suggested chips per target, as "Fill in example
## expectations" places them.
func persona_chips(p: ExpertPersona) -> Dictionary:
	var chips := {}
	var samples := p.simulate(4000)
	for spec in targets:
		if samples.has(spec.name):
			chips[spec.name] = QuantileMath.chips_from_samples(samples[spec.name], spec)
	return chips


## The quantiles those chips give, keyed by target: what the app sends to
## elicito when the user fills in this persona's answer.
func persona_answers(p: ExpertPersona) -> Dictionary:
	var out := {}
	var chips := persona_chips(p)
	for spec in targets:
		if chips.has(spec.name):
			out[spec.name] = Array(QuantileMath.quantiles_from_histogram(chips[spec.name], spec.bin_edges(), spec.probs))
	return out


## Code that fits this model's posterior with the learned `priors`
## ({parameter: [lower, upper]}) in `language`, one of posterior_languages().
## `source` says where the priors come from. Empty: no "Where to go next".
func posterior_code(_language: String, _priors: Dictionary, _source: String) -> String:
	return ""


## The languages posterior_code() supports, as {id: tab title}.
func posterior_languages() -> Dictionary:
	return {}


## Priors to show before anything is fitted, as {parameter: [lower, upper]}.
func placeholder_priors() -> Dictionary:
	return {}


## "γ⁺" from "γ⁺ risk propensity": the label's first word.
func parameter_symbol(param: String) -> String:
	return str(parameter_labels.get(param, param)).split(" ")[0]
