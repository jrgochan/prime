#!/bin/sh
# ============================================
# The Cathedral — Environment Manager
# POSIX-compliant dependency detection & setup
# ============================================
#
# Usage:
#   scripts/env.sh check            Full dependency report
#   scripts/env.sh setup            Interactive installer
#   scripts/env.sh setup-lean       Install Lean 4 only
#   scripts/env.sh setup-rust       Install Rust only
#   scripts/env.sh setup-node       Install Node.js only
#   scripts/env.sh setup-python     Install Python 3 only
#   scripts/env.sh setup-latex      Install LaTeX only
#   scripts/env.sh setup-gmp        Install GMP + MPFR only
#   scripts/env.sh require <tool>   Exit 1 if tool missing (for Makefile)

# ── Colors (only if terminal supports them) ─────────────

if [ -t 1 ] && command -v tput >/dev/null 2>&1; then
    GREEN=$(tput setaf 2)
    RED=$(tput setaf 1)
    YELLOW=$(tput setaf 3)
    CYAN=$(tput setaf 6)
    BOLD=$(tput bold)
    RESET=$(tput sgr0)
else
    GREEN="" RED="" YELLOW="" CYAN="" BOLD="" RESET=""
fi

# ── OS Detection ────────────────────────────────────────

detect_os() {
    case "$(uname -s)" in
        Darwin*)
            OS="macos"
            if command -v brew >/dev/null 2>&1; then
                PKG="brew"
            else
                PKG="none"
            fi
            ;;
        Linux*)
            OS="linux"
            if command -v apt-get >/dev/null 2>&1; then
                PKG="apt"
            elif command -v dnf >/dev/null 2>&1; then
                PKG="dnf"
            elif command -v pacman >/dev/null 2>&1; then
                PKG="pacman"
            else
                PKG="none"
            fi
            ;;
        *)
            OS="unknown"
            PKG="none"
            ;;
    esac
}

# ── Dependency Checks ──────────────────────────────────

FOUND=0
TOTAL=0

check_cmd() {
    name="$1"
    display="$2"
    TOTAL=$((TOTAL + 1))
    if command -v "$name" >/dev/null 2>&1; then
        version=$("$name" --version 2>/dev/null | head -1 | sed 's/.*[Vv]ersion[: ]*//' | head -c 30)
        printf "    ${GREEN}✓${RESET} %-16s %s\n" "$display" "$version"
        FOUND=$((FOUND + 1))
        return 0
    else
        printf "    ${RED}✗${RESET} %-16s ${RED}not found${RESET}\n" "$display"
        return 1
    fi
}

check_lib_macos() {
    name="$1"
    display="$2"
    TOTAL=$((TOTAL + 1))

    # Check Homebrew prefix
    prefix=""
    if command -v brew >/dev/null 2>&1; then
        prefix=$(brew --prefix 2>/dev/null)
    fi

    if [ -n "$prefix" ] && [ -f "$prefix/lib/lib${name}.dylib" ]; then
        printf "    ${GREEN}✓${RESET} %-16s %s/lib/lib%s.dylib\n" "$display" "$prefix" "$name"
        FOUND=$((FOUND + 1))
        return 0
    elif [ -f "/usr/local/lib/lib${name}.dylib" ] || [ -f "/opt/homebrew/lib/lib${name}.dylib" ]; then
        printf "    ${GREEN}✓${RESET} %-16s found\n" "$display"
        FOUND=$((FOUND + 1))
        return 0
    else
        printf "    ${RED}✗${RESET} %-16s ${RED}not found${RESET}\n" "$display"
        return 1
    fi
}

check_lib_linux() {
    name="$1"
    display="$2"
    TOTAL=$((TOTAL + 1))

    if ldconfig -p 2>/dev/null | grep -q "lib${name}\\.so"; then
        printf "    ${GREEN}✓${RESET} %-16s found\n" "$display"
        FOUND=$((FOUND + 1))
        return 0
    elif [ -f "/usr/lib/lib${name}.so" ] || [ -f "/usr/lib64/lib${name}.so" ]; then
        printf "    ${GREEN}✓${RESET} %-16s found\n" "$display"
        FOUND=$((FOUND + 1))
        return 0
    elif pkg-config --exists "$name" 2>/dev/null; then
        printf "    ${GREEN}✓${RESET} %-16s found (pkg-config)\n" "$display"
        FOUND=$((FOUND + 1))
        return 0
    else
        printf "    ${RED}✗${RESET} %-16s ${RED}not found${RESET}\n" "$display"
        return 1
    fi
}

check_lib() {
    if [ "$OS" = "macos" ]; then
        check_lib_macos "$1" "$2"
    else
        check_lib_linux "$1" "$2"
    fi
}

# ── Install Helpers ─────────────────────────────────────

confirm() {
    printf "  %s [y/N]: " "$1"
    read -r answer
    case "$answer" in
        [Yy]*) return 0 ;;
        *) return 1 ;;
    esac
}

install_lean() {
    echo ""
    echo "  ${BOLD}Installing Lean 4 via elan...${RESET}"
    if command -v elan >/dev/null 2>&1; then
        echo "  elan already installed. Updating..."
        elan self update 2>/dev/null || true
    else
        echo "  Downloading elan installer..."
        curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh -s -- -y --default-toolchain none
        echo "  ${GREEN}✓${RESET} elan installed"
        echo "  ${YELLOW}→ Run 'source ~/.elan/env' or restart your shell${RESET}"
    fi
    echo "  ${YELLOW}→ Run 'cd proofs && lake build' to fetch Mathlib (~5 min first time)${RESET}"
}

install_rust() {
    echo ""
    echo "  ${BOLD}Installing Rust via rustup...${RESET}"
    if command -v rustc >/dev/null 2>&1; then
        echo "  Rust already installed. Updating..."
        rustup update stable 2>/dev/null || true
    else
        echo "  Downloading rustup installer..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        echo "  ${GREEN}✓${RESET} Rust installed"
        echo "  ${YELLOW}→ Run 'source ~/.cargo/env' or restart your shell${RESET}"
    fi
}

install_node() {
    echo ""
    echo "  ${BOLD}Installing Node.js...${RESET}"
    if command -v node >/dev/null 2>&1; then
        echo "  Node.js already installed."
        return 0
    fi
    case "$OS-$PKG" in
        macos-brew)  brew install node ;;
        linux-apt)   echo "  ${YELLOW}→ sudo apt install nodejs npm${RESET}" ;;
        linux-dnf)   echo "  ${YELLOW}→ sudo dnf install nodejs npm${RESET}" ;;
        linux-pacman) echo "  ${YELLOW}→ sudo pacman -S nodejs npm${RESET}" ;;
        *)           echo "  ${YELLOW}→ Visit https://nodejs.org/${RESET}" ;;
    esac
}

install_python() {
    echo ""
    echo "  ${BOLD}Installing Python 3...${RESET}"
    if command -v python3 >/dev/null 2>&1; then
        echo "  Python 3 already installed."
        return 0
    fi
    case "$OS-$PKG" in
        macos-brew)  brew install python3 ;;
        linux-apt)   echo "  ${YELLOW}→ sudo apt install python3 python3-pip${RESET}" ;;
        linux-dnf)   echo "  ${YELLOW}→ sudo dnf install python3 python3-pip${RESET}" ;;
        linux-pacman) echo "  ${YELLOW}→ sudo pacman -S python python-pip${RESET}" ;;
        *)           echo "  ${YELLOW}→ Visit https://python.org/${RESET}" ;;
    esac
}

install_latex() {
    echo ""
    echo "  ${BOLD}Installing LaTeX...${RESET}"
    if command -v pdflatex >/dev/null 2>&1; then
        echo "  pdflatex already installed."
        return 0
    fi
    case "$OS-$PKG" in
        macos-brew)
            echo "  Option 1: brew install --cask mactex-no-gui  (~4GB, full)"
            echo "  Option 2: brew install tectonic              (~50MB, minimal)"
            echo "  ${YELLOW}→ We recommend mactex-no-gui for full compatibility${RESET}"
            ;;
        linux-apt)   echo "  ${YELLOW}→ sudo apt install texlive-latex-base texlive-latex-extra texlive-fonts-recommended${RESET}" ;;
        linux-dnf)   echo "  ${YELLOW}→ sudo dnf install texlive-scheme-basic texlive-collection-latexextra${RESET}" ;;
        linux-pacman) echo "  ${YELLOW}→ sudo pacman -S texlive-core texlive-latexextra${RESET}" ;;
        *)           echo "  ${YELLOW}→ Visit https://tug.org/texlive/${RESET}" ;;
    esac
}

install_gmp() {
    echo ""
    echo "  ${BOLD}Installing GMP + MPFR (for high-precision experiments)...${RESET}"
    case "$OS-$PKG" in
        macos-brew)  brew install gmp mpfr ;;
        linux-apt)   echo "  ${YELLOW}→ sudo apt install libgmp-dev libmpfr-dev${RESET}" ;;
        linux-dnf)   echo "  ${YELLOW}→ sudo dnf install gmp-devel mpfr-devel${RESET}" ;;
        linux-pacman) echo "  ${YELLOW}→ sudo pacman -S gmp mpfr${RESET}" ;;
        *)           echo "  ${YELLOW}→ Install GMP and MPFR from source${RESET}" ;;
    esac
}

# ── Commands ────────────────────────────────────────────

cmd_check() {
    detect_os
    echo ""
    echo "  ${BOLD}🏛️  Cathedral Environment Check${RESET}"
    echo "  ═══════════════════════════════════════════"
    echo ""
    echo "  OS: ${CYAN}${OS}${RESET}  Package manager: ${CYAN}${PKG}${RESET}"
    echo ""

    echo "  ${BOLD}Lean 4${RESET} (for: make build, make verify)"
    check_cmd elan "elan" || true
    check_cmd lean "lean" || true
    check_cmd lake "lake" || true
    echo ""

    echo "  ${BOLD}Rust${RESET} (for: make experiment-*, make spectral-engine)"
    check_cmd rustc "rustc" || true
    check_cmd cargo "cargo" || true
    echo ""

    echo "  ${BOLD}Node.js${RESET} (for: make dashboard)"
    check_cmd node "node" || true
    check_cmd npm "npm" || true
    echo ""

    echo "  ${BOLD}Python${RESET} (for: make sedenion, make axiom-hunt, make dump)"
    check_cmd python3 "python3" || true
    echo ""

    echo "  ${BOLD}LaTeX${RESET} (for: make papers)"
    check_cmd pdflatex "pdflatex" || true
    echo ""

    echo "  ${BOLD}C Libraries${RESET} (for: make experiment-vasyunin)"
    check_lib gmp "gmp" || true
    check_lib mpfr "mpfr" || true
    echo ""

    echo "  ═══════════════════════════════════════════"
    if [ "$FOUND" -eq "$TOTAL" ]; then
        echo "  ${GREEN}${BOLD}Status: ${FOUND}/${TOTAL} dependencies found ✨${RESET}"
        echo "  You are ready to build the Cathedral."
    else
        MISSING=$((TOTAL - FOUND))
        echo "  ${YELLOW}${BOLD}Status: ${FOUND}/${TOTAL} dependencies found (${MISSING} missing)${RESET}"
        echo ""
        echo "  Run ${CYAN}make setup${RESET} to install missing dependencies."
        echo "  Or install individually: ${CYAN}make setup-lean${RESET}, ${CYAN}make setup-rust${RESET}, etc."
    fi
    echo ""
}

cmd_setup() {
    detect_os
    echo ""
    echo "  ${BOLD}🏛️  Cathedral Environment Setup${RESET}"
    echo "  ═══════════════════════════════════════════"
    echo "  OS: ${CYAN}${OS}${RESET}  Package manager: ${CYAN}${PKG}${RESET}"
    echo ""

    if [ "$OS" = "macos" ] && [ "$PKG" = "none" ]; then
        echo "  ${YELLOW}Homebrew not found. Install it first:${RESET}"
        echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        echo ""
        echo "  Then re-run: make setup"
        exit 1
    fi

    # Check what's missing and install
    NEED_LEAN=0; NEED_RUST=0; NEED_NODE=0; NEED_PYTHON=0; NEED_LATEX=0; NEED_GMP=0

    command -v lean  >/dev/null 2>&1 || NEED_LEAN=1
    command -v cargo >/dev/null 2>&1 || NEED_RUST=1
    command -v node  >/dev/null 2>&1 || NEED_NODE=1
    command -v python3 >/dev/null 2>&1 || NEED_PYTHON=1
    command -v pdflatex >/dev/null 2>&1 || NEED_LATEX=1

    # Check GMP
    if [ "$OS" = "macos" ]; then
        prefix=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")
        [ -f "$prefix/lib/libgmp.dylib" ] || NEED_GMP=1
    else
        ldconfig -p 2>/dev/null | grep -q "libgmp.so" || NEED_GMP=1
    fi

    if [ $NEED_LEAN -eq 0 ] && [ $NEED_RUST -eq 0 ] && [ $NEED_NODE -eq 0 ] && \
       [ $NEED_PYTHON -eq 0 ] && [ $NEED_LATEX -eq 0 ] && [ $NEED_GMP -eq 0 ]; then
        echo "  ${GREEN}All dependencies already installed! ✨${RESET}"
        echo ""
        exit 0
    fi

    echo "  The following will be installed:"
    [ $NEED_LEAN -eq 1 ]   && echo "    [1] Lean 4 via elan    (for building proofs)"
    [ $NEED_RUST -eq 1 ]   && echo "    [2] Rust via rustup    (for experiments)"
    [ $NEED_NODE -eq 1 ]   && echo "    [3] Node.js            (for dashboard)"
    [ $NEED_PYTHON -eq 1 ] && echo "    [4] Python 3           (for tools)"
    [ $NEED_LATEX -eq 1 ]  && echo "    [5] LaTeX              (for papers)"
    [ $NEED_GMP -eq 1 ]    && echo "    [6] GMP + MPFR         (for high-precision experiments)"
    echo ""

    if confirm "Proceed with installation?"; then
        [ $NEED_LEAN -eq 1 ]   && install_lean
        [ $NEED_RUST -eq 1 ]   && install_rust
        [ $NEED_NODE -eq 1 ]   && install_node
        [ $NEED_PYTHON -eq 1 ] && install_python
        [ $NEED_LATEX -eq 1 ]  && install_latex
        [ $NEED_GMP -eq 1 ]    && install_gmp
        echo ""
        echo "  ${GREEN}${BOLD}Setup complete!${RESET}"
        echo "  Run ${CYAN}make check${RESET} to verify everything is working."
        echo ""
    else
        echo ""
        echo "  Setup cancelled. Install individually with:"
        echo "    make setup-lean    make setup-rust    make setup-node"
        echo "    make setup-python  make setup-latex   make setup-gmp"
        echo ""
    fi
}

cmd_require() {
    tool="$1"
    case "$tool" in
        lean)
            if ! command -v lean >/dev/null 2>&1; then
                echo "${RED}Error: Lean 4 not found.${RESET}"
                echo "  Install: curl -sSf https://raw.githubusercontent.com/leanprover/elan/master/elan-init.sh | sh"
                echo "  Or run:  make setup-lean"
                exit 1
            fi
            ;;
        cargo|rust)
            if ! command -v cargo >/dev/null 2>&1; then
                echo "${RED}Error: Rust/Cargo not found.${RESET}"
                echo "  Install: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
                echo "  Or run:  make setup-rust"
                exit 1
            fi
            ;;
        node)
            if ! command -v node >/dev/null 2>&1; then
                echo "${RED}Error: Node.js not found.${RESET}"
                echo "  Install: brew install node  (macOS)"
                echo "  Or run:  make setup-node"
                exit 1
            fi
            ;;
        python3|python)
            if ! command -v python3 >/dev/null 2>&1; then
                echo "${RED}Error: Python 3 not found.${RESET}"
                echo "  Install: brew install python3  (macOS)"
                echo "  Or run:  make setup-python"
                exit 1
            fi
            ;;
        pdflatex|latex)
            if ! command -v pdflatex >/dev/null 2>&1; then
                echo "${RED}Error: pdflatex not found.${RESET}"
                echo "  Install: brew install --cask mactex-no-gui  (macOS)"
                echo "  Or run:  make setup-latex"
                exit 1
            fi
            ;;
        gmp)
            detect_os
            if [ "$OS" = "macos" ]; then
                prefix=$(brew --prefix 2>/dev/null || echo "/opt/homebrew")
                if [ ! -f "$prefix/lib/libgmp.dylib" ]; then
                    echo "${RED}Error: GMP library not found.${RESET}"
                    echo "  Install: brew install gmp mpfr"
                    echo "  Or run:  make setup-gmp"
                    exit 1
                fi
            else
                if ! ldconfig -p 2>/dev/null | grep -q "libgmp.so"; then
                    echo "${RED}Error: GMP library not found.${RESET}"
                    echo "  Install: sudo apt install libgmp-dev libmpfr-dev"
                    echo "  Or run:  make setup-gmp"
                    exit 1
                fi
            fi
            ;;
        *)
            echo "${RED}Error: Unknown tool '${tool}'${RESET}"
            exit 1
            ;;
    esac
}

# ── Main ────────────────────────────────────────────────

case "${1:-help}" in
    check)
        cmd_check
        ;;
    setup)
        cmd_setup
        ;;
    setup-lean)
        detect_os
        install_lean
        ;;
    setup-rust)
        detect_os
        install_rust
        ;;
    setup-node)
        detect_os
        install_node
        ;;
    setup-python)
        detect_os
        install_python
        ;;
    setup-latex)
        detect_os
        install_latex
        ;;
    setup-gmp)
        detect_os
        install_gmp
        ;;
    require)
        if [ -z "$2" ]; then
            echo "Usage: $0 require <tool>"
            exit 1
        fi
        cmd_require "$2"
        ;;
    help|*)
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  check            Full dependency report"
        echo "  setup            Interactive installer"
        echo "  setup-lean       Install Lean 4 only"
        echo "  setup-rust       Install Rust only"
        echo "  setup-node       Install Node.js only"
        echo "  setup-python     Install Python 3 only"
        echo "  setup-latex      Install LaTeX only"
        echo "  setup-gmp        Install GMP + MPFR only"
        echo "  require <tool>   Exit 1 if tool missing (for Makefile)"
        echo ""
        ;;
esac
