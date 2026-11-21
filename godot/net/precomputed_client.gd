class_name PrecomputedClient
extends ElicitoClient
## Answers fit requests from fits made in advance with elicito, for when no
## server can run (the web version, or a computer without Python).
##
## Each case study's fits.json (CaseStudy.precomputed_fits, written by
## server/tools/precompute.py) holds the real elicito fits of every persona
## and of every panel of personas. A request gets the fit of the closest
## stored answer; the result says which one in its "precomputed" entry, so
## the app can be honest about it. Progress is replayed from the stored
## loss, so the app behaves as with a server, only faster.

## Seconds the replayed training takes (a panel adds a short warm-up).
const PLAY_SECONDS := 1.4
const WARMUP_SECONDS := 0.6
const WARMUP_STEPS := 8
## Fits closer than this (mean relative quantile difference) count as exact.
const EXACT := 1e-4

var _fits: Dictionary = {}  # case id -> parsed fits.json
var _case_studies: Dictionary = {}  # case id -> CaseStudy
var _playing: Dictionary = {}  # the request being replayed
var _clock := 0.0


func _init() -> void:
	auto_connect = false
	reconnect = false
	backend = "precomputed"
	server_version = REQUIRED_SERVER_VERSION
	supports_settings = false


func _ready() -> void:
	connected = true
	connection_changed.emit.call_deferred(true, backend)


## Loads a case study's precomputed fits; false if it has none.
func add_case_study(case_study: CaseStudy) -> bool:
	if case_study.precomputed_fits == "" or not ResourceLoader.exists(case_study.precomputed_fits):
		return false
	var json: JSON = load(case_study.precomputed_fits)
	add_fits(case_study, json.data)
	return true


func add_fits(case_study: CaseStudy, fits: Dictionary) -> void:
	_case_studies[case_study.id] = case_study
	_fits[case_study.id] = fits


func has_fits(case_id: String) -> bool:
	return _fits.has(case_id)


func connect_to_server() -> void:
	pass  # nothing to connect to


func request_fit(case_id: String, expert: Dictionary, _replay_n := 24, _settings := {}) -> String:
	if not _can_start(case_id):
		return ""
	var best := _closest(case_id, expert, _fits[case_id].single)
	var result: Dictionary = best.entry.result.duplicate(true)
	result["precomputed"] = {
		"scenario": best.entry.name,
		"distance": best.distance,
		"exact": best.distance < EXACT,
		"elicito_version": _fits[case_id].get("elicito_version", ""),
	}
	return _play(result, false)


func request_fit_panel(case_id: String, experts: Dictionary, _replay_n := 24, _settings := {}) -> String:
	if not _can_start(case_id):
		return ""
	var fits: Dictionary = _fits[case_id]
	# match each expert to a different stored expert who appears in the panels
	var candidates: Array = fits.single.filter(func(s: Dictionary) -> bool:
		return fits.panels.any(func(p: Dictionary) -> bool: return s.name in p.members))
	var mapping := {}  # requested name -> stored name
	var distance := 0.0
	for requested in experts:
		var free: Array = candidates.filter(func(s: Dictionary) -> bool: return not s.name in mapping.values())
		if free.is_empty():
			fit_failed.emit("Without an elicito server, a panel can have at most %d experts." % candidates.size())
			return ""
		var best := _closest(case_id, experts[requested], free)
		mapping[requested] = best.entry.name
		distance = maxf(distance, best.distance)
	var members: Array = mapping.values()
	var panel: Dictionary = {}
	for p in fits.panels:
		if p.members.size() == members.size() and members.all(func(m: String) -> bool: return m in p.members):
			panel = p
	if panel.is_empty():
		fit_failed.emit("No precomputed fit for this panel. Run the elicito server for live fits.")
		return ""
	var result := _renamed(panel.result, mapping, experts)
	result["precomputed"] = {
		"members": mapping,
		"distance": distance,
		"exact": distance < EXACT,
		"elicito_version": fits.get("elicito_version", ""),
	}
	return _play(result, true)


func _process(delta: float) -> void:
	if _playing.is_empty():
		return
	_clock += delta
	var losses: Array = _playing.result.get("loss_history", [])
	var phases := 2 if _playing.panel else 1
	var warmup := WARMUP_SECONDS if _playing.panel else 0.0
	if _clock < warmup:
		var w := clampi(int(_clock / warmup * WARMUP_STEPS) + 1, 1, WARMUP_STEPS)
		_emit_once("w%d" % w, "Warm-up", w, WARMUP_STEPS, null, 1, phases)
		return
	var n := maxi(losses.size(), 1)
	var done := clampi(int((_clock - warmup) / PLAY_SECONDS * n) + 1, 1, n)
	for i in range(_playing.done, done):
		progress.emit("Training", i + 1, n, losses[i] if i < losses.size() else null, phases, phases)
	_playing.done = done
	if _clock >= warmup + PLAY_SECONDS:
		var result: Dictionary = _playing.result
		result["elapsed"] = _clock
		_playing = {}
		_pending_id = ""
		fit_finished.emit(result)


func _can_start(case_id: String) -> bool:
	if not has_fits(case_id):
		fit_failed.emit("No precomputed fits for this case study. Run the elicito server for live fits.")
		return false
	if is_busy():
		fit_failed.emit("A fit is already running")
		return false
	return true


func _play(result: Dictionary, panel: bool) -> String:
	_pending_id = "precomputed-%d" % Time.get_ticks_msec()
	result["request_id"] = _pending_id
	result["backend"] = backend
	_playing = {"result": result, "panel": panel, "done": 0, "emitted": {}}
	_clock = 0.0
	return _pending_id


func _emit_once(key: String, stage: String, done: int, total: int, loss: Variant, phase: int, phases: int) -> void:
	if not _playing.emitted.has(key):
		_playing.emitted[key] = true
		progress.emit(stage, done, total, loss, phase, phases)


## The stored answer closest to `answers`: {"entry", "distance"}.
func _closest(case_id: String, answers: Dictionary, entries: Array) -> Dictionary:
	var case_study: CaseStudy = _case_studies[case_id]
	var best := {"entry": entries[0], "distance": INF}
	for entry in entries:
		var total := 0.0
		for spec in case_study.targets:
			total += FitSummary.match_error(answers.get(spec.name, []), entry.answers.get(spec.name, []), spec.axis_max - spec.axis_min)
		var d := total / maxi(case_study.targets.size(), 1)
		if d < best.distance:
			best = {"entry": entry, "distance": d}
	return best


## A stored panel result with the user's expert names, in the user's order.
## "answers" stays what was fitted: the stored experts' answers.
static func _renamed(stored: Dictionary, mapping: Dictionary, experts: Dictionary) -> Dictionary:
	var result: Dictionary = stored.duplicate(true)
	result["experts"] = experts.keys()
	for key in ["answers", "expert_priors", "expert_replays", "expert_bound_history", "expert_simulated"]:
		if not stored.has(key):
			continue
		var renamed := {}
		for requested in mapping:
			if stored[key].has(mapping[requested]):
				renamed[requested] = stored[key][mapping[requested]]
		result[key] = renamed
	return result
