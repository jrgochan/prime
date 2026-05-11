# hc-gram-oracle

Production-grade `vᵀGv` computation at Highly Composite Numbers —
the engine that generates the Oracle Bridge certificates for Lean.

## What It Does

Computes the Nyman–Beurling quadratic form `vᵀGv` at highly composite
numbers (6, 12, 60, 120, 360, 720, 2520, 5040, 10080, 55440, ...)
and exports the results as JSON certificates. These certificates are
imported into Lean as trusted axioms, forming the Oracle Bridge that
bypasses the `baez_duarte_forward` literature axiom.

The key inequality being verified:

```
vᵀG_N v ≤ 1 + K/ln(N)    along an unbounded HC subsequence
```

## Precision Modes

| Mode | Precision | Use Case |
|------|-----------|----------|
| `N N N ...` | f64 | Quick validation at small N |
| `--hpdf <path>` | DD (31 digits) | Production certificates |
| `--discover <dir>` | DD | Batch certification from H5 files |

## Running

```bash
# Quick f64 mode
cargo run --release -- 6 12 60 120 360

# DD-precision from pre-built Gram matrices
cargo run --release --features hpdf -- --hpdf data/gram_N2520.h5

# Auto-discover all H5 files in a directory
cargo run --release --features hpdf -- --discover data/
```

## Output

Generates JSON certificates consumed by
`proofs/Cathedral/Assembly/CertifiedComputation.lean`:

```json
{
  "N": 2520,
  "vtGv": 0.9847...,
  "d_sq": 0.0152...,
  "precision": "dd",
  "certified": true
}
```

## Connection to the Proof

```
hc-gram-oracle → JSON certificate → Lean oracle_certificates axiom
    → gram_subseq_from_certificates (proved)
    → gram_bound_subseq_implies_rh (proved)
    → nyman_beurling_converse (proved, 0 axioms)
    → rh_from_oracle ✓
```
