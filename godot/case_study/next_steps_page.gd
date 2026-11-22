class_name NextStepsPage
extends ScrollContainer
## The "Where to go next" tab: the learned priors are ordinary
## distributions, so any probabilistic programming tool can use them to fit
## the posterior. Shows the case study's model, with the priors filled in,
## as code for PyMC (Python) and brms (R), plus links to read on.
##
## The code is shown, not run. The priors come from the latest fit of the
## elicitation tab or of the expert panel (the user can pick).

const HIGHLIGHT := "#a8540f"
const CODE_FONT: Font = preload("res://theme/fonts/DejaVuSansMono-code.ttf")
const PLACEHOLDER := "placeholder"

var case_study: CaseStudy
var sources: Dictionary = {}  # key -> {"label", "priors"}
var _editors: Dictionary = {}  # language -> CodeEdit

@onready var intro: RichTextLabel = %NextIntro
@onready var source_picker: OptionButton = %SourcePicker
@onready var prior_line: RichTextLabel = %PriorLine
@onready var code_tabs: TabContainer = %CodeTabs
@onready var links: RichTextLabel = %Links


## Call once, after the page is in the tree.
func setup(case_study_: CaseStudy) -> void:
	case_study = case_study_
	intro.text = (
		"[b]From prior to posterior[/b]\n"
		+ "The learned prior describes what the experts expect before any data are seen. To learn about real participants, combine it with their data: Bayes' rule turns prior and data into the [color=%s]posterior[/color]. " % HIGHLIGHT
		+ "elicito's priors are ordinary probability distributions, so any probabilistic programming tool can use them. "
		+ "Below is this case study's model with your learned priors filled in, for [color=%s]PyMC[/color] (Python) and [color=%s]brms[/color] (R). Copy it, replace the example data with yours, and sample. The code is shown here, not run." % [HIGHLIGHT, HIGHLIGHT]
	)
	for language in case_study.posterior_languages():
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 6)
		var editor := CodeEdit.new()
		editor.editable = false
		editor.custom_minimum_size = Vector2(0, 520)
		editor.gutters_draw_line_numbers = true
		editor.add_theme_font_override("font", CODE_FONT)
		editor.add_theme_font_size_override("font_size", 13)
		editor.syntax_highlighter = _highlighter(language)
		# read-only, but as easy to read as an editor
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color("#fbf8f1")
		bg.border_color = Color("#e2dccf")
		bg.set_border_width_all(1)
		bg.set_corner_radius_all(6)
		bg.set_content_margin_all(10)
		editor.add_theme_stylebox_override("read_only", bg)
		editor.add_theme_stylebox_override("normal", bg)
		editor.add_theme_color_override("font_readonly_color", Color("#2b2b2b"))
		editor.add_theme_color_override("font_color", Color("#2b2b2b"))
		editor.add_theme_color_override("line_number_color", Color("#a9a294"))
		editor.add_theme_color_override("current_line_color", Color(0, 0, 0, 0))
		box.add_child(editor)
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_END
		var copy := Button.new()
		copy.text = "Copy code"
		copy.pressed.connect(func() -> void:
			DisplayServer.clipboard_set(editor.text)
			copy.text = "Copied ✓")
		editor.text_changed.connect(func() -> void: copy.text = "Copy code")
		row.add_child(copy)
		box.add_child(row)
		box.name = language
		code_tabs.add_child(box)
		code_tabs.set_tab_title(code_tabs.get_tab_count() - 1, case_study.posterior_languages()[language])
		_editors[language] = editor
	links.text = _links_text()
	links.meta_clicked.connect(func(meta: Variant) -> void: OS.shell_open(str(meta)))
	source_picker.item_selected.connect(func(_i: int) -> void: _show())
	set_source(PLACEHOLDER, "No fit yet: the book's priors as placeholders", case_study.placeholder_priors())


## Offers priors under `key` (e.g. "single", "panel") and shows them.
func set_source(key: String, label: String, priors: Dictionary) -> void:
	if key != PLACEHOLDER:
		sources.erase(PLACEHOLDER)
	sources[key] = {"label": label, "priors": priors}
	_rebuild_picker(key)


func remove_sources_with_prefix(prefix: String) -> void:
	for key in sources.keys():
		if key.begins_with(prefix):
			sources.erase(key)
	if sources.is_empty():
		set_source(PLACEHOLDER, "No fit yet: the book's priors as placeholders", case_study.placeholder_priors())


func select_source(key: String) -> void:
	var i := sources.keys().find(key)
	if i >= 0:
		source_picker.select(i)
		_show()


func remove_source(key: String) -> void:
	sources.erase(key)
	if sources.is_empty():
		set_source(PLACEHOLDER, "No fit yet: the book's priors as placeholders", case_study.placeholder_priors())
	else:
		_rebuild_picker(sources.keys()[-1])


func current_key() -> String:
	var keys := sources.keys()
	return keys[source_picker.selected] if source_picker.selected >= 0 and source_picker.selected < keys.size() else ""


func code(language: String) -> String:
	return _editors[language].text if _editors.has(language) else ""


func _rebuild_picker(select_key: String) -> void:
	source_picker.clear()
	var keys := sources.keys()
	for key in keys:
		source_picker.add_item(sources[key].label)
	source_picker.select(keys.find(select_key))
	source_picker.disabled = keys.size() < 2
	_show()


func _show() -> void:
	var key := current_key()
	if key == "":
		return
	var src: Dictionary = sources[key]
	var parts: Array[String] = []
	for param in src.priors:
		var b: Array = src.priors[param]
		parts.append("%s ~ Uniform(%s, %s)" % [case_study.parameter_symbol(param), _num(minf(b[0], b[1])), _num(maxf(b[0], b[1]))])
	var note := " (placeholders: fit a prior first)" if key == PLACEHOLDER else ""
	prior_line.text = "[color=%s]%s[/color]%s" % [HIGHLIGHT, ",  ".join(parts), note]
	for language in _editors:
		_editors[language].text = case_study.posterior_code(language, src.priors, src.label)


func _links_text() -> String:
	var lines: Array[String] = ["[b]Read on[/b]"]
	if case_study.docs_url != "":
		lines.append("• [url=%s]The elicito case study[/url]: the same model, its elicitation, and the posterior fitted with PyMC (section “From prior to posterior”)." % case_study.docs_url)
	lines.append("• [url=https://www.pymc.io/projects/docs/en/stable/learn.html]Learning PyMC[/url]: sampling, diagnostics and posterior checks in Python.")
	lines.append("• [url=https://paulbuerkner.com/brms/]brms[/url]: Bayesian regression models in R, including non-linear models like this one.")
	return "\n".join(lines)


func _highlighter(language: String) -> CodeHighlighter:
	var h := CodeHighlighter.new()
	h.number_color = Color("#a8540f")
	h.symbol_color = Color("#3a3a3a")
	h.function_color = Color("#1f5f8b")
	h.member_variable_color = Color("#3a3a3a")
	h.add_color_region("#", "", Color("#6b8e6b"), true)
	h.add_color_region("\"", "\"", Color("#2e7d32"))
	var keywords := ["import", "as", "with", "for", "in", "if", "not", "print", "True", "False"] if language == "pymc" else ["library", "function", "if", "TRUE", "FALSE", "c"]
	for w in keywords:
		h.add_keyword_color(w, Color("#7b3fa1"))
	return h


static func _num(x: float) -> String:
	var text := "%.3f" % x
	text = text.rstrip("0")
	return text + "0" if text.ends_with(".") else text
