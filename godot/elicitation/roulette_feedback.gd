class_name RouletteFeedback
extends RefCounted
## Plain-language feedback on a chip histogram: what the chips say (most
## likely value, 80% range, how certain) and one gentle hint when the
## pattern looks unintended (everything in one column, gaps, chips piled at
## the end of the axis, an almost flat spread). Also scores a practice answer
## against known true probabilities.

const HIGHLIGHT := "#a8540f"
const GOOD := "#2e7d32"
const RANGE_PROBS: Array[float] = [0.1, 0.5, 0.9]


## One line summarising a complete answer, e.g. "Most likely 4 · 80% of your
## chips between 2 and 7 · fairly certain". Empty while chips are left.
static func summary(spec: TargetSpec, counts: PackedInt32Array) -> String:
	if _total(counts) < spec.chips:
		return ""
	var used := used_bins(counts)
	var range_text := ""
	if used.size() == 1:
		if spec.discrete:
			range_text = "all your chips on %s" % value_text(spec, spec.bin_center(used[0]))
		else:
			var edges := spec.bin_edges()
			range_text = "all your chips between %s and %s" % [spec.format_value(edges[used[0]]), spec.format_value(edges[used[0] + 1])]
	else:
		var r := middle_range(spec, counts)
		range_text = "the middle 80%% of your chips between %s and %s" % [value_text(spec, r.x), value_text(spec, r.y)]
	return "Most likely [color=%s]%s[/color] · %s · [color=%s]%s[/color]" % [
		HIGHLIGHT, value_text(spec, spec.bin_center(mode_bin(counts))), range_text, HIGHLIGHT, certainty(spec, counts)
	]


## Where the middle 80% of the chips lie (x = low end, y = high end). For
## counts: the columns left after taking 10% of the chips off each end.
static func middle_range(spec: TargetSpec, counts: PackedInt32Array) -> Vector2:
	var total := _total(counts)
	if not spec.discrete:
		var q := QuantileMath.quantiles_from_histogram(counts, spec.bin_edges(), RANGE_PROBS)
		return Vector2(q[0], q[2])
	var cut := 0.1 * total
	var lo := 0
	var cum := 0
	for i in counts.size():
		cum += counts[i]
		if cum > cut + 1e-9:
			lo = i
			break
	var hi := counts.size() - 1
	cum = 0
	for i in range(counts.size() - 1, -1, -1):
		cum += counts[i]
		if cum > cut + 1e-9:
			hi = i
			break
	return Vector2(spec.bin_center(lo), spec.bin_center(hi))


## "very certain" … "very uncertain", from how wide the middle 80% of the
## chips is compared with the whole axis.
static func certainty(spec: TargetSpec, counts: PackedInt32Array) -> String:
	if _total(counts) == 0:
		return ""
	var q := QuantileMath.quantiles_from_histogram(counts, spec.bin_edges(), RANGE_PROBS)
	var width := (q[2] - q[0]) / maxf(spec.axis_max - spec.axis_min, 1e-9)
	if width < 0.12:
		return "very certain"
	if width < 0.3:
		return "fairly certain"
	if width < 0.55:
		return "rather uncertain"
	return "very uncertain"


## The most important hint for a complete answer, or "" when nothing stands
## out. Hints are questions, not corrections: the expert decides.
static func hint(spec: TargetSpec, counts: PackedInt32Array) -> String:
	if _total(counts) < spec.chips:
		return ""
	var used := used_bins(counts)
	if used.size() == 1:
		return "All chips in one column says every other value is impossible. Even experts are rarely that sure: could a neighbouring value happen too?"
	if has_gap(counts):
		return "There is an empty column between your chips, so values there are less likely than on both sides. Is that what you mean?"
	if used.size() >= 0.8 * counts.size() and _max(counts) - _min_used(counts) <= 1:
		return "Your chips are spread almost evenly, which says you have no idea at all. If some values seem more likely, stack more chips there."
	# only the top end: the low end is often a natural limit (0 pumps, 0 heads)
	if counts[counts.size() - 1] >= 0.15 * spec.chips:
		return "Many chips sit at the top end of the axis. The axis stops there, so larger values get no chance at all."
	return ""


## How a practice answer compares with the true probabilities `truth`
## (one per bin, summing to 1), as a few short lines.
static func practice_verdict(spec: TargetSpec, counts: PackedInt32Array, truth: PackedFloat64Array) -> String:
	var total := float(_total(counts))
	var overlap := 0.0
	var mean_you := 0.0
	var mean_true := 0.0
	for i in counts.size():
		var u := counts[i] / total
		overlap += minf(u, truth[i])
		mean_you += u * spec.bin_center(i)
		mean_true += truth[i] * spec.bin_center(i)
	var pct := roundi(overlap * 100.0)
	var verdict := "Excellent" if pct >= 85 else ("Good" if pct >= 70 else "A good start")
	var lines: Array[String] = ["[color=%s]%s: your chips match %d%% of the real chances.[/color]" % [GOOD, verdict, pct]]

	# the central range that holds most of the true probability (a fair coin: 3–7 heads)
	var core := _core_bins(truth, 0.85)
	var you_core := 0.0
	var true_core := 0.0
	for i in core:
		you_core += counts[i] / total
		true_core += truth[i]
	var core_text := "%s–%s" % [value_text(spec, spec.bin_center(core[0])), value_text(spec, spec.bin_center(core[core.size() - 1]))]
	var tails := 1.0 - true_core
	if you_core > true_core + 0.07:
		lines.append("You were more certain than the coin: about %d%% of runs land outside %s, but you left almost no chips there." % [roundi(tails * 100.0), core_text])
	elif you_core < true_core - 0.12:
		lines.append("You were less certain than needed: results outside %s happen only %d%% of the time, but you put %d%% of your chips there." % [core_text, roundi(tails * 100.0), roundi((1.0 - you_core) * 100.0)])
	if absf(mean_you - mean_true) > 0.7:
		lines.append("Your chips lean to the %s. The real chances are symmetric around %s." % ["left" if mean_you < mean_true else "right", value_text(spec, mean_true)])
	if lines.size() == 1:
		lines.append("Your spread matches the coin's uncertainty well.")
	lines.append("The outlines show the real chances. Above each column: [color=%s]your chips / real[/color]." % HIGHLIGHT)
	return "\n".join(lines)


## `value` as shown on the axis: for counts, the whole number of its bin.
static func value_text(spec: TargetSpec, value: float) -> String:
	if spec.discrete:
		var b := clampi(int(floor((value - spec.axis_min) / spec.bin_width)), 0, spec.bin_count() - 1)
		return spec.format_value(spec.bin_center(b))
	return spec.format_value(snappedf(value, 0.5) if spec.bin_width >= 1.0 else value)


static func mode_bin(counts: PackedInt32Array) -> int:
	var best := 0
	for i in counts.size():
		if counts[i] > counts[best]:
			best = i
	return best


static func used_bins(counts: PackedInt32Array) -> Array[int]:
	var out: Array[int] = []
	for i in counts.size():
		if counts[i] > 0:
			out.append(i)
	return out


## An empty column with chips on both sides.
static func has_gap(counts: PackedInt32Array) -> bool:
	var used := used_bins(counts)
	return used.size() >= 2 and used[used.size() - 1] - used[0] + 1 > used.size()


## `chips` chips over `n` bins in proportion to `weights`, starting at bin
## `start` (for example answers).
static func spread(weights: Array, start: int, n: int, chips: int) -> PackedInt32Array:
	var exact := PackedFloat64Array()
	exact.resize(n)
	var total := 0.0
	for w in weights:
		total += w
	for i in weights.size():
		exact[clampi(start + i, 0, n - 1)] += weights[i] / total * chips
	# largest remainders get the leftover chips; ties go to the middle first
	var counts := PackedInt32Array()
	var given := 0
	for e in exact:
		counts.append(int(floor(e)))
		given += int(floor(e))
	var order := range(n)
	var mid := (n - 1) / 2.0
	order.sort_custom(func(a: int, b: int) -> bool:
		var ra := exact[a] - counts[a]
		var rb := exact[b] - counts[b]
		return ra > rb + 1e-9 or (absf(ra - rb) <= 1e-9 and absf(a - mid) < absf(b - mid)))
	for i in chips - given:
		counts[order[i % n]] += 1
	return counts


## The smallest run of neighbouring bins around the mode holding at least
## `mass` of `truth`.
static func _core_bins(truth: PackedFloat64Array, mass: float) -> Array[int]:
	var best := 0
	for i in truth.size():
		if truth[i] > truth[best]:
			best = i
	var lo := best
	var hi := best
	var sum := truth[best]
	while sum < mass and (lo > 0 or hi < truth.size() - 1):
		var left := truth[lo - 1] if lo > 0 else -1.0
		var right := truth[hi + 1] if hi < truth.size() - 1 else -1.0
		if left >= right:
			lo -= 1
			sum += left
		else:
			hi += 1
			sum += right
	var out: Array[int] = []
	for i in range(lo, hi + 1):
		out.append(i)
	return out


static func _total(counts: PackedInt32Array) -> int:
	var t := 0
	for c in counts:
		t += c
	return t


static func _max(counts: PackedInt32Array) -> int:
	var m := 0
	for c in counts:
		m = maxi(m, c)
	return m


static func _min_used(counts: PackedInt32Array) -> int:
	var m := 1 << 30
	for c in counts:
		if c > 0:
			m = mini(m, c)
	return m
