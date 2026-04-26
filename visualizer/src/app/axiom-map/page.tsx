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
  tier: 1 | 2 | 3 | 4;
  file: string;
  onCrown: boolean;
}

const CROWN_AXIOMS: Axiom[] = [
  {
    name: "pnt_mu_log_div_k",
    math: "\u03A3 \u03BC(k)\u00B7log(k)/k \u2192 \u22121",
    desc: "The logarithmically weighted M\u00F6bius sum converges to \u22121. This is a derivative-level consequence of the Prime Number Theorem \u2014 unconditionally true. Controls the first-order correction in the log-cutoff witness. Awaits a forward Tauberian theorem (Wiener\u2013Ikehara) in Lean.",
    ref: "Selberg 1949, Wiener-Ikehara",
    tier: 1,
    file: "PNT/AbelMean.lean",
    onCrown: true,
  },
  {
    name: "covariance_bound_from_mertens_34",
    math: "|M(x)| \u2264 Cx\u00BE \u27F9 v\u1D40Cv \u2264 C/log N",
    desc: "The bilinear covariance bound: under the Mertens x\u00BE hypothesis, the centered Gram quadratic form v\u1D40(G\u2212bb\u1D40)v = O(1/log N). Infrastructure in place (s\u2081_decay, s\u2082_decay, s\u2083_uniform_bound proved). Needs direct Abel summation on the double sum.",
    ref: "Abel summation, partial summation",
    tier: 2,
    file: "Covariance/GramFormProof.lean",
    onCrown: true,
  },
  {
    name: "partial_integral_tends_to_formula",
    math: "\u222B\u2080\u00B9 {1/(jx)}{1/(kx)} dx = Vasyunin formula",
    desc: "The piecewise integral of fractional parts converges to the Vasyunin cotangent formula for off-diagonal Gram entries. Diagonal case (j=k) is fully proved. Off-diagonal requires Gauss digamma formula and dominated convergence. Blueprint exists in Archive/DiscreteMirage/.",
    ref: "Vasyunin 1996, B\u00E1ez-Duarte 2005",
    tier: 3,
    file: "Vasyunin/Cotangent/ConvergenceAxioms.lean",
    onCrown: true,
  },
  {
    name: "rh_zeta_lower_bound_from_zero_counting",
    math: "|\u03B6(s)| \u2265 c/|t|^A for Re(s) \u2265 \u00BD+\u03B5",
    desc: "Under RH, the Riemann zeta function has a polynomial lower bound. Derived from the Hadamard product formula and Riemann-von Mangoldt zero-counting function N(T). Powers the Perron contour chain. Borel-Carath\u00E9odory is in Mathlib; the gap is connecting BC to the polynomial bound.",
    ref: "Titchmarsh 1986, Hadamard product",
    tier: 4,
    file: "Zeta/Hadamard.lean",
    onCrown: true,
  },
];

const NON_CROWN_GROUPS = [
  {
    name: "Legacy / Graduated",
    count: 8,
    axioms: [
      "gram_form_upper_bound",
      "pnt_mu_log_sq_div_k",
      "rh_implies_mertens_bound",
      "abel_summation_covariance_bound",
      "gauss_digamma_formula",
      "bd_witness_l2_error_decay",
      "dirichlet_polynomial_mean_value_bound",
      "drop_formula_bound",
    ],
    desc: "Superseded by newer proof paths. Not on the crown theorem\u2019s dependency chain.",
  },
  {
    name: "Resurrected (Isolated)",
    count: 7,
    axioms: [
      "nyman_beurling_equivalence (BaezDuarte ns)",
      "baez_duarte_covariance_divergence",
      "schur_complement_lower",
      "cross_norm_bound",
      "mertens_squarefree_sum",
      "mertens_tapered_sum",
      "mertens_linear_tapered_sum",
    ],
    desc: "Sorry-free files resurrected from Archive. Self-contained, no import path to crown theorem.",
  },
  {
    name: "Spectral Engine",
    count: 7,
    axioms: [
      "block_min_eq_class_min",
      "class_gap_strictly_larger",
      "oct_equals_block",
      "schur_bridge",
      "stable_ratio",
      "liouville_delocalization",
      "oct_gap_lower_bound",
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
      "vaughan_decomposition",
      "type_I_bound",
    ],
    desc: "Bilinear sieve, Vaughan decomposition, and M\u00F6bius uncoupling.",
  },
  {
    name: "MellinBridge",
    count: 8,
    axioms: [
      "mellin_fourier_change",
      "fourier_inversion_autocorrelation",
      "gram_form_eq_l2_norm",
      "mertens_bound_from_rh",
      "abel_summation_l2_bound",
      "baezDuarte_is_L2",
      "baezDuarte_inner_one",
      "baezDuarte_inner_residual",
    ],
    desc: "Mellin/Fourier transform infrastructure and orthogonal witnesses.",
  },
  {
    name: "Analysis & Computation",
    count: 11,
    axioms: [
      "selbergMajorant (def)",
      "selbergMajorant_ge_one_of_pos",
      "selbergMajorant_le_neg_one_of_neg",
      "selbergMajorant_integrable",
      "selbergMajorant_integral",
      "selbergMajorant_fourier_support",
      "montgomery_vaughan_bound",
      "vasyunin_large_gcd",
      "oracle_lambda_min_positive_2000",
      "oracle_witness_bound_100",
      "oracle_witness_bound_1000",
    ],
    desc: "Selberg majorant (7), Vasyunin (1), certified oracle computations (3).",
  },
  {
    name: "Vasyunin Proof Chain",
    count: 2,
    axioms: [
      "witness_numerator_convergence",
      "witness_covariance_decay",
    ],
    desc: "Witness construction infrastructure for alternative proof paths.",
  },
];

const TIER_COLORS: Record<number, {
  bg: string;
  border: string;
  text: string;
  dot: string;
  glow: string;
  label: string;
  sublabel: string;
}> = {
  1: {
    bg: "from-blue-500/15 to-blue-900/10",
    border: "border-blue-500/40",
    text: "text-blue-400",
    dot: "bg-blue-500",
    glow: "shadow-blue-500/20",
    label: "Tier 1 \u2014 PNT",
    sublabel: "Unconditionally true, awaiting Tauberian formalization",
  },
  2: {
    bg: "from-amber-500/15 to-amber-900/10",
    border: "border-amber-500/40",
    text: "text-amber-400",
    dot: "bg-amber-500",
    glow: "shadow-amber-500/20",
    label: "Tier 2 \u2014 Abel Summation",
    sublabel: "Direct bilinear form computation",
  },
  3: {
    bg: "from-emerald-500/15 to-emerald-900/10",
    border: "border-emerald-500/40",
    text: "text-emerald-400",
    dot: "bg-emerald-500",
    glow: "shadow-emerald-500/20",
    label: "Tier 3 \u2014 Vasyunin Convergence",
    sublabel: "Piecewise integral \u2192 cotangent formula",
  },
  4: {
    bg: "from-red-500/15 to-red-900/10",
    border: "border-red-500/40",
    text: "text-red-400",
    dot: "bg-red-500",
    glow: "shadow-red-500/20",
    label: "Tier 4 \u2014 Hadamard",
    sublabel: "Zeta lower bound via zero-counting (conditional on RH)",
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
          <div className="text-[10px] text-slate-600 font-mono mt-1">
            {axiom.file}
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
                {"\uD83D\uDCDA"} {axiom.ref}
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
          <span className="text-3xl">{"\u2705"}</span>
        </div>
        <div>
          <h3 className="text-lg font-bold text-emerald-400">
            Converse Direction: d\u00B2_N \u2192 0 \u27F9 RH
          </h3>
          <p className="text-sm text-slate-400 mt-1">
            <span className="text-emerald-400 font-bold text-lg">
              0 custom axioms
            </span>{" "}
            &mdash; Pure Lean / Mathlib. The Rank-1 Mellin Miracle and contrapositive
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
  const totalNonCrown = NON_CROWN_GROUPS.reduce((s, g) => s + g.count, 0);

  return (
    <div className="space-y-3">
      <h3 className="text-sm font-bold text-slate-500 uppercase tracking-wider">
        {totalNonCrown} Supporting Axioms (not on crown path)
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
          &larr; Back to Cathedral
        </Link>
        <h1 className="text-3xl font-bold mt-3">
          <span className="bg-gradient-to-r from-blue-400 via-amber-400 to-red-400 bg-clip-text text-transparent">
            Axiom Architecture
          </span>
        </h1>
        <p className="text-slate-400 mt-2 max-w-2xl">
          The crown theorem{" "}
          <code className="text-amber-400/80">
            nyman_beurling_equivalence
          </code>{" "}
          depends on exactly <strong className="text-white">4</strong>{" "}
          mathematical axioms, each in a different tier. The converse
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
          className="bg-gradient-to-r from-blue-600 to-blue-500 flex items-center justify-center"
          style={{ width: "25%" }}
        >
          <span className="text-[10px] font-bold text-white">PNT</span>
        </div>
        <div
          className="bg-gradient-to-r from-amber-600 to-amber-500 flex items-center justify-center"
          style={{ width: "25%" }}
        >
          <span className="text-[10px] font-bold text-white">Abel</span>
        </div>
        <div
          className="bg-gradient-to-r from-emerald-600 to-emerald-500 flex items-center justify-center"
          style={{ width: "25%" }}
        >
          <span className="text-[10px] font-bold text-white">Vasyunin</span>
        </div>
        <div
          className="bg-gradient-to-r from-red-600 to-red-500 flex items-center justify-center"
          style={{ width: "25%" }}
        >
          <span className="text-[10px] font-bold text-white">Hadamard</span>
        </div>
      </motion.div>

      {/* Tier legend */}
      <div className="flex flex-wrap gap-6 text-xs">
        {([1, 2, 3, 4] as const).map((t) => {
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

      {/* Forward direction: 4 axioms */}
      <div>
        <h2 className="text-lg font-bold text-slate-200 mb-1 flex items-center gap-2">
          <span className="text-amber-400">{"\u25B6"}</span>
          Forward: RH {"\u27F9"} d{"\u00B2"}_N {"\u2192"} 0
        </h2>
        <p className="text-xs text-slate-500 mb-4">
          Click any axiom to learn more. All 4 are on the crown path.
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
          <span className="text-emerald-400">{"\u25C0"}</span>
          Converse: d{"\u00B2"}_N {"\u2192"} 0 {"\u27F9"} RH
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
        <code>#print axioms nyman_beurling_equivalence</code> &mdash; compiler
        verified, v11, April 26, 2026
      </motion.div>
    </div>
  );
}
