extends GutTest
## QuantileMath: chips -> quantiles, and samples -> chips.

const PROBS: Array[float] = [0.1, 0.25, 0.5, 0.75, 0.9]


func test_uniform_chips_give_linear_quantiles() -> void:
	# one chip in each of 10 bins over [0, 10] -> uniform -> q_p = 10 p
	var counts := PackedInt32Array([1, 1, 1, 1, 1, 1, 1, 1, 1, 1])
	var edges := PackedFloat64Array([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
	var q := QuantileMath.quantiles_from_histogram(counts, edges, PROBS)
	for i in PROBS.size():
		assert_almost_eq(q[i], 10.0 * PROBS[i], 1e-6)


func test_single_bin_spreads_quantiles_inside_it() -> void:
	var counts := PackedInt32Array([0, 0, 0, 20, 0])
	var edges := PackedFloat64Array([-0.5, 0.5, 1.5, 2.5, 3.5, 4.5])
	var q := QuantileMath.quantiles_from_histogram(counts, edges, [0.1, 0.5, 0.9])
	assert_almost_eq(q[0], 2.6, 1e-6)
	assert_almost_eq(q[1], 3.0, 1e-6)
	assert_almost_eq(q[2], 3.4, 1e-6)


func test_no_chips_no_quantiles() -> void:
	var edges := PackedFloat64Array([0, 1, 2, 3, 4])
	assert_true(QuantileMath.quantiles_from_histogram(PackedInt32Array([0, 0, 0, 0]), edges, [0.5]).is_empty())


func test_gap_between_bins() -> void:
	# half the mass in bin 0, half in bin 3: the median sits at the end of bin 0
	var edges := PackedFloat64Array([0, 1, 2, 3, 4])
	var q := QuantileMath.quantiles_from_histogram(PackedInt32Array([5, 0, 0, 5]), edges, [0.5, 0.75])
	assert_almost_eq(q[0], 1.0, 1e-6)
	assert_almost_eq(q[1], 3.5, 1e-6)
	var cdf := QuantileMath.cdf(PackedInt32Array([5, 0, 0, 5]))
	assert_almost_eq(cdf[0], 0.5, 1e-6)
	assert_almost_eq(cdf[3], 1.0, 1e-6)


func test_chips_from_samples_uses_every_chip() -> void:
	var spec := TargetSpec.new()
	spec.axis_min = -0.5
	spec.axis_max = 20.5
	spec.discrete = true
	var samples := PackedFloat64Array()
	for i in 1000:
		samples.append(float(i % 7))
	var chips := QuantileMath.chips_from_samples(samples, spec)
	var total := 0
	for c in chips:
		total += c
	assert_eq(total, spec.chips)
