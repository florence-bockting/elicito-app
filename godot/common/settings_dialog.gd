class_name SettingsDialog
extends AcceptDialog
## Pop-up for elicito's training settings. The values are saved in
## user://training_settings.cfg and sent with every fit; the server checks
## them (see SETTINGS in server/src/elicito_app_server/settings.py). Hover a name for help.

signal settings_changed(settings: Dictionary)

const PATH := "user://training_settings.cfg"
const SECTION := "training"
## name, label, min, max, step, default, help. A default of 0 on an
## "optional" setting means elicito's own default (or "estimate" for tau).
const FIELDS := [
	["epochs", "Simulation budget (epochs)", 50, 5000, 50, 400,
		"CMA-ES runs this many forward simulations. More is slower but searches longer."],
	["seed", "Seed", 0, 1000000, 1, 1,
		"Starting point of the random numbers. The same seed and answers give the same fit."],
	["replications", "Runs (one per seed)", 1, 8, 1, 1,
		"Fits again from the next seeds and keeps the best run. With more than one run the\nlive loss curve only appears at the end, because the runs happen in parallel."],
	["B", "Batch size B", 8, 1024, 8, 128,
		"Simulated data sets per step. Larger is smoother but slower."],
	["num_samples", "Prior samples", 20, 5000, 10, 200,
		"Draws from the prior in each simulated data set."],
	["kappa", "Spread penalty κ", 0.0, 100.0, 0.01, 0.0,
		"Keeps a prior from collapsing to a single value. 0 turns it off."],
]
const OPTIONAL_FIELDS := [
	["sigma0", "CMA-ES step size σ₀", 0.0, 10.0, 0.01, 0.0,
		"First step size of the search. 0 uses elicito's default."],
	["popsize", "CMA-ES population", 0, 256, 1, 0,
		"Candidates per search generation. 0 uses elicito's default."],
	["tau", "Panel disagreement τ", 0.0, 100.0, 0.01, 0.0,
		"Expert panels only: how far experts may move from the panel prior.\n0 lets elicito estimate it from the answers."],
]

var values: Dictionary = {}
var _spins: Dictionary = {}  # name -> SpinBox


func _init() -> void:
	title = "Training settings"
	ok_button_text = "Apply"
	add_cancel_button("Cancel")
	add_button("Reset to defaults", true, "reset")
	custom_action.connect(func(action: StringName) -> void:
		if action == &"reset":
			_set_spins(_defaults()))
	confirmed.connect(_apply)
	_build()
	values = _defaults()
	_load()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var intro := Label.new()
	intro.text = "How elicito trains the prior. Changes apply to the next fit. Hover a setting for help."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(500, 0)
	box.add_child(intro)
	box.add_child(_grid(FIELDS))
	var advanced := Label.new()
	advanced.text = "Search and panel (0 = default)"
	advanced.add_theme_font_size_override("font_size", 14)
	advanced.add_theme_color_override("font_color", Color("#6b6b6b"))
	box.add_child(advanced)
	box.add_child(_grid(OPTIONAL_FIELDS))


func _grid(fields: Array) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	for f in fields:
		var label := Label.new()
		label.text = f[1]
		label.tooltip_text = f[6]
		label.mouse_filter = Control.MOUSE_FILTER_PASS  # so the tooltip shows
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
		var spin := SpinBox.new()
		spin.min_value = f[2]
		spin.max_value = f[3]
		spin.step = f[4]
		spin.custom_minimum_size = Vector2(150, 0)
		spin.tooltip_text = f[6]
		grid.add_child(spin)
		_spins[f[0]] = spin
	return grid


func _defaults() -> Dictionary:
	var d := {}
	for f in FIELDS + OPTIONAL_FIELDS:
		d[f[0]] = f[5]
	return d


## Shows the dialog with the current values.
func open() -> void:
	_set_spins(values)
	popup_centered()


func _set_spins(from: Dictionary) -> void:
	for key in _spins:
		_spins[key].value = from.get(key, 0)


func _apply() -> void:
	for key in _spins:
		values[key] = _spins[key].value
	_save()
	settings_changed.emit(to_request())


## The settings for a fit request: whole numbers where elicito expects
## them, and optional settings left out when 0 (= elicito's default).
func to_request() -> Dictionary:
	var out := {}
	for f in FIELDS:
		out[f[0]] = int(values[f[0]]) if f[4] is int else float(values[f[0]])
	for f in OPTIONAL_FIELDS:
		var v: float = values[f[0]]
		if v > 0.0:
			out[f[0]] = maxi(int(v), 2) if f[0] == "popsize" else v
	return out


## Short text for the button that opens the dialog.
func summary() -> String:
	var runs := int(values.replications)
	return "%d epochs · seed %d · %d run%s" % [int(values.epochs), int(values.seed), runs, "" if runs == 1 else "s"]


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in values:
		values[key] = cfg.get_value(SECTION, key, values[key])


func _save() -> void:
	var cfg := ConfigFile.new()
	for key in values:
		cfg.set_value(SECTION, key, values[key])
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("SettingsDialog: cannot save %s (%s)" % [PATH, error_string(err)])
