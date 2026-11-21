"""Shared helpers for the server tests

Run: pytest            (fast tests, mock backend)
     RUN_ELICITO=1 pytest  (also the real elicito fits, a few minutes)
"""

from __future__ import annotations

import os

import numpy as np
import pytest
from fastapi.testclient import TestClient

from elicito_app_server.app import app
from elicito_app_server.backends import MockBackend
from elicito_app_server.case_studies.bart import PROBS, simulate

EXPERT_A = {"gammap": (0.3, 0.8), "beta": (0.5, 1.5)}
PERSONAS = {
    "Mila": ((0.1, 0.35), (0.2, 0.6)),
    "Sam": ((0.3, 0.8), (0.5, 1.5)),
    "Jonas": ((1.0, 2.0), (2.0, 4.0)),
}


def expert_answers(gammap, beta, n=20_000):
    """Quantile answers an expert with this ground-truth prior would give"""
    sims = simulate(gammap, beta, n, seed=7)
    return {
        "pumps": [float(v) for v in np.quantile([s["pumps"] for s in sims], PROBS)],
        "omega": [float(v) for v in np.quantile([s["omega"] for s in sims], PROBS)],
    }


@pytest.fixture
def mock_client():
    app.state.backend = MockBackend(delay=0.05)
    with TestClient(app) as client:
        yield client
    app.state.backend = None


def pytest_collection_modifyitems(config, items):
    """Real elicito fits are slow: run them only with RUN_ELICITO=1"""
    if os.environ.get("RUN_ELICITO"):
        return
    skip = pytest.mark.skip(reason="slow: set RUN_ELICITO=1")
    for item in items:
        if "elicito" in item.keywords:
            item.add_marker(skip)
