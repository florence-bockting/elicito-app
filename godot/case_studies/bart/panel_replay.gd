class_name PanelReplay
extends VBoxContainer
## The replay of a panel: one row per expert, each with a dozen balloons
## simulated from that expert's own prior, and a small wallet that fills
## with the money they made.

const CELL := Vector2(62, 104)
const ITEM_SCALE := 0.64

var reward := 0.05
var currency := "€"
var _rows: Array[Dictionary] = []  # {"grid", "wallet"}


func _init() -> void:
	add_theme_constant_override("separation", 4)


## experts: [{"name", "color", "draws"}]; draws already carry the payoff.
func show_experts(experts: Array, scene: PackedScene, reward_per_pump: float, currency_symbol: String) -> void:
	reward = reward_per_pump
	currency = currency_symbol
	for child in get_children():
		child.queue_free()
	_rows.clear()
	for e in experts:
		_rows.append(_add_row(e, scene))


func replay() -> void:
	for row in _rows:
		row.grid.replay()


func _add_row(expert: Dictionary, scene: PackedScene) -> Dictionary:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 12)
	add_child(line)

	var name_label := Label.new()
	name_label.text = expert.name
	name_label.custom_minimum_size = Vector2(110, 0)
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_label.add_theme_color_override("font_color", expert.color)
	name_label.add_theme_font_size_override("font_size", 18)
	line.add_child(name_label)

	var grid := ReplayGrid.new()
	grid.cell_size = CELL
	grid.item_scale = ITEM_SCALE
	grid.min_rows = 1
	# exactly as wide as one row of balloons, so the wallet sits right after them
	grid.custom_minimum_size.x = expert.draws.size() * CELL.x
	line.add_child(grid)

	var wallet := WalletView.new()
	wallet.compact = true
	wallet.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(wallet)

	var row := {"grid": grid, "wallet": wallet}
	grid.replay_started.connect(func(_draws: Array) -> void: wallet.reset(reward, currency))
	grid.item_finished.connect(func(_index: int, draw: Dictionary) -> void: wallet.add_trial(draw))
	grid.show_draws(expert.draws, scene)  # starts playing
	return row
