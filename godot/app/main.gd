extends Control
## The app: a header, and either the gallery of case studies or one case
## study. Main owns what every case study shares (the connection to the
## elicito server and the training settings) and hands it down.
##
## Start options (desktop: `godot -- --case=bart`; web: `index.html?case=bart`):
##   case=<id>   open this case study directly
##   embed=1     no way back to the gallery (for the elicito documentation)
##   server=<ws url>  elicito server (default ws://127.0.0.1:8765/ws)

const C_OK := Color("#2e6b3a")
const C_BAD := Color("#c0392b")
const GalleryScene := preload("res://gallery/gallery.tscn")
const CaseStudyScene := preload("res://case_study/case_study_view.tscn")

@export var catalog: CaseStudyCatalog

var options: Dictionary = {}
var current: Control

@onready var back_button: Button = %BackButton
@onready var title_label: Label = %Title
@onready var status_label: Label = %Status
@onready var content: Control = %Content
@onready var client: ElicitoClient = %Client
@onready var settings_dialog: SettingsDialog = %SettingsDialog


func _ready() -> void:
	assert(catalog != null, "Main needs a CaseStudyCatalog")
	options = start_options()
	if options.has("server"):
		client.url = options.server
	client.connection_changed.connect(_on_connection_changed)
	back_button.pressed.connect(open_gallery)
	_on_connection_changed(false, "")
	client.connect_to_server()

	var requested := catalog.find(options.get("case", ""))
	if requested:
		open_case_study(requested)
	else:
		open_gallery()


func open_gallery() -> void:
	var gallery: Gallery = GalleryScene.instantiate()
	_show(gallery)
	gallery.setup(catalog)
	gallery.case_study_chosen.connect(open_case_study)
	title_label.text = "elicito app · case studies"
	back_button.visible = false


func open_case_study(case_study: CaseStudy) -> void:
	var view: CaseStudyView = CaseStudyScene.instantiate()
	_show(view)
	view.setup(case_study, client, settings_dialog)
	title_label.text = "elicito app · %s" % case_study.title
	back_button.visible = not options.get("embed", false) and catalog.case_studies.size() > 1


## Options from the command line (after `--`) or, on the web, the page URL.
static func start_options() -> Dictionary:
	var pairs: Array = []
	for arg in OS.get_cmdline_user_args():
		pairs.append(arg.trim_prefix("--"))
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search.substring(1)")
		if query is String and query != "":
			pairs.append_array(query.split("&"))
	return parse_options(pairs)


## ["case=bart", "embed=1"] -> {"case": "bart", "embed": true}
static func parse_options(pairs: Array) -> Dictionary:
	var out := {}
	for pair in pairs:
		var kv: PackedStringArray = str(pair).split("=", true, 1)
		var key := kv[0].uri_decode()
		var value := kv[1].uri_decode() if kv.size() > 1 else "1"
		out[key] = value in ["1", "true", "yes"] if key == "embed" else value
	return out


func _show(view: Control) -> void:
	if current:
		current.queue_free()
	current = view
	content.add_child(view)


func _on_connection_changed(connected: bool, backend: String) -> void:
	if connected and client.is_outdated():
		status_label.text = "● old server running: restart it"
		status_label.tooltip_text = "Stop the elicito server (Ctrl+C) and start it again: elicito-app-server"
		status_label.add_theme_color_override("font_color", C_BAD)
	elif connected:
		var mock := backend == "mock"
		status_label.text = "● %s server%s" % [backend, " (fake fits!)" if mock else ""]
		status_label.tooltip_text = client.url
		status_label.add_theme_color_override("font_color", C_BAD if mock else C_OK)
	else:
		status_label.text = "○ no elicito server"
		status_label.tooltip_text = "Start it with: elicito-app-server (pip install ./server)"
		status_label.add_theme_color_override("font_color", C_BAD)
