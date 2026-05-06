"use client";
import { useState } from "react";
import { motion } from "framer-motion";
import Link from "next/link";

/* ───────── data ───────── */

interface Milestone {
  version: string;
  date: string;
  axiomCount: number;
  sorryCount: number;
  title: string;
  changes: string[];
  graduated?: string[];
  color: string;
}

const MILESTONES: Milestone[] = [
  {
    version: "v1",
    date: "Apr 7",
    axiomCount: 6,
    sorryCount: 12,
    title: "Initial Foundation",
    changes: [
      "6 axioms, 12 sorry",
      "SpectralRH absorbed into Cathedral",
      "Converse direction established",
    ],
    color: "#ef4444",
  },
  {
    version: "v2",
    date: "Apr 9",
    axiomCount: 5,
    sorryCount: 10,
    title: "First Blood",
    changes: [
      "vasyunin_bd_index_bridge \u2192 THEOREM",
      "Index conversion proved via Mathlib arithmetic",
    ],
    graduated: ["vasyunin_bd_index_bridge"],
    color: "#f97316",
  },
  {
    version: "v3",
    date: "Apr 11",
    axiomCount: 4,
    sorryCount: 8,
    title: "Vasyunin Bypass",
    changes: [
      "vasyunin_eq_integral \u2192 THEOREM",
      "Diagonal G(k,k) proved via Stirling + piecewise FTC",
      "Night assault: 3 axioms annihilated in one session",
    ],
    graduated: ["vasyunin_eq_integral"],
    color: "#eab308",
  },
  {
    version: "v4\u2013v5",
    date: "Apr 13",
    axiomCount: 2,
    sorryCount: 5,
    title: "Decay Axiom Collapse",
    changes: [
      "Decay axioms collapsed into single witness axiom",
      "fract_sq_integral \u2192 THEOREM (Stirling + Squeeze)",
      "rh_implies_mertens_34 absorbed by rh_implies_mertens_bound",
    ],
    graduated: ["fract_sq_integral", "rh_implies_mertens_34"],
    color: "#a3e635",
  },
  {
    version: "v6",
    date: "Apr 16",
    axiomCount: 0,
    sorryCount: 4,
    title: "Zero Axiom Window",
    changes: [
      "All axioms temporarily at 0 (new architecture)",
      "Perron chain construction begins",
      "l2_from_pointwise_bound \u2192 THEOREM via Parseval Bridge",
    ],
    graduated: ["l2_from_pointwise_bound"],
    color: "#22c55e",
  },
  {
    version: "v7",
    date: "Apr 20\u201322",
    axiomCount: 7,
    sorryCount: 3,
    title: "Perron Crown",
    changes: [
      "16-file Perron contour formula chain built",
      "rh_implies_mertens_bound \u2192 PROVED THEOREM",
      "pnt_mu_div_k \u2192 GRADUATED via PNTAnd library",
      "Crown axiom count reset to 7 (new formalization)",
    ],
    graduated: ["rh_implies_mertens_bound", "pnt_mu_div_k"],
    color: "#3b82f6",
  },
  {
    version: "v8",
    date: "Apr 23",
    axiomCount: 5,
    sorryCount: 2,
    title: "Five Walls",
    changes: [
      "abel_mertens_tail_raw \u2192 GRADUATED to theorem",
      "millennium_covariance_cancellation \u2192 GRADUATED",
      "Crown narrowed from 7 to 5",
    ],
    graduated: ["abel_mertens_tail_raw", "millennium_covariance_cancellation"],
    color: "#8b5cf6",
  },
  {
    version: "v9",
    date: "Apr 24",
    axiomCount: 5,
    sorryCount: 2,
    title: "Abel Bypass",
    changes: [
      "pnt_mu_log_sq_div_k ELIMINATED via S\u2083 uniform bound",
      "Instead of proving \u03A3 \u03BC(k)log\u00B2(k)/k \u2192 \u22122\u03B3, proved S\u2083 bounded",
      "Bypass avoids Tauberian machinery entirely",
    ],
    graduated: ["pnt_mu_log_sq_div_k"],
    color: "#a855f7",
  },
  {
    version: "v10",
    date: "Apr 25",
    axiomCount: 4,
    sorryCount: 0,
    title: "Four Walls",
    changes: [
      "gram_form_upper_bound_34 \u2192 GRADUATED via variance decomposition",
      "#print axioms: exactly 4 non-kernel axioms",
      "Zero sorry on crown path",
      "Dead code purge: harmonicTileSum_reciprocity deleted",
    ],
    graduated: ["gram_form_upper_bound_34"],
    color: "#ec4899",
  },
  {
    version: "v11",
    date: "Apr 26",
    axiomCount: 2,
    sorryCount: 0,
    title: "Mellin Crown",
    changes: [
      "Mellin Crown architecture: 4 \u2192 2 crown axioms",
      "Parseval Bridge bypasses PNT, Abel, and Vasyunin chains",
      "Mathlib-style topic-based reorganization (22 directories)",
      "5 sorry-free files resurrected from Archive",
      "161 files, 39,375 lines, ~1,335 theorems",
    ],
    graduated: ["pnt_mu_log_div_k", "covariance_bound_from_mertens_34", "partial_integral_tends_to_formula"],
    color: "#f59e0b",
  },
  {
    version: "v16",
    date: "May 6",
    axiomCount: 1,
    sorryCount: 0,
    title: "Observatory Edition",
    changes: [
      "One-Pillar architecture: baez_duarte_forward sole crown axiom",
      "DD-precision pipeline (Dekker\u2013Knuth) certifies N=55,440",
      "N=20,000 witness scan: d\u00B2\u00B7ln(N) = 0.305",
      "96% vacuum reconstruction from 55,439 prime-frequency waves",
      "308 files, 78,435 lines, 15 papers, ~1,500+ theorems",
    ],
    graduated: ["critical_line_mellin_variance", "rh_zeta_lower_bound_from_zero_counting"],
    color: "#10b981",
  },
];

/* ───────── components ───────── */

function AxiomCounter({ count, maxCount }: { count: number; maxCount: number }) {
  const pct = ((maxCount - count) / maxCount) * 100;
  return (
    <div className="flex items-center gap-3">
      <div className="text-3xl font-bold font-mono text-amber-400">
        {count}
      </div>
      <div className="flex-1">
        <div className="text-[10px] text-slate-500 mb-1">
          {count === 0 ? "ZERO AXIOMS" : `${count} remaining`}
        </div>
        <div className="h-2 bg-[#1e2148] rounded-full overflow-hidden">
          <motion.div
            initial={{ width: 0 }}
            animate={{ width: `${pct}%` }}
            transition={{ duration: 0.8, ease: "easeOut" }}
            className="h-full bg-gradient-to-r from-emerald-500 to-amber-500 rounded-full"
          />
        </div>
      </div>
    </div>
  );
}

function TimelineNode({
  milestone,
  index,
  isSelected,
  onSelect,
}: {
  milestone: Milestone;
  index: number;
  isSelected: boolean;
  onSelect: () => void;
}) {
  return (
    <div className="flex gap-4">
      {/* Timeline spine */}
      <div className="flex flex-col items-center w-12 flex-shrink-0">
        <motion.div
          initial={{ scale: 0, rotate: -180 }}
          animate={{ scale: 1, rotate: 0 }}
          transition={{ delay: 0.1 + index * 0.08, type: "spring", stiffness: 200 }}
          className="w-10 h-10 rounded-xl flex items-center justify-center text-white text-xs font-bold z-10 shadow-lg cursor-pointer"
          style={{ background: milestone.color }}
          onClick={onSelect}
        >
          {milestone.version}
        </motion.div>
        {index < MILESTONES.length - 1 && (
          <div
            className="w-0.5 flex-1 my-1"
            style={{
              background: `linear-gradient(to bottom, ${milestone.color}40, ${MILESTONES[index + 1].color}40)`,
            }}
          />
        )}
      </div>

      {/* Content */}
      <motion.div
        initial={{ opacity: 0, x: -20 }}
        animate={{ opacity: 1, x: 0 }}
        transition={{ delay: 0.15 + index * 0.08 }}
        onClick={onSelect}
        className={`flex-1 mb-3 cursor-pointer rounded-xl p-5 border transition-all duration-300 ${
          isSelected
            ? "bg-gradient-to-r from-[#12142a] to-transparent shadow-lg"
            : "bg-[#0d0e1a]/50 hover:bg-[#12142a]/50"
        }`}
        style={{ borderColor: isSelected ? `${milestone.color}60` : "#1e214830" }}
      >
        <div className="flex items-center justify-between mb-2">
          <div>
            <h3 className="text-sm font-bold text-slate-200">
              {milestone.title}
            </h3>
            <span className="text-[10px] text-slate-600 font-mono">
              {milestone.date}, 2026
            </span>
          </div>
          <div className="flex items-center gap-3">
            <div className="text-right">
              <div className="text-lg font-bold font-mono" style={{ color: milestone.color }}>
                {milestone.axiomCount}
              </div>
              <div className="text-[9px] text-slate-600">axioms</div>
            </div>
            <div className="text-right">
              <div className="text-lg font-bold font-mono text-slate-500">
                {milestone.sorryCount}
              </div>
              <div className="text-[9px] text-slate-600">sorry</div>
            </div>
          </div>
        </div>

        {isSelected && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            transition={{ duration: 0.25 }}
          >
            <div className="mt-3 pt-3 border-t border-slate-700/30 space-y-2">
              {milestone.changes.map((change, i) => (
                <div key={i} className="flex items-start gap-2 text-xs text-slate-400">
                  <span className="text-slate-600 mt-0.5">&bull;</span>
                  <span>{change}</span>
                </div>
              ))}
              {milestone.graduated && milestone.graduated.length > 0 && (
                <div className="mt-2 flex flex-wrap gap-1.5">
                  {milestone.graduated.map((g) => (
                    <code
                      key={g}
                      className="text-[10px] px-2 py-0.5 rounded bg-emerald-500/10 text-emerald-400 border border-emerald-500/20"
                    >
                      {"\u2705"} {g}
                    </code>
                  ))}
                </div>
              )}
            </div>
          </motion.div>
        )}
      </motion.div>
    </div>
  );
}

/* ───────── page ───────── */

export default function GraduationTimelinePage() {
  const [selected, setSelected] = useState<number>(MILESTONES.length - 1);

  const current = MILESTONES[selected];
  const totalGraduated = MILESTONES.reduce(
    (s, m) => s + (m.graduated?.length || 0),
    0
  );

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
          <span className="bg-gradient-to-r from-red-400 via-amber-400 to-emerald-400 bg-clip-text text-transparent">
            Graduation Timeline
          </span>
        </h1>
        <p className="text-slate-400 mt-2 max-w-2xl">
          Watch axioms fall one by one. From 6 crown axioms to 1 in 42 days.
          {" "}<strong className="text-emerald-400">{totalGraduated} axioms graduated</strong> to theorems.
        </p>
      </motion.div>

      {/* Current state counter */}
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.2 }}
        className="mt-6 mb-8 p-5 rounded-xl bg-gradient-to-r from-[#12142a] to-[#0d0e1a] border border-slate-700/30"
      >
        <div className="flex items-center justify-between">
          <div>
            <div className="text-[10px] text-slate-500 uppercase tracking-wider mb-1">
              {current.version} &mdash; {current.title}
            </div>
            <AxiomCounter count={current.axiomCount} maxCount={7} />
          </div>
          <div className="flex gap-8 text-center">
            <div>
              <div className="text-2xl font-bold text-blue-400">308</div>
              <div className="text-[10px] text-slate-600">files</div>
            </div>
            <div>
              <div className="text-2xl font-bold text-violet-400">~1,500+</div>
              <div className="text-[10px] text-slate-600">theorems</div>
            </div>
            <div>
              <div className="text-2xl font-bold text-emerald-400">0</div>
              <div className="text-[10px] text-slate-600">sorry</div>
            </div>
          </div>
        </div>
      </motion.div>

      {/* Timeline */}
      <div className="relative">
        {MILESTONES.map((m, i) => (
          <TimelineNode
            key={m.version}
            milestone={m}
            index={i}
            isSelected={selected === i}
            onSelect={() => setSelected(i)}
          />
        ))}
      </div>
    </div>
  );
}
