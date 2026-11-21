"""Real elicito fits: slow, run with RUN_ELICITO=1

These also catch changes in elicito's API, so CI runs them against the
pinned elicito and, once a week, against the newest release.
"""

from __future__ import annotations

import os

import pytest

from conftest import EXPERT_A, PERSONAS, expert_answers
from elicito_app_server.backends import ElicitoBackend


@pytest.mark.elicito
def test_real_elicito_recovers_expert_a(tmp_path):
    answers = expert_answers(*EXPERT_A.values())
    updates = []
    result = ElicitoBackend(tmp_path).fit("bart", answers, replay_n=8, on_progress=updates.append)
    lo, hi = result["priors"]["gammap"]
    print("gammap bounds", lo, hi, "beta", result["priors"]["beta"])
    assert 0.15 < lo < 0.45 and 0.65 < hi < 0.95
    assert any(u["stage"] == "Training" and u["loss"] is not None for u in updates)
    assert len(result["replay"]) == 8
    assert os.path.exists(result["saved_eliobj"])


@pytest.mark.elicito
def test_real_elicito_panel(tmp_path):
    experts = {n: expert_answers(g, b) for n, (g, b) in PERSONAS.items()}
    result = ElicitoBackend(tmp_path).fit_panel("bart", experts, replay_n=8)
    priors = result["expert_priors"]
    print({n: priors[n]["gammap"] for n in priors}, "tau", result["tau"])
    # the risk-taker's prior on risk propensity reaches far above the cautious one's
    assert priors["Jonas"]["gammap"][1] > priors["Mila"]["gammap"][1] + 0.5
    assert set(result["tau"]) == {"gammap_lower", "gammap_upper", "beta_lower", "beta_upper"}
    assert len(result["replay"]) == 8 and os.path.exists(result["saved_eliobj"])
    # diagnostics: per-expert bound paths end at the expert's fitted bounds
    for name, hist in result["expert_bound_history"].items():
        for p, path in hist.items():
            assert len(path["lower"]) == len(result["loss_history"])
            assert abs(path["lower"][-1] - priors[name][p][0]) < 0.2 * (priors[name][p][1] + 1e-3) + 0.05
    assert set(result["expert_simulated"]["Jonas"]) == {"pumps", "omega"}


@pytest.mark.elicito
def test_real_elicito_uses_settings(tmp_path):
    answers = expert_answers(*EXPERT_A.values())
    result = ElicitoBackend(tmp_path).fit(
        "bart", answers, replay_n=4, settings={"epochs": 200, "seed": 5, "replications": 2, "popsize": 8}
    )
    assert result["settings"]["replications"] == 2
    assert result["priors"]["gammap"][1] > result["priors"]["gammap"][0]
