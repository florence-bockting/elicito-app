"""The case studies the Godot app can run

Each case study is a small object with:

* ``id``            - key the app sends in a fit request
* ``targets``       - names and probabilities of the quantile targets; the
                      app's CaseStudy resource must use the same names
* ``build()``       - returns a fresh ``el.Elicit`` object
* ``bounds(fit)``   - turns the learned hyperparameters into readable priors
* ``replay(fit, n)``- prior predictive draws for the app's Predictions tab

TensorFlow and elicito are imported lazily, so the mock backend runs
without them. To add a case study, write a module like ``bart.py`` and
register it here.
"""

from __future__ import annotations

from typing import Any

from elicito_app_server.case_studies.bart import BartCaseStudy

CASE_STUDIES: dict[str, Any] = {"bart": BartCaseStudy()}
