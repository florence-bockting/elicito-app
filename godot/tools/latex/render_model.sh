#!/usr/bin/env bash
# Renders a case study's model (TikZ graphical model + equations) to the
# PNG that the app shows on the "Statistical model" tab:
#   <case>_model.tex -> res://case_studies/<case>/model.png
#
#   cd godot/tools/latex && ./render_model.sh bart
#
# Needs pdflatex with the tikz, standalone and amsmath packages, plus
# pdftoppm (from poppler-utils). With TinyTeX, missing packages install via:
#   tlmgr install standalone pgf xcolor
set -euo pipefail
cd "$(dirname "$0")"

CASE="${1:-bart}"
NAME="${CASE}_model"
OUT="../../case_studies/${CASE}/model.png"
DPI="${DPI:-240}"  # rendered larger than shown in the app, for sharp text
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

if ! pdflatex -interaction=nonstopmode -halt-on-error -output-directory "$BUILD" "${NAME}.tex" > "$BUILD/log.txt"; then
  grep -A3 '^!' "$BUILD/${NAME}.log" || tail -20 "$BUILD/log.txt"
  echo "LaTeX failed; see the error above." >&2
  exit 1
fi
pdftoppm -png -r "$DPI" -singlefile "$BUILD/${NAME}.pdf" "${OUT%.png}"
echo "wrote ${OUT}"
