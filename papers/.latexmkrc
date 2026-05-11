# .latexmkrc — Cathedral Paper Suite build configuration
#
# Usage:
#   latexmk                      # build all papers
#   latexmk cathedral-physics    # build one paper
#   latexmk -c                   # clean aux files
#   latexmk -C                   # clean aux + PDF
#   latexmk -pvc cathedral-math  # watch mode (rebuild on save)
#
# This file is read automatically by latexmk when invoked from
# the papers/ directory or any subdirectory.

# ═══════════════════════════════════════════════
# §1. ENGINE CONFIGURATION
# ═══════════════════════════════════════════════

# Use pdflatex (all Cathedral papers are pdflatex-native)
$pdf_mode = 1;              # 1 = pdflatex, 2 = ps2pdf, 3 = lualatex, 4 = xelatex
$pdflatex = 'pdflatex -interaction=nonstopmode -halt-on-error -file-line-error %O %S';

# No external bibliography (all papers use \begin{thebibliography})
$bibtex_use = 0;            # 0 = never run bibtex/biber

# No index
$makeindex = '';             # disable makeindex

# ═══════════════════════════════════════════════
# §2. OUTPUT CONTROL
# ═══════════════════════════════════════════════

# Keep build artifacts in a dedicated subdirectory per paper
# This keeps source directories pristine
$out_dir = 'build';
$aux_dir = 'build';

# Silence — show only errors and warnings
$silent = 1;                 # suppress routine output
$warnings_as_errors = 0;     # don't treat warnings as fatal

# ═══════════════════════════════════════════════
# §3. DEPENDENCY TRACKING
# ═══════════════════════════════════════════════

# Tell latexmk about our shared preamble so it rebuilds
# when cathedral-preamble.sty changes
@default_files = ();         # populated by build.sh or command line

# Watch the shared preamble for changes
# (latexmk auto-detects \usepackage deps, but the relative path
# ../shared/ needs explicit help)
ensure_path('TEXINPUTS', '../shared//');
ensure_path('TEXINPUTS', '../../shared//');

# ═══════════════════════════════════════════════
# §4. CLEANUP RULES
# ═══════════════════════════════════════════════

# Extra files to clean (beyond the defaults)
$clean_ext = 'synctex.gz nav snm vrb fls fdb_latexmk';

# ═══════════════════════════════════════════════
# §5. POST-PROCESSING
# ═══════════════════════════════════════════════

# After successful build, copy PDF back to source directory
# for easy access (the build/ dir is for intermediates)
$success_cmd = 'cp %D %R.pdf 2>/dev/null || true';

# Custom dependency: if the shared preamble changes, rebuild
add_cus_dep('sty', 'pdf', 0, 'sty_to_pdf');
sub sty_to_pdf { return 0; }

# ═══════════════════════════════════════════════
# §6. MAX PASSES
# ═══════════════════════════════════════════════

# Most papers need exactly 2 passes (TOC + refs)
# Set a generous limit for safety
$max_repeat = 5;

# ═══════════════════════════════════════════════
# §7. PREVIEW
# ═══════════════════════════════════════════════

# For -pvc (preview continuously) mode on macOS
$pdf_previewer = 'open -a Preview %S';
$pdf_update_method = 0;     # let the previewer detect file changes
