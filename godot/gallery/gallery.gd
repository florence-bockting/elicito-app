class_name Gallery
extends ScrollContainer
## The start screen: one card per case study in the catalog.

signal case_study_chosen(case_study: CaseStudy)

const CardScene := preload("res://gallery/gallery_card.tscn")

@onready var _cards: HFlowContainer = %Cards


func setup(catalog: CaseStudyCatalog) -> void:
	for child in _cards.get_children():
		child.queue_free()
	for case_study in catalog.case_studies:
		var card: GalleryCard = CardScene.instantiate()
		card.setup(case_study)
		card.opened.connect(case_study_chosen.emit)
		_cards.add_child(card)
