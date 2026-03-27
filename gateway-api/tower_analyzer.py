"""
Project HYPERZETA: Cayley-Dickson Tower Analyzer
==================================================
Bridge 5: Division Algebra Non-Vanishing Analysis

Mirrors the Rust core-engine/src/math.rs tower computation in Python.
Computes the Euler product ζ(s) = ∏_p (1-p^(-s))^(-1) at each level
of the Cayley-Dickson tower:

  ℂ (complex)  → ℍ (quaternion) → 𝕆 (octonion) → 𝕊 (sedenion)

KEY INSIGHT: In division algebras (ℍ, 𝕆), the Euler product is
structurally non-vanishing because:
  1. Each factor (1 - p^(-s)) is non-zero
  2. Its inverse exists (division algebra!)
  3. Product of non-zero elements is non-zero (no zero divisors!)

In sedenions (𝕊), zero divisors exist, so this guarantee breaks.
This analysis numerically tracks where the guarantee holds.
"""

import numpy as np
import json
import os
import time

TOWER_CACHE = os.path.join(os.path.dirname(__file__), "..", "proofs", ".tower_cache.json")

PRIMES_25 = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47,
             53, 59, 61, 67, 71, 73, 79, 83, 89, 97]


# ═══════════════════════════════════════════════════════════
# Pure Python Quaternion (Division Algebra — no zero divisors)
# ═══════════════════════════════════════════════════════════

class Quat:
    __slots__ = ['r', 'i', 'j', 'k']
    
    def __init__(self, r=0.0, i=0.0, j=0.0, k=0.0):
        self.r, self.i, self.j, self.k = r, i, j, k
    
    @staticmethod
    def one():
        return Quat(1.0)
    
    @staticmethod
    def from_complex(re, im):
        return Quat(re, im, 0.0, 0.0)
    
    def conj(self):
        return Quat(self.r, -self.i, -self.j, -self.k)
    
    def norm_sq(self):
        return self.r**2 + self.i**2 + self.j**2 + self.k**2
    
    def norm(self):
        return np.sqrt(self.norm_sq())
    
    def __mul__(self, other):
        """Hamilton product"""
        return Quat(
            self.r*other.r - self.i*other.i - self.j*other.j - self.k*other.k,
            self.r*other.i + self.i*other.r + self.j*other.k - self.k*other.j,
            self.r*other.j - self.i*other.k + self.j*other.r + self.k*other.i,
            self.r*other.k + self.i*other.j - self.j*other.i + self.k*other.r,
        )
    
    def __sub__(self, other):
        return Quat(self.r-other.r, self.i-other.i, self.j-other.j, self.k-other.k)
    
    def __add__(self, other):
        return Quat(self.r+other.r, self.i+other.i, self.j+other.j, self.k+other.k)
    
    def scale(self, s):
        return Quat(self.r*s, self.i*s, self.j*s, self.k*s)
    
    def inverse(self):
        """q^(-1) = conj(q)/|q|² — ALWAYS EXISTS for q ≠ 0 (division algebra!)"""
        n = self.norm_sq()
        if n < 1e-30:
            return Quat()
        c = self.conj()
        return Quat(c.r/n, c.i/n, c.j/n, c.k/n)
    
    def exp(self):
        """e^q = e^r (cos|v| + v̂ sin|v|)"""
        v_norm = np.sqrt(self.i**2 + self.j**2 + self.k**2)
        exp_r = np.exp(self.r)
        if v_norm < 1e-15:
            return Quat(exp_r)
        cos_v = np.cos(v_norm)
        sin_v_over_v = np.sin(v_norm) / v_norm
        return Quat(exp_r*cos_v, exp_r*sin_v_over_v*self.i,
                     exp_r*sin_v_over_v*self.j, exp_r*sin_v_over_v*self.k)


# ═══════════════════════════════════════════════════════════
# Pure Python Octonion (Division Algebra — no zero divisors)
# ═══════════════════════════════════════════════════════════

class Oct:
    __slots__ = ['a', 'b']
    
    def __init__(self, a=None, b=None):
        self.a = a or Quat()
        self.b = b or Quat()
    
    @staticmethod
    def one():
        return Oct(Quat.one(), Quat())
    
    @staticmethod
    def from_complex(re, im):
        return Oct(Quat.from_complex(re, im), Quat())
    
    def conj(self):
        return Oct(self.a.conj(), Quat(-self.b.r, -self.b.i, -self.b.j, -self.b.k))
    
    def norm_sq(self):
        return self.a.norm_sq() + self.b.norm_sq()
    
    def norm(self):
        return np.sqrt(self.norm_sq())
    
    def __mul__(self, other):
        """Cayley-Dickson: (a,b)·(c,d) = (ac - d*b, da + bc*)"""
        ac = self.a * other.a
        d_star = other.b.conj()
        d_star_b = d_star * self.b
        first = ac - d_star_b
        
        da = other.b * self.a
        c_star = self.a.conj()
        bc_star = self.b * c_star
        second = da + bc_star
        
        return Oct(first, second)
    
    def __sub__(self, other):
        return Oct(self.a - other.a, self.b - other.b)
    
    def __add__(self, other):
        return Oct(self.a + other.a, self.b + other.b)
    
    def scale(self, s):
        return Oct(self.a.scale(s), self.b.scale(s))
    
    def inverse(self):
        """o^(-1) = conj(o)/|o|² — ALWAYS EXISTS for o ≠ 0 (division algebra!)"""
        n = self.norm_sq()
        if n < 1e-30:
            return Oct()
        return self.conj().scale(1.0 / n)
    
    def exp(self):
        """Octonion exponential"""
        r = self.a.r
        v = Oct(Quat(0, self.a.i, self.a.j, self.a.k), Quat(self.b.r, self.b.i, self.b.j, self.b.k))
        v_norm = v.norm()
        exp_r = np.exp(r)
        if v_norm < 1e-15:
            return Oct(Quat(exp_r), Quat())
        cos_v = np.cos(v_norm)
        sin_v_over_v = np.sin(v_norm) / v_norm
        result = v.scale(sin_v_over_v)
        result.a.r += cos_v
        return result.scale(exp_r)


# ═══════════════════════════════════════════════════════════
# Euler Product at Each Tower Level
# ═══════════════════════════════════════════════════════════

def euler_product_complex(sigma, t, num_primes=25):
    """ζ_ℂ(s) = ∏_p (1 - p^(-s))^(-1) in ℂ"""
    s = complex(sigma, t)
    product = complex(1, 0)
    for p in PRIMES_25[:num_primes]:
        factor = 1.0 - p ** (-s)
        if abs(factor) < 1e-30:
            continue
        product *= 1.0 / factor
    return abs(product), product


def euler_product_quaternion(sigma, t, num_primes=25):
    """ζ_ℍ(s) = ∏_p (1 - p^(-s))^(-1) in ℍ — NON-VANISHING (division algebra)"""
    s = Quat.from_complex(sigma, t)
    product = Quat.one()
    
    for p in PRIMES_25[:num_primes]:
        ln_p = np.log(p)
        neg_s_ln_p = s.scale(-ln_p)
        p_neg_s = neg_s_ln_p.exp()  # p^(-s) = e^{-s·ln(p)}
        
        factor = Quat.one() - p_neg_s  # (1 - p^(-s))
        factor_inv = factor.inverse()  # ALWAYS EXISTS in ℍ!
        product = product * factor_inv
    
    return product.norm(), product


def euler_product_octonion(sigma, t, num_primes=25):
    """ζ_𝕆(s) = ∏_p (1 - p^(-s))^(-1) in 𝕆 — NON-VANISHING (division algebra)"""
    s = Oct.from_complex(sigma, t)
    product = Oct.one()
    
    for p in PRIMES_25[:num_primes]:
        ln_p = np.log(p)
        neg_s_ln_p = s.scale(-ln_p)
        p_neg_s = neg_s_ln_p.exp()
        
        factor = Oct.one() - p_neg_s
        factor_inv = factor.inverse()  # ALWAYS EXISTS in 𝕆!
        product = product * factor_inv
    
    return product.norm(), product


# ═══════════════════════════════════════════════════════════
# Zero Divisor Detection in Sedenions
# ═══════════════════════════════════════════════════════════

from conjecture_miner import Sedenion, zeta_sedenion

def find_sedenion_zero_divisor_example():
    """
    Construct an explicit zero divisor pair in the sedenions.
    The standard example: (e₃ + e₁₀)(e₆ - e₁₅) = 0
    This shows WHY the Euler product guarantee breaks at dim=16.
    """
    a = Sedenion()
    a.c[3] = 1.0   # e₃
    a.c[10] = 1.0   # e₁₀
    
    b = Sedenion()
    b.c[6] = 1.0   # e₆
    b.c[15] = -1.0  # -e₁₅
    
    product = a.mul(b)
    product_norm = product.norm()
    
    return {
        "a_components": a.c.tolist(),
        "b_components": b.c.tolist(),
        "product_norm": float(product_norm),
        "is_zero_divisor": bool(product_norm < 1e-10),
        "a_norm": float(a.norm()),
        "b_norm": float(b.norm()),
        "description": "(e₃ + e₁₀)(e₆ - e₁₅) = 0 in 𝕊₁₆",
    }


# ═══════════════════════════════════════════════════════════
# Full Tower Analysis Pipeline
# ═══════════════════════════════════════════════════════════

class TowerAnalyzer:
    """
    Computes the Euler product Zeta at each level of the Cayley-Dickson tower
    along Re(s) = 1, tracking where the division algebra non-vanishing guarantee
    holds vs. breaks.
    """
    
    def __init__(self, cache_path=TOWER_CACHE):
        self.cache_path = os.path.abspath(cache_path)
        self.results = None
    
    def analyze(self, force=False):
        if not force and os.path.exists(self.cache_path):
            try:
                with open(self.cache_path, "r") as f:
                    self.results = json.load(f)
                print(f"[Tower] Loaded cached analysis")
                return self.results
            except (json.JSONDecodeError, KeyError):
                pass
        
        print("[Tower] Analyzing Cayley-Dickson tower Euler products on Re(s) ≈ 1...")
        start = time.time()
        
        sigma = 1.001  # Just above Re(s) = 1
        
        # Test at 20 points along Im(s) = [1, 80]
        t_values = np.linspace(1.0, 80.0, 20)
        tower_data = []
        
        print(f"  {'t':>8s} | {'|ζ_ℂ|':>10s} | {'|ζ_ℍ|':>10s} | {'|ζ_𝕆|':>10s} | {'|ζ_𝕊|':>10s} | Division Alg?")
        print("  " + "─" * 75)
        
        for t in t_values:
            norm_c, _ = euler_product_complex(sigma, t)
            norm_h, _ = euler_product_quaternion(sigma, t)
            norm_o, _ = euler_product_octonion(sigma, t)
            
            # Sedenion via Dirichlet (not Euler product — no clean factorization)
            s_sed = Sedenion.from_complex(sigma, t)
            zeta_s = zeta_sedenion(s_sed, terms=50)
            norm_s = zeta_s.norm()
            
            # Key: in division algebras, norm is ALWAYS > 0
            div_alg_holds = norm_h > 0.01 and norm_o > 0.01
            
            row = {
                "t": float(t),
                "|ζ_C|": float(norm_c),
                "|ζ_H|": float(norm_h),
                "|ζ_O|": float(norm_o),
                "|ζ_S|": float(norm_s),
                "div_alg_nonvanishing": bool(div_alg_holds),
            }
            tower_data.append(row)
            
            marker = "✓" if div_alg_holds else "✗"
            print(f"  {t:8.2f} | {norm_c:10.6f} | {norm_h:10.6f} | {norm_o:10.6f} | {norm_s:10.6f} | {marker}")
        
        # Find sedenion zero divisors
        print("\n  Zero divisor analysis in 𝕊₁₆:")
        zd = find_sedenion_zero_divisor_example()
        print(f"    {zd['description']}: |a·b| = {zd['product_norm']:.2e} (zero divisor: {zd['is_zero_divisor']})")
        
        # Summary statistics
        all_h_nonzero = all(d["|ζ_H|"] > 0.01 for d in tower_data)
        all_o_nonzero = all(d["|ζ_O|"] > 0.01 for d in tower_data)
        min_h = min(d["|ζ_H|"] for d in tower_data)
        min_o = min(d["|ζ_O|"] for d in tower_data)
        min_c = min(d["|ζ_C|"] for d in tower_data)
        
        # Check restriction: does ζ_ℍ|_ℂ ≈ ζ_ℂ? (they should agree on the complex sub-plane)
        restriction_errors = []
        for d in tower_data:
            if d["|ζ_C|"] > 0.01:
                err = abs(d["|ζ_H|"] - d["|ζ_C|"]) / d["|ζ_C|"]
                restriction_errors.append(err)
        avg_restriction_error = np.mean(restriction_errors) if restriction_errors else 0
        
        elapsed = time.time() - start
        
        self.results = {
            "analysis_time_sec": elapsed,
            "sigma": sigma,
            "tower_data": tower_data,
            "zero_divisor": zd,
            "summary": {
                "quaternion_always_nonzero": bool(all_h_nonzero),
                "octonion_always_nonzero": bool(all_o_nonzero),
                "min_|ζ_C|": float(min_c),
                "min_|ζ_H|": float(min_h),
                "min_|ζ_O|": float(min_o),
                "restriction_agreement": float(avg_restriction_error),
            },
        }
        
        try:
            with open(self.cache_path, "w") as f:
                json.dump(self.results, f, indent=2)
            print(f"\n[Tower] Complete in {elapsed:.1f}s. Cached to {self.cache_path}")
        except Exception as e:
            print(f"\n[Tower] Complete in {elapsed:.1f}s. Cache write failed: {e}")
        
        return self.results
    
    def format_conjectures(self) -> str:
        if self.results is None:
            self.analyze()
        
        r = self.results
        s = r["summary"]
        zd = r["zero_divisor"]
        
        lines = [
            "",
            "CAYLEY-DICKSON TOWER ANALYSIS: Division Algebra Non-Vanishing",
            "=" * 60,
            "",
            "ALGEBRAIC STRUCTURE:",
            "  ℂ (dim 2)  — field, no zero divisors",
            "  ℍ (dim 4)  — division algebra, no zero divisors",
            "  𝕆 (dim 8)  — division algebra, no zero divisors",
            "  𝕊 (dim 16) — NOT a division algebra, HAS zero divisors",
            f"  Example: {zd['description']}: |product| = {zd['product_norm']:.2e}",
            "",
            "EULER PRODUCT NON-VANISHING (Re(s) ≈ 1):",
            f"  Quaternion ζ_ℍ always non-zero: {'YES ✓' if s['quaternion_always_nonzero'] else 'NO ✗'}",
            f"  Octonion  ζ_𝕆 always non-zero: {'YES ✓' if s['octonion_always_nonzero'] else 'NO ✗'}",
            f"  min|ζ_ℂ| = {s['min_|ζ_C|']:.6f}",
            f"  min|ζ_ℍ| = {s['min_|ζ_H|']:.6f}",
            f"  min|ζ_𝕆| = {s['min_|ζ_O|']:.6f}",
            "",
            f"  Restriction check: |ζ_ℍ|_ℂ - ζ_ℂ| / |ζ_ℂ| = {s['restriction_agreement']:.4f}",
            "  (Should be ≈ 0 if quaternionic ζ restricts to complex ζ)",
            "",
            "CONJECTURE (from tower analysis):",
            "  The non-vanishing of ζ(s) on Re(s) = 1 is a consequence of",
            "  ζ being the RESTRICTION of a quaternionic Euler product to ℂ ⊂ ℍ.",
            "  Since ℍ is a division algebra, the quaternionic product is non-vanishing.",
            "  The complex restriction inherits this non-vanishing property.",
        ]
        
        return "\n".join(lines)


if __name__ == "__main__":
    analyzer = TowerAnalyzer()
    results = analyzer.analyze(force=True)
    print("\n" + analyzer.format_conjectures())
