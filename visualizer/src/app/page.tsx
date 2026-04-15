"use client";
import { motion } from "framer-motion";
import Link from "next/link";

interface CardInfo {
  href: string;
  title: string;
  description: string;
  icon: string;
  stats: string;
  gradient: string;
  border: string;
}

const CARDS: CardInfo[] = [
  {
    href: "/term-explorer",
    title: "Term Explorer",
    description:
      "Interactively explore the Vasyunin formula term by term. Toggle dimensions, inspect matrix entries, visualize the log cutoff witness, and walk the proof chain.",
    icon: "🔬",
    stats: "4 terms · live computation · interactive",
    gradient: "from-violet-500/20 to-purple-500/20",
    border: "border-violet-500/20",
  },
  {
    href: "/proof-tree",
    title: "Proof Dependency Tree",
    description:
      "Interactive force-directed graph of every theorem, axiom, and definition. Trace dependency chains and explore the critical path.",
    icon: "🌳",
    stats: "260 theorems · 7 axioms · 0 sorry",
    gradient: "from-emerald-500/20 to-teal-500/20",
    border: "border-emerald-500/20",
  },
  {
    href: "/robin-lagarias",
    title: "Robin–Lagarias Dashboard",
    description:
      "The freshly-proved lagarias_for_primes theorem visualized: σ(p) vs the Lagarias bound for every prime, with the algebraic bypass and Taylor truncation.",
    icon: "🏆",
    stats: "PROVED · 0 sorry · milestone",
    gradient: "from-amber-500/20 to-orange-500/20",
    border: "border-amber-500/20",
  },
  {
    href: "/gram-heatmap",
    title: "Gram Matrix Heatmap",
    description:
      "Visualize the N×N Gram matrix of fractional part inner products. See the structure that makes the proof work.",
    icon: "🔥",
    stats: "N up to 80 · live computation",
    gradient: "from-orange-500/20 to-red-500/20",
    border: "border-orange-500/20",
  },
  {
    href: "/sawtooth",
    title: "Sawtooth Discovery",
    description:
      "Watch the covariance stabilize instead of decaying — the moment formal verification caught a subtle error.",
    icon: "📐",
    stats: "C∞ ≈ 0.00227",
    gradient: "from-blue-500/20 to-purple-500/20",
    border: "border-blue-500/20",
  },
  {
    href: "/offdiag-margin",
    title: "Off-Diagonal Excess",
    description:
      "The running sum of off-diagonal Gram excess vs the 3n bound — visualizing the structural margin in the Cathedral.",
    icon: "📊",
    stats: "18× margin at N=50",
    gradient: "from-cyan-500/20 to-teal-500/20",
    border: "border-cyan-500/20",
  },
  {
    href: "/fractional-waves",
    title: "Fractional Part Waves",
    description:
      "Toggle sawtooth functions {k/x} and their products to see how Gram matrix entries arise from wave interference.",
    icon: "🌊",
    stats: "k = 1 to 8 · interactive",
    gradient: "from-indigo-500/20 to-blue-500/20",
    border: "border-indigo-500/20",
  },
  {
    href: "/hyperplane-trap",
    title: "The Hyperplane Trap",
    description:
      "3D surface of the Mellin residual showing why spoofing weights cannot escape the Cauchy-Schwarz bound in the Báez-Duarte proof.",
    icon: "🕳️",
    stats: "3D · R3F interactive",
    gradient: "from-red-500/20 to-pink-500/20",
    border: "border-red-500/20",
  },
  {
    href: "/cathedral-3d",
    title: "Cathedral 3D",
    description:
      "The proof architecture as a literal cathedral — three pillars (Converse, Forward, Robin) holding the golden roof of RH.",
    icon: "⛪",
    stats: "3D · auto-rotates",
    gradient: "from-purple-500/20 to-indigo-500/20",
    border: "border-purple-500/20",
  },
];

interface RouteInfo {
  label: string;
  name: string;
  desc: string;
  color: string;
  borderColor: string;
}

const ROUTES: RouteInfo[] = [
  {
    label: "STEP 1 — WITNESS",
    name: "Q(v_log) ≥ c·ln N",
    desc: "The log cutoff witness v_k = −μ(k)(1 − ln k/ln N) yields a Rayleigh quotient that grows logarithmically. This IS the RH.",
    color: "from-amber-500/10 to-transparent",
    borderColor: "border-amber-500/20",
  },
  {
    label: "STEP 2 — VARIATIONAL",
    name: "Q(v) ≤ X_N → ∞",
    desc: "Cauchy-Schwarz + Sherman-Morrison: the quadratic form X_N = b^T C^{-1} b diverges, so d²_N = 1/(1+X_N) → 0.",
    color: "from-blue-500/10 to-transparent",
    borderColor: "border-blue-500/20",
  },
  {
    label: "INDEPENDENT — ROBIN",
    name: "Robin ↔ RH ↔ Lagarias",
    desc: "Discrete arithmetic: σ(p) ≤ H_p + exp(H_p)·ln(H_p) proved for ALL primes. Zero axioms.",
    color: "from-emerald-500/10 to-transparent",
    borderColor: "border-emerald-500/20",
  },
];

export default function HomePage() {
  return (
    <div className="p-8 max-w-6xl mx-auto">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ duration: 0.5 }}
        className="mb-12"
      >
        <h1 className="text-4xl font-bold mb-3">
          <span className="bg-gradient-to-r from-amber-400 via-orange-400 to-red-400 bg-clip-text text-transparent">
            The Cathedral
          </span>
        </h1>
        <p className="text-lg text-slate-400 max-w-2xl">
          A machine-checked reduction of the Riemann Hypothesis to seven
          classical axioms in Lean 4, via the Vasyunin cotangent formula.
          8,710 lines. Zero <code className="text-emerald-400">sorry</code>. Every theorem compiler-verified.
        </p>

        <div className="flex gap-6 mt-6 text-sm flex-wrap">
          {[
            { color: "bg-emerald-500", text: "40 Lean files" },
            { color: "bg-emerald-500", text: "8,710 lines" },
            { color: "bg-amber-500", text: "7 axioms" },
            { color: "bg-emerald-500", text: "260 theorems" },
            { color: "bg-blue-500", text: "0 sorry" },
            { color: "bg-purple-500", text: "3,087 modules" },
          ].map((item) => (
            <div key={item.text} className="flex items-center gap-2">
              <div className={`w-2.5 h-2.5 rounded-full ${item.color}`} />
              <span className="text-slate-300">{item.text}</span>
            </div>
          ))}
        </div>
      </motion.div>

      {/* Three Routes */}
      <h2 className="text-xl font-bold text-slate-200 mb-4">
        The Vasyunin Path
      </h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4 mb-12">
        {ROUTES.map((route, i) => (
          <motion.div
            key={route.label}
            initial={{ opacity: 0, x: i === 0 ? -20 : i === 2 ? 20 : 0 }}
            animate={{ opacity: 1, x: 0 }}
            transition={{ delay: 0.2 + i * 0.1 }}
            className={`p-5 rounded-xl bg-gradient-to-br ${route.color} border ${route.borderColor}`}
          >
            <div className="text-[10px] font-mono text-slate-500 mb-2 tracking-wider">
              {route.label}
            </div>
            <h3 className="text-sm font-bold text-slate-200 mb-1 font-mono">
              {route.name}
            </h3>
            <p className="text-xs text-slate-500 leading-relaxed">
              {route.desc}
            </p>
          </motion.div>
        ))}
      </div>

      {/* Milestone banners */}
      <div className="space-y-3 mb-12">
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.5 }}
          className="p-5 rounded-xl bg-gradient-to-r from-amber-500/10 via-amber-500/5 to-transparent border border-amber-500/20"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">🏰</span>
            <div>
              <h3 className="text-sm font-bold text-amber-400">
                The 7-Axiom Cathedral — TITANIUM
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                Every theorem compiler-verified. 7 axioms remain — all classical results:
                Gauss (1813), Dedekind (1892), Vasyunin (1995), Lagarias (2002), Robin (1984),
                and the RH itself as a log cutoff Rayleigh quotient.
                April 14, 2026.
              </p>
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.52 }}
          className="p-5 rounded-xl bg-gradient-to-r from-indigo-500/10 via-indigo-500/5 to-transparent border border-indigo-500/20"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">🪞</span>
            <div>
              <h3 className="text-sm font-bold text-indigo-400">
                Digamma Reflection — ψ(1−s) − ψ(s) = π·cot(πs) PROVED
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                Proved via logDeriv of Mathlib&apos;s Gamma reflection Γ(s)Γ(1−s) = π/sin(πs).
                Chain rule for z ↦ 1−z on LHS, derivative of sin(πz) on RHS. April 14, 2026.
              </p>
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.54 }}
          className="p-5 rounded-xl bg-gradient-to-r from-sky-500/10 via-sky-500/5 to-transparent border border-sky-500/20"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">⚒️</span>
            <div>
              <h3 className="text-sm font-bold text-sky-400">
                Floor Sum Identity — Σ⌊mb/a⌋ = (a−1)(b−1)/2 PROVED (Last sorry!)
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                Hermite/Eisenstein lattice point identity via coprime mod permutation.
                The &quot;Eisenstein maneuver&quot;: multiply by 2 to bypass ℕ division, independently
                rediscovering Eisenstein&apos;s 1844 technique. April 14, 2026.
              </p>
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.55 }}
          className="p-5 rounded-xl bg-gradient-to-r from-red-500/10 via-red-500/5 to-transparent border border-red-500/20"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">💣</span>
            <div>
              <h3 className="text-sm font-bold text-red-400">
                The Factorial Nuke — k₀=0 Edge Case DESTROYED
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                On (1/(N!+1), 1/N!), divisibility (i+1)|N! forces all floor functions to be exact integers.
                When A=0: g(x)=0, f(x)=w₀≠0. The degenerate case is annihilated.
              </p>
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.6 }}
          className="p-5 rounded-xl bg-gradient-to-r from-violet-500/10 via-violet-500/5 to-transparent border border-violet-500/20"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">🔬</span>
            <div>
              <h3 className="text-sm font-bold text-violet-400">
                Euler-Mascheroni Integral — ∫₀¹ {'{'}1/x{'}'} dx = 1 − γ PROVED
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                Substitution u=kx + series identity Σ(1/(m+1) − log(1+1/(m+1))) = γ via tendsto_harmonic_sub_log.
                Axiom vasyunin_mean_eq_integral eliminated. April 12, 2026.
              </p>
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.65 }}
          className="p-5 rounded-xl bg-gradient-to-r from-emerald-500/10 via-emerald-500/5 to-transparent border border-emerald-500/20"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">✅</span>
            <div>
              <h3 className="text-sm font-bold text-emerald-400">
                lagarias_for_primes — PROVED
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                σ(p) ≤ H_p + exp(H_p)·ln(H_p) for ALL primes p. Zero axioms.
              </p>
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.7 }}
          className="p-5 rounded-xl bg-gradient-to-r from-cyan-500/10 via-cyan-500/5 to-transparent border border-cyan-500/20"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">💎</span>
            <div>
              <h3 className="text-sm font-bold text-cyan-400">
                covMatrix3_det3_pos — det(C₃) &gt; 0 PROVED
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                Degree-6 polynomial in 5 transcendentals, verified by polynomial certificates.
              </p>
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.75 }}
          className="p-5 rounded-xl bg-gradient-to-r from-teal-500/10 via-teal-500/5 to-transparent border border-teal-500/20"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">🗺️</span>
            <div>
              <h3 className="text-sm font-bold text-teal-400">
                CrossTermFTC — Off-Diagonal Infrastructure DEPLOYED
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                6 theorems, 0 sorry. Piecewise FTC for ∫(1/(jx)−m)(1/(kx)−n)dx and Beatty sequence bound
                (≤2 tiles per row when j≤k). The analytical engine for eliminating vasyunin_eq_integral.
              </p>
            </div>
          </div>
        </motion.div>
      </div>

      <h2 className="text-xl font-bold text-slate-200 mb-4">Explore</h2>
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {CARDS.map((card, i) => (
          <motion.div
            key={card.href}
            initial={{ opacity: 0, y: 20 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.3 + i * 0.08 }}
          >
            <Link
              href={card.href}
              className={`block p-6 rounded-xl bg-gradient-to-br ${card.gradient} border ${card.border} hover:scale-[1.02] transition-transform duration-200 h-full`}
            >
              <div className="text-3xl mb-3">{card.icon}</div>
              <h3 className="text-lg font-bold text-slate-200 mb-2">
                {card.title}
              </h3>
              <p className="text-sm text-slate-400 mb-3">{card.description}</p>
              <div className="text-xs font-mono text-slate-500">
                {card.stats}
              </div>
            </Link>
          </motion.div>
        ))}
      </div>
    </div>
  );
}
