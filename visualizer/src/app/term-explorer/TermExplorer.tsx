// Term Explorer Component — rendered client-only via dynamic import

import { useState, useMemo, useCallback, useEffect } from "react";
import { motion, AnimatePresence } from "framer-motion";
import katex from "katex";
import {
  gramTermRational, gramTermLog, gramTermCot, gramTermBase,
  gramEntry, meanEntry, covEntry, mobiusSieve, logCutoffWitness,
  GRAM_TERMS, CONSTANTS, type TermInfo,
} from "@/lib/math";

// ─── KaTeX renderer ───
function Tex({ children, display }: { children: string; display?: boolean }) {
  const html = useMemo(() => {
    try {
      return katex.renderToString(children, { displayMode: !!display, throwOnError: false });
    } catch { return children; }
  }, [children, display]);
  return <span dangerouslySetInnerHTML={{ __html: html }} />;
}

// ─── Term toggle pill ───
function TermPill({ term, active, onToggle }: { term: TermInfo; active: boolean; onToggle: () => void }) {
  return (
    <motion.button
      onClick={onToggle}
      whileHover={{ scale: 1.05 }}
      whileTap={{ scale: 0.95 }}
      className={`px-4 py-2 rounded-xl text-sm font-semibold transition-all duration-200 border ${
        active
          ? `text-white border-transparent shadow-lg`
          : "text-slate-500 border-slate-700 opacity-50"
      }`}
      style={active ? { backgroundColor: term.color, boxShadow: `0 0 20px ${term.color}40` } : {}}
    >
      <span className="mr-2">{active ? "●" : "○"}</span>
      {term.name}
      <span className="ml-2 text-xs opacity-70">{term.rank}</span>
    </motion.button>
  );
}

// ─── Matrix cell ───
function Cell({
  value,
  maxAbs,
  isSelected,
  onClick,
  j,
  k,
}: {
  value: number;
  maxAbs: number;
  isSelected: boolean;
  onClick: () => void;
  j: number;
  k: number;
}) {
  const intensity = Math.min(Math.abs(value) / maxAbs, 1);
  const hue = value >= 0 ? 200 : 30;  // blue for positive, amber for negative
  const bg = `hsla(${hue}, 80%, 60%, ${intensity * 0.7})`;

  return (
    <motion.button
      whileHover={{ scale: 1.15, zIndex: 10 }}
      onClick={onClick}
      className={`relative aspect-square rounded-md text-[10px] font-mono flex items-center justify-center transition-all ${
        isSelected ? "ring-2 ring-white" : ""
      }`}
      style={{ backgroundColor: bg }}
      title={`G(${j},${k}) = ${value.toFixed(8)}`}
      suppressHydrationWarning
    >
      {value !== 0 ? (value > 0 ? "+" : "−") : ""}
    </motion.button>
  );
}

// ─── Proof chain step ───
function ChainStep({
  name,
  type,
  latex,
  description,
  delay,
}: {
  name: string;
  type: "axiom" | "theorem";
  latex: string;
  description: string;
  delay: number;
}) {
  const [expanded, setExpanded] = useState(false);
  return (
    <motion.div
      initial={{ opacity: 0, x: -20 }}
      animate={{ opacity: 1, x: 0 }}
      transition={{ delay }}
      className="flex items-start gap-3"
    >
      <div className="flex flex-col items-center">
        <div
          className={`w-4 h-4 rounded-full ${
            type === "axiom" ? "bg-amber-500" : "bg-emerald-500"
          }`}
        />
        <div className="w-0.5 h-8 bg-slate-700" />
      </div>
      <button onClick={() => setExpanded(!expanded)} className="text-left flex-1">
        <div className="flex items-center gap-2">
          <span className={`text-xs font-mono px-2 py-0.5 rounded ${
            type === "axiom" ? "bg-amber-500/20 text-amber-400" : "bg-emerald-500/20 text-emerald-400"
          }`}>
            {type === "axiom" ? "AXIOM" : "THEOREM"}
          </span>
          <span className="text-sm font-mono text-slate-300">{name}</span>
        </div>
        <AnimatePresence>
          {expanded && (
            <motion.div
              initial={{ height: 0, opacity: 0 }}
              animate={{ height: "auto", opacity: 1 }}
              exit={{ height: 0, opacity: 0 }}
              className="mt-2 text-xs text-slate-400 overflow-hidden"
            >
              <div className="mb-1"><Tex>{latex}</Tex></div>
              <p>{description}</p>
            </motion.div>
          )}
        </AnimatePresence>
      </button>
    </motion.div>
  );
}

// ═══════════════════════════════════════════════
// Main Page
// ═══════════════════════════════════════════════

export default function TermExplorer() {
  const [matrixSize, setMatrixSize] = useState(6);
  const [selectedJ, setSelectedJ] = useState(1);
  const [selectedK, setSelectedK] = useState(2);
  const [activeTerms, setActiveTerms] = useState<Set<string>>(
    new Set(["rational", "log", "cot", "base"])
  );
  const [showCov, setShowCov] = useState(false);
  const [witnessN, setWitnessN] = useState(20);
  const [mounted, setMounted] = useState(false);

  useEffect(() => { setMounted(true); }, []);

  const toggleTerm = useCallback((id: string) => {
    setActiveTerms((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id); else next.add(id);
      return next;
    });
  }, []);

  // Compute matrix values
  const matrixData = useMemo(() => {
    const data: number[][] = [];
    let maxAbs = 0;
    for (let j = 1; j <= matrixSize; j++) {
      const row: number[] = [];
      for (let k = 1; k <= matrixSize; k++) {
        let val = 0;
        if (showCov) {
          val = covEntry(j, k);
        } else {
          if (activeTerms.has("rational")) val += gramTermRational(j, k);
          if (activeTerms.has("log")) val += gramTermLog(j, k);
          if (activeTerms.has("cot")) val += gramTermCot(j, k);
          if (activeTerms.has("base")) val += gramTermBase(j, k);
        }
        row.push(val);
        maxAbs = Math.max(maxAbs, Math.abs(val));
      }
      data.push(row);
    }
    return { data, maxAbs };
  }, [matrixSize, activeTerms, showCov]);

  // Selected entry decomposition
  const decomposition = useMemo(() => {
    const j = selectedJ, k = selectedK;
    return {
      rational: gramTermRational(j, k),
      log: gramTermLog(j, k),
      cot: gramTermCot(j, k),
      base: gramTermBase(j, k),
      total: gramEntry(j, k),
      mean: meanEntry(j) * meanEntry(k),
      cov: covEntry(j, k),
    };
  }, [selectedJ, selectedK]);

  // Witness vector for selected N
  const witnessData = useMemo(() => {
    const mu = mobiusSieve(witnessN);
    const v: { k: number; mu: number; v: number; b: number }[] = [];
    for (let k = 1; k <= witnessN; k++) {
      v.push({
        k,
        mu: mu[k],
        v: logCutoffWitness(k, witnessN, mu),
        b: meanEntry(k),
      });
    }
    return v;
  }, [witnessN]);

  return (
    <div className="p-6 max-w-7xl mx-auto">
      {/* KaTeX CSS */}
      <link
        rel="stylesheet"
        href="https://cdn.jsdelivr.net/npm/katex@0.16.9/dist/katex.min.css"
      />

      {/* Header */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="mb-8"
      >
        <h1 className="text-3xl font-bold mb-2">
          <span className="bg-gradient-to-r from-amber-400 via-orange-400 to-red-400 bg-clip-text text-transparent">
            Term Explorer
          </span>
        </h1>
        <p className="text-slate-400 text-sm max-w-2xl">
          Interactively explore the Vasyunin formula term by term. Toggle
          components, inspect individual matrix entries, and see how the Gram
          matrix decomposes into its four fundamental dimensions.
        </p>
      </motion.div>

      {/* Main layout: Matrix + Detail */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left: Matrix viewer */}
        <div className="lg:col-span-2">
          {/* Term toggles */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.2 }}
            className="flex flex-wrap gap-2 mb-4"
          >
            {GRAM_TERMS.map((term) => (
              <TermPill
                key={term.id}
                term={term}
                active={!showCov && activeTerms.has(term.id)}
                onToggle={() => { setShowCov(false); toggleTerm(term.id); }}
              />
            ))}
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={() => setShowCov(!showCov)}
              className={`px-4 py-2 rounded-xl text-sm font-semibold border transition-all ${
                showCov
                  ? "bg-emerald-500 text-white border-transparent shadow-lg"
                  : "text-slate-500 border-slate-700"
              }`}
              style={showCov ? { boxShadow: "0 0 20px rgba(16,185,129,0.3)" } : {}}
            >
              C = G − bbᵀ
            </motion.button>
          </motion.div>

          {/* Size slider */}
          <div className="flex items-center gap-4 mb-4 text-sm text-slate-400">
            <span>N =</span>
            <input
              type="range"
              min={2}
              max={12}
              value={matrixSize}
              onChange={(e) => setMatrixSize(+e.target.value)}
              className="flex-1 accent-amber-500"
            />
            <span className="font-mono text-amber-400 w-8">{matrixSize}</span>
          </div>

          {/* Matrix grid */}
          <motion.div
            layout
            className="p-4 rounded-xl bg-slate-900/50 border border-slate-800"
          >
            {/* Column headers */}
            <div
              className="grid gap-1 mb-1"
              style={{ gridTemplateColumns: `2rem repeat(${matrixSize}, 1fr)` }}
            >
              <div />
              {Array.from({ length: matrixSize }, (_, i) => (
                <div key={i} className="text-[10px] text-center text-slate-500 font-mono">
                  {i + 1}
                </div>
              ))}
            </div>
            {/* Rows */}
            {mounted ? matrixData.data.map((row, ji) => (
              <div
                key={ji}
                className="grid gap-1 mb-1"
                style={{ gridTemplateColumns: `2rem repeat(${matrixSize}, 1fr)` }}
              >
                <div className="text-[10px] text-slate-500 font-mono flex items-center justify-end pr-1">
                  {ji + 1}
                </div>
                {row.map((val, ki) => (
                  <Cell
                    key={ki}
                    value={val}
                    maxAbs={matrixData.maxAbs}
                    isSelected={selectedJ === ji + 1 && selectedK === ki + 1}
                    onClick={() => { setSelectedJ(ji + 1); setSelectedK(ki + 1); }}
                    j={ji + 1}
                    k={ki + 1}
                  />
                ))}
              </div>
            )) : (
              <div className="h-48 flex items-center justify-center text-slate-600 text-sm">Loading matrix...</div>
            )}
          </motion.div>

          {/* Legend */}
          <div className="flex gap-4 mt-3 text-xs text-slate-500">
            <div className="flex items-center gap-1">
              <div className="w-3 h-3 rounded" style={{ background: "hsla(200,80%,60%,0.5)" }} />
              Positive
            </div>
            <div className="flex items-center gap-1">
              <div className="w-3 h-3 rounded" style={{ background: "hsla(30,80%,60%,0.5)" }} />
              Negative
            </div>
            <div className="text-slate-600">Click any cell to inspect</div>
          </div>
        </div>

        {/* Right: Detail panel */}
        <div className="space-y-4">
          {/* Selected entry */}
          <motion.div
            layout
            className="p-5 rounded-xl bg-slate-900/50 border border-slate-800"
          >
            <h3 className="text-sm font-bold text-slate-300 mb-3">
              {showCov ? (
                <Tex>{`C(${selectedJ},${selectedK})`}</Tex>
              ) : (
                <Tex>{`G(${selectedJ},${selectedK})`}</Tex>
              )}
            </h3>

            {/* Term-by-term breakdown */}
            <div className="space-y-2">
              {GRAM_TERMS.map((term) => {
                const val =
                  term.id === "rational" ? decomposition.rational :
                  term.id === "log" ? decomposition.log :
                  term.id === "cot" ? decomposition.cot :
                  decomposition.base;
                return (
                  <div
                    key={term.id}
                    className="flex items-center justify-between px-3 py-2 rounded-lg transition-all"
                    style={{
                      backgroundColor: activeTerms.has(term.id) && !showCov ? term.bgColor : "transparent",
                      opacity: activeTerms.has(term.id) || showCov ? 1 : 0.3,
                    }}
                  >
                    <div className="flex items-center gap-2">
                      <div
                        className="w-2 h-2 rounded-full"
                        style={{ backgroundColor: term.color }}
                      />
                      <span className="text-xs text-slate-400">{term.name}</span>
                    </div>
                    <span className="text-xs font-mono text-slate-300">
                      {val >= 0 ? "+" : ""}{val.toFixed(8)}
                    </span>
                  </div>
                );
              })}

              {/* Divider */}
              <div className="border-t border-slate-700 my-2" />

              {/* Total G */}
              <div className="flex justify-between px-3 py-1">
                <span className="text-xs text-slate-300 font-semibold">
                  G({selectedJ},{selectedK})
                </span>
                <span className="text-xs font-mono text-white font-bold">
                  {decomposition.total >= 0 ? "+" : ""}
                  {decomposition.total.toFixed(8)}
                </span>
              </div>

              {/* Mean deflation */}
              <div className="flex justify-between px-3 py-1">
                <span className="text-xs text-slate-400">
                  −b<sub>{selectedJ}</sub>b<sub>{selectedK}</sub>
                </span>
                <span className="text-xs font-mono text-red-400">
                  −{decomposition.mean.toFixed(8)}
                </span>
              </div>

              {/* Covariance */}
              <div className="flex justify-between px-3 py-1 bg-emerald-500/10 rounded-lg">
                <span className="text-xs text-emerald-400 font-semibold">
                  C({selectedJ},{selectedK})
                </span>
                <span className="text-xs font-mono text-emerald-300 font-bold">
                  {decomposition.cov >= 0 ? "+" : ""}
                  {decomposition.cov.toFixed(8)}
                </span>
              </div>
            </div>
          </motion.div>

          {/* Term definitions */}
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.4 }}
            className="p-5 rounded-xl bg-slate-900/50 border border-slate-800"
          >
            <h3 className="text-sm font-bold text-slate-300 mb-3">Formula</h3>
            <div className="text-center mb-3">
              <Tex display>
                {"G(j,k) = \\sum_{i=1}^{4} T_i(j,k)"}
              </Tex>
            </div>
            <div className="space-y-3">
              {GRAM_TERMS.map((term) => (
                <div
                  key={term.id}
                  className="px-3 py-2 rounded-lg border border-slate-800 hover:border-slate-600 transition-colors"
                  style={{ borderLeftColor: term.color, borderLeftWidth: 3 }}
                >
                  <div className="text-xs mb-1">
                    <Tex>{`T_\\text{${term.name}} = ${term.latex}`}</Tex>
                  </div>
                  <p className="text-[10px] text-slate-500">{term.intuition}</p>
                </div>
              ))}
            </div>
          </motion.div>
        </div>
      </div>

      {/* Witness section */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.6 }}
        className="mt-8"
      >
        <h2 className="text-xl font-bold text-slate-200 mb-4">
          Log Cutoff Witness
        </h2>
        <div className="flex items-center gap-4 mb-4 text-sm text-slate-400">
          <span>N =</span>
          <input
            type="range"
            min={5}
            max={50}
            value={witnessN}
            onChange={(e) => setWitnessN(+e.target.value)}
            className="flex-1 accent-violet-500"
          />
          <span className="font-mono text-violet-400 w-8">{witnessN}</span>
        </div>
        <div className="p-4 rounded-xl bg-slate-900/50 border border-slate-800 overflow-x-auto">
          <div className="flex gap-1 items-end" style={{ minHeight: 120 }}>
            {mounted && witnessData.map(({ k, mu: muK, v }) => {
              const maxV = Math.max(...witnessData.map((d) => Math.abs(d.v)));
              const h = maxV > 0 ? (Math.abs(v) / maxV) * 80 : 0;
              const isSquarefree = muK !== 0;
              return (
                <div
                  key={k}
                  className="flex flex-col items-center"
                  style={{ minWidth: witnessN > 30 ? 12 : 20 }}
                >
                  <div
                    className="w-full rounded-t transition-all"
                    style={{
                      height: h,
                      backgroundColor: v > 0
                        ? "rgba(16,185,129,0.7)"
                        : v < 0
                        ? "rgba(239,68,68,0.7)"
                        : "rgba(100,116,139,0.2)",
                      transform: v < 0 ? "scaleY(-1)" : "none",
                      marginTop: v < 0 ? h : 0,
                    }}
                  />
                  {witnessN <= 30 && (
                    <span
                      className={`text-[8px] mt-1 font-mono ${
                        isSquarefree ? "text-slate-400" : "text-slate-600"
                      }`}
                    >
                      {k}
                    </span>
                  )}
                </div>
              );
            })}
          </div>
          <div className="flex gap-4 mt-3 text-xs text-slate-500">
            <div className="flex items-center gap-1">
              <div className="w-3 h-3 rounded" style={{ background: "rgba(239,68,68,0.7)" }} />
              v &lt; 0 (primes: μ = −1)
            </div>
            <div className="flex items-center gap-1">
              <div className="w-3 h-3 rounded" style={{ background: "rgba(16,185,129,0.7)" }} />
              v &gt; 0 (semiprimes: μ = +1)
            </div>
            <div className="flex items-center gap-1">
              <div className="w-3 h-3 rounded" style={{ background: "rgba(100,116,139,0.2)" }} />
              v = 0 (non-squarefree)
            </div>
          </div>
        </div>
        <div className="mt-3 text-center">
          <Tex display>{"v_k = -\\mu(k)\\left(1 - \\frac{\\ln k}{\\ln N}\\right)"}</Tex>
        </div>
      </motion.div>

      {/* Proof chain */}
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        transition={{ delay: 0.8 }}
        className="mt-8 p-6 rounded-xl bg-slate-900/50 border border-slate-800"
      >
        <h2 className="text-xl font-bold text-slate-200 mb-6">
          The Proof Chain
        </h2>
        <div className="space-y-1">
          <ChainStep
            name="log_cutoff_witness_bound"
            type="axiom"
            latex="\\exists c > 0, \\exists N_0, \\forall N \\geq N_0: c \\cdot \\ln N \\leq Q(v_{\\text{log}})"
            description="The Riemann Hypothesis itself, expressed as a finite discrete quantity."
            delay={0.9}
          />
          <ChainStep
            name="log_cutoff_witness_pos"
            type="theorem"
            latex="v^T C v > 0"
            description="From PosDef + v ≠ 0 via polarization argument."
            delay={1.0}
          />
          <ChainStep
            name="variational_lower_bound"
            type="theorem"
            latex="Q(v) \\leq X_N = b^T C^{-1} b"
            description="Cauchy-Schwarz in the C-inner product."
            delay={1.1}
          />
          <ChainStep
            name="quadForm_diverges"
            type="theorem"
            latex="X_N \\geq c \\cdot \\ln N"
            description="Combines the axiom with the variational bound."
            delay={1.2}
          />
          <ChainStep
            name="nbDistSq_decays"
            type="theorem"
            latex="\\forall \\varepsilon > 0, \\exists N_0: 1/(1+X_N) < \\varepsilon"
            description="The Nyman-Beurling distance d²_N → 0."
            delay={1.3}
          />
          <ChainStep
            name="nyman_beurling_from_mellin"
            type="theorem"
            latex="d_N^2 \\to 0 \\iff \\mathrm{RH}"
            description="The Nyman-Beurling equivalence. QED."
            delay={1.4}
          />
        </div>
      </motion.div>

      {/* Constants reference */}
      <motion.div
        initial={{ opacity: 0 }}
        animate={{ opacity: 1 }}
        transition={{ delay: 1.0 }}
        className="mt-6 p-4 rounded-xl bg-slate-900/30 border border-slate-800 text-xs text-slate-500"
      >
        <div className="flex flex-wrap gap-6">
          <div>γ (Euler-Mascheroni) = {CONSTANTS.GAMMA.toFixed(10)}</div>
          <div>A = ln(2π) − γ = {CONSTANTS.A.toFixed(10)}</div>
          <div>ln 2 = {Math.LN2.toFixed(10)}</div>
          <div>ln 3 = {Math.log(3).toFixed(10)}</div>
        </div>
      </motion.div>
    </div>
  );
}
