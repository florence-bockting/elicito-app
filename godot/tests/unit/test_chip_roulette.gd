extends GutTest
## ChipRoulette's state: adding, removing, completeness, quantiles.

var roulette: ChipRoulette


func before_each() -> void:
	var spec := TargetSpec.new()
	spec.axis_min = 0
	spec.axis_max = 4
	spec.bin_width = 1
	spec.chips = 4
	roulette = autofree(ChipRoulette.new())
	roulette.spec = spec


func test_chips_until_complete() -> void:
	assert_true(roulette.add_chip(0) and roulette.add_chip(1) and roulette.add_chip(1))
	assert_false(roulette.add_chip(9), "a bin outside the axis")
	assert_eq(roulette.chips_left(), 1)
	assert_true(roulette.add_chip(3))
	assert_false(roulette.add_chip(2), "no chips left")
	assert_true(roulette.is_complete())
	assert_almost_eq(roulette.quantiles()[2], 1.5, 1e-6, "median of [1, 2, 0, 1]")


func test_moving_a_chip_clears_the_fit_overlay() -> void:
	roulette.set_counts(PackedInt32Array([1, 2, 0, 1]))
	roulette.set_model_quantiles(PackedFloat64Array([0, 1, 2, 3, 4]))
	assert_true(roulette.remove_chip(1))
	assert_true(roulette.model_quantiles.is_empty())
	assert_false(roulette.remove_chip(2), "an empty bin")


func test_every_change_is_signalled() -> void:
	watch_signals(roulette)
	roulette.add_chip(0)
	roulette.add_chip(1)
	roulette.remove_chip(0)
	roulette.reset()
	assert_signal_emit_count(roulette, "histogram_changed", 4)
	assert_eq(roulette.placed(), 0)
