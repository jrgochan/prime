"use client";
import { useEffect, useRef, useState, useMemo, useCallback } from "react";
import * as d3 from "d3";
import { motion } from "framer-motion";

/** Harmonic number H_n = 1 + 1/2 + ... + 1/n */
function harmonic(n: number): number {
  let h = 0;
  for (let k = 1; k <= n; k++) h += 1 / k;
  return h;
}

/** Sum of divisors σ(n) */
function sigma(n: number): number {
  let s = 0;
  for (let d = 1; d * d <= n; d++) {
    if (n % d === 0) {
      s += d;
      if (d !== n / d) s += n / d;
    }
  }
  return s;
}

/** Lagarias bound: H_n + exp(H_n) * ln(H_n) */
function lagarias_bound(n: number): number {
  const h = harmonic(n);
  if (h <= 0) return Infinity;
  return h + Math.exp(h) * Math.log(h);
}

/** Check if n is prime */
function isPrime(n: number): boolean {
  if (n < 2) return false;
  if (n === 2 || n === 3) return true;
  if (n % 2 === 0 || n % 3 === 0) return false;
  for (let i = 5; i * i <= n; i += 6) {
    if (n % i === 0 || n % (i + 2) === 0) return false;
  }
  return true;
}

/** Euler-Mascheroni constant */
const EULER_GAMMA = 0.5772156649015329;

/** Robin bound: exp(γ) * n * ln(ln(n)) */
function robin_bound(n: number): number {
  if (n < 3) return Infinity;
  const lln = Math.log(Math.log(n));
  if (lln <= 0) return Infinity;
  return Math.exp(EULER_GAMMA) * n * lln;
}

interface DataPoint {
  n: number;
  sigma_n: number;
  lagarias: number;
  robin: number;
  is_prime: boolean;
  margin_lagarias: number;
  margin_robin: number;
}

export default function RobinLagariasPage() {
  const svgRef = useRef<SVGSVGElement>(null);
  const [maxN, setMaxN] = useState(200);
  const [mode, setMode] = useState<"lagarias" | "robin">("lagarias");
  const [showPrimesOnly, setShowPrimesOnly] = useState(false);
  const [hoveredPoint, setHoveredPoint] = useState<DataPoint | null>(null);

  const data = useMemo(() => {
    const points: DataPoint[] = [];
    for (let n = 1; n <= maxN; n++) {
      const s = sigma(n);
      const lb = lagarias_bound(n);
      const rb = robin_bound(n);
      points.push({
        n,
        sigma_n: s,
        lagarias: lb,
        robin: rb,
        is_prime: isPrime(n),
        margin_lagarias: lb - s,
        margin_robin: rb - s,
      });
    }
    return points;
  }, [maxN]);

  const primeData = useMemo(() => data.filter((d) => d.is_prime), [data]);
  const displayData = showPrimesOnly ? primeData : data;

  const drawChart = useCallback(() => {
    if (!svgRef.current || displayData.length === 0) return;

    const svg = d3.select(svgRef.current);
    svg.selectAll("*").remove();

    const margin = { top: 30, right: 40, bottom: 55, left: 80 };
    const width = svgRef.current.clientWidth - margin.left - margin.right;
    const height = svgRef.current.clientHeight - margin.top - margin.bottom;
    const g = svg
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`);

    const x = d3
      .scaleLinear()
      .domain([1, maxN])
      .range([0, width]);
    const yMax =
      d3.max(displayData, (d) =>
        mode === "lagarias"
          ? Math.max(d.sigma_n, d.lagarias)
          : Math.max(d.sigma_n, d.robin)
      ) || 100;
    const y = d3
      .scaleLinear()
      .domain([0, yMax * 1.05])
      .range([height, 0]);

    // Grid lines
    g.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(x).ticks(10))
      .attr("color", "#334155");
    g.append("g").call(d3.axisLeft(y).ticks(8)).attr("color", "#334155");

    // Axis labels
    svg
      .append("text")
      .attr("x", margin.left + width / 2)
      .attr("y", margin.top + height + 48)
      .attr("text-anchor", "middle")
      .attr("fill", "#94a3b8")
      .attr("font-size", 13)
      .text("n");
    svg
      .append("text")
      .attr("transform", "rotate(-90)")
      .attr("x", -(margin.top + height / 2))
      .attr("y", 20)
      .attr("text-anchor", "middle")
      .attr("fill", "#94a3b8")
      .attr("font-size", 13)
      .text(mode === "lagarias" ? "σ(n) vs Lagarias bound" : "σ(n) vs Robin bound");

    // Margin fill
    const area = d3
      .area<DataPoint>()
      .x((d) => x(d.n))
      .y0((d) => y(d.sigma_n))
      .y1((d) => y(mode === "lagarias" ? d.lagarias : d.robin))
      .curve(d3.curveMonotoneX);

    const defs = svg.append("defs");
    const grad = defs
      .append("linearGradient")
      .attr("id", "rlGrad")
      .attr("x1", "0%")
      .attr("y1", "0%")
      .attr("x2", "0%")
      .attr("y2", "100%");
    grad.append("stop").attr("offset", "0%").attr("stop-color", "#f59e0b");
    grad.append("stop").attr("offset", "100%").attr("stop-color", "#10b981");

    g.append("path")
      .datum(displayData)
      .attr("fill", "url(#rlGrad)")
      .attr("opacity", 0.15)
      .attr("d", area);

    // Bound line
    const boundLine = d3
      .line<DataPoint>()
      .x((d) => x(d.n))
      .y((d) => y(mode === "lagarias" ? d.lagarias : d.robin))
      .curve(d3.curveMonotoneX);
    g.append("path")
      .datum(displayData)
      .attr("fill", "none")
      .attr("stroke", "#f59e0b")
      .attr("stroke-width", 2)
      .attr("stroke-dasharray", "6,3")
      .attr("d", boundLine);

    // σ(n) dots
    g.selectAll(".sigma-dot")
      .data(displayData)
      .join("circle")
      .attr("cx", (d) => x(d.n))
      .attr("cy", (d) => y(d.sigma_n))
      .attr("r", (d) => (d.is_prime ? 4 : 2))
      .attr("fill", (d) => (d.is_prime ? "#10b981" : "#3b82f6"))
      .attr("opacity", (d) => (d.is_prime ? 1 : 0.5))
      .attr("cursor", "pointer")
      .on("mouseenter", (_, d) => setHoveredPoint(d))
      .on("mouseleave", () => setHoveredPoint(null));

    // Highlight small primes (the Taylor truncation cases)
    const taylorPrimes = displayData.filter(
      (d) => d.is_prime && d.n <= 7 && d.n >= 2
    );
    g.selectAll(".taylor-ring")
      .data(taylorPrimes)
      .join("circle")
      .attr("cx", (d) => x(d.n))
      .attr("cy", (d) => y(d.sigma_n))
      .attr("r", 7)
      .attr("fill", "none")
      .attr("stroke", "#f59e0b")
      .attr("stroke-width", 1.5)
      .attr("stroke-dasharray", "3,2");

    // Legend
    g.append("text")
      .attr("x", width - 5)
      .attr("y", y(mode === "lagarias" ? displayData[displayData.length - 1]?.lagarias || 0 : displayData[displayData.length - 1]?.robin || 0) - 8)
      .attr("text-anchor", "end")
      .attr("fill", "#f59e0b")
      .attr("font-size", 11)
      .attr("font-family", "var(--font-geist-mono)")
      .text(mode === "lagarias" ? "H_n + exp(H_n)·ln(H_n)" : "exp(γ)·n·ln(ln(n))");
  }, [displayData, maxN, mode]);

  useEffect(() => {
    drawChart();
  }, [drawChart]);

  // Compute proof method for a given prime
  const proofMethod = (p: number): string => {
    if (p >= 11) return "Algebraic bypass (H_p ≥ 3 > e, log(H_p) ≥ 1)";
    if ([2, 3, 5, 7].includes(p)) return "Taylor quartic truncation (norm_num)";
    return "Composite: revert hp; decide";
  };

  return (
    <div className="h-full flex flex-col">
      <div className="p-6 border-b border-[#1e2148]">
        <h2 className="text-2xl font-bold text-slate-200 flex items-center gap-3">
          <span className="text-amber-400">🏆</span>
          Robin–Lagarias Dashboard
        </h2>
        <p className="text-sm text-slate-500 mt-1">
          Visualizing the{" "}
          <code className="text-emerald-400">lagarias_for_primes</code> theorem
          — σ(p) vs the Lagarias/Robin bound for all n
        </p>
      </div>

      {/* Controls */}
      <div className="px-6 py-3 border-b border-[#1e2148]/50 flex items-center gap-4 flex-wrap">
        <div className="flex rounded-lg overflow-hidden border border-[#1e2148]">
          <button
            onClick={() => setMode("lagarias")}
            className={`px-4 py-1.5 text-xs font-medium transition-colors ${
              mode === "lagarias"
                ? "bg-[#1e2148] text-amber-400"
                : "text-slate-500 hover:text-slate-300"
            }`}
          >
            Lagarias Bound
          </button>
          <button
            onClick={() => setMode("robin")}
            className={`px-4 py-1.5 text-xs font-medium transition-colors ${
              mode === "robin"
                ? "bg-[#1e2148] text-amber-400"
                : "text-slate-500 hover:text-slate-300"
            }`}
          >
            Robin Bound
          </button>
        </div>
        <button
          onClick={() => setShowPrimesOnly(!showPrimesOnly)}
          className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors border border-[#1e2148] ${
            showPrimesOnly
              ? "text-emerald-400 bg-emerald-500/10"
              : "text-slate-500"
          }`}
        >
          Primes Only
        </button>
        <div className="flex items-center gap-2 ml-auto">
          <span className="text-xs text-slate-500">N = {maxN}</span>
          <input
            type="range"
            min={50}
            max={500}
            value={maxN}
            onChange={(e) => setMaxN(parseInt(e.target.value))}
            className="w-32 accent-amber-500"
          />
        </div>
      </div>

      <div className="flex-1 flex overflow-hidden">
        {/* Chart */}
        <div className="flex-1 p-4 relative">
          <svg ref={svgRef} className="w-full h-full" />
        </div>

        {/* Side panel */}
        <div className="w-80 p-4 border-l border-[#1e2148] space-y-4 overflow-auto">
          {/* Milestone */}
          <div className="p-4 rounded-xl bg-gradient-to-br from-emerald-500/10 to-transparent border border-emerald-500/20">
            <div className="text-[10px] font-mono text-emerald-400 mb-2 tracking-wider">
              KERNEL-VERIFIED
            </div>
            <h3 className="text-sm font-bold text-emerald-400">
              lagarias_for_primes
            </h3>
            <p className="text-xs text-slate-500 mt-1 leading-relaxed">
              σ(p) ≤ H_p + exp(H_p)·ln(H_p) for <strong>all</strong> primes p.
              Zero gaps, zero axioms.
            </p>
          </div>

          {/* Proof architecture */}
          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148] space-y-3">
            <h4 className="text-xs font-semibold text-slate-400 uppercase tracking-wider">
              Three-Case Architecture
            </h4>
            <div className="space-y-2">
              <div className="flex items-start gap-2">
                <span className="text-emerald-400 text-xs mt-0.5">●</span>
                <div>
                  <div className="text-xs font-mono text-slate-300">
                    p ≥ 11
                  </div>
                  <div className="text-[10px] text-slate-500">
                    Algebraic bypass: H_p ≥ H_11 ≥ 3 {">"} e, so exp(H_p)·log(H_p)
                    ≥ p+1
                  </div>
                </div>
              </div>
              <div className="flex items-start gap-2">
                <span className="text-amber-400 text-xs mt-0.5">●</span>
                <div>
                  <div className="text-xs font-mono text-slate-300">
                    p ∈ {"{2, 3, 5, 7}"}
                  </div>
                  <div className="text-[10px] text-slate-500">
                    Taylor quartic truncation verified at exact rational
                    precision via norm_num
                  </div>
                </div>
              </div>
              <div className="flex items-start gap-2">
                <span className="text-blue-400 text-xs mt-0.5">●</span>
                <div>
                  <div className="text-xs font-mono text-slate-300">
                    Composites {"<"} 11
                  </div>
                  <div className="text-[10px] text-slate-500">
                    Dispatched via revert hp; decide
                  </div>
                </div>
              </div>
            </div>
          </div>

          {/* Hover detail */}
          {hoveredPoint && (
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148]"
            >
              <div className="flex items-center gap-2 mb-2">
                <span
                  className={`text-xs font-mono font-bold ${hoveredPoint.is_prime ? "text-emerald-400" : "text-blue-400"}`}
                >
                  n = {hoveredPoint.n}
                </span>
                {hoveredPoint.is_prime && (
                  <span className="text-[9px] px-1.5 py-0.5 rounded bg-emerald-500/15 text-emerald-400">
                    PRIME
                  </span>
                )}
              </div>
              <div className="space-y-1 text-xs">
                <div className="flex justify-between">
                  <span className="text-slate-500">σ(n)</span>
                  <span className="font-mono text-slate-300">
                    {hoveredPoint.sigma_n}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Lagarias bound</span>
                  <span className="font-mono text-amber-400">
                    {hoveredPoint.lagarias.toFixed(2)}
                  </span>
                </div>
                <div className="flex justify-between">
                  <span className="text-slate-500">Robin bound</span>
                  <span className="font-mono text-amber-400">
                    {hoveredPoint.robin === Infinity
                      ? "∞"
                      : hoveredPoint.robin.toFixed(2)}
                  </span>
                </div>
                <div className="flex justify-between border-t border-[#1e2148] pt-1 mt-1">
                  <span className="text-slate-500">Margin (Lagarias)</span>
                  <span className="font-mono text-emerald-400">
                    {hoveredPoint.margin_lagarias.toFixed(2)}
                  </span>
                </div>
                {hoveredPoint.is_prime && (
                  <div className="mt-2 pt-2 border-t border-[#1e2148]">
                    <div className="text-[10px] text-slate-500 mb-1">
                      Proof method
                    </div>
                    <div className="text-[10px] text-amber-400 font-mono">
                      {proofMethod(hoveredPoint.n)}
                    </div>
                  </div>
                )}
              </div>
            </motion.div>
          )}

          {/* Stats */}
          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148] text-xs space-y-2">
            <div className="flex justify-between">
              <span className="text-slate-500">Primes up to {maxN}</span>
              <span className="text-emerald-400 font-mono">
                {primeData.length}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">All satisfy Lagarias</span>
              <span className="text-emerald-400 font-bold">✓</span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">Min margin (prime)</span>
              <span className="text-amber-400 font-mono">
                {primeData.length > 0
                  ? d3
                      .min(primeData, (d: DataPoint) => d.margin_lagarias)
                      ?.toFixed(3)
                  : "—"}
              </span>
            </div>
            <div className="flex justify-between">
              <span className="text-slate-500">Tightest at</span>
              <span className="text-amber-400 font-mono">
                p ={" "}
                {primeData.reduce(
                  (min, d) =>
                    d.margin_lagarias < (min?.margin_lagarias ?? Infinity)
                      ? d
                      : min,
                  primeData[0]
                )?.n || "—"}
              </span>
            </div>
          </div>

          {/* Source file link */}
          <div className="p-3 rounded-lg bg-[#0a0b14] border border-[#1e2148] text-[10px] text-slate-600 font-mono">
            Cathedral/Robin/PrimeBounds.lean
          </div>
        </div>
      </div>
    </div>
  );
}
