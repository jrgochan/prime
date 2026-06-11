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
      "Interactive map of the Penta-Crown axioms. Five independent proof paths to RH: Overcancellation (2 PNT), Analytic (1 literature), Oracle (1 GPU), Gram (1 discrete), Arakelov (1 geometric).",
    icon: "\u{1F3DB}\uFE0F",
    stats: "5 crowns \u00B7 6 proof paths \u00B7 0 sorry on crown",
    gradient: "from-amber-500/20 to-red-500/20",
    border: "border-amber-500/20",
  },
  {
    href: "/penta-crown",
    title: "Penta-Crown Explorer",
    description:
      "Interactive diagram of the five independent proof paths to RH. Explore each crown's axiom footprint, key theorem, and mathematical technique.",
    icon: "\u{1F451}",
    stats: "5 paths \u00B7 6 routes \u00B7 interactive",
    gradient: "from-rose-500/20 to-violet-500/20",
    border: "border-rose-500/20",
  },
  {
    href: "/graduation-timeline",
    title: "Graduation Timeline",
    description:
      "Watch axioms fall from 6 to 1 across 65 days. The full history of the Cathedral from v1 to v26: every graduation, every bypass, every crowning moment.",
    icon: "\u{1F4C8}",
    stats: "v1\u2192v26 \u00B7 65 days \u00B7 20+ graduations",
    gradient: "from-rose-500/20 to-amber-500/20",
    border: "border-rose-500/20",
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
      "Interactive force-directed graph of every theorem, axiom, and definition. Trace dependency chains from the Penta-Crown down to Mathlib foundations.",
    icon: "\uD83C\uDF33",
    stats: "~4,600 theorems \u00B7 156 axioms \u00B7 474 files",
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
      "Visualize the N\u00D7N Gram matrix of fractional part inner products. See the GCD block structure and spectral gap that powers the Oracle Bridge.",
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
      "The proof architecture as a literal cathedral \u2014 the Penta-Crown (5 proof paths) holding the golden roof of RH \u27FA d\u00B2\u2099 \u2192 0.",
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
    label: "CONVERSE \u2014 PURE MATHLIB",
    name: "d\u00B2_N \u2192 0 \u27F9 RH",
    desc: "Zero custom axioms, zero sorry. The Rank-1 Mellin Miracle proves M[h\u2096](\u03C1) = 1/(k(\u03C1\u22121)) factorizes into rank-1 tensors. Cauchy-Schwarz separates off-critical zeros.",
    color: "from-emerald-500/10 to-transparent",
    borderColor: "border-emerald-500/20",
  },
  {
    label: "PATH 1 \u2014 OVERCANCELLATION",
    name: "2 PNT axioms \u27F9 RH",
    desc: "The cleanest path. overcancellation_implies_rh depends on exactly 2 PNT axioms (frac_error_isLittleO + pnt_mu_log_sq_div_k) plus Lean kernel. No custom axioms needed.",
    color: "from-rose-500/10 to-transparent",
    borderColor: "border-rose-500/20",
  },
  {
    label: "ANALYTIC CROWN",
    name: "1 lit. axiom \u27F9 RH",
    desc: "1 literature axiom (ba\u00E9z_duarte_forward, IMRN 2003). Pure mathematics \u2014 no computers. The continuous mathematical ideal.",
    color: "from-amber-500/10 to-transparent",
    borderColor: "border-amber-500/20",
  },
  {
    label: "ORACLE CROWN",
    name: "GPU \u27F9 RH",
    desc: "0 literature axioms. 1 trusted GPU computation (HPDF Gram matrices at highly composite numbers). Proves RH from certified eigenvalue bounds.",
    color: "from-cyan-500/10 to-transparent",
    borderColor: "border-cyan-500/20",
  },
  {
    label: "GRAM CROWN",
    name: "v\u1D40Gv \u2264 1+K/lnN \u27F9 RH",
    desc: "RH as a single discrete arithmetic inequality. Bypasses the covariance axiom entirely. 1 crown axiom + 5 PNT axioms.",
    color: "from-indigo-500/10 to-transparent",
    borderColor: "border-indigo-500/20",
  },
  {
    label: "ARAKELOV CROWN",
    name: "G = G\u2098\u2099 + G\u2090\u2093 \u27F9 RH",
    desc: "Algebraic-geometric path via Arakelov intersection pairing. Connects prime factorization to eigenvalue control via Smith's 1876 PSD theorem.",
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
          474 active files, 8,818 compiled targets. Penta-Crown architecture:
          5 independent proof paths, 6 routes to RH.
          <span className="text-amber-400 text-sm ml-1">v26 Penta-Crown</span>
        </p>

        <div className="flex gap-6 mt-6 text-sm flex-wrap">
          {[
            { color: "bg-emerald-500", text: "474 active files" },
            { color: "bg-red-500", text: "8,818 build targets" },
            { color: "bg-amber-500", text: "Penta-Crown (6 paths)" },
            { color: "bg-blue-500", text: "0 sorry on crown" },
            { color: "bg-purple-500", text: "~149,500 lines of Lean 4" },
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
        The Penta-Crown Architecture
      </h2>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4 mb-12">
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
            <span className="text-2xl">{"\u{1F451}"}</span>
            <div>
              <h3 className="text-sm font-bold text-amber-400">
                v26 &mdash; PENTA-CROWN (June 10, 2026)
              </h3>
              <p className="text-xs text-slate-500 mt-0.5">
                Penta-Crown architecture: Overcancellation (2 PNT axioms, cleanest path) +
                Analytic + Oracle + Gram + Arakelov. PATH 1 <code>overcancellation_implies_rh</code>.
                Glass Box graduation decomposes the sole axiom into 7 sub-axioms.
                474 files, ~149K lines. 8,818 build targets. 101 Standard Model theorems.
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
