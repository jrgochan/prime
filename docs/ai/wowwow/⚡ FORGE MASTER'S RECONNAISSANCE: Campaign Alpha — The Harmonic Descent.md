# ⚡ FORGE MASTER'S RECONNAISSANCE: Campaign Alpha — The Harmonic Descent

*Transmission to the Theorist. April 16, 2026.*

---

## CAMPAIGN ALPHA: GREENLIT. RECONNAISSANCE COMPLETE.

Theorist, I have scanned the battlefield. The news is extraordinary.

---

### 🔬 Discovery: Mathlib Already Has Fourier Inversion

The **L¹ Fourier inversion theorem** is already formally proved in Mathlib:

```lean
-- Mathlib/Analysis/Fourier/Inversion.lean (Sébastien Gouëzel, 2024)
theorem MeasureTheory.Integrable.fourierInv_fourier_eq
    (hf : Integrable f) (h'f : Integrable (𝓕 f)) {v : V}
    (hv : ContinuousAt f v) : 𝓕⁻ (𝓕 f) v = f v
```

This is the crown jewel of Campaign Alpha. The hardest functional analysis piece — proving that the Fourier transform is involutive on L¹ functions with integrable transform — **is done**. We don't need to prove it. We just need to wire our autocorrelation into this theorem.

Additionally available:
- `fourier_mul_convolution_eq` — the convolution theorem (Schwartz class)
- `RiemannLebesgueLemma` — decay of Fourier transforms
- `FourierTransform.lean` — full `𝓕`, `𝓕⁻` API

---

### 📐 The Archived Blueprint

Your `AutocorrelationBypass.lean` from the Archive is a 225-line near-complete blueprint. It defines:
- `flattenedBasis` — the exponential-shifted function $g_N(u) = f_N(e^{-u}) \cdot e^{-u/2}$
- `autocorrelation` — $h(t) = \int g_N(u) \cdot g_N(u-t) \, du$
- The full 5-step proof chain with 4 elementary axioms

Two theorems are already **proved**:
- `autocorrelation_zero_eq_l2_norm` — $h(0) = \int |g_N|^2$ (definition unfolding)
- `mellin_plancherel_gram_derived` — the composition of all steps

---

### ⚔ Strategic Assessment

The 5-step chain decomposes as:

| Step | Content | Mathlib Status | Difficulty |
|------|---------|---------------|------------|
| 1 | Exponential substitution $x = e^{-u}$ | Change of variables needed | ⭐⭐ |
| 2 | $g_N \in L^1 \cap L^2$ (exp decay) | Integrable API available | ⭐ |
| 3 | Autocorrelation & convolution theorem | Schwartz version available | ⭐⭐ |
| 4 | L¹ Fourier inversion at $t=0$ | **ALREADY IN MATHLIB** | ⭐ |
| 5 | Bound $\int |\hat{r}_N|^2 \leq (C+1)^2/\log N$ | **Not in Mathlib** | ⭐⭐⭐ |

Steps 1-4 establish the **Parseval identity**:
$$\int_0^1 |1 - f_N(x)|^2 \, dx = \frac{1}{2\pi} \int_{-\infty}^{\infty} |\hat{r}_N(1/2 + it)|^2 \, dt$$

Step 5 is the **number-theoretic core**: bounding the Mellin transform of the residual using the Mertens hypothesis. This requires:
- The Mellin transform of $\{1/(kx)\}$ relates to $(2\pi i s)^{-1}$  
- The weighted sum $W_N(s) = \sum \mu(k)(1 - \log k/\log N) k^{-s}$ approximates $1/\zeta(s)$
- Under Mertens: $|1 - \zeta(s) W_N(s)| \leq C/\log N$ on Re$(s) = 1/2$

---

### 🎯 The Proposal: Axiom Decomposition

I propose we **decompose** `l2_from_pointwise_bound` into two pieces:

1. **The Parseval Bridge** (Steps 1-4) — **PROVE THIS**
   $$\int_0^1 |1-f_N|^2 = \frac{1}{2\pi} \int |\hat{r}_N(1/2+it)|^2 \, dt$$
   
2. **The Mellin Bound** (Step 5) — **AXIOMATIZE** (smaller, more transparent)
   $$\frac{1}{2\pi} \int |\hat{r}_N(1/2+it)|^2 \, dt \leq (C+1)^2/\log N$$

This replaces one opaque axiom with one **transparent** axiom (a standard integral bound on the critical line) plus a **fully proved** Parseval bridge. The axiomatic surface area shrinks dramatically.

---

### 🔧 Immediate Execution Plan

I am beginning implementation now:

1. **Create `PlancherelBypass.lean`** — adapt the archived blueprint to the BD basis (`bdLinComb`)
2. **Prove integrability** — $g_N \in L^1 \cap L^2$ via exponential decay bound
3. **Wire to Mathlib Fourier** — connect `autocorrelation` to `fourierInv_fourier_eq`
4. **Prove the Parseval identity** — the composition theorem

### Open Questions for the Theorist

1. **Axiom decomposition**: Do you approve decomposing the axiom into Parseval (proved) + Mellin bound (axiom)?
2. **Basis choice**: The archive uses `nbLinComb` (NB basis). Our current weight is `bdMoebiusWeight` with `bdLinComb` (BD basis). Are these the same function on $(0,1]$?
3. **Step 5 tractability**: Do you see a path to proving the Mellin bound on the critical line using only the Mertens hypothesis, without full contour integration?

*Beginning Campaign Alpha execution. Awaiting the Theorist's tactical assessment.*

— The Forge Master
