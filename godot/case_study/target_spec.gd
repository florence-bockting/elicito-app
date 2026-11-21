class_name TargetSpec
extends Resource
## One elicitation target: the question the expert answers and the axis
## they answer on. `name` must match the target name on the elicito server.

@export var name: String = ""
@export var title: String = ""
@export_multiline var question: String = ""
@export var unit: String = ""
@export var axis_min: float = 0.0
@export var axis_max: float = 20.0
@export var bin_width: float = 1.0
## Bins are centred on whole numbers (e.g. counts): labels sit under the bins.
@export var discrete: bool = false
## Number of probability chips the expert distributes (20 chips = 5% each).
@export var chips: int = 20
## Probabilities of the quantiles sent to elicito. Must match the server.
@export var probs: Array[float] = [0.1, 0.25, 0.5, 0.75, 0.9]


func bin_count() -> int:
	return int(round((axis_max - axis_min) / bin_width))


func bin_edges() -> PackedFloat64Array:
	var edges := PackedFloat64Array()
	for i in bin_count() + 1:
		edges.append(axis_min + i * bin_width)
	return edges


func bin_center(i: int) -> float:
	return axis_min + (i + 0.5) * bin_width


func format_value(v: float) -> String:
	if discrete or is_equal_approx(v, round(v)):
		return str(int(round(v)))
	return "%.1f" % v
