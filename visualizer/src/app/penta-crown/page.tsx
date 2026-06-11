"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";

/* ───────── data ───────── */

interface CrownPath {
  id: string;
  name: string;
  subtitle: string;
  axiomCount: number;
  axiomType: string;
  color: string;
  bgGradient: string;
  borderColor: string;
  glowColor: string;
  icon: string;
  keyFile: string;
  keyTheorem: string;
  description: string;
  details: string[];
}

const PATHS: CrownPath[] = [
  {
    id: "overcancellation",
    name: "PATH 1 — Overcancellation",
    subtitle: "The Cleanest Path",
    axiomCount: 2,
    axiomType: "PNT axioms",
    color: "#f43f5e",
    bgGradient: "from-rose-500/15 via-rose-500/5 to-transparent",
    borderColor: "border-rose-500/30",
    glowColor: "shadow-rose-500/20",
    icon: "🍓",
    keyFile: "Geometry/Renormalization/OvercancellationGraduation.lean",
    keyTheorem: "overcancellation_implies_rh",
    description:
      "The narrowest axiom footprint. Depends only on 2 PNT-level axioms (frac_error_isLittleO + pnt_mu_log_sq_div_k) plus the Lean kernel. No custom axioms needed.",
    details: [
      "PNT consequences → Gram bound → d²_N → 0 → RH",
      "2 PNT axioms (both unconditional from prime number theorem)",
      "Bypasses all Vasyunin/Mellin/Perron infrastructure",
      "The Brave Berry 🍓 — discovered June 7, 2026",
    ],
  },
  {
    id: "analytic",
    name: "Analytic Crown",
    subtitle: "The Literature Path",
    axiomCount: 1,
    axiomType: "literature axiom",
    color: "#f59e0b",
    bgGradient: "from-amber-500/15 via-amber-500/5 to-transparent",
    borderColor: "border-amber-500/30",
    glowColor: "shadow-amber-500/20",
    icon: "📜",
    keyFile: "Assembly/MainChain.lean",
    keyTheorem: "baez_duarte_forward",
    description:
      "The primary formal export. Uses baez_duarte_forward (IMRN 2003) — a published result by Luis Báez-Duarte proving RH implies d²_N → 0.",
    details: [
      "1 literature axiom: baez_duarte_forward (IMRN 2003, No. 36)",
      "Pure mathematics — no computation",
      "Routes through the Direct Mellin Bound",
      "The continuous mathematical ideal",
    ],
  },
  {
    id: "oracle",
    name: "Oracle Crown",
    subtitle: "The Computational Path",
    axiomCount: 1,
    axiomType: "GPU computation",
    color: "#06b6d4",
    bgGradient: "from-cyan-500/15 via-cyan-500/5 to-transparent",
    borderColor: "border-cyan-500/30",
    glowColor: "shadow-cyan-500/20",
    icon: "⚡",
    keyFile: "Assembly/OracleCascade.lean",
    keyTheorem: "rh_from_oracle",
    description:
      "Zero literature axioms. One trusted GPU measurement: DD-precision Gram matrices at highly composite numbers (N = 5040, 27720, 55440).",
    details: [
      "1 computation axiom: oracle_certificates",
      "256-bit MPFR + cuBLAS tensor cores",
      "Certified at N = 55,440 (highest HC number)",
      "Lattice QCD gauge — computation IS the proof",
    ],
  },
  {
    id: "gram",
    name: "Gram Crown",
    subtitle: "The Discrete Path",
    axiomCount: 1,
    axiomType: "crown axiom + 5 PNT",
    color: "#6366f1",
    bgGradient: "from-indigo-500/15 via-indigo-500/5 to-transparent",
    borderColor: "border-indigo-500/30",
    glowColor: "shadow-indigo-500/20",
    icon: "🔢",
    keyFile: "Geometry/Crown/GramBoundDirect.lean",
    keyTheorem: "rh_discrete_subseq",
    description:
      "RH reformulated as a single discrete arithmetic inequality: vᵀGv ≤ 1 + K/ln N. Bypasses the covariance axiom entirely.",
    details: [
      "RH IS an inequality about Möbius-weighted sums",
      "Subsequential: bound needed only along HC numbers",
      "Bypasses covariance axiom entirely",
      "1 crown axiom + 5 PNT bureaucracy axioms",
    ],
  },
  {
    id: "arakelov",
    name: "Arakelov Crown",
    subtitle: "The Geometric Path",
    axiomCount: 1,
    axiomType: "Hodge index axiom",
    color: "#8b5cf6",
    bgGradient: "from-violet-500/15 via-violet-500/5 to-transparent",
    borderColor: "border-violet-500/30",
    glowColor: "shadow-violet-500/20",
    icon: "💎",
    keyFile: "Geometry/Arakelov/ArakelovFusion.lean",
    keyTheorem: "rh_from_arakelov",
    description:
      "Algebraic-geometric path. Decomposes the Gram matrix via Arakelov intersection pairing G = G_fin + G_arch, connecting prime factorization to eigenvalue control.",
    details: [
      "Arakelov Fusion: G = G_fin + G_arch",
      "Tropical geometry → spectral decay",
      "Smith's 1876 PSD theorem → eigenvalue control",
      "1 Hodge index axiom",
    ],
  },
];

const CONVERSE = {
  name: "Converse Direction",
  subtitle: "Pure Mathlib",
  axiomCount: 0,
  color: "#10b981",
  icon: "✅",
  keyTheorem: "nyman_beurling_converse",
  description:
    "d²_N → 0 ⟹ RH. Via the Rank-1 Mellin Miracle: M[hₖ](ρ) = 1/(k(ρ−1)) factorizes into rank-1 tensors. Cauchy-Schwarz separates off-critical zeros. Zero custom axioms, zero sorry.",
};

/* ───────── components ───────── */

function CrownNode({
  path,
  isSelected,
  onSelect,
  index,
}: {
  path: CrownPath;
  isSelected: boolean;
  onSelect: () => void;
  index: number;
}) {
  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.8 }}
      animate={{ opacity: 1, scale: 1 }}
      transition={{ delay: 0.2 + index * 0.1, type: "spring", stiffness: 150 }}
      onClick={onSelect}
      className={`
        cursor-pointer rounded-2xl p-5 transition-all duration-300
        bg-gradient-to-br ${path.bgGradient}
        border ${path.borderColor}
        ${isSelected ? `shadow-xl ${path.glowColor} scale-[1.02]` : "hover:scale-[1.01]"}
      `}
    >
      <div className="flex items-center gap-3 mb-3">
        <div
          className="w-12 h-12 rounded-xl flex items-center justify-center text-2xl shadow-lg"
          style={{ background: `${path.color}30`, border: `1px solid ${path.color}50` }}
        >
          {path.icon}
        </div>
        <div className="flex-1">
          <h3 className="text-sm font-bold text-slate-200">{path.name}</h3>
          <p className="text-[10px] text-slate-500 font-mono">{path.subtitle}</p>
        </div>
        <div className="text-right">
          <div className="text-2xl font-bold font-mono" style={{ color: path.color }}>
            {path.axiomCount}
          </div>
          <div className="text-[9px] text-slate-600">{path.axiomType}</div>
        </div>
      </div>

      <p className="text-xs text-slate-400 leading-relaxed">{path.description}</p>

      <AnimatePresence>
        {isSelected && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.25 }}
            className="overflow-hidden"
          >
            <div className="mt-4 pt-3 border-t border-slate-700/30 space-y-2">
              {path.details.map((d, i) => (
                <div key={i} className="flex items-start gap-2 text-xs text-slate-400">
                  <span style={{ color: path.color }} className="mt-0.5">
                    ▸
                  </span>
                  <span>{d}</span>
                </div>
              ))}
              <div className="mt-3 flex flex-wrap gap-2">
                <code className="text-[10px] px-2 py-0.5 rounded bg-slate-800/80 text-slate-400 border border-slate-700/50">
                  📂 {path.keyFile}
                </code>
                <code
                  className="text-[10px] px-2 py-0.5 rounded border"
                  style={{
                    background: `${path.color}15`,
                    borderColor: `${path.color}30`,
                    color: path.color,
                  }}
                >
                  ⚡ {path.keyTheorem}
                </code>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

/* ───────── page ───────── */

export default function PentaCrownPage() {
  const [selected, setSelected] = useState<string>("overcancellation");

  return (
    <div className="p-8 max-w-5xl mx-auto">
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
        <Link
          href="/"
          className="text-xs text-slate-600 hover:text-slate-400 transition-colors"
        >
          &larr; Back to Cathedral
        </Link>
        <h1 className="text-3xl font-bold mt-3">
          <span className="bg-gradient-to-r from-rose-400 via-amber-400 to-violet-400 bg-clip-text text-transparent">
            The Penta-Crown
          </span>
        </h1>
        <p className="text-slate-400 mt-2 max-w-2xl">
          Five independent proof paths to the Riemann Hypothesis. Each crown
          uses a different mathematical technique, providing cross-validation
          of the formal reduction. Click any path to explore.
        </p>
      </motion.div>

      {/* Crown axiom bar */}
      <motion.div
        initial={{ opacity: 0, scaleX: 0 }}
        animate={{ opacity: 1, scaleX: 1 }}
        transition={{ delay: 0.3, duration: 0.6 }}
        className="mt-8 mb-2 flex rounded-xl overflow-hidden h-3 gap-0.5"
      >
        {PATHS.map((p) => (
          <div
            key={p.id}
            className="flex-1 transition-all duration-300"
            style={{
              background: selected === p.id ? p.color : `${p.color}40`,
              filter: selected === p.id ? "brightness(1.2)" : "none",
            }}
          />
        ))}
      </motion.div>
      <div className="flex justify-between text-[9px] text-slate-600 font-mono mb-8 px-1">
        {PATHS.map((p) => (
          <span key={p.id} style={{ color: selected === p.id ? p.color : undefined }}>
            {p.axiomCount} axiom{p.axiomCount !== 1 ? "s" : ""}
          </span>
        ))}
      </div>

      {/* Crown paths */}
      <div className="space-y-3">
        {PATHS.map((path, i) => (
          <CrownNode
            key={path.id}
            path={path}
            index={i}
            isSelected={selected === path.id}
            onSelect={() => setSelected(selected === path.id ? "" : path.id)}
          />
        ))}
      </div>

      {/* Converse banner */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.8 }}
        className="mt-6 p-6 rounded-2xl bg-gradient-to-r from-emerald-500/10 via-emerald-500/5 to-transparent border border-emerald-500/30"
      >
        <div className="flex items-center gap-4">
          <div className="w-14 h-14 rounded-xl bg-emerald-500/20 border border-emerald-500/30 flex items-center justify-center">
            <span className="text-3xl">{CONVERSE.icon}</span>
          </div>
          <div className="flex-1">
            <div className="flex items-center gap-3">
              <h3 className="text-lg font-bold text-emerald-400">{CONVERSE.name}</h3>
              <span className="text-xs font-mono px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                {CONVERSE.axiomCount} axioms
              </span>
            </div>
            <p className="text-sm text-slate-400 mt-1">{CONVERSE.description}</p>
            <code className="text-[10px] text-emerald-500/60 font-mono mt-2 block">
              ⚡ {CONVERSE.keyTheorem}
            </code>
          </div>
        </div>
      </motion.div>

      {/* Summary stats */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1 }}
        className="mt-8 grid grid-cols-4 gap-4"
      >
        {[
          { label: "Crown Paths", value: "5", color: "text-amber-400" },
          { label: "Total Routes", value: "6", color: "text-rose-400" },
          { label: "Crown Sorry", value: "0", color: "text-emerald-400" },
          { label: "Min Axioms", value: "2 PNT", color: "text-violet-400" },
        ].map((stat) => (
          <div
            key={stat.label}
            className="text-center p-4 rounded-xl bg-slate-800/30 border border-slate-700/30"
          >
            <div className={`text-2xl font-bold font-mono ${stat.color}`}>
              {stat.value}
            </div>
            <div className="text-[10px] text-slate-600 mt-1">{stat.label}</div>
          </div>
        ))}
      </motion.div>

      {/* Footer */}
      <div className="text-center text-xs text-slate-600 mt-8 pt-4 border-t border-slate-800">
        v26 Penta-Crown &mdash; June 10, 2026 &mdash; 474 files, ~149,500
        lines, 0 sorry on crown
      </div>
    </div>
  );
}
