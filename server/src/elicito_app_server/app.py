"""WebSocket bridge between the Godot client and elicito.

Run:
    elicito-app-server         # real elicito fits
    elicito-app-server --mock  # instant fake fits, no TensorFlow needed
(or ``python -m elicito_app_server``)

Protocol (JSON text frames on ws://HOST:PORT/ws):

client -> server
    {"type": "ping"}
    {"type": "fit", "request_id": "...", "case_study": "bart",
     "expert": {"pumps": [q10, q25, q50, q75, q90], "omega": [...]},
     "replay_n": 24}
    {"type": "fit_panel", "request_id": "...", "case_study": "bart",
     "experts": {"Anna": {"pumps": [...], "omega": [...]}, "Ben": {...}},
     "replay_n": 24}          # partial pooling, at least two experts
    Both may carry "settings": {"epochs": 400, "seed": 1, ...}; see
    case_studies.SETTINGS for the names, defaults and ranges.

server -> client
    {"type": "hello", "backend": "elicito", "case_studies": ["bart"], "version": 3}
    {"type": "pong"}
    {"type": "progress", "request_id", "stage", "phase", "phases", "done", "total", "loss"}
        stage is "Warm-up" (no loss) or "Training"; phase counts the runs
    {"type": "heartbeat", "request_id", "elapsed"}
    {"type": "result", "request_id", ...see backends.py...}   # "panel": true for a panel
    {"type": "error", "request_id", "message"}
"""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
import time
from pathlib import Path
from typing import Any

from fastapi import FastAPI, WebSocket, WebSocketDisconnect

from elicito_app_server import __version__
from elicito_app_server.backends import ElicitoBackend, MockBackend
from elicito_app_server.case_studies import CASE_STUDIES

log = logging.getLogger("elicito-app-server")

# Bumped whenever the protocol gains something the client relies on, so an
# old server that is still running can be recognised (1: fits, 2: panels,
# 3: training settings, 4: warm-up phase and fit diagnostics, 5: panels
# with independent fits, "pooling" in fit_panel).
PROTOCOL_VERSION = 5

# Fitted elicito objects are saved here (override with --results).
DEFAULT_RESULTS = Path.cwd() / "elicito-app-results"

app = FastAPI(title="elicito app server", version=__version__)
app.state.backend = None  # set in main() or by tests


def _backend() -> Any:
    if app.state.backend is None:
        app.state.backend = ElicitoBackend(DEFAULT_RESULTS)
    return app.state.backend


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "backend": _backend().name,
        "case_studies": list(CASE_STUDIES),
        "version": PROTOCOL_VERSION,
    }


async def _run_fit(ws: WebSocket, msg: dict[str, Any]) -> None:
    request_id = msg.get("request_id")
    loop = asyncio.get_running_loop()
    queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue()

    def on_progress(update: dict[str, Any]) -> None:  # called from the fit thread
        loop.call_soon_threadsafe(queue.put_nowait, update)

    is_panel = msg.get("type") == "fit_panel"
    args = [
        msg.get("case_study", "bart"),
        msg.get("experts" if is_panel else "expert", {}),
        int(msg.get("replay_n", 24)),
        on_progress,
        msg.get("settings"),
    ]
    if is_panel:
        args.append(msg.get("pooling", "partial"))
    job = asyncio.create_task(
        asyncio.to_thread(_backend().fit_panel if is_panel else _backend().fit, *args)
    )
    started = time.time()
    while not job.done():
        try:
            update = await asyncio.wait_for(queue.get(), timeout=1.0)
        except asyncio.TimeoutError:
            update = {"type": "heartbeat", "elapsed": time.time() - started}
        await ws.send_json({**update, "request_id": request_id})
    while not queue.empty():  # flush the last progress messages
        await ws.send_json({**queue.get_nowait(), "request_id": request_id})
    try:
        result = job.result()
    except ValueError as exc:  # bad answers: tell the expert what is wrong
        await ws.send_json({"type": "error", "request_id": request_id, "message": str(exc)})
        return
    except Exception as exc:  # noqa: BLE001 - report anything else, keep serving
        log.exception("fit failed")
        await ws.send_json(
            {"type": "error", "request_id": request_id, "message": f"fit failed: {exc}"}
        )
        return
    await ws.send_json({**result, "request_id": request_id})


@app.websocket("/ws")
async def websocket(ws: WebSocket) -> None:
    await ws.accept()
    await ws.send_json(
        {
            "type": "hello",
            "backend": _backend().name,
            "case_studies": list(CASE_STUDIES),
            "version": PROTOCOL_VERSION,
        }
    )
    try:
        while True:
            raw = await ws.receive_text()
            try:
                msg = json.loads(raw)
            except json.JSONDecodeError:
                await ws.send_json({"type": "error", "message": "invalid JSON"})
                continue
            kind = msg.get("type")
            if kind == "ping":
                await ws.send_json({"type": "pong"})
            elif kind in ("fit", "fit_panel"):
                await _run_fit(ws, msg)
            else:
                await ws.send_json({"type": "error", "message": f"unknown type '{kind}'"})
    except WebSocketDisconnect:
        return


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8765)
    parser.add_argument("--mock", action="store_true", help="fake fits, no TensorFlow")
    parser.add_argument(
        "--results", type=Path, default=DEFAULT_RESULTS, help="folder for the fitted elicito objects"
    )
    parser.add_argument("--version", action="version", version=__version__)
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO)
    app.state.backend = MockBackend() if args.mock else ElicitoBackend(args.results)

    import uvicorn

    uvicorn.run(app, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
