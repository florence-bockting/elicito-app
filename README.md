# elicito app

Interactive case studies for [elicito](https://github.com/florence-bockting/elicito),
a Python package for learning prior distributions from expert knowledge.

Pick a case study from the gallery, answer a few questions about what you
expect to see (as yourself or as a training persona), and elicito turns the
answers into a prior distribution. The app then shows whether the fit
converged, the learned prior, and what that prior implies, for one expert or
for a panel of experts, and how to use the prior to fit the posterior with
PyMC or brms.

| Gallery | Elicitation | Predictions |
|---|---|---|
| ![](docs/gallery.png) | ![](docs/elicitation.png) | ![](docs/predictions.png) |

The app is made with [Godot 4.7](https://godotengine.org). The fits run in
a small Python server that uses elicito.

## Run it

```bash
python -m venv .venv && source .venv/bin/activate
pip install -e ./server    # Python 3.11 to 3.13; installs elicito
elicito-app-server         # leave it running (or: python -m elicito_app_server)
```

Then open `godot/project.godot` in Godot 4.7 and press **F5** (or run an
exported build). The header shows **● elicito server** once the app is
connected.

**Without a server** (and always in the web version) the app uses
**precomputed fits**: real elicito fits, made in advance, of every training
persona and of every panel of personas. Your own answers get the fit of the
closest stored answer, and the app says so. Click **Use precomputed fits**
in the header, or start with `backend=precomputed`.

Start options (after `--` on the command line, or in the page URL of the web
build, e.g. `index.html?case=bart&embed=1`):

| Option | Meaning |
|---|---|
| `case=<id>` | open this case study directly instead of the gallery |
| `embed=1` | no way back to the gallery, and a layout for a narrower page (embedding in the docs) |
| `server=<url>` | the elicito server, default `ws://127.0.0.1:8765/ws` |
| `backend=precomputed` | no server: fits made in advance (the default on the web) |

## Web version

The workflow `.github/workflows/pages.yml` exports the web build
(`godot/export_presets.cfg`, preset "Web": single-threaded, so GitHub Pages
needs no special headers) and publishes it at
<https://florence-bockting.github.io/elicito-app/>. Set **Settings > Pages >
Source** to **GitHub Actions** once. The build is about 12 MB to download
(gzip), mostly the engine.

To build it yourself, install the Godot 4.7 export templates (Editor >
Manage Export Templates) and run

```bash
godot --headless --path godot --export-release "Web" ../build/web/index.html
python -m http.server -d build/web 8000    # then open http://localhost:8000
```

The BART page of the elicito documentation embeds it:

```html
<iframe src="https://florence-bockting.github.io/elicito-app/?case=bart&embed=1"
  width="100%" height="820" loading="lazy" allow="fullscreen; clipboard-write"></iframe>
```

The web build has no system fonts, so the app brings two small font files in
`godot/theme/fonts/` (subsets of DejaVu, see its licence there): symbols the
default font lacks, and a monospaced font for code.

## Repository layout

```
godot/                     the app (Godot project)
  app/                     Main: header, gallery or one case study
  gallery/                 the start screen
  case_study/              CaseStudy, ExpertPersona and TargetSpec resources;
                           the tabs of one case study and how they are wired
  elicitation/             chips, practice round, expert panel, fit progress
  fit/                     Fitted model: Diagnostics, Priors, Predictions
  net/                     ElicitoClient (WebSocket to the server)
  common/                  small shared widgets and the session log
  case_studies/            catalog.tres and one folder per case study
    bart/                  everything specific to the balloon task
  theme/                   app_theme.tres (made by tools/build_theme.gd)
  tests/                   GUT tests: unit/ and integration/
  addons/gut/              GUT 9.7.1, the test framework (MIT licence)
server/                    the Python server (package elicito-app-server)
.github/workflows/         CI for both parts
```

## How the app is built

The code follows the [best practices of the Godot
documentation](https://docs.godotengine.org/en/stable/tutorials/best_practices/index.html):

- **Self-contained scenes.** Each scene works wherever it is placed. What it
  needs from outside is handed in with a `setup(...)` call by its parent.
- **Call down, signal up.** Parents call methods on their children; children
  only emit signals (`fit_finished`, `play_requested`, ...). Siblings never
  talk to each other: `CaseStudyView` wires its tabs together.
- **No autoloads.** `Main` owns what all case studies share (the
  `ElicitoClient` and the training settings) and hands it down.
- **Data in resources.** A case study is a `.tres` file. Shared logic that
  needs no node lives in `static func` helpers (`QuantileMath`, `FitSummary`).
- **Static typing** throughout; files in snake_case, nodes in PascalCase,
  third-party code in `addons/`.

The flow of one fit:

```
ElicitationPage --request--> ElicitoClient --WebSocket--> elicito-app-server
       |                           |                         (elicito)
       |<------ progress, result --+
       |
       +-- fit_finished --> CaseStudyView --show_single--> FitView
                                  |                        |
                                  |      case study's PredictionsView (e.g. balloons)
                                  +--set_source--> NextStepsPage (PyMC / brms code)

ExpertPanelPage (the personas as a panel) fits and shows its results itself,
and reports them to CaseStudyView the same way.
```

## Add a case study

1. **Server:** write `server/src/elicito_app_server/case_studies/<id>.py` with
   a class like `BartCaseStudy` (the elicito model, `build()`, `bounds()`,
   `simulate_draws()`, `replay()`, `mock_priors()`) and register it in
   `case_studies/__init__.py`. Add a reference test like `tests/test_bart.py`
   that checks the model against the case study in the elicito documentation.
2. **App:** make a folder `godot/case_studies/<id>/` with
   - `<id>.tres`, a `CaseStudy` (or a subclass) with the texts, questions
     (`TargetSpec`, named like the server's targets) and personas;
   - personas: a subclass of `ExpertPersona` that implements `simulate()` and
     `traits()`, and one `.tres` per persona;
   - a Predictions scene whose root extends `PredictionsView`;
   - optional, for the "Where to go next" tab: override `posterior_code()`,
     `posterior_languages()` and `placeholder_priors()` (see
     `bart_case_study.gd`);
   - `model.png` (see `godot/tools/latex/render_model.sh`) and `thumbnail.png`.
3. Add the `.tres` to `godot/case_studies/catalog.tres`. The tests in
   `tests/unit/test_case_studies.gd` check every case study in the catalog.
4. Make the precomputed fits for the offline and web version (below).

## Precomputed fits

The fits for the offline mode live in
`godot/case_studies/<id>/precomputed/fits.json`. Remake them when a case
study, its personas or elicito change (the test
`tests/unit/test_precomputed_fits.gd` fails when they no longer match):

```bash
godot --headless --path godot -s res://tools/export_scenarios.gd   # the answers to fit
python server/tools/precompute.py                                  # real elicito, ~5 min
python server/tools/precompute.py --independent-only               # only the panels without pooling
```

Besides the visible personas, `CaseStudy.precompute_personas` lists hidden
experts whose answers are also fitted, so that more of the users' own
answers have a close stored fit.

## Tests

```bash
# app (from the repository root)
godot --headless --path godot --import
godot --headless --path godot -s addons/gut/gut_cmdln.gd -gexit

# server
pip install "./server[test]"
pytest server                  # fast
RUN_ELICITO=1 pytest server    # plus real elicito fits (a few minutes)
```

In the Godot editor, the GUT panel at the bottom runs the same tests.

## Licence

Apache 2.0, like elicito. GUT (`godot/addons/gut`) is MIT licensed.
