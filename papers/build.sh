#!/bin/bash
# Build all Cathedral papers
# Usage: ./build.sh [paper-name]  (without .tex)
# Examples:
#   ./build.sh                    # build all papers
#   ./build.sh cathedral-physics  # build one paper

set -euo pipefail
cd "$(dirname "$0")"

PAPERS=(
  cathedral
  overview
  cathedral-physics
  cathedral-math
  cathedral-public
  cathedral-cs
  cathedral-security
  cathedral-philosophy
  cathedral-ai
  cathedral-lean
  cathedral-foundations
  cathedral-fun
  cathedral-engineering
  cathedral-futures
  cathedral-energy
  cathedral-dualuse
  cathedral-politics
  cathedral-education
  cathedral-history
  cathedral-invitation
  cathedral-press
  cathedral-legal
  cathedral-letter
)

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m'

build_paper() {
  local name="$1"
  if [ ! -f "${name}.tex" ]; then
    echo -e "${RED}✗ ${name}.tex not found${NC}"
    return 1
  fi

  # Run twice for cross-references / TOC
  for pass in 1 2; do
    if ! pdflatex -interaction=nonstopmode "${name}.tex" > /dev/null 2>&1; then
      echo -e "${RED}✗ ${name}.tex (pass ${pass}) — errors:${NC}"
      pdflatex -interaction=nonstopmode "${name}.tex" 2>&1 | grep "^!" | head -5
      return 1
    fi
  done

  local pages
  pages=$(pdflatex -interaction=nonstopmode "${name}.tex" 2>&1 \
    | grep "Output written" | sed 's/.*(\([0-9]*\) pages.*/\1/')
  local size
  size=$(du -h "${name}.pdf" | cut -f1)

  echo -e "${GREEN}✓ ${name}.pdf${NC}  (${pages} pages, ${size})"
}

if [ $# -gt 0 ]; then
  build_paper "$1"
else
  echo "Building all Cathedral papers..."
  echo ""
  errors=0
  for paper in "${PAPERS[@]}"; do
    build_paper "$paper" || ((errors++))
  done
  echo ""
  if [ $errors -eq 0 ]; then
    echo -e "${GREEN}All papers built successfully.${NC}"
  else
    echo -e "${RED}${errors} paper(s) failed.${NC}"
    exit 1
  fi
fi
