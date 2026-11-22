class_name BartCaseStudy
extends CaseStudy
## The Balloon Analogue Risk Task: money per pump, and the chance that a
## pump pops the balloon.

## Money per pump, shown in the predictions (0 hides the money).
@export var reward_per_pump: float = 0.05
## Chance that one pump pops the balloon.
@export var burst_probability: float = 0.15
@export var currency: String = "€"


## Fills {reward} and {burst} in the intro.
func intro_text() -> String:
	return intro.format({
		"reward": money(reward_per_pump),
		"burst": "%d%%" % roundi(burst_probability * 100.0),
	})


func money(amount: float) -> String:
	return "%s%.2f" % [currency, amount]


# ---------------------------------------------------------------- posterior code

const PYMC_CODE := """# BART model (Lee & Wagenmakers, 2013) with priors learned by elicito
# Priors from: {source}
import arviz as az
import numpy as np
import pymc as pm

BURST = {burst}  # chance that one pump pops the balloon

# Your data: pumps per trial, and whether the balloon popped
pumps = np.array([2, 3, 1, 4, 2, 0, 3])  # replace with your data
popped = np.array([0, 0, 1, 0, 1, 0, 0], dtype=bool)

# One row per decision at pump number k: d = 1 "pump", d = 0 "stop"
k, d = [], []
for n, burst in zip(pumps, popped):
    k += list(range(1, n + 1))
    d += [1] * n  # every pump was a decision to pump
    if not burst:  # cashed in: a decision to stop at pump n + 1
        k.append(n + 1)
        d.append(0)
k, d = np.array(k), np.array(d)

with pm.Model() as bart:
    # priors learned with elicito
    gammap = pm.Uniform("gammap", lower={g_lo}, upper={g_hi})
    beta = pm.Uniform("beta", lower={b_lo}, upper={b_hi})
    omega = pm.Deterministic("omega", -gammap / np.log(1 - BURST))

    # chance to pump at pump k
    theta = pm.math.invlogit(-beta * (k - omega))
    pm.Bernoulli("d", p=theta, observed=d)

    idata = pm.sample()  # the posterior

print(az.summary(idata, var_names=["gammap", "beta", "omega"]))
"""

const BRMS_CODE := """# BART model (Lee & Wagenmakers, 2013) with priors learned by elicito
# Priors from: {source}
library(brms)

# Your data: pumps per trial, and whether the balloon popped
pumps  <- c(2, 3, 1, 4, 2, 0, 3)  # replace with your data
popped <- c(FALSE, FALSE, TRUE, FALSE, TRUE, FALSE, FALSE)

# One row per decision at pump number k: d = 1 "pump", d = 0 "stop"
decisions <- do.call(rbind, lapply(seq_along(pumps), function(t) {
  n <- pumps[t]
  rows <- data.frame(k = seq_len(n), d = rep(1, n))
  if (!popped[t]) rows <- rbind(rows, data.frame(k = n + 1, d = 0))
  rows
}))

# logit(chance to pump) = beta * (omega - k), omega = -gammap / log(1 - {burst})
bart <- bf(
  d ~ beta * (-gammap / log(1 - {burst}) - k),
  gammap + beta ~ 1,
  nl = TRUE
)

# priors learned with elicito
priors <- c(
  prior(uniform({g_lo}, {g_hi}), nlpar = "gammap", lb = {g_lo}, ub = {g_hi}),
  prior(uniform({b_lo}, {b_hi}), nlpar = "beta", lb = {b_lo}, ub = {b_hi})
)

fit <- brm(bart, data = decisions, family = bernoulli(link = "logit"), prior = priors)
summary(fit)  # the posterior
"""


func posterior_languages() -> Dictionary:
	return {"pymc": "Python · PyMC", "brms": "R · brms"}


## The book's priors (Lee & Wagenmakers): Uniform(0, 10) for both.
func placeholder_priors() -> Dictionary:
	return {"gammap": [0.0, 10.0], "beta": [0.0, 10.0]}


func posterior_code(language: String, priors: Dictionary, source: String) -> String:
	var template := ""
	match language:
		"pymc":
			template = PYMC_CODE
		"brms":
			template = BRMS_CODE
		_:
			return ""
	var g: Array = priors.get("gammap", [0.0, 10.0])
	var b: Array = priors.get("beta", [0.0, 10.0])
	return template.format({
		"source": source,
		"burst": _num(burst_probability),
		"g_lo": _num(minf(g[0], g[1])),
		"g_hi": _num(maxf(g[0], g[1])),
		"b_lo": _num(minf(b[0], b[1])),
		"b_hi": _num(maxf(b[0], b[1])),
	})


static func _num(x: float) -> String:
	var text := "%.3f" % x
	text = text.rstrip("0")
	return text + "0" if text.ends_with(".") else text
