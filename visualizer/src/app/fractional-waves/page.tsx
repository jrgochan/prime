"use client";
import { useEffect, useRef, useState } from "react";
import * as d3 from "d3";
import { frac } from "@/lib/math";

export default function FractionalWavesPage() {
  const svgRef = useRef<SVGSVGElement>(null);
  const [activeK, setActiveK] = useState<number[]>([1, 2, 3]);
  const [showProduct, setShowProduct] = useState(false);
  const [productPair, setProductPair] = useState<[number, number]>([2, 3]);

  const COLORS = ["#10b981", "#3b82f6", "#f59e0b", "#ef4444", "#8b5cf6", "#ec4899", "#06b6d4", "#f97316"];

  useEffect(() => {
    if (!svgRef.current) return;
    const svg = d3.select(svgRef.current);
    svg.selectAll("*").remove();

    const margin = { top: 20, right: 30, bottom: 50, left: 60 };
    const width = svgRef.current.clientWidth - margin.left - margin.right;
    const height = svgRef.current.clientHeight - margin.top - margin.bottom;
    const g = svg.append("g").attr("transform", `translate(${margin.left},${margin.top})`);

    const numPoints = 2000;
    const x = d3.scaleLinear().domain([0.01, 1]).range([0, width]);
    const y = d3.scaleLinear().domain([-0.1, 1.1]).range([height, 0]);

    // Axes
    g.append("g").attr("transform", `translate(0,${height})`).call(d3.axisBottom(x).ticks(10)).attr("color", "#334155");
    g.append("g").call(d3.axisLeft(y).ticks(5)).attr("color", "#334155");

    svg.append("text").attr("x", margin.left + width / 2).attr("y", margin.top + height + 45)
      .attr("text-anchor", "middle").attr("fill", "#94a3b8").attr("font-size", 13).text("x");
    svg.append("text").attr("transform", "rotate(-90)").attr("x", -(margin.top + height / 2)).attr("y", 15)
      .attr("text-anchor", "middle").attr("fill", "#94a3b8").attr("font-size", 13).text("{k/x}");

    // Draw each active sawtooth
    activeK.forEach((k, idx) => {
      const points: [number, number][] = [];
      for (let i = 1; i <= numPoints; i++) {
        const xVal = i / numPoints;
        if (xVal < 0.005) continue;
        points.push([xVal, frac(k / xVal)]);
      }

      // Break into segments at discontinuities
      const segments: [number, number][][] = [[]];
      for (let i = 0; i < points.length; i++) {
        const cur = segments[segments.length - 1];
        if (cur.length > 0 && Math.abs(points[i][1] - cur[cur.length - 1][1]) > 0.5) {
          segments.push([]);
        }
        segments[segments.length - 1].push(points[i]);
      }

      const line = d3.line<[number, number]>().x(d => x(d[0])).y(d => y(d[1]));
      const color = COLORS[idx % COLORS.length];

      segments.forEach(seg => {
        if (seg.length < 2) return;
        g.append("path").datum(seg)
          .attr("fill", "none").attr("stroke", color).attr("stroke-width", 1.5)
          .attr("stroke-opacity", 0.8).attr("d", line);
      });
    });

    // Draw product if enabled
    if (showProduct) {
      const [j, k] = productPair;
      const productY = d3.scaleLinear().domain([-0.05, 0.6]).range([height, 0]);

      const points: [number, number][] = [];
      for (let i = 1; i <= numPoints; i++) {
        const xVal = i / numPoints;
        if (xVal < 0.005) continue;
        points.push([xVal, frac(j / xVal) * frac(k / xVal)]);
      }

      const segments: [number, number][][] = [[]];
      for (let i = 0; i < points.length; i++) {
        const cur = segments[segments.length - 1];
        if (cur.length > 0 && Math.abs(points[i][1] - cur[cur.length - 1][1]) > 0.3) {
          segments.push([]);
        }
        segments[segments.length - 1].push(points[i]);
      }

      const line = d3.line<[number, number]>().x(d => x(d[0])).y(d => productY(d[1]));

      segments.forEach(seg => {
        if (seg.length < 2) return;
        g.append("path").datum(seg)
          .attr("fill", "none").attr("stroke", "#f59e0b").attr("stroke-width", 2)
          .attr("stroke-opacity", 0.9).attr("d", line);
      });

      // 1/4 reference
      g.append("line").attr("x1", 0).attr("x2", width)
        .attr("y1", productY(0.25)).attr("y2", productY(0.25))
        .attr("stroke", "#f59e0b").attr("stroke-dasharray", "6,3").attr("stroke-opacity", 0.5);

      g.append("text").attr("x", width - 5).attr("y", productY(0.25) - 8)
        .attr("text-anchor", "end").attr("fill", "#f59e0b").attr("font-size", 10)
        .attr("font-family", "var(--font-geist-mono)").text("∫ = 1/4 (baseline)");
    }
  }, [activeK, showProduct, productPair]);

  const toggleK = (k: number) => {
    setActiveK(prev => prev.includes(k) ? prev.filter(v => v !== k) : [...prev, k]);
  };

  return (
    <div className="h-full flex flex-col">
      <div className="p-6 border-b border-[#1e2148]">
        <h2 className="text-2xl font-bold text-slate-200">Fractional Part Waves</h2>
        <p className="text-sm text-slate-500 mt-1">
          The sawtooth functions {"{"}k/x{"}"} that form the basis of the Gram matrix
        </p>
      </div>

      <div className="flex-1 flex">
        <div className="flex-1 p-4">
          <svg ref={svgRef} className="w-full h-full" />
        </div>

        <div className="w-72 p-4 border-l border-[#1e2148] space-y-4 overflow-auto">
          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148]">
            <div className="text-xs text-slate-500 mb-3">Active waves ({"{"}k/x{"}"})</div>
            <div className="grid grid-cols-4 gap-2">
              {[1, 2, 3, 4, 5, 6, 7, 8].map((k, i) => (
                <button key={k} onClick={() => toggleK(k)}
                  className={`px-2 py-1.5 rounded-lg text-xs font-mono transition-all ${
                    activeK.includes(k)
                      ? "text-white ring-1 ring-white/20"
                      : "text-slate-600 bg-[#0a0b14]"
                  }`}
                  style={{ backgroundColor: activeK.includes(k) ? COLORS[i] + "44" : undefined,
                           color: activeK.includes(k) ? COLORS[i] : undefined }}
                >
                  k={k}
                </button>
              ))}
            </div>
          </div>

          <div className="p-4 rounded-xl bg-[#12142a] border border-[#1e2148]">
            <label className="flex items-center gap-2 cursor-pointer">
              <input type="checkbox" checked={showProduct} onChange={e => setShowProduct(e.target.checked)}
                className="accent-amber-500" />
              <span className="text-sm text-slate-300">Show product {"{"}j/x{"}"}{"{"}k/x{"}"}</span>
            </label>
            {showProduct && (
              <div className="mt-3 flex gap-2">
                <select value={productPair[0]} onChange={e => setProductPair([parseInt(e.target.value), productPair[1]])}
                  className="bg-[#0a0b14] border border-[#1e2148] rounded px-2 py-1 text-xs text-slate-300">
                  {[1,2,3,4,5,6,7,8].map(k => <option key={k} value={k}>j={k}</option>)}
                </select>
                <select value={productPair[1]} onChange={e => setProductPair([productPair[0], parseInt(e.target.value)])}
                  className="bg-[#0a0b14] border border-[#1e2148] rounded px-2 py-1 text-xs text-slate-300">
                  {[1,2,3,4,5,6,7,8].map(k => <option key={k} value={k}>k={k}</option>)}
                </select>
              </div>
            )}
          </div>

          <div className="p-4 rounded-xl bg-gradient-to-br from-blue-500/10 to-transparent border border-blue-500/20 text-xs text-slate-400 space-y-2">
            <div className="text-xs font-mono text-blue-400 mb-2">HOW IT WORKS</div>
            <p>Each sawtooth {"{"}k/x{"}"} has k−1 discontinuities on (0,1].</p>
            <p>The Gram matrix entry G<sub>jk</sub> is the integral of the product of two such waves.</p>
            <p>The ∫ = 1/4 baseline comes from E[{"{"}X{"}"}] = 1/2.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
