"""
Project HYPERZETA: Hilbert-Pólya Operator Search
==================================================
Bridge 3: Construct a candidate self-adjoint operator whose eigenvalues
approximate the non-trivial zeros of the Riemann zeta function.

The Hilbert-Pólya conjecture (1914) states that RH is equivalent to:
  ∃ self-adjoint operator T : eigenvalues of ½ + iT are the non-trivial zeros of ζ(s)

The Berry-Keating conjecture (1999) narrows this to H = ½(xp + px).

This module searches for STRUCTURED Hermitian matrices (Toeplitz, tridiagonal,
and general) whose eigenvalues best match the first N known zero heights,
then analyzes the winning structure for patterns formalizable in Lean 4.

A diagonal matrix trivially matches any target eigenvalues—that's uninteresting.
The real question is: does a SIMPLE formula exist?
"""

import numpy as np
import os
import json
import time

OPERATOR_CACHE = os.path.join(os.path.dirname(__file__), "..", "proofs", ".operator_cache.json")

# First 30 non-trivial zero heights of ζ(s) (imaginary parts)
# Source: Odlyzko's tables, verified to extreme precision
ZERO_HEIGHTS = np.array([
    14.134725142, 21.022039639, 25.010857580, 30.424876126, 32.935061588,
    37.586178159, 40.918719012, 43.327073281, 48.005150881, 49.773832478,
    52.970321478, 56.446247697, 59.347044003, 60.831778525, 65.112544048,
    67.079811257, 69.546401711, 72.067157674, 75.704690699, 77.144840069,
    79.337375020, 82.910380854, 84.735492981, 87.425274613, 88.809111208,
    92.491899271, 94.651344041, 95.870634228, 98.831194218, 101.317851006,
])


def _to_python(obj):
    """Recursively convert numpy types to Python native types for JSON serialization."""
    if isinstance(obj, dict):
        return {k: _to_python(v) for k, v in obj.items()}
    elif isinstance(obj, (list, tuple)):
        return [_to_python(v) for v in obj]
    elif isinstance(obj, (np.integer,)):
        return int(obj)
    elif isinstance(obj, (np.floating,)):
        return float(obj)
    elif isinstance(obj, (np.bool_,)):
        return bool(obj)
    elif isinstance(obj, np.ndarray):
        return obj.tolist()
    return obj


# ═══════════════════════════════════════════════════════════
# Structured Matrix Classes
# Each class constrains the search to a specific matrix family.
# ═══════════════════════════════════════════════════════════

class ToeplitzSearch:
    """
    Search for a symmetric Toeplitz matrix: M[i,j] = f(|i-j|).
    Only `dim` free parameters (one per diagonal distance).
    """
    name = "Toeplitz"
    
    def __init__(self, dim):
        self.dim = dim
        self.n_params = dim  # f(0), f(1), ..., f(dim-1)
    
    def to_matrix(self, params):
        M = np.zeros((self.dim, self.dim))
        for i in range(self.dim):
            for j in range(self.dim):
                M[i, j] = params[abs(i - j)]
        return M
    
    def init_params(self, target):
        # Initialize: diagonal ≈ mean(target), off-diagonals small
        params = np.zeros(self.dim)
        params[0] = np.mean(target)
        return params


class TridiagonalSearch:
    """
    Search for a symmetric tridiagonal matrix.
    Parameters: `dim` diagonal entries + `dim-1` off-diagonal entries.
    This is the structure of discrete Sturm-Liouville operators.
    """
    name = "Tridiagonal"
    
    def __init__(self, dim):
        self.dim = dim
        self.n_params = 2 * dim - 1  # diag + subdiag
    
    def to_matrix(self, params):
        M = np.zeros((self.dim, self.dim))
        diag = params[:self.dim]
        subdiag = params[self.dim:]
        for i in range(self.dim):
            M[i, i] = diag[i]
        for i in range(self.dim - 1):
            M[i, i+1] = subdiag[i]
            M[i+1, i] = subdiag[i]
        return M
    
    def init_params(self, target):
        params = np.zeros(self.n_params)
        # Initialize diagonal with target values
        params[:self.dim] = target
        # Initialize off-diagonal with small random values
        params[self.dim:] = np.random.randn(self.dim - 1) * 0.1
        return params


class PentadiagonalSearch:
    """
    Search for a symmetric pentadiagonal matrix (bandwidth 2).
    Parameters: diag + 2 sub/super-diagonals.
    """
    name = "Pentadiagonal"
    
    def __init__(self, dim):
        self.dim = dim
        self.n_params = 3 * dim - 3  # diag + subdiag1 + subdiag2
    
    def to_matrix(self, params):
        M = np.zeros((self.dim, self.dim))
        diag = params[:self.dim]
        sub1 = params[self.dim:2*self.dim - 1]
        sub2 = params[2*self.dim - 1:]
        for i in range(self.dim):
            M[i, i] = diag[i]
        for i in range(self.dim - 1):
            M[i, i+1] = sub1[i]
            M[i+1, i] = sub1[i]
        for i in range(self.dim - 2):
            M[i, i+2] = sub2[i]
            M[i+2, i] = sub2[i]
        return M
    
    def init_params(self, target):
        params = np.zeros(self.n_params)
        params[:self.dim] = target
        params[self.dim:] = np.random.randn(2 * self.dim - 3) * 0.05
        return params


class HilbertPolyaSearch:
    """
    Searches across multiple structured matrix families to find the simplest
    Hermitian operator whose eigenvalues approximate the zeta zeros.
    
    The point: a DIAGONAL matrix trivially works, but that's mathematically
    vacuous. We want a matrix with STRUCTURE — because structure implies a
    formula, and a formula can be formalized in Lean 4.
    """
    
    def __init__(self, dim=20, learning_rate=0.01, max_iters=5000, cache_path=OPERATOR_CACHE):
        self.dim = min(dim, len(ZERO_HEIGHTS))
        self.target = ZERO_HEIGHTS[:self.dim]
        self.lr = learning_rate
        self.max_iters = max_iters
        self.cache_path = os.path.abspath(cache_path)
        self.best_matrix = None
        self.best_loss = float('inf')
        self.report = None
    
    def _eigenvalue_loss(self, matrix):
        """MSE between matrix eigenvalues and target zero heights."""
        eigenvalues = np.sort(np.linalg.eigvalsh(matrix))
        target_sorted = np.sort(self.target)
        return float(np.sum((eigenvalues - target_sorted) ** 2))
    
    def _gradient(self, searcher, params, epsilon=1e-5):
        """Finite-difference gradient of the eigenvalue loss."""
        grad = np.zeros_like(params)
        M0 = searcher.to_matrix(params)
        f0 = self._eigenvalue_loss(M0)
        for i in range(len(params)):
            params_plus = params.copy()
            params_plus[i] += epsilon
            M_plus = searcher.to_matrix(params_plus)
            grad[i] = (self._eigenvalue_loss(M_plus) - f0) / epsilon
        return grad
    
    def _optimize(self, searcher, lr=None, max_iters=None):
        """Run gradient descent for a specific matrix structure."""
        lr = lr or self.lr
        max_iters = max_iters or self.max_iters
        
        params = searcher.init_params(self.target)
        best_params = params.copy()
        best_loss = self._eigenvalue_loss(searcher.to_matrix(params))
        
        velocity = np.zeros_like(params)
        momentum = 0.9
        
        for iteration in range(max_iters):
            grad = self._gradient(searcher, params)
            
            # Gradient clipping
            grad_norm = np.linalg.norm(grad)
            if grad_norm > 100.0:
                grad *= (100.0 / grad_norm)
            
            velocity = momentum * velocity - lr * grad
            params = params + velocity
            
            M = searcher.to_matrix(params)
            loss = self._eigenvalue_loss(M)
            
            if loss < best_loss:
                best_loss = loss
                best_params = params.copy()
            
            if (iteration + 1) % 500 == 0:
                print(f"    [{iteration+1}/{max_iters}] loss={loss:.4f} | best={best_loss:.4f}")
            
            if best_loss < 1e-6:
                print(f"    Converged at iteration {iteration+1}!")
                break
        
        return best_params, best_loss
    
    def search(self, force=False):
        """
        Search across Toeplitz, tridiagonal, and pentadiagonal structures.
        Compare results and pick the best structured operator.
        """
        if not force and os.path.exists(self.cache_path):
            try:
                with open(self.cache_path, "r") as f:
                    self.report = json.load(f)
                self.best_matrix = np.array(self.report["best_matrix"])
                self.best_loss = self.report["best_loss"]
                print(f"[Operator] Loaded cached result (loss={self.best_loss:.6f})")
                return self.report
            except (json.JSONDecodeError, KeyError):
                pass
        
        print(f"[Operator] Searching for {self.dim}×{self.dim} structured Hermitian operators...")
        print(f"[Operator] Target: first {self.dim} zeta zeros")
        start = time.time()
        
        np.random.seed(42)
        
        results = {}
        
        # Search each structure class
        searchers = [
            TridiagonalSearch(self.dim),
            PentadiagonalSearch(self.dim),
            ToeplitzSearch(self.dim),
        ]
        
        for searcher in searchers:
            print(f"\n  [{searcher.name}] params={searcher.n_params}")
            best_params, best_loss = self._optimize(searcher, max_iters=self.max_iters)
            best_matrix = searcher.to_matrix(best_params)
            eigenvalues = np.sort(np.linalg.eigvalsh(best_matrix))
            max_err = float(np.max(np.abs(eigenvalues - np.sort(self.target))))
            
            results[searcher.name] = {
                "loss": best_loss,
                "max_error": max_err,
                "matrix": best_matrix,
                "eigenvalues": eigenvalues,
                "params": best_params,
                "n_params": searcher.n_params,
            }
            
            print(f"  [{searcher.name}] Final loss={best_loss:.6f} | max_error={max_err:.6f}")
        
        # Pick the best structure
        best_name = min(results, key=lambda k: results[k]["loss"])
        best = results[best_name]
        self.best_matrix = best["matrix"]
        self.best_loss = best["loss"]
        
        elapsed = time.time() - start
        
        # Analyze the winning matrix
        structure = self._analyze_structure(self.best_matrix)
        
        self.report = _to_python({
            "dim": self.dim,
            "best_structure": best_name,
            "best_loss": self.best_loss,
            "search_time_sec": elapsed,
            "eigenvalues": best["eigenvalues"].tolist(),
            "target_zeros": self.target.tolist(),
            "max_eigenvalue_error": best["max_error"],
            "best_matrix": self.best_matrix.tolist(),
            "structure": structure,
            "all_results": {
                name: {
                    "loss": float(r["loss"]),
                    "max_error": float(r["max_error"]),
                    "n_params": r["n_params"],
                }
                for name, r in results.items()
            },
        })
        
        # Cache
        try:
            with open(self.cache_path, "w") as f:
                json.dump(self.report, f, indent=2)
            print(f"\n[Operator] Best: {best_name} (loss={self.best_loss:.6f}) in {elapsed:.1f}s")
        except Exception as e:
            print(f"\n[Operator] Complete in {elapsed:.1f}s. Cache write failed: {e}")
        
        return self.report
    
    def _analyze_structure(self, M):
        """Analyze the matrix structure for patterns."""
        dim = M.shape[0]
        total_energy = float(np.sum(M**2))
        if total_energy < 1e-15:
            total_energy = 1e-15
        
        # Diagonal analysis
        diagonal = np.diag(M)
        diag_energy = float(np.sum(diagonal**2))
        
        # Band energy analysis
        band_energies = {}
        for bw in [0, 1, 2, 3, 5]:
            be = sum(
                M[i, j]**2
                for i in range(dim)
                for j in range(dim)
                if abs(i-j) <= bw
            )
            band_energies[bw] = float(be) / total_energy
        
        # Off-diagonal patterns
        off_diag = {}
        for k in range(1, min(dim, 5)):
            vals = [float(M[i, i+k]) for i in range(dim-k)]
            off_diag[k] = {
                "mean": float(np.mean(vals)),
                "std": float(np.std(vals)),
                "values": [round(v, 6) for v in vals[:5]],
            }
        
        # Diagonal spacing pattern (gaps between consecutive diagonal entries)
        diag_diffs = [float(diagonal[i+1] - diagonal[i]) for i in range(len(diagonal)-1)]
        
        return _to_python({
            "diagonal_dominance": round(diag_energy / total_energy, 4),
            "is_diagonal_dominant": bool(diag_energy / total_energy > 0.95),
            "band_energy_ratios": {str(k): round(v, 4) for k, v in band_energies.items()},
            "diagonal_values": [round(float(d), 6) for d in diagonal[:10]],
            "diagonal_spacings": [round(d, 4) for d in diag_diffs[:10]],
            "off_diagonal_by_distance": off_diag,
        })
    
    def format_report(self):
        """Format results for injection into the LLM prompt."""
        if self.report is None:
            self.search()
        
        r = self.report
        s = r["structure"]
        
        lines = [
            "HILBERT-PÓLYA OPERATOR SEARCH RESULTS:",
            f"Best structure: {r['best_structure']} ({r['dim']}×{r['dim']})",
            f"Eigenvalue match loss: {r['best_loss']:.6f} | Max error: {r['max_eigenvalue_error']:.6f}",
            "",
            "Structures tested:",
        ]
        
        for name, res in r["all_results"].items():
            lines.append(f"  {name:20s} | loss={res['loss']:.4f} | params={res['n_params']}")
        
        lines.append("")
        
        if not s["is_diagonal_dominant"]:
            lines.append(f"FINDING: The best operator has significant OFF-DIAGONAL structure.")
            lines.append(f"  Diagonal accounts for only {s['diagonal_dominance']*100:.1f}% of the matrix energy.")
            
            if s.get("off_diagonal_by_distance", {}).get(1, {}).get("std", 1.0) < 0.1:
                mean_sub = s["off_diagonal_by_distance"]["1"]["mean"]
                lines.append(f"  The sub-diagonal is approximately CONSTANT: ~{mean_sub:.4f}")
                lines.append(f"  This resembles a discrete Laplacian + potential operator:")
                lines.append(f"  H = -Δ + V, where V[i] = diagonal[i] and Δ is the graph Laplacian.")
        else:
            lines.append(f"FINDING: The operator is diagonal-dominant ({s['diagonal_dominance']*100:.1f}%).")
            lines.append(f"  Off-diagonal corrections: {s['off_diagonal_by_distance'].get('1', {}).get('values', [])[:3]}")
        
        lines.append(f"\n  Diagonal entries (≈ zero heights): {s['diagonal_values'][:5]}...")
        lines.append(f"  Diagonal spacings: {s['diagonal_spacings'][:5]}...")
        
        lines.append("")
        lines.append("IMPLICATION FOR RH:")
        lines.append(f"  The {r['best_structure']} structure suggests a specific operator form.")
        lines.append("  If this operator has a closed-form definition and its eigenvalues provably")
        lines.append("  match the zeta zeros, proving self-adjointness gives a proof of RH")
        lines.append("  via the Hilbert-Pólya conjecture.")
        
        return "\n".join(lines)


if __name__ == "__main__":
    search = HilbertPolyaSearch(dim=15, learning_rate=0.005, max_iters=2000)
    report = search.search(force=True)
    print("\n" + search.format_report())
    
    # Show eigenvalue comparison
    eigenvalues = np.sort(np.linalg.eigvalsh(np.array(report["best_matrix"])))
    print("\nEigenvalue comparison:")
    print(f"{'Target':>12s}  {'Found':>12s}  {'Error':>12s}")
    for t, e in zip(sorted(ZERO_HEIGHTS[:15]), eigenvalues):
        print(f"{t:12.6f}  {e:12.6f}  {abs(t-e):12.8f}")
