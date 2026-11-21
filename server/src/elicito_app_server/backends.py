"""Fit backends: the real elicito backend and a fast mock for UI work.

Both expose ``fit(case_id, expert, replay_n, on_progress) -> dict`` and
return the same result shape, so the Godot client can't tell them apart.
"""

from __future__ import annotations

import contextlib
import math
import threading
import time
import uuid
from pathlib import Path
from typing import Any, Callable, Iterator

import numpy as np

from elicito_app_server.case_studies import CASE_STUDIES
from elicito_app_server.settings import validate_settings
from elicito_app_server.validation import density, validate_expert, validate_panel

ProgressFn = Callable[[dict[str, Any]], None]


class _ProgressShim:
    """Stand-in for elicito's internal ``ProgressTable``.

    elicito has no public progress callback. Its optimizers create a
    ``ProgressTable`` and call ``update(advance, loss=...)`` once per
    generation, so we swap that class for this shim while a fit runs and
    forward each update to the client. This touches private API: if a
    future elicito version renames it, ``_hook_progress`` silently does
    nothing and the client falls back to the heartbeat.
    """

    callback: ProgressFn | None = None
    # A panel fit with an estimated spread trains twice: a warm-up run that
    # measures how much the experts disagree, then the real fit. The first
    # `warmup` training runs are reported as stage "Warm-up", without loss.
    warmup = 0
    _runs = 0

    def __init__(self, description: str, total: int, disable: bool = False, **fields: Any):
        cls = type(self)
        self.stage = description
        self.phase = 1
        if description == "Training":
            self.phase = min(cls._runs + 1, cls.warmup + 1)
            if cls._runs < cls.warmup:
                self.stage = "Warm-up"
            cls._runs += 1
        self.total = max(int(total), 1)
        self.done = 0
        self._last_sent = -1.0
        self._emit(fields)

    def update(self, advance: int = 1, **fields: Any) -> None:
        self.done = min(self.done + int(advance), self.total)
        self._emit(fields)

    def close(self) -> None:
        self.done = self.total
        self._emit({}, force=True)

    def _emit(self, fields: dict[str, Any], force: bool = False) -> None:
        cb = type(self).callback
        if cb is None:
            return
        frac = self.done / self.total
        # throttle: at most ~100 messages per stage
        if not force and frac - self._last_sent < 0.01 and self.done < self.total:
            return
        self._last_sent = frac
        loss = fields.get("loss")
        if self.stage != "Training" or loss is None or not math.isfinite(float(loss)):
            loss = None
        cb(
            dict(
                type="progress",
                stage=self.stage,
                phase=self.phase,
                phases=type(self).warmup + 1,
                done=self.done,
                total=self.total,
                loss=None if loss is None else float(loss),
            )
        )


EXPERT_REPLAY_N = 12  # simulated trials per expert in a panel's replay

_FIT_LOCK = threading.Lock()  # the hook is global, so fits run one at a time


@contextlib.contextmanager
def _hook_progress(callback: ProgressFn, warmup: int = 0) -> Iterator[None]:
    patched: list[tuple[Any, Any]] = []
    try:
        import elicito.initializers.sampling as sampling
        import elicito.optimizers.cmaes as cmaes
        import elicito.optimizers.sgd as sgd

        for module in (sampling, cmaes, sgd):
            if hasattr(module, "ProgressTable"):
                patched.append((module, module.ProgressTable))
                module.ProgressTable = _ProgressShim
    except ImportError:
        pass
    _ProgressShim.callback = callback
    _ProgressShim.warmup = warmup
    _ProgressShim._runs = 0
    try:
        yield
    finally:
        _ProgressShim.callback = None
        for module, original in patched:
            module.ProgressTable = original


def _uniform(bounds: dict[str, Any], n: int, rng: np.random.Generator) -> dict[str, np.ndarray]:
    """n draws per parameter from Uniform(lower, upper)"""
    return {p: rng.uniform(lo, hi, size=n) for p, (lo, hi) in bounds.items()}


def _case(case_id: str) -> Any:
    if case_id not in CASE_STUDIES:
        raise ValueError(f"unknown case study '{case_id}'")
    return CASE_STUDIES[case_id]


class ElicitoBackend:
    name = "elicito"

    def __init__(self, results_dir: Path):
        self.results_dir = results_dir
        self.results_dir.mkdir(parents=True, exist_ok=True)

    def fit(
        self,
        case_id: str,
        expert: dict[str, Any],
        replay_n: int = 24,
        on_progress: ProgressFn | None = None,
        settings: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        case = _case(case_id)
        answers = validate_expert(case, expert)
        settings = validate_settings(settings)
        on_progress = on_progress or (lambda _msg: None)
        started = time.time()
        with _FIT_LOCK, _hook_progress(on_progress):
            eliobj = case.build(settings)
            fit = eliobj.fit(answers)
        best = fit.best()
        hyper = fit.hyperparameters()
        loss = fit.results["history_stats/loss"]["total_loss"].isel(replication=best)
        hyper_hist = fit.results["history_stats/hyperparameter"].to_dataset().isel(replication=best)
        summary = fit.sample()["elicited_summary"].to_dataset().isel(replication=best)
        simulated = {
            name: [float(v) for v in summary[name].values.mean(axis=0)] for name in case.targets
        }
        fit_id = time.strftime("%Y%m%d-%H%M%S-") + uuid.uuid4().hex[:6]
        saved = self.results_dir / f"{case_id}-{fit_id}"
        eliobj.save(file=str(saved), overwrite=True)
        return dict(
            type="result",
            backend=self.name,
            case_study=case_id,
            fit_id=fit_id,
            expert=answers,
            hyperparameters={k: float(v) for k, v in hyper.items()},
            priors=case.bounds(hyper),
            loss_history=[float(v) for v in np.asarray(loss.values)],
            bound_history=case.bound_history({k: hyper_hist[k].values for k in case.hyper_names()}),
            simulated_quantiles=simulated,
            probs={name: list(p) for name, p in case.targets.items()},
            replay=case.replay(fit, replay_n, seed=int(time.time()) % 100_000),
            saved_eliobj=str(saved) + ".pkl",
            settings=settings,
            elapsed=time.time() - started,
        )

    def fit_panel(
        self,
        case_id: str,
        experts: dict[str, Any],
        replay_n: int = 24,
        on_progress: ProgressFn | None = None,
        settings: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Fit a panel with partial pooling: every hyperparameter may differ by expert"""
        import elicito as el

        case = _case(case_id)
        answers = validate_panel(case, experts)
        settings = validate_settings(settings)
        on_progress = on_progress or (lambda _msg: None)
        started = time.time()
        # with no fixed spread, elicito first runs a warm-up fit to estimate it
        warmup = 1 if settings["tau"] is None else 0
        with _FIT_LOCK, _hook_progress(on_progress, warmup):
            eliobj = case.build(settings)
            eliobj.settings["pool"] = el.partial(over=case.hyper_names(), tau=settings["tau"])
            panel = eliobj.fit(answers)
        joint = panel.joint
        best = joint.best()
        loss = joint.results["history_stats/loss"]["total_loss"].isel(replication=best)
        diagnostics = _panel_diagnostics(case, panel, list(answers), best)
        pop = panel.population_prior(num_samples=20_000, seed=int(time.time()) % 100_000)
        fit_id = time.strftime("%Y%m%d-%H%M%S-") + uuid.uuid4().hex[:6]
        saved = self.results_dir / f"{case_id}-panel-{fit_id}"
        eliobj.save(file=str(saved), overwrite=True)
        return _panel_result(
            case,
            self.name,
            case_id,
            answers,
            {name: case.bounds(panel.hyperparameters(name)) for name in answers},
            case.bounds(panel.hyperparameters()),
            {p: np.asarray(pop[p].values) for p in case.parameters},
            panel.tau or {},
            [float(v) for v in np.asarray(loss.values)],
            replay_n,
            str(saved) + ".pkl",
            started,
            settings,
            diagnostics,
        )


def _panel_diagnostics(case: Any, panel: Any, names: list[str], best: int) -> dict[str, Any]:
    """How each expert's hyperparameters moved, and what each expert's prior implies"""
    hist = panel.joint.results["history_stats/hyperparameter"].to_dataset().isel(replication=best)
    shared = {k: np.asarray(hist[k].values, dtype=np.float64) for k in case.hyper_names()}
    expert_hist = {}
    for e, name in enumerate(names):
        values = {}
        for k, glob in shared.items():
            offset_name = f"{k}__e{e}"
            if panel.tau and k in panel.tau and offset_name in hist:
                # an expert's value: the shared value, moved by its offset on the unconstrained scale
                hyp = panel._hypers[k]
                offset = np.asarray(hist[offset_name].values, dtype=np.float64)
                values[k] = np.asarray(hyp["constraint"](hyp["unconstrain"](glob) + offset), dtype=np.float64)
            else:
                values[k] = glob
        expert_hist[name] = case.bound_history(values)
    summary = panel.joint.sample()["elicited_summary"].to_dataset().isel(replication=best)
    simulated = {
        name: {
            t: [float(v) for v in np.asarray(summary[f"{t}__e{e}"].values).mean(axis=0)]
            for t in case.targets
        }
        for e, name in enumerate(names)
    }
    return dict(
        expert_bound_history=expert_hist,
        panel_bound_history=case.bound_history(shared),
        expert_simulated=simulated,
    )


def _panel_result(
    case: Any,
    backend: str,
    case_id: str,
    experts: dict[str, Any],
    expert_priors: dict[str, dict[str, list[float]]],
    panel_priors: dict[str, list[float]],
    population: dict[str, np.ndarray],
    tau: dict[str, float],
    loss_history: list[float],
    replay_n: int,
    saved: str | None,
    started: float,
    settings: dict[str, Any],
    diagnostics: dict[str, Any],
) -> dict[str, Any]:
    """The message for a fitted panel; the same for both backends"""
    seed = int(time.time()) % 100_000
    upper = {
        p: float(max(np.quantile(population[p], 0.995), *(b[p][1] for b in expert_priors.values())) * 1.05)
        for p in case.parameters
    }
    rng = np.random.default_rng(seed)
    idx = rng.choice(len(population[case.parameters[0]]), replay_n, replace=False)
    # a few trials from each expert's own prior, so the replay can show one row per expert
    expert_replays = {}
    for k, (name, bounds) in enumerate(expert_priors.items()):
        samples = {p: rng.uniform(*bounds[p], size=EXPERT_REPLAY_N) for p in case.parameters}
        expert_replays[name] = case.simulate_draws(samples, seed + 1 + k)
    return dict(
        type="result",
        panel=True,
        backend=backend,
        case_study=case_id,
        experts=list(experts),
        answers=experts,
        expert_priors=expert_priors,
        panel_priors=panel_priors,
        population={p: density(population[p], upper[p]) for p in case.parameters},
        tau={k: float(v) for k, v in tau.items()},
        loss_history=loss_history,
        probs={name: list(p) for name, p in case.targets.items()},
        **diagnostics,
        replay=case.simulate_draws({p: population[p][idx] for p in case.parameters}, seed),
        expert_replays=expert_replays,
        saved_eliobj=saved,
        settings=settings,
        elapsed=time.time() - started,
    )


class MockBackend:
    """Fast stand-in: the case study guesses Uniform bounds from the answers.

    Good enough to develop and demo the Godot UI without TensorFlow.
    The numbers are NOT an elicito fit.
    """

    name = "mock"

    def __init__(self, delay: float = 1.5):
        self.delay = delay

    def fit(
        self,
        case_id: str,
        expert: dict[str, Any],
        replay_n: int = 24,
        on_progress: ProgressFn | None = None,
        settings: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        case = _case(case_id)
        answers = validate_expert(case, expert)
        settings = validate_settings(settings)  # checked, then ignored by the mock
        on_progress = on_progress or (lambda _msg: None)
        started = time.time()

        loss_history = self._fake_training(on_progress, phase=1, phases=1)

        priors = case.mock_priors(answers)
        # a made-up path from a wide start to the final bounds
        k = np.exp(-np.arange(len(loss_history)) / 8.0)
        fake_hist = {}
        for p, (lo, hi) in priors.items():
            fake_hist[f"{p}_lower"] = lo * (1 - 0.8 * k)
            fake_hist[f"{p}_upper"] = hi * (1 + 0.8 * k)

        rng = np.random.default_rng(int(time.time()))
        replay = case.simulate_draws(_uniform(priors, replay_n, rng), seed=int(time.time()))
        sims = case.simulate_draws(_uniform(priors, 2000, np.random.default_rng(1)), seed=1)
        simulated = {
            t: [float(v) for v in np.quantile([s[t] for s in sims], probs)]
            for t, probs in case.targets.items()
        }
        return dict(
            type="result",
            backend=self.name,
            case_study=case_id,
            fit_id="mock-" + uuid.uuid4().hex[:6],
            expert=answers,
            hyperparameters={
                f"{p}_{side}": float(v)
                for p, bounds in priors.items()
                for side, v in zip(("lower", "upper"), bounds)
            },
            priors={p: [float(lo), float(hi)] for p, (lo, hi) in priors.items()},
            loss_history=loss_history,
            bound_history=case.bound_history(fake_hist),
            simulated_quantiles=simulated,
            probs={name: list(p) for name, p in case.targets.items()},
            replay=replay,
            saved_eliobj=None,
            settings=settings,
            elapsed=time.time() - started,
        )

    def fit_panel(
        self,
        case_id: str,
        experts: dict[str, Any],
        replay_n: int = 24,
        on_progress: ProgressFn | None = None,
        settings: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        """Mock panel: one mock fit per expert, the population mixes them"""
        case = _case(case_id)
        answers = validate_panel(case, experts)
        settings = validate_settings(settings)
        started = time.time()
        def warmup_progress(msg: dict[str, Any]) -> None:
            on_progress({**msg, "stage": "Warm-up", "loss": None, "phase": 1, "phases": 2})

        delay, self.delay = self.delay, self.delay / max(len(answers), 1)
        try:
            fits = {name: self.fit(case_id, a, 1, warmup_progress) for name, a in answers.items()}
        finally:
            self.delay = delay
        loss_history = self._fake_training(on_progress, phase=2, phases=2)
        rng = np.random.default_rng(1)
        population = {}
        for p in case.parameters:
            pick = rng.integers(0, len(fits), 20_000)
            bounds = np.array([fits[n]["priors"][p] for n in answers])[pick]
            population[p] = rng.uniform(bounds[:, 0], bounds[:, 1])
        panel_priors = {
            p: [float(np.mean([f["priors"][p][i] for f in fits.values()])) for i in (0, 1)]
            for p in case.parameters
        }
        return _panel_result(
            case,
            self.name,
            case_id,
            answers,
            {name: f["priors"] for name, f in fits.items()},
            panel_priors,
            population,
            dict.fromkeys(case.hyper_names(), 0.5),
            loss_history,
            replay_n,
            None,
            started,
            settings,
            dict(
                expert_bound_history={name: f["bound_history"] for name, f in fits.items()},
                panel_bound_history=fits[next(iter(fits))]["bound_history"],
                expert_simulated={name: f["simulated_quantiles"] for name, f in fits.items()},
            ),
        )

    def _fake_training(self, on_progress: ProgressFn, phase: int, phases: int) -> list[float]:
        steps = 40
        loss_history = []
        for i in range(steps):
            loss = 2.0 * math.exp(-i / 8.0) + 0.05
            loss_history.append(loss)
            on_progress(dict(type="progress", stage="Training", phase=phase, phases=phases, done=i + 1, total=steps, loss=loss))
            time.sleep(self.delay / steps)
        return loss_history
