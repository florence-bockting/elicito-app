"""Fits the app's scenarios with elicito, for the app's offline mode (web)

The web version of the app cannot run elicito, so it answers from fits made
in advance. This script reads the scenarios that the app exported
(godot/case_studies/<id>/precomputed/scenarios.json, written by
godot/tools/export_scenarios.gd), fits each expert and each panel with the
real elicito backend and default training settings, and writes
fits.json next to it.

    pip install ./server
    godot --headless --path godot -s res://tools/export_scenarios.gd
    python server/tools/precompute.py            # all case studies
    python server/tools/precompute.py --case bart

Rerun both steps when a case study, its personas or elicito change; the
app's tests check that fits.json still matches the exported answers.
"""

from __future__ import annotations

import argparse
import importlib.metadata
import json
import tempfile
import time
from pathlib import Path
from typing import Any

from elicito_app_server.backends import ElicitoBackend
from elicito_app_server.settings import validate_settings

CASE_STUDIES_DIR = Path(__file__).resolve().parents[2] / "godot" / "case_studies"


def precompute(scenarios: dict[str, Any], backend: Any, log: Any = print) -> dict[str, Any]:
    """Fits every expert and every panel of one case study's scenarios"""
    case_id = scenarios["case_study"]
    replay_n = int(scenarios.get("replay_n", 24))
    answers = {s["name"]: s["answers"] for s in scenarios["single"]}
    out: dict[str, Any] = {
        "case_study": case_id,
        "elicito_version": importlib.metadata.version("elicito"),
        "settings": validate_settings({}),
        "made_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "single": [],
        "panels": [],
    }
    for name, expert in answers.items():
        log(f"{case_id}: fitting {name}")
        result = backend.fit(case_id, expert, replay_n=replay_n)
        out["single"].append({"name": name, "answers": expert, "result": _clean(result)})
    for panel in scenarios["panels"]:
        members = panel["members"]
        log(f"{case_id}: fitting the panel {', '.join(members)}")
        result = backend.fit_panel(case_id, {m: answers[m] for m in members}, replay_n=replay_n)
        out["panels"].append({"members": members, "result": _clean(result)})
    return out


def _clean(result: dict[str, Any]) -> dict[str, Any]:
    """Drops what only makes sense on the machine that made the fit"""
    result = dict(result)
    result["saved_eliobj"] = None
    result.pop("request_id", None)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--case", help="only this case study id")
    parser.add_argument("--dir", type=Path, default=CASE_STUDIES_DIR, help="the app's case_studies folder")
    args = parser.parse_args()
    files = sorted(args.dir.glob("*/precomputed/scenarios.json"))
    if args.case:
        files = [f for f in files if f.parent.parent.name == args.case]
    if not files:
        raise SystemExit(f"no scenarios.json under {args.dir}; run godot/tools/export_scenarios.gd first")
    with tempfile.TemporaryDirectory() as tmp:
        backend = ElicitoBackend(Path(tmp))
        for path in files:
            scenarios = json.loads(path.read_text())
            fits = precompute(scenarios, backend)
            target = path.with_name("fits.json")
            target.write_text(json.dumps(fits, separators=(",", ":")) + "\n")
            print(f"wrote {target} ({target.stat().st_size // 1024} kB)")


if __name__ == "__main__":
    main()
