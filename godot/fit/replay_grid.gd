class_name ReplayGrid
extends Control
## Lays out one replay item per prior predictive draw and plays them all.
## Works with any case study whose replay scene has `play(draw, delay)` and
## a `finished(draw)` signal.

signal replay_started(draws: Array)
signal item_finished(index: int, draw: Dictionary)
signal replay_finished(draws: Array)

@export var cell_size := Vector2(96, 160)
@export var stagger := 0.04  # seconds between the starts of neighbours
@export var item_scale := 1.0  # smaller items for compact rows
@export var min_rows := 2  # reserve this many rows of space

var draws: Array = []
var _scene: PackedScene
var _remaining := 0


func _init() -> void:
	clip_contents = true


func _ready() -> void:
	custom_minimum_size.y = min_rows * cell_size.y


func show_draws(new_draws: Array, scene: PackedScene) -> void:
	draws = new_draws
	_scene = scene
	replay()


func replay() -> void:
	for child in get_children():
		child.queue_free()
	if _scene == null or draws.is_empty():
		return
	_remaining = draws.size()
	replay_started.emit(draws)
	for i in draws.size():
		var item := _scene.instantiate()
		item.scale = Vector2.ONE * item_scale
		add_child(item)
		item.finished.connect(_on_item_finished.bind(i))
		item.play(draws[i], i * stagger)
	_layout()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_layout()


func _layout() -> void:
	var cols := maxi(1, int(size.x / cell_size.x))
	var used_w := cols * cell_size.x
	var x0 := (size.x - used_w) * 0.5
	var i := 0
	for child in get_children():
		if child.is_queued_for_deletion():
			continue
		var c := i % cols
		@warning_ignore("integer_division")
		var r := i / cols  # row index: whole rows only
		child.position = Vector2(x0 + (c + 0.5) * cell_size.x, r * cell_size.y + cell_size.y * 0.36)
		i += 1
	# grow to fit all rows (only the height changes, so no resize loop)
	var rows := ceili(float(i) / cols)
	custom_minimum_size.y = maxf(min_rows, rows) * cell_size.y


func _on_item_finished(draw: Dictionary, index: int) -> void:
	item_finished.emit(index, draw)
	_remaining -= 1
	if _remaining == 0:
		replay_finished.emit(draws)
