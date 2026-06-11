"use client";
import { useState } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";

/* ───────── data ───────── */

interface DedekindFile {
  id: string;
  name: string;
  path: string;
  lines: number;
  sorry: number;
  role: string;
  color: string;
  icon: string;
  provides: string[];
  imports: string[];
  keyTheorems: { name: string; desc: string; status: "proved" | "sorry" | "assembled" }[];
  description: string;
}

const FILES: DedekindFile[] = [
  {
    id: "reciprocity",
    name: "DedekindReciprocity",
    path: "Cathedral/Physics/Bridges/DedekindReciprocity.lean",
    lines: 1047,
    sorry: 1,
    role: "Foundation Layer",
    color: "#6366f1",
    icon: "\uD83E\uDDF1",
    provides: [
      "sawtooth function definition",
      "dedekindSum(b, a) definition",
      "Cross-sum expansion",
      "Three-term relation (r=1 proved, r\u22652 sorry)",
      "Reciprocity law (modulo three-term)",
    ],
    imports: [],
    keyTheorems: [
      { name: "sawtooth_eq_fract", desc: "((x)) = {x} - 1/2 for non-integer x", status: "proved" },
      { name: "dedekindSum", desc: "s(b,a) = \u2211 ((k/a))((kb/a))", status: "proved" },
      { name: "sawtooth_div_pos", desc: "Positivity of sawtooth at division points", status: "proved" },
      { name: "dedekind_cross_sum", desc: "Cross-sum via weighted floor sums", status: "proved" },
      { name: "dedekind_three_term", desc: "Three-term relation (r\u22652 sorry \u2014 file-ordering artifact)", status: "sorry" },
      { name: "dedekind_reciprocity", desc: "s(a,b)+s(b,a) = (a\u00b2+b\u00b2+1)/(12ab)\u22121/4", status: "proved" },
    ],
    description:
      "Self-contained foundation. Defines the Dedekind sum s(b,a) via the sawtooth function ((x)), proves basic properties (periodicity, cross-sum), and derives the reciprocity law. Contains 1 sorry: the three-term relation for r\u22652, which is a file-ordering artifact resolved by DedekindAssembly.",
  },
  {
    id: "bridge",
    name: "DedekindBridge",
    path: "Cathedral/Physics/Bridges/DedekindBridge.lean",
    lines: 1044,
    sorry: 1,
    role: "Bridge Layer",
    color: "#f59e0b",
    icon: "\uD83C\uDF09",
    provides: [
      "weighted_floor_euclidean (Brave Berry \uD83C\uDF53)",
      "Euclidean descent for three-term relation",
      "Ramanujan matrix entry connection",
      "Vasyunin-Dedekind bridge",
    ],
    imports: ["DedekindReciprocity"],
    keyTheorems: [
      { name: "weighted_floor_euclidean", desc: "The Brave Berry \uD83C\uDF53 \u2014 Euclidean descent for weighted floor sums", status: "proved" },
      { name: "dedekind_three_term_bridge", desc: "Three-term relation (all r, sorry-free)", status: "proved" },
      { name: "dedekind_contains_ramanujan", desc: "R(j,k) = gcd(j,k)\u00b2/(12jk) \u2286 Dedekind reciprocity", status: "proved" },
      { name: "ramanujan_from_dedekind", desc: "Ramanujan entry from Dedekind decomposition", status: "proved" },
    ],
    description:
      "Imports DedekindReciprocity and proves the sorry-free three-term relation via the Brave Berry \uD83C\uDF53 (weighted_floor_euclidean). Connects Dedekind sums to the Ramanujan matrix entry R(j,k) = gcd(j,k)\u00b2/(12jk), bridging to the Vasyunin/Gram world.",
  },
  {
    id: "assembly",
    name: "DedekindAssembly",
    path: "Cathedral/Physics/Bridges/DedekindAssembly.lean",
    lines: 254,
    sorry: 0,
    role: "Assembly Layer",
    color: "#10b981",
    icon: "\u2705",
    provides: [
      "Sorry-free three-term relation",
      "Sorry-free reciprocity expansion",
      "Sorry-free reciprocity law",
      "Sorry-free Ramanujan connection",
    ],
    imports: ["DedekindBridge"],
    keyTheorems: [
      { name: "dedekind_three_term_assembled", desc: "Three-term (sorry-free assembly)", status: "assembled" },
      { name: "dedekind_reciprocity_assembled", desc: "Full reciprocity law (sorry-free)", status: "assembled" },
      { name: "dedekind_contains_ramanujan_assembled", desc: "Ramanujan \u2286 Dedekind (sorry-free)", status: "assembled" },
      { name: "ramanujan_from_dedekind_assembled", desc: "Ramanujan from Dedekind (sorry-free)", status: "assembled" },
    ],
    description:
      "Resolves the circular dependency. Imports DedekindBridge (which transitively imports DedekindReciprocity) and provides sorry-free versions of all key theorems. This is the clean export layer.",
  },
];

/* ───────── components ───────── */

function FileNode({
  file,
  isSelected,
  onSelect,
  index,
}: {
  file: DedekindFile;
  isSelected: boolean;
  onSelect: () => void;
  index: number;
}) {
  const statusColor = file.sorry > 0 ? "text-amber-400" : "text-emerald-400";
  const statusText = file.sorry > 0 ? `${file.sorry} sorry (artifact)` : "0 sorry";

  return (
    <motion.div
      initial={{ opacity: 0, x: -30 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ delay: 0.3 + index * 0.15, type: "spring", stiffness: 120 }}
      onClick={onSelect}
      className={`
        cursor-pointer rounded-2xl p-5 transition-all duration-300
        border
        ${isSelected ? "scale-[1.01] shadow-xl" : "hover:scale-[1.005]"}
      `}
      style={{
        background: `linear-gradient(135deg, ${file.color}15, ${file.color}05, transparent)`,
        borderColor: isSelected ? `${file.color}60` : `${file.color}25`,
        boxShadow: isSelected ? `0 0 30px ${file.color}15` : "none",
      }}
    >
      {/* Header */}
      <div className="flex items-center gap-3 mb-3">
        <div
          className="w-12 h-12 rounded-xl flex items-center justify-center text-2xl shadow-lg"
          style={{ background: `${file.color}20`, border: `1px solid ${file.color}40` }}
        >
          {file.icon}
        </div>
        <div className="flex-1">
          <h3 className="text-sm font-bold text-slate-200">{file.name}.lean</h3>
          <p className="text-[10px] font-mono" style={{ color: file.color }}>
            {file.role}
          </p>
        </div>
        <div className="text-right space-y-1">
          <div className="text-sm font-bold font-mono text-slate-300">
            {file.lines.toLocaleString()} <span className="text-[10px] text-slate-600">lines</span>
          </div>
          <div className={`text-[10px] font-mono ${statusColor}`}>{statusText}</div>
        </div>
      </div>

      {/* Provides */}
      <div className="flex flex-wrap gap-1.5 mb-2">
        {file.provides.map((p) => (
          <span
            key={p}
            className="text-[9px] px-2 py-0.5 rounded-full border"
            style={{
              background: `${file.color}10`,
              borderColor: `${file.color}25`,
              color: `${file.color}cc`,
            }}
          >
            {p}
          </span>
        ))}
      </div>

      <p className="text-xs text-slate-400 leading-relaxed">{file.description}</p>

      {/* Expanded: theorem list */}
      <AnimatePresence>
        {isSelected && (
          <motion.div
            initial={{ height: 0, opacity: 0 }}
            animate={{ height: "auto", opacity: 1 }}
            exit={{ height: 0, opacity: 0 }}
            transition={{ duration: 0.3 }}
            className="overflow-hidden"
          >
            <div className="mt-4 pt-3 border-t border-slate-700/30">
              <h4 className="text-[10px] text-slate-500 uppercase tracking-wider mb-2">
                Key Theorems
              </h4>
              <div className="space-y-2">
                {file.keyTheorems.map((t) => (
                  <div
                    key={t.name}
                    className="flex items-start gap-2 text-xs"
                  >
                    <span
                      className={`mt-0.5 text-[10px] ${
                        t.status === "proved"
                          ? "text-emerald-400"
                          : t.status === "assembled"
                          ? "text-cyan-400"
                          : "text-amber-400"
                      }`}
                    >
                      {t.status === "proved" ? "\u2705" : t.status === "assembled" ? "\uD83D\uDD17" : "\u26A0\uFE0F"}
                    </span>
                    <div>
                      <code className="text-slate-300 text-[11px]">{t.name}</code>
                      <p className="text-slate-500 text-[10px] mt-0.5">{t.desc}</p>
                    </div>
                  </div>
                ))}
              </div>
              <div className="mt-3">
                <code className="text-[9px] text-slate-600 block">
                  \uD83D\uDCC2 {file.path}
                </code>
              </div>
            </div>
          </motion.div>
        )}
      </AnimatePresence>
    </motion.div>
  );
}

function DependencyArrow({ from, to, label }: { from: string; to: string; label: string }) {
  return (
    <motion.div
      initial={{ opacity: 0, scaleY: 0 }}
      animate={{ opacity: 1, scaleY: 1 }}
      transition={{ delay: 0.6, duration: 0.4 }}
      className="flex items-center justify-center py-2"
    >
      <div className="flex flex-col items-center">
        <div className="w-0.5 h-6 bg-gradient-to-b from-slate-600 to-slate-700" />
        <div className="flex items-center gap-2 py-1 px-3 rounded-full bg-slate-800/60 border border-slate-700/40">
          <span className="text-[9px] text-slate-500">{from}</span>
          <span className="text-slate-600">\u2192</span>
          <span className="text-[9px] text-slate-400">{label}</span>
          <span className="text-slate-600">\u2192</span>
          <span className="text-[9px] text-slate-500">{to}</span>
        </div>
        <div className="w-0.5 h-6 bg-gradient-to-b from-slate-700 to-slate-600" />
      </div>
    </motion.div>
  );
}

/* ───────── page ───────── */

export default function DedekindTreePage() {
  const [selected, setSelected] = useState<string>("assembly");

  return (
    <div className="p-8 max-w-4xl mx-auto">
      <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }}>
        <Link
          href="/"
          className="text-xs text-slate-600 hover:text-slate-400 transition-colors"
        >
          &larr; Back to Cathedral
        </Link>
        <h1 className="text-3xl font-bold mt-3">
          <span className="bg-gradient-to-r from-indigo-400 via-amber-400 to-emerald-400 bg-clip-text text-transparent">
            Dedekind Architecture
          </span>
        </h1>
        <p className="text-slate-400 mt-2 max-w-2xl">
          The three-file architecture for the Dedekind reciprocity law.
          Foundation &rarr; Bridge &rarr; Assembly resolves a circular dependency
          while keeping the full <code className="text-amber-400/80">s(a,b) + s(b,a) = (a&sup2; + b&sup2; + 1)/(12ab) &minus; 1/4</code>{" "}
          reciprocity sorry-free in the assembly layer.
        </p>
      </motion.div>

      {/* The Formula */}
      <motion.div
        initial={{ opacity: 0, scale: 0.95 }}
        animate={{ opacity: 1, scale: 1 }}
        transition={{ delay: 0.2 }}
        className="mt-6 p-6 rounded-2xl bg-gradient-to-r from-[#12142a] via-[#0f1025] to-[#12142a] border border-indigo-500/20 text-center"
      >
        <div className="text-[10px] text-indigo-400/60 uppercase tracking-wider mb-2">
          The Dedekind Reciprocity Law (1892)
        </div>
        <div className="text-xl font-mono text-slate-200 tracking-wide">
          s(a,b) + s(b,a) = <span className="text-amber-400">(a&sup2; + b&sup2; + 1)</span> / <span className="text-cyan-400">(12ab)</span> &minus; <span className="text-rose-400">1/4</span>
        </div>
        <div className="text-[10px] text-slate-600 mt-2">
          where s(b,a) = \u2211<sub>k=1..a-1</sub> ((k/a))((kb/a)) and ((x)) is the sawtooth function
        </div>
      </motion.div>

      {/* Architecture diagram */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 0.3 }}
        className="mt-8 space-y-0"
      >
        {/* Layer 1: Foundation */}
        <FileNode
          file={FILES[0]}
          isSelected={selected === "reciprocity"}
          onSelect={() => setSelected(selected === "reciprocity" ? "" : "reciprocity")}
          index={0}
        />

        <DependencyArrow from="Reciprocity" to="Bridge" label="imports defs + cross-sum" />

        {/* Layer 2: Bridge */}
        <FileNode
          file={FILES[1]}
          isSelected={selected === "bridge"}
          onSelect={() => setSelected(selected === "bridge" ? "" : "bridge")}
          index={1}
        />

        <DependencyArrow from="Bridge" to="Assembly" label="imports Brave Berry \uD83C\uDF53" />

        {/* Layer 3: Assembly */}
        <FileNode
          file={FILES[2]}
          isSelected={selected === "assembly"}
          onSelect={() => setSelected(selected === "assembly" ? "" : "assembly")}
          index={2}
        />
      </motion.div>

      {/* The Sorry Resolution */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.8 }}
        className="mt-6 p-5 rounded-2xl bg-gradient-to-r from-amber-500/5 via-transparent to-emerald-500/5 border border-slate-700/30"
      >
        <h3 className="text-sm font-bold text-slate-200 mb-3">
          \u26A0\uFE0F The File-Ordering Artifact
        </h3>
        <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-xs">
          <div className="p-3 rounded-xl bg-indigo-500/5 border border-indigo-500/20">
            <div className="text-indigo-400 font-bold mb-1">Problem</div>
            <p className="text-slate-400">
              DedekindReciprocity needs the three-term relation for r\u22652,
              but the proof requires <code className="text-amber-400">weighted_floor_euclidean</code>{" "}
              which lives in DedekindBridge, creating a circular import.
            </p>
          </div>
          <div className="p-3 rounded-xl bg-amber-500/5 border border-amber-500/20">
            <div className="text-amber-400 font-bold mb-1">Solution</div>
            <p className="text-slate-400">
              DedekindReciprocity marks r\u22652 as <code className="text-amber-400">sorry</code>,
              DedekindBridge proves it via the Brave Berry \uD83C\uDF53,
              DedekindAssembly re-exports the sorry-free version.
            </p>
          </div>
          <div className="p-3 rounded-xl bg-emerald-500/5 border border-emerald-500/20">
            <div className="text-emerald-400 font-bold mb-1">Result</div>
            <p className="text-slate-400">
              The assembly layer provides the <strong>complete, sorry-free</strong>{" "}
              Dedekind reciprocity law. All downstream consumers import from Assembly.
            </p>
          </div>
        </div>
      </motion.div>

      {/* Stats */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1 }}
        className="mt-6 grid grid-cols-5 gap-3"
      >
        {[
          { value: "3", label: "Files", color: "text-indigo-400" },
          { value: "2,345", label: "Total lines", color: "text-amber-400" },
          { value: "1", label: "Sorry (artifact)", color: "text-amber-400" },
          { value: "10+", label: "Theorems", color: "text-emerald-400" },
          { value: "1892", label: "Dedekind's year", color: "text-rose-400" },
        ].map((s) => (
          <div
            key={s.label}
            className="text-center p-3 rounded-xl bg-slate-800/30 border border-slate-700/30"
          >
            <div className={`text-xl font-bold font-mono ${s.color}`}>{s.value}</div>
            <div className="text-[9px] text-slate-600 mt-1">{s.label}</div>
          </div>
        ))}
      </motion.div>

      {/* Footer */}
      <div className="text-center text-xs text-slate-600 mt-8 pt-4 border-t border-slate-800">
        Dedekind Architecture &mdash; v26 Penta-Crown &mdash;{" "}
        134 years from Dedekind's ink to Lean's kernel \uD83C\uDF53
      </div>
    </div>
  );
}
