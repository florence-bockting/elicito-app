extends GutTest


func test_discrete_bins_are_centred_on_whole_numbers() -> void:
	var t := TargetSpec.new()
	t.axis_min = -0.5
	t.axis_max = 20.5
	t.discrete = true
	assert_eq(t.bin_count(), 21)
	assert_almost_eq(t.bin_center(3), 3.0, 1e-9)
	assert_eq(t.bin_edges().size(), 22)
	assert_eq(t.format_value(3.0), "3")
