class_name QuantileMath
extends RefCounted
## Turns a chip histogram into the quantiles elicito expects.
##
## The chips in a bin are spread uniformly over the bin, so the CDF is
## piecewise linear and every quantile has a unique value.


## Quantiles of the histogram `counts` over the bins `edges` (one more edge
## than counts). Returns an empty array when no chips are placed.
static func quantiles_from_histogram(
	counts: PackedInt32Array, edges: PackedFloat64Array, probs: Array[float]
) -> PackedFloat64Array:
	assert(edges.size() == counts.size() + 1, "need one more edge than bins")
	var out := PackedFloat64Array()
	var total := 0
	for c in counts:
		total += c
	if total == 0:
		return out
	for p in probs:
		var cum := 0.0
		var q := edges[edges.size() - 1]
		for i in counts.size():
			var mass := float(counts[i]) / total
			if mass > 0.0 and cum + mass >= p - 1e-9:
				var frac := clampf((p - cum) / mass, 0.0, 1.0)
				q = edges[i] + frac * (edges[i + 1] - edges[i])
				break
			cum += mass
		out.append(q)
	return out


## Fraction of chips at or below each bin's right edge, for drawing the CDF.
static func cdf(counts: PackedInt32Array) -> PackedFloat64Array:
	var out := PackedFloat64Array()
	var total := 0
	for c in counts:
		total += c
	var cum := 0
	for c in counts:
		cum += c
		out.append(float(cum) / total if total > 0 else 0.0)
	return out

## Turns simulated values into a chip histogram with exactly `spec.chips`
## chips (largest-remainder rounding), e.g. to show a persona's answer.
static func chips_from_samples(samples: PackedFloat64Array, spec: TargetSpec) -> PackedInt32Array:
	var n_bins := spec.bin_count()
	var raw := PackedFloat64Array()
	raw.resize(n_bins)
	raw.fill(0.0)
	for v in samples:
		var b := clampi(int(floor((v - spec.axis_min) / spec.bin_width)), 0, n_bins - 1)
		raw[b] += 1.0
	var counts := PackedInt32Array()
	counts.resize(n_bins)
	var remainders := []
	var given := 0
	for i in n_bins:
		var exact := raw[i] / samples.size() * spec.chips
		counts[i] = int(floor(exact))
		given += counts[i]
		remainders.append([exact - floor(exact), i])
	# hand the leftover chips to the bins that were rounded down the most
	remainders.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
	for k in spec.chips - given:
		counts[remainders[k][1]] += 1
	return counts
