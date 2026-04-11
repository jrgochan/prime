"use client";
import { useEffect, useRef, useState } from "react";
import * as d3 from "d3";
import { motion } from "framer-motion";
import { gramEntry } from "@/lib/math";

interface DataPoint {
  n: number;
  sum: number;
  bound: number;
}

export default function OffDiagMarginPage() {
  const svgRef = useRef<SVGSVGElement>(null);
  const [maxN, setMaxN] = useState(50);
  const [data, setData] = useState<DataPoint[]>([]);
  const [computing, setComputing] = useState(false);

  useEffect(() => {
    setComputing(true);
    // Use requestAnimationFrame to not block UI
    requestAnimationFrame(() => {
      const points: DataPoint[] = [];
      let runningSum = 0;
      const cache: number[][] = [];

      for (let n = 2; n <= maxN; n++) {
        cache[n] = [];
        for (let k = 1; k < n; k++) {
          const g = gramEntry(n, k);
          cache[n][k] = g;
          runningSum += 2 * (g - 0.25);
        }
        points.push({ n, sum: runningSum, bound: 3 * n });
      }
      setData(points);
      setComputing(false);
    });
  }, [maxN]);

  useEffect(() => {
    if (!svgRef.current || data.length === 0) return;

    const svg = d3.select(svgRef.current);
    svg.selectAll("*").remove();

    const margin = { top: 30, right: 40, bottom: 55, left: 80 };
    const width = svgRef.current.clientWidth - margin.left - margin.right;
    const height = svgRef.current.clientHeight - margin.top - margin.bottom;
    const g = svg.append("g").attr("transform", `translate(${margin.left},${margin.top})`);

    const x = d3.scaleLinear().domain([2, maxN]).range([0, width]);
    const yMin = Math.min(d3.min(data, d => d.sum) || 0, -10);
    const yMax = Math.max(d3.max(data, d => d.bound) || 100, 50);
    const y = d3.scaleLinear().domain([yMin * 1.1, yMax * 1.1]).range([height, 0]);

    // Axes
    g.append("g").attr("transform", `translate(0,${height})`).call(d3.axisBottom(x).ticks(10)).attr("color", "#334155");
    g.append("g").call(d3.axisLeft(y).ticks(8)).attr("color", "#334155");

    // Labels
    svg.append("text").attr("x", margin.left + width / 2).attr("y", margin.top + height + 48)
      .attr("text-anchor", "middle").attr("fill", "#94a3b8").attr("font-size", 13).text("Matrix size n");
    svg.append("text").attr("transform", "rotate(-90)").attr("x", -(margin.top + height / 2)).attr("y", 20)
      .attr("text-anchor", "middle").attr("fill", "#94a3b8").attr("font-size", 13).text("Σ (G_ij − 1/4)");

    // Zero line
    g.append("line").attr("x1", 0).attr("x2", width)
      .attr("y1", y(0)).attr("y2", y(0))
      .attr("stroke", "#475569").attr("stroke-dasharray", "4,4");

    // Bound line (3n)
    const boundLine = d3.line<DataPoint>().x(d => x(d.n)).y(d => y(d.bound)).curve(d3.curveMonotoneX);
    g.append("path").datum(data)
      .attr("fill", "none").attr("stroke", "#ef4444").attr("stroke-width", 2)
      .attr("stroke-dasharray", "8,4").attr("d", boundLine);

    g.append("text").attr("x", x(maxN) - 5).attr("y", y(3 * maxN) - 10)
      .attr("text-anchor", "end").attr("fill", "#ef4444").attr("font-size", 11)
      .attr("font-family", "var(--font-geist-mono)").text("Bound: 3n");

    // Area fill between curve and bound (the margin)
    const area = d3.area<DataPoint>()
      .x(d => x(d.n))
      .y0(d => y(d.sum))
      .y1(d => y(d.bound))
      .curve(d3.curveMonotoneX);

    g.append("path").datum(data)
      .attr("fill", "url(#marginGradient)").attr("opacity", 0.3).attr("d", area);

    // Gradient
    const defs = svg.append("defs");
    const gradient = defs.append("linearGradient").attr("id", "marginGradient")
      .attr("x1", "0%").attr("y1", "0%").attr("x2", "0%").attr("y2", "100%");
    gradient.append("stop").attr("offset", "0%").attr("stop-color", "#f59e0b");
    gradient.append("stop").attr("offset", "100%").attr("stop-color", "#10b981");

    // Actual sum line
    const sumLine = d3.line<DataPoint>().x(d => x(d.n)).y(d => y(d.sum)).curve(d3.curveMonotoneX);
    g.append("path").datum(data)
      .attr("fill", "none").attr("stroke", "#10b981").attr("stroke-width", 2.5).attr("d", sumLine);

    // Dots
    g.selectAll(".dot").data(data).join("circle")
      .attr("cx", d => x(d.n)).attr("cy", d => y(d.sum))
      .attr("r", 2.5).attr("fill", "#10b981");

    // Label at end
    const last = data[data.length - 1];
    if (last) {
      g.append("text").attr("x", x(last.n) + 8).attr("y", y(last.sum) + 4)
        .attr("fill", "#10b981").attr("font-size", 11).attr("font-family", "var(--font-geist-mono)")
        .text(`≈ ${last.sum.toFixed(1)}`);
    }

  }, [data, maxN]);

  const last = data[data.length - 1];
  const marginRatio = last ? (last.bound / Math.abs(last.sum)).toFixed(1) : "—";

  return (
    <div className="h-full flex flex-col">
      <div className="p-6 border-b border-[#1e2148]">
        <h2 className="text-2xl font-bold text-slate-200">Off-Diagonal Gram Excess</h2>
        <p className="text-sm text-slate-500 mt-1">
          The running sum Σ(G<sub>ij</sub> − 1/4) dives negative while the structural bound 3n floats above —
          visualizing the margin from <code className="text-slate-400">GramOffDiag.lean</code>
        </p>
      </div>

      <div className="flex-1 flex">
        <div className="flex-1 p-4 relative">
          <svg ref={svgRef} className="w-full h-full" />
          {computing && (
            <div className="absolute inset-0 flex items-center justify-center bg-[#0a0b14]/60">
              <div className="text-amber-400 animate-pulse">Computing N={maxN}...</div>
            </div>
          )}
        </div>

        <div className="w-72 p-4 border-l border-[#1e2148] space-y-4 overflow-auto">
          <motion.div initial={{ opacity: 0 }} animate={{ opacity: 1 }}
            className="p-4 rounded-xl bg-gradient-to-br from-amber-500/10 to-transparent border border-amber-500/20"
          >
            <div className="text-xs font-mono text-amber-400 mb-2">SAFETY MARGIN</div>
            <div className="text-3xl font-bold text-amber-400">{marginRatio}×</div>
            <p className="text-xs text-slate-500 mt-1">bound / |actual sum|</p>
          </motion.div>

          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148]">
            <div className="text-xs text-slate-500 mb-1">Actual sum at n={maxN}</div>
            <div className="text-lg font-mono text-emerald-400">{last ? last.sum.toFixed(2) : "—"}</div>
            <div className="text-xs text-slate-500 mt-2">Bound (3n)</div>
            <div className="text-lg font-mono text-red-400">{last ? last.bound : "—"}</div>
          </div>

          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148] text-xs text-slate-400 space-y-2">
            <p><strong className="text-emerald-400">Green curve:</strong> Actual off-diagonal excess (negative!)</p>
            <p><strong className="text-red-400">Red dashed:</strong> Upper bound 3n (structural, from GramOffDiag)</p>
            <p><strong className="text-amber-400">Shaded region:</strong> The enormous safety margin</p>
          </div>

          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148]">
            <div className="text-xs text-slate-500 mb-2">Matrix size</div>
            <input type="range" min={10} max={80} value={maxN}
              onChange={(e) => setMaxN(parseInt(e.target.value))} className="w-full accent-amber-500" />
            <div className="text-xs text-slate-500 mt-1">n = {maxN}</div>
          </div>
        </div>
      </div>
    </div>
  );
}
