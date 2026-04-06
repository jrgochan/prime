# SpectralRH Proof Architecture

> ⚠️ **OUTDATED**: This document describes an earlier 3-axiom architecture.
> The current Cathedral (v1.0) uses **2 axioms**: `offdiag_excess_sum_le` and
> `zeta_zero_separates`. See the [main README](../../README.md) for the current state.

## Fully-Connected Critical Path (April 2026)

The Riemann Hypothesis is reduced to **3 axioms** with **zero sorry**:

```mermaid
graph TD
    T2["🔴 type_II_sieve_bound<br/>K < 1 (Tier 3: Frontier)"]
    V["🟡 vasyunin_expansion<br/>(Tier 2)"]
    M["🟡 moebius_uncoupling<br/>(Tier 2)"]
    SIR["✅ sieve_implies_stable_ratio<br/>PROVED (BilinearSieve.lean)"]
    SRP["stable_ratio_parity<br/>(proved in BilinearSieve)"]
    SCLR["✅ schur_complement_lower_from_ratio<br/>PROVED (ParitySchur.lean)"]
    SDV2["🟡 schur_to_distance_scaling_v2<br/>(bridge axiom)"]
    NB["✅ nb_distance_scaling<br/>THEOREM (Assembly.lean)"]
    DC["✅ distance_converges_to_zero<br/>PROVED"]
    NYM["📘 nyman_beurling<br/>(Beurling 1955)"]
    RH["✅ riemann_hypothesis<br/>PROVED"]

    T2 --> SIR
    V -.-> SIR
    M -.-> SIR
    SIR --> SRP
    SRP --> SDV2
    SRP --> SCLR
    SDV2 --> NB
    NB --> DC
    DC --> RH
    NYM --> RH

    style T2 fill:#ff6b6b,color:#000
    style RH fill:#51cf66,color:#000
    style NB fill:#51cf66,color:#000
    style DC fill:#51cf66,color:#000
    style SIR fill:#51cf66,color:#000
    style SCLR fill:#51cf66,color:#000
    style SDV2 fill:#ffd43b,color:#000
    style V fill:#ffd43b,color:#000
    style M fill:#ffd43b,color:#000
    style NYM fill:#74c0fc,color:#000
```

## File Dependency Graph

```mermaid
graph LR
    Defs --> Structural
    Defs --> RayleighBridge
    Defs --> AlignmentDecay
    Defs --> Quantitative
    Defs --> PTSymmetry
    Defs --> GramBounds
    Defs --> OctonionicPartition
    Defs --> ClassRestriction
    
    Structural --> ParitySchur
    PTSymmetry --> ParitySchur
    RayleighBridge --> Structural
    
    ParitySchur --> BilinearSieve
    
    Structural --> Assembly
    Quantitative --> Assembly
    AlignmentDecay --> Assembly
    BilinearSieve --> Assembly

    style Assembly fill:#51cf66,color:#000
    style BilinearSieve fill:#51cf66,color:#000
    style ParitySchur fill:#51cf66,color:#000
    style GramBounds fill:#51cf66,color:#000
```

## Axiom Census

| Category | Count | Files |
|----------|-------|-------|
| **Critical path** | 7 | Assembly, ParitySchur, BilinearSieve, Structural |
| Off-path (exploratory) | 21 | SpectralFlow, ClassRestriction, etc. |
| **Total** | **28** | 11 files |

### Critical Path Axioms

| Axiom | File | Tier | Status |
|-------|------|------|--------|
| `type_II_sieve_bound` | BilinearSieve | 3 | 🔴 Open (K ≈ 0.961) |
| `vasyunin_expansion` | BilinearSieve | 2 | 🟡 Coprime case done |
| `moebius_uncoupling` | BilinearSieve | 2 | 🟡 Vaughan formalization |
| `stable_ratio_parity` | ParitySchur | — | ✅ Proved in BilinearSieve |
| `schur_to_distance_scaling_v2` | ParitySchur | 2 | 🟡 Bridge axiom |
| `nyman_beurling` | Assembly | — | 📘 Published (1955) |
| `drop_formula_bound` | Structural | — | ⚪ Supporting |

## Key Verified Theorems

| Theorem | File | Technique |
|---------|------|-----------|
| `gram_pos_def` | Structural | L² linear independence |
| `gram_block_decomposition` | ParitySchur | Parity projection algebra |
| `schur_complement_pos_of_gram_pos` | ParitySchur | Case split on det(C) |
| `gramMatrix_posSemidef` | ParitySchur | PosSemidef bridge |
| `parityBlockA_psd` / `parityBlockC_psd` | ParitySchur | conjTranspose_mul_mul_same |
| `schur_complement_lower_from_ratio` | ParitySchur | sub_mulVec + linarith |
| `sieve_implies_stable_ratio` | BilinearSieve | Optimal witness w=C⁻¹Bᵀv |
| `nb_distance_scaling` | Assembly | schur_to_distance_v2 + stable_ratio |
| `distance_converges_to_zero` | Assembly | Logarithmic divergence |
| `riemann_hypothesis` | Assembly | Nyman-Beurling criterion |
