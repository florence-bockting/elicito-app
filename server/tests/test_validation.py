"""Checks of what the app sends: answers, panels, training settings"""

from __future__ import annotations

import pytest

from conftest import EXPERT_A, expert_answers
from elicito_app_server.case_studies import CASE_STUDIES
from elicito_app_server.settings import validate_settings
from elicito_app_server.validation import validate_expert, validate_panel


def test_validate_rejects_bad_answers():
    case = CASE_STUDIES["bart"]
    good = expert_answers(*EXPERT_A.values(), n=500)
    assert validate_expert(case, good)["pumps"] == good["pumps"]
    with pytest.raises(ValueError, match="missing"):
        validate_expert(case, {"pumps": good["pumps"]})
    with pytest.raises(ValueError, match="non-decreasing"):
        validate_expert(case, {**good, "omega": [5, 4, 3, 2, 1]})
    with pytest.raises(ValueError, match="needs 5"):
        validate_expert(case, {**good, "omega": [1, 2]})


def test_validate_panel():
    case = CASE_STUDIES["bart"]
    one = expert_answers(*EXPERT_A.values(), n=500)
    with pytest.raises(ValueError, match="at least two"):
        validate_panel(case, {"Anna": one})
    with pytest.raises(ValueError, match="Ben: .*missing"):
        validate_panel(case, {"Anna": one, "Ben": {"pumps": one["pumps"]}})
    assert set(validate_panel(case, {"Anna": one, "Ben": one})) == {"Anna", "Ben"}


def test_validate_settings():
    defaults = validate_settings(None)
    assert defaults["epochs"] == 400 and defaults["sigma0"] is None and defaults["tau"] is None
    assert validate_settings({"epochs": "800", "kappa": 0.5})["epochs"] == 800
    with pytest.raises(ValueError, match="between"):
        validate_settings({"replications": 20})
    with pytest.raises(ValueError, match="unknown"):
        validate_settings({"learning_rate": 0.1})
