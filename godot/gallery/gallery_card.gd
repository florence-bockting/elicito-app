class_name GalleryCard
extends PanelContainer
## One case study in the gallery: picture, title, summary, and buttons to
## open it or read it in the elicito documentation.

signal opened(case_study: CaseStudy)

var case_study: CaseStudy

@onready var _thumbnail: TextureRect = %Thumbnail
@onready var _title: Label = %CardTitle
@onready var _summary: Label = %Summary
@onready var _open_button: Button = %OpenButton
@onready var _docs_button: LinkButton = %DocsButton


func _ready() -> void:
	_open_button.pressed.connect(func() -> void: opened.emit(case_study))
	_docs_button.pressed.connect(func() -> void: OS.shell_open(case_study.docs_url))
	if case_study:
		_show()


func setup(case_study_: CaseStudy) -> void:
	case_study = case_study_
	if is_node_ready():
		_show()


func _show() -> void:
	_thumbnail.texture = case_study.thumbnail
	_thumbnail.visible = case_study.thumbnail != null
	_title.text = case_study.title
	_summary.text = case_study.summary
	_docs_button.visible = case_study.docs_url != ""
