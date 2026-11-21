"""Checks for the answers and panels the app sends, and a density helper"""

from __future__ import annotations

from typing import Any

import numpy as np


def validate_expert(case: Any, expert: dict[str, Any]) -> dict[str, list[float]]:
    """Check the client's answers against the case study; return clean floats"""
    if not isinstance(expert, dict):
        raise ValueError("'expert' must be an object keyed by target name")
    missing = set(case.targets) - set(expert)
    extra = set(expert) - set(case.targets)
    if missing or extra:
        raise ValueError(
            f"targets do not match: missing {sorted(missing)}, unknown {sorted(extra)}"
        )
    clean: dict[str, list[float]] = {}
    for name, probs in case.targets.items():
        values = expert[name]
        if not isinstance(values, list) or len(values) != len(probs):
            raise ValueError(f"'{name}' needs {len(probs)} quantiles")
        try:
            floats = [float(v) for v in values]
        except (TypeError, ValueError) as exc:
            raise ValueError(f"'{name}' must contain numbers") from exc
        if not all(np.isfinite(floats)):
            raise ValueError(f"'{name}' contains non-finite values")
        if any(b < a for a, b in zip(floats, floats[1:])):
            raise ValueError(f"'{name}' quantiles must be non-decreasing")
        clean[name] = floats
    return clean


def validate_panel(case: Any, experts: Any) -> dict[str, dict[str, list[float]]]:
    """Check a panel: at least two experts, unique names, valid answers each"""
    if not isinstance(experts, dict) or len(experts) < 2:
        raise ValueError("a panel needs the answers of at least two experts")
    clean = {}
    for name, answers in experts.items():
        if not isinstance(name, str) or not name.strip():
            raise ValueError("every expert in the panel needs a name")
        try:
            clean[name.strip()] = validate_expert(case, answers)
        except ValueError as exc:
            raise ValueError(f"{name}: {exc}") from exc
    if len(clean) != len(experts):
        raise ValueError("expert names in the panel must be unique")
    return clean


def density(samples: np.ndarray, upper: float, bins: int = 40) -> dict[str, Any]:
    """Histogram density of samples on [0, upper], plus a 90% interval"""
    samples = np.asarray(samples, float)
    counts, edges = np.histogram(np.clip(samples, 0.0, upper), bins=bins, range=(0.0, upper))
    width = edges[1] - edges[0]
    return dict(
        edges=[float(e) for e in edges],
        density=[float(c / (len(samples) * width)) for c in counts],
        q05=float(np.quantile(samples, 0.05)),
        q95=float(np.quantile(samples, 0.95)),
    )
