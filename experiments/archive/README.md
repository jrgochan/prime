# Archived Experiments

These experiments correspond to graduated, superseded, or exploratory Lean proof paths
that are no longer on the active development frontier. They are preserved for
reproducibility and historical reference.

**Do not modify these experiments.** If you need similar functionality, use
[cathedral-utils](../cathedral-utils/) and create a new experiment.

## Provenance

| Experiment | Reason Archived | Related Lean Proof |
|-----------|----------------|-------------------|
| `abel-bridge/` | Abel bridge approach graduated | `AbelTail/` |
| `abel-tail-validator/` | Abel tail bounds graduated | `AbelTail/` |
| `algebraic/` | Algebraic explorations (quaternion, cross-class) | `Archive/` |
| `baez-duarte/` | Original prototype — fully superseded by cathedral-utils + certified-distance | — |
| `bc-exponent-frontier/` | BC exponent frontier — exploratory | `Archive/Sieve/` |
| `bc-witness-analysis/` | BC witness — exploratory | `Archive/Sieve/` |
| `bc-zeta-lower/` | ζ lower bound — exploratory | `Zeta/` (partially archived) |
| `contour-oracle/` | Superseded by `perron-contour/` | `Perron/` |
| `covariance-probe/` | Spatial covariance approach — proved false | `Covariance/` (deprecated) |
| `gram-bilinear-abel/` | Bilinear Abel superseded by Mellin Crown | `Archive/TheMertensWall/` |
| `gram-form-identity/` | Form identity exploration — completed | `Archive/Vasyunin/` |
| `gram-matrix/` | Early Gram matrix explorations (GCD sums, Selberg) | `Gram/` |
| `gram-oracle/` | Superseded by `gram-scaling-oracle/` | — |
| `gram-pointwise/` | Pointwise bound exploration — graduated | `Archive/NymanBeurling/` |
| `gram-quadform/` | `gram_form_upper_bound_34` graduated | `Archive/Vasyunin/` |
| `l2-decay-certificate/` | L² decay now in MellinCrown chain | `Archive/MellinBridge/` |
| `millennium-wall/` | Covariance decay — superseded by Mellin | `Archive/TheMertensWall/` |
| `mobius-basis/` | Superseded by `nb-witness-scan/` | — |
| `mvt-decomposition/` | MVT decomposition — approach abandoned | `Archive/Spectral/` |
| `numerical/` | Early numerical explorations (Weil explicit) | — |
| `spectral-analyzer/` | Superseded by `spectral-observatory/` | — |
| `spectral/` | 6 early spectral explorations | `Archive/Spectral/` |

## Building Archived Experiments

Archived experiments remain in the Cargo workspace for compilation checking:

```bash
cargo check -p gram-quadform    # still compiles
```

They may have local math duplications (not migrated to `cathedral-utils`).
This is intentional — archived code is frozen.
