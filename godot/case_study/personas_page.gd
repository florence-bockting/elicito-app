class_name PersonasPage
extends ScrollContainer
## The "Training personas" tab: one card per persona, then how their
## traits show up in the answers, and a button on to the next tab.

signal play_requested(persona: ExpertPersona)
signal next_requested

const PersonaCardScene := preload("res://case_study/persona_card.tscn")

@onready var _intro: Label = %PersonasIntro
@onready var _cards: HBoxContainer = %PersonaCards
@onready var _text: RichTextLabel = %PersonasText
@onready var next_button: Button = %NextButton


func _ready() -> void:
	next_button.pressed.connect(next_requested.emit)


func setup(case_study: CaseStudy) -> void:
	if case_study.personas_intro != "":
		_intro.text = case_study.personas_intro
	_text.text = case_study.personas_text
	for p in case_study.personas:
		var card: PersonaCard = PersonaCardScene.instantiate()
		card.setup(p)
		card.play_requested.connect(play_requested.emit)
		_cards.add_child(card)
