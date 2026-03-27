#!/bin/bash
# HYPERZETA Hardware & Environment Checker

echo "Scanning M2 Max System Compilers..."

if ! command -v python3 &> /dev/null
then
    echo "[!] python3 missing. Install Python 3.10+"
    exit 1
fi

if ! command -v cargo &> /dev/null
then
    echo "[!] Cargo (Rust) missing. Run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
    exit 1
fi

if ! command -v npm &> /dev/null
then
    echo "[!] npm missing. Install Node.js v18+"
    exit 1
fi

echo "[✔] All mathematical compiler environments validated natively."
exit 0
