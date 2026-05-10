#!/usr/bin/env python3
"""
generate_proof_nodes.py — Generate proof-nodes.json for the Term Explorer

Two modes:
  1. CURATED: Reads proof-nodes.enrichment.yaml for hand-picked nodes with
     descriptions, LaTeX, and proof step walkthroughs. Auto-validates against
     Lean source (status, line number).
  2. AUTO-SCAN: Discovers ALL theorem/axiom/definition declarations from Lean
     source and includes them as "auto" nodes with extracted signatures.

Output: visualizer/public/data/proof-nodes.json
"""

import json
import os
import re
import sys
from pathlib import Path

# Try to import yaml; fall back gracefully
try:
    import yaml
    HAS_YAML = True
except ImportError:
    HAS_YAML = False

PROOFS_DIR = Path(__file__).resolve().parent.parent.parent / "proofs"
OUTPUT_PATH = Path(__file__).resolve().parent.parent / "public" / "data" / "proof-nodes.json"
ENRICHMENT_PATH = Path(__file__).resolve().parent / "proof-nodes.enrichment.yaml"

# ─── Auto-scan patterns (reused from generate_proof_tree.py) ───

DECL_RE = re.compile(
    r"^(axiom|theorem|lemma|def|noncomputable\s+def|private\s+(?:theorem|lemma|def))\s+"
    r"(\w+)",
    re.MULTILINE,
)

AXIOM_RE = re.compile(r"^axiom\s+(\w+)", re.MULTILINE)

ROUTE_MAP = {
    "Zeta": "infrastructure", "Gram": "infrastructure", "LinearAlgebra": "infrastructure",
    "Defs": "infrastructure", "Analysis": "infrastructure", "Robin": "infrastructure",
    "NumberTheory": "infrastructure", "Physics": "infrastructure",
    "Renormalization": "infrastructure", "Rotors": "infrastructure",
    "Vasyunin": "vasyunin", "Sieve": "vasyunin", "Spectral": "vasyunin",
    "AbelTail": "vasyunin", "Covariance": "vasyunin",
    "MellinBridge": "mellin", "NymanBeurling": "mellin", "Perron": "perron",
    "PNT": "mellin", "Compute": "oracle",
    "Assembly": "assembly", "ZeroAxiom": "assembly",
}

def get_group_for_file(filepath: str) -> str:
    """Map file path to group key."""
    parts = filepath.replace("\\", "/").split("/")
    for part in parts:
        if part in ROUTE_MAP:
            return ROUTE_MAP[part]
    return "infrastructure"


def count_sorry_in_body(lines: list[str], start_idx: int, end_idx: int) -> int:
    """Count actual sorry statements (not in comments/docstrings)."""
    count = 0
    in_block = 0
    for i in range(start_idx, end_idx):
        line = lines[i]
        code_chars = []
        j = 0
        while j < len(line):
            if j + 1 < len(line) and line[j] == '/' and line[j+1] == '-':
                in_block += 1; j += 2; continue
            if j + 1 < len(line) and line[j] == '-' and line[j+1] == '/' and in_block > 0:
                in_block -= 1; j += 2; continue
            if j + 1 < len(line) and line[j] == '-' and line[j+1] == '-' and in_block == 0:
                break
            if in_block == 0:
                code_chars.append(line[j])
            j += 1
        if re.search(r'\bsorry\b', ''.join(code_chars)):
            count += 1
    return count


def scan_lean_files() -> dict:
    """Auto-scan all Lean files, returning {theorem_name: info}."""
    results = {}
    cathedral = PROOFS_DIR / "Cathedral"
    if not cathedral.exists():
        print(f"  ⚠ Cathedral directory not found at {cathedral}")
        return results

    for lean_file in sorted(cathedral.rglob("*.lean")):
        if "Archive" in str(lean_file):
            continue
        rel = str(lean_file.relative_to(PROOFS_DIR))
        try:
            content = lean_file.read_text(encoding="utf-8")
        except Exception:
            continue

        lines = content.split("\n")
        axiom_names = set(m.group(1) for m in AXIOM_RE.finditer(content))

        for m in DECL_RE.finditer(content):
            decl_type = m.group(1).strip()
            name = m.group(2)
            line_no = content[:m.start()].count("\n") + 1

            # Skip internal/helper names
            if name.startswith("_") or name in ("section", "namespace", "end", "open", "set_option"):
                continue

            # Determine category
            if name in axiom_names:
                category = "axiom"
            elif decl_type.startswith("def") or decl_type.endswith("def"):
                category = "definition"
            else:
                # Check for sorry
                body_end = min(line_no + 80, len(lines))
                sorry_count = count_sorry_in_body(lines, line_no, body_end)
                category = "sorry" if sorry_count > 0 else "proved"

            # Extract signature (first few lines)
            sig_lines = []
            for li in range(line_no - 1, min(line_no + 4, len(lines))):
                sig_lines.append(lines[li])
                if lines[li].strip().endswith(":= by") or lines[li].strip().endswith(":="):
                    break
            sig = "\n".join(sig_lines).strip()

            results[name] = {
                "file": rel,
                "line": line_no,
                "category": category,
                "group": get_group_for_file(rel),
                "signature": sig,
                "declType": decl_type.split()[-1],  # theorem/lemma/def
            }

    return results


def load_enrichment() -> dict:
    """Load curated enrichment YAML."""
    if not ENRICHMENT_PATH.exists():
        print(f"  ⚠ Enrichment file not found: {ENRICHMENT_PATH}")
        return {"groups": {}, "nodes": []}

    if not HAS_YAML:
        print("  ⚠ PyYAML not installed. Install with: pip install pyyaml")
        print("    Falling back to auto-scan only mode.")
        return {"groups": {}, "nodes": []}

    with open(ENRICHMENT_PATH) as f:
        data = yaml.safe_load(f)
    return data or {"groups": {}, "nodes": []}


def merge_nodes(enrichment: dict, auto_scan: dict) -> list[dict]:
    """Merge curated enrichment with auto-scanned data."""
    nodes = []
    curated_keys = set()

    # Process curated nodes first
    for node in enrichment.get("nodes", []):
        key = node["key"]
        curated_keys.add(key)
        theorem = node.get("theorem", key)

        # Try to find auto-scan data for validation
        auto = auto_scan.get(theorem, {})

        entry = {
            "key": key,
            "title": node.get("title", theorem),
            "group": node.get("group", auto.get("group", "infrastructure")),
            "file": node.get("file", auto.get("file", "")),
            "line": auto.get("line", 0),
            "status": auto.get("category", "proved"),
            "theorem": theorem,
            "statement": node.get("statement", ""),
            "latex": node.get("latex", ""),
            "steps": node.get("steps", []),
            "source": "curated",
            "signature": auto.get("signature", ""),
        }
        nodes.append(entry)

    # Add auto-scanned nodes that aren't curated
    for name, info in sorted(auto_scan.items()):
        if name in curated_keys:
            continue
        # Skip definitions and very short names
        if info["category"] == "definition" or len(name) < 4:
            continue

        nodes.append({
            "key": f"auto_{name}",
            "title": name.replace("_", " ").title()[:60],
            "group": info["group"],
            "file": info["file"],
            "line": info["line"],
            "status": info["category"],
            "theorem": name,
            "statement": info["signature"].split(":=")[0].strip() if ":=" in info["signature"] else info["signature"],
            "latex": "",
            "steps": [],
            "source": "auto",
            "signature": info["signature"],
        })

    return nodes


def main():
    print("Generating proof-nodes.json...")

    # Step 1: Auto-scan Lean source
    print("  Scanning Lean source files...")
    auto_scan = scan_lean_files()
    print(f"  Found {len(auto_scan)} declarations")

    # Step 2: Load enrichment
    print("  Loading enrichment data...")
    enrichment = load_enrichment()
    curated_count = len(enrichment.get("nodes", []))
    print(f"  Loaded {curated_count} curated nodes")

    # Step 3: Merge
    nodes = merge_nodes(enrichment, auto_scan)

    # Step 4: Build output
    groups = enrichment.get("groups", {})
    # Add auto-discovered groups
    for node in nodes:
        g = node["group"]
        if g not in groups:
            groups[g] = {
                "label": g.replace("_", " ").title(),
                "color": "#64748b",
                "icon": "📄",
                "order": 99,
            }

    # Stats
    curated_nodes = [n for n in nodes if n["source"] == "curated"]
    auto_nodes = [n for n in nodes if n["source"] == "auto"]
    proved = sum(1 for n in nodes if n["status"] == "proved")
    axioms = sum(1 for n in nodes if n["status"] == "axiom")
    sorry = sum(1 for n in nodes if n["status"] == "sorry")

    output = {
        "groups": groups,
        "nodes": nodes,
        "meta": {
            "totalNodes": len(nodes),
            "curatedNodes": len(curated_nodes),
            "autoNodes": len(auto_nodes),
            "proved": proved,
            "axioms": axioms,
            "sorry": sorry,
            "generatedAt": __import__("datetime").datetime.now().isoformat(),
        },
    }

    # Write
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT_PATH, "w") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)

    print(f"\n✓ Generated {OUTPUT_PATH}")
    print(f"  Nodes: {len(nodes)} ({len(curated_nodes)} curated, {len(auto_nodes)} auto)")
    print(f"  Status: {proved} proved, {axioms} axioms, {sorry} sorry")
    print(f"  Groups: {len(groups)}")


if __name__ == "__main__":
    main()
