"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";

/* ───────── data ───────── */

interface Axiom {
  name: string;
  math: string;
  desc: string;
  ref: string;
  tier: 1 | 2 | 3;
  onCrown: boolean;
}

const CROWN_AXIOMS: Axiom[] = [
  {
    name: "rh_implies_mertens_34",
    math: "RH → |M(x)| = O(x^{3/4})",
    desc: "The sole RH-content axiom. If the Riemann Hypothesis holds, the Mertens function M(x) = Σμ(n) grows no faster than x^{3/4}. This is the mathematical heart of the forward direction.",
    ref: "Titchmarsh 1986, Theorem 14.25",
    tier: 1,
    onCrown: true,
  },
  {
    name: "pnt_mu_div_k",
    math: "Σ μ(k)/k → 0",
    desc: "The first Möbius sum converges to zero. This is equivalent to the Prime Number Theorem — unconditionally true, proved by de la Vallée-Poussin in 1896.",
    ref: "Selberg 1949, de la Vallée-Poussin 1896",
    tier: 2,
    onCrown: true,
  },
  {
    name: "pnt_mu_log_div_k",
    math: "Σ μ(k)log(k)/k → -1",
    desc: "The logarithmically weighted Möbius sum. Controls the first-order correction in the log-cutoff witness. Unconditionally true — a deeper consequence of PNT.",
    ref: "Selberg 1949",
    tier: 2,
    onCrown: true,
  },
  {
    name: "pnt_mu_log_sq_div_k",
    math: "Σ μ(k)log²(k)/k → -2γ",
    desc: "The squared-log Möbius sum relates to the Euler-Mascheroni constant γ. Controls second-order asymptotics. Unconditionally true.",
    ref: "Selberg 1949, Euler 1740",
    tier: 2,
    onCrown: true,
  },
  {
    name: "abel_mertens_tail_raw",
    math: "Abel summation tail bounds",
    desc: "Bounds on the tail of Abel summation applied to the Mertens function. This is the engine that converts pointwise Mertens bounds into L² integral bounds on the witness function.",
    ref: "Abel 1826",
    tier: 3,
    onCrown: true,
  },
  {
    name: "millennium_covariance_cancellation",
    math: "2D covariance bound → 0",
    desc: "The deep covariance cancellation. The double sum ΣΣ v_j·v_k·(G_jk - b_j·b_k) vanishes as N→∞. This requires Parseval-level analysis in two dimensions.",
    ref: "Plancherel 1910",
    tier: 3,
    onCrown: true,
  },
  {
    name: "vasyunin_eq_integral",
    math: "G(j,k) = ∫₀¹ {1/(jx)}{1/(kx)} dx",
    desc: "The Gram matrix entry equals the L² inner product integral. Connects the algebraic matrix framework to the analytic L² setting. From Vasyunin's 1995 representation.",
    ref: "Vasyunin 1996, Báez-Duarte 2005",
    tier: 3,
    onCrown: true,
  },
];

const NON_CROWN_GROUPS = [
  {
    name: "Spectral Engine",
    count: 6,
    axioms: [
      "block_min_eq_class_min",
      "class_gap_strictly_larger",
      "oct_equals_block",
      "schur_bridge",
      "stable_ratio",
      "liouville_delocalization",
    ],
    desc: "Eigenvalue analysis via octonionic partition and class restriction.",
  },
  {
    name: "Sieve Engine",
    count: 7,
    axioms: [
      "stable_ratio_parity",
      "gram_eigenvalue_log_scaling",
      "eigenvalue_implies_distance_bound",
      "moebius_uncoupling",
      "type_II_sieve_bound",
      "vasyunin_large_gcd",
      "vaughan_decomposition",
    ],
    desc: "Bilinear sieve, Vaughan decomposition, and Möbius uncoupling.",
  },
  {
    name: "Mellin Bridge",
    count: 9,
    axioms: [
      "mertens_bound_from_rh",
      "abel_summation_l2_bound",
      "rh_implies_mertens_bound",
      "mellin_fourier_change",
      "fourier_inversion_autocorrelation",
      "gram_form_eq_l2_norm",
      "baezDuarte_is_L2",
      "baezDuarte_inner_one",
      "baezDuarte_inner_residual",
    ],
    desc: "Mellin/Fourier transform infrastructure and orthogonal witnesses.",
  },
  {
    name: "Other",
    count: 10,
    axioms: [
      "oct_gap_lower_bound",
      "type_I_bound",
      "drop_formula_bound",
      "abel_summation_covariance_bound",
      "bd_witness_l2_error_decay",
      "witness_covariance_decay",
      "witness_numerator_convergence",
      "witness_l2_error_decay_gram",
      "dirichlet_polynomial_mean_value_bound",
      "bd_gram_form_decay",
    ],
    desc: "Alternative proof paths, bypass engines, and witness constructions.",
  },
];

const TIER_COLORS = {
  1: {
    bg: "from-red-500/15 to-red-900/10",
    border: "border-red-500/40",
    text: "text-red-400",
    dot: "bg-red-500",
    glow: "shadow-red-500/20",
    label: "Tier 1 — RH Content",
    sublabel: "The only axiom that encodes actual RH information",
  },
  2: {
    bg: "from-blue-500/15 to-blue-900/10",
    border: "border-blue-500/40",
    text: "text-blue-400",
    dot: "bg-blue-500",
    glow: "shadow-blue-500/20",
    label: "Tier 2 — Prime Number Theorem",
    sublabel: "Unconditionally true (proved 1896), awaiting Lean formalization",
  },
  3: {
    bg: "from-emerald-500/15 to-emerald-900/10",
    border: "border-emerald-500/40",
    text: "text-emerald-400",
    dot: "bg-emerald-500",
    glow: "shadow-emerald-500/20",
    label: "Tier 3 — Classical Analysis",
    sublabel: "Well-known results in real/harmonic analysis",
  },
};

/* ───────── components ───────── */

function AxiomCard({ axiom, index }: { axiom: Axiom; index: number }) {
  const [expanded, setExpanded] = useState(false);
  const tier = TIER_COLORS[axiom.tier];

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ delay: 0.15 + index * 0.08 }}
      onClick={() => setExpanded(!expanded)}
      className={`
        cursor-pointer rounded-xl p-5
        bg-gradient-to-br ${tier.bg}
        border ${tier.border}
        hover:shadow-lg ${tier.glow}
        transition-all duration-300
      `}
    >
      <div className="flex items-start gap-3">
        <div className="flex flex-col items-center gap-1 pt-0.5">
          <div
            className={`w-8 h-8 rounded-full ${tier.dot} flex items-center justify-center text-white font-bold text-sm shadow-lg`}
          >
            {index + 1}
          </div>
          <div className={`text-[9px] font-mono ${tier.text} opacity-70`}>
            T{axiom.tier}
          </div>
        </div>
        <div className="flex-1 min-w-0">
          <code className={`text-sm font-bold ${tier.text} break-all`}>
            {axiom.name}
          </code>
          <div className="text-slate-300 text-sm mt-1 font-mono">
            {axiom.math}
          </div>
        </div>
      </div>

      <AnimatePresence>
        {expanded && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.25 }}
            className="overflow-hidden"
          >
            <div className="mt-4 pt-3 border-t border-slate-700/50 space-y-2">
              <p className="text-xs text-slate-400 leading-relaxed">
                {axiom.desc}
              </p>
              <p className="text-[10px] text-slate-600 font-mono">
                📚 {axiom.ref}
              </p>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

function ConverseBanner() {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.95 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ delay: 0.9 }}
      className="p-6 rounded-xl bg-gradient-to-r from-emerald-500/10 via-emerald-500/5 to-transparent border border-emerald-500/30"
    >
      <div className="flex items-center gap-4">
        <div className="w-16 h-16 rounded-2xl bg-emerald-500/20 border border-emerald-500/30 flex items-center justify-center">
          <span className="text-3xl">✅</span>
        </div>
        <div>
          <h3 className="text-lg font-bold text-emerald-400">
            Converse Direction: d²_N → 0 ⟹ RH
          </h3>
          <p className="text-sm text-slate-400 mt-1">
            <span className="text-emerald-400 font-bold text-lg">
              0 custom axioms
            </span>{" "}
            — Pure Lean / Mathlib. The Rank-1 Mellin Miracle and contrapositive
            argument require no additional assumptions beyond the Lean kernel.
          </p>
          <p className="text-xs text-slate-600 mt-2 font-mono">
            propext + Classical.choice + Quot.sound (Lean kernel only)
          </p>
        </div>
      </div>
    </motion.div>
  );
}

function NonCrownSection() {
  const [expandedGroup, setExpandedGroup] = useState<string | null>(null);

  return (
    <div className="space-y-3">
      <h3 className="text-sm font-bold text-slate-500 uppercase tracking-wider">
        32 Supporting Axioms (not on crown path)
      </h3>
      <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
        {NON_CROWN_GROUPS.map((group) => (
          <motion.div
            key={group.name}
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 1.1 }}
            onClick={() =>
              setExpandedGroup(
                expandedGroup === group.name ? null : group.name
              )
            }
            className="cursor-pointer p-4 rounded-xl bg-slate-800/50 border border-slate-700/50 hover:border-slate-600/50 transition-all"
          >
            <div className="flex items-center justify-between">
              <div>
                <h4 className="text-sm font-bold text-slate-300">
                  {group.name}
                </h4>
                <p className="text-xs text-slate-500 mt-0.5">{group.desc}</p>
              </div>
              <div className="text-lg font-bold text-slate-600">
                {group.count}
              </div>
            </div>
            <AnimatePresence>
              {expandedGroup === group.name && (
                <motion.div
                  initial={{ height: 0, opacity: 0 }}
                  animate={{ height: "auto", opacity: 1 }}
                  exit={{ height: 0, opacity: 0 }}
                  className="overflow-hidden"
                >
                  <div className="mt-3 pt-3 border-t border-slate-700/30 flex flex-wrap gap-1.5">
                    {group.axioms.map((a) => (
                      <code
                        key={a}
                        className="text-[10px] px-2 py-0.5 rounded bg-slate-700/50 text-slate-400"
                      >
                        {a}
                      </code>
                    ))}
                  </div>
                </motion.div>
              )}
            </AnimatePresence>
          </motion.div>
        ))}
      </div>
    </div>
  );
}

/* ───────── page ───────── */

export default function AxiomMapPage() {
  return (
    <div className="p-8 max-w-5xl mx-auto space-y-10">
      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
      >
        <Link
          href="/"
          className="text-xs text-slate-600 hover:text-slate-400 transition-colors"
        >
          ← Back to Cathedral
        </Link>
        <h1 className="text-3xl font-bold mt-3">
          <span className="bg-gradient-to-r from-red-400 via-blue-400 to-emerald-400 bg-clip-text text-transparent">
            Axiom Architecture
          </span>
        </h1>
        <p className="text-slate-400 mt-2 max-w-2xl">
          The crown theorem{" "}
          <code className="text-amber-400/80">
            nyman_beurling_equivalence
          </code>{" "}
          depends on exactly <strong className="text-white">7</strong>{" "}
          mathematical axioms, organized into three tiers. The converse
          direction uses <strong className="text-emerald-400">zero</strong>{" "}
          custom axioms.
        </p>
      </motion.div>

      {/* Visual summary bar */}
      <motion.div
        initial={{ opacity: 0, scaleX: 0.8 }}
        animate={{ opacity: 1, scaleX: 1 }}
        transition={{ delay: 0.2 }}
        className="flex rounded-xl overflow-hidden h-10"
      >
        <div
          className="bg-gradient-to-r from-red-600 to-red-500 flex items-center justify-center"
          style={{ width: `${(1 / 7) * 100}%` }}
        >
          <span className="text-[10px] font-bold text-white">RH</span>
        </div>
        <div
          className="bg-gradient-to-r from-blue-600 to-blue-500 flex items-center justify-center"
          style={{ width: `${(3 / 7) * 100}%` }}
        >
          <span className="text-[10px] font-bold text-white">
            PNT (3)
          </span>
        </div>
        <div
          className="bg-gradient-to-r from-emerald-600 to-emerald-500 flex items-center justify-center"
          style={{ width: `${(3 / 7) * 100}%` }}
        >
          <span className="text-[10px] font-bold text-white">
            Classical (3)
          </span>
        </div>
      </motion.div>

      {/* Tier legend */}
      <div className="flex flex-wrap gap-6 text-xs">
        {([1, 2, 3] as const).map((t) => {
          const tier = TIER_COLORS[t];
          return (
            <div key={t} className="flex items-center gap-2">
              <div className={`w-3 h-3 rounded-full ${tier.dot}`} />
              <div>
                <span className={`font-bold ${tier.text}`}>{tier.label}</span>
                <span className="text-slate-600 ml-1.5">
                  {tier.sublabel}
                </span>
              </div>
            </div>
          );
        })}
      </div>

      {/* Forward direction: 7 axioms */}
      <div>
        <h2 className="text-lg font-bold text-slate-200 mb-1 flex items-center gap-2">
          <span className="text-amber-400">▶</span>
          Forward: RH ⟹ d²_N → 0
        </h2>
        <p className="text-xs text-slate-500 mb-4">
          Click any axiom to learn more. All 7 are on the crown path.
        </p>
        <div className="space-y-3">
          {CROWN_AXIOMS.map((axiom, i) => (
            <AxiomCard key={axiom.name} axiom={axiom} index={i} />
          ))}
        </div>
      </div>

      {/* Converse: 0 axioms */}
      <div>
        <h2 className="text-lg font-bold text-slate-200 mb-3 flex items-center gap-2">
          <span className="text-emerald-400">◀</span>
          Converse: d²_N → 0 ⟹ RH
        </h2>
        <ConverseBanner />
      </div>

      {/* Non-crown axioms */}
      <NonCrownSection />

      {/* Footer */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.3 }}
        className="text-center text-xs text-slate-600 pt-4 border-t border-slate-800"
      >
        <code>#print axioms nyman_beurling_equivalence</code> — compiler
        verified, April 19, 2026
      </motion.div>
    </div>
  );
}
