"""Writes tests/data/bart_reference.json from the elicito documentation's BART model

The app's server has its own TensorFlow version of the BART model. This
script evaluates the PyMC model of the elicito case study
(docs/case-studies/bart-risk-taking.py in the elicito repository) at a few
fixed parameter values, so tests/test_bart.py can check that the two
models agree. Rerun it whenever the case study's model changes:

    pip install pymc
    python tools/bart_reference.py

The model block below is copied from the case study, with the priors
replaced by fixed values and the observed decisions left out.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pymc as pm
import pytensor.tensor as pt

BURST = 0.15  # the burst probability of George's balloons in the case study
K = 20  # the largest number of pumps of the output
n = np.arange(1, K + 2)  # pump number n comes after n - 1 pumps
BEFORE = np.tril(np.ones((K + 1, K + 1)), -1)  # BEFORE[n, i] = 1 if i < n
SHIFT = np.eye(K + 1, k=-1)  # moves entry m - 1 to entry m

# (gammap, beta) pairs: cautious to risky, inconsistent to consistent
POINTS = [(0.2, 0.5), (0.5, 1.0), (0.8, 2.0), (1.2, 0.8), (1.5, 3.0), (2.5, 1.5), (4.0, 6.0)]


def main() -> None:
    gammap_values = np.array([g for g, _ in POINTS])
    beta_values = np.array([b for _, b in POINTS])
    with pm.Model() as model:
        gammap = pm.Data("gammap", gammap_values)[:, None]
        beta = pm.Data("beta", beta_values)[:, None]
        omega = pm.Deterministic("omega", -gammap / np.log(1 - BURST))

        # the number of pumps in one trial (verbatim from the case study)
        theta_n = pm.math.invlogit(beta * (n - omega))
        log_go_on = pt.log(pt.clip(1 - theta_n, 1e-12, 1.0)) + np.log(1 - BURST)
        alive = pt.exp((BEFORE * log_go_on[..., None, :]).sum(axis=-1))  # A_n
        stop = alive * theta_n
        burst = alive * (1 - theta_n) * BURST
        p_pumps = stop + (SHIFT * burst[..., None, :]).sum(axis=-1)
        p_pumps = pm.Deterministic("p_pumps", p_pumps / p_pumps.sum(axis=-1, keepdims=True))

    omega_v, p_pumps_v = pm.draw([model["omega"], model["p_pumps"]], draws=1)
    out = {
        "source": "elicito docs/case-studies/bart-risk-taking.py (PyMC model)",
        "pymc_version": pm.__version__,
        "burst": BURST,
        "K": K,
        "points": [
            {"gammap": g, "beta": b, "omega": float(o), "p_pumps": [float(v) for v in p]}
            for (g, b), o, p in zip(POINTS, np.ravel(omega_v), p_pumps_v)
        ],
    }
    path = Path(__file__).parents[1] / "tests" / "data" / "bart_reference.json"
    path.write_text(json.dumps(out, indent=1) + "\n")
    print(f"wrote {path}")


if __name__ == "__main__":
    main()
