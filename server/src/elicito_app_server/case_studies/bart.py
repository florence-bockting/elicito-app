"""Balloon Analogue Risk Task (Lee & Wagenmakers, 2013)

The model is written directly in TensorFlow, so the server needs no PyMC.
It follows the BART case study in the elicito documentation; the parity
test in tests/test_bart.py checks that the two agree.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

import numpy as np

from elicito_app_server.settings import validate_settings

BURST = 0.15
K = 20  # the largest number of pumps the model returns


def omega(gammap: np.ndarray) -> np.ndarray:
    return -np.asarray(gammap) / np.log(1.0 - BURST)


def simulate_trial(gammap: float, beta: float, rng: np.random.Generator) -> tuple[int, bool]:
    """Return (number of pumps, burst?) for one trial."""
    w = float(omega(gammap))
    pumps = 0
    for n in range(1, K + 2):
        p_stop = 1.0 / (1.0 + np.exp(-beta * (n - w)))
        if rng.random() < p_stop:
            return pumps, False
        pumps += 1
        if rng.random() < BURST:
            return pumps, True
        if pumps >= K:
            return pumps, False
    return pumps, False


def simulate(
    gammap_bounds: tuple[float, float],
    beta_bounds: tuple[float, float],
    n: int,
    seed: int = 0,
) -> list[dict[str, float]]:
    """Draw ``n`` participants from Uniform priors and simulate one trial each."""
    rng = np.random.default_rng(seed)
    g = rng.uniform(*gammap_bounds, size=n)
    b = rng.uniform(*beta_bounds, size=n)
    out = []
    for gi, bi in zip(g, b):
        pumps, burst = simulate_trial(gi, bi, rng)
        out.append(
            dict(
                gammap=float(gi),
                beta=float(bi),
                omega=float(omega(gi)),
                pumps=int(pumps),
                burst=bool(burst),
            )
        )
    return out


PROBS = (0.1, 0.25, 0.5, 0.75, 0.9)


def trial_outcomes(gammap: Any, beta: Any) -> tuple[Any, Any]:
    """Probabilities of how one trial ends, as TensorFlow tensors

    ``stop[..., n - 1]``: the participant stops after n - 1 pumps.
    ``burst[..., n - 1]``: the balloon bursts on pump n.
    The number of pumps m therefore has P(m) = stop[m] + burst[m - 1], as
    in the case study of the elicito documentation.
    """
    import tensorflow as tf

    gammap = tf.convert_to_tensor(gammap, tf.float32)
    beta = tf.convert_to_tensor(beta, tf.float32)
    omega = -gammap / np.log(1.0 - BURST)
    n = tf.range(1, K + 2, dtype=tf.float32)
    # probability of stopping at decision n
    theta = tf.sigmoid(beta[..., None] * (n - omega[..., None]))
    go_on = tf.math.log(tf.clip_by_value(1.0 - theta, 1e-12, 1.0)) + np.log(1.0 - BURST)
    alive = tf.exp(tf.math.cumsum(go_on, axis=-1, exclusive=True))
    stop = alive * theta  # stops after n - 1 pumps
    burst = alive * (1.0 - theta) * BURST  # bursts on pump n
    return stop, burst


@dataclass
class BartCaseStudy:
    """Balloon Analogue Risk Task (Lee & Wagenmakers, 2013).

    Mirrors elicito's BART case study, written as a TensorFlow callable
    instead of a PyMC model so the server needs no PyMC.
    """

    id: str = "bart"
    parameters: tuple[str, ...] = ("gammap", "beta")
    targets: dict[str, tuple[float, ...]] = field(
        default_factory=lambda: {"pumps": PROBS, "omega": PROBS}
    )

    def build(self, settings: dict[str, Any] | None = None) -> Any:
        """A fresh el.Elicit; ``settings`` come from validate_settings()"""
        import elicito as el

        settings = settings or validate_settings({})
        import tensorflow as tf
        import tensorflow_probability as tfp

        tfd = tfp.distributions

        class BartModel:
            """Generative model: prior samples -> pumps, burst flag, omega"""

            def __call__(self, prior_samples: Any) -> dict[str, Any]:
                gammap = prior_samples[..., 0]
                beta = prior_samples[..., 1]
                omega = -gammap / np.log(1.0 - BURST)
                stop, burst = trial_outcomes(gammap, beta)
                logits = tf.math.log(tf.concat([stop, burst], axis=-1) + 1e-12)
                outcome = tfd.Categorical(logits=logits).sample()
                is_burst = tf.cast(outcome >= K + 1, tf.float32)
                pumps = tf.cast(outcome % (K + 1), tf.float32) + is_burst
                return dict(pumps=pumps, burst=is_burst, omega=omega)

        parameters = [
            el.parameter(
                name=p,
                family=tfd.Uniform,
                hyperparams=dict(
                    low=el.hyper(f"{p}_lower", lower=0.0),
                    high=el.hyper(f"{p}_upper", lower=0.0),
                ),
            )
            for p in self.parameters
        ]
        targets = [el.quantiles(name, probs=probs) for name, probs in self.targets.items()]
        cmaes = {k: settings[k] for k in ("sigma0", "popsize") if settings[k] is not None}
        return el.Elicit(
            BartModel(),
            targets,
            parameters,
            seeds=tuple(range(settings["seed"], settings["seed"] + settings["replications"])),
            epochs=settings["epochs"],
            B=settings["B"],
            num_samples=settings["num_samples"],
            kappa=settings["kappa"],
            cmaes=cmaes or None,
            verbose=False,
        )

    def bounds(self, hyper: dict[str, float]) -> dict[str, list[float]]:
        """Sorted Uniform bounds per parameter (CMA-ES may swap low/high)"""
        return {
            p: sorted([float(hyper[f"{p}_lower"]), float(hyper[f"{p}_upper"])])
            for p in self.parameters
        }

    def bound_history(self, hist: dict[str, Any]) -> dict[str, dict[str, list[float]]]:
        """Per epoch: the Uniform bounds of each parameter, sorted like bounds()"""
        out = {}
        for p in self.parameters:
            a = np.asarray(hist[f"{p}_lower"], dtype=np.float64)
            b = np.asarray(hist[f"{p}_upper"], dtype=np.float64)
            out[p] = dict(lower=[float(v) for v in np.minimum(a, b)], upper=[float(v) for v in np.maximum(a, b)])
        return out

    def hyper_names(self) -> list[str]:
        """All hyperparameters; a panel lets every one of them differ by expert"""
        return [f"{p}_{side}" for p in self.parameters for side in ("lower", "upper")]

    def simulate_draws(self, samples: dict[str, Any], seed: int) -> list[dict[str, Any]]:
        """One simulated trial per prior draw; ``samples`` maps parameter -> values"""
        rng = np.random.default_rng(seed)
        out = []
        for g, b in zip(np.asarray(samples["gammap"], float), np.asarray(samples["beta"], float)):
            g = max(g, 0.0)  # the panel prior can reach slightly below zero
            pumps, burst = simulate_trial(g, max(b, 0.0), rng)
            out.append(
                dict(gammap=float(g), beta=float(b), omega=float(omega(g)),
                     pumps=int(pumps), burst=bool(burst))
            )
        return out

    def mock_priors(self, answers: dict[str, list[float]]) -> dict[str, tuple[float, float]]:
        """For the mock backend: rough Uniform bounds from the answers, no elicito"""
        # omega quantiles 10% / 90% -> gammap bounds, with Uniform stretch
        o10, o90 = answers["omega"][0], answers["omega"][-1]
        scale = -np.log(1 - BURST)
        stretch = 1.25  # the 10-90 range of a Uniform is 80% of its width
        mid, half = (o10 + o90) / 2, max((o90 - o10) / 2 * stretch, 0.1)
        return {"gammap": (max(0.0, (mid - half) * scale), (mid + half) * scale), "beta": (0.5, 1.5)}

    def replay(self, fit: Any, n: int, seed: int) -> list[dict[str, Any]]:
        best = fit.best()
        draws = fit.sample(num_samples=n, B=1, seed=seed)
        model = draws["model"].to_dataset().isel(replication=best, batch=0)
        prior = draws["prior"].to_dataset().isel(replication=best, batch=0)
        return [
            dict(
                gammap=float(prior["gammap"].values[i]),
                beta=float(prior["beta"].values[i]),
                omega=float(model["omega"].values[i]),
                pumps=int(model["pumps"].values[i]),
                burst=bool(model["burst"].values[i] > 0.5),
            )
            for i in range(n)
        ]
