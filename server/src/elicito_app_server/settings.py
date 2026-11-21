"""Training settings the app may send with a fit, with defaults and ranges"""

from __future__ import annotations

from typing import Any


# Training settings the client may change: name -> (type, default, min, max).
# None as default means "elicito's default" (or "estimate" for tau).
SETTINGS: dict[str, tuple[type, Any, float, float]] = {
    "epochs": (int, 400, 50, 5000),  # CMA-ES: budget in forward simulations
    "seed": (int, 1, 0, 1_000_000),
    "replications": (int, 1, 1, 8),  # one run per seed; >1 run in worker processes
    "B": (int, 128, 8, 1024),  # batch size
    "num_samples": (int, 200, 20, 5000),  # prior samples per batch
    "kappa": (float, 0.0, 0.0, 100.0),  # spread penalty
    "sigma0": (float, None, 0.001, 10.0),  # CMA-ES first step size
    "popsize": (int, None, 2, 256),  # CMA-ES candidates per generation
    "tau": (float, None, 0.001, 100.0),  # panel: spread of expert offsets
}


def validate_settings(settings: Any) -> dict[str, Any]:
    """Fill in defaults and check ranges; unknown names are an error"""
    if settings is None:
        settings = {}
    if not isinstance(settings, dict):
        raise ValueError("'settings' must be an object")
    unknown = set(settings) - set(SETTINGS)
    if unknown:
        raise ValueError(f"unknown settings: {sorted(unknown)}")
    clean: dict[str, Any] = {}
    for name, (kind, default, low, high) in SETTINGS.items():
        value = settings.get(name, default)
        if value is None:
            clean[name] = None
            continue
        try:
            value = kind(value)
        except (TypeError, ValueError) as exc:
            raise ValueError(f"setting '{name}' must be a number") from exc
        if not low <= value <= high:
            raise ValueError(f"setting '{name}' must be between {low:g} and {high:g}")
        clean[name] = value
    return clean
