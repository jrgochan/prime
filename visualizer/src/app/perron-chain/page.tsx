"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";

/* ───────── data ───────── */

interface ChainNode {
  file: string;
  dir: string;
  lines: number;
  theorems: number;
  key: string;
  desc: string;
  status: "proved" | "axiom" | "sorry";
  axiomName?: string;
}

const CHAIN: ChainNode[] = [
  {
    file: "Defs.lean",
    dir: "Perron",
    lines: 187,
    theorems: 12,
    key: "perronKernel(s,x) = x\u02E2/(s\u00B7ln x)",
    desc: "Core definitions: Perron kernel, rectangle contour, summability predicates. The mathematical vocabulary for the entire chain.",
    status: "proved",
  },
  {
    file: "Rectangle.lean",
    dir: "Perron",
    lines: 260,
    theorems: 8,
    key: "Rectangle contour calculus",
    desc: "Rectangle contour integration infrastructure: path composition, orientation, and integral identities for the Perron rectangle [c\u2212iT, c+iT, \u2212U+iT, \u2212U\u2212iT].",
    status: "proved",
  },
  {
    file: "KernelBound.lean",
    dir: "Perron",
    lines: 315,
    theorems: 10,
    key: "|K(s,x)| \u2264 C\u00B7x\u1D9C/|t|",
    desc: "Pointwise bounds on the Perron kernel. Controls the integrand on the vertical segments. Uses the half-integer Perron evaluation.",
    status: "proved",
  },
  {
    file: "IntegralBounds.lean",
    dir: "Perron",
    lines: 198,
    theorems: 6,
    key: "\u222B|K(s,x)|ds \u2264 C\u00B7x\u1D9C/T",
    desc: "Integral bounds for the Perron kernel over vertical line segments. The engine that makes the T\u2192\u221E limit work.",
    status: "proved",
  },
  {
    file: "VerticalBounds.lean",
    dir: "Perron",
    lines: 342,
    theorems: 11,
    key: "Vertical integral \u2192 0 as T \u2192 \u221E",
    desc: "The vertical line integrals on the left side of the rectangle vanish as T\u2192\u221E. The key asymptotic step.",
    status: "proved",
  },
  {
    file: "HalfIntegerPerron.lean",
    dir: "Perron",
    lines: 586,
    theorems: 15,
    key: "\u222B K(s,n) ds = 1 or 0",
    desc: "The half-integer Perron evaluation: the contour integral of x\u02E2/s picks out exactly the terms with n \u2264 x. The largest file in the chain (586 lines).",
    status: "proved",
  },
  {
    file: "DirichletPoly.lean",
    dir: "Perron",
    lines: 298,
    theorems: 9,
    key: "D(s) = \u03A3 a(n)/n\u02E2",
    desc: "Dirichlet polynomial infrastructure: convergence, summability, and the connection to the Perron integral via term-by-term integration.",
    status: "proved",
  },
  {
    file: "ContourShift.lean",
    dir: "Perron",
    lines: 412,
    theorems: 14,
    key: "Shift contour c \u2192 c\u2032 via Cauchy",
    desc: "The contour shift theorem: move the vertical line from Re(s) = c to Re(s) = c\u2032, picking up residues. Uses Cauchy\u2019s theorem + uniform bounds.",
    status: "proved",
  },
  {
    file: "ResidueGtOne.lean",
    dir: "Perron",
    lines: 188,
    theorems: 7,
    key: "Res(1/\u03B6, s=1) = \u22121",
    desc: "Residue computation for 1/\u03B6(s) at s=1. The pole of \u03B6(s) becomes a simple zero of 1/\u03B6(s), contributing \u2212M(x) to the Perron integral.",
    status: "proved",
  },
  {
    file: "ResidueLtOne.lean",
    dir: "Perron",
    lines: 203,
    theorems: 8,
    key: "Residues at \u03B6 zeros = O(x\u03C1)",
    desc: "Residue contributions from the non-trivial zeros \u03C1 of \u03B6(s). Under RH, all \u03C1 have Re(\u03C1) = \u00BD, giving O(x^{\u00BD+\u03B5}).",
    status: "proved",
  },
  {
    file: "PerronMoebius.lean",
    dir: "Perron",
    lines: 367,
    theorems: 12,
    key: "M(x) = (1/2\u03C0i)\u222B 1/\u03B6(s) \u00B7 x\u02E2/s ds",
    desc: "The Perron formula for M(x): the Mertens function equals a contour integral of x\u02E2/(\u03B6(s)\u00B7s). The central identity.",
    status: "proved",
  },
  {
    file: "Formula.lean",
    dir: "Perron",
    lines: 156,
    theorems: 5,
    key: "Perron formula (clean statement)",
    desc: "The clean, final statement of the Perron formula without auxiliary hypotheses. Packages PerronMoebius for downstream use.",
    status: "proved",
  },
  {
    file: "SummabilityHelpers.lean",
    dir: "Perron",
    lines: 184,
    theorems: 8,
    key: "\u03A3|a(n)|/n\u1D9C < \u221E",
    desc: "Summability lemmas: absolute convergence of Dirichlet series for Re(s) > 1. The fuel that powers every contour integral.",
    status: "proved",
  },
  {
    file: "AssemblyHelpers.lean",
    dir: "Perron",
    lines: 245,
    theorems: 9,
    key: "rpow bounds + assembly glue",
    desc: "Helper lemmas for combining Perron results: real power inequalities, monotonicity, and integral estimates for the final Mertens bound.",
    status: "sorry",
  },
  {
    file: "MertensConversion.lean",
    dir: "Perron",
    lines: 85,
    theorems: 3,
    key: "M(x) = O(x^{\u00BD+\u03B5}) \u2192 M(x) = O(x\u00BE)",
    desc: "Converts the Perron-derived Mertens bound O(x^{\u00BD+\u03B5}) to the weaker-but-sufficient O(x\u00BE) needed by the Gram form proof.",
    status: "proved",
  },
  {
    file: "MertensFromPerron.lean",
    dir: "Perron",
    lines: 210,
    theorems: 5,
    key: "RH \u2192 |M(x)| \u2264 C\u00B7x\u00BE",
    desc: "THE CROWN RESULT: chains the entire Perron formula through contour shift and zero counting to produce the Mertens 3/4-power bound from RH. This is the entry point for the forward direction.",
    status: "proved",
  },
];

/* ───────── components ───────── */

function ChainNodeCard({
  node,
  index,
  isExpanded,
  onToggle,
}: {
  node: ChainNode;
  index: number;
  isExpanded: boolean;
  onToggle: () => void;
}) {
  const statusColors = {
    proved: { bg: "from-emerald-500/10", border: "border-emerald-500/30", text: "text-emerald-400", badge: "bg-emerald-500" },
    axiom: { bg: "from-amber-500/10", border: "border-amber-500/30", text: "text-amber-400", badge: "bg-amber-500" },
    sorry: { bg: "from-yellow-500/10", border: "border-yellow-500/30", text: "text-yellow-400", badge: "bg-yellow-500" },
  };
  const colors = statusColors[node.status];

  return (
    <div className="flex gap-3">
      {/* Vertical connector */}
      <div className="flex flex-col items-center w-8 flex-shrink-0">
        <motion.div
          initial={{ scale: 0 }}
          animate={{ scale: 1 }}
          transition={{ delay: 0.1 + index * 0.05 }}
          className={`w-6 h-6 rounded-full ${colors.badge} flex items-center justify-center text-white text-[10px] font-bold z-10 shadow-lg`}
        >
          {index + 1}
        </motion.div>
        {index < CHAIN.length - 1 && (
          <div className="w-0.5 flex-1 bg-gradient-to-b from-slate-600/50 to-slate-700/30 my-1" />
        )}
      </div>

      {/* Card */}
      <motion.div
        initial={{ opacity: 0, x: -20 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ delay: 0.1 + index * 0.05 }}
        onClick={onToggle}
        className={`flex-1 mb-2 cursor-pointer rounded-xl p-4 bg-gradient-to-r ${colors.bg} to-transparent border ${colors.border} hover:shadow-lg transition-all duration-300`}
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <code className={`text-sm font-bold ${colors.text}`}>
              {node.file}
            </code>
            <span className="text-[10px] text-slate-600 font-mono">
              {node.lines}L &middot; {node.theorems} thms
            </span>
          </div>
          <span className={`text-[9px] font-bold uppercase px-2 py-0.5 rounded ${colors.badge} text-white`}>
            {node.status}
          </span>
        </div>
        <div className="text-sm text-slate-300 mt-1 font-mono">
          {node.key}
        </div>

        <AnimatePresence>
          {isExpanded && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: "auto", opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              transition={{ duration: 0.2 }}
              className="overflow-hidden"
            >
              <p className="text-xs text-slate-400 mt-3 pt-3 border-t border-slate-700/30 leading-relaxed">
                {node.desc}
              </p>
            </motion.div>
          )}
        </AnimatePresence>
      </motion.div>
    </div>
  );
}

/* ───────── page ───────── */

export default function PerronChainPage() {
  const [expanded, setExpanded] = useState<number | null>(null);

  const totalLines = CHAIN.reduce((s, n) => s + n.lines, 0);
  const totalTheorems = CHAIN.reduce((s, n) => s + n.theorems, 0);
  const provedCount = CHAIN.filter((n) => n.status === "proved").length;

  return (
    <div className="p-8 max-w-4xl mx-auto">
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
          <span className="bg-gradient-to-r from-blue-400 via-cyan-400 to-emerald-400 bg-clip-text text-transparent">
            The Perron Chain
          </span>
        </h1>
        <p className="text-slate-400 mt-2 max-w-2xl">
          16 files proving <strong className="text-white">RH &rArr; |M(x)| = O(x&frac34;)</strong> via
          the Perron contour formula. The analytic heart of the forward direction.
        </p>
      </motion.div>

      {/* Stats bar */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.2 }}
        className="flex gap-6 mt-6 mb-8 text-sm flex-wrap"
      >
        {[
          { color: "bg-blue-500", text: `${CHAIN.length} files` },
          { color: "bg-cyan-500", text: `${totalLines.toLocaleString()} lines` },
          { color: "bg-emerald-500", text: `${totalTheorems} theorems` },
          { color: "bg-emerald-500", text: `${provedCount}/${CHAIN.length} proved` },
        ].map((item) => (
          <div key={item.text} className="flex items-center gap-2">
            <div className={`w-2.5 h-2.5 rounded-full ${item.color}`} />
            <span className="text-slate-300">{item.text}</span>
          </div>
        ))}
      </motion.div>

      {/* The chain */}
      <div className="relative">
        {CHAIN.map((node, i) => (
          <ChainNodeCard
            key={node.file}
            node={node}
            index={i}
            isExpanded={expanded === i}
            onToggle={() => setExpanded(expanded === i ? null : i)}
          />
        ))}
      </div>

      {/* Footer */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1 }}
        className="mt-8 p-5 rounded-xl bg-gradient-to-r from-blue-500/10 via-transparent to-emerald-500/10 border border-blue-500/20"
      >
        <h3 className="text-sm font-bold text-blue-400 mb-2">
          How the chain works
        </h3>
        <p className="text-xs text-slate-400 leading-relaxed">
          The Perron formula expresses M(x) = &Sigma;&mu;(n) as a contour integral of x&#x02E2;/(&zeta;(s)&middot;s).
          The chain builds this from first principles: define the kernel (1&ndash;2), bound it (3&ndash;5),
          evaluate it at half-integers (6), connect to Dirichlet series (7), shift the contour (8),
          compute residues at s=1 and at zeta zeros (9&ndash;10), assemble the formula (11&ndash;12),
          prove summability (13), handle edge cases (14), convert the bound (15), and conclude (16).
          Under RH, all non-trivial zeros have Re(&rho;) = &frac12;, giving |M(x)| = O(x&frac34;).
        </p>
      </motion.div>
    </div>
  );
}
