# elicito-app-server

The Python side of [elicito-app](../README.md): a small WebSocket server
that receives the expert's answers from the Godot app, runs the fit with
[elicito](https://github.com/florence-bockting/elicito), and sends back the
fitted prior, diagnostics and simulated trials.

```bash
pip install ./server            # from the repository root
elicito-app-server              # real elicito fits on ws://127.0.0.1:8765/ws
elicito-app-server --mock       # instant fake fits, no TensorFlow needed
```

Fitted elicito objects are saved to `./elicito-app-results` (change with
`--results`).

## Layout

| Path | What it holds |
|---|---|
| `src/elicito_app_server/app.py` | FastAPI app and the WebSocket protocol |
| `src/elicito_app_server/backends.py` | `ElicitoBackend` (real fits) and `MockBackend` |
| `src/elicito_app_server/case_studies/` | one module per case study, registered in `__init__.py` |
| `src/elicito_app_server/settings.py` | training settings the app may send |
| `src/elicito_app_server/validation.py` | checks for answers and panels |
| `tests/` | `pytest`; `RUN_ELICITO=1 pytest` also runs real fits |
| `tools/bart_reference.py` | reference numbers from the elicito docs' BART model |

## Tests

```bash
pip install "./server[test]"
pytest server                   # fast, mock backend
RUN_ELICITO=1 pytest server     # plus real elicito fits (a few minutes)
```

`tests/test_bart.py` checks that the app's BART model gives the same
pumps distribution as the PyMC model in the elicito documentation. When the
case study's model changes there, rerun `python tools/bart_reference.py`
(needs PyMC) and commit the new `tests/data/bart_reference.json`.
