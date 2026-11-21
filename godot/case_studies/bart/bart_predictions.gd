class_name BartPredictions
extends PredictionsView
## BART's "Predictions" tab: each balloon is one simulated trial of a
## participant drawn from the fitted prior, and the wallet shows the money
## those trials made. A panel gets one row of balloons per expert.

const SINGLE_CAPTION := "Each balloon is one simulated trial of a participant drawn from your fitted prior. Colour = planned pumps ω (blue cautious, amber moderate, red risky); the faint ring marks the planned size."
const PANEL_CAPTION := "Each row: %d simulated trials of participants drawn from that expert's fitted prior, and the money they made."

## One balloon; its root needs play(draw, delay) and summarize(draws).
@export var balloon_scene: PackedScene

var _draws: Array = []
var _panel_rows: Array = []
var _is_panel := false

@onready var replay_title: Label = %ReplayTitle
@onready var replay_caption: Label = %ReplayCaption
@onready var replay_button: Button = %ReplayButton
@onready var replay_grid: ReplayGrid = %Replay
@onready var panel_replay: PanelReplay = %PanelReplay
@onready var earnings_row: Control = %EarningsRow
@onready var wallet_view: WalletView = %WalletView


func _ready() -> void:
	replay_button.pressed.connect(play)
	replay_grid.replay_started.connect(func(_d: Array) -> void: wallet_view.reset(_bart().reward_per_pump, _bart().currency))
	replay_grid.item_finished.connect(func(_i: int, draw: Dictionary) -> void: wallet_view.add_trial(draw))
	replay_grid.replay_finished.connect(_on_replay_finished)


func show_single(draws: Array) -> void:
	_is_panel = false
	_draws = _with_payoff(draws)
	replay_title.text = "What your prior implies"
	replay_caption.text = SINGLE_CAPTION
	replay_grid.visible = true
	panel_replay.visible = false
	earnings_row.visible = _bart().reward_per_pump > 0.0
	replay_button.disabled = false


func show_panel(experts: Array) -> void:
	_is_panel = true
	_panel_rows = []
	for e in experts:
		_panel_rows.append({"name": e.name, "color": e.color, "draws": _with_payoff(e.draws)})
	replay_title.text = "What each expert's prior implies"
	var n: int = _panel_rows[0].draws.size() if not _panel_rows.is_empty() else 0
	replay_caption.text = PANEL_CAPTION % n
	replay_grid.visible = false
	earnings_row.visible = false
	panel_replay.visible = true
	replay_button.disabled = false


func play() -> void:
	if _is_panel:
		panel_replay.show_experts(_panel_rows, balloon_scene, _bart().reward_per_pump, _bart().currency)
	else:
		replay_grid.show_draws(_draws, balloon_scene)


func _on_replay_finished(draws: Array) -> void:
	var first := replay_grid.get_child(0) if replay_grid.get_child_count() > 0 else null
	if first and first.has_method("summarize"):
		replay_title.text = "What your prior implies: %s" % first.summarize(draws)


## The balloons show the money: each draw also carries the payoff.
func _with_payoff(draws: Array) -> Array:
	var out := []
	for d in draws:
		var copy: Dictionary = d.duplicate()
		copy["reward_per_pump"] = _bart().reward_per_pump
		copy["currency"] = _bart().currency
		out.append(copy)
	return out


func _bart() -> BartCaseStudy:
	return case_study as BartCaseStudy
