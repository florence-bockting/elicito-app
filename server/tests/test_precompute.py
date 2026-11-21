"""The precompute tool, with the mock backend"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from conftest import PERSONAS, expert_answers
from elicito_app_server.backends import MockBackend

sys.path.insert(0, str(Path(__file__).parents[1] / "tools"))
import precompute  # noqa: E402


def test_precompute_fits_every_scenario():
    names = list(PERSONAS)
    scenarios = {
        "case_study": "bart",
        "replay_n": 6,
        "single": [{"name": n, "answers": expert_answers(g, b, n=500)} for n, (g, b) in PERSONAS.items()],
        "panels": [{"members": names[:2]}, {"members": names}],
    }
    fits = precompute.precompute(scenarios, MockBackend(delay=0.0), log=lambda _m: None)
    assert [s["name"] for s in fits["single"]] == names
    assert all(s["result"]["type"] == "result" and s["result"]["saved_eliobj"] is None for s in fits["single"])
    assert [p["members"] for p in fits["panels"]] == [names[:2], names]
    assert fits["panels"][1]["result"]["experts"] == names
    assert len(fits["single"][0]["result"]["replay"]) == 6
    assert fits["settings"]["epochs"] == 400
    json.dumps(fits)  # plain JSON, nothing numpy left
