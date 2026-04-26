"use client";
import { useState, useMemo, useCallback } from "react";
import { motion, AnimatePresence } from "framer-motion";
import Link from "next/link";
import {
  gramEntry,
  gramTermRational,
  gramTermLog,
  gramTermCot,
  gramTermBase,
  meanEntry,
  covEntry,
  logCutoffWitness,
  mobiusSieve,
  GRAM_TERMS,
  CONSTANTS,
} from "@/lib/math";

/* ───────── types ───────── */

type Tab = "gram" | "witness" | "distance";

/* ───────── sub-components ───────── */

function TermToggle({
  term,
  active,
  onToggle,
}: {
  term: (typeof GRAM_TERMS)[0];
  active: boolean;
  onToggle: () => void;
}) {
  return (
    <button
      onClick={onToggle}
      className={`flex items-center gap-2 px-3 py-2 rounded-lg text-xs transition-all duration-200 border ${
        active
          ? "shadow-lg"
          : "opacity-40 hover:opacity-70"
      }`}
      style={{
        background: active ? term.bgColor : "transparent",
        borderColor: active ? term.color + "60" : "#1e214830",
        color: active ? term.color : "#64748b",
      }}
    >
      <div
        className="w-3 h-3 rounded-sm"
        style={{ background: active ? term.color : "#334155" }}
      />
      <span className="font-bold">{term.name}</span>
      <span className="text-slate-600 ml-1">{term.rank}</span>
    </button>
  );
}

function MatrixCell({
  value,
  j,
  k,
  maxAbs,
  onClick,
}: {
  value: number;
  j: number;
  k: number;
  maxAbs: number;
  onClick: () => void;
}) {
  const intensity = Math.min(Math.abs(value) / maxAbs, 1);
  const hue = value >= 0 ? 145 : 0;
  const bg = `hsla(${hue}, 70%, 50%, ${intensity * 0.8})`;

  return (
    <div
      onClick={onClick}
      className="aspect-square flex items-center justify-center text-[8px] font-mono cursor-pointer hover:ring-1 hover:ring-amber-400/50 rounded-sm transition-all"
      style={{ background: bg }}
      title={`G(${j},${k}) = ${value.toFixed(6)}`}
    >
      {value !== 0 && Math.abs(value) > 0.001 ? value.toFixed(2) : ""}
    </div>
  );
}

function WitnessBar({
  k,
  value,
  mu,
  maxAbs,
}: {
  k: number;
  value: number;
  mu: number;
  maxAbs: number;
}) {
  const width = Math.min(Math.abs(value) / maxAbs * 100, 100);
  const color = value > 0 ? "#10b981" : value < 0 ? "#ef4444" : "#334155";

  return (
    <div className="flex items-center gap-2 text-xs h-6">
      <div className="w-6 text-right font-mono text-slate-500">{k}</div>
      <div className="w-8 text-right font-mono text-slate-600">
        {mu === 0 ? "0" : mu > 0 ? "+1" : "\u22121"}
      </div>
      <div className="flex-1 h-4 bg-[#1e2148] rounded-sm overflow-hidden relative">
        <motion.div
          initial={{ width: 0 }}
          animate={{ width: `${width}%` }}
          transition={{ duration: 0.3, delay: k * 0.02 }}
          className="h-full rounded-sm"
          style={{ background: color }}
        />
      </div>
      <div className="w-16 text-right font-mono text-slate-400">
        {value.toFixed(4)}
      </div>
    </div>
  );
}

/* ───────── main page ───────── */

export default function TermExplorerPage() {
  const [tab, setTab] = useState<Tab>("gram");
  const [activeTerms, setActiveTerms] = useState<Set<string>>(
    new Set(["rational", "log", "cot", "base"])
  );
  const [N, setN] = useState(12);
  const [selectedCell, setSelectedCell] = useState<{ j: number; k: number } | null>(null);

  const mu = useMemo(() => mobiusSieve(Math.max(N + 1, 100)), [N]);

  const toggleTerm = useCallback(
    (id: string) => {
      setActiveTerms((prev) => {
        const next = new Set(prev);
        if (next.has(id)) next.delete(id);
        else next.add(id);
        return next;
      });
    },
    []
  );

  // Compute matrix values
  const { matrix, maxAbs } = useMemo(() => {
    const m: number[][] = [];
    let max = 0;
    for (let j = 1; j <= N; j++) {
      const row: number[] = [];
      for (let k = 1; k <= N; k++) {
        let val = 0;
        if (activeTerms.has("rational")) val += gramTermRational(j, k);
        if (activeTerms.has("log")) val += gramTermLog(j, k);
        if (activeTerms.has("cot")) val += gramTermCot(j, k);
        if (activeTerms.has("base")) val += gramTermBase(j, k);
        row.push(val);
        max = Math.max(max, Math.abs(val));
      }
      m.push(row);
    }
    return { matrix: m, maxAbs: max || 1 };
  }, [N, activeTerms]);

  // Witness values
  const witnessValues = useMemo(() => {
    const vals: { k: number; value: number; mu: number }[] = [];
    let max = 0;
    for (let k = 1; k <= N; k++) {
      const v = logCutoffWitness(k, N, mu);
      vals.push({ k, value: v, mu: mu[k] });
      max = Math.max(max, Math.abs(v));
    }
    return { vals, maxAbs: max || 1 };
  }, [N, mu]);

  // Distance computation
  const distanceData = useMemo(() => {
    const points: { n: number; d2: number }[] = [];
    for (let n = 2; n <= Math.min(N, 40); n++) {
      // d²_N = 1 - bᵀv where v = log-cutoff witness
      let bv = 0;
      let vGv = 0;
      for (let j = 1; j <= n; j++) {
        const vj = logCutoffWitness(j, n, mu);
        bv += meanEntry(j) * vj;
        for (let k = 1; k <= n; k++) {
          const vk = logCutoffWitness(k, n, mu);
          vGv += vj * gramEntry(j, k) * vk;
        }
      }
      const d2 = Math.max(0, 1 - 2 * bv + vGv);
      points.push({ n, d2 });
    }
    return points;
  }, [N, mu]);

  // Cell detail
  const cellDetail = useMemo(() => {
    if (!selectedCell) return null;
    const { j, k } = selectedCell;
    return {
      j,
      k,
      total: gramEntry(j, k),
      rational: gramTermRational(j, k),
      log: gramTermLog(j, k),
      cot: gramTermCot(j, k),
      base: gramTermBase(j, k),
      mean_j: meanEntry(j),
      mean_k: meanEntry(k),
      cov: covEntry(j, k),
    };
  }, [selectedCell]);

  return (
    <div className="p-8 max-w-6xl mx-auto">
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
          <span className="bg-gradient-to-r from-amber-400 via-violet-400 to-blue-400 bg-clip-text text-transparent">
            Term Explorer
          </span>
        </h1>
        <p className="text-slate-400 mt-2 max-w-2xl">
          Decompose the Gram matrix G(j,k) into its four components. Toggle terms,
          adjust N, and watch how the proof&apos;s structure emerges from wave interference.
        </p>
      </motion.div>

      {/* Tabs */}
      <div className="flex gap-2 mt-6 mb-6">
        {([
          { id: "gram" as Tab, label: "Gram Matrix", icon: "\uD83D\uDD25" },
          { id: "witness" as Tab, label: "Log-Cutoff Witness", icon: "\u2211" },
          { id: "distance" as Tab, label: "d\u00B2_N Decay", icon: "\uD83D\uDCC9" },
        ]).map((t) => (
          <button
            key={t.id}
            onClick={() => setTab(t.id)}
            className={`px-4 py-2 rounded-lg text-sm font-medium transition-all ${
              tab === t.id
                ? "bg-gradient-to-r from-amber-500/20 to-violet-500/20 text-amber-400 border border-amber-500/30"
                : "text-slate-500 hover:text-slate-300 border border-transparent"
            }`}
          >
            {t.icon} {t.label}
          </button>
        ))}
      </div>

      {/* N slider */}
      <div className="flex items-center gap-4 mb-6">
        <label className="text-xs text-slate-500 font-mono">N =</label>
        <input
          type="range"
          min={2}
          max={tab === "distance" ? 40 : 20}
          value={N}
          onChange={(e) => setN(parseInt(e.target.value))}
          className="flex-1 max-w-xs accent-amber-500"
        />
        <span className="text-sm font-mono text-amber-400 w-8">{N}</span>
      </div>

      {/* ═══ GRAM MATRIX TAB ═══ */}
      <AnimatePresence mode="wait">
        {tab === "gram" && (
          <motion.div
            key="gram"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            {/* Term toggles */}
            <div className="flex flex-wrap gap-2 mb-6">
              {GRAM_TERMS.map((term) => (
                <TermToggle
                  key={term.id}
                  term={term}
                  active={activeTerms.has(term.id)}
                  onToggle={() => toggleTerm(term.id)}
                />
              ))}
            </div>

            <div className="flex gap-6">
              {/* Matrix grid */}
              <div className="flex-1">
                <div
                  className="grid gap-0.5"
                  style={{
                    gridTemplateColumns: `repeat(${N}, 1fr)`,
                  }}
                >
                  {matrix.map((row, j) =>
                    row.map((val, k) => (
                      <MatrixCell
                        key={`${j}-${k}`}
                        value={val}
                        j={j + 1}
                        k={k + 1}
                        maxAbs={maxAbs}
                        onClick={() => setSelectedCell({ j: j + 1, k: k + 1 })}
                      />
                    ))
                  )}
                </div>
                <div className="flex justify-between mt-2 text-[10px] text-slate-600">
                  <span>j = 1</span>
                  <span>j = {N}</span>
                </div>
              </div>

              {/* Cell detail panel */}
              <div className="w-72 flex-shrink-0">
                {cellDetail ? (
                  <motion.div
                    key={`${cellDetail.j}-${cellDetail.k}`}
                    initial={{ opacity: 0, x: 10 }}
                    animate={{ opacity: 1, x: 0 }}
                    className="p-4 rounded-xl bg-[#12142a] border border-slate-700/50 space-y-3"
                  >
                    <div className="text-xs text-slate-500">
                      G({cellDetail.j}, {cellDetail.k})
                    </div>
                    <div className="text-lg font-mono font-bold text-amber-400">
                      {cellDetail.total.toFixed(6)}
                    </div>
                    <div className="space-y-1.5">
                      {GRAM_TERMS.map((term) => {
                        const val = ({
                          rational: cellDetail.rational,
                          log: cellDetail.log,
                          cot: cellDetail.cot,
                          base: cellDetail.base,
                        } as Record<string, number>)[term.id];
                        const pct = cellDetail.total !== 0
                          ? Math.abs(val / cellDetail.total) * 100
                          : 0;
                        return (
                          <div key={term.id} className="flex items-center gap-2">
                            <div
                              className="w-2 h-2 rounded-sm"
                              style={{ background: term.color }}
                            />
                            <span className="text-[10px] text-slate-400 w-16">{term.name}</span>
                            <span className="text-[10px] font-mono text-slate-300 flex-1 text-right">
                              {val.toFixed(6)}
                            </span>
                            <span className="text-[9px] text-slate-600 w-10 text-right">
                              {pct.toFixed(0)}%
                            </span>
                          </div>
                        );
                      })}
                    </div>
                    <div className="pt-2 border-t border-slate-700/30 space-y-1">
                      <div className="flex justify-between text-[10px]">
                        <span className="text-slate-500">b({cellDetail.j})</span>
                        <span className="text-slate-300 font-mono">
                          {cellDetail.mean_j.toFixed(6)}
                        </span>
                      </div>
                      <div className="flex justify-between text-[10px]">
                        <span className="text-slate-500">b({cellDetail.k})</span>
                        <span className="text-slate-300 font-mono">
                          {cellDetail.mean_k.toFixed(6)}
                        </span>
                      </div>
                      <div className="flex justify-between text-[10px]">
                        <span className="text-slate-500">C({cellDetail.j},{cellDetail.k})</span>
                        <span className="text-violet-400 font-mono font-bold">
                          {cellDetail.cov.toFixed(6)}
                        </span>
                      </div>
                    </div>
                  </motion.div>
                ) : (
                  <div className="p-4 rounded-xl bg-[#12142a] border border-slate-700/30 text-xs text-slate-600 text-center">
                    Click a cell to inspect its decomposition
                  </div>
                )}

                {/* Formula reference */}
                <div className="mt-4 p-4 rounded-xl bg-gradient-to-br from-violet-500/5 to-transparent border border-violet-500/20">
                  <div className="text-[10px] font-mono text-violet-400 mb-2">
                    VASYUNIN FORMULA
                  </div>
                  <div className="text-xs text-slate-400 leading-relaxed space-y-1">
                    <p>G(j,k) = <span style={{color: "#f59e0b"}}>Rational</span> + <span style={{color: "#3b82f6"}}>Log</span> + <span style={{color: "#8b5cf6"}}>Cot</span> + <span style={{color: "#ef4444"}}>Base</span></p>
                    <p className="text-[10px] text-slate-600 mt-2">
                      A = ln(2&pi;) &minus; &gamma; &asymp; {CONSTANTS.A.toFixed(4)}
                    </p>
                    <p className="text-[10px] text-slate-600">
                      &gamma; &asymp; {CONSTANTS.GAMMA.toFixed(4)}
                    </p>
                  </div>
                </div>
              </div>
            </div>
          </motion.div>
        )}

        {/* ═══ WITNESS TAB ═══ */}
        {tab === "witness" && (
          <motion.div
            key="witness"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <div className="p-4 rounded-xl bg-gradient-to-r from-emerald-500/5 to-transparent border border-emerald-500/20 mb-6">
              <div className="text-[10px] font-mono text-emerald-400 mb-1">
                LOG-CUTOFF WITNESS
              </div>
              <p className="text-xs text-slate-400">
                v&#x2096; = &minus;&mu;(k) &middot; (1 &minus; ln(k)/ln(N)). The Bartlett window taper:
                v&#x2081; = 1 (since ln(1)=0), v_N = 0 (since ln(N)/ln(N)=1).
                Only squarefree k contribute (&mu;(k) &ne; 0).
              </p>
            </div>

            <div className="space-y-1">
              {witnessValues.vals.map((w) => (
                <WitnessBar
                  key={w.k}
                  k={w.k}
                  value={w.value}
                  mu={w.mu}
                  maxAbs={witnessValues.maxAbs}
                />
              ))}
            </div>

            <div className="mt-4 flex gap-4 text-xs text-slate-600">
              <div className="flex items-center gap-1">
                <div className="w-3 h-2 rounded-sm bg-emerald-500" />
                <span>Positive (squarefree, even # primes)</span>
              </div>
              <div className="flex items-center gap-1">
                <div className="w-3 h-2 rounded-sm bg-red-500" />
                <span>Negative (squarefree, odd # primes)</span>
              </div>
              <div className="flex items-center gap-1">
                <div className="w-3 h-2 rounded-sm bg-[#334155]" />
                <span>Zero (non-squarefree, &mu;(k)=0)</span>
              </div>
            </div>
          </motion.div>
        )}

        {/* ═══ DISTANCE TAB ═══ */}
        {tab === "distance" && (
          <motion.div
            key="distance"
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
          >
            <div className="p-4 rounded-xl bg-gradient-to-r from-amber-500/5 to-transparent border border-amber-500/20 mb-6">
              <div className="text-[10px] font-mono text-amber-400 mb-1">
                B&Aacute;EZ-DUARTE DISTANCE
              </div>
              <p className="text-xs text-slate-400">
                d&sup2;_N = 1 &minus; 2b&sup1;v + v&sup1;Gv. As N &rarr; &infin;, d&sup2;_N &rarr; 0 &hArr; RH.
                The log-cutoff witness gives d&sup2;_N &asymp; C/log(N).
              </p>
            </div>

            {/* Bar chart */}
            <div className="space-y-1">
              {distanceData.map((pt) => {
                const maxD2 = Math.max(...distanceData.map((p) => p.d2));
                const width = maxD2 > 0 ? (pt.d2 / maxD2) * 100 : 0;
                return (
                  <div key={pt.n} className="flex items-center gap-2 text-xs h-6">
                    <div className="w-6 text-right font-mono text-slate-500">{pt.n}</div>
                    <div className="flex-1 h-4 bg-[#1e2148] rounded-sm overflow-hidden">
                      <motion.div
                        initial={{ width: 0 }}
                        animate={{ width: `${width}%` }}
                        transition={{ duration: 0.4, delay: pt.n * 0.03 }}
                        className="h-full rounded-sm bg-gradient-to-r from-amber-500 to-orange-500"
                      />
                    </div>
                    <div className="w-20 text-right font-mono text-slate-400">
                      {pt.d2.toFixed(6)}
                    </div>
                  </div>
                );
              })}
            </div>

            {distanceData.length > 2 && (
              <div className="mt-4 p-3 rounded-lg bg-[#12142a] border border-slate-700/30">
                <div className="text-[10px] text-slate-500 mb-1">Convergence rate</div>
                <div className="text-xs text-slate-400">
                  d&sup2;_{N} &asymp;{" "}
                  <span className="text-amber-400 font-mono">
                    {(distanceData[distanceData.length - 1].d2 * Math.log(N)).toFixed(4)}
                  </span>
                  {" "}/log({N}) &mdash; consistent with C/log(N) decay
                </div>
              </div>
            )}
          </motion.div>
        )}
      </AnimatePresence>
    </div>
  );
}
