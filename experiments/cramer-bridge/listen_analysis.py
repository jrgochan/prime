"""Listen for the zeta zeros in Cramér's mean square J(X) = ∫₁^X ((ψ(u)−u)/u)² du.

Prediction (RH, explicit formula):
    J(X) = C₀ log X + C₁ + Σ_{ρ≠ρ'} X^{i(γ−γ')} / (i(γ−γ') ρ ρ̄') + o(1)
"""
import sys
import numpy as np

GAMMA_E = 0.5772156649015329
C0_THEORY = 2 + GAMMA_E - np.log(4 * np.pi)

# First 30 nontrivial zeta zeros (imaginary parts)
ZEROS = np.array([
    14.134725142, 21.022039639, 25.010857580, 30.424876126, 32.935061588,
    37.586178159, 40.918719012, 43.327073281, 48.005150881, 49.773832478,
    52.970321478, 56.446247697, 59.347044003, 60.831778525, 65.112544048,
    67.079810529, 69.546401711, 72.067157674, 75.704690699, 77.144840069,
    79.337375020, 82.910380854, 84.735492981, 87.425274613, 88.809111208,
    92.491899271, 94.651344041, 95.870634228, 98.831194218, 101.317851006,
])


def oscillation(t, zeros):
    """Σ_{ρ≠ρ'} e^{i(γ−γ')t} / (i(γ−γ') ρ ρ̄')  over ±γ.

    The (a,b) and (b,a) terms are complex conjugates, so we sum a<b and double.
    """
    g = np.concatenate([zeros, -zeros])
    rho = 0.5 + 1j * g
    ia, ib = np.triu_indices(len(g), k=1)
    d = g[ia] - g[ib]
    coef = 1.0 / (1j * d * rho[ia] * np.conj(rho[ib]))
    out = np.zeros_like(t)
    chunk = 4096
    for s in range(0, len(d), chunk):
        ph = np.exp(1j * np.outer(t, d[s:s + chunk]))
        out += 2.0 * np.real(ph @ coef[s:s + chunk])
    return out


def main(path, t_min=9.0, zeros_path=None):
    data = np.loadtxt(path, skiprows=1)
    t, J = data[:, 0], data[:, 2]
    m = t >= t_min
    t, J = t[m], J[m]

    zeros = np.loadtxt(zeros_path) if zeros_path else ZEROS
    print(f"zeros used     : {len(zeros)} (up to γ = {zeros[-1]:.2f})")
    osc = oscillation(t, zeros)

    # Fit J − osc = C₀ t + C₁
    A = np.vstack([t, np.ones_like(t)]).T
    (c0, c1), *_ = np.linalg.lstsq(A, J - osc, rcond=None)
    print(f"t range        : [{t[0]:.2f}, {t[-1]:.2f}]  ({len(t)} samples)")
    print(f"C0 fit         : {c0:.6f}   theory 2+γ−ln4π = {C0_THEORY:.6f}")
    print(f"C1 fit         : {c1:.4f}")

    # Residual after smooth part (C₀ fixed to theory, C₁ refit)
    c1_th = np.mean(J - osc - C0_THEORY * t)
    resid = J - C0_THEORY * t - c1_th
    print(f"C1 (C0=theory) : {c1_th:.4f}")
    print(f"resid rms      : {resid.std():.3e}")
    print(f"predicted rms  : {osc.std():.3e}")
    corr = np.corrcoef(resid, osc)[0, 1]
    left = resid - osc
    print(f"corr(resid, prediction from {len(zeros)} zeros) = {corr:.4f}")
    print(f"rms after subtracting prediction      = {left.std():.3e}")

    # Null test: fake 'zeros' (shuffled spacings, same density)
    rng = np.random.default_rng(0)
    nulls = []
    for _ in range(20 if len(zeros) <= 50 else 4):
        fake = np.cumsum(rng.permutation(np.diff(np.concatenate([[0], zeros]))) *
                         rng.uniform(0.8, 1.2))
        nulls.append(np.corrcoef(resid, oscillation(t, fake))[0, 1])
    print(f"null corr (fake zeros): mean {np.mean(nulls):+.3f}, max |c| {np.max(np.abs(nulls)):.3f}")

    try:
        import matplotlib
        matplotlib.use("Agg")
        import matplotlib.pyplot as plt
        fig, ax = plt.subplots(2, 1, figsize=(11, 6.5), sharex=True)
        ax[0].plot(t, resid * 1e3, lw=1.0, color="#4cc9f0", label="measured: J − C₀·log X − C₁")
        ax[0].plot(t, osc * 1e3, lw=1.0, color="#f72585", alpha=0.85,
                   label=f"predicted from first {len(zeros)} zeta zeros")
        ax[0].set_ylabel("×10⁻³")
        ax[0].legend(loc="upper right", fontsize=9)
        ax[0].set_title(f"Hearing the zeta zeros in Cramér's mean square   (corr = {corr:.3f})")
        ax[1].plot(t, left * 1e3, lw=0.8, color="#7209b7")
        ax[1].set_ylabel("measured − predicted ×10⁻³")
        ax[1].set_xlabel("t = log X")
        for a in ax:
            a.grid(alpha=0.25)
        fig.tight_layout()
        out = path.replace(".tsv", ".png")
        fig.savefig(out, dpi=130)
        print(f"figure: {out}")
    except ImportError:
        print("(matplotlib not available — no figure)")


if __name__ == "__main__":
    main(sys.argv[1],
         float(sys.argv[2]) if len(sys.argv) > 2 else 9.0,
         sys.argv[3] if len(sys.argv) > 3 else None)
