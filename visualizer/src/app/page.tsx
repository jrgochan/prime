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
    href: "/axiom-map",
    title: "Axiom Architecture",
    description:
      "Interactive map of the 1 crown axiom: ba\u00E9z_duarte_forward (IMRN 2003). The One-Pillar architecture. Click to explore its role and mathematical statement.",
    icon: "\u{1F3DB}\uFE0F",
    stats: "1 crown \u00B7 ~50 total \u00B7 0 on converse",
    gradient: "from-amber-500/20 to-red-500/20",
    border: "border-amber-500/20",
  },
  {
    href: "/term-explorer",
    title: "Term Explorer",
    description:
      "Interactively explore the Vasyunin formula term by term. Toggle dimensions, inspect matrix entries, visualize the log cutoff witness, and walk the proof chain.",
    icon: "\uD83D\uDD2C",
    stats: "4 terms \u00B7 live computation \u00B7 interactive",
    gradient: "from-violet-500/20 to-purple-500/20",
    border: "border-violet-500/20",
  },
  {
    href: "/proof-tree",
    title: "Proof Dependency Tree",
    description:
      "Interactive force-directed graph of every theorem, axiom, and definition. Trace dependency chains and explore the critical path.",
    icon: "\uD83C\uDF33",
    stats: "~1,500+ theorems \u00B7 ~50 axioms \u00B7 308 files",
    gradient: "from-emerald-500/20 to-teal-500/20",
    border: "border-emerald-500/20",
  },
  {
    href: "/robin-lagarias",
    title: "Robin\u2013Lagarias Dashboard",
    description:
      "The freshly-proved lagarias_for_primes theorem visualized: \u03C3(p) vs the Lagarias bound for every prime, with the algebraic bypass and Taylor truncation.",
    icon: "\uD83C\uDFC6",
    stats: "PROVED \u00B7 0 sorry \u00B7 milestone",
    gradient: "from-amber-500/20 to-orange-500/20",
    border: "border-amber-500/20",
  },
  {
    href: "/gram-heatmap",
    title: "Gram Matrix Heatmap",
    description:
      "Visualize the N\u00D7N Gram matrix of fractional part inner products. See the structure that makes the proof work.",
    icon: "\uD83D\uDD25",
    stats: "N up to 80 \u00B7 live computation",
    gradient: "from-orange-500/20 to-red-500/20",
    border: "border-orange-500/20",
  },
  {
    href: "/sawtooth",
    title: "Sawtooth Discovery",
    description:
      "Watch the covariance stabilize instead of decaying \u2014 the moment formal verification caught a subtle error.",
    icon: "\uD83D\uDCD0",
    stats: "C\u221E \u2248 0.00227",
    gradient: "from-blue-500/20 to-purple-500/20",
    border: "border-blue-500/20",
  },
  {
    href: "/offdiag-margin",
    title: "Off-Diagonal Excess",
    description:
      "The running sum of off-diagonal Gram excess vs the 3n bound \u2014 visualizing the structural margin in the Cathedral.",
    icon: "\uD83D\uDCCA",
    stats: "18\u00D7 margin at N=50",
    gradient: "from-cyan-500/20 to-teal-500/20",
    border: "border-cyan-500/20",
  },
  {
    href: "/fractional-waves",
    title: "Fractional Part Waves",
    description:
      "Toggle sawtooth functions {k/x} and their products to see how Gram matrix entries arise from wave interference.",
    icon: "\uD83C\uDF0A",
    stats: "k = 1 to 8 \u00B7 interactive",
    gradient: "from-indigo-500/20 to-blue-500/20",
    border: "border-indigo-500/20",
  },
  {
    href: "/hyperplane-trap",
    title: "The Hyperplane Trap",
    description:
      "3D surface of the Mellin residual showing why spoofing weights cannot escape the Cauchy-Schwarz bound in the B\u00E1ez-Duarte proof.",
    icon: "\uD83D\uDD73\uFE0F",
    stats: "3D \u00B7 R3F interactive",
    gradient: "from-red-500/20 to-pink-500/20",
    border: "border-red-500/20",
  },
  {
    href: "/cathedral-3d",
    title: "Cathedral 3D",
    description:
      "The proof architecture as a literal cathedral \u2014 one pillar (ba\u00E9z_duarte_forward) holding the golden roof of RH \u27FA d\u00B2\u2099 \u2192 0.",
    icon: "\u26EA",
    stats: "3D \u00B7 auto-rotates",
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
    label: "PILLAR I \u2014 CONVERSE",
    name: "d\u00B2_N \u2192 0 \u27F9 RH",
    desc: "PURE MATHLIB: Zero custom axioms, zero sorry. The Rank-1 Mellin Miracle proves M[h\u2096](\u03C1) = 1/(k(\u03C1\u22121)) factorizes into rank-1 tensors, Cauchy-Schwarz separates off-critical zeros.",
    color: "from-emerald-500/10 to-transparent",
    borderColor: "border-emerald-500/20",
  },
  {
    label: "PILLAR \u2014 FORWARD (ONE-PILLAR)",
    name: "RH \u27F9 d\u00B2_N \u2192 0",
    desc: "1 axiom (ba\u00E9z_duarte_forward), 0 sorry on crown path. The BD forward direction (IMRN 2003) directly gives d\u00B2_N \u2192 0 under RH. Alternative paths: Mellin (2 axioms), Perron (4 axioms).",
    color: "from-amber-500/10 to-transparent",
    borderColor: "border-amber-500/20",
  },
  {
    label: "CAPSTONE",
    name: "RH \u27FA d\u00B2_N \u2192 0",
    desc: "Assembly layer chains both directions via nyman_beurling_equivalence. The crown theorem is the \u27FA of the two pillars. 6 capstone files in Assembly/.",
    color: "from-violet-500/10 to-transparent",
    borderColor: "border-violet-500/20",
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
          A machine-checked reduction of the Riemann Hypothesis in Lean 4.
          308 active files. ~50 axioms &mdash; one on the crown theorem&apos;s critical path.
          Zero custom axioms on the converse.
          <span className="text-amber-400 text-sm ml-1">v16 Observatory</span>
        </p>

        <div className="flex gap-6 mt-6 text-sm flex-wrap">
          {[
            { color: "bg-emerald-500", text: "308 active files" },
            { color: "bg-red-500", text: "~1,500+ theorems" },
            { color: "bg-amber-500", text: "~50 axioms (1 on crown)" },
            { color: "bg-blue-500", text: "0 sorry on crown" },
            { color: "bg-purple-500", text: "78,435 lines of Lean 4" },
          ].map((item) => (
            <div key={item.text} className="flex items-center gap-2">
              <div className={`w-2.5 h-2.5 rounded-full ${item.color}`} />
              <span className="text-slate-300">{item.text}</span>
            </div>
          ))}
        </div>
      </motion.div>

      {/* Two Pillars */}
      <h2 className="text-xl font-bold text-slate-200 mb-4">
        The One-Pillar Architecture
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
          transition={{ delay: 0.45 }}
          className="p-5 rounded-xl bg-gradient-to-r from-amber-500/10 via-amber-500/5 to-transparent border border-amber-500/20"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">{"\u{1F3DB}\uFE0F"}</span>
            <div>
              <h3 className="text-sm font-bold text-amber-400">
                v16 &mdash; OBSERVATORY EDITION (May 6, 2026)
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                One-Pillar Cathedral: <code>baez_duarte_forward</code> as sole crown axiom.
                DD-precision pipeline (Dekker&ndash;Knuth) certifies N=55,440 Gram matrices.
                N=20,000 witness scan confirms d&sup2; &sim; 0.43/ln(N) scaling law.
                96% vacuum reconstruction. 308 files, 78,435 lines, 15 papers.
              </p>
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.48 }}
          className="p-5 rounded-xl bg-gradient-to-r from-emerald-500/10 via-emerald-500/5 to-transparent border border-emerald-500/20"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">{"\u{1F451}"}</span>
            <div>
              <h3 className="text-sm font-bold text-emerald-400">
                v10 &mdash; FOUR WALLS (April 25, 2026)
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                Crown theorem <code>nyman_beurling_equivalence</code> verified by <code>#print axioms</code>:
                exactly 4 non-kernel axioms. <code>gram_form_upper_bound_34</code> graduated via variance decomposition.
                Converse direction: PURE MATHLIB (zero custom axioms).
              </p>
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.50 }}
          className="p-5 rounded-xl bg-gradient-to-r from-violet-500/10 via-violet-500/5 to-transparent border border-violet-500/30"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">{"\u26A1"}</span>
            <div>
              <h3 className="text-sm font-bold text-violet-400">
                v9 &mdash; ABEL BYPASS (April 24, 2026)
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                <code>pnt_mu_log_sq_div_k</code> ELIMINATED via S&#x2083; uniform bound.
                Instead of proving &Sigma; &mu;(k)log&sup2;(k)/k &rarr; &minus;2&gamma;, proved the S&#x2083; term is uniformly bounded,
                bypassing Tauberian machinery entirely.
              </p>
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.52 }}
          className="p-5 rounded-xl bg-gradient-to-r from-orange-500/10 via-amber-600/5 to-transparent border border-orange-500/30"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">{"\uD83D\uDD25"}</span>
            <div>
              <h3 className="text-sm font-bold text-orange-400">
                v7 &mdash; PERRON CROWN (April 20&ndash;22, 2026)
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                <code>rh_implies_mertens_bound</code> GRADUATED: 16-file Perron contour formula chain proves
                RH &rArr; |M(x)| = O(x&#xBD;&#x207A;&#x03B5;). <code>pnt_mu_div_k</code> GRADUATED via PrimeNumberTheoremAnd library bridge.
              </p>
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.54 }}
          className="p-5 rounded-xl bg-gradient-to-r from-indigo-500/10 via-indigo-500/5 to-transparent border border-indigo-500/20"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">{"\uD83E\uDE9E"}</span>
            <div>
              <h3 className="text-sm font-bold text-indigo-400">
                Digamma Reflection &mdash; &psi;(1&minus;s) &minus; &psi;(s) = &pi;&middot;cot(&pi;s) PROVED
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                Proved via logDeriv of Mathlib&apos;s Gamma reflection &Gamma;(s)&Gamma;(1&minus;s) = &pi;/sin(&pi;s).
                April 14, 2026.
              </p>
            </div>
          </div>
        </motion.div>
        <motion.div
          initial={{ opacity: 0, scale: 0.98 }}
          animate={{ opacity: 1, scale: 1 }}
          transition={{ delay: 0.56 }}
          className="p-5 rounded-xl bg-gradient-to-r from-cyan-500/10 via-cyan-500/5 to-transparent border border-cyan-500/20"
        >
          <div className="flex items-center gap-3">
            <span className="text-2xl">{"\uD83D\uDD2C"}</span>
            <div>
              <h3 className="text-sm font-bold text-cyan-400">
                Rank-1 Mellin Miracle &mdash; Converse PURE MATHLIB
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                M[h&#x2096;](&rho;) = 1/(k(&rho;&minus;1)) factorizes as rank-1 tensor at every zeta zero.
                Cauchy-Schwarz separation proves d&sup2; &gt; 0 for off-critical zeros.
                Re(&Lambda;&#x2080;(s)) &lt; 4 for s &isin; (0,1) via Jacobi theta. Zero axioms, zero sorry.
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
