#!/bin/bash
# build.sh — Compile the SpectralRH paper
# Usage: cd proofs/SpectralRH/paper && bash build.sh

set -e

echo "═══════════════════════════════════════"
echo " Building SpectralRH Paper"
echo "═══════════════════════════════════════"

# First pass: generate .aux and .bbl requests
echo "[1/4] pdflatex (first pass)..."
pdflatex -interaction=nonstopmode main.tex > /dev/null 2>&1 || true

# BibTeX pass: resolve citations
echo "[2/4] bibtex..."
bibtex main > /dev/null 2>&1 || true

# Second pass: incorporate bibliography
echo "[3/4] pdflatex (second pass)..."
pdflatex -interaction=nonstopmode main.tex > /dev/null 2>&1 || true

# Third pass: resolve cross-references
echo "[4/4] pdflatex (final pass)..."
pdflatex -interaction=nonstopmode main.tex > /dev/null 2>&1 || true

# Check for output
if [ -f main.pdf ]; then
    PAGES=$(pdfinfo main.pdf 2>/dev/null | grep "Pages:" | awk '{print $2}' || echo "?")
    SIZE=$(ls -lh main.pdf | awk '{print $5}')
    echo ""
    echo "✅ main.pdf generated successfully"
    echo "   Pages: ${PAGES}"
    echo "   Size:  ${SIZE}"
    echo ""
    echo "   Open with: open main.pdf"
else
    echo ""
    echo "❌ Build failed. Check main.log for details."
    exit 1
fi
