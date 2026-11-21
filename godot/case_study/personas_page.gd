class_name PersonasPage
extends ScrollContainer
## The "Training personas" tab: one card per persona, then how their
## traits show up in the answers.

signal play_requested(persona: ExpertPersona)

const PersonaCardScene := preload("res://case_study/persona_card.tscn")

@onready var _cards: HBoxContainer = %PersonaCards
@onready var _text: RichTextLabel = %PersonasText


func setup(case_study: CaseStudy) -> void:
	_text.text = case_study.personas_text
	for p in case_study.personas:
		var card: PersonaCard = PersonaCardScene.instantiate()
		card.setup(p)
		card.play_requested.connect(play_requested.emit)
		_cards.add_child(card)
