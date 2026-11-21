class_name PredictionsView
extends Control
## Base class of a case study's "Predictions" tab: it shows what a fitted
## prior implies, as simulated outcomes. Each case study provides a scene
## whose root extends this class (CaseStudy.predictions_scene).
##
## FitView calls setup() once, then show_single() or show_panel() after
## each fit, and play() when the tab becomes visible.

var case_study: CaseStudy


func setup(case_study_: CaseStudy) -> void:
	case_study = case_study_


## One expert: `draws` are the server's simulated outcomes ("replay").
func show_single(_draws: Array) -> void:
	pass


## A panel: [{"name", "color", "draws"}], one entry per expert.
func show_panel(_experts: Array) -> void:
	pass


## Starts (or restarts) the animation, if there is one.
func play() -> void:
	pass
