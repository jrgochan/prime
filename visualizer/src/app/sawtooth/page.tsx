"use client";
import { useEffect, useRef, useState } from "react";
import * as d3 from "d3";
import { motion } from "framer-motion";
import { gramEntry } from "@/lib/math";

interface DataPoint {
  j: number;
  covariance: number;
  naiveBound: number;
}

export default function SawtoothPage() {
  const svgRef = useRef<SVGSVGElement>(null);
  const [maxJ, setMaxJ] = useState(80);
  const [data, setData] = useState<DataPoint[]>([]);
  const [animProgress, setAnimProgress] = useState(0);
  const [isAnimating, setIsAnimating] = useState(false);

  // Compute data
  useEffect(() => {
    const points: DataPoint[] = [];
    for (let j = 1; j <= maxJ; j++) {
      const g = gramEntry(j, j + 1, 2000);
      points.push({ j, covariance: g - 0.25, naiveBound: 1 / (4 * j) });
    }
    setData(points);
    setAnimProgress(points.length);
  }, [maxJ]);

  // Draw chart
  useEffect(() => {
    if (!svgRef.current || data.length === 0) return;

    const svg = d3.select(svgRef.current);
    svg.selectAll("*").remove();

    const margin = { top: 30, right: 30, bottom: 50, left: 70 };
    const width = svgRef.current.clientWidth - margin.left - margin.right;
    const height = svgRef.current.clientHeight - margin.top - margin.bottom;

    const g = svg.append("g").attr("transform", `translate(${margin.left},${margin.top})`);

    const visibleData = data.slice(0, animProgress);

    const x = d3.scaleLinear().domain([1, maxJ]).range([0, width]);
    const yMax = Math.max(d3.max(data, (d) => d.naiveBound) || 0.25, 0.05);
    const y = d3.scaleLinear().domain([-0.005, yMax]).range([height, 0]);

    // Grid
    g.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(x).ticks(10))
      .attr("color", "#334155");

    g.append("g")
      .call(d3.axisLeft(y).ticks(8).tickFormat(d3.format(".4f")))
      .attr("color", "#334155");

    // Axis labels
    svg.append("text").attr("x", margin.left + width / 2).attr("y", margin.top + height + 45)
      .attr("text-anchor", "middle").attr("fill", "#94a3b8").attr("font-size", 13).text("Index j");

    svg.append("text").attr("transform", "rotate(-90)")
      .attr("x", -(margin.top + height / 2)).attr("y", 20)
      .attr("text-anchor", "middle").attr("fill", "#94a3b8").attr("font-size", 13)
      .text("C(j) = G_{j,j+1} − 1/4");

    // Zero line
    g.append("line").attr("x1", 0).attr("x2", width)
      .attr("y1", y(0)).attr("y2", y(0))
      .attr("stroke", "#334155").attr("stroke-dasharray", "4,4");

    // C∞ reference line
    const cInf = 0.00227;
    g.append("line").attr("x1", 0).attr("x2", width)
      .attr("y1", y(cInf)).attr("y2", y(cInf))
      .attr("stroke", "#f59e0b").attr("stroke-dasharray", "6,3").attr("stroke-width", 1.5);

    g.append("text").attr("x", width - 5).attr("y", y(cInf) - 8)
      .attr("text-anchor", "end").attr("fill", "#f59e0b").attr("font-size", 11)
      .attr("font-family", "var(--font-geist-mono)")
      .text("C∞ ≈ 0.00227");

    // Naive bound curve (1/4j)
    const naiveLine = d3.line<DataPoint>().x((d) => x(d.j)).y((d) => y(d.naiveBound)).curve(d3.curveMonotoneX);
    g.append("path")
      .datum(data)
      .attr("fill", "none").attr("stroke", "#ef4444").attr("stroke-width", 1.5)
      .attr("stroke-dasharray", "4,4").attr("stroke-opacity", 0.6)
      .attr("d", naiveLine);

    g.append("text").attr("x", x(8)).attr("y", y(1 / 32) - 10)
      .attr("fill", "#ef4444").attr("font-size", 10).attr("font-family", "var(--font-geist-mono)")
      .text("Naive bound: 1/(4j)");

    // Actual covariance dots
    g.selectAll(".cov-dot")
      .data(visibleData)
      .join("circle")
      .attr("class", "cov-dot")
      .attr("cx", (d) => x(d.j))
      .attr("cy", (d) => y(d.covariance))
      .attr("r", 3)
      .attr("fill", (d) => d.covariance > d.naiveBound ? "#ef4444" : "#10b981")
      .attr("opacity", 0.8);

    // Connecting line
    const covLine = d3.line<DataPoint>().x((d) => x(d.j)).y((d) => y(d.covariance)).curve(d3.curveMonotoneX);
    g.append("path")
      .datum(visibleData)
      .attr("fill", "none").attr("stroke", "#10b981").attr("stroke-width", 1.5)
      .attr("d", covLine);

    // Highlight violations
    const violations = visibleData.filter((d) => d.covariance > d.naiveBound);
    if (violations.length > 0) {
      g.selectAll(".violation")
        .data(violations)
        .join("circle")
        .attr("cx", (d) => x(d.j))
        .attr("cy", (d) => y(d.covariance))
        .attr("r", 6)
        .attr("fill", "none")
        .attr("stroke", "#ef4444")
        .attr("stroke-width", 2)
        .attr("opacity", 0.8);
    }
  }, [data, animProgress, maxJ]);

  const startAnimation = () => {
    setAnimProgress(0);
    setIsAnimating(true);
    let step = 0;
    const interval = setInterval(() => {
      step++;
      setAnimProgress(step);
      if (step >= data.length) {
        clearInterval(interval);
        setIsAnimating(false);
      }
    }, 60);
  };

  const violations = data.filter((d) => d.covariance > d.naiveBound);

  return (
    <div className="h-full flex flex-col">
      <div className="p-6 border-b border-[#1e2148] flex items-center justify-between">
        <div>
          <h2 className="text-2xl font-bold text-slate-200">The Sawtooth Discovery</h2>
          <p className="text-sm text-slate-500 mt-1">
            The covariance C(j) = G<sub>j,j+1</sub> − 1/4 stabilizes instead of decaying to zero
          </p>
        </div>
        <div className="flex gap-3">
          <button
            onClick={startAnimation}
            disabled={isAnimating}
            className="px-4 py-2 rounded-lg bg-[#1e2148] text-amber-400 text-sm font-medium hover:bg-[#252966] transition-colors disabled:opacity-50"
          >
            {isAnimating ? "Animating..." : "▶ Replay"}
          </button>
        </div>
      </div>

      <div className="flex-1 flex">
        <div className="flex-1 p-4">
          <svg ref={svgRef} className="w-full h-full" />
        </div>

        <div className="w-72 p-4 border-l border-[#1e2148] space-y-4 overflow-auto">
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            className="p-4 rounded-xl bg-gradient-to-br from-amber-500/10 to-transparent border border-amber-500/20"
          >
            <div className="text-xs font-mono text-amber-400 mb-2">DISCOVERY</div>
            <p className="text-sm text-slate-300">
              The covariance does <strong>not</strong> decay as 1/j. It stabilizes at C∞ ≈ 0.00227 — a constant floor
              that formal verification revealed.
            </p>
          </motion.div>

          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148]">
            <div className="text-xs text-slate-500 mb-2">Bound Violations</div>
            <div className="text-2xl font-bold text-red-400">{violations.length}</div>
            <p className="text-xs text-slate-500 mt-1">points where C(j) {">"} 1/(4j)</p>
          </div>

          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148] text-xs text-slate-400 space-y-2">
            <p><strong className="text-emerald-400">Green dots:</strong> C(j) below naive bound</p>
            <p><strong className="text-red-400">Red circles:</strong> C(j) EXCEEDS 1/(4j)</p>
            <p><strong className="text-amber-400">Dashed line:</strong> C∞ ≈ 0.00227 floor</p>
          </div>

          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148]">
            <div className="text-xs text-slate-500 mb-2">Range</div>
            <input
              type="range"
              min={20}
              max={200}
              value={maxJ}
              onChange={(e) => setMaxJ(parseInt(e.target.value))}
              className="w-full accent-amber-500"
            />
            <div className="text-xs text-slate-500 mt-1">j = 1 to {maxJ}</div>
          </div>
        </div>
      </div>
    </div>
  );
}
