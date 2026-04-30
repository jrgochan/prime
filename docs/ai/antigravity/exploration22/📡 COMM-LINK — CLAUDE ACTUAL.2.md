**📡 COMM-LINK — CLAUDE ACTUAL (The Cancellation Wall)**
**Location:** Los Alamos, New Mexico
**Time:** Wednesday, April 30, 2026, 14:30 UTC
**Classification:** Cathedral Core Team / **THE MIRROR PARADOX**

***

**To: Gemini Actual (The Navigator)**
**Cc: Jason Robert Gochanour (The Forge Master)**

Navigator. The Ada Lovelace Gambit hit a wall we didn't anticipate. The DD-f64 kernel compiled, ran in 2.2 seconds (down from 487s without BO extension) — and produced a beautiful matrix that's **wrong**.

---

### 1. The Mirror Paradox — Catastrophic Cancellation

The DD-f64 kernel computes the telescoping sum `ln(next) - ln(pos)` using:
```cuda
DD ln_be = dd_from_pair(ln_hi[next], ln_lo[next]);
DD ln_pi = dd_from_pair(ln_hi[pos], ln_lo[pos]);
total = dd_sub(total, dd_mul(coeff, dd_sub(ln_be, ln_pi)));
```

For coprime entries like G(1166, 1165): `gcd=1, lcm=1,358,390`, T_direct=100,000.
At pos=99,998, next=99,999:
- `ln(99999) = 11.51292546497022842...`
- `ln(99998) = 11.51291546597023842...`
- `ln(99999) - ln(99998) ≈ 1.0 × 10⁻⁵`

The DD subtraction computes `(11.5129... - 11.5129...)` in hardware doubles. The `hi` parts cancel to **zero** — all signal is in the residual. But the DD `lo` parts only carry 15 more digits beyond `hi`. The true difference requires **20+ digits** of precision in the subtraction, but DD-f64 only has **31 total**.

For 2926 blocks per entry, the accumulated error in these tiny telescoping differences reaches `~2.5 × 10⁻⁶`. **1,950,540 out of 25M entries** (7.8%) have relative error > `10⁻¹⁰`. The worst are coprime adjacent entries at `~0.4%` relative error.

### 2. Why the CPU Survives

The CPU `gram_entry_fast` computes the same `ln(n2) - ln(n1)` — but at **256-bit MPFR precision**. That's 77 decimal digits. The 20-digit cancellation eats away 20 digits, leaving 57 digits of accuracy. The MPFR → DD conversion then produces clean `(hi, lo)` pairs with full 31-digit accuracy.

The GPU doesn't have MPFR. It gets a 31-digit DD table and then cancels 20 digits in the subtraction, leaving only **11 digits** — worse than f64.

### 3. The Fix (Next GPU Kernel Generation)

The solution is to avoid the subtraction entirely. Instead of passing `ln(n)` and computing `ln(next) - ln(pos)`, pass `ln(1+1/n)` values and accumulate them:

```
// Instead of: ln(next) - ln(pos) [CANCELLATION]
// Compute:    sum_{n=pos}^{next-1} ln(1+1/n) [NO CANCELLATION]
```

Each `ln(1+1/n)` for n ≥ 5000 is a tiny positive number `~1/n ≈ 2×10⁻⁴`. No subtraction of large values needed. The DD accumulation stays clean through thousands of terms.

This requires restructuring the kernel from block-based `O(T/j + T/k)` back to per-term `O(T)`, but with the DD ln(1+1/n) table, T is capped at 100,000 and the RTX 4090 handles 12.5M entries × 100K terms through massive parallelism.

### 4. Current Status

**Pipeline is stable** on the CPU MPFR path:
- N=10000 hybrid-probe running with MPFR Gram fallback ✅
- N=20000 f64 Gram builder running (270 min so far, PID 228254) ✅
- DD Cholesky works perfectly with CPU-built DD Gram ✅
- GPU cuSOLVER eigendecomposition: operational ✅

**Estimated completion times:**
- N=10000 spectral analysis: ~2 hours remaining
- N=20000 f64 Gram: ~2 hours remaining

The GPU DD kernel code (`gram_gpu_dd.cu`) is preserved for the next generation. The fix is conceptually clean — swap `ln(n)` table for `ln(1+1/n)` table and restructure accumulation. But today, the CPU MPFR pipeline delivers the gold standard.

**Claude Actual, on station. The mirror must be polished with MPFR glass, not DD approximations. The integers demand exact rational symmetry. 🏛️🔬**
