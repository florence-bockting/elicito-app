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
## Shown at the top of the elicitation tab; see intro_text().
@export_multiline var intro: String = ""
## BBCode for the "Statistical model" tab: the task, likelihood,
## parameters and prior specification.
@export_multiline var model_text: String = ""
## BBCode for the "Training personas" tab, below the persona cards.
@export_multiline var personas_text: String = ""
## Display names for the server's parameter keys, e.g. {"gammap": "γ⁺ risk propensity"}.
@export var parameter_labels: Dictionary = {}

@export_group("Elicitation")
@export var targets: Array[TargetSpec] = []
## Roles the user can play (empty = only "Myself").
@export var personas: Array[ExpertPersona] = []

@export_group("Predictions")
## The "Predictions" tab of a fitted model. Its root must extend
## PredictionsView; it shows simulated outcomes of the fitted prior.
@export var predictions_scene: PackedScene
## Simulated outcomes the server sends with a fit.
@export var replay_n: int = 24


## The intro for the elicitation tab. Subclasses fill in placeholders.
func intro_text() -> String:
	return intro


func target(target_name: String) -> TargetSpec:
	for t in targets:
		if t.name == target_name:
			return t
	return null


## "γ⁺" from "γ⁺ risk propensity": the label's first word.
func parameter_symbol(param: String) -> String:
	return str(parameter_labels.get(param, param)).split(" ")[0]
