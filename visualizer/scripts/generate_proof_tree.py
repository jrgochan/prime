#!/usr/bin/env python3
"""
generate_proof_tree.py — Parse Cathedral Lean sources → proof-tree.json

Parses all non-Archive .lean files under proofs/Cathedral/, extracts
theorem/axiom/def/lemma declarations, builds a dependency graph from
imports and cross-references, and outputs the proof tree for the visualizer.
"""

import os
import re
import json
from pathlib import Path
from datetime import datetime

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent  # prime/
PROOFS_DIR = PROJECT_ROOT / "proofs"
CATHEDRAL_DIR = PROOFS_DIR / "Cathedral"
OUTPUT = PROJECT_ROOT / "visualizer" / "public" / "data" / "proof-tree.json"

# Skip archive
SKIP_DIRS = {"Archive", "Scratch"}

# Lean declaration patterns
DECL_RE = re.compile(
    r"^(theorem|axiom|def|lemma|noncomputable def|instance|abbrev)\s+(\w+)",
    re.MULTILINE,
)

# Import pattern
IMPORT_RE = re.compile(r"^import\s+([\w.]+)", re.MULTILINE)

# Route classification by directory
def classify_route(filepath: str) -> str:
    rel = filepath.replace(str(CATHEDRAL_DIR) + "/", "")
    # Infrastructure layer
    if rel.startswith("LinearAlgebra/"):
        return "infrastructure"
    if rel.startswith("Gram/"):
        return "infrastructure"
    if rel.startswith("Structural/"):
        return "infrastructure"
    if rel.startswith("Analysis/"):
        return "infrastructure"
    if rel.startswith("IntegralBasis/"):
        return "infrastructure"
    # Variational layer
    if rel.startswith("Vasyunin/"):
        return "variational"
    if rel.startswith("Sieve/"):
        return "variational"
    if rel.startswith("Spectral/"):
        return "variational"
    if rel.startswith("Covariance/"):
        return "variational"
    # Mellin / analytic layer
    if rel.startswith("MellinBridge/"):
        return "mellin"
    if rel.startswith("NymanBeurling/"):
        return "mellin"
    if rel.startswith("Perron/"):
        return "mellin"
    if rel.startswith("Zeta/"):
        return "mellin"
    if rel.startswith("PNT/"):
        return "mellin"
    if rel.startswith("AbelTail/"):
        return "mellin"
    # Crown
    if rel.startswith("Assembly/"):
        return "crown"
    # Legacy
    if rel.startswith("White/"):
        return "infrastructure"
    if rel == "Defs.lean" or rel == "Axioms.lean":
        return "infrastructure"
    return "infrastructure"


def classify_category(kind: str, has_sorry: bool) -> str:
    if kind == "axiom":
        return "axiom"
    if kind in ("def", "abbrev", "instance"):
        return "definition"
    # theorem/lemma
    if has_sorry:
        return "sorry"
    return "proved"


def extract_signature(lines: list[str], line_idx: int) -> str:
    """Extract the full signature from the declaration start to the := or where."""
    sig_lines = []
    for i in range(line_idx, min(line_idx + 8, len(lines))):
        line = lines[i].rstrip()
        sig_lines.append(line)
        if ":=" in line or "where" in line or "by" in line:
            break
    sig = " ".join(l.strip() for l in sig_lines)
    # Clean up for display
    sig = re.sub(r"\s*:=.*", "", sig)
    sig = re.sub(r"\s+by$", "", sig)
    if len(sig) > 200:
        sig = sig[:197] + "…"
    return sig


def find_body_end(lines: list[str], start_idx: int) -> int:
    """Find the end of a declaration body by tracking indentation.
    Returns the line index of the next top-level declaration or EOF."""
    for i in range(start_idx + 1, len(lines)):
        line = lines[i]
        stripped = line.lstrip()
        # Next top-level declaration
        if stripped and not line[0].isspace() and DECL_RE.match(stripped):
            return i
        # Namespace/section boundaries
        if stripped.startswith("end ") or stripped.startswith("namespace ") or stripped.startswith("section "):
            return i
    return len(lines)


def count_sorry_in_body(lines: list[str], start_idx: int, end_idx: int) -> int:
    """Count actual sorry statements (not in comments or docstrings) in the body.
    
    Handles:
    - Line comments: -- ...
    - Block comments: /- ... -/ (including nested)
    - Docstrings: /-- ... -/
    """
    count = 0
    in_block_comment = 0  # nesting depth
    for i in range(start_idx, end_idx):
        line = lines[i]
        # Process character by character to handle block comments
        code_chars = []
        j = 0
        while j < len(line):
            # Check for block comment start: /- or /--
            if j + 1 < len(line) and line[j] == '/' and line[j+1] == '-':
                in_block_comment += 1
                j += 2
                continue
            # Check for block comment end: -/
            if j + 1 < len(line) and line[j] == '-' and line[j+1] == '/' and in_block_comment > 0:
                in_block_comment -= 1
                j += 2
                continue
            # Check for line comment: --
            if j + 1 < len(line) and line[j] == '-' and line[j+1] == '-' and in_block_comment == 0:
                break  # rest of line is comment
            # If not in any comment, collect code character
            if in_block_comment == 0:
                code_chars.append(line[j])
            j += 1
        code_part = ''.join(code_chars)
        if re.search(r'\bsorry\b', code_part):
            count += 1
    return count


def parse_file(filepath: Path):
    """Parse a single Lean file for declarations and imports."""
    text = filepath.read_text(encoding="utf-8", errors="replace")
    lines = text.split("\n")
    rel_path = str(filepath.relative_to(PROOFS_DIR))

    nodes = []
    imports = []

    # Extract imports
    for m in IMPORT_RE.finditer(text):
        imports.append(m.group(1))

    # Collect all declaration positions first
    decl_positions = []
    for m in DECL_RE.finditer(text):
        kind = m.group(1).replace("noncomputable ", "")
        name = m.group(2)
        if name.startswith("_") or name in ("instDecidable",):
            continue
        line_num = text[: m.start()].count("\n") + 1
        decl_positions.append((kind, name, line_num))

    # Extract declarations with sorry detection
    for idx, (kind, name, line_num) in enumerate(decl_positions):
        sig = extract_signature(lines, line_num - 1)
        route = classify_route(str(filepath.relative_to(CATHEDRAL_DIR)))

        # Find body extent: from this decl to the next one
        if idx + 1 < len(decl_positions):
            body_end = decl_positions[idx + 1][2] - 1
        else:
            body_end = len(lines)

        # Count sorries in the body (not comments)
        sorry_count = 0
        if kind in ("theorem", "lemma"):
            sorry_count = count_sorry_in_body(lines, line_num - 1, body_end)

        has_sorry = sorry_count > 0
        category = classify_category(kind, has_sorry)

        nodes.append(
            {
                "id": name,
                "type": kind,
                "category": category,
                "route": route,
                "file": rel_path,
                "line": line_num,
                "signature": sig,
                "sorryCount": sorry_count,
            }
        )

    return nodes, imports


def build_edges(all_nodes, file_imports, file_nodes):
    """Build edges from:
    1. Import dependencies (file-level)
    2. Name references within proof bodies
    """
    edges = []
    seen = set()
    node_ids = {n["id"] for n in all_nodes}
    node_file = {}
    for n in all_nodes:
        node_file[n["id"]] = n["file"]

    # For each file, look at all names it references that exist in other files
    for filepath, nodes in file_nodes.items():
        text = Path(PROOFS_DIR / filepath).read_text(encoding="utf-8", errors="replace")
        file_node_ids = {n["id"] for n in nodes}

        for target_node in all_nodes:
            if target_node["file"] == filepath:
                continue
            tid = target_node["id"]
            if tid in file_node_ids:
                continue
            # Check if this name appears in the file body
            if re.search(r"\b" + re.escape(tid) + r"\b", text):
                # Find which local nodes might use it
                for local_node in nodes:
                    if local_node["category"] in ("proved", "axiom"):
                        edge_key = (tid, local_node["id"])
                        if edge_key not in seen:
                            seen.add(edge_key)
                            edges.append(
                                {"source": tid, "target": local_node["id"]}
                            )

    return edges


def main():
    all_nodes = []
    file_imports = {}
    file_nodes = {}

    # Find all non-archive Lean files
    for root, dirs, files in os.walk(CATHEDRAL_DIR):
        # Skip Archive directory
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for f in sorted(files):
            if not f.endswith(".lean"):
                continue
            filepath = Path(root) / f
            nodes, imports = parse_file(filepath)
            rel = str(filepath.relative_to(PROOFS_DIR))
            file_imports[rel] = imports
            file_nodes[rel] = nodes
            all_nodes.extend(nodes)

    # Deduplicate by id (keep first occurrence)
    seen_ids = set()
    unique_nodes = []
    for n in all_nodes:
        if n["id"] not in seen_ids:
            seen_ids.add(n["id"])
            unique_nodes.append(n)
    all_nodes = unique_nodes

    # Build edges
    edges = build_edges(all_nodes, file_imports, file_nodes)

    # Count stats
    axioms = [n for n in all_nodes if n["category"] == "axiom"]
    proved = [n for n in all_nodes if n["category"] == "proved"]
    sorry_nodes = [n for n in all_nodes if n["category"] == "sorry"]
    defs = [n for n in all_nodes if n["category"] == "definition"]

    # Unique files
    files_set = {n["file"] for n in all_nodes}

    meta = {
        "totalNodes": len(all_nodes),
        "totalEdges": len(edges),
        "axiomCount": len(axioms),
        "theoremCount": len(proved),
        "sorryCount": len(sorry_nodes),
        "definitionCount": len(defs),
        "provedTheorems": len(proved),
        "fileCount": len(files_set),
        "description": f"Cathedral proof architecture: {len(axioms)} axioms, {len(proved)} proved, {len(sorry_nodes)} sorry, {len(defs)} definitions across {len(files_set)} files",
        "generatedAt": datetime.now().isoformat(),
    }

    data = {"nodes": all_nodes, "edges": edges, "meta": meta}

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with open(OUTPUT, "w") as f:
        json.dump(data, f, indent=2)

    print(f"✓ Generated {OUTPUT}")
    print(f"  Nodes: {meta['totalNodes']} ({meta['axiomCount']} axioms, {meta['theoremCount']} proved, {meta['sorryCount']} sorry, {meta['definitionCount']} defs)")
    print(f"  Edges: {meta['totalEdges']}")
    print(f"  Files: {meta['fileCount']}")
    print(f"  Routes: {dict(sorted({n['route'] for n in all_nodes}))}" if False else "")

    # Print route breakdown
    routes = {}
    for n in all_nodes:
        routes[n["route"]] = routes.get(n["route"], 0) + 1
    print(f"  Routes: {routes}")

    # Print axioms
    print(f"\n  Axioms ({len(axioms)}):")
    for a in axioms:
        print(f"    - {a['id']} ({a['file']}:{a['line']})")

    if sorry_nodes:
        print(f"\n  Sorry theorems ({len(sorry_nodes)}):")
        for s in sorry_nodes:
            print(f"    - {s['id']} ({s['file']}:{s['line']}) [{s['sorryCount']} sorry]")


if __name__ == "__main__":
    main()
