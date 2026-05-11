"""
Project HYPERZETA: Sedenion Left-Multiplication Operator Analysis
================================================================
Path 4 from the Hilbert-Pólya Approach

For a sedenion a, the left-multiplication map L_a(x) = a·x is a linear
operator on ℝ¹⁶. Its 16×16 matrix encodes the algebraic structure.

Key property: L_a has a zero eigenvalue ⟺ a is a zero divisor.

We study the operator T(s) = L_{ζ_𝕊(s)} at known zeta zero heights
to understand the spectral geometry of the zeta function in 16D.
"""

import numpy as np
import sys
import time

# First 10 known non-trivial zero heights
ZERO_HEIGHTS = [
    14.134725142, 21.022039639, 25.010857580, 30.424876126, 32.935061588,
    37.586178159, 40.918719012, 43.327073281, 48.005150881, 49.773832478,
]

def sedenion_multiply(a, b):
    """Multiply two sedenions using the Cayley-Dickson construction.

    A sedenion is represented as a 16-element numpy array.
    Cayley-Dickson: if a = (p, q) and b = (r, s) where p,q,r,s are octonions,
    then a·b = (p·r - s*·q, s·p + q·r*) where * is conjugation.
    We recurse down: sedenion → octonion → quaternion → complex → real.
    """
    n = len(a)
    if n == 1:
        return a * b

    half = n // 2
    # Split into pairs (Cayley-Dickson)
    p, q = a[:half], a[half:]
    r, s = b[:half], b[half:]

    # Conjugate: negate all imaginary parts (indices 1..n-1)
    def conj(x):
        c = x.copy()
        c[1:] = -c[1:]
        return c

    # a·b = (p·r - conj(s)·q,  s·p + q·conj(r))
    pr = sedenion_multiply(p, r)
    sq = sedenion_multiply(conj(s), q)
    sp = sedenion_multiply(s, p)
    qr = sedenion_multiply(q, conj(r))

    return np.concatenate([pr - sq, sp + qr])


def sedenion_zeta(sigma, t, terms=100):
    """Compute ζ_𝕊(s) = Σ_{n=1}^{N} n^{-s} in sedenion arithmetic.

    For each n, n^{-s} = n^{-σ} · (cos(t·ln(n)) - i·sin(t·ln(n)))
    where i is the sedenion e₁ basis element.
    The result is a 16-component sedenion.
    """
    result = np.zeros(16)
    for n in range(1, terms + 1):
        mag = n ** (-sigma)
        angle = -t * np.log(n)
        # n^{-s} lives in the (e₀, e₁) plane (complex subspace)
        term = np.zeros(16)
        term[0] = mag * np.cos(angle)
        term[1] = mag * np.sin(angle)
        result += term
    return result


def left_multiplication_matrix(a):
    """Build the 16×16 matrix for the operator L_a(x) = a·x.

    Column j = a · e_j where e_j is the j-th basis sedenion.
    """
    n = len(a)
    matrix = np.zeros((n, n))
    for j in range(n):
        e_j = np.zeros(n)
        e_j[j] = 1.0
        matrix[:, j] = sedenion_multiply(a, e_j)
    return matrix


def get_zeta_operator(sigma, t, terms=100):
    """Get the 16×16 left-multiplication operator matrix for ζ_𝕊(s)."""
    components = sedenion_zeta(sigma, t, terms)
    norm = np.linalg.norm(components)
    matrix = left_multiplication_matrix(components)
    return matrix, components, norm


def analyze_spectrum(matrix, label=""):
    """Compute and analyze eigenvalues of a 16×16 operator matrix."""
    eigenvalues = np.linalg.eigvals(matrix)
    
    # Sort by magnitude
    magnitudes = np.abs(eigenvalues)
    idx = np.argsort(magnitudes)
    eigenvalues = eigenvalues[idx]
    magnitudes = magnitudes[idx]
    
    # Check for zero eigenvalues (zero divisor signature)
    zero_threshold = 1e-10
    num_zero = np.sum(magnitudes < zero_threshold)
    
    # Check symmetry properties
    is_real_spectrum = np.allclose(eigenvalues.imag, 0, atol=1e-12)
    
    # Check if matrix is symmetric (would imply self-adjoint operator)
    is_symmetric = np.allclose(matrix, matrix.T, atol=1e-12)
    
    # Compute condition number
    cond = magnitudes[-1] / max(magnitudes[0], 1e-30)
    
    return {
        "eigenvalues": eigenvalues,
        "magnitudes": magnitudes,
        "num_zero_eigenvalues": int(num_zero),
        "is_real_spectrum": bool(is_real_spectrum),
        "is_symmetric": bool(is_symmetric),
        "spectral_radius": float(magnitudes[-1]),
        "min_eigenvalue_mag": float(magnitudes[0]),
        "condition_number": float(cond),
        "trace": float(np.trace(matrix)),
        "determinant": float(np.linalg.det(matrix)),
    }


def analyze_at_point(sigma, t, terms=100, verbose=True):
    """Full spectral analysis at s = σ + it."""
    matrix, components, norm = get_zeta_operator(sigma, t, terms)
    spectrum = analyze_spectrum(matrix, f"σ={sigma}, t={t:.4f}")
    
    if verbose:
        print(f"\n{'='*60}")
        print(f"  s = {sigma} + {t:.6f}i  |  |ζ_𝕊(s)| = {norm:.8f}")
        print(f"{'='*60}")
        print(f"  ζ_𝕊 components [0:4]: [{components[0]:.6f}, {components[1]:.6f}, {components[2]:.6f}, {components[3]:.6f}]")
        print(f"  ζ_𝕊 components [4:8]: [{components[4]:.6f}, {components[5]:.6f}, {components[6]:.6f}, {components[7]:.6f}]")
        print(f"  Symmetric matrix?   {spectrum['is_symmetric']}")
        print(f"  Real spectrum?      {spectrum['is_real_spectrum']}")
        print(f"  Zero eigenvalues:   {spectrum['num_zero_eigenvalues']}")
        print(f"  Determinant:        {spectrum['determinant']:.6e}")
        print(f"  Trace:              {spectrum['trace']:.6f}")
        print(f"  Spectral radius:    {spectrum['spectral_radius']:.6f}")
        print(f"  Min |λ|:            {spectrum['min_eigenvalue_mag']:.6e}")
        
        # Show all eigenvalues
        print(f"\n  Eigenvalues (sorted by |λ|):")
        for i, (ev, mag) in enumerate(zip(spectrum['eigenvalues'], spectrum['magnitudes'])):
            marker = " ←ZERO" if mag < 1e-10 else ""
            if ev.imag == 0 or abs(ev.imag) < 1e-14:
                print(f"    λ_{i:2d} = {ev.real:+12.6f}   |λ| = {mag:.6e}{marker}")
            else:
                print(f"    λ_{i:2d} = {ev.real:+12.6f} {ev.imag:+12.6f}i   |λ| = {mag:.6e}{marker}")
    
    return spectrum, norm, components


def sweep_sigma_at_zero(t, sigma_range=(0.3, 0.7), num_points=20, terms=100):
    """Sweep σ from 0.3 to 0.7 at a fixed t (known zero height).
    Watch how eigenvalues evolve as we cross the critical line σ = 1/2."""
    
    print(f"\n{'*'*70}")
    print(f"  SIGMA SWEEP at t = {t:.6f} (known zero height)")
    print(f"  σ ∈ [{sigma_range[0]}, {sigma_range[1]}], {num_points} points")
    print(f"{'*'*70}")
    
    sigmas = np.linspace(sigma_range[0], sigma_range[1], num_points)
    results = []
    
    for sigma in sigmas:
        matrix, components, norm = get_zeta_operator(sigma, t, terms)
        eigenvalues = np.linalg.eigvals(matrix)
        magnitudes = np.sort(np.abs(eigenvalues))
        det = np.linalg.det(matrix)
        
        results.append({
            'sigma': sigma,
            'norm': norm,
            'min_eigenvalue': magnitudes[0],
            'max_eigenvalue': magnitudes[-1],
            'det': det,
        })
        
        marker = " ◀ CRITICAL LINE" if abs(sigma - 0.5) < 0.015 else ""
        print(f"  σ = {sigma:.3f}  |ζ| = {norm:.6f}  min|λ| = {magnitudes[0]:.4e}  det = {det:.4e}{marker}")
    
    return results


def main():
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  Project HYPERZETA: Sedenion Left-Multiplication Operator   ║")
    print("║  Path 4: Hilbert-Pólya Spectral Analysis                    ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    
    start = time.time()
    
    # ═══════════════════════════════════════════════════════════
    # EXPERIMENT 1: Analyze at a NON-zero point (σ = 2, t = 0)
    # Expect: all eigenvalues non-zero, matrix well-conditioned
    # ═══════════════════════════════════════════════════════════
    print("\n\n▓▓▓ EXPERIMENT 1: Non-zero point (σ=2, t=0) ▓▓▓")
    analyze_at_point(2.0, 0.0, terms=100)
    
    # ═══════════════════════════════════════════════════════════
    # EXPERIMENT 2: Analyze NEAR a known zero (σ=0.5, t=14.1347)
    # Expect: eigenvalues approaching zero, matrix singular
    # ═══════════════════════════════════════════════════════════
    print("\n\n▓▓▓ EXPERIMENT 2: Near first zero (σ=0.5, t=14.1347) ▓▓▓")
    analyze_at_point(0.5, 14.134725, terms=200)
    
    # ═══════════════════════════════════════════════════════════
    # EXPERIMENT 3: Sweep σ across the critical line at t₁
    # Watch eigenvalues evolve → minimum at σ = 1/2?
    # ═══════════════════════════════════════════════════════════
    print("\n\n▓▓▓ EXPERIMENT 3: σ-sweep at first zero height ▓▓▓")
    sweep_sigma_at_zero(14.134725, sigma_range=(0.4, 0.6), num_points=21, terms=200)
    
    # ═══════════════════════════════════════════════════════════
    # EXPERIMENT 4: Compare spectra at multiple known zeros
    # ═══════════════════════════════════════════════════════════
    print("\n\n▓▓▓ EXPERIMENT 4: Spectral structure at first 5 zeros ▓▓▓")
    for i, t in enumerate(ZERO_HEIGHTS[:5]):
        spec, norm, _ = analyze_at_point(0.5, t, terms=200, verbose=False)
        print(f"  Zero #{i+1}: t = {t:10.6f}  |ζ| = {norm:.6e}  "
              f"min|λ| = {spec['min_eigenvalue_mag']:.4e}  "
              f"det = {spec['determinant']:.4e}  "
              f"symmetric = {spec['is_symmetric']}  "
              f"real_spec = {spec['is_real_spectrum']}")
    
    # ═══════════════════════════════════════════════════════════
    # EXPERIMENT 5: Analyze OFF the critical line (σ ≠ 1/2)
    # At same t values → eigenvalues should NOT approach zero
    # ═══════════════════════════════════════════════════════════
    print("\n\n▓▓▓ EXPERIMENT 5: Off-critical-line at same t values ▓▓▓")
    for sigma in [0.3, 0.4, 0.5, 0.6, 0.7]:
        t = 14.134725
        spec, norm, _ = analyze_at_point(sigma, t, terms=200, verbose=False)
        marker = " ◀ CRITICAL" if abs(sigma - 0.5) < 0.01 else ""
        print(f"  σ = {sigma:.1f}  |ζ| = {norm:.6e}  "
              f"min|λ| = {spec['min_eigenvalue_mag']:.4e}  "
              f"det = {spec['determinant']:.4e}{marker}")
    
    elapsed = time.time() - start
    print(f"\n\nTotal analysis time: {elapsed:.1f}s")


if __name__ == "__main__":
    main()
