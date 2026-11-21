"""The BART model of the app against the model of the elicito documentation

tests/data/bart_reference.json holds the pumps distribution of the
documentation's PyMC model at a few parameter values; see
tools/bart_reference.py. If one of these tests fails, the app's model and
the case study have drifted apart.
"""

from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import pytest

from elicito_app_server.case_studies.bart import BURST, K, omega, simulate, trial_outcomes

REFERENCE = json.loads((Path(__file__).parent / "data" / "bart_reference.json").read_text())
POINTS = REFERENCE["points"]


def test_reference_uses_the_same_task():
    assert REFERENCE["burst"] == BURST and REFERENCE["K"] == K


@pytest.mark.parametrize("point", POINTS, ids=lambda p: f"g{p['gammap']}-b{p['beta']}")
def test_tensorflow_model_matches_the_docs(point):
    """Same pumps distribution as the PyMC model, up to float32 rounding"""
    stop, burst = (np.asarray(t, dtype=float) for t in trial_outcomes([point["gammap"]], [point["beta"]]))
    p_pumps = stop[0].copy()
    p_pumps[1:] += burst[0][:-1]  # bursting on pump m leaves m pumps
    p_pumps /= p_pumps.sum()
    np.testing.assert_allclose(p_pumps, point["p_pumps"], atol=1e-5)
    assert omega(point["gammap"]) == pytest.approx(point["omega"])


@pytest.mark.parametrize("point", POINTS[:4], ids=lambda p: f"g{p['gammap']}-b{p['beta']}")
def test_replay_simulator_matches_the_docs(point):
    """The numpy simulator behind the balloons draws from the same distribution"""
    g, b = point["gammap"], point["beta"]
    sims = simulate((g, g), (b, b), 20_000, seed=3)
    counts = np.bincount([s["pumps"] for s in sims], minlength=K + 1)[: K + 1] / len(sims)
    np.testing.assert_allclose(counts, point["p_pumps"], atol=0.015)


def test_simulator_plans_match_omega():
    g = 3.5 * -np.log(1 - BURST)  # omega = 3.5, halfway between decisions
    sims = simulate((g, g), (50.0, 50.0), 500, seed=1)
    # very consistent participant: stops after 3 pumps unless the balloon bursts
    stopped = [s["pumps"] for s in sims if not s["burst"]]
    assert set(stopped) == {3}
    assert all(s["pumps"] <= 3 for s in sims)
