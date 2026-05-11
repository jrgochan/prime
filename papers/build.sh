#!/bin/bash
# build.sh — Cathedral Paper Suite build script (latexmk wrapper)
#
# Usage:
#   ./build.sh                       Build all 15 papers
#   ./build.sh cathedral-physics     Build one paper (auto-finds directory)
#   ./build.sh science/              Build all papers in a group
#   ./build.sh clean                 Remove all build artifacts
#   ./build.sh watch cathedral-math  Watch mode (rebuild on save, open preview)
#
# Requires: latexmk (install via: sudo tlmgr install latexmk)

set -euo pipefail
cd "$(dirname "$0")"

PAPER_GROUPS="core working_drafts/science working_drafts/applications working_drafts/humanities working_drafts/public working_drafts/policy"

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

# ── Preflight ────────────────────────────────────────────
check_latexmk() {
  if ! command -v latexmk &>/dev/null; then
    echo "${RED}✗ latexmk not found${NC}"
    echo ""
    echo "  Install it with:  ${BOLD}sudo tlmgr install latexmk${NC}"
    echo "  Or via Homebrew:  ${BOLD}brew install --cask mactex${NC} (includes latexmk)"
    echo ""
    exit 1
  fi
}

# ── Build a single paper ─────────────────────────────────
build_paper() {
  local texpath="$1"
  local dir name

  if [ ! -f "$texpath" ]; then
    echo "${RED}✗ $texpath not found${NC}"
    return 1
  fi

  dir=$(dirname "$texpath")
  name=$(basename "$texpath" .tex)

  # Run latexmk from the paper's directory (quiet mode, explicit rc path)
  if latexmk -pdf -cd -quiet -r "$(pwd)/.latexmkrc" "$texpath" >/dev/null 2>&1; then
    # Extract page count from the build log
    local logfile="$dir/build/${name}.log"
    local pages="?"
    if [ -f "$logfile" ]; then
      pages=$(grep "Output written" "$logfile" 2>/dev/null | sed 's/.* (\([0-9]*\) pages.*/\1/' | tail -1)
    fi
    local size
    size=$(du -h "$dir/${name}.pdf" 2>/dev/null | cut -f1 || echo "?")
    echo "${GREEN}✓ $texpath${NC}  (${pages:-?} pages, ${size})"
  else
    echo "${RED}✗ $texpath — build failed${NC}"
    # Show the relevant errors from the log
    local logfile="$dir/build/${name}.log"
    if [ -f "$logfile" ]; then
      grep "^!" "$logfile" | head -5 | sed 's/^/  /'
    fi
    return 1
  fi
}

# ── Find a paper by name ─────────────────────────────────
find_paper() {
  local query="$1"

  # Try exact path
  if [ -f "$query" ]; then echo "$query"; return 0; fi
  if [ -f "${query}.tex" ]; then echo "${query}.tex"; return 0; fi

  # Search all groups
  for group in $PAPER_GROUPS; do
    if [ -f "$group/$query" ]; then echo "$group/$query"; return 0; fi
    if [ -f "$group/${query}.tex" ]; then echo "$group/${query}.tex"; return 0; fi
  done

  return 1
}

# ── Commands ──────────────────────────────────────────────

cmd_clean() {
  echo "Cleaning build artifacts..."
  for group in $PAPER_GROUPS; do
    rm -rf "$group/build" 2>/dev/null || true
  done
  # Also clean any stray aux files from pre-latexmk era
  find . \( -name '*.aux' -o -name '*.log' -o -name '*.toc' -o -name '*.out' \
            -o -name '*.synctex.gz' -o -name '*.fls' -o -name '*.fdb_latexmk' \) \
       -not -path '*/build/*' -delete 2>/dev/null || true
  echo "${GREEN}✓ Clean${NC}"
}

cmd_watch() {
  local target="$1"
  local path
  path=$(find_paper "$target") || {
    echo "${RED}✗ Cannot find paper: $target${NC}"
    exit 1
  }
  echo "${CYAN}👁  Watching ${path} (Ctrl+C to stop)${NC}"
  latexmk -pdf -pvc -cd -r "$(pwd)/.latexmkrc" "$path"
}

cmd_build_group() {
  local dir="$1"
  local errors=0
  local count=0

  echo -e "${YELLOW}── ${dir} ──${NC}"
  for tex in "$dir"/*.tex; do
    [ -f "$tex" ] || continue
    build_paper "$tex" || errors=$((errors + 1))
    count=$((count + 1))
  done
  echo ""
  return $errors
}

cmd_build_all() {
  echo "${BOLD}Building all Cathedral papers...${NC}"
  echo ""
  local errors=0
  local total=0

  for group in $PAPER_GROUPS; do
    local group_errors=0
    cmd_build_group "$group" || group_errors=$?
    errors=$((errors + group_errors))
    total=$((total + $(ls "$group"/*.tex 2>/dev/null | wc -l)))
  done

  if [ $errors -eq 0 ]; then
    echo "${GREEN}${BOLD}All $total papers built successfully.${NC}"
  else
    echo "${RED}${BOLD}$errors/$total paper(s) failed.${NC}"
    exit 1
  fi
}

cmd_build_one() {
  local target="$1"
  local path
  path=$(find_paper "$target") || {
    echo "${RED}✗ Cannot find paper: $target${NC}"
    echo "  Searched: $PAPER_GROUPS"
    exit 1
  }
  build_paper "$path"
}

# ── Main ──────────────────────────────────────────────────

check_latexmk

case "${1:-}" in
  "")
    cmd_build_all
    ;;
  clean)
    cmd_clean
    ;;
  watch)
    if [ -z "${2:-}" ]; then
      echo "${RED}Usage: ./build.sh watch <paper-name>${NC}"
      exit 1
    fi
    cmd_watch "$2"
    ;;
  *)
    target="$1"
    if [ -d "$target" ]; then
      cmd_build_group "${target%/}"
    else
      cmd_build_one "$target"
    fi
    ;;
esac
